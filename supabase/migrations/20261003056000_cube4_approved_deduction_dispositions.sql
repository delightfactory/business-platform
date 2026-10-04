-- Bounded debt source approval and explicit residual disposition. Original
-- obligations are preserved; no silent clipping, cancellation or debt engine.
CREATE TABLE payroll.deduction_dispositions(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),
 period_id uuid NOT NULL,employment_id uuid NOT NULL,claim_key text NOT NULL,
 original_amount numeric(18,2) NOT NULL CHECK(original_amount>0),
 payroll_amount numeric(18,2) NOT NULL CHECK(payroll_amount>=0),
 residual_amount numeric(18,2) NOT NULL CHECK(residual_amount>0),
 disposition text NOT NULL CHECK(disposition IN('carry','external_settlement')),
 source_versions jsonb NOT NULL,target_head uuid,target_period uuid,occurred_on date,
 reference text NOT NULL,reason text NOT NULL,actor_id uuid NOT NULL,intent jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(tenant_id,id),
 CHECK(original_amount=payroll_amount+residual_amount),
 CHECK((disposition='carry')=(target_head IS NOT NULL AND target_period IS NOT NULL)),
 CHECK((disposition='external_settlement')=(occurred_on IS NOT NULL)),
 CHECK(occurred_on IS NULL OR isfinite(occurred_on)),
 CHECK(disposition<>'external_settlement' OR (target_head IS NULL AND target_period IS NULL)),
 FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id),
 FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id),
 FOREIGN KEY(tenant_id,target_head) REFERENCES payroll.input_heads(tenant_id,id));
ALTER TABLE payroll.deduction_dispositions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.deduction_dispositions FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION payroll.guard_deduction_disposition() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'payroll_immutable_disposition' USING ERRCODE='55000';END$$;
CREATE TRIGGER deduction_disposition_immutable BEFORE UPDATE OR DELETE ON payroll.deduction_dispositions
 FOR EACH ROW EXECUTE FUNCTION payroll.guard_deduction_disposition();
REVOKE ALL ON FUNCTION payroll.guard_deduction_disposition() FROM PUBLIC,anon,authenticated,service_role;

-- Retractions are append-only and allowed only before financial consumption.
CREATE TABLE payroll.deduction_disposition_retractions(
 tenant_id uuid NOT NULL,disposition_id uuid NOT NULL,actor_id uuid NOT NULL,reference text NOT NULL,reason text NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(tenant_id,disposition_id),FOREIGN KEY(tenant_id,disposition_id) REFERENCES payroll.deduction_dispositions(tenant_id,id));
ALTER TABLE payroll.deduction_disposition_retractions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.deduction_disposition_retractions FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER deduction_disposition_retraction_immutable BEFORE UPDATE OR DELETE ON payroll.deduction_disposition_retractions FOR EACH ROW EXECUTE FUNCTION payroll.guard_deduction_disposition();
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.validate_input(text,jsonb)'::regprocedure);
 anchor:=' IF p_kind=''adjustment'' THEN keys:=keys||ARRAY[''deduction_category'',''consent_reference''];END IF;';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_recurring_debt_keys';END IF;
 definition:=replace(definition,anchor,anchor||' IF p_kind=''recurring'' THEN keys:=keys||ARRAY[''deduction_category'',''consent_reference'',''reference'',''carry_component_id''];END IF;');
 anchor:='p_kind<>''adjustment'' OR coalesce(p_data->>''deduction_category''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_recurring_debt_validation';END IF;
 EXECUTE replace(definition,anchor,'p_kind NOT IN(''adjustment'',''recurring'') OR coalesce(p_data->>''deduction_category''');
END $patch$;

ALTER FUNCTION public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)
 RENAME TO payroll_save_input_before_recurring_debts;
