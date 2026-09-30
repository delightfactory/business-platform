-- Organizational transfers preserve the assigned policy snapshot; policy changes use their dedicated command.
CREATE OR REPLACE FUNCTION public.schedule_people_work_assignment(p_tenant_id uuid,p_employment_id uuid,p_effective_date date,
  p_site_id uuid,p_department_id uuid,p_job_id uuid,p_manager_employee_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_employment people.employments%ROWTYPE; v_previous people.work_assignments%ROWTYPE;
  v_site_employer uuid; v_department_available boolean; v_job people.jobs%ROWTYPE;
  v_new_assignment_id uuid; v_previous_before jsonb; v_context jsonb; v_event text;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage') THEN
    RAISE EXCEPTION 'people_org_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR p_employment_id IS NULL OR p_effective_date IS NULL OR p_site_id IS NULL THEN
    RAISE EXCEPTION 'people_assignment_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_employment FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_assignment_employment_not_found' USING ERRCODE='P0002'; END IF;
  IF v_employment.employment_status<>'active' THEN
    RAISE EXCEPTION 'people_assignment_employment_inactive' USING ERRCODE='23514';
  END IF;
  IF p_effective_date<v_today THEN RAISE EXCEPTION 'people_assignment_backdate_not_supported' USING ERRCODE='22023'; END IF;
  IF v_employment.end_date IS NOT NULL AND p_effective_date>v_employment.end_date THEN
    RAISE EXCEPTION 'people_assignment_after_employment_end' USING ERRCODE='23514';
  END IF;
  IF EXISTS (SELECT 1 FROM people.work_assignments a WHERE a.tenant_id=p_tenant_id
    AND a.employment_id=p_employment_id AND a.valid_from>v_today) THEN
    RAISE EXCEPTION 'people_assignment_future_exists' USING ERRCODE='23514';
  END IF;
  SELECT * INTO v_previous FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
      AND a.valid_from<=v_today AND (a.valid_until IS NULL OR a.valid_until>v_today)
    ORDER BY a.valid_from DESC,a.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND OR v_previous.valid_until IS NOT NULL THEN
    RAISE EXCEPTION 'people_assignment_current_missing' USING ERRCODE='23514';
  END IF;
  IF p_effective_date<=v_previous.valid_from THEN
    RAISE EXCEPTION 'people_assignment_before_current_start' USING ERRCODE='22023';
  END IF;
  SELECT legal_entity_id INTO v_site_employer FROM platform_core.tenant_sites s
    WHERE s.tenant_id=p_tenant_id AND s.id=p_site_id AND s.is_active;
  IF v_site_employer IS NULL OR v_site_employer<>v_employment.employer_entity_id THEN
    RAISE EXCEPTION 'people_assignment_site_unavailable' USING ERRCODE='23503';
  END IF;
  IF p_department_id IS NOT NULL THEN
    WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
      SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
      WHERE d.tenant_id=p_tenant_id AND d.id=p_department_id
      UNION ALL
      SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
      FROM people.departments parent JOIN ancestors chain
        ON parent.tenant_id=p_tenant_id AND parent.id=chain.parent_id
      WHERE NOT parent.id=ANY(chain.path)
    ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_department_available FROM ancestors;
    IF NOT v_department_available THEN RAISE EXCEPTION 'people_assignment_department_unavailable' USING ERRCODE='23503'; END IF;
  END IF;
  IF p_job_id IS NOT NULL THEN
    SELECT * INTO v_job FROM people.jobs j WHERE j.tenant_id=p_tenant_id AND j.id=p_job_id;
    IF NOT FOUND OR NOT v_job.is_active THEN RAISE EXCEPTION 'people_assignment_job_unavailable' USING ERRCODE='23503'; END IF;
    IF v_job.department_id IS NOT NULL AND v_job.department_id IS DISTINCT FROM p_department_id THEN
      RAISE EXCEPTION 'people_assignment_job_department_mismatch' USING ERRCODE='23514';
    END IF;
  END IF;
  IF p_manager_employee_id IS NOT NULL THEN
    IF p_manager_employee_id=v_employment.employee_id THEN
      RAISE EXCEPTION 'people_assignment_self_manager' USING ERRCODE='23514';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM people.employees m WHERE m.tenant_id=p_tenant_id
      AND m.id=p_manager_employee_id AND m.workforce_status='active'
      AND EXISTS (SELECT 1 FROM people.employments active_employment
        WHERE active_employment.tenant_id=m.tenant_id AND active_employment.employee_id=m.id
          AND active_employment.employment_status='active' AND active_employment.start_date<=p_effective_date)) THEN
      RAISE EXCEPTION 'people_assignment_manager_unavailable' USING ERRCODE='23503';
    END IF;
  END IF;
  v_previous_before := pg_catalog.jsonb_build_object('id',v_previous.id,'site_id',v_previous.site_id,
    'department_id',v_previous.department_id,'job_id',v_previous.job_id,
    'manager_employee_id',v_previous.manager_employee_id,'valid_from',v_previous.valid_from,
    'valid_until',v_previous.valid_until,'work_policy_template_id',v_previous.work_policy_template_id,'work_policy_version',v_previous.work_policy_version);
  UPDATE people.work_assignments SET valid_until=p_effective_date
    WHERE tenant_id=p_tenant_id AND id=v_previous.id;
  INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,department_id,job_id,manager_employee_id,valid_from,work_policy_template_id,work_policy_version)
    VALUES(p_tenant_id,p_employment_id,p_site_id,p_department_id,p_job_id,p_manager_employee_id,p_effective_date,v_previous.work_policy_template_id,v_previous.work_policy_version)
    RETURNING id INTO v_new_assignment_id;
  v_context := pg_catalog.jsonb_build_object('site_id',p_site_id,'department_id',p_department_id,
    'job_id',p_job_id,'manager_employee_id',p_manager_employee_id,'valid_from',p_effective_date,'valid_until',NULL,'work_policy_template_id',v_previous.work_policy_template_id,'work_policy_version',v_previous.work_policy_version);
  v_event := CASE WHEN p_effective_date=v_today THEN 'assignment.transferred' ELSE 'assignment.transfer_scheduled' END;
  INSERT INTO people.work_assignment_audit_events(tenant_id,employment_id,actor_user_id,event_key,assignment_id,details)
    VALUES(p_tenant_id,p_employment_id,v_actor,v_event,v_new_assignment_id,
      pg_catalog.jsonb_build_object('before',v_previous_before,'after',pg_catalog.jsonb_build_object(
        'previous_valid_until',p_effective_date,'new_assignment_id',v_new_assignment_id,'context',v_context)));
  RETURN pg_catalog.jsonb_build_object('assignment_id',v_new_assignment_id,'effective_date',p_effective_date,
    'state',CASE WHEN p_effective_date=v_today THEN 'transferred' ELSE 'scheduled' END);
END;
$function$;
REVOKE ALL ON FUNCTION public.schedule_people_work_assignment(uuid,uuid,date,uuid,uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.schedule_people_work_assignment(uuid,uuid,date,uuid,uuid,uuid,uuid) TO authenticated;
