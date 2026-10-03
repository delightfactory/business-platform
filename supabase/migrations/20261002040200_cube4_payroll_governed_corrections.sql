-- Slice6: attributable, typed governed correction. No public financial finalization or legal guesses.
CREATE TABLE payroll.correction_cases(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),original_output uuid NOT NULL,
 revision integer NOT NULL DEFAULT 0,status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','review','approved','routed','completed','cancelled')),
 proposal_id uuid,created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,employer_id,id),FOREIGN KEY(tenant_id,employer_id,original_output) REFERENCES payroll.final_contexts(tenant_id,employer_id,id));
CREATE UNIQUE INDEX payroll_one_open_correction ON payroll.correction_cases(tenant_id,original_output) WHERE status IN('draft','review','approved');
CREATE TABLE payroll.correction_proposals(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,case_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),revision integer NOT NULL,
 typed_changes jsonb NOT NULL,source_changes jsonb NOT NULL,source_scope jsonb NOT NULL,reason text NOT NULL,reference text NOT NULL,
 target_period uuid,responsibilities jsonb NOT NULL,created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,case_id,revision),FOREIGN KEY(tenant_id,employer_id,case_id) REFERENCES payroll.correction_cases(tenant_id,employer_id,id),FOREIGN KEY(tenant_id,target_period) REFERENCES payroll.periods(tenant_id,id));
ALTER TABLE payroll.correction_cases ADD FOREIGN KEY(tenant_id,proposal_id) REFERENCES payroll.correction_proposals(tenant_id,id);
CREATE TABLE payroll.correction_events(
 tenant_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),case_id uuid NOT NULL,proposal_id uuid NOT NULL,operation text NOT NULL,
 actor_id uuid NOT NULL REFERENCES auth.users(id),reason text NOT NULL,details jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),FOREIGN KEY(tenant_id,case_id) REFERENCES payroll.correction_cases(tenant_id,id),FOREIGN KEY(tenant_id,proposal_id) REFERENCES payroll.correction_proposals(tenant_id,id));
CREATE TABLE payroll.correction_source_effects(
 tenant_id uuid NOT NULL,case_id uuid NOT NULL,proposal_id uuid NOT NULL,change_index integer NOT NULL,
 transaction_id xid8 NOT NULL,backend_pid integer NOT NULL,affected_outputs jsonb NOT NULL,source_table text NOT NULL,operation text NOT NULL,old_row jsonb,new_row jsonb NOT NULL,
 actor_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,proposal_id,change_index),FOREIGN KEY(tenant_id,case_id) REFERENCES payroll.correction_cases(tenant_id,id),FOREIGN KEY(tenant_id,proposal_id) REFERENCES payroll.correction_proposals(tenant_id,id));
CREATE TABLE payroll.correction_targets(
 tenant_id uuid NOT NULL,case_id uuid NOT NULL,proposal_id uuid NOT NULL,employment_id uuid NOT NULL,head_id uuid NOT NULL,
 amount numeric(18,2) NOT NULL CHECK(amount<>0),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,proposal_id,head_id),UNIQUE(tenant_id,head_id),FOREIGN KEY(tenant_id,proposal_id) REFERENCES payroll.correction_proposals(tenant_id,id),FOREIGN KEY(tenant_id,head_id) REFERENCES payroll.input_heads(tenant_id,id));
CREATE TABLE payroll.correction_settlements(
 tenant_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),case_id uuid NOT NULL,proposal_id uuid NOT NULL,employment_id uuid NOT NULL,
 direction text NOT NULL CHECK(direction IN('employee_extra_payment','employee_recovery')),amount numeric(18,2) NOT NULL CHECK(amount>0),
 occurred_on date NOT NULL,reference text NOT NULL,reason text NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),FOREIGN KEY(tenant_id,case_id) REFERENCES payroll.correction_cases(tenant_id,id),FOREIGN KEY(tenant_id,proposal_id) REFERENCES payroll.correction_proposals(tenant_id,id),FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id));
CREATE TABLE payroll.correction_request_links(tenant_id uuid NOT NULL,request_id uuid NOT NULL,case_id uuid NOT NULL,PRIMARY KEY(tenant_id,request_id,case_id),FOREIGN KEY(tenant_id,request_id) REFERENCES payroll.correction_requirements(tenant_id,id),FOREIGN KEY(tenant_id,case_id) REFERENCES payroll.correction_cases(tenant_id,id));
ALTER TABLE payroll.runs ADD COLUMN amendment_of uuid;
ALTER TABLE payroll.runs ADD FOREIGN KEY(tenant_id,amendment_of) REFERENCES payroll.final_contexts(tenant_id,id);
CREATE TABLE payroll.amendment_runs(tenant_id uuid NOT NULL,run_id uuid NOT NULL,case_id uuid NOT NULL,proposal_id uuid NOT NULL,PRIMARY KEY(tenant_id,run_id),FOREIGN KEY(tenant_id,run_id) REFERENCES payroll.runs(tenant_id,id),FOREIGN KEY(tenant_id,case_id) REFERENCES payroll.correction_cases(tenant_id,id),FOREIGN KEY(tenant_id,proposal_id) REFERENCES payroll.correction_proposals(tenant_id,id));
DROP INDEX payroll.payroll_one_active_run;
CREATE UNIQUE INDEX payroll_one_active_run ON payroll.runs(tenant_id,employer_id,period_id) WHERE amendment_of IS NULL AND status IN('draft','review','approved','locked');
CREATE UNIQUE INDEX payroll_one_active_amendment ON payroll.runs(tenant_id,amendment_of) WHERE amendment_of IS NOT NULL AND status IN('draft','review','approved','locked');
DO $f$ DECLARE tab text;BEGIN
 FOREACH tab IN ARRAY ARRAY['correction_cases','correction_proposals','correction_events','correction_source_effects','correction_targets','correction_settlements','correction_request_links','amendment_runs'] LOOP
  EXECUTE format('ALTER TABLE payroll.%I ENABLE ROW LEVEL SECURITY',tab);EXECUTE format('REVOKE ALL ON payroll.%I FROM PUBLIC,anon,authenticated,service_role',tab);
  IF tab<>'correction_cases' THEN EXECUTE format('CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.%I FOR EACH ROW EXECUTE FUNCTION payroll.immutable()',tab);END IF;
 END LOOP;
END $f$;
-- Resolution is linked evidence. Historical requirements remain immutable and inspectable.
ALTER FUNCTION payroll.run_manifest(uuid,uuid,uuid) RENAME TO run_manifest_before_corrections;
CREATE FUNCTION payroll.run_manifest(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE m jsonb;BEGIN
 m:=payroll.run_manifest_before_corrections(p_tenant,p_employer,p_period);
 RETURN jsonb_set(m,'{corrections}',COALESCE((SELECT jsonb_agg(x ORDER BY x->>'id') FROM jsonb_array_elements(m->'corrections')x WHERE NOT EXISTS(SELECT 1 FROM payroll.correction_request_links l JOIN payroll.correction_cases c ON c.tenant_id=l.tenant_id AND c.id=l.case_id WHERE l.tenant_id=p_tenant AND l.request_id=(x->>'id')::uuid AND c.status IN('routed','completed'))),'[]'));
END $f$;
CREATE FUNCTION payroll.guard_correction_case() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF TG_OP='DELETE' OR OLD.status IN('completed','cancelled') OR to_jsonb(NEW)-ARRAY['revision','status','proposal_id'] IS DISTINCT FROM to_jsonb(OLD)-ARRAY['revision','status','proposal_id'] THEN RAISE EXCEPTION 'payroll_immutable' USING ERRCODE='55000';END IF;
 IF NEW.revision<>OLD.revision+1 OR OLD.status='approved' AND NEW.status NOT IN('review','routed','completed') OR OLD.status='routed' AND NEW.status NOT IN('routed','completed') OR NEW.proposal_id IS DISTINCT FROM OLD.proposal_id AND(OLD.status NOT IN('draft','review') OR NEW.status<>'draft') THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER correction_case_lifecycle BEFORE UPDATE OR DELETE ON payroll.correction_cases FOR EACH ROW EXECUTE FUNCTION payroll.guard_correction_case();
-- Exact private proof, never a GUC or a blanket guard switch. Historical before/after remains attributable.
CREATE FUNCTION payroll.source_effect_authorized(p_table text,p_operation text,p_old jsonb,p_new jsonb) RETURNS boolean LANGUAGE sql VOLATILE SET search_path='' AS $f$
 SELECT EXISTS(SELECT 1 FROM payroll.correction_source_effects e JOIN payroll.correction_cases c ON c.tenant_id=e.tenant_id AND c.id=e.case_id
 WHERE e.transaction_id=pg_current_xact_id() AND e.backend_pid=pg_backend_pid() AND e.source_table=p_table AND e.operation=p_operation
 AND e.affected_outputs=(SELECT p.source_scope->'affected_outputs' FROM payroll.correction_proposals p WHERE p.tenant_id=e.tenant_id AND p.id=e.proposal_id) AND e.old_row IS NOT DISTINCT FROM p_old AND e.new_row=p_new AND e.actor_id=auth.uid() AND c.status='approved' AND c.proposal_id=e.proposal_id AND EXISTS(SELECT 1 FROM payroll.correction_events a WHERE a.tenant_id=c.tenant_id AND a.case_id=c.id AND a.proposal_id=e.proposal_id AND a.operation='approve'))
$f$;
DO $f$ DECLARE proc text;definition text;BEGIN
 FOREACH proc IN ARRAY ARRAY['payroll.guard_people_frozen_history()','payroll.guard_final_employment_scope()'] LOOP
  definition:=pg_get_functiondef(proc::regprocedure);
  IF definition NOT LIKE '%payroll_people_correction_required%' THEN RAISE EXCEPTION 'unexpected_people_correction_guard';END IF;
  IF proc='payroll.guard_people_frozen_history()' THEN
   definition:=replace(definition,' t:=COALESCE',' IF payroll.source_effect_authorized(TG_TABLE_NAME,TG_OP,old_data,new_data) THEN RETURN NEW;END IF; t:=COALESCE');
  ELSE
   definition:=replace(definition,' IF old_data IS NOT NULL',' IF payroll.source_effect_authorized(TG_TABLE_NAME,TG_OP,old_data,new_data) THEN RETURN NEW;END IF; IF old_data IS NOT NULL');
  END IF;
  IF definition NOT LIKE '%source_effect_authorized%' THEN RAISE EXCEPTION 'unexpected_people_guard_anchor';END IF;EXECUTE definition;
 END LOOP;
END $f$;
CREATE FUNCTION payroll.correction_lock(p_tenant uuid,p_employer uuid,p_employees uuid[] DEFAULT '{}') RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM payroll.lock_source_scope(p_tenant);
 PERFORM 1 FROM platform_core.tenants WHERE id=p_tenant FOR SHARE;PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant AND user_id=auth.uid() FOR SHARE;
 PERFORM 1 FROM people.employees e WHERE tenant_id=p_tenant ORDER BY id FOR UPDATE;
 PERFORM 1 FROM people.employments WHERE tenant_id=p_tenant ORDER BY id FOR UPDATE;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant ORDER BY id FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
END $f$;
CREATE FUNCTION payroll.correction_scope(p_tenant uuid,p_employer uuid) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT jsonb_build_object('employments',COALESCE((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.id) FROM people.employments h WHERE h.tenant_id=p_tenant),'[]'),
 'compensation',COALESCE((SELECT jsonb_agg(to_jsonb(v) ORDER BY v.id) FROM people.compensation_versions v JOIN people.employments h ON h.tenant_id=v.tenant_id AND h.id=v.employment_id WHERE h.tenant_id=p_tenant),'[]'),
 'assignments',COALESCE((SELECT jsonb_agg(to_jsonb(v) ORDER BY v.id) FROM people.work_assignments v JOIN people.employments h ON h.tenant_id=v.tenant_id AND h.id=v.employment_id WHERE h.tenant_id=p_tenant),'[]'),
 'inputs',COALESCE((SELECT jsonb_agg(jsonb_build_object('head',to_jsonb(h),'version',to_jsonb(v)) ORDER BY h.id,v.revision) FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id WHERE h.tenant_id=p_tenant),'[]'),
 'employees',COALESCE((SELECT jsonb_agg(to_jsonb(e) ORDER BY e.id) FROM people.employees e WHERE e.tenant_id=p_tenant AND EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=e.tenant_id AND h.employee_id=e.id)),'[]'),
 'payments',COALESCE((SELECT jsonb_agg(jsonb_build_object('output',c.id,'revision',COALESCE(h.revision,0),'ever_paid',payroll.output_has_ever_paid(c.tenant_id,c.id)) ORDER BY c.id) FROM payroll.final_contexts c LEFT JOIN payroll.payment_heads h ON h.tenant_id=c.tenant_id AND h.output_id=c.id WHERE c.tenant_id=p_tenant),'[]'),
 'outputs',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'period_id',period_id) ORDER BY id) FROM payroll.final_contexts WHERE tenant_id=p_tenant),'[]'))
