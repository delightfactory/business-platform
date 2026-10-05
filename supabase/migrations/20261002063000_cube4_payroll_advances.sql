-- Slice 7: interest-free Employee Finance subledger. No bank execution or legal qualification bypass.
-- Finance is optional. Existing obligations remain closable after commercial entitlement loss.
ALTER TABLE platform_core.tenant_capability_entitlements DROP CONSTRAINT tenant_capability_entitlements_capability_key_check;
ALTER TABLE platform_core.tenant_capability_entitlements ADD CONSTRAINT tenant_capability_entitlements_capability_key_check CHECK(capability_key IN('hr.people','hr.payroll','hr.attendance','hr.leave','hr.employee_finance'));
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events DROP CONSTRAINT tenant_capability_entitlement_audit_events_capability_key_check;
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events ADD CONSTRAINT tenant_capability_entitlement_audit_events_capability_key_check CHECK(capability_key IN('hr.people','hr.payroll','hr.attendance','hr.leave','hr.employee_finance'));
DO $f$ DECLARE signature text;definition text;BEGIN
 FOREACH signature IN ARRAY ARRAY['platform_private.tenant_capability_is_enabled(uuid,text,timestamp with time zone)','public.platform_tenant_entitlement_snapshot(uuid)','public.change_tenant_capability_entitlement(uuid,text,boolean,date,text)'] LOOP
  definition:=pg_get_functiondef(signature::regprocedure);
  IF position('''hr.leave''' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_finance_capability_definition';END IF;
  definition:=replace(definition,'''hr.people'',''hr.payroll'',''hr.attendance'',''hr.leave''','''hr.people'',''hr.payroll'',''hr.attendance'',''hr.leave'',''hr.employee_finance''');
  definition:=replace(definition,'''hr.payroll'',''hr.leave''','''hr.payroll'',''hr.leave'',''hr.employee_finance''');
  IF signature='public.platform_tenant_entitlement_snapshot(uuid)' THEN definition:=replace(definition,'(''hr.leave'')) w(key)','(''hr.leave''),(''hr.employee_finance'')) w(key)');END IF;
  EXECUTE definition;
 END LOOP;
END $f$;
-- Preserve People dependency when terminating its commercial entitlement.
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.change_tenant_capability_entitlement(uuid,text,boolean,date,text)'::regprocedure);
 d:=replace(d,'before_state:=jsonb_build_object',
 'IF p_capability_key=''hr.people'' AND EXISTS(SELECT 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key=''hr.employee_finance'' AND e.is_granted AND e.valid_from<=now_at AND(e.valid_until IS NULL OR e.valid_until>now_at) AND(NOT p_is_granted OR(expiry IS NOT NULL AND(e.valid_until IS NULL OR e.valid_until>expiry)))) THEN RAISE EXCEPTION ''tenant_entitlement_finance_must_end_first'' USING ERRCODE=''23514'';END IF; before_state:=jsonb_build_object');
 EXECUTE d;
END $f$;
CREATE TABLE payroll.advance_heads(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,id uuid NOT NULL,employment_id uuid NOT NULL,revision integer NOT NULL CHECK(revision>0),
 status text NOT NULL CHECK(status IN('draft','approved','active','cancelled')),version_id uuid NOT NULL,
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,employer_id,id),FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id),FOREIGN KEY(tenant_id,employer_id) REFERENCES platform_core.tenant_legal_entities(tenant_id,id));
CREATE TABLE payroll.advance_versions(
 tenant_id uuid NOT NULL,advance_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),revision integer NOT NULL,
 principal numeric(18,2) NOT NULL CHECK(principal>0),effective_on date NOT NULL,first_period uuid NOT NULL,
 installment_count integer NOT NULL CHECK(installment_count BETWEEN 1 AND 120),installment_amount numeric(18,2) NOT NULL CHECK(installment_amount>0),
 reason text NOT NULL CHECK(length(reason) BETWEEN 3 AND 500),created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,advance_id,revision),UNIQUE(tenant_id,advance_id,id),FOREIGN KEY(tenant_id,advance_id) REFERENCES payroll.advance_heads(tenant_id,id),FOREIGN KEY(tenant_id,first_period) REFERENCES payroll.periods(tenant_id,id));
ALTER TABLE payroll.advance_heads ADD FOREIGN KEY(tenant_id,id,version_id) REFERENCES payroll.advance_versions(tenant_id,advance_id,id) DEFERRABLE INITIALLY DEFERRED;
CREATE TABLE payroll.advance_installments(
 tenant_id uuid NOT NULL,advance_id uuid NOT NULL,version_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),ordinal integer NOT NULL CHECK(ordinal>0),period_id uuid NOT NULL,amount numeric(18,2) NOT NULL CHECK(amount>0),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,version_id,ordinal),UNIQUE(tenant_id,version_id,period_id),UNIQUE(tenant_id,advance_id,id),FOREIGN KEY(tenant_id,advance_id,version_id) REFERENCES payroll.advance_versions(tenant_id,advance_id,id),FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id));
CREATE TABLE payroll.advance_events(
 tenant_id uuid NOT NULL,advance_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),kind text NOT NULL CHECK(kind IN('approval','disbursement','settlement','compensation','termination_review','deferral_review','payroll_deduction')),
 delta numeric(18,2) NOT NULL,occurred_on date NOT NULL,reference text NOT NULL CHECK(length(reference) BETWEEN 3 AND 160),reason text NOT NULL CHECK(length(reason) BETWEEN 3 AND 500),
 original_event uuid,output_id uuid,installment_id uuid,correction_case uuid,actor_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,advance_id,id),FOREIGN KEY(tenant_id,advance_id) REFERENCES payroll.advance_heads(tenant_id,id),
 FOREIGN KEY(tenant_id,advance_id,original_event) REFERENCES payroll.advance_events(tenant_id,advance_id,id),FOREIGN KEY(tenant_id,output_id) REFERENCES payroll.final_contexts(tenant_id,id),FOREIGN KEY(tenant_id,installment_id) REFERENCES payroll.advance_installments(tenant_id,id),FOREIGN KEY(tenant_id,correction_case) REFERENCES payroll.correction_cases(tenant_id,id),
 CHECK((kind<>'payroll_deduction' OR installment_id IS NOT NULL)), CHECK((kind='disbursement' AND delta>0 AND original_event IS NULL AND output_id IS NULL) OR(kind='settlement' AND delta<0 AND original_event IS NULL AND output_id IS NULL) OR(kind='payroll_deduction' AND delta<0 AND original_event IS NULL AND output_id IS NOT NULL) OR(kind='compensation' AND delta<>0 AND original_event IS NOT NULL) OR(kind IN('approval','termination_review','deferral_review') AND delta=0 AND original_event IS NULL AND output_id IS NULL)));
CREATE UNIQUE INDEX advance_output_installment_once ON payroll.advance_events(tenant_id,output_id,installment_id) WHERE kind='payroll_deduction';
CREATE UNIQUE INDEX advance_disbursed_once ON payroll.advance_events(tenant_id,advance_id) WHERE kind='disbursement';
CREATE UNIQUE INDEX advance_event_compensated_once ON payroll.advance_events(tenant_id,original_event) WHERE kind='compensation';
-- A separately approved replacement never overwrites mistaken principal evidence.
CREATE TABLE payroll.advance_replacements(tenant_id uuid NOT NULL,replacement_id uuid NOT NULL,original_id uuid NOT NULL,correction_event uuid NOT NULL,
 PRIMARY KEY(tenant_id,replacement_id),UNIQUE(tenant_id,original_id),CHECK(replacement_id<>original_id),
 FOREIGN KEY(tenant_id,replacement_id) REFERENCES payroll.advance_heads(tenant_id,id),FOREIGN KEY(tenant_id,original_id,correction_event) REFERENCES payroll.advance_events(tenant_id,advance_id,id));
