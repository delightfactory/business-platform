-- Bounded payment recovery. The browser retains only an opaque attempt identity.
CREATE TABLE payroll.payment_requests(
 tenant_id uuid NOT NULL,request_id uuid NOT NULL DEFAULT gen_random_uuid(),actor_id uuid NOT NULL REFERENCES auth.users(id),employer_id uuid NOT NULL,output_id uuid NOT NULL,attempt_key uuid NOT NULL,request jsonb NOT NULL,state text NOT NULL DEFAULT 'pending' CHECK(state IN('pending','committed','cancelled')),result jsonb,created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),resolved_at timestamptz,PRIMARY KEY(tenant_id,request_id),UNIQUE(actor_id,attempt_key),FOREIGN KEY(tenant_id,employer_id,output_id) REFERENCES payroll.final_contexts(tenant_id,employer_id,id),CHECK(jsonb_typeof(request)='object'));
CREATE UNIQUE INDEX payroll_payment_requests_one_pending_scope ON payroll.payment_requests(tenant_id,actor_id,output_id) WHERE state='pending';
ALTER TABLE payroll.payment_requests ADD CONSTRAINT payroll_payment_request_shape CHECK(request ?& ARRAY['expected','operation','date','reference','reason','allocations','original','confirmed'] AND request->>'operation' IN('allocations','remaining','compensate') AND request->>'date' ~ '^\d{4}-\d{2}-\d{2}$' AND (request->>'date')::date IS NOT NULL AND request->>'confirmed'='true' AND jsonb_typeof(request->'allocations')='array');
ALTER TABLE payroll.payment_requests ADD CONSTRAINT payroll_payment_request_terminal CHECK((state='pending' AND result IS NULL AND resolved_at IS NULL) OR(state='committed' AND result IS NOT NULL AND resolved_at IS NOT NULL) OR(state='cancelled' AND result IS NULL AND resolved_at IS NOT NULL));
ALTER TABLE payroll.payment_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.payment_requests FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.payroll_payment_request_prepare(p_tenant uuid,p_employer uuid,p_output uuid,p_attempt uuid,p_request jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid();old payroll.payment_requests%ROWTYPE;c payroll.final_contexts%ROWTYPE;normalized jsonb;op text;d text;ref text;why text;alloc jsonb;original uuid;expected integer;receipt payroll.command_receipts%ROWTYPE;
BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
 IF a IS NULL OR NOT platform_private.has_tenant_permission(p_tenant,a,'payroll.payment_record') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_request->>'operation'='compensate' AND NOT platform_private.has_tenant_permission(p_tenant,a,'payroll.correct') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_attempt IS NULL OR jsonb_typeof(p_request) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.lock_payment_scope(p_tenant,p_employer,p_output);
 PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
 IF p_request->>'operation'='compensate' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;
 SELECT * INTO c FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 op:=p_request->>'operation';d:=p_request->>'date';ref:=btrim(COALESCE(p_request->>'reference',''));why:=btrim(COALESCE(p_request->>'reason',''));alloc:=COALESCE(p_request->'allocations','[]'::jsonb);
 BEGIN expected:=(p_request->>'expected')::integer;EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END;
 BEGIN IF p_request->>'original' IS NOT NULL AND p_request->>'original'<>'' THEN original:=(p_request->>'original')::uuid;END IF;EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END;
 IF expected IS NULL OR expected<0 OR op IS NULL OR d IS NULL OR op NOT IN('allocations','remaining','compensate') OR d !~ '^\d{4}-\d{2}-\d{2}$' OR length(ref) NOT BETWEEN 3 AND 160 OR length(why) NOT BETWEEN 3 AND 500 OR p_request->>'confirmed' IS DISTINCT FROM 'yes' OR jsonb_typeof(alloc) IS DISTINCT FROM 'array' OR jsonb_array_length(alloc)>100 THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF (op='allocations' AND(jsonb_array_length(alloc)=0 OR original IS NOT NULL)) OR(op<>'allocations' AND alloc<>'[]'::jsonb) OR(op='remaining' AND original IS NOT NULL) OR(op='compensate' AND original IS NULL) THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF NOT isfinite(d::date) OR d::date<DATE '0001-01-01' OR d::date>DATE '9999-12-31' THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF p_request-ARRAY['expected','operation','date','reference','reason','allocations','original','confirmed']<>'{}'::jsonb THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF d::date>(clock_timestamp() AT TIME ZONE(c.period_snapshot->>'timezone'))::date THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF op='allocations' AND EXISTS(SELECT 1 FROM jsonb_array_elements(alloc)i WHERE jsonb_typeof(i) IS DISTINCT FROM 'object' OR i-ARRAY['employment_id','amount']<>'{}'::jsonb OR COALESCE(i->>'employment_id','') !~* '^[0-9a-f-]{36}$' OR COALESCE(i->>'amount','') !~ '^\d{1,16}(\.\d{1,2})?$' ) THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF op='allocations' AND(EXISTS(SELECT 1 FROM jsonb_array_elements(alloc)i WHERE(i->>'amount')::numeric<=0) OR(SELECT count(*)<>count(DISTINCT(i->>'employment_id')::uuid) FROM jsonb_array_elements(alloc)i)) THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 normalized:=jsonb_build_object('expected',expected,'operation',op,'date',d::date,'reference',ref,'reason',why,'allocations',CASE WHEN op='allocations' THEN(SELECT jsonb_agg(jsonb_build_object('employment_id',(i->>'employment_id')::uuid,'amount',to_char((i->>'amount')::numeric,'FM9999999999999990.00')) ORDER BY(i->>'employment_id')::uuid) FROM jsonb_array_elements(alloc)i) ELSE '[]'::jsonb END,'original',original,'confirmed',true);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND AND receipt.intent<>normalized||jsonb_build_object('operation','payment_'||op,'employer',p_employer,'output',p_output) THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
 SELECT * INTO old FROM payroll.payment_requests WHERE actor_id=a AND attempt_key=p_attempt FOR UPDATE;
 IF FOUND THEN IF old.tenant_id<>p_tenant OR old.employer_id<>p_employer OR old.output_id<>p_output OR old.request<>normalized THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN jsonb_build_object('attempt',old.attempt_key,'state',old.state,'result',old.result);END IF;
 INSERT INTO payroll.payment_requests(tenant_id,actor_id,employer_id,output_id,attempt_key,request)VALUES(p_tenant,a,p_employer,p_output,p_attempt,normalized);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details)VALUES(p_tenant,p_employer,a,'payment_request_prepare',jsonb_build_object('output',p_output,'attempt',p_attempt));
 RETURN jsonb_build_object('attempt',p_attempt,'state','pending');
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';WHEN unique_violation THEN RAISE EXCEPTION 'payroll_payment_request_scope_busy' USING ERRCODE='55P03';END $f$;

