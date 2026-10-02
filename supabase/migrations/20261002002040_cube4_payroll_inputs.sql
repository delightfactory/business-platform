-- Cube 4 Slice 2: reviewed inputs only. No monetary calculation, consumption or public lock.
CREATE TABLE payroll.input_heads (
 tenant_id uuid NOT NULL, employer_id uuid NOT NULL, id uuid NOT NULL DEFAULT gen_random_uuid(),
 kind text NOT NULL CHECK(kind IN('component','recurring','manual_units','adjustment','opening_ytd','policy')),
 employment_id uuid, period_id uuid, revision integer NOT NULL DEFAULT 0,
 PRIMARY KEY(tenant_id,id), UNIQUE(tenant_id,employer_id,id),
 FOREIGN KEY(tenant_id,employer_id) REFERENCES platform_core.tenant_legal_entities(tenant_id,id),
 FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id),
 FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id));
CREATE UNIQUE INDEX payroll_policy_once ON payroll.input_heads(tenant_id) WHERE kind='policy';
CREATE TABLE payroll.input_versions (
 tenant_id uuid NOT NULL, employer_id uuid NOT NULL, id uuid NOT NULL DEFAULT gen_random_uuid(), head_id uuid NOT NULL,
 revision integer NOT NULL, data jsonb NOT NULL, effective_from date NOT NULL, effective_until date,
 status text NOT NULL CHECK(status IN('draft','approved','cancelled','applied')),
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 approved_by uuid REFERENCES auth.users(id), approved_at timestamptz,
 PRIMARY KEY(tenant_id,id), UNIQUE(tenant_id,head_id,revision),
 FOREIGN KEY(tenant_id,employer_id,head_id) REFERENCES payroll.input_heads(tenant_id,employer_id,id),
 CHECK(effective_until IS NULL OR effective_until>effective_from),
 CHECK((status<>'approved') OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)));
CREATE TRIGGER payroll_input_version_immutable BEFORE UPDATE OR DELETE ON payroll.input_versions FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
-- Future calculation/lock consumers register immutable evidence privately, under E -> H -> Employer.
CREATE TABLE payroll.people_frozen_contexts (
 tenant_id uuid NOT NULL, employer_id uuid NOT NULL, employment_id uuid NOT NULL, period_id uuid NOT NULL,
 run_id uuid NOT NULL, source_snapshot jsonb NOT NULL, registered_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,run_id,employment_id),
 FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id),
 FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id),
 FOREIGN KEY(tenant_id,employer_id) REFERENCES platform_core.tenant_legal_entities(tenant_id,id));
CREATE TRIGGER payroll_people_context_immutable BEFORE UPDATE OR DELETE ON payroll.people_frozen_contexts FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
CREATE TABLE payroll.correction_requirements (
 tenant_id uuid NOT NULL, employer_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),employment_id uuid NOT NULL,
 period_id uuid NOT NULL,reason text NOT NULL,requested_by uuid NOT NULL REFERENCES auth.users(id),requested_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id), FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id),
 FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id));
CREATE TRIGGER payroll_correction_requirement_immutable BEFORE UPDATE OR DELETE ON payroll.correction_requirements FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
ALTER TABLE payroll.input_heads ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.input_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.people_frozen_contexts ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.correction_requirements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.input_heads,payroll.input_versions,payroll.people_frozen_contexts,payroll.correction_requirements FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION payroll.lock_input_scope(p_tenant uuid,p_employer uuid,p_employment uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE employee uuid; BEGIN
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant::text,90427));
 PERFORM 1 FROM platform_core.tenants WHERE id=p_tenant FOR SHARE;
 PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant AND user_id=auth.uid() FOR SHARE;
 IF p_employment IS NOT NULL THEN
  SELECT employee_id INTO employee FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment AND employer_entity_id=p_employer;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM people.employees WHERE tenant_id=p_tenant AND id=employee FOR UPDATE;
  PERFORM 1 FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment AND employer_entity_id=p_employer FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
