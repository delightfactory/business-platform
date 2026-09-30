CREATE TABLE people.employment_lifecycle_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  employee_id uuid NOT NULL,
  employment_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN ('employment.ended','employment.rehired')),
  details jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,employment_id) REFERENCES people.employments(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX employment_lifecycle_audit_employee_idx
  ON people.employment_lifecycle_audit_events(tenant_id,employee_id,created_at DESC);
ALTER TABLE people.employment_lifecycle_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.employment_lifecycle_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE people.employment_lifecycle_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION people.prevent_employment_lifecycle_audit_mutation() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'people_employment_lifecycle_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER employment_lifecycle_audit_append_only
BEFORE UPDATE OR DELETE ON people.employment_lifecycle_audit_events
FOR EACH ROW EXECUTE FUNCTION people.prevent_employment_lifecycle_audit_mutation();
REVOKE ALL ON FUNCTION people.prevent_employment_lifecycle_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.people_employment_history(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id) THEN
    RAISE EXCEPTION 'people_employee_not_found' USING ERRCODE='P0002';
  END IF;
  SELECT pg_catalog.jsonb_build_object('items',COALESCE(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object('id',e.id,'employer',le.display_name,'start_date',e.start_date,
      'end_date',e.end_date,'status',e.employment_status,'pay_basis',e.pay_basis)
    ORDER BY e.start_date DESC,e.id DESC),'[]'::jsonb),
    'events',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'event',a.event_key,'created_at',a.created_at,'details',a.details)
      ORDER BY a.created_at DESC,a.id DESC) FROM (
        SELECT * FROM people.employment_lifecycle_audit_events
        WHERE tenant_id=p_tenant_id AND employee_id=p_employee_id
        ORDER BY created_at DESC,id DESC LIMIT 100
      ) a),'[]'::jsonb),
    'events_truncated',(SELECT pg_catalog.count(*)>100 FROM people.employment_lifecycle_audit_events
      WHERE tenant_id=p_tenant_id AND employee_id=p_employee_id))
  INTO v_result
  FROM people.employments e
  JOIN platform_core.tenant_legal_entities le ON le.tenant_id=e.tenant_id AND le.id=e.employer_entity_id
  WHERE e.tenant_id=p_tenant_id AND e.employee_id=p_employee_id;
  RETURN COALESCE(v_result,pg_catalog.jsonb_build_object('items','[]'::jsonb,'events','[]'::jsonb,'events_truncated',false));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employment_history(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employment_history(uuid,uuid) TO authenticated;

CREATE FUNCTION public.end_people_employment(p_tenant_id uuid,p_employee_id uuid,p_employment_id uuid,p_end_date date)
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
  IF p_end_date<>v_today THEN
    RAISE EXCEPTION 'people_employment_end_today_only' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_assignment FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
      AND a.valid_from<=v_today AND (a.valid_until IS NULL OR a.valid_until>v_today)
    ORDER BY a.valid_from DESC,a.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_current_assignment_missing' USING ERRCODE='23514'; END IF;
  SELECT * INTO v_comp FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
      AND c.valid_from<=v_today AND (c.valid_until IS NULL OR c.valid_until>v_today)
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

  UPDATE people.work_assignments SET valid_until=v_today+1
    WHERE tenant_id=p_tenant_id AND id=v_current_assignment_id;
  UPDATE people.compensation_versions SET valid_until=v_today+1
    WHERE tenant_id=p_tenant_id AND id=v_current_compensation_id;
  UPDATE people.employments SET end_date=v_today,employment_status='ended'
    WHERE tenant_id=p_tenant_id AND id=p_employment_id;
  UPDATE people.employees SET workforce_status='ended',updated_at=pg_catalog.transaction_timestamp()
    WHERE tenant_id=p_tenant_id AND id=p_employee_id;
  v_after := pg_catalog.jsonb_build_object('employment_status','ended','end_date',v_today,
    'employee_status','ended','assignment_id',v_current_assignment_id,'assignment_valid_until',v_today+1,
    'compensation_version_id',v_current_compensation_id,'compensation_valid_until',v_today+1);
  INSERT INTO people.employment_lifecycle_audit_events(tenant_id,employee_id,employment_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_employee_id,p_employment_id,v_actor,'employment.ended',pg_catalog.jsonb_build_object(
      'before',v_before,'after',v_after,'cancelled_future_assignments',v_pending_assignments,
      'cancelled_future_compensation',v_pending_compensation,
      'handoff_required',pg_catalog.jsonb_build_array('payroll_final_settlement','leave_balance_review','finance_balance_review')));
  RETURN pg_catalog.jsonb_build_object('employment_id',p_employment_id,'end_date',v_today,'state','ended');
END;
$function$;
REVOKE ALL ON FUNCTION public.end_people_employment(uuid,uuid,uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.end_people_employment(uuid,uuid,uuid,date) TO authenticated;

CREATE FUNCTION public.rehire_people_employee(p_tenant_id uuid,p_employee_id uuid,p_employer_entity_id uuid,
  p_site_id uuid,p_start_date date,p_pay_basis text,p_base_amount numeric,p_payroll_eligible boolean,
  p_department_id uuid DEFAULT NULL,p_job_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_employee people.employees%ROWTYPE; v_previous people.employments%ROWTYPE;
  v_employment_id uuid; v_assignment_id uuid; v_compensation_id uuid; v_site_employer uuid;
  v_department_available boolean; v_job people.jobs%ROWTYPE; v_before jsonb; v_after jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'people_rehire_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR p_employee_id IS NULL OR p_employer_entity_id IS NULL OR p_site_id IS NULL
     OR p_start_date IS NULL OR p_pay_basis IS NULL OR p_pay_basis NOT IN ('monthly','daily') OR p_base_amount IS NULL
     OR p_base_amount<0 OR p_base_amount>999999999999.99 OR p_base_amount<>pg_catalog.round(p_base_amount,2)
     OR p_payroll_eligible IS NULL THEN
    RAISE EXCEPTION 'people_rehire_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_employee FROM people.employees e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_not_found' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_previous FROM people.employments e WHERE e.tenant_id=p_tenant_id AND e.employee_id=p_employee_id
    ORDER BY e.start_date DESC,e.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND OR v_previous.employment_status<>'ended' OR v_employee.workforce_status<>'ended' THEN
    RAISE EXCEPTION 'people_rehire_requires_ended_employee' USING ERRCODE='23514';
  END IF;
  IF EXISTS (SELECT 1 FROM people.employments e WHERE e.tenant_id=p_tenant_id AND e.employee_id=p_employee_id
    AND e.employment_status='active') THEN
    RAISE EXCEPTION 'people_rehire_active_employment_exists' USING ERRCODE='23514';
  END IF;
  IF p_start_date<v_today OR p_start_date<=v_previous.end_date THEN
    RAISE EXCEPTION 'people_rehire_start_date_invalid' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employer_entity_id AND e.is_active) THEN
    RAISE EXCEPTION 'people_employer_unavailable' USING ERRCODE='23503';
  END IF;
  SELECT s.legal_entity_id INTO v_site_employer FROM platform_core.tenant_sites s
    WHERE s.tenant_id=p_tenant_id AND s.id=p_site_id AND s.is_active;
  IF v_site_employer IS NULL OR v_site_employer<>p_employer_entity_id THEN
    RAISE EXCEPTION 'people_site_unavailable' USING ERRCODE='23503';
  END IF;
  IF p_department_id IS NOT NULL THEN
    WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
      SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
      WHERE d.tenant_id=p_tenant_id AND d.id=p_department_id
      UNION ALL SELECT parent.id,parent.parent_id,parent.is_active,chain.path||parent.id
      FROM people.departments parent JOIN ancestors chain
        ON parent.tenant_id=p_tenant_id AND parent.id=chain.parent_id WHERE NOT parent.id=ANY(chain.path)
    ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_department_available FROM ancestors;
    IF NOT v_department_available THEN RAISE EXCEPTION 'people_department_unavailable' USING ERRCODE='23503'; END IF;
  END IF;
  IF p_job_id IS NOT NULL THEN
    SELECT * INTO v_job FROM people.jobs j WHERE j.tenant_id=p_tenant_id AND j.id=p_job_id AND j.is_active;
    IF NOT FOUND THEN RAISE EXCEPTION 'people_job_unavailable' USING ERRCODE='23503'; END IF;
    IF v_job.department_id IS NOT NULL AND v_job.department_id IS DISTINCT FROM p_department_id THEN
      RAISE EXCEPTION 'people_job_unavailable' USING ERRCODE='23514';
    END IF;
  END IF;
  v_before := pg_catalog.jsonb_build_object('employee_status',v_employee.workforce_status,
    'prior_employment_id',v_previous.id,'prior_end_date',v_previous.end_date);
  INSERT INTO people.employments(tenant_id,employee_id,employer_entity_id,start_date,pay_basis,payroll_eligible)
    VALUES(p_tenant_id,p_employee_id,p_employer_entity_id,p_start_date,p_pay_basis,p_payroll_eligible)
    RETURNING id INTO v_employment_id;
  INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,department_id,job_id,valid_from)
    VALUES(p_tenant_id,v_employment_id,p_site_id,p_department_id,p_job_id,p_start_date) RETURNING id INTO v_assignment_id;
  INSERT INTO people.compensation_versions(tenant_id,employment_id,amount,valid_from)
    VALUES(p_tenant_id,v_employment_id,p_base_amount,p_start_date) RETURNING id INTO v_compensation_id;
  UPDATE people.employees SET workforce_status='active',updated_at=pg_catalog.transaction_timestamp()
    WHERE tenant_id=p_tenant_id AND id=p_employee_id;
  v_after := pg_catalog.jsonb_build_object('employee_status','active','employment_id',v_employment_id,
    'employer_id',p_employer_entity_id,'start_date',p_start_date,'pay_basis',p_pay_basis,
    'payroll_eligible',p_payroll_eligible,'assignment_id',v_assignment_id,'site_id',p_site_id,
    'department_id',p_department_id,'job_id',p_job_id,'compensation_version_id',v_compensation_id);
  INSERT INTO people.employment_lifecycle_audit_events(tenant_id,employee_id,employment_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_employee_id,v_employment_id,v_actor,'employment.rehired',pg_catalog.jsonb_build_object(
      'before',v_before,'after',v_after,'handoff_required',pg_catalog.jsonb_build_array(
        'payroll_final_settlement','leave_balance_review','finance_balance_review')));
  RETURN pg_catalog.jsonb_build_object('employee_id',p_employee_id,'employment_id',v_employment_id,
    'assignment_id',v_assignment_id,'compensation_version_id',v_compensation_id,'state','rehired');
END;
$function$;
REVOKE ALL ON FUNCTION public.rehire_people_employee(uuid,uuid,uuid,uuid,date,text,numeric,boolean,uuid,uuid)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.rehire_people_employee(uuid,uuid,uuid,uuid,date,text,numeric,boolean,uuid,uuid)
  TO authenticated;