CREATE FUNCTION public.payroll_save_input(p_tenant uuid,p_employer uuid,p_kind text,p_employment uuid,p_period uuid,p_head uuid,p_expected integer,p_from date,p_until date,p_data jsonb,p_operation text,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;component jsonb;component_until date;head payroll.input_heads;version payroll.input_versions;receipt payroll.command_receipts;intent jsonb;result jsonb;
BEGIN
 IF p_kind<>'recurring' OR p_kind IS NULL THEN
  RETURN public.payroll_save_input_before_recurring_debts(p_tenant,p_employer,p_kind,p_employment,p_period,p_head,p_expected,p_from,p_until,p_data,p_operation,p_attempt);END IF;
 PERFORM payroll.authorized(p_tenant,'payroll.prepare',true);
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 SELECT v.data,v.effective_until INTO component,component_until FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id
  WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.kind='component' AND h.id=(p_data->>'component_id')::uuid
   AND v.effective_from<=p_from ORDER BY v.effective_from DESC,v.revision DESC LIMIT 1;
 IF component->>'classification' IS DISTINCT FROM 'deduction' THEN
  IF p_data ?| ARRAY['deduction_category','consent_reference','reference','carry_component_id'] THEN RAISE EXCEPTION 'payroll_deduction_source_invalid' USING ERRCODE='22023';END IF;
  RETURN public.payroll_save_input_before_recurring_debts(p_tenant,p_employer,p_kind,p_employment,p_period,p_head,p_expected,p_from,p_until,p_data,p_operation,p_attempt);END IF;
 a:=payroll.authorized(p_tenant,CASE WHEN p_operation='approve' THEN 'employee_finance.approve' ELSE 'employee_finance.manage' END,true);
 IF (component_until IS NOT NULL AND component_until<=p_from) OR component->>'active' IS DISTINCT FROM 'true' OR component->>'behavior' IS DISTINCT FROM 'recurring' THEN RAISE EXCEPTION 'payroll_component_unavailable' USING ERRCODE='22023';END IF;
 PERFORM payroll.validate_input(p_kind,p_data);
 IF NOT(p_data ?& ARRAY['deduction_category','reference']) THEN RAISE EXCEPTION 'payroll_deduction_source_invalid' USING ERRCODE='22023';END IF;
 IF p_operation<>'approve' THEN RETURN public.payroll_save_input_before_recurring_debts(p_tenant,p_employer,p_kind,p_employment,p_period,p_head,p_expected,p_from,p_until,p_data,p_operation,p_attempt);END IF;
 IF p_attempt IS NULL OR p_period IS NOT NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 intent:=jsonb_build_object('operation','recurring_debt_approve','employer',p_employer,'head',p_head,'expected',p_expected,'employment',p_employment,'from',p_from,'until',p_until,'data',p_data);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO head FROM payroll.input_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_head FOR UPDATE;
 SELECT * INTO version FROM payroll.input_versions WHERE tenant_id=p_tenant AND head_id=p_head AND revision=head.revision;
 IF head.id IS NULL OR head.kind<>'recurring' OR head.employment_id IS DISTINCT FROM p_employment THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF head.revision IS DISTINCT FROM p_expected OR version.status<>'draft' OR version.data-'component_interpretation' IS DISTINCT FROM p_data OR version.effective_from<>p_from OR version.effective_until IS DISTINCT FROM p_until THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409';END IF;
 IF EXISTS(SELECT 1 FROM payroll.people_frozen_contexts f JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id
  WHERE f.tenant_id=p_tenant AND f.employment_id=p_employment AND daterange(p.starts_on,p.ends_on,'[]')&&daterange(p_from,p_until,'[)')) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514';END IF;
 INSERT INTO payroll.input_versions(tenant_id,employer_id,head_id,revision,data,effective_from,effective_until,status,created_by,approved_by,approved_at)
 VALUES(p_tenant,p_employer,p_head,p_expected+1,version.data,p_from,p_until,'approved',a,a,clock_timestamp());
 UPDATE payroll.input_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND id=p_head;
 result:=jsonb_build_object('id',p_head,'revision',p_expected+1,'status','approved');
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'recurring_debt_approve',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'employee_finance.approve',true);PERFORM payroll.authorized(p_tenant,'payroll.prepare',true);RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_save_input_before_recurring_debts(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid) TO authenticated;