END $f$;
-- Guard only dates whose meaning changes: prospective closure after a frozen window stays lawful.
CREATE FUNCTION payroll.guard_people_frozen_history() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE t uuid; h uuid; old_data jsonb; new_data jsonb; frozen record; d date; old_covers boolean; new_covers boolean; BEGIN
 old_data:=CASE WHEN TG_OP='INSERT' THEN NULL ELSE to_jsonb(OLD) END;
 new_data:=CASE WHEN TG_OP='DELETE' THEN NULL ELSE to_jsonb(NEW) END;
 t:=COALESCE((new_data->>'tenant_id')::uuid,(old_data->>'tenant_id')::uuid);
 h:=CASE WHEN TG_TABLE_NAME='employments' THEN COALESCE((new_data->>'id')::uuid,(old_data->>'id')::uuid) ELSE COALESCE((new_data->>'employment_id')::uuid,(old_data->>'employment_id')::uuid) END;
 -- Supported People writers already own H. Consumer registration owns E -> H before evidence.
 PERFORM 1 FROM people.employments WHERE tenant_id=t AND id=h FOR UPDATE;
 FOR frozen IN SELECT p.starts_on,p.ends_on FROM payroll.people_frozen_contexts c JOIN payroll.periods p ON p.tenant_id=c.tenant_id AND p.id=c.period_id WHERE c.tenant_id=t AND c.employment_id=h LOOP
  FOR d IN SELECT generate_series(frozen.starts_on,frozen.ends_on,interval '1 day')::date LOOP
   IF TG_TABLE_NAME='employments' THEN
    old_covers:=old_data IS NOT NULL AND d>=(old_data->>'start_date')::date AND ((old_data->>'end_date') IS NULL OR d<=(old_data->>'end_date')::date);
    new_covers:=new_data IS NOT NULL AND d>=(new_data->>'start_date')::date AND ((new_data->>'end_date') IS NULL OR d<=(new_data->>'end_date')::date);
    IF old_covers IS DISTINCT FROM new_covers OR (old_covers AND new_covers AND (old_data - ARRAY['start_date','end_date','employment_status','created_at']) IS DISTINCT FROM (new_data - ARRAY['start_date','end_date','employment_status','created_at'])) THEN RAISE EXCEPTION 'payroll_people_correction_required' USING ERRCODE='23514'; END IF;
   ELSE
    old_covers:=old_data IS NOT NULL AND d>=(old_data->>'valid_from')::date AND ((old_data->>'valid_until') IS NULL OR d<(old_data->>'valid_until')::date);
    new_covers:=new_data IS NOT NULL AND d>=(new_data->>'valid_from')::date AND ((new_data->>'valid_until') IS NULL OR d<(new_data->>'valid_until')::date);
    IF old_covers IS DISTINCT FROM new_covers OR (old_covers AND new_covers AND (old_data - ARRAY['valid_from','valid_until','created_at']) IS DISTINCT FROM (new_data - ARRAY['valid_from','valid_until','created_at'])) THEN RAISE EXCEPTION 'payroll_people_correction_required' USING ERRCODE='23514'; END IF;
   END IF;
  END LOOP;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $f$;
CREATE TRIGGER payroll_employment_history_guard BEFORE UPDATE OR DELETE ON people.employments FOR EACH ROW EXECUTE FUNCTION payroll.guard_people_frozen_history();
CREATE TRIGGER payroll_compensation_history_guard BEFORE INSERT OR UPDATE OR DELETE ON people.compensation_versions FOR EACH ROW EXECUTE FUNCTION payroll.guard_people_frozen_history();
CREATE TRIGGER payroll_assignment_history_guard BEFORE INSERT OR UPDATE OR DELETE ON people.work_assignments FOR EACH ROW EXECUTE FUNCTION payroll.guard_people_frozen_history();
CREATE FUNCTION public.payroll_input_access(p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid(); result jsonb; BEGIN
 IF a IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 SELECT jsonb_object_agg(k,platform_private.has_tenant_permission(p_tenant,a,k)) INTO result FROM unnest(ARRAY['payroll.view','payroll_config.manage','payroll.prepare','payroll.approve','employee_finance.view','employee_finance.manage','employee_finance.approve','payroll.correct']) k;
 IF NOT EXISTS(SELECT 1 FROM jsonb_each_text(result) WHERE value='true') THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 RETURN result||jsonb_build_object('enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.payroll',clock_timestamp()));
