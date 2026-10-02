-- Slice 5 records external payment evidence only. No bank execution or public financial lock.
CREATE TABLE payroll.payment_heads(tenant_id uuid NOT NULL,output_id uuid NOT NULL,revision integer NOT NULL DEFAULT 0 CHECK(revision>=0),PRIMARY KEY(tenant_id,output_id),FOREIGN KEY(tenant_id,output_id) REFERENCES payroll.final_contexts(tenant_id,id));
CREATE TABLE payroll.payment_events(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,output_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),kind text NOT NULL CHECK(kind IN('payment','compensation')),
 original_event uuid,paid_on date NOT NULL,reference text NOT NULL CHECK(length(reference) BETWEEN 3 AND 160),reason text NOT NULL CHECK(length(reason) BETWEEN 3 AND 500),
 evidence_meaning text NOT NULL CHECK(evidence_meaning IN('external_payment_recorded','mistaken_record_only')),actor_id uuid NOT NULL REFERENCES auth.users(id),actor_label text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,output_id,id),FOREIGN KEY(tenant_id,employer_id,output_id) REFERENCES payroll.final_contexts(tenant_id,employer_id,id),
 FOREIGN KEY(tenant_id,output_id,original_event) REFERENCES payroll.payment_events(tenant_id,output_id,id),
 CHECK((kind='payment' AND original_event IS NULL AND evidence_meaning='external_payment_recorded') OR(kind='compensation' AND original_event IS NOT NULL AND evidence_meaning='mistaken_record_only')));
CREATE UNIQUE INDEX payroll_payment_compensated_once ON payroll.payment_events(tenant_id,original_event) WHERE kind='compensation';
CREATE TABLE payroll.payment_allocations(tenant_id uuid NOT NULL,output_id uuid NOT NULL,event_id uuid NOT NULL,employment_id uuid NOT NULL,amount numeric(18,2) NOT NULL CHECK(amount>0),
 PRIMARY KEY(tenant_id,event_id,employment_id),FOREIGN KEY(tenant_id,output_id,event_id) REFERENCES payroll.payment_events(tenant_id,output_id,id),FOREIGN KEY(tenant_id,output_id,employment_id) REFERENCES payroll.final_employees(tenant_id,output_id,employment_id));
DO $f$ DECLARE tab text;BEGIN
 FOREACH tab IN ARRAY ARRAY['payment_heads','payment_events','payment_allocations'] LOOP
  EXECUTE format('ALTER TABLE payroll.%I ENABLE ROW LEVEL SECURITY',tab);EXECUTE format('REVOKE ALL ON payroll.%I FROM PUBLIC,anon,authenticated,service_role',tab);
  IF tab<>'payment_heads' THEN EXECUTE format('CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.%I FOR EACH ROW EXECUTE FUNCTION payroll.immutable()',tab);END IF;
 END LOOP;