CREATE FUNCTION payroll.recurring_debt_source(p_manifest jsonb,p_employee jsonb,p_line jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE part jsonb;source jsonb;data jsonb;previous_data jsonb;heads uuid[]:='{}';versions jsonb:='[]';hid uuid;matches integer;
BEGIN
 FOR part IN SELECT value FROM jsonb_array_elements(p_line->'details') LOOP
  SELECT count(*),jsonb_agg(value)->0 INTO matches,source FROM jsonb_array_elements(payroll.manifest_recurring(p_manifest,(p_employee->>'employment_id')::uuid,(p_line->>'component')::uuid,(part->>'date')::date));
  data:=source->'version'->'data';hid:=(source->'head'->>'id')::uuid;
  IF matches<>1 OR source->'version'->>'status' IS DISTINCT FROM 'approved' OR NOT(data ?& ARRAY['deduction_category','reference']) THEN RAISE EXCEPTION 'payroll_deduction_approval_required' USING ERRCODE='22023';END IF;
  IF previous_data IS NOT NULL AND (data-ARRAY['value','reason','component_id']) IS DISTINCT FROM previous_data THEN RAISE EXCEPTION 'payroll_deduction_source_allocation_required' USING ERRCODE='22023';END IF;
  previous_data:=data-ARRAY['value','reason','component_id'];
  IF NOT hid=ANY(heads) THEN heads:=array_append(heads,hid);END IF;
  IF NOT versions @> jsonb_build_array(source->'version'->'id') THEN versions:=versions||jsonb_build_array(source->'version'->'id');END IF;
 END LOOP;
 IF array_length(heads,1) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'payroll_deduction_source_allocation_required' USING ERRCODE='22023';END IF;
 RETURN jsonb_build_object('source_head',heads[1],'source_versions',versions,'data',data);
END $f$;
REVOKE ALL ON FUNCTION payroll.recurring_debt_source(jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

-- The builder first validates the full approved source. Only an explicitly
-- approved, captured disposition can replace this period's recovered amount.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_reviewed_wage_deductions(jsonb,jsonb)'::regprocedure);
 anchor:='amount numeric;total numeric:=0;';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_debt_variables';END IF;
 definition:=replace(definition,anchor,'disposition jsonb;source_versions jsonb;claim_key text;deduction_lines jsonb:=''[]'';source_heads jsonb:=''{}'';'||anchor);
 anchor:='  IF line->>''component'' NOT LIKE ''adjustment:%'' THEN RAISE EXCEPTION ''payroll_deduction_approval_required'' USING ERRCODE=''22023'';END IF;';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_recurring_debt_branch';END IF;
 definition:=replace(definition,anchor,$insert$
  IF line->>'component' NOT LIKE 'adjustment:%' THEN
   source:=payroll.recurring_debt_source(p_manifest,p_employee,line);data:=source->'data';amount:=(line->>'amount')::numeric;
   claim_key:='recurring:'||(line->>'component');source_versions:=source->'source_versions';
  ELSE
$insert$);
 anchor:='  claims:=claims||jsonb_build_array';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_debt_claim_add';END IF;
 definition:=replace(definition,anchor,$insert$
  claim_key:=source->'head'->>'id';source_versions:=jsonb_build_array(source->'version'->'id');
  source:=source||jsonb_build_object('source_head',source->'head'->'id');
  END IF;
  source_heads:=source_heads||jsonb_build_object(claim_key,jsonb_build_object('source_head',source->'source_head','source_versions',source_versions));
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_manifest->'deduction_carry_origins','[]')) origin WHERE origin->>'target_head'=claim_key AND origin->>'final_output' IS NULL) THEN RAISE EXCEPTION 'payroll_carry_source_unfinalized' USING ERRCODE='22023';END IF;
  SELECT value INTO disposition FROM jsonb_array_elements(coalesce(p_manifest->'deduction_dispositions','[]'))
   WHERE value->>'employment_id'=employment::text AND value->>'claim_key'=claim_key;
  IF disposition IS NOT NULL THEN
   IF (disposition->>'original_amount')::numeric<>amount OR disposition->'source_versions' IS DISTINCT FROM source_versions THEN RAISE EXCEPTION 'payroll_deduction_disposition_stale' USING ERRCODE='22023';END IF;
   IF disposition->>'disposition'='carry' AND (disposition->'target_source'->>'status' IS DISTINCT FROM 'approved' OR (disposition->'target_source'->'data'->>'amount')::numeric IS DISTINCT FROM (disposition->>'residual_amount')::numeric) THEN RAISE EXCEPTION 'payroll_deduction_disposition_stale' USING ERRCODE='22023';END IF;
   amount:=(disposition->>'payroll_amount')::numeric;
   line:=line||jsonb_build_object('amount',amount::text,'deduction_disposition',disposition,'original_approved_amount',disposition->'original_amount');
  END IF;
  deduction_lines:=deduction_lines||jsonb_build_array(line);
  IF amount>0 THEN
  claims:=claims||jsonb_build_array$insert$);
 definition:=replace(definition,'''id'',source->''head''->>''id'',''amount'',amount,','''id'',claim_key,''amount'',amount,');
 anchor:='  total:=total+amount;';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_debt_total';END IF;
 definition:=replace(definition,anchor,'  END IF;'||anchor);
 anchor:=' IF plan->>''ready'' IS DISTINCT FROM ''true'' THEN';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_debt_plan';END IF;
 definition:=replace(definition,anchor,$insert$
 plan:=jsonb_set(plan,'{claims}',coalesce((SELECT jsonb_agg(value||(source_heads->(value->>'id'))) FROM jsonb_array_elements(plan->'claims')),'[]'));
 IF plan->>'ready' IS DISTINCT FROM 'true' THEN$insert$);
 anchor:='FOR claim IN SELECT value FROM jsonb_array_elements(p_employee->''lines'') WHERE value->>''classification''=''deduction'' AND value->>''component'' NOT LIKE ''advance:%'' LOOP';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_debt_final_lines';END IF;
 EXECUTE replace(definition,anchor,'FOR claim IN SELECT value FROM jsonb_array_elements(deduction_lines) LOOP');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_disposition_manifest';END IF;
 EXECUTE replace(definition,anchor,$insert$
 m:=m||jsonb_build_object(
  'deduction_dispositions',coalesce((SELECT jsonb_agg(to_jsonb(d)||jsonb_build_object('target_source',(SELECT to_jsonb(v) FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id=d.tenant_id AND h.id=d.target_head)) ORDER BY d.id) FROM payroll.deduction_dispositions d WHERE d.tenant_id=p_tenant AND d.employer_id=p_employer AND d.period_id=p_period AND NOT EXISTS(SELECT 1 FROM payroll.deduction_disposition_retractions x WHERE x.tenant_id=d.tenant_id AND x.disposition_id=d.id)),'[]'),
  'deduction_carry_origins',coalesce((SELECT jsonb_agg(jsonb_build_object('target_head',d.target_head,'disposition',d.id,'period_id',d.period_id,'final_output',(SELECT f.id FROM payroll.final_contexts f WHERE f.tenant_id=d.tenant_id AND f.period_id=d.period_id AND EXISTS(SELECT 1 FROM jsonb_array_elements(f.manifest->'deduction_dispositions') v WHERE v->>'id'=d.id::text) ORDER BY f.finalized_at DESC LIMIT 1)) ORDER BY d.id) FROM payroll.deduction_dispositions d WHERE d.tenant_id=p_tenant AND d.employer_id=p_employer AND d.target_period=p_period AND NOT EXISTS(SELECT 1 FROM payroll.deduction_disposition_retractions x WHERE x.tenant_id=d.tenant_id AND x.disposition_id=d.id)),'[]'),
  'engine',(m->>'engine')||'-approved-debt-dispositions-v1');
$insert$||anchor);
END $patch$;
-- Only an exact captured, conserved split can consume the original approved
-- adjustment. Its raw input evidence and original amount remain immutable.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.contributed_adjustment_versions(jsonb,jsonb)'::regprocedure);
 anchor:='AND(l->>''amount'')::numeric=(i->''version''->''data''->>''amount'')::numeric';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_disposition_consumption';END IF;
 EXECUTE replace(definition,anchor,$insert$
 AND ((l->>'amount')::numeric=(i->'version'->'data'->>'amount')::numeric OR EXISTS(
  SELECT 1 FROM jsonb_array_elements(coalesce(p_manifest->'deduction_dispositions','[]')) split
  WHERE l->'deduction_disposition'=split AND split->>'tenant_id'=i->'version'->>'tenant_id'
   AND split->>'employer_id'=i->'version'->>'employer_id'
   AND split->>'period_id'=p_manifest->'period'->>'id'
   AND split->>'employment_id'=e->>'employment_id' AND split->>'claim_key'=i->'head'->>'id'
   AND split->'source_versions'=jsonb_build_array(i->'version'->'id')
   AND (split->>'original_amount')::numeric=(i->'version'->'data'->>'amount')::numeric
   AND (split->>'payroll_amount')::numeric=(l->>'amount')::numeric
   AND (split->>'original_amount')::numeric=(split->>'payroll_amount')::numeric+(split->>'residual_amount')::numeric
   AND (split->>'residual_amount')::numeric>0))$insert$);
END $patch$;
ALTER FUNCTION payroll.stale_reasons(jsonb,jsonb) RENAME TO stale_reasons_before_debt_dispositions;
CREATE FUNCTION payroll.stale_reasons(p_old jsonb,p_current jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT payroll.stale_reasons_before_debt_dispositions(p_old,p_current)||CASE WHEN p_old->'deduction_carry_origins' IS DISTINCT FROM p_current->'deduction_carry_origins' THEN '["deduction_carry_origins_changed"]'::jsonb ELSE '[]'::jsonb END||CASE WHEN p_old->'deduction_dispositions' IS DISTINCT FROM p_current->'deduction_dispositions' THEN '["deduction_dispositions_changed"]'::jsonb ELSE '[]'::jsonb END
$$;
REVOKE ALL ON FUNCTION payroll.stale_reasons(jsonb,jsonb),payroll.stale_reasons_before_debt_dispositions(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.payroll_deduction_disposition(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_candidate uuid,p_revision integer,p_employment uuid,p_claim text,p_payroll_amount numeric,p_disposition text,p_target_period uuid,p_occurred_on date,p_reference text,p_reason text,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;run payroll.runs;candidate payroll.candidates;period payroll.periods;target payroll.periods;source payroll.input_versions;
 receipt payroll.command_receipts;stored payroll.deduction_dispositions;carry_component payroll.input_versions;carry_component_id uuid;employee jsonb;claim jsonb;data jsonb;head jsonb;approved jsonb;intent jsonb;result jsonb;residual numeric;
BEGIN
 a:=payroll.authorized(p_tenant,'employee_finance.approve',true);PERFORM payroll.authorized(p_tenant,'employee_finance.manage',true);
 IF p_disposition='external_settlement' THEN PERFORM payroll.authorized(p_tenant,'payroll.payment_record',true);END IF;
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 a:=payroll.authorized(p_tenant,'employee_finance.approve',true);
 IF p_attempt IS NULL OR p_claim IS NULL OR length(p_claim) NOT BETWEEN 36 AND 80 OR p_disposition IS NULL OR p_disposition NOT IN('carry','external_settlement') OR p_payroll_amount IS NULL OR p_payroll_amount<0 OR p_payroll_amount<>round(p_payroll_amount,2)
  OR p_reference IS NULL OR p_reason IS NULL OR length(btrim(p_reference)) NOT BETWEEN 3 AND 160 OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 intent:=jsonb_build_object('operation','deduction_disposition','employer',p_employer,'period',p_period,'run',p_run,'candidate',p_candidate,'revision',p_revision,'employment',p_employment,'claim',p_claim,'payroll_amount',p_payroll_amount,'disposition',p_disposition,'target_period',p_target_period,'occurred_on',p_occurred_on,'reference',btrim(p_reference),'reason',btrim(p_reason));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO stored FROM payroll.deduction_dispositions WHERE tenant_id=p_tenant AND period_id=p_period AND employment_id=p_employment AND claim_key=p_claim AND NOT EXISTS(SELECT 1 FROM payroll.deduction_disposition_retractions x WHERE x.tenant_id=deduction_dispositions.tenant_id AND x.disposition_id=deduction_dispositions.id);
 IF FOUND THEN RAISE EXCEPTION 'payroll_disposition_already_approved' USING ERRCODE='PT409';END IF;
 SELECT * INTO run FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_run FOR UPDATE;
 SELECT * INTO candidate FROM payroll.candidates WHERE tenant_id=p_tenant AND run_id=p_run AND id=p_candidate;
 IF run.id IS NULL OR run.status<>'review' OR run.revision IS DISTINCT FROM p_revision OR run.candidate_id IS DISTINCT FROM p_candidate OR candidate.id IS NULL THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409';END IF;
 IF payroll.stale_reasons(candidate.input_manifest,payroll.run_manifest(p_tenant,p_employer,p_period))<>'[]'::jsonb THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409';END IF;
 SELECT value INTO employee FROM jsonb_array_elements(candidate.output->'employees') WHERE value->>'employment_id'=p_employment::text;
 SELECT value INTO claim FROM jsonb_array_elements(employee->'deduction_plan'->'claims') WHERE value->>'id'=p_claim;
 IF claim IS NULL OR claim->>'source_head' IS NULL OR p_payroll_amount>(claim->>'capacity_amount')::numeric THEN RAISE EXCEPTION 'payroll_deduction_capacity_disposition_required' USING ERRCODE='22023';END IF;
 residual:=(claim->>'amount')::numeric-p_payroll_amount;IF residual<=0 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 SELECT * INTO source FROM payroll.input_versions WHERE tenant_id=p_tenant AND head_id=(claim->>'source_head')::uuid AND id=(claim->'source_versions'->>0)::uuid;
 IF source.id IS NULL OR source.status<>'approved' THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409';END IF;
 IF p_disposition='carry' THEN
  IF p_occurred_on IS NOT NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
  SELECT * INTO target FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_target_period;
  IF target.id IS NULL OR target.starts_on<=period.ends_on OR EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND period_id=target.id) THEN RAISE EXCEPTION 'payroll_carry_target_invalid' USING ERRCODE='22023';END IF;
  -- A recurring debt uses the corresponding bounded one-time deduction catalog
  -- entry chosen in its approved source, never a generated policy/component.
  data:=source.data||jsonb_build_object('amount',residual::text,'reference',btrim(p_reference),'reason',btrim(p_reason));
  data:=data-'value'-'component_interpretation';
  IF p_claim LIKE 'recurring:%' THEN
   IF source.data->>'carry_component_id' IS NULL THEN RAISE EXCEPTION 'payroll_carry_component_required' USING ERRCODE='22023';END IF;
   data:=jsonb_set(data,'{component_id}',source.data->'carry_component_id');END IF;
  data:=data-'carry_component_id';
  carry_component_id:=(data->>'component_id')::uuid;
  SELECT v.* INTO carry_component FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id
   WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.kind='component' AND h.id=carry_component_id AND v.effective_from<=target.starts_on ORDER BY v.effective_from DESC,v.revision DESC LIMIT 1;
  IF carry_component.id IS NULL OR carry_component.status='cancelled' OR (carry_component.effective_until IS NOT NULL AND carry_component.effective_until<=target.starts_on)
   OR carry_component.data->>'active' IS DISTINCT FROM 'true' OR carry_component.data->>'classification' IS DISTINCT FROM 'deduction'
   OR carry_component.data->>'behavior' IS DISTINCT FROM 'period_input' OR carry_component.data->>'calculation' IS DISTINCT FROM 'fixed'
   THEN RAISE EXCEPTION 'payroll_carry_component_required' USING ERRCODE='22023';END IF;
  head:=public.payroll_save_input(p_tenant,p_employer,'adjustment',p_employment,target.id,NULL,0,target.starts_on,target.ends_on+1,data,'save',gen_random_uuid());
  approved:=public.payroll_save_input(p_tenant,p_employer,'adjustment',p_employment,target.id,(head->>'id')::uuid,1,target.starts_on,target.ends_on+1,data,'approve',gen_random_uuid());
 ELSE
  IF p_target_period IS NOT NULL OR p_occurred_on IS NULL OR NOT isfinite(p_occurred_on) OR p_occurred_on>(clock_timestamp() AT TIME ZONE period.timezone)::date THEN RAISE EXCEPTION 'payroll_payment_date_invalid' USING ERRCODE='22023';END IF;
 END IF;
 INSERT INTO payroll.deduction_dispositions(tenant_id,employer_id,period_id,employment_id,claim_key,original_amount,payroll_amount,residual_amount,disposition,source_versions,target_head,target_period,occurred_on,reference,reason,actor_id,intent)
 VALUES(p_tenant,p_employer,p_period,p_employment,p_claim,(claim->>'amount')::numeric,p_payroll_amount,residual,p_disposition,claim->'source_versions',(approved->>'id')::uuid,p_target_period,p_occurred_on,btrim(p_reference),btrim(p_reason),a,intent) RETURNING * INTO stored;
 result:=jsonb_build_object('id',stored.id,'target_head',stored.target_head,'original_amount',stored.original_amount,'payroll_amount',stored.payroll_amount,'residual_amount',stored.residual_amount,'disposition',stored.disposition,'requires_recalculation',true);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'deduction_disposition_approved',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'employee_finance.approve',true);PERFORM payroll.authorized(p_tenant,'employee_finance.manage',true);
 IF p_disposition='external_settlement' THEN PERFORM payroll.authorized(p_tenant,'payroll.payment_record',true);END IF;RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_deduction_disposition(uuid,uuid,uuid,uuid,uuid,integer,uuid,text,numeric,text,uuid,date,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_deduction_disposition(uuid,uuid,uuid,uuid,uuid,integer,uuid,text,numeric,text,uuid,date,text,text,uuid) TO authenticated;

-- Scoped read model and receipt recovery; browser persistence contains opaque IDs only.
CREATE FUNCTION public.payroll_deduction_workspace(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;period payroll.periods;permissions jsonb;choices jsonb;entries jsonb;
BEGIN
 a:=payroll.authorized(p_tenant,'payroll.review',false);
 SELECT * INTO period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF period.id IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 permissions:=jsonb_build_object('can_approve',platform_private.has_tenant_permission(p_tenant,a,'employee_finance.approve') AND platform_private.has_tenant_permission(p_tenant,a,'employee_finance.manage'),'can_external',platform_private.has_tenant_permission(p_tenant,a,'payroll.payment_record'));
 SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.starts_on),'[]') INTO choices FROM
  (SELECT id,starts_on,ends_on FROM payroll.periods p WHERE tenant_id=p_tenant AND employer_id=p_employer AND starts_on>period.ends_on
   AND NOT EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=p.tenant_id AND f.period_id=p.id) ORDER BY starts_on LIMIT 24)p;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.id,'employment',d.employment_id,'claim',d.claim_key,'original_amount',d.original_amount,'payroll_amount',d.payroll_amount,'residual_amount',d.residual_amount,'mode',d.disposition,'target_period',d.target_period,'date',d.occurred_on,'reference',d.reference,'reason',d.reason,'created_at',d.created_at,'retracted',EXISTS(SELECT 1 FROM payroll.deduction_disposition_retractions x WHERE x.tenant_id=d.tenant_id AND x.disposition_id=d.id)) ORDER BY d.created_at),'[]') INTO entries
  FROM payroll.deduction_dispositions d WHERE d.tenant_id=p_tenant AND d.employer_id=p_employer AND d.period_id=p_period;
 RETURN jsonb_build_object('access',permissions,'periods',choices,'dispositions',entries,'can_retract',NOT EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=p_tenant AND f.period_id=p_period),'today',(clock_timestamp() AT TIME ZONE period.timezone)::date);