END $f$;
CREATE FUNCTION payroll.input_permission(p_kind text,p_operation text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT CASE WHEN p_kind IN('component','policy') THEN 'payroll_config.manage' WHEN p_kind='adjustment' THEN CASE WHEN p_operation='approve' THEN 'employee_finance.approve' ELSE 'employee_finance.manage' END WHEN p_kind='manual_units' AND p_operation='approve' THEN 'payroll.approve' ELSE 'payroll.prepare' END
$f$;
CREATE FUNCTION payroll.validate_input(p_kind text,p_data jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE keys text[]; val numeric; BEGIN
 IF jsonb_typeof(p_data)<>'object' THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 keys:=CASE p_kind WHEN 'policy' THEN ARRAY['mode','reason'] WHEN 'component' THEN ARRAY['key','name','classification','calculation','base','value','taxable','social','visible','active','order','behavior','reason'] WHEN 'recurring' THEN ARRAY['component_id','value','reason'] WHEN 'manual_units' THEN ARRAY['units','reference','reason'] WHEN 'adjustment' THEN ARRAY['component_id','amount','reference','reason'] WHEN 'opening_ytd' THEN ARRAY['year','taxable_earnings','tax_withheld','social_base','employee_social','employer_social','reference','reason'] END;
 IF keys IS NULL OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE NOT k=ANY(keys)) OR length(btrim(COALESCE(p_data->>'reason',''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_kind='policy' AND COALESCE(p_data->>'mode','') NOT IN('fixed_30_day','calendar_days') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_kind='component' THEN
  IF COALESCE(p_data->>'key','') !~ '^[a-z][a-z0-9_]{1,39}$' OR length(btrim(COALESCE(p_data->>'name',''))) NOT BETWEEN 2 AND 100 OR COALESCE(p_data->>'classification','') NOT IN('earning','deduction','employer_cost') OR COALESCE(p_data->>'calculation','') NOT IN('fixed','percentage') OR COALESCE(p_data->>'behavior','') NOT IN('recurring','period_input') OR COALESCE(p_data->>'taxable','') NOT IN('true','false') OR COALESCE(p_data->>'social','') NOT IN('true','false') OR COALESCE(p_data->>'visible','') NOT IN('true','false') OR COALESCE(p_data->>'active','') NOT IN('true','false') OR COALESCE(p_data->>'order','') !~ '^[0-9]{1,3}$' OR (p_data->>'calculation'='percentage' AND COALESCE(p_data->>'base','')<>'base_pay') OR (p_data->>'calculation'='fixed' AND COALESCE(p_data->>'base','')<>'') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_kind IN('component','recurring','manual_units','adjustment') THEN
  val:=CASE p_kind WHEN 'manual_units' THEN (p_data->>'units')::numeric WHEN 'adjustment' THEN (p_data->>'amount')::numeric ELSE (p_data->>'value')::numeric END;
  IF val IS NULL OR val<0 OR val>999999999999.99 OR val<>round(val,2) OR (p_kind IN('manual_units','adjustment') AND val=0) OR (p_kind='manual_units' AND val>366) OR (p_kind='component' AND p_data->>'calculation'='percentage' AND val>100) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_kind='opening_ytd' THEN
  IF COALESCE(p_data->>'year','') !~ '^[0-9]{4}$' OR (p_data->>'year')::int NOT BETWEEN 2000 AND 2200 OR length(btrim(COALESCE(p_data->>'reference',''))) NOT BETWEEN 3 AND 160 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;

  IF EXISTS(SELECT 1 FROM unnest(ARRAY['taxable_earnings','tax_withheld','social_base','employee_social','employer_social']) k WHERE p_data->>k IS NULL OR (p_data->>k)::numeric<0 OR (p_data->>k)::numeric>999999999999.99 OR (p_data->>k)::numeric<>round((p_data->>k)::numeric,2)) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_kind IN('manual_units','adjustment') AND length(COALESCE(p_data->>'reference',''))>160 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
END $f$;
CREATE FUNCTION public.payroll_save_input(p_tenant uuid,p_employer uuid,p_kind text,p_employment uuid,p_period uuid,p_head uuid,p_expected integer,p_from date,p_until date,p_data jsonb,p_operation text,p_attempt uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid; permission text; current payroll.input_versions%ROWTYPE; head payroll.input_heads%ROWTYPE; receipt payroll.command_receipts%ROWTYPE; intent jsonb; result jsonb; next_status text; component payroll.input_versions%ROWTYPE; bounds payroll.periods%ROWTYPE; BEGIN
 IF p_kind IS NULL OR p_operation IS NULL OR p_kind NOT IN('component','policy','recurring','manual_units','adjustment','opening_ytd') OR p_operation NOT IN('save','approve','cancel') OR p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 permission:=payroll.input_permission(p_kind,p_operation);
 PERFORM payroll.authorized(p_tenant,permission,true);
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 a:=payroll.authorized(p_tenant,permission,true);
 intent:=jsonb_build_object('operation','input_'||p_operation,'employer',p_employer,'kind',p_kind,'employment',p_employment,'period',p_period,'head',p_head,'expected',p_expected,'from',p_from,'until',p_until,'data',p_data);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409'; END IF; RETURN receipt.result; END IF;
 IF (p_kind IN('recurring','manual_units','adjustment','opening_ytd'))<>(p_employment IS NOT NULL) OR (p_kind IN('manual_units','adjustment'))<>(p_period IS NOT NULL) OR p_from IS NULL OR (p_until IS NOT NULL AND p_until<=p_from) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_employment IS NOT NULL AND NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment AND employer_entity_id=p_employer AND payroll_eligible AND start_date<=COALESCE((SELECT ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND id=p_period),p_from) AND (end_date IS NULL OR end_date>=p_from)) THEN RAISE EXCEPTION 'payroll_employment_unavailable' USING ERRCODE='22023'; END IF;
 IF p_period IS NOT NULL THEN
  SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
  IF NOT FOUND OR p_from<>bounds.starts_on OR p_until IS DISTINCT FROM bounds.ends_on+1 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 END IF;
 PERFORM payroll.validate_input(p_kind,p_data);
 IF p_head IS NOT NULL THEN
  SELECT * INTO head FROM payroll.input_heads WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_head FOR UPDATE;
  IF NOT FOUND OR head.kind<>p_kind OR head.employment_id IS DISTINCT FROM p_employment OR head.period_id IS DISTINCT FROM p_period THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
  IF p_kind IN('manual_units','adjustment','opening_ytd') AND EXISTS(SELECT 1 FROM payroll.input_frozen_versions f JOIN payroll.input_versions v ON v.tenant_id=f.tenant_id AND v.id=f.version_id WHERE v.tenant_id=p_tenant AND v.head_id=head.id) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514'; END IF;
  SELECT * INTO current FROM payroll.input_versions WHERE tenant_id=p_tenant AND head_id=p_head AND revision=head.revision;
  IF head.revision<>p_expected OR current.status IN('applied','cancelled') OR (p_operation='save' AND p_kind IN('manual_units','adjustment') AND current.status<>'draft') THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
  IF p_operation<>'save' AND (p_data<>current.data OR p_from<>current.effective_from OR p_until IS DISTINCT FROM current.effective_until) THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
 ELSE
  IF p_expected<>0 OR p_operation<>'save' THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
  INSERT INTO payroll.input_heads(tenant_id,employer_id,kind,employment_id,period_id) VALUES(p_tenant,p_employer,p_kind,p_employment,p_period) RETURNING * INTO head;
 END IF;
 IF p_operation='approve' AND (p_kind NOT IN('manual_units','adjustment') OR current.status<>'draft') OR p_operation='cancel' AND (p_kind NOT IN('manual_units','adjustment') OR current.status NOT IN('draft','approved')) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_kind='policy' AND head.revision>0 AND p_operation='save' THEN RAISE EXCEPTION 'payroll_policy_already_set' USING ERRCODE='55000'; END IF;
 IF p_kind IN('component','recurring','opening_ytd') AND head.revision>0 AND (p_from<=current.effective_from OR p_kind<>'component' AND current.effective_until IS NOT NULL AND p_from>=current.effective_until) THEN RAISE EXCEPTION 'payroll_effective_conflict' USING ERRCODE='PT409'; END IF;
 IF p_kind='opening_ytd' AND ((p_data->>'year')::int<>extract(year FROM p_from)::int OR head.revision>0 AND p_data->>'year'<>current.data->>'year') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_kind='component' AND EXISTS(SELECT 1 FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.kind='component' AND h.id<>head.id AND v.data->>'key'=p_data->>'key') THEN RAISE EXCEPTION 'payroll_duplicate_component' USING ERRCODE='23505'; END IF;
 IF p_kind='manual_units' AND NOT EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=p_tenant AND h.id=p_employment AND h.pay_basis='daily' AND (p_data->>'units')::numeric<=least(COALESCE(h.end_date,bounds.ends_on),bounds.ends_on)-greatest(h.start_date,bounds.starts_on)+1) THEN RAISE EXCEPTION 'payroll_units_capacity' USING ERRCODE='22023'; END IF;
 IF p_kind IN('recurring','adjustment') THEN
  SELECT v.* INTO component FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.id=(p_data->>'component_id')::uuid AND h.kind='component' AND v.effective_from<=p_from ORDER BY v.effective_from DESC,v.revision DESC LIMIT 1;
  IF NOT FOUND OR component.data->>'active'<>'true' OR (component.effective_until IS NOT NULL AND component.effective_until<=p_from) OR (p_kind='recurring' AND component.data->>'behavior'<>'recurring') OR (p_kind='adjustment' AND (component.data->>'behavior'<>'period_input' OR component.data->>'classification'='employer_cost' OR component.data->>'calculation'<>'fixed')) OR (p_kind='recurring' AND component.data->>'calculation'='percentage' AND (p_data->>'value')::numeric>100) THEN RAISE EXCEPTION 'payroll_component_unavailable' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_kind IN('recurring','opening_ytd','manual_units') AND EXISTS(
  SELECT 1 FROM payroll.input_heads h JOIN (
   SELECT iv.*,lead(iv.effective_from) OVER(PARTITION BY iv.tenant_id,iv.head_id ORDER BY iv.effective_from,iv.revision) AS successor_from
   FROM payroll.input_versions iv WHERE iv.tenant_id=p_tenant
  ) v ON v.tenant_id=h.tenant_id AND v.head_id=h.id
  WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer
   AND (h.employment_id=p_employment OR p_kind='opening_ytd' AND h.employment_id IN(SELECT id FROM people.employments WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND employee_id=(SELECT employee_id FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment)))
   AND h.kind=p_kind AND h.id<>head.id AND v.status<>'cancelled'
   AND ((p_kind='manual_units' AND h.period_id=p_period AND v.revision=h.revision)
    OR (p_kind='opening_ytd' AND v.data->>'year'=p_data->>'year' AND v.revision=h.revision)
    OR (p_kind='recurring' AND v.data->>'component_id'=p_data->>'component_id'
     AND daterange(v.effective_from,LEAST(v.effective_until,v.successor_from),'[)')&&daterange(p_from,p_until,'[)')))
 ) THEN RAISE EXCEPTION 'payroll_duplicate_input' USING ERRCODE='23505'; END IF;
 IF EXISTS(SELECT 1 FROM payroll.people_frozen_contexts f JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND (p_employment IS NULL OR f.employment_id=p_employment) AND (p_kind='opening_ytd' AND extract(year FROM p.ends_on)::text=p_data->>'year' OR p_kind<>'opening_ytd' AND daterange(p.starts_on,p.ends_on,'[]')&&daterange(p_from,p_until,'[)'))) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514'; END IF;
 next_status:=CASE WHEN p_operation='approve' THEN 'approved' WHEN p_operation='cancel' THEN 'cancelled' ELSE 'draft' END;
 INSERT INTO payroll.input_versions(tenant_id,employer_id,head_id,revision,data,effective_from,effective_until,status,created_by,approved_by,approved_at) VALUES(p_tenant,p_employer,head.id,head.revision+1,p_data,p_from,p_until,next_status,a,CASE WHEN next_status='approved' THEN a END,CASE WHEN next_status='approved' THEN clock_timestamp() END);
 UPDATE payroll.input_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND id=head.id;
 result:=jsonb_build_object('id',head.id,'revision',head.revision+1,'status',next_status);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'input_'||p_operation,intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,permission,true); RETURN result;
END $f$;
CREATE FUNCTION public.payroll_request_correction(p_tenant uuid,p_employer uuid,p_employment uuid,p_period uuid,p_reason text,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid; intent jsonb; receipt payroll.command_receipts%ROWTYPE; result jsonb; id uuid; BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.correct',true); PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment); a:=payroll.authorized(p_tenant,'payroll.correct',true);
 IF p_attempt IS NULL OR length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 intent:=jsonb_build_object('operation','correction_request','employer',p_employer,'employment',p_employment,'period',p_period,'reason',btrim(p_reason));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409'; END IF; RETURN receipt.result; END IF;
 IF NOT EXISTS(SELECT 1 FROM payroll.people_frozen_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND employment_id=p_employment AND period_id=p_period) THEN RAISE EXCEPTION 'payroll_correction_not_required' USING ERRCODE='22023'; END IF;
 INSERT INTO payroll.correction_requirements(tenant_id,employer_id,employment_id,period_id,reason,requested_by) VALUES(p_tenant,p_employer,p_employment,p_period,btrim(p_reason),a) RETURNING correction_requirements.id INTO id;
 result:=jsonb_build_object('id',id,'status','requested');
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'correction_requested',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result); RETURN result;
END $f$;
CREATE FUNCTION public.payroll_input_workspace(p_tenant uuid,p_employer uuid,p_period uuid,p_query text DEFAULT '',p_after uuid DEFAULT NULL,p_record_after uuid DEFAULT NULL,p_limit integer DEFAULT 30) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE access jsonb; bounds payroll.periods%ROWTYPE; people_items jsonb; records jsonb; component_choices jsonb; BEGIN
 access:=public.payroll_input_access(p_tenant);
 IF length(COALESCE(p_query,''))>120 OR p_query IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_period_required' USING ERRCODE='22023'; END IF;
 -- Payroll-owned projection: identity, dated eligibility and completeness only; no salary/contact/leave reason disclosure.
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]') INTO people_items FROM (
 SELECT h.id,e.full_name,e.employee_code,h.pay_basis,h.start_date,h.end_date,
 CASE WHEN EXISTS(SELECT 1 FROM generate_series(greatest(h.start_date,bounds.starts_on),least(COALESCE(h.end_date,bounds.ends_on),bounds.ends_on),interval '1 day') covered_day WHERE NOT EXISTS(SELECT 1 FROM people.compensation_versions c WHERE c.tenant_id=h.tenant_id AND c.employment_id=h.id AND c.valid_from<=covered_day::date AND (c.valid_until IS NULL OR c.valid_until>covered_day::date))) THEN 'compensation_missing'
 WHEN h.pay_basis='daily' AND NOT EXISTS(SELECT 1 FROM payroll.input_heads ih JOIN payroll.input_versions iv ON iv.tenant_id=ih.tenant_id AND iv.head_id=ih.id AND iv.revision=ih.revision WHERE ih.tenant_id=h.tenant_id AND ih.employment_id=h.id AND ih.period_id=p_period AND ih.kind='manual_units' AND iv.status='approved') THEN 'approved_units_missing' ELSE 'reviewed_inputs_only' END AS readiness
 FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND h.start_date<=bounds.ends_on AND (h.end_date IS NULL OR h.end_date>=bounds.starts_on) AND (p_after IS NULL OR h.id>p_after) AND (e.full_name ILIKE '%'||p_query||'%' OR e.employee_code ILIKE '%'||p_query||'%') ORDER BY h.id LIMIT p_limit) x;
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]') INTO records FROM (
 SELECT h.id,h.kind,h.employment_id,h.period_id,(SELECT e.full_name FROM people.employments eh JOIN people.employees e ON e.tenant_id=eh.tenant_id AND e.id=eh.employee_id WHERE eh.tenant_id=h.tenant_id AND eh.id=h.employment_id) AS employee_name,v.revision,v.data,v.effective_from,v.effective_until,v.status,v.approved_at FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision
 WHERE h.tenant_id=p_tenant AND (h.employer_id=p_employer OR h.kind='policy') AND (h.period_id IS NULL OR h.period_id=p_period)
 AND (h.kind<>'adjustment' OR (access->>'employee_finance.view')::boolean OR (access->>'employee_finance.manage')::boolean OR (access->>'employee_finance.approve')::boolean)
 AND (h.kind='adjustment' OR (access->>'payroll.view')::boolean OR (access->>'payroll.prepare')::boolean OR (access->>'payroll.approve')::boolean OR (access->>'payroll_config.manage')::boolean)
 AND (p_record_after IS NULL OR h.id>p_record_after) ORDER BY h.id LIMIT 50) x;
 -- Eligible input choices reveal no catalog values, tax treatment or Employee salary.
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]') INTO component_choices FROM (
  SELECT h.id,v.data->>'name' AS name,v.data->>'behavior' AS behavior,v.data->>'classification' AS classification,v.data->>'calculation' AS calculation,(v.data->>'active')::boolean AS active,v.effective_from,v.effective_until
  FROM payroll.input_heads h JOIN LATERAL(SELECT iv.* FROM payroll.input_versions iv WHERE iv.tenant_id=h.tenant_id AND iv.head_id=h.id AND iv.effective_from<=bounds.starts_on ORDER BY iv.effective_from DESC,iv.revision DESC LIMIT 1)v ON true
  WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.kind='component'
   AND (p_record_after IS NULL OR h.id>p_record_after)
   AND v.data->>'active'='true' AND (v.effective_until IS NULL OR v.effective_until>bounds.starts_on)
   AND ((access->>'payroll.view')::boolean OR (access->>'payroll.prepare')::boolean OR (access->>'payroll.approve')::boolean OR (access->>'payroll_config.manage')::boolean
    OR (((access->>'employee_finance.view')::boolean OR (access->>'employee_finance.manage')::boolean OR (access->>'employee_finance.approve')::boolean) AND v.data->>'behavior'='period_input' AND v.data->>'calculation'='fixed' AND v.data->>'classification' IN('earning','deduction')))
  ORDER BY h.id LIMIT 50
 )x;
 RETURN jsonb_build_object('access',access,'period',jsonb_build_object('id',bounds.id,'starts_on',bounds.starts_on,'ends_on',bounds.ends_on),'employees',people_items,'component_choices',component_choices,'component_choices_more',jsonb_array_length(component_choices)=50,'records',records,'records_more',jsonb_array_length(records)=50,'legal_pack','unqualified','optional_sources','not_checked');
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_input_access(uuid),public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid),public.payroll_input_workspace(uuid,uuid,uuid,text,uuid,uuid,integer),public.payroll_request_correction(uuid,uuid,uuid,uuid,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_input_access(uuid),public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid),public.payroll_input_workspace(uuid,uuid,uuid,text,uuid,uuid,integer),public.payroll_request_correction(uuid,uuid,uuid,uuid,text,uuid) TO authenticated;
DO $f$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('platform_private.people_role_bundle_catalog()'::regprocedure);
 IF definition NOT LIKE '%payroll.calendar.manager.v1%' OR definition LIKE '%payroll.input.approver.v1%' THEN RAISE EXCEPTION 'unexpected_role_catalog'; END IF;
 definition:=replace(definition,'''payroll.calendar.manager.v1''::text,ARRAY[''payroll.view'',''payroll_config.manage'']::text[])','''payroll.calendar.manager.v1''::text,ARRAY[''payroll.view'',''payroll_config.manage'']::text[]),
 (''payroll.input.approver.v1''::text,ARRAY[''payroll.view'',''payroll.approve'']::text[]),
 (''employee_finance.reader.v1''::text,ARRAY[''employee_finance.view'']::text[]),
 (''employee_finance.author.v1''::text,ARRAY[''employee_finance.view'',''employee_finance.manage'']::text[]),
 (''employee_finance.approver.v1''::text,ARRAY[''employee_finance.view'',''employee_finance.approve'']::text[]),
 (''payroll.correction.requester.v1''::text,ARRAY[''payroll.view'',''payroll.correct'']::text[])');
 EXECUTE definition;
 definition:=pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure);
 IF definition NOT LIKE '%cardinality(p_bundle_keys) > 17%' THEN RAISE EXCEPTION 'unexpected_role_bundle_limit'; END IF;
 EXECUTE replace(definition,'cardinality(p_bundle_keys) > 17','cardinality(p_bundle_keys) > 22');
