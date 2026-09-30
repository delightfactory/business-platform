CREATE OR REPLACE FUNCTION public.end_people_employment(p_tenant_id uuid,p_employee_id uuid,p_employment_id uuid,p_end_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_employment people.employments%ROWTYPE; v_employee people.employees%ROWTYPE;
  v_assignment people.work_assignments%ROWTYPE; v_comp people.compensation_versions%ROWTYPE;
  v_before jsonb; v_after jsonb; v_pending_assignments jsonb := '[]'::jsonb; v_pending_compensation jsonb := '[]'::jsonb;
  v_assignment_before jsonb; v_previous_assignment_id uuid; v_comp_before jsonb; v_previous_comp_id uuid;
  v_current_assignment_id uuid; v_current_compensation_id uuid;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'people_employment_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR p_employee_id IS NULL OR p_employment_id IS NULL OR p_end_date IS NULL THEN
    RAISE EXCEPTION 'people_employment_end_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_employee FROM people.employees e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_not_found' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_employment FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id AND e.employee_id=p_employee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_not_found' USING ERRCODE='P0002'; END IF;
  IF v_employment.employment_status<>'active' THEN
    RAISE EXCEPTION 'people_employment_not_active' USING ERRCODE='23514';
  END IF;
  IF v_employment.start_date>v_today THEN
    RAISE EXCEPTION 'people_employment_not_started' USING ERRCODE='23514';
  END IF;
  IF p_end_date>v_today THEN
    RAISE EXCEPTION 'people_employment_future_end_unsupported' USING ERRCODE='22023';
  END IF;
  IF p_end_date<v_employment.start_date THEN
    RAISE EXCEPTION 'people_employment_end_before_start' USING ERRCODE='22023';
  END IF;
  IF EXISTS (SELECT 1 FROM people.work_assignments a WHERE a.tenant_id=p_tenant_id
      AND a.employment_id=p_employment_id AND a.valid_from>p_end_date AND a.valid_from<=v_today)
     OR EXISTS (SELECT 1 FROM people.compensation_versions c WHERE c.tenant_id=p_tenant_id
      AND c.employment_id=p_employment_id AND c.valid_from>p_end_date AND c.valid_from<=v_today) THEN
    RAISE EXCEPTION 'people_employment_end_after_effective_change' USING ERRCODE='23514';
  END IF;
  SELECT * INTO v_assignment FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
      AND a.valid_from<=p_end_date AND (a.valid_until IS NULL OR a.valid_until>p_end_date)
    ORDER BY a.valid_from DESC,a.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_current_assignment_missing' USING ERRCODE='23514'; END IF;
  SELECT * INTO v_comp FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
      AND c.valid_from<=p_end_date AND (c.valid_until IS NULL OR c.valid_until>p_end_date)
    ORDER BY c.valid_from DESC,c.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_current_compensation_missing' USING ERRCODE='23514'; END IF;
  v_current_assignment_id := v_assignment.id;
  v_current_compensation_id := v_comp.id;

  v_before := pg_catalog.jsonb_build_object('employment_status',v_employment.employment_status,
    'end_date',v_employment.end_date,'employee_status',v_employee.workforce_status,
    'assignment_id',v_assignment.id,'assignment_valid_until',v_assignment.valid_until,
    'compensation_version_id',v_comp.id,'compensation_valid_until',v_comp.valid_until);

  FOR v_assignment IN SELECT * FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id AND a.valid_from>v_today
    ORDER BY a.valid_from FOR UPDATE
  LOOP
    SELECT a.id INTO v_previous_assignment_id FROM people.work_assignments a
      WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
        AND a.valid_until=v_assignment.valid_from AND a.id<>v_assignment.id
      ORDER BY a.valid_from DESC,a.id DESC LIMIT 1;
    v_assignment_before := pg_catalog.jsonb_build_object('id',v_assignment.id,'site_id',v_assignment.site_id,
      'department_id',v_assignment.department_id,'job_id',v_assignment.job_id,
      'manager_employee_id',v_assignment.manager_employee_id,'valid_from',v_assignment.valid_from,
      'valid_until',v_assignment.valid_until);
    DELETE FROM people.work_assignments WHERE tenant_id=p_tenant_id AND id=v_assignment.id;
    IF v_previous_assignment_id IS NOT NULL THEN
      UPDATE people.work_assignments SET valid_until=NULL WHERE tenant_id=p_tenant_id AND id=v_previous_assignment_id;
    END IF;
    v_pending_assignments := v_pending_assignments || pg_catalog.jsonb_build_array(v_assignment_before);
    INSERT INTO people.work_assignment_audit_events(tenant_id,employment_id,actor_user_id,event_key,assignment_id,details)
      VALUES(p_tenant_id,p_employment_id,v_actor,'assignment.transfer_cancelled',v_assignment.id,
        pg_catalog.jsonb_build_object('cancelled',v_assignment_before,'reason','employment_ended'));
  END LOOP;

  FOR v_comp IN SELECT * FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id AND c.valid_from>v_today
    ORDER BY c.valid_from FOR UPDATE
  LOOP
    SELECT c.id INTO v_previous_comp_id FROM people.compensation_versions c
      WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
        AND c.valid_until=v_comp.valid_from AND c.id<>v_comp.id
      ORDER BY c.valid_from DESC,c.id DESC LIMIT 1;
    v_comp_before := pg_catalog.jsonb_build_object('id',v_comp.id,'amount',v_comp.amount,
      'currency',v_comp.currency_code,'valid_from',v_comp.valid_from,'valid_until',v_comp.valid_until);
    DELETE FROM people.compensation_versions WHERE tenant_id=p_tenant_id AND id=v_comp.id;
    IF v_previous_comp_id IS NOT NULL THEN
      UPDATE people.compensation_versions SET valid_until=NULL WHERE tenant_id=p_tenant_id AND id=v_previous_comp_id;
    END IF;
    v_pending_compensation := v_pending_compensation || pg_catalog.jsonb_build_array(v_comp_before);
    INSERT INTO people.compensation_audit_events(tenant_id,employment_id,actor_user_id,event_key,subject_version_id,details)
      VALUES(p_tenant_id,p_employment_id,v_actor,'compensation.change_cancelled',v_comp.id,
        pg_catalog.jsonb_build_object('cancelled',v_comp_before,'reason','employment_ended'));
  END LOOP;

  UPDATE people.work_assignments SET valid_until=p_end_date+1
    WHERE tenant_id=p_tenant_id AND id=v_current_assignment_id;
  UPDATE people.compensation_versions SET valid_until=p_end_date+1
    WHERE tenant_id=p_tenant_id AND id=v_current_compensation_id;
  UPDATE people.employments SET end_date=p_end_date,employment_status='ended'
    WHERE tenant_id=p_tenant_id AND id=p_employment_id;
  UPDATE people.employees SET workforce_status='ended',updated_at=pg_catalog.transaction_timestamp()
    WHERE tenant_id=p_tenant_id AND id=p_employee_id;
  v_after := pg_catalog.jsonb_build_object('employment_status','ended','end_date',v_today,
    'employee_status','ended','assignment_id',v_current_assignment_id,'assignment_valid_until',p_end_date+1,
    'compensation_version_id',v_current_compensation_id,'compensation_valid_until',p_end_date+1);
  INSERT INTO people.employment_lifecycle_audit_events(tenant_id,employee_id,employment_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_employee_id,p_employment_id,v_actor,'employment.ended',pg_catalog.jsonb_build_object(
      'before',v_before,'after',v_after,'cancelled_future_assignments',v_pending_assignments,
      'cancelled_future_compensation',v_pending_compensation,
      'handoff_required',pg_catalog.jsonb_build_array('payroll_final_settlement','leave_balance_review','finance_balance_review')));
  RETURN pg_catalog.jsonb_build_object('employment_id',p_employment_id,'end_date',p_end_date,'state','ended');
END;
$function$;
REVOKE ALL ON FUNCTION public.end_people_employment(uuid,uuid,uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.end_people_employment(uuid,uuid,uuid,date) TO authenticated;