END $f$;
CREATE FUNCTION public.payroll_deduction_reconcile(p_tenant uuid,p_employer uuid,p_period uuid,p_employment uuid,p_claim text,p_attempt uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;receipt payroll.command_receipts;
BEGIN
 a:=payroll.authorized(p_tenant,'employee_finance.approve',true);PERFORM payroll.authorized(p_tenant,'employee_finance.manage',true);
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 a:=payroll.authorized(p_tenant,'employee_finance.approve',true);
 IF p_attempt IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','not_committed');END IF;
 IF receipt.intent->>'operation' NOT IN('deduction_disposition','deduction_disposition_retract') OR receipt.intent->>'employer' IS DISTINCT FROM p_employer::text OR receipt.intent->>'period' IS DISTINCT FROM p_period::text OR receipt.intent->>'employment' IS DISTINCT FROM p_employment::text OR receipt.intent->>'claim' IS DISTINCT FROM p_claim THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
 IF receipt.intent->>'disposition'='external_settlement' THEN PERFORM payroll.authorized(p_tenant,'payroll.payment_record',true);END IF;
 RETURN jsonb_build_object('status','committed','result',receipt.result);
END $f$;
REVOKE ALL ON FUNCTION public.payroll_deduction_workspace(uuid,uuid,uuid),public.payroll_deduction_reconcile(uuid,uuid,uuid,uuid,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_deduction_workspace(uuid,uuid,uuid),public.payroll_deduction_reconcile(uuid,uuid,uuid,uuid,text,uuid) TO authenticated;

-- Finalization validates every approved disposition, including obligations whose
-- source was subsequently cancelled or became ineligible. A manifest entry by
-- itself never proves that an original obligation was actually consumed.
CREATE FUNCTION payroll.validate_deduction_dispositions(p_manifest jsonb,p_output jsonb) RETURNS void
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE split jsonb;line jsonb;employee jsonb;
BEGIN
 FOR split IN SELECT value FROM jsonb_array_elements(coalesce(p_manifest->'deduction_dispositions','[]')) LOOP
  SELECT value INTO employee FROM jsonb_array_elements(p_output->'employees') WHERE value->>'employment_id'=split->>'employment_id';
  SELECT value INTO line FROM jsonb_array_elements(employee->'lines') WHERE value->'deduction_disposition'=split;
  IF line IS NULL OR (line->>'amount')::numeric IS DISTINCT FROM (split->>'payroll_amount')::numeric OR employee->>'financially_qualified' IS DISTINCT FROM 'true'
   THEN RAISE EXCEPTION 'payroll_deduction_disposition_stale' USING ERRCODE='23514';END IF;
 END LOOP;
END $f$;
REVOKE ALL ON FUNCTION payroll.validate_deduction_dispositions(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.append_final_output_before_advances(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
 anchor:=' INSERT INTO payroll.final_contexts(';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_debt_final_validation';END IF;
 EXECUTE replace(definition,anchor,' PERFORM payroll.validate_deduction_dispositions(c.input_manifest,c.output);'||anchor);
END $patch$;

CREATE FUNCTION public.payroll_deduction_disposition_retract(p_tenant uuid,p_employer uuid,p_period uuid,p_disposition uuid,p_reference text,p_reason text,p_attempt uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;stored payroll.deduction_dispositions;head payroll.input_heads;version payroll.input_versions;receipt payroll.command_receipts;intent jsonb;result jsonb;
BEGIN
 a:=payroll.authorized(p_tenant,'employee_finance.approve',true);PERFORM payroll.authorized(p_tenant,'employee_finance.manage',true);
 SELECT * INTO stored FROM payroll.deduction_dispositions WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_disposition;
 IF stored.id IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF stored.disposition='external_settlement' THEN PERFORM payroll.authorized(p_tenant,'payroll.payment_record',true);END IF;
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,stored.employment_id);a:=payroll.authorized(p_tenant,'employee_finance.approve',true);
 IF p_attempt IS NULL OR p_reference IS NULL OR p_reason IS NULL OR length(btrim(p_reference)) NOT BETWEEN 3 AND 160 OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 intent:=jsonb_build_object('operation','deduction_disposition_retract','employer',p_employer,'period',p_period,'employment',stored.employment_id,'claim',stored.claim_key,'disposition_id',p_disposition,'disposition',stored.disposition,'reference',btrim(p_reference),'reason',btrim(p_reason));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 IF EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND period_id=p_period) OR EXISTS(SELECT 1 FROM payroll.deduction_disposition_retractions WHERE tenant_id=p_tenant AND disposition_id=p_disposition) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514';END IF;
 IF stored.target_head IS NOT NULL THEN
  SELECT * INTO head FROM payroll.input_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=stored.target_head FOR UPDATE;
  SELECT * INTO version FROM payroll.input_versions WHERE tenant_id=p_tenant AND head_id=head.id AND revision=head.revision;
  IF version.status NOT IN('approved','cancelled') OR EXISTS(SELECT 1 FROM payroll.input_frozen_versions f JOIN payroll.input_versions v ON v.tenant_id=f.tenant_id AND v.id=f.version_id WHERE v.tenant_id=p_tenant AND v.head_id=head.id) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514';END IF;
  IF version.status='approved' THEN
   PERFORM public.payroll_save_input(p_tenant,p_employer,'adjustment',stored.employment_id,stored.target_period,head.id,head.revision,version.effective_from,version.effective_until,version.data,'cancel',gen_random_uuid());END IF;
 END IF;
 INSERT INTO payroll.deduction_disposition_retractions VALUES(p_tenant,p_disposition,a,btrim(p_reference),btrim(p_reason),clock_timestamp());
 result:=jsonb_build_object('id',p_disposition,'retracted',true,'requires_recalculation',true);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'deduction_disposition_retracted',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'employee_finance.approve',true);PERFORM payroll.authorized(p_tenant,'employee_finance.manage',true);
 IF stored.disposition='external_settlement' THEN PERFORM payroll.authorized(p_tenant,'payroll.payment_record',true);END IF;RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_deduction_disposition_retract(uuid,uuid,uuid,uuid,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_deduction_disposition_retract(uuid,uuid,uuid,uuid,text,text,uuid) TO authenticated;

ALTER FUNCTION payroll.approval_readiness(payroll.candidates) RENAME TO approval_readiness_before_debt_dispositions;
CREATE FUNCTION payroll.approval_readiness(p_candidate payroll.candidates) RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE readiness jsonb;
BEGIN
 readiness:=payroll.approval_readiness_before_debt_dispositions(p_candidate);
 IF readiness->>'ready'='true' THEN
  BEGIN
   PERFORM payroll.validate_deduction_dispositions(p_candidate.input_manifest,p_candidate.output);
  EXCEPTION WHEN SQLSTATE '23514' THEN
   RETURN readiness||jsonb_build_object('ready',false,'blocking_count',(readiness->>'blocking_count')::integer+1,'stale_reasons',(readiness->'stale_reasons')||'"deduction_disposition_unresolved"'::jsonb);
  END;
 END IF;
 RETURN readiness;
END $f$;
REVOKE ALL ON FUNCTION payroll.approval_readiness(payroll.candidates),payroll.approval_readiness_before_debt_dispositions(payroll.candidates) FROM PUBLIC,anon,authenticated,service_role;