END $f$;

-- Internal foundation only. Slices 3-6 must supply run authority and reviewed money lifecycle before calling.
CREATE FUNCTION payroll.register_people_context(p_tenant uuid,p_employer uuid,p_employment uuid,p_period uuid,p_run uuid,p_expected jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE snapshot jsonb; bounds payroll.periods%ROWTYPE; BEGIN
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF NOT FOUND OR bounds.ends_on-bounds.starts_on>366 OR p_run IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 SELECT jsonb_build_object('employment',to_jsonb(h),'compensation',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.valid_from,c.id) FROM people.compensation_versions c WHERE c.tenant_id=p_tenant AND c.employment_id=p_employment AND daterange(c.valid_from,c.valid_until,'[)')&&daterange(bounds.starts_on,bounds.ends_on,'[]')),'[]'),'assignments',COALESCE((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.valid_from,w.id) FROM people.work_assignments w WHERE w.tenant_id=p_tenant AND w.employment_id=p_employment AND daterange(w.valid_from,w.valid_until,'[)')&&daterange(bounds.starts_on,bounds.ends_on,'[]')),'[]')) INTO snapshot FROM people.employments h WHERE h.tenant_id=p_tenant AND h.id=p_employment AND h.employer_entity_id=p_employer;
 IF p_expected IS NULL OR snapshot IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409'; END IF;
 INSERT INTO payroll.people_frozen_contexts(tenant_id,employer_id,employment_id,period_id,run_id,source_snapshot) VALUES(p_tenant,p_employer,p_employment,p_period,p_run,snapshot);