CREATE FUNCTION public.payroll_payment_request_get(p_tenant uuid,p_employer uuid,p_output uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid();r payroll.payment_requests%ROWTYPE;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
 IF a IS NULL OR NOT platform_private.has_tenant_permission(p_tenant,a,'payroll.payment_record') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM payroll.payment_requests WHERE tenant_id=p_tenant AND actor_id=a AND employer_id=p_employer AND output_id=p_output AND state='pending' ORDER BY created_at DESC LIMIT 1;
 IF NOT FOUND THEN RETURN NULL;END IF;IF r.request->>'operation'='compensate' AND NOT platform_private.has_tenant_permission(p_tenant,a,'payroll.correct') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;RETURN jsonb_build_object('attempt',r.attempt_key,'state',r.state,'result',r.result);END $f$;

CREATE FUNCTION public.payroll_payment_request_submit(p_tenant uuid,p_employer uuid,p_output uuid,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid();r payroll.payment_requests%ROWTYPE;v jsonb;BEGIN
 SELECT * INTO r FROM payroll.payment_requests WHERE actor_id=a AND attempt_key=p_attempt;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF r.tenant_id<>p_tenant OR r.employer_id<>p_employer OR r.output_id<>p_output THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.lock_payment_scope(r.tenant_id,r.employer_id,r.output_id);
 SELECT * INTO r FROM payroll.payment_requests q WHERE q.tenant_id=r.tenant_id AND q.request_id=r.request_id FOR UPDATE;
 IF r.state='cancelled' THEN RAISE EXCEPTION 'payroll_payment_request_cancelled' USING ERRCODE='23514';END IF;
 PERFORM payroll.authorized(r.tenant_id,'payroll.payment_record',false);IF r.request->>'operation'='compensate' THEN PERFORM payroll.authorized(r.tenant_id,'payroll.correct',false);END IF;IF r.state='committed' THEN RETURN r.result;END IF;
 v:=public.payroll_record_payment(r.tenant_id,r.employer_id,r.output_id,(r.request->>'expected')::integer,r.request->>'operation',(r.request->>'date')::date,r.request->>'reference',r.request->>'reason',r.request->'allocations',(r.request->>'original')::uuid,true,r.attempt_key);
 UPDATE payroll.payment_requests SET state='committed',result=v,resolved_at=clock_timestamp() WHERE tenant_id=r.tenant_id AND request_id=r.request_id;RETURN v;END $f$;

CREATE FUNCTION payroll.payment_request_immutable() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF OLD.state<>'pending' AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'payroll_payment_request_immutable' USING ERRCODE='55000';END IF;
 IF TG_OP='DELETE' OR OLD.request_id IS DISTINCT FROM NEW.request_id OR OLD.created_at IS DISTINCT FROM NEW.created_at OR OLD.request IS DISTINCT FROM NEW.request OR OLD.attempt_key IS DISTINCT FROM NEW.attempt_key OR OLD.actor_id IS DISTINCT FROM NEW.actor_id OR OLD.tenant_id IS DISTINCT FROM NEW.tenant_id OR OLD.employer_id IS DISTINCT FROM NEW.employer_id OR OLD.output_id IS DISTINCT FROM NEW.output_id THEN RAISE EXCEPTION 'payroll_payment_request_immutable' USING ERRCODE='55000';END IF;
 IF NEW.state='pending' AND NEW.result IS NOT NULL THEN RAISE EXCEPTION 'payroll_payment_request_invalid_state' USING ERRCODE='22023';END IF;
 IF NEW.state='committed' AND NEW.result IS NULL THEN RAISE EXCEPTION 'payroll_payment_request_invalid_state' USING ERRCODE='22023';END IF;
 IF NEW.state<>'committed' AND NEW.result IS NOT NULL THEN RAISE EXCEPTION 'payroll_payment_request_invalid_state' USING ERRCODE='22023';END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER payment_request_immutable BEFORE UPDATE OR DELETE ON payroll.payment_requests FOR EACH ROW EXECUTE FUNCTION payroll.payment_request_immutable();
REVOKE ALL ON FUNCTION payroll.payment_request_immutable() FROM PUBLIC,anon,authenticated,service_role;

-- Cancellation also creates a non-executable tombstone when a response was lost before prepare.
CREATE FUNCTION public.payroll_payment_request_cancel(p_tenant uuid,p_employer uuid,p_output uuid,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid();r payroll.payment_requests%ROWTYPE;req jsonb:=jsonb_build_object('expected',0,'operation','allocations','date','0001-01-01','reference','cancelled','reason','cancelled before preparation','allocations','[]'::jsonb,'original',NULL,'confirmed',true);
BEGIN
 IF a IS NULL OR p_attempt IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
 IF NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.lock_payment_scope(p_tenant,p_employer,p_output);
 PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
 IF EXISTS(SELECT 1 FROM payroll.command_receipts cr WHERE cr.tenant_id=p_tenant AND cr.actor_id=a AND cr.attempt_key=p_attempt AND cr.intent->>'operation'='payment_compensate') THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;
 IF EXISTS(SELECT 1 FROM payroll.command_receipts cr WHERE cr.tenant_id=p_tenant AND cr.actor_id=a AND cr.attempt_key=p_attempt) THEN RAISE EXCEPTION 'payroll_payment_request_committed' USING ERRCODE='23514';END IF;
 SELECT * INTO r FROM payroll.payment_requests WHERE actor_id=a AND attempt_key=p_attempt FOR UPDATE;
 IF FOUND THEN
  IF r.tenant_id<>p_tenant OR r.employer_id<>p_employer OR r.output_id<>p_output THEN RAISE EXCEPTION 'payroll_payment_request_scope_conflict' USING ERRCODE='42501';END IF;
  PERFORM payroll.authorized(r.tenant_id,'payroll.payment_record',false);
  IF EXISTS(SELECT 1 FROM payroll.command_receipts cr WHERE cr.tenant_id=r.tenant_id AND cr.actor_id=a AND cr.attempt_key=r.attempt_key) THEN RAISE EXCEPTION 'payroll_payment_request_committed' USING ERRCODE='23514';END IF;
  IF r.state='committed' THEN RAISE EXCEPTION 'payroll_payment_request_committed' USING ERRCODE='23514';END IF;
  IF r.request->>'operation'='compensate' THEN PERFORM payroll.authorized(r.tenant_id,'payroll.correct',false);END IF;
  IF r.state='cancelled' THEN RETURN jsonb_build_object('attempt',p_attempt,'state','cancelled');END IF;
  UPDATE payroll.payment_requests SET state='cancelled',resolved_at=clock_timestamp() WHERE tenant_id=r.tenant_id AND request_id=r.request_id;
 ELSE
  PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
  INSERT INTO payroll.payment_requests(tenant_id,actor_id,employer_id,output_id,attempt_key,request,state,resolved_at) VALUES(p_tenant,a,p_employer,p_output,p_attempt,req,'cancelled',clock_timestamp());
 END IF;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details)VALUES(p_tenant,p_employer,a,'payment_request_cancel',jsonb_build_object('output',p_output,'attempt',p_attempt));
 RETURN jsonb_build_object('attempt',p_attempt,'state','cancelled');
END $f$;
REVOKE ALL ON FUNCTION public.payroll_payment_request_cancel(uuid,uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_payment_request_cancel(uuid,uuid,uuid,uuid) TO authenticated;


REVOKE ALL ON FUNCTION public.payroll_payment_request_prepare(uuid,uuid,uuid,uuid,jsonb),public.payroll_payment_request_get(uuid,uuid,uuid),public.payroll_payment_request_submit(uuid,uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_payment_request_prepare(uuid,uuid,uuid,uuid,jsonb),public.payroll_payment_request_get(uuid,uuid,uuid),public.payroll_payment_request_submit(uuid,uuid,uuid,uuid) TO authenticated;