CREATE TABLE payroll.advance_allocations(
 tenant_id uuid NOT NULL,advance_id uuid NOT NULL,event_id uuid NOT NULL,installment_id uuid NOT NULL,amount numeric(18,2) NOT NULL CHECK(amount<>0),
 PRIMARY KEY(tenant_id,event_id,installment_id),FOREIGN KEY(tenant_id,advance_id,event_id) REFERENCES payroll.advance_events(tenant_id,advance_id,id),FOREIGN KEY(tenant_id,advance_id,installment_id) REFERENCES payroll.advance_installments(tenant_id,advance_id,id));
CREATE TABLE payroll.advance_deferrals(tenant_id uuid NOT NULL,advance_id uuid NOT NULL,installment_id uuid NOT NULL,revision integer NOT NULL,target_period uuid NOT NULL,event_id uuid NOT NULL,
 PRIMARY KEY(tenant_id,installment_id,revision),FOREIGN KEY(tenant_id,advance_id,installment_id) REFERENCES payroll.advance_installments(tenant_id,advance_id,id),FOREIGN KEY(tenant_id,target_period) REFERENCES payroll.periods(tenant_id,id),FOREIGN KEY(tenant_id,advance_id,event_id) REFERENCES payroll.advance_events(tenant_id,advance_id,id));
-- A terminal absence proof shares the writer serialization lock. Never time-expire this tombstone.
CREATE INDEX advance_allocations_installment ON payroll.advance_allocations(tenant_id,installment_id);
CREATE INDEX advance_heads_employer ON payroll.advance_heads(tenant_id,employer_id,employment_id);
CREATE TABLE payroll.advance_attempt_closures(tenant_id uuid NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),attempt uuid NOT NULL,intent jsonb NOT NULL,closed_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(tenant_id,actor_id,attempt));
-- Trusted future statutory adapter only. Ordinary callers cannot create an allowance or assert qualification.
CREATE TABLE payroll.advance_allowances(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,period_id uuid NOT NULL,employment_id uuid NOT NULL,installment_id uuid NOT NULL,
 source_revision integer NOT NULL,amount numeric(18,2) NOT NULL CHECK(amount>0),qualified_pack uuid NOT NULL,
 wage_basis numeric(18,2) NOT NULL CHECK(wage_basis>0),category text NOT NULL CHECK(length(category)>0),obligation_identity text NOT NULL CHECK(length(obligation_identity)>0),evidence text NOT NULL CHECK(length(evidence)>0),
 PRIMARY KEY(tenant_id,period_id,installment_id,source_revision),FOREIGN KEY(qualified_pack) REFERENCES payroll.statutory_packs(id),FOREIGN KEY(tenant_id,installment_id) REFERENCES payroll.advance_installments(tenant_id,id),FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id),FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id));
DO $f$ DECLARE tab text;BEGIN
 FOREACH tab IN ARRAY ARRAY['advance_replacements','advance_deferrals','advance_heads','advance_versions','advance_installments','advance_events','advance_allocations','advance_attempt_closures','advance_allowances'] LOOP
  EXECUTE format('ALTER TABLE payroll.%I ENABLE ROW LEVEL SECURITY',tab);EXECUTE format('REVOKE ALL ON payroll.%I FROM PUBLIC,anon,authenticated,service_role',tab);
  IF tab<>'advance_heads' THEN EXECUTE format('CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.%I FOR EACH ROW EXECUTE FUNCTION payroll.immutable()',tab);END IF;
 END LOOP;
END $f$;
CREATE FUNCTION payroll.advance_authorized(p_tenant uuid,p_operation text) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE a uuid:=auth.uid();required text;BEGIN
 required:=CASE WHEN p_operation IN('approve','activate','settle','compensate','termination','defer','correct_deduction','correct_disbursement') THEN 'employee_finance.approve' ELSE 'employee_finance.manage' END;
 IF p_operation='view' THEN
  IF a IS NULL OR NOT(platform_private.has_tenant_permission(p_tenant,a,'employee_finance.view') OR platform_private.has_tenant_permission(p_tenant,a,'employee_finance.manage') OR platform_private.has_tenant_permission(p_tenant,a,'employee_finance.approve')) THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501';END IF;
 ELSE PERFORM payroll.authorized(p_tenant,required,false);IF p_operation='correct_disbursement' THEN PERFORM payroll.authorized(p_tenant,'employee_finance.manage',false);END IF;IF p_operation='correct_deduction' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;END IF;
 RETURN a;
END $f$;
CREATE FUNCTION payroll.lock_advance_scope(p_tenant uuid,p_employer uuid,p_employment uuid,p_advance uuid) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 PERFORM payroll.lock_source_scope(p_tenant);
 PERFORM 1 FROM platform_core.tenants WHERE id=p_tenant FOR SHARE;
 PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant AND user_id=auth.uid() FOR SHARE;
 PERFORM 1 FROM people.employees e JOIN people.employments h ON h.tenant_id=e.tenant_id AND h.employee_id=e.id WHERE h.tenant_id=p_tenant AND h.id=p_employment AND h.employer_entity_id=p_employer FOR UPDATE OF e;
 IF NOT FOUND THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501';END IF;
 PERFORM 1 FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment FOR UPDATE;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer FOR UPDATE;
 PERFORM 1 FROM payroll.advance_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND employment_id=p_employment AND id=p_advance FOR UPDATE;
END $f$;
CREATE FUNCTION payroll.advance_balance(p_tenant uuid,p_advance uuid) RETURNS numeric LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT COALESCE(sum(delta),0) FROM payroll.advance_events WHERE tenant_id=p_tenant AND advance_id=p_advance
$f$;
CREATE FUNCTION payroll.advance_status(p_tenant uuid,p_advance uuid) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT CASE WHEN EXISTS(SELECT 1 FROM payroll.advance_events original JOIN payroll.advance_events reversal ON reversal.tenant_id=original.tenant_id AND reversal.original_event=original.id WHERE original.tenant_id=h.tenant_id AND original.advance_id=h.id AND original.kind='disbursement' AND reversal.kind='compensation' AND reversal.delta=-original.delta) THEN 'record_corrected'
 WHEN h.status='active' AND payroll.advance_balance(p_tenant,h.id)=0 THEN 'settled' ELSE h.status END FROM payroll.advance_heads h WHERE h.tenant_id=p_tenant AND h.id=p_advance
$f$;
CREATE FUNCTION payroll.installment_remaining(p_tenant uuid,p_installment uuid) RETURNS numeric LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT i.amount-COALESCE((SELECT sum(a.amount) FROM payroll.advance_allocations a WHERE a.tenant_id=i.tenant_id AND a.installment_id=i.id),0) FROM payroll.advance_installments i WHERE i.tenant_id=p_tenant AND i.id=p_installment
$f$;
-- Both writer and resolver accept the identical scoped intent, including invalid financial fields.
-- Financial validation happens after tombstone/receipt resolution so a delayed write can never escape closure.
CREATE FUNCTION payroll.advance_intent_authority(p_tenant uuid,p_employer uuid,p_intent jsonb) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE op text:=p_intent->>'operation';BEGIN
 IF jsonb_typeof(p_intent) IS DISTINCT FROM 'object' OR p_intent-ARRAY['operation','advance','employment','expected','data']<>'{}'::jsonb OR op IS NULL OR op NOT IN('save','approve','activate','cancel','settle','compensate','termination','defer','correct_deduction','correct_disbursement') OR p_intent->>'advance' IS NULL OR p_intent->>'employment' IS NULL OR jsonb_typeof(p_intent->'data') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.advance_authorized(p_tenant,op);
 PERFORM payroll.lock_advance_scope(p_tenant,p_employer,(p_intent->>'employment')::uuid,(p_intent->>'advance')::uuid);
 IF op='correct_deduction' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;RETURN payroll.advance_authorized(p_tenant,op);
