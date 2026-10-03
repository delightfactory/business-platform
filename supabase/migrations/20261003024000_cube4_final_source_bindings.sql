-- Cube4: private, immutable source dependency binding.
-- This is a durable identity record, not source consumption or financial
-- qualification.  The existing approval/readiness and G6 gates remain closed.

CREATE TABLE payroll.final_source_bindings(
  tenant_id uuid NOT NULL,
  output_id uuid NOT NULL,
  employer_id uuid NOT NULL,
  period_id uuid NOT NULL,
  employment_id uuid NOT NULL,
  source_date date NOT NULL,
  source_domain text NOT NULL CHECK(source_domain IN('time','leave')),
  source_key text NOT NULL,
  source_identity jsonb NOT NULL,
  source_version jsonb NOT NULL,
  captured_payload jsonb NOT NULL,
  captured_digest text NOT NULL,
  dependency_lineage jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY(tenant_id,output_id,source_domain,source_date,source_key),
  UNIQUE(tenant_id,output_id,source_domain,source_date,source_identity),
  FOREIGN KEY(tenant_id,employer_id,output_id) REFERENCES payroll.final_contexts(tenant_id,employer_id,id),
  FOREIGN KEY(tenant_id,output_id,employment_id) REFERENCES payroll.final_employees(tenant_id,output_id,employment_id),
  FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id),
  CHECK(length(btrim(source_key))>0),
  CHECK(length(captured_digest)=64)
);
ALTER TABLE payroll.final_source_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.final_source_bindings FORCE ROW LEVEL SECURITY;
CREATE TRIGGER payroll_final_source_bindings_immutable
  BEFORE UPDATE OR DELETE ON payroll.final_source_bindings
  FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
