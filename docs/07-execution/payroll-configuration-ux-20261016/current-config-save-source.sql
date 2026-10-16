CREATE OR REPLACE FUNCTION public.payroll_save_input_before_recurring_debts(p_tenant uuid, p_employer uuid, p_kind text, p_employment uuid, p_period uuid, p_head uuid, p_expected integer, p_from date, p_until date, p_data jsonb, p_operation text, p_attempt uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE a uuid; permission text; current payroll.input_versions%ROWTYPE; head payroll.input_heads%ROWTYPE; receipt payroll.command_receipts%ROWTYPE; intent jsonb; result jsonb; next_status text; component payroll.input_versions%ROWTYPE; bounds payroll.periods%ROWTYPE; BEGIN
 IF p_kind IS NULL OR p_operation IS NULL OR p_kind NOT IN('component','policy','recurring','manual_units','adjustment','opening_ytd','statutory_context') OR p_operation NOT IN('save','approve','cancel') OR p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 permission:=payroll.input_permission(p_kind,p_operation);
 PERFORM payroll.authorized(p_tenant,permission,true);
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 a:=payroll.authorized(p_tenant,permission,true);
 intent:=jsonb_build_object('operation','input_'||p_operation,'employer',p_employer,'kind',p_kind,'employment',p_employment,'period',p_period,'head',p_head,'expected',p_expected,'from',p_from,'until',p_until,'data',p_data);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409'; END IF; RETURN receipt.result; END IF;
 IF (p_kind IN('recurring','manual_units','adjustment','opening_ytd','statutory_context'))<>(p_employment IS NOT NULL) OR (p_kind IN('manual_units','adjustment'))<>(p_period IS NOT NULL) OR p_from IS NULL OR (p_until IS NOT NULL AND p_until<=p_from) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_employment IS NOT NULL AND NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment AND employer_entity_id=p_employer AND payroll_eligible AND start_date<=COALESCE((SELECT ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND id=p_period),p_from) AND (end_date IS NULL OR end_date>=p_from)) THEN RAISE EXCEPTION 'payroll_employment_unavailable' USING ERRCODE='22023'; END IF;
 IF p_period IS NOT NULL THEN
  SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
  IF NOT FOUND OR p_from<>bounds.starts_on OR p_until IS DISTINCT FROM bounds.ends_on+1 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 END IF;

 IF p_kind='statutory_context' AND(NOT isfinite(p_from) OR(p_until IS NOT NULL AND NOT isfinite(p_until))) THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
 PERFORM payroll.validate_input(p_kind,p_data);
 IF p_kind='opening_ytd' THEN PERFORM payroll.validate_opening_coverage(p_data,p_from); END IF; IF p_kind='manual_units' AND p_operation IN('save','approve') AND p_data->>'source'='time' AND NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp()) THEN RAISE EXCEPTION 'payroll_time_source_disabled' USING ERRCODE='55000';END IF;
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
 IF p_kind IN('component','recurring','opening_ytd','statutory_context') AND head.revision>0 AND (p_from<=current.effective_from OR p_kind NOT IN('component','statutory_context') AND current.effective_until IS NOT NULL AND p_from>=current.effective_until) THEN RAISE EXCEPTION 'payroll_effective_conflict' USING ERRCODE='PT409'; END IF;
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
 IF EXISTS(SELECT 1 FROM payroll.people_frozen_contexts f JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id WHERE f.tenant_id=p_tenant AND(f.employer_id=p_employer OR p_kind='policy') AND (p_employment IS NULL OR f.employment_id=p_employment) AND (p_kind='opening_ytd' AND extract(year FROM p.ends_on)::text=p_data->>'year' OR p_kind<>'opening_ytd' AND daterange(p.starts_on,p.ends_on,'[]')&&daterange(p_from,p_until,'[)'))) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514'; END IF;
 next_status:=CASE WHEN p_operation='approve' THEN 'approved' WHEN p_operation='cancel' THEN 'cancelled' ELSE 'draft' END;
 INSERT INTO payroll.input_versions(tenant_id,employer_id,head_id,revision,data,effective_from,effective_until,status,created_by,approved_by,approved_at) VALUES(p_tenant,p_employer,head.id,head.revision+1,CASE WHEN p_kind='recurring' THEN p_data||jsonb_build_object('component_interpretation',payroll.component_interpretation(component.data)) ELSE p_data END,p_from,p_until,next_status,a,CASE WHEN next_status='approved' THEN a END,CASE WHEN next_status='approved' THEN clock_timestamp() END);
 UPDATE payroll.input_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND id=head.id;
 result:=jsonb_build_object('id',head.id,'revision',head.revision+1,'status',next_status);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'input_'||p_operation,intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,permission,true); RETURN result;
END $function$