END $f$;
CREATE FUNCTION public.payroll_resolve_advance_attempt(p_tenant uuid,p_employer uuid,p_intent jsonb,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;intent jsonb;r payroll.command_receipts%ROWTYPE;c payroll.advance_attempt_closures%ROWTYPE;BEGIN
 IF p_attempt IS NULL THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 a:=payroll.advance_intent_authority(p_tenant,p_employer,p_intent);intent:=jsonb_build_object('operation','advance_command','employer',p_employer,'request',p_intent);
 SELECT * INTO r FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF r.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN jsonb_build_object('resolution','committed','result',r.result);END IF;
 SELECT * INTO c FROM payroll.advance_attempt_closures WHERE tenant_id=p_tenant AND actor_id=a AND attempt=p_attempt;
 IF FOUND THEN IF c.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
 ELSE
  INSERT INTO payroll.advance_attempt_closures(tenant_id,actor_id,attempt,intent) VALUES(p_tenant,a,p_attempt,intent);
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'advance_attempt_closed',jsonb_build_object('attempt',p_attempt,'advance',p_intent->>'advance','original_operation',p_intent->>'operation'));
 END IF;
 PERFORM payroll.advance_authorized(p_tenant,p_intent->>'operation');
 RETURN jsonb_build_object('resolution','closed_without_commit');
