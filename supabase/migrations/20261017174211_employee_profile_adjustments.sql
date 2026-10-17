-- Employee-scoped projection. All commands still use payroll_save_input and its
-- existing permission, receipt, revision, frozen-history and audit guarantees.
CREATE OR REPLACE FUNCTION public.people_employee_adjustments(
 p_tenant uuid,p_employee uuid,p_period uuid DEFAULT NULL,
 p_before date DEFAULT NULL,p_after uuid DEFAULT NULL,p_focus uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE snapshot jsonb; access jsonb; employment people.employments%ROWTYPE;
 bounds payroll.periods%ROWTYPE; periods jsonb; records jsonb; components jsonb;
 today date:=(clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date;
BEGIN
 snapshot:=public.people_employee_snapshot(p_tenant,p_employee);
 access:=public.payroll_input_access(p_tenant);
 IF NOT (coalesce((access->>'employee_finance.view')::boolean,false)
  OR coalesce((access->>'employee_finance.manage')::boolean,false)
  OR coalesce((access->>'employee_finance.approve')::boolean,false)) THEN
  RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';
 END IF;
 SELECT * INTO employment FROM people.employments
 WHERE tenant_id=p_tenant AND employee_id=p_employee
  AND id=(snapshot->'employment'->>'id')::uuid;
 IF NOT FOUND THEN RETURN jsonb_build_object('access',access,'periods','[]'::jsonb,'records','[]'::jsonb,'components','[]'::jsonb); END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY starts_on DESC),'[]') INTO periods FROM (
  SELECT id,starts_on,ends_on FROM payroll.periods
  WHERE tenant_id=p_tenant AND employer_id=employment.employer_entity_id
   AND ends_on>=employment.start_date AND (employment.end_date IS NULL OR starts_on<=employment.end_date)
   AND (p_before IS NULL OR starts_on<p_before) ORDER BY starts_on DESC LIMIT 24
 )x;
 IF p_period IS NOT NULL THEN
  SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant
   AND employer_id=employment.employer_entity_id AND id=p_period
   AND ends_on>=employment.start_date AND (employment.end_date IS NULL OR starts_on<=employment.end_date);
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_period_required' USING ERRCODE='22023'; END IF;
 ELSIF p_before IS NULL AND (SELECT count(*) FROM payroll.periods WHERE tenant_id=p_tenant
  AND employer_id=employment.employer_entity_id AND starts_on<=today AND ends_on>=today
  AND ends_on>=employment.start_date AND (employment.end_date IS NULL OR starts_on<=employment.end_date))=1 THEN
  SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant
   AND employer_id=employment.employer_entity_id AND starts_on<=today AND ends_on>=today
   AND ends_on>=employment.start_date AND (employment.end_date IS NULL OR starts_on<=employment.end_date);
 END IF;
 IF bounds.id IS NOT NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') INTO components FROM (
   SELECT h.id,v.data->>'name' AS name,v.data->>'classification' AS classification
   FROM payroll.input_heads h JOIN LATERAL (
    SELECT * FROM payroll.input_versions WHERE tenant_id=h.tenant_id AND head_id=h.id
     AND effective_from<=bounds.starts_on ORDER BY effective_from DESC,revision DESC LIMIT 1
   )v ON true WHERE h.tenant_id=p_tenant AND h.employer_id=employment.employer_entity_id
    AND h.kind='component' AND v.status<>'cancelled' AND v.data->>'active'='true'
    AND (v.effective_until IS NULL OR v.effective_until>bounds.starts_on)
    AND v.data->>'behavior'='period_input' AND v.data->>'calculation'='fixed'
    AND v.data->>'classification' IN('earning','deduction') ORDER BY h.id LIMIT 101
  )x;
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') INTO records FROM (
   SELECT h.id,h.kind,h.employment_id,h.period_id,v.revision,v.data,v.effective_from,v.effective_until,v.status
   FROM payroll.input_heads h JOIN payroll.input_versions v
    ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision
   WHERE h.tenant_id=p_tenant AND h.employment_id=employment.id
    AND h.employer_id=employment.employer_entity_id AND h.kind='adjustment'
    AND h.period_id=bounds.id AND (p_after IS NULL OR h.id>p_after) ORDER BY h.id LIMIT 21
  )x;
 END IF;
 RETURN jsonb_build_object('access',access,'employment',employment.id,'employer',employment.employer_entity_id,
  'eligible',employment.payroll_eligible,'periods',periods,
  'period',CASE WHEN bounds.id IS NOT NULL THEN jsonb_build_object('id',bounds.id,'starts_on',bounds.starts_on,'ends_on',bounds.ends_on) END,
  'locked',EXISTS(SELECT 1 FROM payroll.people_frozen_contexts WHERE tenant_id=p_tenant AND employment_id=employment.id AND period_id=bounds.id),
  'records',coalesce(records,'[]'),'components',coalesce(components,'[]'),
  'focused_record',(SELECT to_jsonb(x) FROM (
   SELECT h.id,h.kind,h.employment_id,h.period_id,v.revision,v.data,v.effective_from,v.effective_until,v.status
   FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision
   WHERE h.tenant_id=p_tenant AND h.employment_id=employment.id AND h.employer_id=employment.employer_entity_id
    AND h.kind='adjustment' AND h.period_id=bounds.id AND h.id=p_focus
  )x));
END $f$;
REVOKE ALL ON FUNCTION public.people_employee_adjustments(uuid,uuid,uuid,date,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_adjustments(uuid,uuid,uuid,date,uuid,uuid) TO authenticated;