REVOKE ALL ON payroll.final_source_bindings FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.validate_final_source_currentness(
  p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_candidate uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE
  r payroll.runs%ROWTYPE; c payroll.candidates%ROWTYPE; period payroll.periods%ROWTYPE;
  manifest jsonb; fresh jsonb; item jsonb; me jsonb; output_employee boolean;
  enabled_time boolean; enabled_leave boolean; time_items jsonb; leave_items jsonb;
  bindings jsonb:='[]'::jsonb; identity jsonb; version jsonb; key text; digest text; seen text[]:='{}';
BEGIN
  PERFORM payroll.correction_append_authority(p_tenant,p_run);
  SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run;
  SELECT * INTO c FROM payroll.candidates WHERE tenant_id=p_tenant AND run_id=p_run AND id=p_candidate;
  IF r.id IS NULL OR c.id IS NULL OR r.employer_id IS DISTINCT FROM p_employer OR r.period_id IS DISTINCT FROM p_period
     OR c.employer_id IS DISTINCT FROM p_employer THEN RAISE EXCEPTION 'payroll_source_scope' USING ERRCODE='23514'; END IF;
  manifest:=c.input_manifest;
  SELECT * INTO period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
  IF NOT FOUND OR manifest->'period'->>'id' IS DISTINCT FROM p_period::text
     OR manifest->'period'->>'tenant_id' IS DISTINCT FROM p_tenant::text
     OR manifest->'period'->>'employer_id' IS DISTINCT FROM p_employer::text
     OR (manifest->'period'->>'starts_on')::date IS DISTINCT FROM period.starts_on
     OR (manifest->'period'->>'ends_on')::date IS DISTINCT FROM period.ends_on
  THEN RAISE EXCEPTION 'payroll_source_scope' USING ERRCODE='23514'; END IF;
  IF jsonb_typeof(manifest->'optional') IS DISTINCT FROM 'object'
     OR NOT(manifest->'optional' ? 'time') OR NOT(manifest->'optional' ? 'leave')
     OR jsonb_typeof(manifest->'optional'->'time') IS DISTINCT FROM 'boolean'
     OR jsonb_typeof(manifest->'optional'->'leave') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'payroll_source_invalid'; END IF;
  enabled_time:=(manifest->'optional'->>'time')::boolean; enabled_leave:=(manifest->'optional'->>'leave')::boolean;
  IF manifest->'optional_sources'->'time' IS NULL OR manifest->'optional_sources'->'leave' IS NULL
     OR jsonb_typeof(manifest->'optional_sources'->'time'->'enabled') IS DISTINCT FROM 'boolean'
     OR jsonb_typeof(manifest->'optional_sources'->'leave'->'enabled') IS DISTINCT FROM 'boolean'
     OR (manifest->'optional_sources'->'time'->>'enabled')::boolean IS DISTINCT FROM enabled_time
     OR (manifest->'optional_sources'->'leave'->>'enabled')::boolean IS DISTINCT FROM enabled_leave
  THEN RAISE EXCEPTION 'payroll_source_invalid'; END IF;
  time_items:=COALESCE(manifest->'optional_sources'->'time'->'items','[]'::jsonb);
  leave_items:=COALESCE(manifest->'optional_sources'->'leave'->'items','[]'::jsonb);
  IF NOT enabled_time AND (time_items<>'[]'::jsonb OR manifest->'optional_sources'->'time'->'coverage' IS DISTINCT FROM jsonb_build_object('contract','cube4-time-coverage-v1','enabled',false,'items','[]'::jsonb)) THEN RAISE EXCEPTION 'payroll_source_disabled'; END IF;
  IF NOT enabled_leave AND leave_items<>'[]'::jsonb THEN RAISE EXCEPTION 'payroll_source_disabled'; END IF;
  IF enabled_time OR enabled_leave THEN fresh:=payroll.capture_optional_sources(p_tenant,p_employer,p_period); END IF;
  IF enabled_time AND fresh->'time' IS DISTINCT FROM manifest->'optional_sources'->'time' THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409'; END IF;
  IF enabled_leave AND fresh->'leave' IS DISTINCT FROM manifest->'optional_sources'->'leave' THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409'; END IF;

  IF enabled_time THEN FOR item IN SELECT value FROM jsonb_array_elements(time_items) LOOP
    IF item->>'date' IS NULL OR (item->>'date')::date NOT BETWEEN period.starts_on AND period.ends_on OR item->>'employment_id' IS NULL OR item->>'employee_id' IS NULL OR item->>'work_instance_id' IS NULL OR item->>'fact_id' IS NULL OR item->>'fact_version' IS NULL OR item->>'interpretation_id' IS NULL OR item->>'interpretation_version' IS NULL THEN RAISE EXCEPTION 'payroll_source_identity_missing'; END IF;
    SELECT value INTO me FROM jsonb_array_elements(COALESCE(manifest->'employees','[]'::jsonb)) WHERE value->'employment'->>'id'=item->>'employment_id';
    output_employee:=EXISTS(SELECT 1 FROM jsonb_array_elements(COALESCE(c.output->'employees','[]'::jsonb)) WHERE value->>'employment_id'=item->>'employment_id');
    IF NOT output_employee THEN CONTINUE; END IF;
    IF me IS NULL OR (item->>'employee_id') IS DISTINCT FROM me->'employment'->>'employee_id' THEN RAISE EXCEPTION 'payroll_source_scope'; END IF;
    key:='time:'||(item->>'work_instance_id')||':'||(item->>'fact_id')||':'||(item->>'fact_version')||':'||(item->>'interpretation_id')||':'||(item->>'interpretation_version');
    IF key=ANY(seen) THEN RAISE EXCEPTION 'payroll_source_duplicate'; END IF; seen:=seen||key;
    identity:=jsonb_build_object('work_instance_id',item->'work_instance_id','fact_id',item->'fact_id','interpretation_id',item->'interpretation_id'); version:=jsonb_build_object('fact_version',item->'fact_version','interpretation_version',item->'interpretation_version'); digest:=encode(extensions.digest(item::text,'sha256'),'hex');
    bindings:=bindings||jsonb_build_array(jsonb_build_object('employment_id',item->>'employment_id','date',item->>'date','domain','time','key',key,'identity',identity,'version',version,'payload',item,'lineage',jsonb_build_object('work_instance_id',item->'work_instance_id','fact_id',item->'fact_id','interpretation_id',item->'interpretation_id'),'digest',digest));
  END LOOP; END IF;
  IF enabled_leave THEN FOR item IN SELECT value FROM jsonb_array_elements(leave_items) LOOP
    IF item->>'date' IS NULL OR (item->>'date')::date NOT BETWEEN period.starts_on AND period.ends_on OR item->>'employment_id' IS NULL OR item->>'employee_id' IS NULL OR item->>'request_id' IS NULL OR item->>'request_version' IS NULL OR item->>'approved_preview_version' IS NULL THEN RAISE EXCEPTION 'payroll_source_identity_missing'; END IF;
    SELECT value INTO me FROM jsonb_array_elements(COALESCE(manifest->'employees','[]'::jsonb)) WHERE value->'employment'->>'id'=item->>'employment_id';
    output_employee:=EXISTS(SELECT 1 FROM jsonb_array_elements(COALESCE(c.output->'employees','[]'::jsonb)) WHERE value->>'employment_id'=item->>'employment_id');
    IF NOT output_employee THEN CONTINUE; END IF;
    IF me IS NULL OR (item->>'employee_id') IS DISTINCT FROM me->'employment'->>'employee_id' THEN RAISE EXCEPTION 'payroll_source_scope'; END IF;
    key:='leave:'||(item->>'request_id')||':'||(item->>'approved_preview_version')||':'||(item->>'date');
    IF key=ANY(seen) THEN RAISE EXCEPTION 'payroll_source_duplicate'; END IF; seen:=seen||key;
    identity:=jsonb_build_object('request_id',item->'request_id','date',item->'date'); version:=jsonb_build_object('request_version',item->'request_version','approved_preview_version',item->'approved_preview_version'); digest:=encode(extensions.digest(item::text,'sha256'),'hex');
    bindings:=bindings||jsonb_build_array(jsonb_build_object('employment_id',item->>'employment_id','date',item->>'date','domain','leave','key',key,'identity',identity,'version',version,'payload',item,'lineage',jsonb_build_object('cancellation',item->'cancellation','correction_links',item->'correction_links','ledger_links',item->'ledger_links'),'digest',digest));
  END LOOP; END IF;
  RETURN bindings;
END $f$;

CREATE FUNCTION payroll.insert_final_source_bindings(p_tenant uuid,p_employer uuid,p_period uuid,p_output uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE c payroll.final_contexts%ROWTYPE; b jsonb; existing payroll.final_source_bindings%ROWTYPE; bindings jsonb; actor uuid;
BEGIN
  SELECT * INTO c FROM payroll.final_contexts WHERE tenant_id=p_tenant AND id=p_output;
  IF c.id IS NULL OR c.employer_id IS DISTINCT FROM p_employer OR c.period_id IS DISTINCT FROM p_period OR c.manifest->'period'->>'employer_id' IS DISTINCT FROM p_employer::text THEN RAISE EXCEPTION 'payroll_source_scope' USING ERRCODE='23514'; END IF;
  actor:=payroll.correction_append_authority(p_tenant,c.run_id);
  IF c.finalized_by IS DISTINCT FROM actor THEN RAISE EXCEPTION 'payroll_source_authority' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM payroll.candidates x WHERE x.tenant_id=p_tenant AND x.run_id=c.run_id AND x.id=c.candidate_id AND x.input_manifest IS NOT DISTINCT FROM c.manifest AND x.output IS NOT DISTINCT FROM c.result) THEN RAISE EXCEPTION 'payroll_source_final_snapshot'; END IF;
  IF EXISTS(SELECT 1 FROM payroll.final_employees fe WHERE fe.tenant_id=p_tenant AND fe.output_id=p_output AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(COALESCE(c.result->'employees','[]'::jsonb)) e WHERE (e->>'employment_id')::uuid=fe.employment_id)) OR EXISTS(SELECT 1 FROM jsonb_array_elements(COALESCE(c.result->'employees','[]'::jsonb)) e WHERE NOT EXISTS(SELECT 1 FROM payroll.final_employees fe WHERE fe.tenant_id=p_tenant AND fe.output_id=p_output AND fe.employment_id=(e->>'employment_id')::uuid)) THEN RAISE EXCEPTION 'payroll_source_final_employee_scope'; END IF;
  bindings:=payroll.validate_final_source_currentness(p_tenant,p_employer,p_period,c.run_id,c.candidate_id);
  FOR b IN SELECT value FROM jsonb_array_elements(bindings) LOOP
    IF NOT EXISTS(SELECT 1 FROM payroll.final_employees WHERE tenant_id=p_tenant AND employer_id=p_employer AND output_id=p_output AND employment_id=(b->>'employment_id')::uuid) THEN RAISE EXCEPTION 'payroll_source_output_employee'; END IF;
    SELECT * INTO existing FROM payroll.final_source_bindings WHERE tenant_id=p_tenant AND output_id=p_output AND source_domain=b->>'domain' AND source_date=(b->>'date')::date AND source_key=b->>'key';
    IF FOUND THEN
      IF existing.captured_digest IS DISTINCT FROM encode(extensions.digest((b->'payload')::text,'sha256'),'hex') OR existing.captured_payload IS DISTINCT FROM b->'payload' OR existing.source_identity IS DISTINCT FROM b->'identity' OR existing.source_version IS DISTINCT FROM b->'version' THEN RAISE EXCEPTION 'payroll_source_binding_conflict' USING ERRCODE='PT409'; END IF;
    ELSE
      INSERT INTO payroll.final_source_bindings(tenant_id,output_id,employer_id,period_id,employment_id,source_date,source_domain,source_key,source_identity,source_version,captured_payload,captured_digest,dependency_lineage) VALUES(p_tenant,p_output,p_employer,p_period,(b->>'employment_id')::uuid,(b->>'date')::date,b->>'domain',b->>'key',b->'identity',b->'version',b->'payload',encode(extensions.digest((b->'payload')::text,'sha256'),'hex'),b->'lineage');
    END IF;
  END LOOP;