END $f$;
CREATE FUNCTION public.payroll_advance_command(p_tenant uuid,p_employer uuid,p_intent jsonb,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;request_intent jsonb;receipt payroll.command_receipts%ROWTYPE;h payroll.advance_heads%ROWTYPE;v payroll.advance_versions%ROWTYPE;d jsonb:=p_intent->'data';op text:=p_intent->>'operation';aid uuid:=(p_intent->>'advance')::uuid;hid uuid:=(p_intent->>'employment')::uuid;expected integer;
 principal numeric;cents bigint;unit_cents bigint;n integer;first payroll.periods%ROWTYPE;period record;counted integer:=0;last_end date;vid uuid;event uuid;original payroll.advance_events%ROWTYPE;balance numeric;amount numeric;left_amount numeric;allocation numeric;item record;result jsonb;day date;reference text;reason text;BEGIN
 IF p_attempt IS NULL THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 a:=payroll.advance_intent_authority(p_tenant,p_employer,p_intent);IF op='correct_deduction' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;request_intent:=jsonb_build_object('operation','advance_command','employer',p_employer,'request',p_intent);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>request_intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 IF EXISTS(SELECT 1 FROM payroll.advance_attempt_closures WHERE tenant_id=p_tenant AND actor_id=a AND attempt=p_attempt) THEN IF EXISTS(SELECT 1 FROM payroll.advance_attempt_closures WHERE tenant_id=p_tenant AND actor_id=a AND attempt=p_attempt AND advance_attempt_closures.intent<>request_intent) THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RAISE EXCEPTION 'finance_attempt_closed' USING ERRCODE='PT409';END IF;
 IF COALESCE(p_intent->>'expected','')!~'^[0-9]{1,9}$' THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;expected:=(p_intent->>'expected')::integer;
 IF d-(CASE op WHEN 'save' THEN ARRAY['principal','count','installment_amount','first_period','effective_on','reason','corrected_advance'] WHEN 'settle' THEN ARRAY['date','reference','reason','amount','confirmed'] WHEN 'correct_disbursement' THEN ARRAY['date','reference','reason','original','confirmed'] WHEN 'compensate' THEN ARRAY['date','reference','reason','original','confirmed'] WHEN 'defer' THEN ARRAY['date','reference','reason','installment','target_period','confirmed'] WHEN 'correct_deduction' THEN ARRAY['date','reference','reason','original','correction_case','confirmed'] ELSE ARRAY['date','reference','reason','confirmed'] END)<>'{}'::jsonb THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 reason:=btrim(COALESCE(d->>'reason',''));reference:=btrim(COALESCE(d->>'reference',''));day:=COALESCE((d->>'date')::date,(clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date);
 IF length(reason) NOT BETWEEN 3 AND 500 OR(op<>'save' AND length(reference) NOT BETWEEN 3 AND 160) OR day>(clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date OR(op<>'save' AND d->>'confirmed' IS DISTINCT FROM 'yes') THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO h FROM payroll.advance_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND employment_id=hid AND advance_heads.id=aid;
 IF(h.id IS NULL AND(expected<>0 OR op<>'save')) OR(h.id IS NOT NULL AND h.revision<>expected) THEN RAISE EXCEPTION 'finance_stale' USING ERRCODE='PT409';END IF;
 IF h.id IS NOT NULL THEN SELECT * INTO v FROM payroll.advance_versions WHERE tenant_id=p_tenant AND advance_versions.id=h.version_id;END IF;
 balance:=payroll.advance_balance(p_tenant,aid);
 IF op='save' THEN
  IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.employee_finance',clock_timestamp()) THEN RAISE EXCEPTION 'finance_disabled' USING ERRCODE='55000';END IF;
  IF h.id IS NOT NULL AND h.status<>'draft' THEN RAISE EXCEPTION 'finance_schedule_immutable' USING ERRCODE='23514';END IF;
  IF COALESCE(d->>'principal','')!~'^[0-9]{1,12}(\.[0-9]{1,2})?$' OR(d->>'count' IS NOT NULL AND COALESCE(d->>'count','')!~'^[0-9]{1,3}$') OR(d->>'installment_amount' IS NOT NULL AND COALESCE(d->>'installment_amount','')!~'^[0-9]{1,12}(\.[0-9]{1,2})?$') OR((d->>'count' IS NULL)=(d->>'installment_amount' IS NULL)) THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
  principal:=(d->>'principal')::numeric;cents:=(principal*100)::bigint;
  IF principal<=0 THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
  IF d->>'count' IS NOT NULL THEN n:=(d->>'count')::integer;IF n NOT BETWEEN 1 AND 120 OR cents<n THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;unit_cents:=cents/n;
  ELSE unit_cents:=((d->>'installment_amount')::numeric*100)::bigint;IF unit_cents<=0 OR unit_cents>cents THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;n:=ceil(cents::numeric/unit_cents)::integer;IF n>120 THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;END IF;
  SELECT * INTO first FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND periods.id=(d->>'first_period')::uuid;
  IF first.id IS NULL OR(d->>'effective_on')::date>first.ends_on OR(d->>'effective_on')::date<(SELECT start_date FROM people.employments WHERE tenant_id=p_tenant AND employments.id=hid) OR EXISTS(SELECT 1 FROM people.employments eh WHERE eh.tenant_id=p_tenant AND eh.id=hid AND eh.end_date IS NOT NULL AND(d->>'effective_on')::date>eh.end_date) OR EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND(period_snapshot->>'ends_on')::date>=first.starts_on) THEN RAISE EXCEPTION 'finance_first_period_invalid' USING ERRCODE='23514';END IF;
  vid:=gen_random_uuid();
  IF h.id IS NULL THEN INSERT INTO payroll.advance_heads VALUES(p_tenant,p_employer,aid,hid,1,'draft',vid);ELSE UPDATE payroll.advance_heads SET revision=revision+1,version_id=vid WHERE tenant_id=p_tenant AND advance_heads.id=aid;END IF;
  INSERT INTO payroll.advance_versions(tenant_id,advance_id,id,revision,principal,effective_on,first_period,installment_count,installment_amount,reason,created_by) VALUES(p_tenant,aid,vid,expected+1,principal,(d->>'effective_on')::date,first.id,n,unit_cents::numeric/100,reason,a);
  FOR period IN SELECT * FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND starts_on>=first.starts_on ORDER BY starts_on LIMIT n LOOP
   counted:=counted+1;IF last_end IS NOT NULL AND period.starts_on<>last_end+1 THEN RAISE EXCEPTION 'finance_schedule_periods_missing' USING ERRCODE='23514';END IF;last_end:=period.ends_on;
   IF EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=period.id) THEN RAISE EXCEPTION 'finance_first_period_invalid' USING ERRCODE='23514';END IF;
   INSERT INTO payroll.advance_installments(tenant_id,advance_id,version_id,ordinal,period_id,amount) VALUES(p_tenant,aid,vid,counted,period.id,(CASE WHEN counted=n THEN cents-unit_cents*(n-1) ELSE unit_cents END)::numeric/100);
  END LOOP;
  IF counted<>n THEN RAISE EXCEPTION 'finance_schedule_periods_missing' USING ERRCODE='23514';END IF;
  IF NULLIF(d->>'corrected_advance','') IS NOT NULL THEN
   IF h.id IS NULL THEN
    SELECT ev.* INTO original FROM payroll.advance_heads old JOIN payroll.advance_events ev ON ev.tenant_id=old.tenant_id AND ev.advance_id=old.id AND ev.kind='compensation' AND ev.delta<0 JOIN payroll.advance_events disb ON disb.tenant_id=ev.tenant_id AND disb.id=ev.original_event AND disb.kind='disbursement' WHERE old.tenant_id=p_tenant AND old.employer_id=p_employer AND old.employment_id=hid AND old.id=(d->>'corrected_advance')::uuid AND payroll.advance_status(p_tenant,old.id)='record_corrected';
    IF original.id IS NULL THEN RAISE EXCEPTION 'finance_principal_reconciliation_required' USING ERRCODE='23514';END IF;
    INSERT INTO payroll.advance_replacements VALUES(p_tenant,aid,(d->>'corrected_advance')::uuid,original.id);
   ELSIF NOT EXISTS(SELECT 1 FROM payroll.advance_replacements WHERE tenant_id=p_tenant AND replacement_id=aid AND original_id=(d->>'corrected_advance')::uuid) THEN RAISE EXCEPTION 'finance_principal_reconciliation_required' USING ERRCODE='23514';END IF;
  END IF;
 ELSIF op='approve' THEN
  IF h.status<>'draft' OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.employee_finance',clock_timestamp()) THEN RAISE EXCEPTION 'finance_activation_blocked' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,actor_id) VALUES(p_tenant,aid,'approval',0,day,reference,reason,a);
  UPDATE payroll.advance_heads SET status='approved',revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='activate' THEN
  IF h.status<>'approved' OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.employee_finance',clock_timestamp()) OR day<v.effective_on OR EXISTS(SELECT 1 FROM payroll.final_contexts f JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=v.first_period WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND(f.period_snapshot->>'ends_on')::date>=p.starts_on) THEN RAISE EXCEPTION 'finance_activation_blocked' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,actor_id) VALUES(p_tenant,aid,'disbursement',v.principal,day,reference,reason,a);
  UPDATE payroll.advance_heads SET status='active',revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='cancel' THEN
  IF h.status NOT IN('draft','approved') OR balance<>0 THEN RAISE EXCEPTION 'finance_cancel_blocked' USING ERRCODE='23514';END IF;
  UPDATE payroll.advance_heads SET status='cancelled',revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='settle' THEN
  IF h.status<>'active' OR COALESCE(d->>'amount','')!~'^[0-9]{1,12}(\.[0-9]{1,2})?$' THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;amount:=(d->>'amount')::numeric;
  IF amount<=0 OR amount>balance THEN RAISE EXCEPTION 'finance_settlement_excess' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,actor_id) VALUES(p_tenant,aid,'settlement',-amount,day,reference,reason,a) RETURNING advance_events.id INTO event;
  left_amount:=amount;
  FOR item IN SELECT i.id,payroll.installment_remaining(p_tenant,i.id) remaining FROM payroll.advance_installments i WHERE i.tenant_id=p_tenant AND i.version_id=h.version_id ORDER BY ordinal LOOP
   allocation:=least(left_amount,item.remaining);IF allocation>0 THEN INSERT INTO payroll.advance_allocations VALUES(p_tenant,aid,event,item.id,allocation);left_amount:=left_amount-allocation;END IF;EXIT WHEN left_amount=0;
  END LOOP;
  IF left_amount<>0 THEN RAISE EXCEPTION 'finance_balance_inconsistent' USING ERRCODE='23514';END IF;
  UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='correct_disbursement' THEN
  SELECT * INTO original FROM payroll.advance_events WHERE tenant_id=p_tenant AND advance_id=aid AND advance_events.id=(d->>'original')::uuid AND kind='disbursement';
  IF original.id IS NULL OR h.status<>'active' OR balance<>original.delta OR EXISTS(SELECT 1 FROM payroll.advance_events WHERE tenant_id=p_tenant AND advance_id=aid AND(kind IN('settlement','payroll_deduction') OR original_event=original.id)) THEN RAISE EXCEPTION 'finance_principal_reconciliation_required' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,original_event,actor_id) VALUES(p_tenant,aid,'compensation',-original.delta,day,reference,reason,original.id,a);
  UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='compensate' THEN
  SELECT * INTO original FROM payroll.advance_events WHERE tenant_id=p_tenant AND advance_id=aid AND advance_events.id=(d->>'original')::uuid AND kind='settlement';
  IF original.id IS NULL OR EXISTS(SELECT 1 FROM payroll.advance_events WHERE tenant_id=p_tenant AND original_event=original.id) THEN RAISE EXCEPTION 'finance_compensation_invalid' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,original_event,actor_id) VALUES(p_tenant,aid,'compensation',-original.delta,day,reference,reason,original.id,a) RETURNING advance_events.id INTO event;
  INSERT INTO payroll.advance_allocations SELECT al.tenant_id,al.advance_id,event,al.installment_id,-al.amount FROM payroll.advance_allocations al WHERE al.tenant_id=p_tenant AND al.event_id=original.id;
  UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='defer' THEN
  IF h.status<>'active' THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
  SELECT p.* INTO first FROM payroll.periods p WHERE p.tenant_id=p_tenant AND p.employer_id=p_employer AND p.id=(d->>'target_period')::uuid;
  IF first.id IS NULL OR NOT EXISTS(SELECT 1 FROM payroll.advance_installments i JOIN payroll.periods p ON p.tenant_id=i.tenant_id AND p.id=i.period_id WHERE i.tenant_id=p_tenant AND i.advance_id=aid AND i.version_id=h.version_id AND i.id=(d->>'installment')::uuid AND first.starts_on>p.ends_on AND payroll.installment_remaining(p_tenant,i.id)>0) OR EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=first.id) OR EXISTS(SELECT 1 FROM payroll.advance_deferrals x JOIN payroll.periods p ON p.tenant_id=x.tenant_id AND p.id=x.target_period WHERE x.tenant_id=p_tenant AND x.installment_id=(d->>'installment')::uuid AND first.starts_on<=p.ends_on) THEN RAISE EXCEPTION 'finance_deferral_invalid' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,actor_id) VALUES(p_tenant,aid,'deferral_review',0,day,reference,reason,a) RETURNING advance_events.id INTO event;
  INSERT INTO payroll.advance_deferrals VALUES(p_tenant,aid,(d->>'installment')::uuid,h.revision+1,first.id,event);
  UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='correct_deduction' THEN
  PERFORM payroll.authorized(p_tenant,'payroll.correct',false);
  SELECT * INTO original FROM payroll.advance_events WHERE tenant_id=p_tenant AND advance_id=aid AND advance_events.id=(d->>'original')::uuid AND kind='payroll_deduction';
  IF original.id IS NULL OR NOT payroll.output_has_ever_paid(p_tenant,original.output_id) OR EXISTS(SELECT 1 FROM payroll.advance_events WHERE tenant_id=p_tenant AND original_event=original.id) OR NOT EXISTS(SELECT 1 FROM payroll.correction_cases cc JOIN payroll.correction_proposals cp ON cp.tenant_id=cc.tenant_id AND cp.id=cc.proposal_id WHERE cc.tenant_id=p_tenant AND cc.employer_id=p_employer AND cc.id=(d->>'correction_case')::uuid AND cc.original_output=original.output_id AND cc.status IN('routed','completed') AND EXISTS(SELECT 1 FROM jsonb_array_elements(cp.responsibilities)rr WHERE rr->>'employment_id'=hid::text AND rr->>'output_id'=original.output_id::text AND rr->>'basis'='external_reviewed' AND (rr->>'amount')::numeric=-original.delta)) THEN RAISE EXCEPTION 'finance_governed_correction_required' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,original_event,correction_case,actor_id) VALUES(p_tenant,aid,'compensation',-original.delta,day,reference,reason,original.id,(d->>'correction_case')::uuid,a) RETURNING advance_events.id INTO event;
  INSERT INTO payroll.advance_allocations SELECT al.tenant_id,al.advance_id,event,al.installment_id,-al.amount FROM payroll.advance_allocations al WHERE al.tenant_id=p_tenant AND al.event_id=original.id;
  UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 ELSIF op='termination' THEN
  IF h.status<>'active' OR balance<=0 OR NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND employments.id=hid AND end_date IS NOT NULL AND end_date<=day) THEN RAISE EXCEPTION 'finance_termination_review_invalid' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,actor_id) VALUES(p_tenant,aid,'termination_review',0,day,reference,reason,a);
  UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 END IF;
 SELECT jsonb_build_object('id',advance_heads.id,'revision',revision,'status',payroll.advance_status(p_tenant,advance_heads.id),'outstanding',payroll.advance_balance(p_tenant,advance_heads.id)::text) INTO result FROM payroll.advance_heads WHERE tenant_id=p_tenant AND advance_heads.id=aid;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'advance_'||op,request_intent||jsonb_build_object('result',result));
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,request_intent,result);
 PERFORM payroll.advance_authorized(p_tenant,op);IF op='correct_deduction' THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);END IF;RETURN result;