$f$;
CREATE FUNCTION payroll.source_hash(p_row jsonb) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT encode(extensions.digest(COALESCE(p_row,'null'::jsonb)::text,'sha256'),'hex')
$f$;
-- Reuse the existing input-domain invariants, excluding only the frozen-history refusal and prospective-only rule.
DO $f$ DECLARE d text;body text;a integer;b integer;BEGIN
 d:=pg_get_functiondef('public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)'::regprocedure);
 a:=strpos(d,' IF p_kind=''opening_ytd'' AND');b:=strpos(d,' IF EXISTS(SELECT 1 FROM payroll.people_frozen_contexts');
 IF a=0 OR b<=a THEN RAISE EXCEPTION 'unexpected_correction_input_context_anchor';END IF;
 body:=substring(d FROM a FOR b-a);
 EXECUTE 'CREATE FUNCTION payroll.validate_correction_input_context(head payroll.input_heads,current payroll.input_versions,p_from date,p_until date,p_data jsonb) RETURNS void LANGUAGE plpgsql SET search_path='''' AS $body$ DECLARE p_tenant uuid:=head.tenant_id;p_employer uuid:=head.employer_id;p_kind text:=head.kind;p_employment uuid:=head.employment_id;p_period uuid:=head.period_id;bounds payroll.periods%ROWTYPE;component payroll.input_versions%ROWTYPE;BEGIN SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND id=p_period;'||body||' END $body$';
END $f$;
CREATE FUNCTION payroll.correction_typed_authority(p_tenant uuid,p_changes jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE x jsonb;permission text;kind text;head payroll.input_heads%ROWTYPE;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.correct',false);
 FOR x IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
  kind:=x->>'type';permission:=CASE WHEN kind IN('compensation','compensation_split') THEN 'compensation.manage' WHEN kind IN('assignment','assignment_split') THEN 'org_context.manage' WHEN kind IN('employment','new_employment') THEN 'employment.manage' END;
  IF permission IS NOT NULL AND NOT(platform_private.has_tenant_permission(p_tenant,auth.uid(),permission) OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  IF kind='new_employment' THEN
   IF NOT(platform_private.has_tenant_permission(p_tenant,auth.uid(),'compensation.manage') AND platform_private.has_tenant_permission(p_tenant,auth.uid(),'org_context.manage')) AND NOT platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
   IF x->'fields'->>'employee_id' IS NULL AND NOT(platform_private.has_tenant_permission(p_tenant,auth.uid(),'people.manage') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  ELSIF kind='input_revision' THEN
   SELECT * INTO head FROM payroll.input_heads WHERE tenant_id=p_tenant AND id=(x->>'source_id')::uuid;
   IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
   PERFORM payroll.authorized(p_tenant,payroll.input_permission(head.kind,'save'),false);
   IF head.kind IN('manual_units','adjustment') THEN PERFORM payroll.authorized(p_tenant,payroll.input_permission(head.kind,'approve'),false);END IF;
  END IF;
 END LOOP;
END $f$;
CREATE FUNCTION payroll.compile_source_changes(p_tenant uuid,p_employer uuid,p_changes jsonb,p_actor uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE change jsonb;kind text;fields jsonb;old_row jsonb;new_row jsonb;table_name text;keys text[];
 result jsonb:='[]';v_source_id uuid;emp uuid;amount numeric;from_date date;until_date date;site uuid;row_value jsonb;head payroll.input_heads%ROWTYPE;version payroll.input_versions%ROWTYPE;BEGIN
 IF jsonb_typeof(p_changes) IS DISTINCT FROM 'array' OR jsonb_array_length(p_changes) NOT BETWEEN 1 AND 32 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
  IF jsonb_typeof(change) IS DISTINCT FROM 'object' OR change-ARRAY['type','source_id','expected_hash','fields']<>'{}'::jsonb OR jsonb_typeof(change->'fields') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  kind:=change->>'type';fields:=change->'fields';old_row:=NULL;new_row:=NULL;
  keys:=CASE kind WHEN 'compensation_split' THEN ARRAY['amount','effective_from'] WHEN 'assignment_split' THEN ARRAY['site_id','department_id','job_id','manager_employee_id','work_policy_template_id','work_policy_version','effective_from'] WHEN 'compensation' THEN ARRAY['amount','valid_from','valid_until'] WHEN 'assignment' THEN ARRAY['site_id','department_id','job_id','manager_employee_id','valid_from','valid_until','work_policy_template_id','work_policy_version'] WHEN 'employment' THEN ARRAY['start_date','end_date','pay_basis','payroll_eligible'] WHEN 'new_employment' THEN ARRAY['employee_id','employee_code','full_name','start_date','end_date','pay_basis','payroll_eligible','amount','site_id'] WHEN 'input_revision' THEN ARRAY['effective_from','effective_until','data','cancelled'] END;
  IF keys IS NULL OR EXISTS(SELECT 1 FROM jsonb_object_keys(fields)k WHERE NOT k=ANY(keys)) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  IF kind='new_employment' THEN
   IF change->>'source_id' IS NOT NULL OR change->>'expected_hash' IS NOT NULL THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   emp:=(fields->>'employee_id')::uuid;from_date:=(fields->>'start_date')::date;until_date:=(fields->>'end_date')::date;amount:=(fields->>'amount')::numeric;site:=(fields->>'site_id')::uuid;
   IF from_date IS NULL OR until_date<from_date OR COALESCE(fields->>'pay_basis','') NOT IN('monthly','daily') OR COALESCE(fields->>'payroll_eligible','') NOT IN('true','false') OR amount IS NULL OR amount<0 OR amount>999999999999.99 OR amount<>round(amount,2) OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND id=site AND legal_entity_id=p_employer AND is_active) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   IF emp IS NULL THEN
    IF length(btrim(COALESCE(fields->>'employee_code',''))) NOT BETWEEN 1 AND 40 OR length(btrim(COALESCE(fields->>'full_name',''))) NOT BETWEEN 2 AND 160 OR EXISTS(SELECT 1 FROM people.employees WHERE tenant_id=p_tenant AND lower(employee_code)=lower(btrim(fields->>'employee_code'))) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
    emp:=gen_random_uuid();new_row:=to_jsonb(jsonb_populate_record(NULL::people.employees,jsonb_build_object('tenant_id',p_tenant,'id',emp,'employee_code',btrim(fields->>'employee_code'),'full_name',btrim(fields->>'full_name'),'workforce_status',CASE WHEN until_date IS NULL THEN 'active' ELSE 'ended' END,'created_by_user_id',p_actor,'created_at',now(),'updated_at',now())));
    result:=result||jsonb_build_array(jsonb_build_object('source_table','employees','operation','INSERT','old_row',NULL,'new_row',new_row));
   ELSIF NOT EXISTS(SELECT 1 FROM people.employees WHERE tenant_id=p_tenant AND id=emp) OR fields->>'employee_code' IS NOT NULL OR fields->>'full_name' IS NOT NULL THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   IF EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND employee_id=emp AND daterange(start_date,end_date,'[]')&&daterange(from_date,until_date,'[]')) THEN RAISE EXCEPTION 'payroll_proposal_overlap' USING ERRCODE='23514';END IF;
   v_source_id:=gen_random_uuid();new_row:=to_jsonb(jsonb_populate_record(NULL::people.employments,jsonb_build_object('tenant_id',p_tenant,'id',v_source_id,'employee_id',emp,'employer_entity_id',p_employer,'start_date',from_date,'end_date',until_date,'employment_status',CASE WHEN until_date IS NULL THEN 'active' ELSE 'ended' END,'pay_basis',fields->>'pay_basis','payroll_eligible',(fields->>'payroll_eligible')::boolean,'created_at',now())));
   result:=result||jsonb_build_array(jsonb_build_object('source_table','employments','operation','INSERT','old_row',NULL,'new_row',new_row));
   new_row:=to_jsonb(jsonb_populate_record(NULL::people.compensation_versions,jsonb_build_object('tenant_id',p_tenant,'id',gen_random_uuid(),'employment_id',v_source_id,'amount',amount,'currency_code','EGP','valid_from',from_date,'valid_until',until_date+1,'created_at',now())));
   result:=result||jsonb_build_array(jsonb_build_object('source_table','compensation_versions','operation','INSERT','old_row',NULL,'new_row',new_row));
   new_row:=to_jsonb(jsonb_populate_record(NULL::people.work_assignments,jsonb_build_object('tenant_id',p_tenant,'id',gen_random_uuid(),'employment_id',v_source_id,'site_id',site,'valid_from',from_date,'valid_until',until_date+1,'created_at',now())));
   result:=result||jsonb_build_array(jsonb_build_object('source_table','work_assignments','operation','INSERT','old_row',NULL,'new_row',new_row));CONTINUE;
  END IF;
  v_source_id:=(change->>'source_id')::uuid;
  IF kind IN('compensation','compensation_split') THEN SELECT to_jsonb(v),v.employment_id INTO old_row,emp FROM people.compensation_versions v WHERE v.tenant_id=p_tenant AND v.id=v_source_id;table_name:='compensation_versions';
  ELSIF kind IN('assignment','assignment_split') THEN SELECT to_jsonb(v),v.employment_id INTO old_row,emp FROM people.work_assignments v WHERE v.tenant_id=p_tenant AND v.id=v_source_id;table_name:='work_assignments';
  ELSIF kind='employment' THEN SELECT to_jsonb(v),v.id INTO old_row,emp FROM people.employments v WHERE v.tenant_id=p_tenant AND v.id=v_source_id;table_name:='employments';
  ELSE SELECT * INTO head FROM payroll.input_heads WHERE tenant_id=p_tenant AND(employer_id=p_employer OR input_heads.kind='policy') AND input_heads.id=v_source_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
   SELECT * INTO version FROM payroll.input_versions WHERE tenant_id=p_tenant AND head_id=v_source_id AND revision=head.revision;old_row:=to_jsonb(version);emp:=head.employment_id;table_name:='input_versions';
  END IF;
  IF old_row IS NULL OR(kind<>'input_revision' AND NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND employments.id=emp AND employer_entity_id=p_employer)) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  IF change->>'expected_hash' IS DISTINCT FROM payroll.source_hash(old_row) THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
  IF kind='input_revision' THEN
   PERFORM payroll.validate_input(head.kind,fields->'data');
   from_date:=(fields->>'effective_from')::date;until_date:=(fields->>'effective_until')::date;
   IF from_date IS NULL OR until_date<=from_date OR COALESCE(fields->>'cancelled','') NOT IN('true','false') THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   PERFORM payroll.validate_correction_input_context(head,version,from_date,until_date,fields->'data');
   IF head.kind IN('manual_units','adjustment') AND NOT EXISTS(SELECT 1 FROM payroll.periods WHERE tenant_id=p_tenant AND id=head.period_id AND starts_on=from_date AND ends_on+1=until_date) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   new_row:=to_jsonb(head)||jsonb_build_object('revision',head.revision+1);result:=result||jsonb_build_array(jsonb_build_object('source_table','input_heads','operation','UPDATE','old_row',to_jsonb(head),'new_row',new_row));
   new_row:=to_jsonb(version)||jsonb_build_object('id',gen_random_uuid(),'revision',head.revision+1,'data',fields->'data','effective_from',from_date,'effective_until',until_date,'status',CASE WHEN(fields->>'cancelled')::boolean THEN 'cancelled' WHEN head.kind IN('manual_units','adjustment') THEN 'approved' ELSE 'draft' END,'created_by',p_actor,'created_at',now(),'approved_by',CASE WHEN head.kind IN('manual_units','adjustment') THEN p_actor END,'approved_at',CASE WHEN head.kind IN('manual_units','adjustment') THEN now() END);
   result:=result||jsonb_build_array(jsonb_build_object('source_table','input_versions','operation','INSERT','old_row',NULL,'new_row',new_row,'supersedes',version.id));CONTINUE;
  END IF;
  IF kind IN('compensation_split','assignment_split') THEN
   from_date:=(fields->>'effective_from')::date;
   IF from_date IS NULL OR from_date<=(old_row->>'valid_from')::date OR(old_row->>'valid_until' IS NOT NULL AND from_date>=(old_row->>'valid_until')::date) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   new_row:=old_row||jsonb_build_object('valid_until',from_date);
   result:=result||jsonb_build_array(jsonb_build_object('source_table',table_name,'operation','UPDATE','old_row',old_row,'new_row',new_row));
   new_row:=old_row||(fields-'effective_from')||jsonb_build_object('id',gen_random_uuid(),'valid_from',from_date,'created_at',now());
   IF kind='compensation_split' THEN amount:=(new_row->>'amount')::numeric;IF amount IS NULL OR amount<0 OR amount>999999999999.99 OR amount<>round(amount,2) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;new_row:=to_jsonb(jsonb_populate_record(NULL::people.compensation_versions,new_row));
   ELSE new_row:=to_jsonb(jsonb_populate_record(NULL::people.work_assignments,new_row));PERFORM payroll.assert_correction_assignment(p_tenant,p_employer,new_row);END IF;
   result:=result||jsonb_build_array(jsonb_build_object('source_table',table_name,'operation','INSERT','old_row',NULL,'new_row',new_row));CONTINUE;
  END IF;
  new_row:=old_row||fields;
  IF kind='employment' THEN
   new_row:=new_row||jsonb_build_object('employment_status',CASE WHEN new_row->>'end_date' IS NULL THEN 'active' ELSE 'ended' END);
   IF(new_row->>'start_date') IS NULL OR(new_row->>'end_date')::date<(new_row->>'start_date')::date OR COALESCE(new_row->>'pay_basis','') NOT IN('monthly','daily') OR COALESCE(new_row->>'payroll_eligible','') NOT IN('true','false') THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  ELSE
   IF new_row->>'valid_from' IS NULL OR(new_row->>'valid_until')::date<=(new_row->>'valid_from')::date THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   IF kind='compensation' THEN amount:=(new_row->>'amount')::numeric;IF amount IS NULL OR amount<0 OR amount>999999999999.99 OR amount<>round(amount,2) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   ELSE IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND id=(new_row->>'site_id')::uuid AND legal_entity_id=p_employer AND is_active) OR (new_row->>'work_policy_template_id' IS NULL)<>(new_row->>'work_policy_version' IS NULL) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;END IF;
  END IF;
  new_row:=CASE kind WHEN 'compensation' THEN to_jsonb(jsonb_populate_record(NULL::people.compensation_versions,new_row)) WHEN 'assignment' THEN to_jsonb(jsonb_populate_record(NULL::people.work_assignments,new_row)) ELSE to_jsonb(jsonb_populate_record(NULL::people.employments,new_row)) END;
  IF new_row=old_row THEN RAISE EXCEPTION 'payroll_proposal_unchanged' USING ERRCODE='22023';END IF;
  result:=result||jsonb_build_array(jsonb_build_object('source_table',table_name,'operation','UPDATE','old_row',old_row,'new_row',new_row));
 END LOOP;
 -- Preserve People lifecycle status alongside the exact governed Employment change.
 FOR change IN SELECT DISTINCT jsonb_build_object('employee',h->'new_row'->>'employee_id') FROM jsonb_array_elements(result)h WHERE h->>'source_table'='employments' LOOP
  SELECT to_jsonb(e) INTO old_row FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=(change->>'employee')::uuid;
  IF old_row IS NOT NULL THEN
   new_row:=old_row||jsonb_build_object('workforce_status',CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(result)h WHERE h->>'source_table'='employments' AND h->'new_row'->>'employee_id'=old_row->>'id' AND h->'new_row'->>'end_date' IS NULL) OR EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=p_tenant AND h.employee_id=(old_row->>'id')::uuid AND h.end_date IS NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result)x WHERE x->>'source_table'='employments' AND x->'new_row'->>'id'=h.id::text)) THEN 'active' ELSE 'ended' END,'updated_at',now());
   IF new_row->>'workforce_status' IS DISTINCT FROM old_row->>'workforce_status' THEN result:=result||jsonb_build_array(jsonb_build_object('source_table','employees','operation','UPDATE','old_row',old_row,'new_row',new_row));END IF;
  END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(result)x GROUP BY x->>'source_table',x->'new_row'->>'id' HAVING count(*)>1) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 RETURN result;
END $f$;
CREATE FUNCTION payroll.correction_source_authority(p_tenant uuid,p_actor uuid,p_changes jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE change jsonb;permission text;head payroll.input_heads%ROWTYPE;BEGIN
 IF p_actor IS DISTINCT FROM payroll.authorized(p_tenant,'payroll.correct',false) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
  permission:=CASE change->>'source_table' WHEN 'employees' THEN CASE WHEN change->>'operation'='INSERT' THEN 'people.manage' ELSE 'employment.manage' END WHEN 'employments' THEN 'employment.manage' WHEN 'compensation_versions' THEN 'compensation.manage' WHEN 'work_assignments' THEN 'org_context.manage' END;
  IF permission IS NOT NULL THEN IF NOT(platform_private.has_tenant_permission(p_tenant,p_actor,permission) OR platform_private.has_tenant_permission(p_tenant,p_actor,'tenant.administer')) THEN RAISE EXCEPTION 'payroll_source_authority_required' USING ERRCODE='42501';END IF;
  ELSIF change->>'source_table' IN('input_heads','input_versions') THEN
   SELECT * INTO head FROM payroll.input_heads WHERE tenant_id=p_tenant AND id=CASE WHEN change->>'source_table'='input_heads' THEN(change->'new_row'->>'id')::uuid ELSE(change->'new_row'->>'head_id')::uuid END;
   PERFORM payroll.authorized(p_tenant,payroll.input_permission(head.kind,'save'),false);
   IF head.kind='manual_units' THEN PERFORM payroll.authorized(p_tenant,'payroll.approve',false);ELSIF head.kind='adjustment' THEN PERFORM payroll.authorized(p_tenant,'employee_finance.approve',false);END IF;
  ELSE RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
END $f$;
CREATE FUNCTION payroll.assert_correction_assignment(p_tenant uuid,p_employer uuid,p_row jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE available boolean;department uuid:=(p_row->>'department_id')::uuid;job people.jobs%ROWTYPE;employee uuid;BEGIN
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND id=(p_row->>'site_id')::uuid AND legal_entity_id=p_employer AND is_active) THEN RAISE EXCEPTION 'people_assignment_site_unavailable' USING ERRCODE='23503';END IF;
 IF department IS NOT NULL THEN
  WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS(SELECT id,parent_id,is_active,ARRAY[id] FROM people.departments WHERE tenant_id=p_tenant AND id=department UNION ALL SELECT d.id,d.parent_id,d.is_active,a.path||d.id FROM people.departments d JOIN ancestors a ON d.tenant_id=p_tenant AND d.id=a.parent_id WHERE NOT d.id=ANY(a.path)) SELECT COALESCE(bool_and(is_active),false) INTO available FROM ancestors;
  IF NOT available THEN RAISE EXCEPTION 'people_assignment_department_unavailable' USING ERRCODE='23503';END IF;
 END IF;
 IF p_row->>'job_id' IS NOT NULL THEN SELECT * INTO job FROM people.jobs WHERE tenant_id=p_tenant AND id=(p_row->>'job_id')::uuid;IF NOT FOUND OR NOT job.is_active OR(job.department_id IS NOT NULL AND job.department_id IS DISTINCT FROM department) THEN RAISE EXCEPTION 'people_assignment_job_department_mismatch' USING ERRCODE='23514';END IF;END IF;
 SELECT employee_id INTO employee FROM people.employments WHERE tenant_id=p_tenant AND id=(p_row->>'employment_id')::uuid;
 IF p_row->>'manager_employee_id' IS NOT NULL AND((p_row->>'manager_employee_id')::uuid=employee OR NOT EXISTS(SELECT 1 FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.employee_id=(p_row->>'manager_employee_id')::uuid AND e.workforce_status='active' AND h.start_date<=(p_row->>'valid_from')::date AND(h.end_date IS NULL OR h.end_date>=(p_row->>'valid_from')::date))) THEN RAISE EXCEPTION 'people_assignment_manager_unavailable' USING ERRCODE='23514';END IF;
 IF(p_row->>'work_policy_template_id' IS NULL)<>(p_row->>'work_policy_version' IS NULL) OR(p_row->>'work_policy_template_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM time.work_policy_versions WHERE tenant_id=p_tenant AND template_id=(p_row->>'work_policy_template_id')::uuid AND version=(p_row->>'work_policy_version')::integer)) THEN RAISE EXCEPTION 'people_assignment_policy_unavailable' USING ERRCODE='23503';END IF;
END $f$;
CREATE FUNCTION payroll.apply_correction_sources(p_case payroll.correction_cases,p_actor uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE proposal payroll.correction_proposals%ROWTYPE;change jsonb;source_table text;source_schema text;index_value integer:=0;columns text;employee uuid;count_value integer;BEGIN
 IF p_case.status<>'approved' THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 proposal:=payroll.correction_current(p_case);PERFORM payroll.correction_source_authority(p_case.tenant_id,p_actor,proposal.source_changes);
 IF EXISTS(SELECT 1 FROM payroll.correction_source_effects WHERE tenant_id=p_case.tenant_id AND proposal_id=proposal.id) THEN RAISE EXCEPTION 'payroll_correction_already_applied' USING ERRCODE='23514';END IF;
 FOR change IN SELECT value FROM jsonb_array_elements(proposal.source_changes) LOOP
  index_value:=index_value+1;source_table:=change->>'source_table';IF source_table='work_assignments' AND(change->>'operation'='INSERT' OR((change->'old_row')-ARRAY['valid_from','valid_until']) IS DISTINCT FROM((change->'new_row')-ARRAY['valid_from','valid_until'])) THEN PERFORM payroll.assert_correction_assignment(p_case.tenant_id,p_case.employer_id,change->'new_row');END IF;source_schema:=CASE WHEN source_table IN('input_heads','input_versions') THEN 'payroll' ELSE 'people' END;
  IF source_table NOT IN('employees','employments','compensation_versions','work_assignments','input_heads','input_versions') OR change->>'operation' NOT IN('INSERT','UPDATE') THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  INSERT INTO payroll.correction_source_effects(tenant_id,case_id,proposal_id,change_index,transaction_id,backend_pid,affected_outputs,source_table,operation,old_row,new_row,actor_id) VALUES(p_case.tenant_id,p_case.id,proposal.id,index_value,pg_current_xact_id(),pg_backend_pid(),proposal.source_scope->'affected_outputs',source_table,change->>'operation',NULLIF(change->'old_row','null'::jsonb),change->'new_row',p_actor);
  IF change->>'operation'='INSERT' THEN EXECUTE format('INSERT INTO %I.%I SELECT (jsonb_populate_record(NULL::%I.%I,$1)).*',source_schema,source_table,source_schema,source_table) USING change->'new_row';
  ELSE
   SELECT string_agg(format('%I',key),',' ORDER BY key) INTO columns FROM jsonb_object_keys(change->'new_row')key WHERE key NOT IN('tenant_id','id') AND(change->'old_row'->key) IS DISTINCT FROM(change->'new_row'->key);
   IF columns IS NULL THEN RAISE EXCEPTION 'payroll_proposal_unchanged' USING ERRCODE='22023';END IF;
   EXECUTE format('UPDATE %I.%I r SET (%s)=(SELECT %s FROM jsonb_populate_record(NULL::%I.%I,$1)) WHERE r.tenant_id=$2 AND r.id=$3 AND to_jsonb(r)=$4',source_schema,source_table,columns,columns,source_schema,source_table) USING change->'new_row',p_case.tenant_id,(change->'new_row'->>'id')::uuid,change->'old_row';
   GET DIAGNOSTICS count_value=ROW_COUNT;IF count_value<>1 THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
  END IF;
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_case.tenant_id,p_case.employer_id,p_actor,'correction_source_applied',jsonb_build_object('case',p_case.id,'proposal',proposal.id,'change_index',index_value,'affected_outputs',proposal.source_scope->'affected_outputs','source',change));
 END LOOP;
 PERFORM payroll.correction_source_authority(p_case.tenant_id,p_actor,proposal.source_changes);
END $f$;
-- A selected input successor suppresses prior versions through the next effective version, including expiry/cancellation.
-- Missing old rows contribute no interval for Employment or its newly inserted dated children.
CREATE FUNCTION payroll.correction_affected_outputs(p_tenant uuid,p_employer uuid,p_changes jsonb,p_original uuid) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT COALESCE(jsonb_agg(to_jsonb(f) ORDER BY f.id),'[]') FROM(
 SELECT c.id,c.employer_id,c.period_id,p.starts_on,p.ends_on,payroll.output_has_ever_paid(c.tenant_id,c.id) ever_paid FROM payroll.final_contexts c JOIN payroll.periods p ON p.tenant_id=c.tenant_id AND p.id=c.period_id
 WHERE c.tenant_id=p_tenant AND(c.employer_id=p_employer OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_changes)x JOIN payroll.input_heads h ON h.tenant_id=p_tenant AND h.id=(x->'new_row'->>'head_id')::uuid WHERE x->>'source_table'='input_versions' AND h.kind='policy')) AND NOT EXISTS(SELECT 1 FROM payroll.output_successions s WHERE s.tenant_id=c.tenant_id AND s.original_output=c.id) AND(c.id=p_original OR EXISTS(
 SELECT 1 FROM jsonb_array_elements(p_changes)x WHERE CASE x->>'source_table'
 WHEN 'employees' THEN false WHEN 'input_heads' THEN false
 WHEN 'input_versions' THEN EXISTS(SELECT 1 FROM payroll.input_heads h WHERE h.tenant_id=p_tenant AND h.id=(x->'new_row'->>'head_id')::uuid AND(h.period_id IS NULL OR h.period_id=c.period_id) AND daterange((x->'new_row'->>'effective_from')::date,(SELECT min(v.effective_from) FROM payroll.input_versions v WHERE v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision<=h.revision AND v.effective_from>(x->'new_row'->>'effective_from')::date),'[)')&&daterange(p.starts_on,p.ends_on,'[]'))
 WHEN 'employments' THEN (NULLIF(x->'new_row','null'::jsonb) IS NOT NULL AND daterange((x->'new_row'->>'start_date')::date,(x->'new_row'->>'end_date')::date,'[]')&&daterange(p.starts_on,p.ends_on,'[]')) OR (NULLIF(x->'old_row','null'::jsonb) IS NOT NULL AND daterange((x->'old_row'->>'start_date')::date,(x->'old_row'->>'end_date')::date,'[]')&&daterange(p.starts_on,p.ends_on,'[]'))
 ELSE (EXISTS(SELECT 1 FROM payroll.final_employees e WHERE e.tenant_id=c.tenant_id AND e.output_id=c.id AND e.employment_id=(x->'new_row'->>'employment_id')::uuid) OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_changes)h WHERE h->>'source_table'='employments' AND h->'new_row'->>'id'=x->'new_row'->>'employment_id'))
 AND(daterange((x->'new_row'->>'valid_from')::date,(x->'new_row'->>'valid_until')::date,'[)')&&daterange(p.starts_on,p.ends_on,'[]') OR (NULLIF(x->'old_row','null'::jsonb) IS NOT NULL AND daterange((x->'old_row'->>'valid_from')::date,(x->'old_row'->>'valid_until')::date,'[)')&&daterange(p.starts_on,p.ends_on,'[]'))) END)))f
$f$;
-- Closure authority covers only a material change in the exact protected dates, never unrelated future work.
CREATE FUNCTION payroll.assert_correction_material(p_tenant uuid,p_changes jsonb,p_outputs jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE x jsonb;o jsonb;old_row jsonb;new_row jsonb;old_range daterange;new_range daterange;period_range daterange;material boolean;dates text[];BEGIN
 FOR x IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
  old_row:=NULLIF(x->'old_row','null'::jsonb);new_row:=x->'new_row';material:=false;
  IF x->>'source_table'='employees' THEN
   material:=EXISTS(SELECT 1 FROM jsonb_array_elements(p_changes)h WHERE h->>'source_table'='employments' AND h->'new_row'->>'employee_id'=new_row->>'id');
  ELSIF x->>'source_table'='input_heads' THEN
   material:=EXISTS(SELECT 1 FROM jsonb_array_elements(p_changes)v WHERE v->>'source_table'='input_versions' AND v->'new_row'->>'head_id'=new_row->>'id');
  ELSE
   FOR o IN SELECT value FROM jsonb_array_elements(p_outputs) LOOP
    period_range:=daterange((o->>'starts_on')::date,(o->>'ends_on')::date,'[]');
    IF x->>'source_table'='employments' THEN
     dates:=ARRAY['start_date','end_date','employment_status'];old_range:=daterange((old_row->>'start_date')::date,(old_row->>'end_date')::date,'[]');new_range:=daterange((new_row->>'start_date')::date,(new_row->>'end_date')::date,'[]');
    ELSIF x->>'source_table'='input_versions' THEN
     dates:=ARRAY['effective_from','effective_until'];old_range:=NULL;new_range:=daterange((new_row->>'effective_from')::date,(new_row->>'effective_until')::date,'[)');
    ELSE
     dates:=ARRAY['valid_from','valid_until'];old_range:=daterange((old_row->>'valid_from')::date,(old_row->>'valid_until')::date,'[)');new_range:=daterange((new_row->>'valid_from')::date,(new_row->>'valid_until')::date,'[)');
    END IF;
    IF old_row IS NULL THEN material:=material OR new_range&&period_range;
    ELSE material:=material OR(old_range*period_range IS DISTINCT FROM new_range*period_range) OR(new_range&&period_range AND old_row-dates IS DISTINCT FROM new_row-dates);END IF;
   END LOOP;
  END IF;
  IF NOT material THEN RAISE EXCEPTION 'payroll_correction_outside_protected_dates' USING ERRCODE='23514';END IF;
 END LOOP;

END $f$;
CREATE FUNCTION payroll.correction_route(p_tenant uuid,p_outputs jsonb) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(p_outputs)x WHERE payroll.output_has_ever_paid(p_tenant,(x->>'id')::uuid)) THEN 'paid_correction' ELSE 'amendment' END
$f$;
CREATE FUNCTION payroll.overlay_correction(p_manifest jsonb,p_changes jsonb,p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE manifest jsonb:=p_manifest;change jsonb;old_row jsonb;new_row jsonb;key text;items jsonb;person jsonb;head jsonb;period jsonb:=p_manifest->'period';BEGIN
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
  new_row:=change->'new_row';old_row:=change->'old_row';key:=CASE change->>'source_table' WHEN 'compensation_versions' THEN 'compensation' WHEN 'work_assignments' THEN 'assignments' WHEN 'input_versions' THEN 'inputs' ELSE NULL END;
  IF change->>'source_table'='employments' THEN
   SELECT COALESCE(jsonb_agg(x ORDER BY x->'employment'->>'id'),'[]') INTO items FROM jsonb_array_elements(manifest->'employees')x WHERE x->'employment'->>'id'<>new_row->>'id';
   IF(new_row->>'payroll_eligible')::boolean AND(new_row->>'start_date')::date<=(period->>'ends_on')::date AND(new_row->>'end_date' IS NULL OR(new_row->>'end_date')::date>=(period->>'starts_on')::date) THEN
    SELECT jsonb_build_object('employment',new_row,'name',full_name,'code',employee_code) INTO person FROM people.employees WHERE tenant_id=p_tenant AND id=(new_row->>'employee_id')::uuid;
    IF person IS NULL THEN SELECT jsonb_build_object('employment',new_row,'name',x->'new_row'->>'full_name','code',x->'new_row'->>'employee_code') INTO person FROM jsonb_array_elements(p_changes)x WHERE x->>'source_table'='employees' AND x->'new_row'->>'id'=new_row->>'employee_id';END IF;
    items:=items||jsonb_build_array(person);
   END IF;
   manifest:=jsonb_set(manifest,'{employees}',items);
  ELSIF key IN('compensation','assignments') THEN
   SELECT COALESCE(jsonb_agg(x ORDER BY x->>'employment_id',x->>'valid_from',x->>'id'),'[]') INTO items FROM jsonb_array_elements(manifest->key)x WHERE x->>'id'<>new_row->>'id';
   IF daterange((new_row->>'valid_from')::date,(new_row->>'valid_until')::date,'[)')&&daterange((period->>'starts_on')::date,(period->>'ends_on')::date,'[]') THEN items:=items||jsonb_build_array(new_row);END IF;
   manifest:=jsonb_set(manifest,ARRAY[key],items);
  ELSIF key='inputs' THEN
   SELECT x->'head' INTO head FROM jsonb_array_elements(manifest->'inputs')x WHERE x->'head'->>'id'=new_row->>'head_id' LIMIT 1;
   IF head IS NULL THEN SELECT jsonb_build_object('id',id,'kind',kind,'employment_id',employment_id,'employee_id',(SELECT employee_id FROM people.employments WHERE tenant_id=p_tenant AND id=h.employment_id),'period_id',period_id) INTO head FROM payroll.input_heads h WHERE h.tenant_id=p_tenant AND h.id=(new_row->>'head_id')::uuid;END IF;
   IF(new_row->>'effective_from')::date<=(period->>'ends_on')::date THEN manifest:=jsonb_set(manifest,'{inputs}',COALESCE((SELECT jsonb_agg(x) FROM jsonb_array_elements(manifest->'inputs')x WHERE x->'version'->>'id'<>new_row->>'id'),'[]')||jsonb_build_array(jsonb_build_object('head',head,'version',new_row)));END IF;
  END IF;
 END LOOP;
 -- Newly eligible existing Employment needs its scoped dated companions even when those rows were not edited.
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) WHERE value->>'source_table'='employments' LOOP
  new_row:=change->'new_row';
  FOREACH key IN ARRAY ARRAY['compensation','assignments'] LOOP
   SELECT COALESCE(jsonb_agg(x),'[]') INTO items FROM(SELECT to_jsonb(v) x FROM people.compensation_versions v WHERE key='compensation' AND v.tenant_id=p_tenant AND v.employment_id=(new_row->>'id')::uuid AND daterange(v.valid_from,v.valid_until,'[)')&&daterange((period->>'starts_on')::date,(period->>'ends_on')::date,'[]') UNION ALL SELECT to_jsonb(v) FROM people.work_assignments v WHERE key='assignments' AND v.tenant_id=p_tenant AND v.employment_id=(new_row->>'id')::uuid AND daterange(v.valid_from,v.valid_until,'[)')&&daterange((period->>'starts_on')::date,(period->>'ends_on')::date,'[]'))rows WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(manifest->key)m WHERE m->>'id'=x->>'id') AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_changes)c WHERE c->'new_row'->>'id'=x->>'id');
   manifest:=jsonb_set(manifest,ARRAY[key],manifest->key||items);
  END LOOP;
 END LOOP;
 -- Normalize exactly as the live manifest, including removal of sources whose Employment is no longer eligible.
 SELECT COALESCE(jsonb_agg(x ORDER BY x->'employment'->>'id'),'[]') INTO items FROM jsonb_array_elements(manifest->'employees')x;manifest:=jsonb_set(manifest,'{employees}',items);
 FOREACH key IN ARRAY ARRAY['compensation','assignments'] LOOP
  SELECT COALESCE(jsonb_agg(x ORDER BY x->>'employment_id',x->>'valid_from',x->>'id'),'[]') INTO items FROM jsonb_array_elements(manifest->key)x WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(manifest->'employees')e WHERE e->'employment'->>'id'=x->>'employment_id');manifest:=jsonb_set(manifest,ARRAY[key],items);
 END LOOP;
 SELECT COALESCE(jsonb_agg(x ORDER BY x->'head'->>'id',(x->'version'->>'revision')::int),'[]') INTO items FROM jsonb_array_elements(manifest->'inputs')x;manifest:=jsonb_set(manifest,'{inputs}',items);
 RETURN manifest;
END $f$;
CREATE FUNCTION payroll.normalize_correction_responsibilities(p_rows jsonb,p_changes jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE row_value jsonb;employment uuid;result jsonb:='[]';BEGIN
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows)>100 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 FOR row_value IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
  IF row_value->>'employment_ref' IS NOT NULL THEN
   IF row_value->>'employment_id' IS NOT NULL OR COALESCE(row_value->>'employment_ref','')!~'^new:[0-9]{1,2}$' THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   SELECT(x->'new_row'->>'id')::uuid INTO employment FROM jsonb_array_elements(p_changes) WITH ORDINALITY a(x,n) WHERE x->>'source_table'='employments' AND x->>'operation'='INSERT' ORDER BY n LIMIT 1 OFFSET(split_part(row_value->>'employment_ref',':',2))::integer;
   IF employment IS NULL THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   row_value:=(row_value-'employment_ref')||jsonb_build_object('employment_id',employment);
  END IF;
  result:=result||jsonb_build_array(row_value);
 END LOOP;RETURN result;
END $f$;
CREATE FUNCTION payroll.validate_correction_responsibilities(p_tenant uuid,p_employer uuid,p_affected jsonb,p_rows jsonb,p_target uuid,p_changes jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE row_value jsonb;amount numeric;component payroll.input_versions%ROWTYPE;period payroll.periods%ROWTYPE;employment jsonb;BEGIN
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows)>100 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 FOR row_value IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
  IF row_value-ARRAY['output_id','employment_id','amount','basis','component_id','reference','source','target_period']<>'{}'::jsonb OR COALESCE(row_value->>'basis','') NOT IN('period_component','external_reviewed') OR length(btrim(COALESCE(row_value->>'reference',''))) NOT BETWEEN 3 AND 160 OR length(btrim(COALESCE(row_value->>'source',''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  amount:=(row_value->>'amount')::numeric;
  SELECT x->'new_row' INTO employment FROM jsonb_array_elements(p_changes)x WHERE x->>'source_table'='employments' AND x->'new_row'->>'id'=row_value->>'employment_id';
  IF employment IS NULL THEN SELECT to_jsonb(h) INTO employment FROM people.employments h WHERE h.tenant_id=p_tenant AND h.id=(row_value->>'employment_id')::uuid ;END IF;
  IF amount IS NULL OR amount=0 OR abs(amount)>999999999999.99 OR amount<>round(amount,2) OR employment IS NULL OR employment->>'tenant_id'<>p_tenant::text OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_affected)o WHERE o->>'id'=row_value->>'output_id' AND o->>'employer_id'=employment->>'employer_entity_id') OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_affected)x WHERE x->>'id'=row_value->>'output_id') THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  IF NOT EXISTS(SELECT 1 FROM payroll.final_employees f WHERE f.tenant_id=p_tenant AND f.output_id=(row_value->>'output_id')::uuid AND f.employment_id=(row_value->>'employment_id')::uuid) AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_changes)h JOIN payroll.periods eligible_period ON eligible_period.tenant_id=p_tenant AND eligible_period.id=(SELECT period_id FROM payroll.final_contexts WHERE tenant_id=p_tenant AND id=(row_value->>'output_id')::uuid) WHERE h->>'source_table'='employments' AND h->'new_row'->>'id'=row_value->>'employment_id' AND daterange((h->'new_row'->>'start_date')::date,(h->'new_row'->>'end_date')::date,'[]')&&daterange(eligible_period.starts_on,eligible_period.ends_on,'[]')) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 IF row_value->>'basis'='period_component' THEN
   SELECT * INTO period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=(employment->>'employer_entity_id')::uuid AND id=COALESCE((row_value->>'target_period')::uuid,p_target);
   IF NOT FOUND OR period.starts_on<=(SELECT max((x->>'ends_on')::date) FROM jsonb_array_elements(p_affected)x) OR EXISTS(SELECT 1 FROM payroll.runs WHERE tenant_id=p_tenant AND period_id=period.id AND status IN('approved','locked','superseded')) OR NOT COALESCE((employment->>'payroll_eligible')::boolean,false) OR(employment->>'start_date')::date>period.ends_on OR(employment->>'end_date')::date<period.starts_on THEN RAISE EXCEPTION 'payroll_correction_target_unavailable' USING ERRCODE='23514';END IF;
   SELECT v.* INTO component FROM payroll.input_heads h JOIN LATERAL(SELECT * FROM payroll.input_versions WHERE tenant_id=h.tenant_id AND head_id=h.id AND effective_from<=period.starts_on ORDER BY effective_from DESC,revision DESC LIMIT 1)v ON true WHERE h.tenant_id=p_tenant AND h.employer_id=(employment->>'employer_entity_id')::uuid AND h.id=(row_value->>'component_id')::uuid AND h.kind='component';
   IF component.id IS NULL OR component.status='cancelled' OR component.effective_until<=period.ends_on OR component.data->>'active'<>'true' OR component.data->>'behavior'<>'period_input' OR component.data->>'calculation'<>'fixed' OR component.data->>'classification'<>(CASE WHEN amount>0 THEN 'earning' ELSE 'deduction' END) THEN RAISE EXCEPTION 'payroll_correction_component_unavailable' USING ERRCODE='23514';END IF;
  ELSIF row_value->>'component_id' IS NOT NULL THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_affected)o WHERE (o->>'ever_paid')::boolean AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows)r WHERE r->>'output_id'=o->>'id')) THEN RAISE EXCEPTION 'payroll_correction_responsibility_required' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows)x GROUP BY x->>'output_id',x->>'employment_id' HAVING count(*)>1) THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
END $f$;
CREATE FUNCTION payroll.correction_current(p_case payroll.correction_cases) RETURNS payroll.correction_proposals LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE proposal payroll.correction_proposals%ROWTYPE;scope jsonb;BEGIN
 SELECT * INTO proposal FROM payroll.correction_proposals WHERE tenant_id=p_case.tenant_id AND case_id=p_case.id AND id=p_case.proposal_id;
 IF proposal.id IS NULL THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 scope:=payroll.correction_scope(p_case.tenant_id,p_case.employer_id);
 IF proposal.source_scope-'affected_outputs' IS DISTINCT FROM scope THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
 RETURN proposal;
END $f$;
CREATE FUNCTION public.payroll_correction_proposal(p_tenant uuid,p_employer uuid,p_output uuid,p_case uuid,p_expected integer,p_changes jsonb,p_rows jsonb,p_target uuid,p_reason text,p_reference text,p_preview_hash text,p_operation text,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;c payroll.correction_cases%ROWTYPE;proposal payroll.correction_proposals%ROWTYPE;scope jsonb;compiled jsonb;affected jsonb;rows_normalized jsonb;intent jsonb;fingerprint text;receipt payroll.command_receipts%ROWTYPE;result jsonb;extra uuid[];BEGIN
 a:=payroll.authorized(p_tenant,'payroll.correct',false);
 IF p_operation IS NULL OR p_operation NOT IN('preview','save') OR p_expected IS NULL OR p_expected<0 OR p_attempt IS NULL OR length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 3 AND 500 OR length(btrim(COALESCE(p_reference,''))) NOT BETWEEN 3 AND 160 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 IF NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT COALESCE(array_agg((x->'fields'->>'employee_id')::uuid),'{}') INTO extra FROM jsonb_array_elements(p_changes)x WHERE x->>'type'='new_employment' AND x->'fields'->>'employee_id' IS NOT NULL;
 PERFORM payroll.correction_lock(p_tenant,p_employer,extra);a:=payroll.authorized(p_tenant,'payroll.correct',false);
 intent:=jsonb_build_object('operation','correction_proposal','employer',p_employer,'output',p_output,'case',p_case,'expected',p_expected,'changes',p_changes,'responsibilities',p_rows,'target',p_target,'reason',btrim(p_reason),'reference',btrim(p_reference),'preview_hash',p_preview_hash);
 IF p_operation='save' THEN
  PERFORM payroll.correction_typed_authority(p_tenant,p_changes);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
  IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_output) THEN RAISE EXCEPTION 'payroll_output_superseded' USING ERRCODE='23514';END IF;
 IF p_case IS NOT NULL THEN SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_case FOR UPDATE;
  IF NOT FOUND OR c.original_output<>p_output THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  IF c.revision<>p_expected OR c.status NOT IN('draft','review') THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 ELSIF p_expected<>0 OR EXISTS(SELECT 1 FROM payroll.correction_cases WHERE tenant_id=p_tenant AND original_output=p_output AND status IN('draft','review','approved')) THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 IF p_operation='save' AND p_case IS NOT NULL AND EXISTS(SELECT 1 FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id WHERE m.tenant_id=p_tenant AND m.case_id=p_case AND r.status='approved') THEN RAISE EXCEPTION 'payroll_correction_release_required' USING ERRCODE='23514';END IF;
 compiled:=payroll.compile_source_changes(p_tenant,p_employer,p_changes,a);affected:=payroll.correction_affected_outputs(p_tenant,p_employer,compiled,p_output);PERFORM payroll.assert_correction_material(p_tenant,compiled,affected);
 rows_normalized:=payroll.normalize_correction_responsibilities(p_rows,compiled);PERFORM payroll.validate_correction_responsibilities(p_tenant,p_employer,affected,rows_normalized,p_target,compiled);
 scope:=payroll.correction_scope(p_tenant,p_employer);fingerprint:=payroll.source_hash((intent-'preview_hash')||jsonb_build_object('scope',scope));
 result:=jsonb_build_object('preview_hash',fingerprint,'route',payroll.correction_route(p_tenant,affected),'affected_outputs',COALESCE((SELECT jsonb_agg(value) FROM(SELECT value FROM jsonb_array_elements(affected) LIMIT 30)page),'[]'),'affected_count',jsonb_array_length(affected),'change_count',jsonb_array_length(compiled),'responsibility_count',jsonb_array_length(p_rows),'legal_delta_qualified',false);
 IF p_operation='preview' THEN RETURN result;END IF;
 IF p_preview_hash IS DISTINCT FROM fingerprint THEN RAISE EXCEPTION 'payroll_correction_preview_stale' USING ERRCODE='PT409';END IF;
 IF p_case IS NULL THEN INSERT INTO payroll.correction_cases(tenant_id,employer_id,original_output,created_by) VALUES(p_tenant,p_employer,p_output,a) RETURNING * INTO c;END IF;
 INSERT INTO payroll.correction_proposals(tenant_id,employer_id,case_id,revision,typed_changes,source_changes,source_scope,reason,reference,target_period,responsibilities,created_by) VALUES(p_tenant,p_employer,c.id,c.revision+1,p_changes,compiled,scope||jsonb_build_object('affected_outputs',affected),btrim(p_reason),btrim(p_reference),p_target,rows_normalized,a) RETURNING * INTO proposal;
 UPDATE payroll.correction_cases SET revision=c.revision+1,status='draft',proposal_id=proposal.id WHERE tenant_id=p_tenant AND correction_cases.id=c.id;
 INSERT INTO payroll.correction_request_links SELECT p_tenant,r.id,c.id FROM payroll.correction_requirements r WHERE r.tenant_id=p_tenant AND r.employer_id=p_employer AND EXISTS(SELECT 1 FROM jsonb_array_elements(affected)x WHERE x->>'period_id'=r.period_id::text) AND EXISTS(SELECT 1 FROM jsonb_array_elements(compiled)x WHERE COALESCE(x->'new_row'->>'employment_id',CASE WHEN x->>'source_table'='employments' THEN x->'new_row'->>'id' END)=r.employment_id::text) ON CONFLICT DO NOTHING;
 -- Cancel obsolete amendment candidates, retaining their immutable inputs/results and proposal history.
 UPDATE payroll.runs r SET status='cancelled',revision=r.revision+1,cancelled_by=a,cancelled_at=now(),cancel_reason='Superseded correction proposal' FROM payroll.amendment_runs m WHERE m.tenant_id=r.tenant_id AND m.run_id=r.id AND m.tenant_id=p_tenant AND m.case_id=c.id AND r.status IN('draft','review');
 result:=result||jsonb_build_object('case_id',c.id,'proposal_id',proposal.id,'revision',c.revision+1,'status','draft');
 INSERT INTO payroll.correction_events(tenant_id,case_id,proposal_id,operation,actor_id,reason,details) VALUES(p_tenant,c.id,proposal.id,'proposal_saved',a,p_reason,result);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'correction_proposal_saved',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);PERFORM payroll.correction_typed_authority(p_tenant,p_changes);RETURN result;
END $f$;
CREATE FUNCTION payroll.amendment_manifest(p_tenant uuid,p_run uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE r payroll.runs%ROWTYPE;c payroll.correction_cases%ROWTYPE;p payroll.correction_proposals%ROWTYPE;manifest jsonb;scope jsonb;proof_count integer;BEGIN
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run;
 SELECT case_source.* INTO c FROM payroll.amendment_runs a JOIN payroll.correction_cases case_source ON case_source.tenant_id=a.tenant_id AND case_source.id=a.case_id WHERE a.tenant_id=p_tenant AND a.run_id=p_run;
 SELECT proposal_source.* INTO p FROM payroll.correction_proposals proposal_source JOIN payroll.amendment_runs a ON a.tenant_id=proposal_source.tenant_id AND a.proposal_id=proposal_source.id WHERE a.tenant_id=p_tenant AND a.run_id=p_run;
 IF r.id IS NULL OR c.id IS NULL OR p.id IS NULL OR c.proposal_id<>p.id OR c.status IN('cancelled','routed','completed') THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 scope:=payroll.correction_scope(p_tenant,r.employer_id);
 SELECT count(*) INTO proof_count FROM payroll.correction_source_effects WHERE tenant_id=p_tenant AND proposal_id=p.id AND transaction_id=pg_current_xact_id() AND backend_pid=pg_backend_pid();
 IF p.source_scope-'affected_outputs' IS DISTINCT FROM scope AND NOT(c.status='approved' AND proof_count>0 AND proof_count=jsonb_array_length(p.source_changes)) THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
 manifest:=payroll.overlay_correction(payroll.run_manifest(p_tenant,r.employer_id,r.period_id),p.source_changes,p_tenant);
 manifest:=jsonb_set(manifest,'{original_consumed_adjustments}',COALESCE((SELECT jsonb_agg(i) FROM payroll.final_contexts f CROSS JOIN LATERAL jsonb_array_elements(f.manifest->'inputs')i WHERE f.tenant_id=p_tenant AND f.id=r.amendment_of AND i->'head'->>'kind'='adjustment' AND i->'version'->>'status'='approved'),'[]'));
 manifest:=jsonb_set(manifest,'{corrections}',COALESCE((SELECT jsonb_agg(x ORDER BY x->>'id') FROM jsonb_array_elements(manifest->'corrections')x WHERE NOT EXISTS(SELECT 1 FROM payroll.correction_request_links l WHERE l.tenant_id=p_tenant AND l.case_id=c.id AND l.request_id=(x->>'id')::uuid)),'[]'));
 RETURN manifest||jsonb_build_object('correction_proposal',p.id,'correction_outputs',p.source_scope->'affected_outputs');
END $f$;
CREATE FUNCTION public.payroll_correction_command(p_tenant uuid,p_employer uuid,p_case uuid,p_expected integer,p_operation text,p_reason text,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;c payroll.correction_cases%ROWTYPE;p payroll.correction_proposals%ROWTYPE;r payroll.runs%ROWTYPE;output_row jsonb;item jsonb;receipt payroll.command_receipts%ROWTYPE;intent jsonb;result jsonb;candidate uuid;manifest jsonb;calculated jsonb;head uuid;period payroll.periods%ROWTYPE;amount numeric;extra uuid[];next_status text;BEGIN
 a:=payroll.authorized(p_tenant,'payroll.correct',false);
 IF p_operation IS NULL OR p_operation NOT IN('calculate','approve','release','cancel','route_paid') OR p_expected IS NULL OR p_expected<0 OR p_attempt IS NULL OR length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 IF p_operation='calculate' THEN PERFORM payroll.authorized(p_tenant,'payroll.prepare',false);ELSIF p_operation IN('approve','release') THEN PERFORM payroll.authorized(p_tenant,'payroll.approve',false);END IF;
 SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_case;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO p FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND id=c.proposal_id;
 SELECT COALESCE(array_agg((x->'fields'->>'employee_id')::uuid),'{}') INTO extra FROM jsonb_array_elements(p.typed_changes)x WHERE x->>'type'='new_employment' AND x->'fields'->>'employee_id' IS NOT NULL;
 PERFORM payroll.correction_lock(p_tenant,p_employer,extra);a:=payroll.authorized(p_tenant,'payroll.correct',false);
 IF p_operation='calculate' THEN PERFORM payroll.authorized(p_tenant,'payroll.prepare',false);ELSIF p_operation IN('approve','release') THEN PERFORM payroll.authorized(p_tenant,'payroll.approve',false);END IF;
 intent:=jsonb_build_object('operation','correction_'||p_operation,'employer',p_employer,'case',p_case,'expected',p_expected,'reason',btrim(p_reason));
 IF p_operation NOT IN('release','cancel') THEN PERFORM payroll.correction_source_authority(p_tenant,a,p.source_changes);END IF;
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND id=p_case FOR UPDATE;
 IF c.revision<>p_expected OR c.status IN('routed','completed','cancelled') THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 IF p_operation NOT IN('release','cancel') THEN p:=payroll.correction_current(c);END IF;
 IF p_operation='calculate' THEN
  IF c.status NOT IN('draft','review') OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.source_scope->'affected_outputs')x WHERE NOT(x->>'ever_paid')::boolean) THEN RAISE EXCEPTION 'payroll_paid_correction_route_required' USING ERRCODE='23514';END IF;
  FOR output_row IN SELECT value FROM jsonb_array_elements(p.source_scope->'affected_outputs') WHERE NOT(value->>'ever_paid')::boolean LOOP
   SELECT source_run.* INTO r FROM payroll.runs source_run JOIN payroll.amendment_runs m ON m.tenant_id=source_run.tenant_id AND m.run_id=source_run.id WHERE m.tenant_id=p_tenant AND m.case_id=c.id AND m.proposal_id=p.id AND source_run.amendment_of=(output_row->>'id')::uuid AND source_run.status IN('draft','review','approved');
   IF FOUND AND r.status='approved' THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
   IF NOT FOUND THEN INSERT INTO payroll.runs(tenant_id,employer_id,period_id,amendment_of,created_by,status) VALUES(p_tenant,(output_row->>'employer_id')::uuid,(output_row->>'period_id')::uuid,(output_row->>'id')::uuid,a,'draft') RETURNING * INTO r;INSERT INTO payroll.amendment_runs VALUES(p_tenant,r.id,c.id,p.id);END IF;
   manifest:=payroll.amendment_manifest(p_tenant,r.id);calculated:=payroll.build_correction_review(manifest);
   INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,revision,engine_version,input_manifest,output,created_by) VALUES(p_tenant,r.employer_id,r.id,r.revision+1,manifest->>'engine',manifest,calculated,a) RETURNING id INTO candidate;
   UPDATE payroll.runs SET status='review',revision=r.revision+1,candidate_id=candidate WHERE tenant_id=p_tenant AND id=r.id;
  END LOOP;
  next_status:='review';
 ELSIF p_operation='approve' THEN
  IF c.status NOT IN('draft','review') OR(payroll.correction_route(p_tenant,p.source_scope->'affected_outputs')='paid_correction' AND jsonb_array_length(p.responsibilities)=0) THEN RAISE EXCEPTION 'payroll_correction_responsibility_required' USING ERRCODE='23514';END IF;
  PERFORM payroll.correction_source_authority(p_tenant,a,p.source_changes);
  PERFORM payroll.validate_correction_responsibilities(p_tenant,p_employer,p.source_scope->'affected_outputs',p.responsibilities,p.target_period,p.source_changes);
  next_status:='approved';
 ELSIF p_operation='release' THEN
  IF c.status<>'approved' THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
  next_status:='review';
 ELSIF p_operation='cancel' THEN
  IF c.status='approved' OR EXISTS(SELECT 1 FROM payroll.amendment_runs m JOIN payroll.runs source_run ON source_run.tenant_id=m.tenant_id AND source_run.id=m.run_id WHERE m.tenant_id=p_tenant AND m.case_id=c.id AND source_run.status='approved') THEN RAISE EXCEPTION 'payroll_correction_release_required' USING ERRCODE='23514';END IF;
  UPDATE payroll.runs source_run SET status='cancelled',revision=source_run.revision+1,cancelled_by=a,cancelled_at=now(),cancel_reason=p_reason FROM payroll.amendment_runs m WHERE m.tenant_id=source_run.tenant_id AND m.run_id=source_run.id AND m.tenant_id=p_tenant AND m.case_id=c.id AND source_run.status IN('draft','review');
  next_status:='cancelled';
 ELSE
  IF c.status<>'approved' OR payroll.correction_route(p_tenant,p.source_scope->'affected_outputs')<>'paid_correction' THEN RAISE EXCEPTION 'payroll_paid_correction_route_required' USING ERRCODE='23514';END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(p.responsibilities) WHERE value->>'basis'='period_component' LOOP PERFORM payroll.authorized(p_tenant,'employee_finance.manage',false);PERFORM payroll.authorized(p_tenant,'employee_finance.approve',false);END LOOP;
  PERFORM payroll.validate_correction_responsibilities(p_tenant,p_employer,p.source_scope->'affected_outputs',p.responsibilities,p.target_period,p.source_changes);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p.source_scope->'affected_outputs')x WHERE NOT(x->>'ever_paid')::boolean) THEN RAISE EXCEPTION 'payroll_mixed_dispositions_require_atomic_finalization' USING ERRCODE='23514';END IF;
  PERFORM payroll.apply_correction_sources(c,a);
  PERFORM payroll.route_correction_responsibilities(c,p,a);
  next_status:='routed';
 END IF;
 UPDATE payroll.correction_cases SET status=next_status,revision=c.revision+1 WHERE tenant_id=p_tenant AND id=c.id RETURNING * INTO c;
 result:=jsonb_build_object('case_id',c.id,'proposal_id',c.proposal_id,'revision',c.revision,'status',c.status,'route',payroll.correction_route(p_tenant,p.source_scope->'affected_outputs'),'legal_delta_qualified',false);
 INSERT INTO payroll.correction_events(tenant_id,case_id,proposal_id,operation,actor_id,reason,details) VALUES(p_tenant,c.id,p.id,p_operation,a,p_reason,result);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'correction_'||p_operation,intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);PERFORM payroll.authorized(p_tenant,'payroll.correct',false);IF p_operation NOT IN('release','cancel') THEN PERFORM payroll.correction_source_authority(p_tenant,a,p.source_changes);END IF;RETURN result;
END $f$;

CREATE FUNCTION payroll.route_correction_responsibilities(p_case payroll.correction_cases,p payroll.correction_proposals,p_actor uuid) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE period payroll.periods%ROWTYPE;item jsonb;amount numeric;head uuid;p_tenant uuid:=p_case.tenant_id;p_employer uuid:=p_case.employer_id;a uuid:=p_actor;c payroll.correction_cases:=p_case;BEGIN
 IF p_actor IS DISTINCT FROM payroll.authorized(p_tenant,'payroll.correct',false) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p.responsibilities)x WHERE x->>'basis'='period_component') THEN PERFORM payroll.authorized(p_tenant,'employee_finance.manage',false);PERFORM payroll.authorized(p_tenant,'employee_finance.approve',false);END IF;
  FOR item IN SELECT jsonb_build_object('employment_id',value->>'employment_id','component_id',value->>'component_id','target_period',COALESCE(value->>'target_period',p.target_period::text),'amount',sum((value->>'amount')::numeric),'references',jsonb_agg(value)) FROM jsonb_array_elements(p.responsibilities) WHERE value->>'basis'='period_component' GROUP BY value->>'employment_id',value->>'component_id',COALESCE(value->>'target_period',p.target_period::text) LOOP
   SELECT * INTO period FROM payroll.periods WHERE tenant_id=p_tenant AND id=(item->>'target_period')::uuid;
   amount:=(item->>'amount')::numeric;
   IF amount=0 OR abs(amount)>999999999999.99 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   INSERT INTO payroll.input_heads(tenant_id,employer_id,kind,employment_id,period_id,revision) VALUES(p_tenant,period.employer_id,'adjustment',(item->>'employment_id')::uuid,period.id,1) RETURNING id INTO head;
   INSERT INTO payroll.input_versions(tenant_id,employer_id,head_id,revision,data,effective_from,effective_until,status,created_by,approved_by,approved_at) VALUES(p_tenant,period.employer_id,head,1,jsonb_build_object('component_id',item->>'component_id','amount',abs(amount)::text,'reference',p.reference,'reason',p.reason),period.starts_on,period.ends_on+1,'approved',a,a,now());
   INSERT INTO payroll.correction_targets VALUES(p_tenant,c.id,p.id,(item->>'employment_id')::uuid,head,amount,now());
  END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p.responsibilities)x WHERE x->>'basis'='period_component') THEN PERFORM payroll.authorized(p_tenant,'employee_finance.manage',false);PERFORM payroll.authorized(p_tenant,'employee_finance.approve',false);END IF;
END $f$;
-- Amendment approval uses the exact reviewed overlay; ordinary candidate checks remain unchanged.
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('payroll.approval_readiness(payroll.candidates)'::regprocedure);
 IF d NOT LIKE '%payroll.run_manifest(p_candidate.tenant_id,p_candidate.employer_id%' THEN RAISE EXCEPTION 'unexpected_approval_manifest_anchor';END IF;
 d:=replace(d,'payroll.run_manifest(p_candidate.tenant_id,p_candidate.employer_id,(p_candidate.input_manifest->''period''->>''id'')::uuid)','CASE WHEN EXISTS(SELECT 1 FROM payroll.amendment_runs WHERE tenant_id=p_candidate.tenant_id AND run_id=p_candidate.run_id) THEN payroll.amendment_manifest(p_candidate.tenant_id,p_candidate.run_id) ELSE payroll.run_manifest(p_candidate.tenant_id,p_candidate.employer_id,(p_candidate.input_manifest->''period''->>''id'')::uuid) END');EXECUTE d;
END $f$;
-- Ordinary run entry never selects or mutates a governed amendment accidentally.
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text)'::regprocedure);
 d:=replace(d,'period_id=p_period ORDER BY','period_id=p_period AND amendment_of IS NULL ORDER BY');EXECUTE d;
 d:=pg_get_functiondef('public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 d:=replace(d,'id=p_run FOR UPDATE','id=p_run AND amendment_of IS NULL FOR UPDATE');EXECUTE d;
END $f$;
-- Only an immutable same-period succession permits terminal locked -> superseded.
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('payroll.guard_run_lifecycle()'::regprocedure);
 d:=replace(d,' IF OLD.status IN', ' IF OLD.status=''locked'' AND NEW.status=''superseded'' AND NEW.revision=OLD.revision+1 AND to_jsonb(NEW)-ARRAY[''status'',''revision'']=to_jsonb(OLD)-ARRAY[''status'',''revision''] AND EXISTS(SELECT 1 FROM payroll.final_contexts f JOIN payroll.output_successions s ON s.tenant_id=f.tenant_id AND s.original_output=f.id WHERE f.tenant_id=OLD.tenant_id AND f.run_id=OLD.id) THEN RETURN NEW;END IF; IF OLD.status IN');
 IF d NOT LIKE '%output_successions%' THEN RAISE EXCEPTION 'unexpected_run_lifecycle_anchor';END IF;EXECUTE d;
END $f$;
CREATE FUNCTION payroll.correction_append_authority(p_tenant uuid,p_run uuid) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE a uuid;BEGIN
 IF EXISTS(SELECT 1 FROM payroll.amendment_runs m JOIN payroll.correction_cases c ON c.tenant_id=m.tenant_id AND c.id=m.case_id WHERE m.tenant_id=p_tenant AND m.run_id=p_run AND c.status='approved' AND m.proposal_id=c.proposal_id) THEN
  a:=payroll.authorized(p_tenant,'payroll.lock',false);PERFORM payroll.authorized(p_tenant,'payroll.correct',false);RETURN a;
 END IF;
 RETURN payroll.authorized(p_tenant,'payroll.lock',true);
END $f$;
ALTER FUNCTION payroll.append_final_output(uuid,uuid,uuid,uuid,integer,uuid) RENAME TO append_final_output_single;
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('payroll.append_final_output_single(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
 d:=replace(d,'payroll.authorized(p_tenant,''payroll.lock'',true)','payroll.correction_append_authority(p_tenant,p_run)');EXECUTE d;
END $f$;
-- Private batch: all source effects, all affected approved outputs, and all succession links commit together.
CREATE FUNCTION payroll.append_correction_outputs(p_tenant uuid,p_case uuid,p_expected integer,p_actor uuid,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE c payroll.correction_cases%ROWTYPE;p payroll.correction_proposals%ROWTYPE;r payroll.runs%ROWTYPE;v payroll.candidates%ROWTYPE;o jsonb;replacement uuid;result jsonb:='[]';intent jsonb;receipt payroll.command_receipts%ROWTYPE;BEGIN
 IF p_actor IS DISTINCT FROM payroll.authorized(p_tenant,'payroll.correct',false) OR p_attempt IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND id=p_case;
 IF c.id IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.correction_lock(p_tenant,c.employer_id);PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 SELECT * INTO p FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND id=c.proposal_id;PERFORM payroll.correction_source_authority(p_tenant,p_actor,p.source_changes);
 intent:=jsonb_build_object('operation','private_correction_append','case',p_case,'expected',p_expected);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=p_actor AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND id=p_case FOR UPDATE;
 IF c.revision<>p_expected OR c.status<>'approved' THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 p:=payroll.correction_current(c);
 PERFORM payroll.validate_correction_responsibilities(p_tenant,c.employer_id,p.source_scope->'affected_outputs',p.responsibilities,p.target_period,p.source_changes);
 FOR o IN SELECT value FROM jsonb_array_elements(p.source_scope->'affected_outputs') WHERE NOT(value->>'ever_paid')::boolean ORDER BY value->>'id' LOOP
  SELECT r0.* INTO r FROM payroll.amendment_runs m JOIN payroll.runs r0 ON r0.tenant_id=m.tenant_id AND r0.id=m.run_id WHERE m.tenant_id=p_tenant AND m.case_id=c.id AND m.proposal_id=p.id AND r0.amendment_of=(o->>'id')::uuid AND r0.status='approved';
  SELECT * INTO v FROM payroll.candidates WHERE tenant_id=p_tenant AND run_id=r.id AND id=r.candidate_id;
  IF r.id IS NULL OR v.id IS NULL OR NOT COALESCE((payroll.approval_readiness(v)->>'ready')::boolean,false) THEN RAISE EXCEPTION 'payroll_approval_blocked' USING ERRCODE='23514';END IF;
 END LOOP;
 PERFORM payroll.apply_correction_sources(c,p_actor);
 FOR o IN SELECT value FROM jsonb_array_elements(p.source_scope->'affected_outputs') WHERE NOT(value->>'ever_paid')::boolean ORDER BY value->>'id' LOOP
  SELECT r0.* INTO r FROM payroll.amendment_runs m JOIN payroll.runs r0 ON r0.tenant_id=m.tenant_id AND r0.id=m.run_id WHERE m.tenant_id=p_tenant AND m.case_id=c.id AND m.proposal_id=p.id AND r0.amendment_of=(o->>'id')::uuid AND r0.status='approved';
  replacement:=payroll.append_final_output_single(p_tenant,r.id,r.candidate_id,p_actor,r.revision,gen_random_uuid());
  INSERT INTO payroll.output_successions(tenant_id,original_output,replacement_output,actor_id,reason) VALUES(p_tenant,(o->>'id')::uuid,replacement,p_actor,p.reason);
  UPDATE payroll.runs SET status='superseded',revision=revision+1 WHERE tenant_id=p_tenant AND id=(SELECT run_id FROM payroll.final_contexts WHERE tenant_id=p_tenant AND id=(o->>'id')::uuid);
  result:=result||jsonb_build_array(jsonb_build_object('original_output',o->>'id','replacement_output',replacement));
 END LOOP;
 PERFORM payroll.route_correction_responsibilities(c,p,p_actor);
 UPDATE payroll.correction_cases SET status=CASE WHEN jsonb_array_length(p.responsibilities)>0 THEN 'routed' ELSE 'completed' END,revision=revision+1 WHERE tenant_id=p_tenant AND id=c.id;
 result:=jsonb_build_object('case_id',c.id,'revision',c.revision+1,'replacements',result,'status',CASE WHEN jsonb_array_length(p.responsibilities)>0 THEN 'routed' ELSE 'completed' END);
 INSERT INTO payroll.correction_events(tenant_id,case_id,proposal_id,operation,actor_id,reason,details) VALUES(p_tenant,c.id,p.id,'replace_outputs',p_actor,p.reason,result);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,c.employer_id,p_actor,'correction_outputs_replaced',result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,p_actor,p_attempt,intent,result);PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);RETURN result;
END $f$;
CREATE FUNCTION payroll.append_final_output(p_tenant uuid,p_run uuid,p_candidate uuid,p_actor uuid,p_expected integer,p_attempt uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF EXISTS(SELECT 1 FROM payroll.amendment_runs WHERE tenant_id=p_tenant AND run_id=p_run) THEN RAISE EXCEPTION 'payroll_atomic_correction_required' USING ERRCODE='23514';END IF;
 RETURN payroll.append_final_output_single(p_tenant,p_run,p_candidate,p_actor,p_expected,p_attempt);
END $f$;

CREATE FUNCTION public.payroll_correction_settlement(p_tenant uuid,p_employer uuid,p_case uuid,p_expected integer,p_employment uuid,p_direction text,p_amount numeric,p_date date,p_reference text,p_reason text,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;c payroll.correction_cases%ROWTYPE;p payroll.correction_proposals%ROWTYPE;capacity numeric;recorded numeric;result jsonb;intent jsonb;receipt payroll.command_receipts%ROWTYPE;entry uuid;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
 IF p_direction IS NULL OR p_direction NOT IN('employee_extra_payment','employee_recovery') OR p_amount IS NULL OR p_amount<=0 OR p_amount<>round(p_amount,2) OR p_amount>999999999999.99 OR p_date IS NULL OR p_attempt IS NULL OR length(btrim(COALESCE(p_reference,''))) NOT BETWEEN 3 AND 160 OR length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.correction_lock(p_tenant,p_employer);a:=payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
 intent:=jsonb_build_object('operation','correction_external_evidence','case',p_case,'expected',p_expected,'employment',p_employment,'direction',p_direction,'amount',p_amount,'date',p_date,'reference',btrim(p_reference),'reason',btrim(p_reason));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_case FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF c.revision<>p_expected OR c.status<>'routed' THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 SELECT * INTO p FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND id=c.proposal_id;
 IF p_date>(clock_timestamp() AT TIME ZONE((SELECT period_snapshot->>'timezone' FROM payroll.final_contexts WHERE tenant_id=p_tenant AND id=c.original_output)))::date THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 SELECT COALESCE(sum(abs((x->>'amount')::numeric)),0) INTO capacity FROM jsonb_array_elements(p.responsibilities)x WHERE x->>'basis'='external_reviewed' AND x->>'employment_id'=p_employment::text AND CASE WHEN p_direction='employee_extra_payment' THEN (x->>'amount')::numeric>0 ELSE (x->>'amount')::numeric<0 END;
 SELECT COALESCE(sum(amount),0) INTO recorded FROM payroll.correction_settlements WHERE tenant_id=p_tenant AND proposal_id=p.id AND employment_id=p_employment AND direction=p_direction;
 IF capacity=0 OR recorded+p_amount>capacity THEN RAISE EXCEPTION 'payroll_settlement_excess' USING ERRCODE='23514';END IF;
 INSERT INTO payroll.correction_settlements(tenant_id,case_id,proposal_id,employment_id,direction,amount,occurred_on,reference,reason,actor_id) VALUES(p_tenant,c.id,p.id,p_employment,p_direction,p_amount,p_date,btrim(p_reference),btrim(p_reason),a) RETURNING id INTO entry;
 UPDATE payroll.correction_cases SET revision=revision+1 WHERE tenant_id=p_tenant AND id=c.id;
 result:=jsonb_build_object('id',entry,'case_id',c.id,'revision',c.revision+1,'basis','approved_manual_external','amount',p_amount::text,'responsibility_remaining',(capacity-recorded-p_amount)::text,'original_obligation_unchanged',true,'statutory_delta_qualified',false);
 INSERT INTO payroll.correction_events(tenant_id,case_id,proposal_id,operation,actor_id,reason,details) VALUES(p_tenant,c.id,p.id,'external_evidence',a,btrim(p_reason),intent||result);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'correction_external_evidence',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);RETURN result;
END $f$;
-- Public approval retains legal readiness; amendment closure requires both correction and approval authority.
CREATE FUNCTION payroll.correction_approval_authority(p_tenant uuid,p_run uuid) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF EXISTS(SELECT 1 FROM payroll.amendment_runs m JOIN payroll.correction_cases c ON c.tenant_id=m.tenant_id AND c.id=m.case_id WHERE m.tenant_id=p_tenant AND m.run_id=p_run AND c.proposal_id=m.proposal_id AND c.status IN('draft','review','approved')) THEN PERFORM payroll.authorized(p_tenant,'payroll.correct',false);RETURN payroll.authorized(p_tenant,'payroll.approve',false);END IF;
 RETURN payroll.authorized(p_tenant,'payroll.approve',true);
END $f$;
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);d:=replace(d,'payroll.authorized(p_tenant,''payroll.approve'',true)','payroll.correction_approval_authority(p_tenant,p_run)');EXECUTE d;
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_correction_proposal(uuid,uuid,uuid,uuid,integer,jsonb,jsonb,uuid,text,text,text,text,uuid),public.payroll_correction_command(uuid,uuid,uuid,integer,text,text,uuid),public.payroll_correction_settlement(uuid,uuid,uuid,integer,uuid,text,numeric,date,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_correction_proposal(uuid,uuid,uuid,uuid,integer,jsonb,jsonb,uuid,text,text,text,text,uuid),public.payroll_correction_command(uuid,uuid,uuid,integer,text,text,uuid),public.payroll_correction_settlement(uuid,uuid,uuid,integer,uuid,text,numeric,date,text,text,uuid) TO authenticated;

CREATE FUNCTION public.payroll_correction_workspace(p_tenant uuid,p_employer uuid,p_output uuid,p_case uuid DEFAULT NULL,p_kind text DEFAULT 'compensation',p_employee uuid DEFAULT NULL,p_after uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;f payroll.final_contexts%ROWTYPE;c payroll.correction_cases%ROWTYPE;p payroll.correction_proposals%ROWTYPE;sources jsonb;items jsonb;result jsonb;permission text;BEGIN
 a:=payroll.authorized(p_tenant,'payroll.correct',false);
 IF p_kind IS NULL OR p_kind NOT IN('compensation','assignment','employment','new_employment','input_revision') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO f FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output;
 IF f.id IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 permission:=CASE p_kind WHEN 'compensation' THEN 'compensation.manage' WHEN 'assignment' THEN 'org_context.manage' WHEN 'employment' THEN 'employment.manage' WHEN 'new_employment' THEN 'employment.manage' ELSE NULL END;
 IF permission IS NOT NULL AND NOT(platform_private.has_tenant_permission(p_tenant,auth.uid(),permission) OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT COALESCE(jsonb_agg(x),'[]') INTO items FROM(SELECT h.id,h.employer_entity_id employer_id,e.full_name name,e.employee_code code,h.start_date,h.end_date,h.pay_basis,h.payroll_eligible FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id WHERE h.tenant_id=p_tenant AND(h.employer_entity_id=p_employer OR p_kind='input_revision') AND(p_after IS NULL OR h.id>p_after) ORDER BY h.id LIMIT 30)x;
 IF p_employee IS NOT NULL AND NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND id=p_employee) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT COALESCE(jsonb_agg(jsonb_build_object('id',row_data->>'id','expected_hash',payroll.source_hash(row_data),'fields',row_data-ARRAY['tenant_id','id','created_at','currency_code','employment_id','employee_id','employer_entity_id','employment_status'])),'[]') INTO sources FROM(SELECT row_data FROM(
 SELECT to_jsonb(v) row_data FROM people.compensation_versions v WHERE p_kind='compensation' AND v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.work_assignments v WHERE p_kind='assignment' AND v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.employments v WHERE p_kind='employment' AND v.tenant_id=p_tenant AND v.id=p_employee)rows WHERE p_after IS NULL OR(row_data->>'id')::uuid>p_after ORDER BY row_data->>'id' LIMIT 30)bounded;
 IF p_kind='input_revision' THEN
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id',h.id,'kind',h.kind,'expected_hash',payroll.source_hash(to_jsonb(v)),'fields',jsonb_build_object('data',v.data,'effective_from',v.effective_from,'effective_until',v.effective_until,'cancelled',v.status='cancelled'))),'[]') INTO sources FROM(SELECT * FROM payroll.input_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND(employment_id=p_employee OR employment_id IS NULL) AND(p_after IS NULL OR id>p_after) ORDER BY id LIMIT 30)h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE platform_private.has_tenant_permission(p_tenant,auth.uid(),payroll.input_permission(h.kind,'save')) OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer');
 END IF;
 IF p_case IS NOT NULL THEN
  SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND original_output=p_output AND id=p_case;
  IF c.id IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  SELECT * INTO p FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND id=c.proposal_id;
  PERFORM payroll.correction_source_authority(p_tenant,a,p.source_changes);
 END IF;
 result:=jsonb_build_object('replacement_outputs',COALESCE((SELECT jsonb_agg(jsonb_build_object('original_output',s.original_output,'replacement_output',s.replacement_output,'employer_id',(SELECT employer_id FROM payroll.final_contexts next WHERE next.tenant_id=s.tenant_id AND next.id=s.replacement_output))) FROM payroll.output_successions s WHERE s.tenant_id=p_tenant AND(s.original_output=f.id OR EXISTS(SELECT 1 FROM jsonb_array_elements(p.source_scope->'affected_outputs')o WHERE o->>'id'=s.original_output::text))),'[]'),'employer',f.legal_employer,'period',f.period_snapshot,'today',(clock_timestamp() AT TIME ZONE(f.period_snapshot->>'timezone'))::date,'output_id',f.id,'ever_paid',payroll.output_has_ever_paid(p_tenant,f.id) OR EXISTS(SELECT 1 FROM jsonb_array_elements(p.source_scope->'affected_outputs')o WHERE(o->>'ever_paid')::boolean),'superseded',EXISTS(SELECT 1 FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=f.id),'employees',items,'sources',sources,
 'period_choices',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT id,employer_id,starts_on,ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND(employer_id=p_employer OR p_kind='input_revision') AND starts_on>(f.period_snapshot->>'ends_on')::date AND NOT EXISTS(SELECT 1 FROM payroll.runs r WHERE r.tenant_id=p_tenant AND r.period_id=periods.id AND r.status IN('approved','locked','superseded')) ORDER BY starts_on LIMIT 30)x),'[]'),
 'component_choices',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT h.id,h.employer_id,v.data->>'name' name,v.data->>'classification' classification FROM payroll.input_heads h JOIN LATERAL(SELECT data,status FROM payroll.input_versions WHERE tenant_id=h.tenant_id AND head_id=h.id ORDER BY effective_from DESC,revision DESC LIMIT 1)v ON true WHERE h.tenant_id=p_tenant AND(h.employer_id=p_employer OR p_kind='input_revision') AND h.kind='component' AND v.status<>'cancelled' AND v.data->>'active'='true' AND v.data->>'calculation'='fixed' AND v.data->>'behavior'='period_input' AND v.data->>'classification' IN('earning','deduction') ORDER BY h.id LIMIT 30)x),'[]'),
 'output_choices',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT output_source.id,output_source.employer_id,output_source.legal_employer->>'display_name' employer,period_source.starts_on,period_source.ends_on,payroll.output_has_ever_paid(output_source.tenant_id,output_source.id) ever_paid FROM payroll.final_contexts output_source JOIN payroll.periods period_source ON period_source.tenant_id=output_source.tenant_id AND period_source.id=output_source.period_id WHERE output_source.tenant_id=p_tenant AND(output_source.employer_id=p_employer OR p_kind='input_revision') AND NOT EXISTS(SELECT 1 FROM payroll.output_successions z WHERE z.tenant_id=output_source.tenant_id AND z.original_output=output_source.id) ORDER BY period_source.starts_on DESC LIMIT 30)x),'[]'),
 'references',CASE WHEN p_kind IN('assignment','new_employment') THEN jsonb_build_object('employee_id',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT e.id,e.full_name name FROM people.employees e WHERE e.tenant_id=p_tenant AND EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=e.tenant_id AND h.employee_id=e.id AND h.employer_entity_id=p_employer) ORDER BY e.id LIMIT 30)x),'[]'),'department_id',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT id,name FROM people.departments WHERE tenant_id=p_tenant AND is_active ORDER BY id LIMIT 30)x),'[]'),'job_id',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT id,name FROM people.jobs WHERE tenant_id=p_tenant AND is_active ORDER BY id LIMIT 30)x),'[]'),'manager_employee_id',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT e.id,e.full_name name FROM people.employees e WHERE e.tenant_id=p_tenant AND e.workforce_status='active' AND EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=e.tenant_id AND h.employee_id=e.id AND h.employer_entity_id=p_employer) ORDER BY e.id LIMIT 30)x),'[]'),'work_policy_template_id',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT template_id id,name,version FROM time.work_policy_versions WHERE tenant_id=p_tenant ORDER BY template_id,version DESC LIMIT 30)x),'[]')) ELSE '{}'::jsonb END,
 'sites',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT id,display_name name FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND legal_entity_id=p_employer AND is_active ORDER BY id LIMIT 30)x),'[]'),
 'case',CASE WHEN c.id IS NOT NULL THEN jsonb_build_object('id',c.id,'revision',c.revision,'status',c.status,'proposal_id',c.proposal_id,'reason',p.reason,'reference',p.reference,'changes',p.typed_changes,'responsibilities',p.responsibilities,'target_period',p.target_period,'affected_outputs',COALESCE((SELECT jsonb_agg(value) FROM(SELECT value FROM jsonb_array_elements(p.source_scope->'affected_outputs') LIMIT 30)page),'[]'),'affected_count',jsonb_array_length(p.source_scope->'affected_outputs')) END,
 'access',jsonb_build_object('can_view_final',platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.view'),'can_view_payments',platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.view') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.payment_record'),'can_prepare',platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.prepare'),'can_approve',platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.approve'),'can_record',platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.payment_record')),
 'amendments',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',r.id,'period_id',r.period_id,'revision',r.revision,'status',r.status,'candidate_id',r.candidate_id,'approval',CASE WHEN r.status IN('review','approved') THEN payroll.approval_readiness(v) END,'issues',CASE WHEN r.status IN('review','approved') THEN v.output->'issues' END)) FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id LEFT JOIN payroll.candidates v ON v.tenant_id=r.tenant_id AND v.id=r.candidate_id WHERE m.tenant_id=p_tenant AND m.case_id=c.id AND m.proposal_id=p.id),'[]'),
 'settlements',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT employment_id,direction,amount,occurred_on,reference,reason,actor_id,created_at FROM payroll.correction_settlements WHERE tenant_id=p_tenant AND case_id=c.id ORDER BY created_at DESC LIMIT 20)x),'[]'),
 'history',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT id,status,revision,created_at FROM payroll.correction_cases WHERE tenant_id=p_tenant AND original_output=p_output ORDER BY created_at DESC LIMIT 20)x),'[]'));
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'correction_workspace_access',jsonb_build_object('output',p_output,'case',p_case,'kind',p_kind,'employment',p_employee));RETURN result;
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_correction_workspace(uuid,uuid,uuid,uuid,text,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_correction_workspace(uuid,uuid,uuid,uuid,text,uuid,uuid) TO authenticated;

CREATE FUNCTION public.payroll_correction_access(p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant AND user_id=auth.uid() AND access_state='active') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('can_correct',platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.correct'));
END $f$;
CREATE FUNCTION public.payroll_correction_outputs(p_tenant uuid,p_employer uuid DEFAULT NULL,p_person uuid DEFAULT NULL,p_after uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;result jsonb;employer uuid;BEGIN
 a:=payroll.authorized(p_tenant,'payroll.correct',false);
 SELECT COALESCE(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM(SELECT f.id,f.employer_id,f.period_id,f.legal_employer->>'display_name' employer,p.starts_on,p.ends_on,payroll.output_has_ever_paid(f.tenant_id,f.id) ever_paid FROM payroll.final_contexts f JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id WHERE f.tenant_id=p_tenant AND(p_employer IS NULL OR f.employer_id=p_employer) AND(p_after IS NULL OR f.id>p_after) AND NOT EXISTS(SELECT 1 FROM payroll.output_successions s WHERE s.tenant_id=f.tenant_id AND s.original_output=f.id) AND(p_person IS NULL OR EXISTS(SELECT 1 FROM payroll.final_employees e JOIN people.employments h ON h.tenant_id=e.tenant_id AND h.id=e.employment_id WHERE e.tenant_id=f.tenant_id AND e.output_id=f.id AND h.employee_id=p_person)) ORDER BY f.id LIMIT 30)x;
 FOR employer IN SELECT DISTINCT(value->>'employer_id')::uuid FROM jsonb_array_elements(result) LOOP INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,employer,a,'correction_output_discovery',jsonb_build_object('person',p_person,'after',p_after));END LOOP;RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_correction_access(uuid),public.payroll_correction_outputs(uuid,uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_correction_access(uuid),public.payroll_correction_outputs(uuid,uuid,uuid,uuid) TO authenticated;

-- Historical viewers can follow the immutable successor without reading money through correction navigation.
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.payroll_final_output(uuid,uuid,uuid,uuid,uuid,integer,boolean)'::regprocedure);
 IF d NOT LIKE '%''superseded'',superseded%' THEN RAISE EXCEPTION 'unexpected_final_successor_anchor';END IF;
 d:=replace(d,'''superseded'',superseded','''replacement_output_id'',(SELECT replacement_output FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_output),''superseded'',superseded');EXECUTE d;