END $f$;
CREATE FUNCTION payroll.payment_authorized(p_tenant uuid,p_write boolean) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE a uuid:=auth.uid();BEGIN
 IF p_write THEN RETURN payroll.authorized(p_tenant,'payroll.payment_record',false);END IF;
 IF a IS NULL OR NOT(platform_private.has_tenant_permission(p_tenant,a,'payroll.view') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.payment_record')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 RETURN a;
END $f$;
CREATE FUNCTION public.payroll_payment_access(p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=payroll.payment_authorized(p_tenant,false);BEGIN
 RETURN jsonb_build_object('can_record',platform_private.has_tenant_permission(p_tenant,a,'payroll.payment_record'),'can_correct_record',platform_private.has_tenant_permission(p_tenant,a,'payroll.payment_record') AND platform_private.has_tenant_permission(p_tenant,a,'payroll.correct'),'enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.payroll',clock_timestamp()),'can_review_entry',platform_private.has_tenant_permission(p_tenant,a,'payroll.view') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.prepare') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.review') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.approve'));
END $f$;
CREATE FUNCTION payroll.lock_payment_scope(p_tenant uuid,p_employer uuid,p_output uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM payroll.lock_source_scope(p_tenant);
 PERFORM 1 FROM platform_core.tenants WHERE id=p_tenant FOR SHARE;
 PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant AND user_id=auth.uid() FOR SHARE;
 PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND EXISTS(SELECT 1 FROM payroll.final_employees f JOIN people.employments h ON h.tenant_id=f.tenant_id AND h.id=f.employment_id WHERE f.tenant_id=e.tenant_id AND f.output_id=p_output AND h.employee_id=e.id) ORDER BY e.id FOR UPDATE;
 PERFORM 1 FROM people.employments h WHERE h.tenant_id=p_tenant AND EXISTS(SELECT 1 FROM payroll.final_employees f WHERE f.tenant_id=h.tenant_id AND f.output_id=p_output AND f.employment_id=h.id) ORDER BY h.id FOR UPDATE;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 INSERT INTO payroll.payment_heads VALUES(p_tenant,p_output,0) ON CONFLICT DO NOTHING;
 PERFORM 1 FROM payroll.payment_heads WHERE tenant_id=p_tenant AND output_id=p_output FOR UPDATE;
END $f$;
CREATE FUNCTION payroll.output_has_ever_paid(p_tenant uuid,p_output uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT EXISTS(SELECT 1 FROM payroll.payment_events WHERE tenant_id=p_tenant AND output_id=p_output AND kind='payment')
$f$;
CREATE FUNCTION payroll.payment_balances(p_tenant uuid,p_output uuid) RETURNS TABLE(employment_id uuid,employee_snapshot jsonb,payable numeric,recorded numeric,compensated numeric,paid numeric,remaining numeric) LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT f.employment_id,f.employee_snapshot,f.net,COALESCE(p.recorded,0),COALESCE(p.compensated,0),COALESCE(p.recorded,0)-COALESCE(p.compensated,0),f.net-COALESCE(p.recorded,0)+COALESCE(p.compensated,0)
 FROM payroll.final_employees f LEFT JOIN LATERAL(SELECT sum(a.amount) FILTER(WHERE e.kind='payment') AS recorded,sum(a.amount) FILTER(WHERE e.kind='compensation') AS compensated FROM payroll.payment_allocations a JOIN payroll.payment_events e ON e.tenant_id=a.tenant_id AND e.id=a.event_id WHERE a.tenant_id=f.tenant_id AND a.output_id=f.output_id AND a.employment_id=f.employment_id)p ON true WHERE f.tenant_id=p_tenant AND f.output_id=p_output
$f$;
CREATE FUNCTION public.payroll_record_payment(p_tenant uuid,p_employer uuid,p_output uuid,p_expected integer,p_operation text,p_date date,p_reference text,p_reason text,p_allocations jsonb,p_original uuid,p_confirmed boolean,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;c payroll.final_contexts%ROWTYPE;revision integer;intent jsonb;receipt payroll.command_receipts%ROWTYPE;allocations jsonb;event uuid;total numeric;paid numeric;remaining numeric;result jsonb;BEGIN
 a:=payroll.payment_authorized(p_tenant,true);
 IF p_operation='compensate' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;
 IF p_expected IS NULL OR p_expected<0 OR p_attempt IS NULL OR p_operation IS NULL OR p_operation NOT IN('allocations','remaining','compensate') OR p_date IS NULL OR length(COALESCE(btrim(p_reference),'')) NOT BETWEEN 3 AND 160 OR length(COALESCE(btrim(p_reason),'')) NOT BETWEEN 3 AND 500 OR p_confirmed IS DISTINCT FROM true OR jsonb_typeof(p_allocations) IS DISTINCT FROM 'array' OR jsonb_array_length(p_allocations)>100 THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO c FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_date>(clock_timestamp() AT TIME ZONE(c.period_snapshot->>'timezone'))::date THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF(p_operation='allocations' AND(jsonb_array_length(p_allocations)=0 OR p_original IS NOT NULL)) OR(p_operation<>'allocations' AND p_allocations<>'[]'::jsonb) OR(p_operation='remaining' AND p_original IS NOT NULL) OR(p_operation='compensate' AND p_original IS NULL) THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 IF p_operation='allocations' THEN
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_allocations)i WHERE jsonb_typeof(i) IS DISTINCT FROM 'object' OR i-ARRAY['employment_id','amount']<>'{}'::jsonb OR COALESCE(i->>'employment_id','')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' OR COALESCE(i->>'amount','')!~'^[0-9]{1,16}(\.[0-9]{1,2})?$') THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_allocations)i WHERE(i->>'amount')::numeric<=0) OR(SELECT count(*)<>count(DISTINCT(i->>'employment_id')::uuid) FROM jsonb_array_elements(p_allocations)i) THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
  SELECT jsonb_agg(jsonb_build_object('employment_id',(i->>'employment_id')::uuid,'amount',to_char((i->>'amount')::numeric,'FM9999999999999990.00')) ORDER BY(i->>'employment_id')::uuid) INTO allocations FROM jsonb_array_elements(p_allocations)i;
 ELSE allocations:='[]';END IF;
 PERFORM payroll.lock_payment_scope(p_tenant,p_employer,p_output);a:=payroll.payment_authorized(p_tenant,true);IF p_operation='compensate' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;
 -- Entitlement-loss closure is limited to this existing approved, immutable obligation; it cannot create a run/payable.
 intent:=jsonb_build_object('operation','payment_'||p_operation,'employer',p_employer,'output',p_output,'expected',p_expected,'date',p_date,'reference',btrim(p_reference),'reason',btrim(p_reason),'allocations',allocations,'original',p_original,'confirmed',true);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 IF EXISTS(SELECT 1 FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_output) THEN RAISE EXCEPTION 'payroll_output_superseded' USING ERRCODE='23514';END IF;
 SELECT h.revision INTO revision FROM payroll.payment_heads h WHERE tenant_id=p_tenant AND output_id=p_output;
 IF revision<>p_expected THEN RAISE EXCEPTION 'payroll_payment_stale' USING ERRCODE='PT409';END IF;
 IF p_operation='remaining' THEN
  SELECT COALESCE(jsonb_agg(jsonb_build_object('employment_id',b.employment_id,'amount',b.remaining::text) ORDER BY b.employment_id),'[]') INTO allocations FROM payroll.payment_balances(p_tenant,p_output)b WHERE b.remaining>0;
  IF allocations='[]'::jsonb THEN RAISE EXCEPTION 'payroll_payment_complete' USING ERRCODE='23514';END IF;
 ELSIF p_operation='compensate' THEN
  IF NOT EXISTS(SELECT 1 FROM payroll.payment_events WHERE tenant_id=p_tenant AND output_id=p_output AND id=p_original AND kind='payment') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  IF EXISTS(SELECT 1 FROM payroll.payment_events WHERE tenant_id=p_tenant AND original_event=p_original) THEN RAISE EXCEPTION 'payroll_payment_compensated' USING ERRCODE='23514';END IF;
  SELECT jsonb_agg(jsonb_build_object('employment_id',employment_id,'amount',amount::text) ORDER BY employment_id) INTO allocations FROM payroll.payment_allocations WHERE tenant_id=p_tenant AND event_id=p_original;
 ELSE
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(allocations)i WHERE NOT EXISTS(SELECT 1 FROM payroll.final_employees WHERE tenant_id=p_tenant AND output_id=p_output AND employment_id=(i->>'employment_id')::uuid)) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(allocations)i JOIN payroll.payment_balances(p_tenant,p_output)b ON b.employment_id=(i->>'employment_id')::uuid WHERE(i->>'amount')::numeric>b.remaining) THEN RAISE EXCEPTION 'payroll_payment_excess' USING ERRCODE='23514';END IF;
 END IF;
 IF jsonb_array_length(allocations)>5000 OR allocations IS NULL THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 INSERT INTO payroll.payment_events(tenant_id,employer_id,output_id,kind,original_event,paid_on,reference,reason,evidence_meaning,actor_id,actor_label) VALUES(p_tenant,p_employer,p_output,CASE WHEN p_operation='compensate' THEN 'compensation' ELSE 'payment' END,p_original,p_date,btrim(p_reference),btrim(p_reason),CASE WHEN p_operation='compensate' THEN 'mistaken_record_only' ELSE 'external_payment_recorded' END,a,(SELECT COALESCE(email,'مسؤول تسجيل الدفعات') FROM auth.users WHERE id=a)) RETURNING id INTO event;
 INSERT INTO payroll.payment_allocations SELECT p_tenant,p_output,event,(i->>'employment_id')::uuid,(i->>'amount')::numeric FROM jsonb_array_elements(allocations)i;
 UPDATE payroll.payment_heads h SET revision=h.revision+1 WHERE tenant_id=p_tenant AND output_id=p_output;
 SELECT COALESCE(sum(b.paid),0),COALESCE(sum(b.remaining),0) INTO paid,remaining FROM payroll.payment_balances(p_tenant,p_output)b;
 SELECT sum((i->>'amount')::numeric) INTO total FROM jsonb_array_elements(allocations)i;
 result:=jsonb_build_object('event_id',event,'revision',revision+1,'amount',total::text,'paid',paid::text,'remaining',remaining::text,'status',CASE WHEN paid=0 THEN 'unpaid' WHEN remaining=0 THEN 'paid' ELSE 'partially_paid' END,'ever_paid',payroll.output_has_ever_paid(p_tenant,p_output),'kind',CASE WHEN p_operation='compensate' THEN 'compensation' ELSE 'payment' END);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'payment_'||p_operation,intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.payment_authorized(p_tenant,true);IF p_operation='compensate' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;RETURN result;
END $f$;
CREATE FUNCTION public.payroll_payment_workspace(p_tenant uuid,p_employer uuid,p_output uuid,p_query text DEFAULT '',p_after uuid DEFAULT NULL,p_history_before uuid DEFAULT NULL,p_event uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;c payroll.final_contexts%ROWTYPE;access jsonb;summary jsonb;items jsonb;history jsonb;revision integer;cursor_time timestamptz;entry jsonb;BEGIN
 a:=payroll.payment_authorized(p_tenant,false);
 IF p_query IS NULL OR length(p_query)>120 THEN RAISE EXCEPTION 'payroll_payment_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO c FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.lock_source_scope(p_tenant);access:=public.payroll_payment_access(p_tenant);
 IF p_history_before IS NOT NULL THEN SELECT created_at INTO cursor_time FROM payroll.payment_events WHERE tenant_id=p_tenant AND output_id=p_output AND id=p_history_before;IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;END IF;
 IF p_event IS NOT NULL THEN SELECT jsonb_build_object('reference',reference,'kind',kind,'paid_on',paid_on) INTO entry FROM payroll.payment_events WHERE tenant_id=p_tenant AND output_id=p_output AND id=p_event;IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;END IF;
 SELECT h.revision INTO revision FROM payroll.payment_heads h WHERE tenant_id=p_tenant AND output_id=p_output;
 SELECT jsonb_build_object('payable',COALESCE(sum(payable),0)::text,'recorded',COALESCE(sum(recorded),0)::text,'compensated',COALESCE(sum(compensated),0)::text,'paid',COALESCE(sum(paid),0)::text,'remaining',COALESCE(sum(remaining),0)::text,'employee_count',count(*),'remaining_count',count(*) FILTER(WHERE remaining>0),'status',CASE WHEN COALESCE(sum(paid),0)=0 THEN 'unpaid' WHEN COALESCE(sum(remaining),0)=0 THEN 'paid' ELSE 'partially_paid' END,'ever_paid',payroll.output_has_ever_paid(p_tenant,p_output)) INTO summary FROM payroll.payment_balances(p_tenant,p_output);
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY employment_id),'[]') INTO items FROM(SELECT employment_id,employee_snapshot,payable::text,recorded::text,compensated::text,paid::text,remaining::text,(SELECT a.amount::text FROM payroll.payment_allocations a WHERE a.tenant_id=p_tenant AND a.output_id=p_output AND a.event_id=p_event AND a.employment_id=b.employment_id) AS entry_amount FROM payroll.payment_balances(p_tenant,p_output)b WHERE(p_event IS NULL OR EXISTS(SELECT 1 FROM payroll.payment_allocations a WHERE a.tenant_id=p_tenant AND a.output_id=p_output AND a.event_id=p_event AND a.employment_id=b.employment_id)) AND(p_after IS NULL OR employment_id>p_after) AND(employee_snapshot->>'name' ILIKE '%'||p_query||'%' OR employee_snapshot->>'code' ILIKE '%'||p_query||'%') ORDER BY employment_id LIMIT 30)x;
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY created_at DESC,id DESC),'[]') INTO history FROM(SELECT e.id,e.kind,e.original_event,e.paid_on,e.reference,e.reason,e.actor_label,e.created_at,sum(a.amount)::text AS amount,count(*) AS employee_count,EXISTS(SELECT 1 FROM payroll.payment_events x WHERE x.tenant_id=e.tenant_id AND x.original_event=e.id) AS compensated FROM payroll.payment_events e JOIN payroll.payment_allocations a ON a.tenant_id=e.tenant_id AND a.event_id=e.id WHERE e.tenant_id=p_tenant AND e.output_id=p_output AND(p_history_before IS NULL OR(e.created_at,e.id)<(cursor_time,p_history_before)) GROUP BY e.id,e.tenant_id ORDER BY e.created_at DESC,e.id DESC LIMIT 20)x;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'payment_workspace_access',jsonb_build_object('output',p_output,'event',p_event,'employee_count',jsonb_array_length(items),'history_count',jsonb_array_length(history)));
 PERFORM payroll.payment_authorized(p_tenant,false);
 RETURN jsonb_build_object('access',access,'today',(clock_timestamp() AT TIME ZONE(c.period_snapshot->>'timezone'))::date,'output_id',p_output,'employer',c.legal_employer,'period',jsonb_build_object('starts_on',c.period_snapshot->>'starts_on','ends_on',c.period_snapshot->>'ends_on'),'revision',COALESCE(revision,0),'summary',summary,'selected_entry',entry,'employees',items,'history',history,'superseded',EXISTS(SELECT 1 FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_output));