END $f$;
-- Unpaid replacement eligibility uses virtual balance excluding that original output, including fully consumed heads.
CREATE FUNCTION payroll.advance_sources(p_tenant uuid,p_employer uuid,p_period uuid,p_original uuid DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT COALESCE(jsonb_agg(jsonb_build_object('advance',h.id,'employment_id',h.employment_id,'revision',h.revision,'version',h.version_id,'installment',i.id,'scheduled_period',due.id,'ordinal',i.ordinal,
 'amount',i.amount::text,'outstanding',greatest(0,i.amount-COALESCE(x.applied,0))::text,
 'allowance',CASE WHEN a.amount IS NOT NULL AND a.source_revision=h.revision AND s.state='verified' AND s.engine_adapter IS NOT NULL THEN to_jsonb(a) END) ORDER BY h.id,i.ordinal),'[]')
 FROM payroll.advance_heads h JOIN payroll.advance_installments i ON i.tenant_id=h.tenant_id AND i.version_id=h.version_id
 JOIN payroll.periods due ON due.tenant_id=i.tenant_id AND due.id=COALESCE((SELECT x.target_period FROM payroll.advance_deferrals x WHERE x.tenant_id=i.tenant_id AND x.installment_id=i.id ORDER BY x.revision DESC LIMIT 1),i.period_id) JOIN payroll.periods target ON target.tenant_id=h.tenant_id AND target.employer_id=h.employer_id AND target.id=p_period
 LEFT JOIN LATERAL(SELECT sum(al.amount) AS applied FROM payroll.advance_allocations al JOIN payroll.advance_events ev ON ev.tenant_id=al.tenant_id AND ev.id=al.event_id WHERE al.tenant_id=i.tenant_id AND al.installment_id=i.id AND(ev.output_id IS DISTINCT FROM p_original OR p_original IS NULL))x ON true
 LEFT JOIN payroll.advance_allowances a ON a.tenant_id=i.tenant_id AND a.installment_id=i.id AND a.period_id=p_period AND a.employment_id=h.employment_id AND a.employer_id=h.employer_id AND a.source_revision=h.revision
 LEFT JOIN payroll.statutory_packs s ON s.id=a.qualified_pack AND daterange(s.effective_from,s.effective_until,'[)')@>daterange(target.starts_on,target.ends_on,'[]')
 WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.status='active' AND (p_original IS NULL OR NOT payroll.output_has_ever_paid(p_tenant,p_original)) AND payroll.advance_balance(p_tenant,h.id)-COALESCE((SELECT sum(ev.delta) FROM payroll.advance_events ev WHERE ev.tenant_id=h.tenant_id AND ev.advance_id=h.id AND ev.output_id=p_original),0)>0 AND due.starts_on<=target.ends_on AND i.amount-COALESCE(x.applied,0)>0
$f$;
ALTER FUNCTION payroll.run_manifest(uuid,uuid,uuid) RENAME TO run_manifest_before_advances;
CREATE FUNCTION payroll.run_manifest(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE m jsonb;BEGIN
 m:=payroll.run_manifest_before_advances(p_tenant,p_employer,p_period);
 RETURN jsonb_set(m||jsonb_build_object('advances',payroll.advance_sources(p_tenant,p_employer,p_period),'engine',(m->>'engine')||'-advances-v1'),'{optional,finance}',jsonb_build_object('enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.employee_finance',clock_timestamp()),'projection','advances-v1','adjustments','unchanged'));
END $f$;
-- Replacements restore the original unpaid allocation only in their private calculation projection.
-- The paid original is never reopened. Source and old movements remain immutable.
ALTER FUNCTION payroll.amendment_manifest(uuid,uuid) RENAME TO amendment_manifest_before_advances;
CREATE FUNCTION payroll.amendment_manifest(p_tenant uuid,p_run uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE m jsonb;r payroll.runs%ROWTYPE;BEGIN
 m:=payroll.amendment_manifest_before_advances(p_tenant,p_run);
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run;
 IF r.amendment_of IS NOT NULL THEN
  IF payroll.output_has_ever_paid(p_tenant,r.amendment_of) THEN RAISE EXCEPTION 'finance_paid_original_preserved' USING ERRCODE='23514';END IF;
  m:=m||jsonb_build_object('advances',payroll.advance_sources(p_tenant,r.employer_id,r.period_id,r.amendment_of));
 END IF;
 RETURN m;
END $f$;
ALTER FUNCTION payroll.stale_reasons(jsonb,jsonb) RENAME TO stale_reasons_before_advances;
CREATE FUNCTION payroll.stale_reasons(p_old jsonb,p_current jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT payroll.stale_reasons_before_advances(p_old,p_current)||CASE WHEN p_old->'advances' IS DISTINCT FROM p_current->'advances' THEN '["advances_changed"]'::jsonb ELSE '[]'::jsonb END
$f$;
ALTER FUNCTION payroll.build_review(jsonb) RENAME TO build_review_before_advances;
CREATE FUNCTION payroll.build_review(p_manifest jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE result jsonb;employees jsonb:='[]';e jsonb;source jsonb;issues jsonb;employee_issues jsonb;deductions numeric;total numeric:=0;lines jsonb;amount numeric;allowed jsonb;seen text[]:='{}';BEGIN
 result:=payroll.build_review_before_advances(p_manifest);issues:=result->'issues';
 FOR e IN SELECT value FROM jsonb_array_elements(result->'employees') LOOP
  employee_issues:=e->'issues';deductions:=0;lines:=e->'lines';allowed:='[]';
  FOR source IN SELECT value FROM jsonb_array_elements(COALESCE(p_manifest->'advances','[]')) WHERE value->>'employment_id'=e->>'employment_id' LOOP
   seen:=array_append(seen,source->>'installment');
   IF source->'allowance' IS NULL OR source->'allowance'='null'::jsonb THEN
    employee_issues:=employee_issues||jsonb_build_array(payroll.issue('advance_caps_unqualified',(e->>'employment_id')::uuid,'employee_finance_compliance'));CONTINUE;
   END IF;
   amount:=(source->'allowance'->>'amount')::numeric;
   IF amount<=0 OR amount>(source->>'outstanding')::numeric OR source->'allowance'->>'source_revision' IS DISTINCT FROM source->>'revision' THEN
    employee_issues:=employee_issues||jsonb_build_array(payroll.issue('advance_allowance_stale',(e->>'employment_id')::uuid,'employee_finance_compliance'));CONTINUE;
   END IF;
   deductions:=deductions+amount;allowed:=allowed||jsonb_build_array(source||jsonb_build_object('consumed_amount',amount::text));
   lines:=lines||jsonb_build_array(jsonb_build_object('component','advance:'||(source->>'installment'),'name','قسط سلفة مُراجع','classification','deduction','amount',amount::text,'details',jsonb_build_array(jsonb_build_object('reason','قسط معتمد ضمن أساس خصم مؤهل','approved_amount',amount::text))));
   IF amount<(source->>'outstanding')::numeric THEN employee_issues:=employee_issues||jsonb_build_array(payroll.issue('advance_carry_forward_required',(e->>'employment_id')::uuid,'employee_finance'));END IF;
  END LOOP;
  total:=total+deductions;issues:=issues||(SELECT COALESCE(jsonb_agg(i),'[]') FROM jsonb_array_elements(employee_issues)i WHERE i->>'code' LIKE 'advance_%');
  employees:=employees||jsonb_build_array(e||jsonb_build_object('issues',employee_issues,'lines',lines,'deductions',((e->>'deductions')::numeric+deductions)::text,'advance_deductions',allowed));
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(COALESCE(p_manifest->'advances','[]'))s WHERE NOT(s->>'installment'=ANY(seen))) THEN issues:=issues||jsonb_build_array(payroll.issue('advance_employment_unavailable',NULL,'employee_finance'));END IF;
 RETURN result||jsonb_build_object('engine',p_manifest->>'engine','employees',employees,'issues',issues,'deductions',((result->>'deductions')::numeric+total)::text);
END $f$;
-- All locked deduction postings share the source-finalization transaction and the original receipt.
ALTER FUNCTION payroll.append_final_output_single(uuid,uuid,uuid,uuid,integer,uuid) RENAME TO append_final_output_before_advances;
CREATE FUNCTION payroll.append_final_output_single(p_tenant uuid,p_run uuid,p_candidate uuid,p_actor uuid,p_expected integer,p_attempt uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE r payroll.runs%ROWTYPE;c payroll.candidates%ROWTYPE;am payroll.runs%ROWTYPE;item jsonb;e jsonb;h payroll.advance_heads%ROWTYPE;remaining numeric;event uuid;output uuid;old record;existing payroll.command_receipts%ROWTYPE;BEGIN
 PERFORM payroll.correction_append_authority(p_tenant,p_run);
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run;
 PERFORM payroll.lock_finalization_sources(p_tenant,r.employer_id,r.period_id);
 SELECT * INTO existing FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=p_actor AND attempt_key=p_attempt;
 IF FOUND THEN RETURN payroll.append_final_output_before_advances(p_tenant,p_run,p_candidate,p_actor,p_expected,p_attempt);END IF;
 SELECT * INTO c FROM payroll.candidates WHERE tenant_id=p_tenant AND run_id=p_run AND id=p_candidate;
 SELECT * INTO am FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run;
 IF am.amendment_of IS NOT NULL AND payroll.output_has_ever_paid(p_tenant,am.amendment_of) THEN RAISE EXCEPTION 'finance_paid_original_preserved' USING ERRCODE='23514';END IF;
 FOR e IN SELECT value FROM jsonb_array_elements(c.output->'employees') LOOP
  FOR item IN SELECT value FROM jsonb_array_elements(COALESCE(e->'advance_deductions','[]')) LOOP
   SELECT * INTO h FROM payroll.advance_heads WHERE tenant_id=p_tenant AND id=(item->>'advance')::uuid FOR UPDATE;
   IF h.employer_id IS DISTINCT FROM r.employer_id OR h.employment_id::text IS DISTINCT FROM e->>'employment_id' OR h.status<>'active' OR h.revision::text IS DISTINCT FROM item->>'revision' OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.input_manifest->'advances')s WHERE s=item-'consumed_amount') OR(item->>'consumed_amount')::numeric<=0 OR(item->>'consumed_amount')::numeric>(item->>'outstanding')::numeric OR(item->>'consumed_amount') IS DISTINCT FROM item->'allowance'->>'amount' OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(e->'lines')l WHERE l->>'component'='advance:'||(item->>'installment') AND l->>'classification'='deduction' AND(l->>'amount')::numeric=(item->>'consumed_amount')::numeric) THEN RAISE EXCEPTION 'finance_consumption_stale' USING ERRCODE='23514';END IF;
   remaining:=payroll.installment_remaining(p_tenant,(item->>'installment')::uuid);
   IF am.amendment_of IS NOT NULL THEN remaining:=remaining+COALESCE((SELECT sum(a.amount) FROM payroll.advance_allocations a JOIN payroll.advance_events v ON v.tenant_id=a.tenant_id AND v.id=a.event_id WHERE a.tenant_id=p_tenant AND a.installment_id=(item->>'installment')::uuid AND v.output_id=am.amendment_of),0);END IF;
   IF(item->>'consumed_amount')::numeric>remaining THEN RAISE EXCEPTION 'finance_consumption_stale' USING ERRCODE='23514';END IF;
  END LOOP;
 END LOOP;
 output:=payroll.append_final_output_before_advances(p_tenant,p_run,p_candidate,p_actor,p_expected,p_attempt);
 IF am.amendment_of IS NOT NULL THEN
  FOR old IN SELECT * FROM payroll.advance_events WHERE tenant_id=p_tenant AND output_id=am.amendment_of AND kind='payroll_deduction' ORDER BY advance_id,id LOOP
   IF EXISTS(SELECT 1 FROM payroll.advance_events WHERE tenant_id=p_tenant AND original_event=old.id) THEN RAISE EXCEPTION 'finance_original_already_replaced' USING ERRCODE='23514';END IF;
   INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,original_event,output_id,actor_id) VALUES(p_tenant,old.advance_id,'compensation',-old.delta,(c.input_manifest->'period'->>'ends_on')::date,output::text,'استبدال مسير لم يسبق دفعه؛ الأصل محفوظ',old.id,output,p_actor) RETURNING id INTO event;
   INSERT INTO payroll.advance_allocations SELECT tenant_id,advance_id,event,installment_id,-amount FROM payroll.advance_allocations WHERE tenant_id=p_tenant AND event_id=old.id;
   UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND id=old.advance_id;
  END LOOP;
 END IF;
 FOR e IN SELECT value FROM jsonb_array_elements(c.output->'employees') LOOP
  FOR item IN SELECT value FROM jsonb_array_elements(COALESCE(e->'advance_deductions','[]')) LOOP
   INSERT INTO payroll.advance_events(tenant_id,advance_id,kind,delta,occurred_on,reference,reason,output_id,installment_id,actor_id) VALUES(p_tenant,(item->>'advance')::uuid,'payroll_deduction',-(item->>'consumed_amount')::numeric,(c.input_manifest->'period'->>'ends_on')::date,output::text,'قسط مقفل وفق أساس خصم مؤهل محفوظ',output,(item->>'installment')::uuid,p_actor) RETURNING id INTO event;
   INSERT INTO payroll.advance_allocations VALUES(p_tenant,(item->>'advance')::uuid,event,(item->>'installment')::uuid,(item->>'consumed_amount')::numeric);
   UPDATE payroll.advance_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND id=(item->>'advance')::uuid;
  END LOOP;
 END LOOP;
 IF EXISTS(SELECT 1 FROM payroll.advance_heads h WHERE h.tenant_id=p_tenant AND h.employer_id=r.employer_id AND payroll.advance_balance(p_tenant,h.id)<0) THEN RAISE EXCEPTION 'finance_negative_balance' USING ERRCODE='23514';END IF;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,r.employer_id,p_actor,'advance_locked_consumption',jsonb_build_object('output',output,'candidate',p_candidate));
 RETURN output;