END $f$;
REVOKE ALL ON FUNCTION payroll.validate_final_source_currentness(uuid,uuid,uuid,uuid,uuid),payroll.insert_final_source_bindings(uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

-- Keep the established Tenant/advisory/H prefix. Only existing Time W rows are
-- fenced, and only when Time is enabled; no W->Leave edge is introduced.
DO $patch$
DECLARE d text; old text; new text;
BEGIN
  d:=pg_get_functiondef('payroll.lock_finalization_sources(uuid,uuid,uuid)'::regprocedure);
  old:='LOCK TABLE payroll.statutory_packs IN SHARE MODE;';
  IF (length(d)-length(replace(d,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'unexpected_final_source_lock_anchor'; END IF;
  new:='LOCK TABLE payroll.statutory_packs IN SHARE MODE;
  IF platform_private.tenant_capability_is_enabled(p_tenant,''hr.attendance'',clock_timestamp()) THEN
    PERFORM 1 FROM time.work_instances i JOIN people.employments h ON h.tenant_id=i.tenant_id AND h.id=i.employment_id
     WHERE i.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND i.operational_date BETWEEN (SELECT starts_on FROM payroll.periods WHERE tenant_id=p_tenant AND id=p_period) AND (SELECT ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND id=p_period) ORDER BY i.operational_date,i.id FOR UPDATE OF i;
  END IF;
  -- Leave remains a currentness check, not a new broad lock edge.';
  EXECUTE replace(d,old,new);
END $patch$;

-- Bulk Time approval locks all supplied WorkInstances by day/id before it
-- classifies off-day IDs as unavailable. Use that same order in Cube4 even
-- when a caller submits mixed dates. No Time writer or historical migration
-- is changed, and the existing Employment prefix remains intact.
DO $patch_calculation_order$
DECLARE d text; old text:='ORDER BY i.id FOR UPDATE;';
BEGIN
  d:=pg_get_functiondef('payroll.lock_calculate_current_employments(uuid,uuid,uuid)'::regprocedure);
  IF (length(d)-length(replace(d,old,'')))/length(old)<>1 THEN
    RAISE EXCEPTION 'unexpected_calculate_source_order_anchor';
  END IF;
  EXECUTE replace(d,old,'ORDER BY i.operational_date,i.id FOR UPDATE OF i;');
END $patch_calculation_order$;

DO $patch$
DECLARE d text; old text; new text;
BEGIN
  d:=pg_get_functiondef('payroll.append_final_output_before_advances(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
  IF position('DECLARE r payroll.runs%ROWTYPE' IN d)=0 OR position('INSERT INTO payroll.final_contexts' IN d)=0 THEN RAISE EXCEPTION 'unexpected_final_append_anchor'; END IF;
  old:='DECLARE r payroll.runs%ROWTYPE;c payroll.candidates%ROWTYPE;e jsonb;h jsonb;output uuid;';
  IF (length(d)-length(replace(d,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'unexpected_final_append_declaration_anchor'; END IF;
  d:=replace(d,old,'DECLARE r payroll.runs%ROWTYPE;c payroll.candidates%ROWTYPE;e jsonb;h jsonb;output uuid;bindings jsonb;');
  old:='INSERT INTO payroll.final_contexts(tenant_id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)';
  new:='bindings:=payroll.validate_final_source_currentness(p_tenant,r.employer_id,r.period_id,p_run,p_candidate);
  INSERT INTO payroll.final_contexts(tenant_id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)';
  IF (length(d)-length(replace(d,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'unexpected_final_append_context_anchor'; END IF;
  d:=replace(d,old,new);
  old:='FOR input IN SELECT DISTINCT(i->''version''->>''id'')::uuid AS id FROM jsonb_array_elements(c.input_manifest->''inputs'')i LOOP';
  new:='PERFORM payroll.insert_final_source_bindings(p_tenant,r.employer_id,r.period_id,output);
  FOR input IN SELECT DISTINCT(i->''version''->>''id'')::uuid AS id FROM jsonb_array_elements(c.input_manifest->''inputs'')i LOOP';
  IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_final_append_binding_anchor'; END IF;
  d:=replace(d,old,new);
  EXECUTE d;
END $patch$;