END $f$;

CREATE FUNCTION payroll.correction_review_state(p_candidate payroll.candidates) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 RETURN payroll.approval_readiness(p_candidate);
EXCEPTION WHEN SQLSTATE 'PT409' THEN RETURN jsonb_build_object('ready',false,'blocking_count',1,'stale_reasons',jsonb_build_array('correction_scope_changed'));
END $f$;
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.payroll_correction_workspace(uuid,uuid,uuid,uuid,text,uuid,uuid)'::regprocedure);
 d:=replace(d,'payroll.approval_readiness(v)','payroll.correction_review_state(v)');EXECUTE d;
 d:=pg_get_functiondef('public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 d:=replace(d,' readiness:=payroll.approval_readiness(c);',' IF p_operation=''approve'' AND EXISTS(SELECT 1 FROM payroll.amendment_runs m JOIN payroll.correction_cases head ON head.tenant_id=m.tenant_id AND head.id=m.case_id WHERE m.tenant_id=p_tenant AND m.run_id=p_run AND(head.status<>''approved'' OR head.proposal_id<>m.proposal_id)) THEN RAISE EXCEPTION ''payroll_correction_proposal_approval_required'' USING ERRCODE=''23514'';END IF; readiness:=payroll.approval_readiness(c);');
 IF d NOT LIKE '%payroll_correction_proposal_approval_required%' THEN RAISE EXCEPTION 'unexpected_child_approval_anchor';END IF;EXECUTE d;
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;

DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 d:=replace(d,'readiness:=payroll.approval_readiness(c);','readiness:=CASE WHEN p_operation=''approve'' THEN payroll.approval_readiness(c) ELSE jsonb_build_object(''ready'',false,''stale_reasons'',''[]''::jsonb) END;');EXECUTE d;
END $f$;

-- Applied means consumed by the original, not cancelled. Reuse only its exact preserved approved adjustment basis.
CREATE FUNCTION payroll.build_correction_review(p_manifest jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE calculation_manifest jsonb;inputs jsonb;BEGIN
 SELECT COALESCE(jsonb_agg(CASE WHEN i->'head'->>'kind'='adjustment' AND i->'version'->>'status'='applied' AND EXISTS(SELECT 1 FROM jsonb_array_elements(p_manifest->'original_consumed_adjustments')original WHERE original->'head'->>'id'=i->'head'->>'id' AND original->'version'->'data'=i->'version'->'data' AND original->'version'->'effective_from'=i->'version'->'effective_from' AND original->'version'->'effective_until' IS NOT DISTINCT FROM i->'version'->'effective_until') THEN jsonb_set(i,'{version,status}','"approved"') ELSE i END ORDER BY i->'head'->>'id',(i->'version'->>'revision')::integer),'[]') INTO inputs FROM jsonb_array_elements(p_manifest->'inputs')i;
 calculation_manifest:=jsonb_set(p_manifest,'{inputs}',inputs);
 RETURN payroll.build_review(calculation_manifest);
END $f$;
DO $f$ DECLARE d text;BEGIN
 d:=pg_get_functiondef('public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 d:=replace(d,' IF p_run IS NULL THEN',' IF p_run IS NULL AND EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period) THEN RAISE EXCEPTION ''payroll_correction_required'' USING ERRCODE=''23514'';END IF; IF p_run IS NULL THEN');
 IF d NOT LIKE '%payroll.correction_required%' AND d NOT LIKE '%payroll_correction_required%' THEN RAISE EXCEPTION 'unexpected_final_period_command_anchor';END IF;EXECUTE d;
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;

-- An amendment always retains the exact legal Employer and immutable period of its original.
CREATE FUNCTION payroll.guard_amendment_identity() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF TG_OP='UPDATE' AND NEW.amendment_of IS DISTINCT FROM OLD.amendment_of THEN RAISE EXCEPTION 'payroll_immutable' USING ERRCODE='55000';END IF;
 IF NEW.amendment_of IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=NEW.tenant_id AND f.id=NEW.amendment_of AND f.employer_id=NEW.employer_id AND f.period_id=NEW.period_id) THEN RAISE EXCEPTION 'payroll_amendment_scope_invalid' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER amendment_identity BEFORE INSERT OR UPDATE ON payroll.runs FOR EACH ROW EXECUTE FUNCTION payroll.guard_amendment_identity();
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;


-- S6-R5: independently paged purpose-scoped metadata and source choices, never a company manifest.
CREATE FUNCTION public.payroll_correction_choices(p_tenant uuid,p_employer uuid,p_output uuid,p_kind text,p_choice text,p_query text DEFAULT '',p_after text DEFAULT NULL,p_selected uuid DEFAULT NULL,p_version integer DEFAULT NULL,p_employee uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;f payroll.final_contexts%ROWTYPE;permission text;result jsonb;BEGIN
 actor:=payroll.authorized(p_tenant,'payroll.correct',false);
 SELECT * INTO f FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output;
 IF f.id IS NULL OR p_kind NOT IN('compensation','assignment','employment','new_employment','input_revision') OR p_choice NOT IN('employees','sources','site_id','department_id','job_id','manager_employee_id','work_policy_template_id','employee_id','periods','components','outputs') OR length(COALESCE(p_query,''))>120 OR(p_after IS NOT NULL AND p_after!~'^[0-9a-f-]{36}:[0-9]{10}$') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 permission:=CASE p_kind WHEN 'compensation' THEN 'compensation.manage' WHEN 'assignment' THEN 'org_context.manage' WHEN 'employment' THEN 'employment.manage' WHEN 'new_employment' THEN 'employment.manage' END;
 IF permission IS NOT NULL AND NOT(platform_private.has_tenant_permission(p_tenant,auth.uid(),permission) OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_choice IN('department_id','job_id','manager_employee_id','work_policy_template_id') AND p_kind<>'assignment' OR p_choice IN('site_id','employee_id') AND p_kind NOT IN('assignment','new_employment') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_choice IN('department_id','job_id','manager_employee_id','work_policy_template_id','site_id') AND NOT(platform_private.has_tenant_permission(p_tenant,auth.uid(),'org_context.manage') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_employee IS NOT NULL AND NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND id=p_employee AND(employer_entity_id=p_employer OR p_kind='input_revision')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 WITH choices AS(
 SELECT h.id,0 version,e.full_name||' · '||e.employee_code name,jsonb_build_object('id',h.id,'name',e.full_name||' · '||e.employee_code,'employer_id',h.employer_entity_id) item FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id WHERE p_choice='employees' AND h.tenant_id=p_tenant AND(h.employer_entity_id=p_employer OR p_kind='input_revision')
 UNION ALL SELECT e.id,0,e.full_name||' · '||e.employee_code,jsonb_build_object('id',e.id,'name',e.full_name||' · '||e.employee_code) FROM people.employees e WHERE p_choice='employee_id' AND e.tenant_id=p_tenant
 UNION ALL SELECT s.id,0,s.display_name,jsonb_build_object('id',s.id,'name',s.display_name) FROM platform_core.tenant_sites s WHERE p_choice='site_id' AND s.tenant_id=p_tenant AND s.legal_entity_id=p_employer AND(s.is_active OR s.id=p_selected)
 UNION ALL SELECT d.id,0,d.name,jsonb_build_object('id',d.id,'name',d.name) FROM people.departments d WHERE p_choice='department_id' AND d.tenant_id=p_tenant AND(d.is_active OR d.id=p_selected)
 UNION ALL SELECT j.id,0,j.name,jsonb_build_object('id',j.id,'name',j.name) FROM people.jobs j WHERE p_choice='job_id' AND j.tenant_id=p_tenant AND(j.is_active OR j.id=p_selected)
 UNION ALL SELECT e.id,0,e.full_name,jsonb_build_object('id',e.id,'name',e.full_name) FROM people.employees e WHERE p_choice='manager_employee_id' AND e.tenant_id=p_tenant AND(e.workforce_status='active' OR e.id=p_selected) AND EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=e.tenant_id AND h.employee_id=e.id AND h.employer_entity_id=p_employer)
 UNION ALL SELECT w.template_id,w.version,w.name||' · نسخة '||w.version,jsonb_build_object('id',w.template_id,'name',w.name||' · نسخة '||w.version,'version',w.version) FROM time.work_policy_versions w WHERE p_choice='work_policy_template_id' AND w.tenant_id=p_tenant
 UNION ALL SELECT period.id,0,period.starts_on||' — '||period.ends_on||' · '||le.display_name,jsonb_build_object('id',period.id,'name',period.starts_on||' — '||period.ends_on||' · '||le.display_name,'employer_id',period.employer_id) FROM payroll.periods period JOIN platform_core.tenant_legal_entities le ON le.tenant_id=period.tenant_id AND le.id=period.employer_id WHERE p_choice='periods' AND period.tenant_id=p_tenant AND(period.employer_id=p_employer OR p_kind='input_revision') AND period.starts_on>(f.period_snapshot->>'ends_on')::date AND NOT EXISTS(SELECT 1 FROM payroll.runs r WHERE r.tenant_id=period.tenant_id AND r.period_id=period.id AND r.status IN('approved','locked','superseded'))
 UNION ALL SELECT h.id,0,v.data->>'name',jsonb_build_object('id',h.id,'name',v.data->>'name','classification',v.data->>'classification','employer_id',h.employer_id) FROM payroll.input_heads h JOIN LATERAL(SELECT * FROM payroll.input_versions WHERE tenant_id=h.tenant_id AND head_id=h.id ORDER BY effective_from DESC,revision DESC LIMIT 1)v ON true WHERE p_choice='components' AND h.tenant_id=p_tenant AND(h.employer_id=p_employer OR p_kind='input_revision') AND h.kind='component' AND(v.status<>'cancelled' AND v.data->>'active'='true' OR h.id=p_selected)
 UNION ALL SELECT c.id,0,period.starts_on||' — '||period.ends_on||' · '||(c.legal_employer->>'display_name'),jsonb_build_object('id',c.id,'name',period.starts_on||' — '||period.ends_on||' · '||(c.legal_employer->>'display_name'),'employer_id',c.employer_id) FROM payroll.final_contexts c JOIN payroll.periods period ON period.tenant_id=c.tenant_id AND period.id=c.period_id WHERE p_choice='outputs' AND c.tenant_id=p_tenant AND(c.employer_id=p_employer OR p_kind='input_revision') AND NOT EXISTS(SELECT 1 FROM payroll.output_successions z WHERE z.tenant_id=c.tenant_id AND z.original_output=c.id)
 UNION ALL SELECT (row_data->>'id')::uuid,0,COALESCE(row_data->>'valid_from',row_data->>'start_date'),'{}'::jsonb||jsonb_build_object('id',row_data->>'id','name',COALESCE(row_data->>'valid_from',row_data->>'start_date')||' — '||COALESCE(row_data->>'valid_until',row_data->>'end_date','مستمر'),'expected_hash',payroll.source_hash(row_data),'fields',row_data-ARRAY['tenant_id','id','created_at','currency_code','employment_id','employee_id','employer_entity_id','employment_status']) FROM(SELECT to_jsonb(v) row_data FROM people.compensation_versions v WHERE p_choice='sources' AND p_kind='compensation' AND v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.work_assignments v WHERE p_choice='sources' AND p_kind='assignment' AND v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.employments v WHERE p_choice='sources' AND p_kind='employment' AND v.tenant_id=p_tenant AND v.id=p_employee) source_rows
 UNION ALL SELECT h.id,0,h.kind||' · '||COALESCE(v.data->>'name',v.data->>'reference',v.effective_from::text),jsonb_build_object('id',h.id,'name',h.kind||' · '||COALESCE(v.data->>'name',v.data->>'reference',v.effective_from::text),'kind',h.kind,'expected_hash',payroll.source_hash(to_jsonb(v)),'fields',jsonb_build_object('data',v.data,'effective_from',v.effective_from,'effective_until',v.effective_until,'cancelled',v.status='cancelled')) FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE p_choice='sources' AND p_kind='input_revision' AND h.tenant_id=p_tenant AND(h.employer_id=p_employer OR h.kind='policy') AND(h.employment_id=p_employee OR h.employment_id IS NULL) AND(platform_private.has_tenant_permission(p_tenant,auth.uid(),payroll.input_permission(h.kind,'save')) OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer'))
 ),scoped AS(SELECT *,id::text||':'||lpad(version::text,10,'0') cursor FROM choices),page AS(SELECT * FROM scoped WHERE(p_after IS NULL OR cursor>p_after) AND name ILIKE '%'||COALESCE(p_query,'')||'%' ORDER BY cursor LIMIT 30)
 SELECT jsonb_build_object('items',COALESCE((SELECT jsonb_agg(item||jsonb_build_object('cursor',cursor) ORDER BY cursor) FROM page),'[]'),'next',CASE WHEN(SELECT count(*) FROM page)=30 THEN(SELECT max(cursor) FROM page) END,'selected',(SELECT item FROM scoped WHERE id=p_selected AND(p_version IS NULL OR version=p_version) ORDER BY version DESC LIMIT 1)) INTO result;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,actor,'correction_choice_access',jsonb_build_object('output',p_output,'kind',p_kind,'choice',p_choice,'after',p_after));RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_correction_choices(uuid,uuid,uuid,text,text,text,text,uuid,integer,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_correction_choices(uuid,uuid,uuid,text,text,text,text,uuid,integer,uuid) TO authenticated;

-- Recovery closes an uncommitted attempt under the same tenant source fence as writers.
CREATE TABLE payroll.correction_attempt_closures(
 tenant_id uuid NOT NULL,actor_id uuid NOT NULL,attempt_key uuid NOT NULL,
 employer_id uuid NOT NULL,output_id uuid NOT NULL,intent jsonb NOT NULL,
 closed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,actor_id,attempt_key),
 FOREIGN KEY(tenant_id,output_id) REFERENCES payroll.final_contexts(tenant_id,id));
ALTER TABLE payroll.correction_attempt_closures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.correction_attempt_closures FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.correction_attempt_closures FOR EACH ROW EXECUTE FUNCTION payroll.immutable();

CREATE FUNCTION payroll.assert_correction_attempt_open(p_tenant uuid,p_actor uuid,p_attempt uuid,p_intent jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE closed payroll.correction_attempt_closures%ROWTYPE;BEGIN
 SELECT * INTO closed FROM payroll.correction_attempt_closures WHERE tenant_id=p_tenant AND actor_id=p_actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF closed.intent IS DISTINCT FROM p_intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  RAISE EXCEPTION 'payroll_attempt_closed' USING ERRCODE='PT409';
 END IF;
END $f$;

CREATE FUNCTION public.payroll_correction_reconcile(p_tenant uuid,p_employer uuid,p_output uuid,p_rpc text,p_args jsonb,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;intent jsonb;receipt payroll.command_receipts%ROWTYPE;closed payroll.correction_attempt_closures%ROWTYPE;
 case_row payroll.correction_cases%ROWTYPE;proposal payroll.correction_proposals%ROWTYPE;run_row payroll.runs%ROWTYPE;
 operation text;expected integer;case_id uuid;keys text[];change jsonb;source_employer uuid;result jsonb;
BEGIN
 actor:=payroll.authorized(p_tenant,'payroll.correct',false);
 IF p_attempt IS NULL OR jsonb_typeof(p_args) IS DISTINCT FROM 'object' OR octet_length(p_args::text)>200000 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 IF (p_args->>'p_tenant')::uuid IS DISTINCT FROM p_tenant OR (p_args->>'p_employer')::uuid IS DISTINCT FROM p_employer THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 operation:=p_args->>'p_operation';expected:=(p_args->>'p_expected')::integer;case_id:=(p_args->>'p_case')::uuid;
 IF expected IS NULL OR expected<0 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 PERFORM set_config('lock_timeout','5s',true);
 PERFORM payroll.correction_lock(p_tenant,p_employer);
 actor:=payroll.authorized(p_tenant,'payroll.correct',false);
 IF NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_rpc='payroll_correction_proposal' THEN
  keys:=ARRAY['p_tenant','p_employer','p_output','p_case','p_expected','p_changes','p_rows','p_target','p_reason','p_reference','p_preview_hash','p_operation'];
  IF operation IS DISTINCT FROM 'save' OR (p_args->>'p_output')::uuid IS DISTINCT FROM p_output OR jsonb_typeof(p_args->'p_changes') IS DISTINCT FROM 'array' OR jsonb_array_length(p_args->'p_changes') NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  PERFORM payroll.correction_typed_authority(p_tenant,p_args->'p_changes');
  FOR change IN SELECT value FROM jsonb_array_elements(p_args->'p_changes') LOOP
   source_employer:=NULL;
   IF change->>'type' IN('compensation','compensation_split') THEN SELECT h.employer_entity_id INTO source_employer FROM people.compensation_versions v JOIN people.employments h ON h.tenant_id=v.tenant_id AND h.id=v.employment_id WHERE v.tenant_id=p_tenant AND v.id=(change->>'source_id')::uuid;
   ELSIF change->>'type' IN('assignment','assignment_split') THEN SELECT h.employer_entity_id INTO source_employer FROM people.work_assignments v JOIN people.employments h ON h.tenant_id=v.tenant_id AND h.id=v.employment_id WHERE v.tenant_id=p_tenant AND v.id=(change->>'source_id')::uuid;
   ELSIF change->>'type'='employment' THEN SELECT employer_entity_id INTO source_employer FROM people.employments WHERE tenant_id=p_tenant AND id=(change->>'source_id')::uuid;
   ELSIF change->>'type'='input_revision' THEN SELECT employer_id INTO source_employer FROM payroll.input_heads WHERE tenant_id=p_tenant AND id=(change->>'source_id')::uuid AND(employer_id=p_employer OR kind='policy');IF FOUND AND source_employer IS NULL THEN source_employer:=p_employer;END IF;
   ELSIF change->>'type'='new_employment' THEN
    IF change->'fields'->>'employee_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM people.employees WHERE tenant_id=p_tenant AND id=(change->'fields'->>'employee_id')::uuid) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;source_employer:=p_employer;
   ELSE RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   IF source_employer IS DISTINCT FROM p_employer THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  END LOOP;
  IF case_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=case_id AND original_output=p_output) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  intent:=jsonb_build_object('operation','correction_proposal','employer',p_employer,'output',p_output,'case',case_id,'expected',expected,'changes',p_args->'p_changes','responsibilities',p_args->'p_rows','target',(p_args->>'p_target')::uuid,'reason',btrim(p_args->>'p_reason'),'reference',btrim(p_args->>'p_reference'),'preview_hash',p_args->>'p_preview_hash');
 ELSIF p_rpc IN('payroll_correction_command','payroll_correction_settlement') THEN
  SELECT * INTO case_row FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=case_id AND original_output=p_output;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  SELECT * INTO proposal FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND id=case_row.proposal_id;
  IF p_rpc='payroll_correction_command' THEN
   keys:=ARRAY['p_tenant','p_employer','p_case','p_expected','p_operation','p_reason'];
   IF operation IS NULL OR operation NOT IN('calculate','approve','release','cancel','route_paid') THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   IF operation='calculate' THEN PERFORM payroll.authorized(p_tenant,'payroll.prepare',false);ELSIF operation IN('approve','release') THEN PERFORM payroll.authorized(p_tenant,'payroll.approve',false);END IF;
   IF operation NOT IN('release','cancel') THEN PERFORM payroll.correction_source_authority(p_tenant,actor,proposal.source_changes);END IF;
   intent:=jsonb_build_object('operation','correction_'||operation,'employer',p_employer,'case',case_id,'expected',expected,'reason',btrim(p_args->>'p_reason'));
  ELSE
   keys:=ARRAY['p_tenant','p_employer','p_case','p_expected','p_employment','p_direction','p_amount','p_date','p_reference','p_reason'];
   PERFORM payroll.authorized(p_tenant,'payroll.payment_record',false);
   IF NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND id=(p_args->>'p_employment')::uuid) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
   intent:=jsonb_build_object('operation','correction_external_evidence','case',case_id,'expected',expected,'employment',(p_args->>'p_employment')::uuid,'direction',p_args->>'p_direction','amount',(p_args->>'p_amount')::numeric,'date',(p_args->>'p_date')::date,'reference',btrim(p_args->>'p_reference'),'reason',btrim(p_args->>'p_reason'));
  END IF;
 ELSIF p_rpc='payroll_candidate_approval' THEN
  keys:=ARRAY['p_tenant','p_employer','p_period','p_run','p_candidate','p_expected','p_operation','p_reason'];
  IF operation IS NULL OR operation NOT IN('approve','release') THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  SELECT * INTO run_row FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=(p_args->>'p_period')::uuid AND id=(p_args->>'p_run')::uuid;
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM payroll.candidates WHERE tenant_id=p_tenant AND employer_id=p_employer AND run_id=run_row.id AND id=(p_args->>'p_candidate')::uuid) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  SELECT c.* INTO case_row FROM payroll.amendment_runs m JOIN payroll.correction_cases c ON c.tenant_id=m.tenant_id AND c.id=m.case_id WHERE m.tenant_id=p_tenant AND m.run_id=run_row.id AND c.employer_id=p_employer AND c.original_output=p_output;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  SELECT * INTO proposal FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND id=case_row.proposal_id;
  PERFORM payroll.authorized(p_tenant,'payroll.approve',false);PERFORM payroll.correction_source_authority(p_tenant,actor,proposal.source_changes);
  intent:=jsonb_build_object('operation','candidate_'||operation,'employer',p_employer,'period',(p_args->>'p_period')::uuid,'run',run_row.id,'candidate',(p_args->>'p_candidate')::uuid,'expected',expected,'reason',btrim(p_args->>'p_reason'));
 ELSE RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 IF p_args-keys<>'{}'::jsonb OR NOT p_args ?& keys THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF receipt.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  RETURN jsonb_build_object('outcome','committed','result',receipt.result);
 END IF;
 SELECT * INTO closed FROM payroll.correction_attempt_closures WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF closed.intent IS DISTINCT FROM intent OR closed.output_id<>p_output OR closed.employer_id<>p_employer THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
 ELSE
  INSERT INTO payroll.correction_attempt_closures(tenant_id,actor_id,attempt_key,employer_id,output_id,intent) VALUES(p_tenant,actor,p_attempt,p_employer,p_output,intent);
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,actor,'correction_attempt_closed',jsonb_build_object('attempt',p_attempt,'output',p_output,'operation',intent->>'operation'));
 END IF;
 RETURN jsonb_build_object('outcome','closed_uncommitted');
END $f$;
REVOKE ALL ON FUNCTION payroll.assert_correction_attempt_open(uuid,uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_correction_reconcile(uuid,uuid,uuid,text,jsonb,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_correction_reconcile(uuid,uuid,uuid,text,jsonb,uuid) TO authenticated;

-- Preserve each writer's exact intent and full authority checks. The tenant fence is
-- acquired before this check, so reconciliation and a delayed writer cannot both win.
DO $f$
DECLARE signature text;definition text;anchor text;replacement text;BEGIN
 FOREACH signature IN ARRAY ARRAY[
 'public.payroll_correction_proposal(uuid,uuid,uuid,uuid,integer,jsonb,jsonb,uuid,text,text,text,text,uuid)',
 'public.payroll_correction_command(uuid,uuid,uuid,integer,text,text,uuid)',
 'public.payroll_correction_settlement(uuid,uuid,uuid,integer,uuid,text,numeric,date,text,text,uuid)',
 'public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid)'] LOOP
  definition:=pg_get_functiondef(signature::regprocedure);
  anchor:='SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;';
  replacement:='PERFORM payroll.assert_correction_attempt_open(p_tenant,a,p_attempt,intent); '||anchor;
  IF strpos(definition,anchor)=0 OR strpos(definition,'payroll.assert_correction_attempt_open')>0 THEN RAISE EXCEPTION 'unexpected_correction_attempt_fence_anchor';END IF;
  EXECUTE replace(definition,anchor,replacement);
 END LOOP;
END $f$;