END $f$;

CREATE FUNCTION public.payroll_advance_choices(p_tenant uuid,p_employer uuid,p_kind text,p_query text DEFAULT '',p_after uuid DEFAULT NULL,p_selected uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE items jsonb;selected jsonb;BEGIN
 PERFORM payroll.advance_authorized(p_tenant,'view');
 IF p_kind NOT IN('employers','employments','periods') OR p_query IS NULL OR length(p_query)>120 THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 IF p_kind='employers' THEN
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') INTO items FROM(SELECT id,display_name AS name FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND is_active AND(p_after IS NULL OR id>p_after) AND display_name ILIKE '%'||p_query||'%' ORDER BY id LIMIT 30)x;
  SELECT jsonb_build_object('id',id,'name',display_name) INTO selected FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_selected;
 ELSIF p_kind='employments' THEN
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') INTO items FROM(SELECT h.id,e.full_name AS name,e.employee_code AS code,h.start_date,h.end_date FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND(p_after IS NULL OR h.id>p_after) AND(e.full_name ILIKE '%'||p_query||'%' OR e.employee_code ILIKE '%'||p_query||'%') ORDER BY h.id LIMIT 30)x;
  SELECT jsonb_build_object('id',h.id,'name',e.full_name,'code',e.employee_code,'start_date',h.start_date,'end_date',h.end_date) INTO selected FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.id=p_selected;
 ELSE
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') INTO items FROM(SELECT id,label AS name,starts_on,ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND(p_after IS NULL OR id>p_after) AND(label ILIKE '%'||p_query||'%' OR starts_on::text ILIKE '%'||p_query||'%') ORDER BY id LIMIT 30)x;
  SELECT jsonb_build_object('id',id,'name',label,'starts_on',starts_on,'ends_on',ends_on) INTO selected FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_selected;
 END IF;
 IF p_selected IS NOT NULL AND selected IS NULL THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('items',items,'selected',selected,'next',CASE WHEN jsonb_array_length(items)=30 THEN items->29->>'id' END);
END $f$;
CREATE FUNCTION public.payroll_advance_workspace(p_tenant uuid,p_employer uuid,p_advance uuid DEFAULT NULL,p_query text DEFAULT '',p_after uuid DEFAULT NULL,p_installment_after integer DEFAULT 0,p_history_before uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;items jsonb;detail jsonb;h payroll.advance_heads%ROWTYPE;v payroll.advance_versions%ROWTYPE;schedule jsonb;history jsonb;cursor_time timestamptz;access jsonb;BEGIN
 a:=payroll.advance_authorized(p_tenant,'view');
 IF p_query IS NULL OR length(p_query)>120 OR p_installment_after IS NULL OR p_installment_after<0 OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer) THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 access:=jsonb_build_object('can_manage',platform_private.has_tenant_permission(p_tenant,a,'employee_finance.manage'),'can_approve',platform_private.has_tenant_permission(p_tenant,a,'employee_finance.approve'),'can_correct_payroll',platform_private.has_tenant_permission(p_tenant,a,'payroll.correct'),'can_view_final',platform_private.has_tenant_permission(p_tenant,a,'payroll.view'),'can_review_payroll',platform_private.has_tenant_permission(p_tenant,a,'payroll.view') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.prepare') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.review') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.approve'),'enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.employee_finance',clock_timestamp()));
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') INTO items FROM(SELECT h.id,h.employment_id,h.revision,e.full_name AS name,e.employee_code AS code,v.principal::text,
 payroll.advance_status(p_tenant,h.id) AS status,payroll.advance_balance(p_tenant,h.id)::text AS outstanding,
 (SELECT jsonb_build_object('id',i.id,'amount',payroll.installment_remaining(p_tenant,i.id)::text,'starts_on',p.starts_on) FROM payroll.advance_installments i JOIN payroll.periods p ON p.tenant_id=i.tenant_id AND p.id=COALESCE((SELECT x.target_period FROM payroll.advance_deferrals x WHERE x.tenant_id=i.tenant_id AND x.installment_id=i.id ORDER BY revision DESC LIMIT 1),i.period_id) WHERE i.tenant_id=h.tenant_id AND i.version_id=h.version_id AND payroll.advance_balance(p_tenant,h.id)>0 AND payroll.installment_remaining(p_tenant,i.id)>0 ORDER BY p.starts_on,i.ordinal LIMIT 1) AS next_installment
 FROM payroll.advance_heads h JOIN payroll.advance_versions v ON v.tenant_id=h.tenant_id AND v.id=h.version_id JOIN people.employments emp ON emp.tenant_id=h.tenant_id AND emp.id=h.employment_id JOIN people.employees e ON e.tenant_id=emp.tenant_id AND e.id=emp.employee_id WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND(p_after IS NULL OR h.id>p_after) AND(e.full_name ILIKE '%'||p_query||'%' OR e.employee_code ILIKE '%'||p_query||'%') ORDER BY h.id LIMIT 30)x;
 IF p_advance IS NOT NULL THEN
  SELECT * INTO h FROM payroll.advance_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_advance;
  IF h.id IS NULL THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501';END IF;
  SELECT * INTO v FROM payroll.advance_versions WHERE tenant_id=p_tenant AND id=h.version_id;
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY ordinal),'[]') INTO schedule FROM(SELECT i.id,i.ordinal,i.amount::text,payroll.installment_remaining(p_tenant,i.id)::text AS remaining,p.id AS period_id,p.starts_on,p.ends_on,
   EXISTS(SELECT 1 FROM payroll.advance_deferrals x WHERE x.tenant_id=i.tenant_id AND x.installment_id=i.id) AS deferred FROM payroll.advance_installments i JOIN payroll.periods p ON p.tenant_id=i.tenant_id AND p.id=COALESCE((SELECT x.target_period FROM payroll.advance_deferrals x WHERE x.tenant_id=i.tenant_id AND x.installment_id=i.id ORDER BY x.revision DESC LIMIT 1),i.period_id) WHERE i.tenant_id=p_tenant AND i.version_id=h.version_id AND i.ordinal>p_installment_after ORDER BY i.ordinal LIMIT 30)x;
  IF p_history_before IS NOT NULL THEN SELECT created_at INTO cursor_time FROM payroll.advance_events WHERE tenant_id=p_tenant AND advance_id=h.id AND id=p_history_before;IF NOT FOUND THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501';END IF;END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY created_at DESC,id DESC),'[]') INTO history FROM(SELECT e.id,e.kind,e.delta::text,e.occurred_on,e.reference,e.reason,e.original_event,e.output_id,e.correction_case,e.created_at,EXISTS(SELECT 1 FROM payroll.advance_events c WHERE c.tenant_id=e.tenant_id AND c.original_event=e.id) AS compensated FROM payroll.advance_events e WHERE e.tenant_id=p_tenant AND e.advance_id=h.id AND(p_history_before IS NULL OR(e.created_at,e.id)<(cursor_time,p_history_before)) ORDER BY e.created_at DESC,e.id DESC LIMIT 20)x;
  detail:=to_jsonb(h)||jsonb_build_object('version',to_jsonb(v),'name',(SELECT full_name FROM people.employees e JOIN people.employments emp ON emp.tenant_id=e.tenant_id AND emp.employee_id=e.id WHERE emp.tenant_id=p_tenant AND emp.id=h.employment_id),'outstanding',payroll.advance_balance(p_tenant,h.id)::text,'status',payroll.advance_status(p_tenant,h.id),'termination_on',(SELECT end_date FROM people.employments WHERE tenant_id=p_tenant AND id=h.employment_id),'next_installment',(SELECT jsonb_build_object('amount',payroll.installment_remaining(p_tenant,i.id)::text,'starts_on',p.starts_on) FROM payroll.advance_installments i JOIN payroll.periods p ON p.tenant_id=i.tenant_id AND p.id=COALESCE((SELECT x.target_period FROM payroll.advance_deferrals x WHERE x.tenant_id=i.tenant_id AND x.installment_id=i.id ORDER BY x.revision DESC LIMIT 1),i.period_id) WHERE i.tenant_id=p_tenant AND i.version_id=h.version_id AND payroll.advance_balance(p_tenant,h.id)>0 AND payroll.installment_remaining(p_tenant,i.id)>0 ORDER BY p.starts_on,i.ordinal LIMIT 1),'schedule',schedule,'history',history);
 END IF;
 RETURN jsonb_build_object('access',access,'employer',(SELECT jsonb_build_object('id',id,'name',display_name) FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer),'items',items,'detail',detail,'next',CASE WHEN jsonb_array_length(items)=30 THEN items->29->>'id' END,'today',(clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date);
END $f$;
-- Every added private helper is inaccessible to ordinary callers; no automatic permissions or grants.
DO $f$ DECLARE fn record;BEGIN
 FOR fn IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='payroll' AND p.proname IN('advance_authorized','lock_advance_scope','advance_balance','advance_status','installment_remaining','advance_intent_authority','advance_sources','run_manifest_before_advances','amendment_manifest_before_advances','stale_reasons_before_advances','build_review_before_advances','append_final_output_before_advances','append_final_output_single','run_manifest','amendment_manifest','stale_reasons','build_review') LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',fn.signature);END LOOP;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_advance_command(uuid,uuid,jsonb,uuid),public.payroll_resolve_advance_attempt(uuid,uuid,jsonb,uuid),public.payroll_advance_choices(uuid,uuid,text,text,uuid,uuid),public.payroll_advance_workspace(uuid,uuid,uuid,text,uuid,integer,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_advance_command(uuid,uuid,jsonb,uuid),public.payroll_resolve_advance_attempt(uuid,uuid,jsonb,uuid),public.payroll_advance_choices(uuid,uuid,text,text,uuid,uuid),public.payroll_advance_workspace(uuid,uuid,uuid,text,uuid,integer,uuid) TO authenticated;

DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 IF position('''cube4-review-v2-exact'',manifest,output,a' IN d)=0 THEN RAISE EXCEPTION 'unexpected_advance_candidate_engine_anchor';END IF;
 EXECUTE replace(d,'''cube4-review-v2-exact'',manifest,output,a','manifest->>''engine'',manifest,output,a');
END $f$;






-- A Finance approver with correction authority sees only attributable reviewed responsibilities,
-- never the case's People proposal, statutory result or Payroll net.
CREATE FUNCTION public.payroll_advance_correction_choices(p_tenant uuid,p_employer uuid,p_advance uuid,p_event uuid,p_query text DEFAULT '',p_after uuid DEFAULT NULL,p_selected uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE h payroll.advance_heads%ROWTYPE;event payroll.advance_events%ROWTYPE;items jsonb;selected jsonb;BEGIN
 PERFORM payroll.advance_authorized(p_tenant,'correct_deduction');PERFORM payroll.lock_source_scope(p_tenant);PERFORM payroll.advance_authorized(p_tenant,'correct_deduction');
 IF p_query IS NULL OR length(p_query)>120 THEN RAISE EXCEPTION 'finance_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO h FROM payroll.advance_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_advance;
 SELECT * INTO event FROM payroll.advance_events WHERE tenant_id=p_tenant AND advance_id=p_advance AND id=p_event AND kind='payroll_deduction';
 IF h.id IS NULL OR event.id IS NULL OR NOT payroll.output_has_ever_paid(p_tenant,event.output_id) THEN RAISE EXCEPTION 'finance_governed_correction_required' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM payroll.advance_events WHERE tenant_id=p_tenant AND original_event=event.id) THEN RETURN jsonb_build_object('items','[]'::jsonb,'selected',NULL,'next',NULL,'already_compensated',true,'event',jsonb_build_object('reference',event.reference,'amount',(-event.delta)::text,'occurred_on',event.occurred_on));END IF;
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') INTO items FROM(SELECT c.id,p.reference AS name,p.reason FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id WHERE c.tenant_id=p_tenant AND c.employer_id=p_employer AND c.original_output=event.output_id AND c.status IN('routed','completed') AND(p_after IS NULL OR c.id>p_after) AND(p.reference ILIKE '%'||p_query||'%' OR p.reason ILIKE '%'||p_query||'%') AND EXISTS(SELECT 1 FROM jsonb_array_elements(p.responsibilities)r WHERE r->>'employment_id'=h.employment_id::text AND r->>'output_id'=event.output_id::text AND r->>'basis'='external_reviewed' AND (r->>'amount')::numeric=-event.delta) ORDER BY c.id LIMIT 30)x;
 IF p_selected IS NOT NULL THEN
  SELECT jsonb_build_object('id',c.id,'name',p.reference,'reason',p.reason) INTO selected FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id WHERE c.tenant_id=p_tenant AND c.employer_id=p_employer AND c.original_output=event.output_id AND c.id=p_selected AND c.status IN('routed','completed') AND EXISTS(SELECT 1 FROM jsonb_array_elements(p.responsibilities)r WHERE r->>'employment_id'=h.employment_id::text AND r->>'output_id'=event.output_id::text AND r->>'basis'='external_reviewed' AND (r->>'amount')::numeric=-event.delta);
  IF selected IS NULL THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501';END IF;
 END IF;
 RETURN jsonb_build_object('items',items,'selected',selected,'next',CASE WHEN jsonb_array_length(items)=30 THEN items->29->>'id' END,'event',jsonb_build_object('reference',event.reference,'amount',(-event.delta)::text,'occurred_on',event.occurred_on));
END $f$;
REVOKE ALL ON FUNCTION public.payroll_advance_correction_choices(uuid,uuid,uuid,uuid,text,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_advance_correction_choices(uuid,uuid,uuid,uuid,text,uuid,uuid) TO authenticated;
