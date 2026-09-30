CREATE OR REPLACE FUNCTION public.people_work_assignment_history(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb; v_start_date date;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT e.start_date INTO v_start_date FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_assignment_employment_not_found' USING ERRCODE='P0002'; END IF;
  WITH assignments AS (
    SELECT a.*,pg_catalog.row_number() OVER (ORDER BY a.valid_from DESC,a.id DESC) ordinal
    FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
    ORDER BY a.valid_from DESC,a.id DESC LIMIT 101
  )
  SELECT pg_catalog.jsonb_build_object(
    'items',COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',a.id,'site_id',a.site_id,'site',s.display_name,'department_id',a.department_id,
      'department',d.name,'job_id',a.job_id,'job',j.name,'manager_employee_id',a.manager_employee_id,
      'manager',m.full_name,'valid_from',a.valid_from,'valid_until',a.valid_until,
      'status',CASE WHEN a.valid_from>v_today AND a.valid_from=v_start_date AND NOT EXISTS (
          SELECT 1 FROM people.work_assignments prior_assignment
          WHERE prior_assignment.tenant_id=a.tenant_id AND prior_assignment.employment_id=a.employment_id
            AND prior_assignment.valid_from<a.valid_from) THEN 'initial_scheduled'
        WHEN a.valid_from>v_today THEN 'scheduled'
        WHEN a.valid_until IS NOT NULL AND a.valid_until<=v_today THEN 'past' ELSE 'current' END
    ) ORDER BY a.valid_from DESC,a.id DESC) FILTER (WHERE a.ordinal<=100),'[]'::jsonb),
    'truncated',COALESCE(pg_catalog.bool_or(a.ordinal>100),false)
  ) INTO v_result
  FROM assignments a
  LEFT JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id
  LEFT JOIN people.departments d ON d.tenant_id=a.tenant_id AND d.id=a.department_id
  LEFT JOIN people.jobs j ON j.tenant_id=a.tenant_id AND j.id=a.job_id
  LEFT JOIN people.employees m ON m.tenant_id=a.tenant_id AND m.id=a.manager_employee_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_work_assignment_history(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_work_assignment_history(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_people_work_assignment(p_tenant_id uuid,p_employment_id uuid,p_assignment_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_employment people.employments%ROWTYPE; v_future people.work_assignments%ROWTYPE;
  v_previous people.work_assignments%ROWTYPE; v_cancelled jsonb; v_previous_before jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage') THEN
    RAISE EXCEPTION 'people_org_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_employment FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_assignment_employment_not_found' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_future FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id AND a.id=p_assignment_id
      AND a.valid_from>v_today FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_assignment_not_future' USING ERRCODE='23514'; END IF;
  IF v_future.valid_from=v_employment.start_date AND NOT EXISTS (
    SELECT 1 FROM people.work_assignments prior_assignment
    WHERE prior_assignment.tenant_id=p_tenant_id AND prior_assignment.employment_id=p_employment_id
      AND prior_assignment.valid_from<v_future.valid_from) THEN
    RAISE EXCEPTION 'people_assignment_initial_not_cancellable' USING ERRCODE='23514';
  END IF;
  SELECT * INTO v_previous FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
      AND a.valid_until=v_future.valid_from AND a.valid_from<v_future.valid_from
    ORDER BY a.valid_from DESC,a.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_assignment_previous_not_found' USING ERRCODE='23514'; END IF;
  v_cancelled := pg_catalog.jsonb_build_object('id',v_future.id,'site_id',v_future.site_id,
    'department_id',v_future.department_id,'job_id',v_future.job_id,
    'manager_employee_id',v_future.manager_employee_id,'valid_from',v_future.valid_from,'valid_until',v_future.valid_until);
  v_previous_before := pg_catalog.jsonb_build_object('id',v_previous.id,'valid_until',v_previous.valid_until);
  DELETE FROM people.work_assignments WHERE tenant_id=p_tenant_id AND id=v_future.id;
  UPDATE people.work_assignments SET valid_until=NULL WHERE tenant_id=p_tenant_id AND id=v_previous.id;
  INSERT INTO people.work_assignment_audit_events(tenant_id,employment_id,actor_user_id,event_key,assignment_id,details)
    VALUES(p_tenant_id,p_employment_id,v_actor,'assignment.transfer_cancelled',v_future.id,
      pg_catalog.jsonb_build_object('cancelled',v_cancelled,'restored',v_previous_before ||
        pg_catalog.jsonb_build_object('valid_until',NULL)));
  RETURN pg_catalog.jsonb_build_object('assignment_id',v_future.id,'restored_assignment_id',v_previous.id,'state','cancelled');
END;
$function$;
REVOKE ALL ON FUNCTION public.cancel_people_work_assignment(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_people_work_assignment(uuid,uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.people_employee_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object(
    'id',e.id,'code',e.employee_code,'name',e.full_name,
    'status',CASE WHEN e.workforce_status='active' AND emp.start_date>v_today THEN 'scheduled' ELSE e.workforce_status END,
    'can_manage',platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage'),
    'employment',CASE WHEN emp.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object(
      'id',emp.id,'employer_id',emp.employer_entity_id,'employer',le.display_name,
      'start_date',emp.start_date,'end_date',emp.end_date,'status',emp.employment_status) END,
    'assignment',CASE WHEN a.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object(
      'id',a.id,'site_id',a.site_id,'site',s.display_name,
      'department_id',a.department_id,'department',d.name,'job_id',a.job_id,'job',j.name,
      'manager_employee_id',a.manager_employee_id,'manager',m.full_name,
      'valid_from',a.valid_from,'valid_until',a.valid_until,
      'is_scheduled',emp.employment_status='active' AND emp.start_date>v_today) END
  ) INTO v_result
  FROM people.employees e
  LEFT JOIN LATERAL (SELECT * FROM people.employments x WHERE x.tenant_id=e.tenant_id
    AND x.employee_id=e.id ORDER BY x.start_date DESC LIMIT 1) emp ON true
  LEFT JOIN platform_core.tenant_legal_entities le ON le.tenant_id=emp.tenant_id AND le.id=emp.employer_entity_id
  LEFT JOIN LATERAL (SELECT * FROM people.work_assignments x WHERE x.tenant_id=emp.tenant_id
    AND x.employment_id=emp.id
    AND x.valid_from<=CASE WHEN emp.employment_status='ended' THEN emp.end_date
      WHEN emp.start_date>v_today THEN emp.start_date ELSE v_today END
    AND (x.valid_until IS NULL OR x.valid_until>CASE WHEN emp.employment_status='ended' THEN emp.end_date
      WHEN emp.start_date>v_today THEN emp.start_date ELSE v_today END)
    ORDER BY x.valid_from DESC,x.id DESC LIMIT 1) a ON true
  LEFT JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id
  LEFT JOIN people.departments d ON d.tenant_id=a.tenant_id AND d.id=a.department_id
  LEFT JOIN people.jobs j ON j.tenant_id=a.tenant_id AND j.id=a.job_id
  LEFT JOIN people.employees m ON m.tenant_id=a.tenant_id AND m.id=a.manager_employee_id
  WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_snapshot(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.people_compensation_history(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb; v_pay_basis text; v_employment_start date;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.view') THEN
    RAISE EXCEPTION 'compensation_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT e.pay_basis,e.start_date INTO v_pay_basis,v_employment_start FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_compensation_employment_not_found' USING ERRCODE='P0002'; END IF;
  WITH versions AS (
    SELECT c.*,pg_catalog.row_number() OVER (ORDER BY c.valid_from DESC,c.id DESC) ordinal
    FROM people.compensation_versions c WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
    ORDER BY c.valid_from DESC,c.id DESC LIMIT 101
  )
  SELECT pg_catalog.jsonb_build_object(
    'pay_basis',v_pay_basis,
    'items',COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',v.id,'amount',v.amount,'currency',v.currency_code,'valid_from',v.valid_from,'valid_until',v.valid_until,
      'status',CASE WHEN v.valid_from>v_today AND v.valid_from=v_employment_start AND NOT EXISTS (
          SELECT 1 FROM people.compensation_versions prior_version
          WHERE prior_version.tenant_id=v.tenant_id AND prior_version.employment_id=v.employment_id
            AND prior_version.valid_from<v.valid_from) THEN 'initial_scheduled'
        WHEN v.valid_from>v_today THEN 'scheduled'
        WHEN v.valid_until IS NOT NULL AND v.valid_until<=v_today THEN 'past' ELSE 'current' END
    ) ORDER BY v.valid_from DESC,v.id DESC) FILTER (WHERE v.ordinal<=100),'[]'::jsonb),
    'truncated',COALESCE(pg_catalog.bool_or(v.ordinal>100),false)
  ) INTO v_result FROM versions v;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_compensation_history(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_compensation_history(uuid,uuid) TO authenticated;