END $f$;
-- The irrevocable fact is historical payment, not today's compensated balance.
DO $f$ DECLARE definition text;BEGIN
 definition:=pg_get_functiondef('payroll.guard_output_succession_scope()'::regprocedure);
 IF definition NOT LIKE '%RETURN NEW;%' THEN RAISE EXCEPTION 'unexpected_succession_guard';END IF;
 definition:=replace(definition,' SELECT * INTO old_output',' PERFORM payroll.lock_source_scope(NEW.tenant_id);SELECT * INTO old_output');
 IF definition NOT LIKE '%PERFORM payroll.lock_source_scope(NEW.tenant_id)%' THEN RAISE EXCEPTION 'unexpected_succession_lock';END IF;
 EXECUTE replace(definition,'RETURN NEW;','IF payroll.output_has_ever_paid(NEW.tenant_id,NEW.original_output) THEN RAISE EXCEPTION ''payroll_paid_correction_route_required'' USING ERRCODE=''23514'';END IF;RETURN NEW;');
 definition:=pg_get_functiondef('public.payroll_run_access(uuid)'::regprocedure);
 IF definition NOT LIKE '%''can_view_final'',%' THEN RAISE EXCEPTION 'unexpected_run_access';END IF;
 EXECUTE replace(definition,'''can_view_final'',','''can_payment_record'',platform_private.has_tenant_permission(p_tenant,a,''payroll.payment_record''),''can_view_final'',');
 definition:=pg_get_functiondef('platform_private.people_role_bundle_catalog()'::regprocedure);
 IF definition NOT LIKE '%payroll.reviewer.v1%' OR definition LIKE '%payroll.payment.recorder.v1%' THEN RAISE EXCEPTION 'unexpected_role_catalog';END IF;
 EXECUTE replace(definition,'''payroll.reviewer.v1''::text,ARRAY[''payroll.view'',''payroll.review'']::text[])','''payroll.reviewer.v1''::text,ARRAY[''payroll.view'',''payroll.review'']::text[]),(''payroll.payment.recorder.v1''::text,ARRAY[''payroll.view'',''payroll.payment_record'']::text[])');
 definition:=pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure);
 IF definition NOT LIKE '%cardinality(p_bundle_keys) > 23%' THEN RAISE EXCEPTION 'unexpected_role_limit';END IF;
 EXECUTE replace(definition,'cardinality(p_bundle_keys) > 23','cardinality(p_bundle_keys) > 24');
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_payment_access(uuid),public.payroll_record_payment(uuid,uuid,uuid,integer,text,date,text,text,jsonb,uuid,boolean,uuid),public.payroll_payment_workspace(uuid,uuid,uuid,text,uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_payment_access(uuid),public.payroll_record_payment(uuid,uuid,uuid,integer,text,date,text,text,jsonb,uuid,boolean,uuid),public.payroll_payment_workspace(uuid,uuid,uuid,text,uuid,uuid,uuid) TO authenticated;