END $f$;
REVOKE ALL ON FUNCTION payroll.register_people_context(uuid,uuid,uuid,uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.payroll_input_periods(p_tenant uuid,p_employer uuid,p_before date DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM public.payroll_input_access(p_tenant);
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 RETURN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.starts_on DESC) FROM(SELECT id,starts_on,ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND (p_before IS NULL OR starts_on<p_before) ORDER BY starts_on DESC LIMIT 24)x),'[]');
END $f$;
REVOKE ALL ON FUNCTION public.payroll_input_periods(uuid,uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_input_periods(uuid,uuid,date) TO authenticated;
CREATE TABLE payroll.input_frozen_versions(tenant_id uuid NOT NULL,run_id uuid NOT NULL,version_id uuid NOT NULL,PRIMARY KEY(tenant_id,run_id,version_id),FOREIGN KEY(tenant_id,version_id) REFERENCES payroll.input_versions(tenant_id,id));
ALTER TABLE payroll.input_frozen_versions ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER payroll_frozen_input_immutable BEFORE UPDATE OR DELETE ON payroll.input_frozen_versions FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
REVOKE ALL ON payroll.input_frozen_versions FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.payroll_input_employers(p_tenant uuid,p_query text DEFAULT '',p_after_name text DEFAULT NULL,p_after_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM public.payroll_input_access(p_tenant);
 IF p_query IS NULL OR length(p_query)>120 OR (p_after_name IS NULL)<>(p_after_id IS NULL) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 RETURN jsonb_build_object('items',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.name,x.id) FROM(SELECT id,display_name AS name FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND is_active AND display_name ILIKE '%'||p_query||'%' AND(p_after_id IS NULL OR (display_name,id)>(p_after_name,p_after_id)) ORDER BY display_name,id LIMIT 30)x),'[]'),'unique_employer',(SELECT CASE WHEN count(*)=1 THEN min(id::text) END FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND is_active));
END $f$;
REVOKE ALL ON FUNCTION public.payroll_input_employers(uuid,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_input_employers(uuid,text,text,uuid) TO authenticated;

CREATE FUNCTION public.payroll_correction_items(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.view');
 RETURN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.name,x.employment_id) FROM(SELECT DISTINCT f.employment_id,e.full_name AS name,EXISTS(SELECT 1 FROM payroll.correction_requirements r WHERE r.tenant_id=f.tenant_id AND r.employment_id=f.employment_id AND r.period_id=f.period_id) AS requested FROM payroll.people_frozen_contexts f JOIN people.employments h ON h.tenant_id=f.tenant_id AND h.id=f.employment_id JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND f.period_id=p_period ORDER BY name,employment_id LIMIT 50)x),'[]');
END $f$;
REVOKE ALL ON FUNCTION public.payroll_correction_items(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_correction_items(uuid,uuid,uuid) TO authenticated;
