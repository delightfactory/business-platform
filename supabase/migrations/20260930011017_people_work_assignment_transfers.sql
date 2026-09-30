CREATE TABLE people.work_assignment_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  employment_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN (
    'assignment.transferred','assignment.transfer_scheduled','assignment.transfer_cancelled')),
  assignment_id uuid NOT NULL,
  details jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,employment_id) REFERENCES people.employments(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX work_assignment_audit_employment_idx
  ON people.work_assignment_audit_events(tenant_id,employment_id,created_at DESC);
ALTER TABLE people.work_assignment_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.work_assignment_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE people.work_assignment_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION people.prevent_work_assignment_audit_mutation() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'people_assignment_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER work_assignment_audit_append_only BEFORE UPDATE OR DELETE ON people.work_assignment_audit_events
FOR EACH ROW EXECUTE FUNCTION people.prevent_work_assignment_audit_mutation();
REVOKE ALL ON FUNCTION people.prevent_work_assignment_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.people_work_assignment_history(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id) THEN
    RAISE EXCEPTION 'people_assignment_employment_not_found' USING ERRCODE='P0002';
  END IF;
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
      'status',CASE WHEN a.valid_from>v_today THEN 'scheduled'
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

CREATE FUNCTION public.people_work_assignment_options(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_employee_id uuid; v_employer_id uuid; v_result jsonb;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage') THEN
    RAISE EXCEPTION 'people_org_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT employee_id,employer_entity_id INTO v_employee_id,v_employer_id
  FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_assignment_employment_not_found' USING ERRCODE='P0002'; END IF;
  WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
    SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d WHERE d.tenant_id=p_tenant_id
    UNION ALL
    SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
    FROM people.departments parent JOIN ancestors chain
      ON parent.tenant_id=p_tenant_id AND parent.id=chain.parent_id
    WHERE NOT parent.id=ANY(chain.path)
  ), effective_departments AS (
    SELECT id,pg_catalog.bool_and(is_active) effectively_active FROM ancestors GROUP BY id
  )
  SELECT pg_catalog.jsonb_build_object(
    'sites',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',x.id,'name',x.display_name)
      ORDER BY x.display_name,x.id) FROM (SELECT s.id,s.display_name FROM platform_core.tenant_sites s
      WHERE s.tenant_id=p_tenant_id AND s.legal_entity_id=v_employer_id AND s.is_active
      ORDER BY s.display_name,s.id LIMIT 1000) x),'[]'::jsonb),
    'sites_truncated',EXISTS(SELECT 1 FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id
      AND s.legal_entity_id=v_employer_id AND s.is_active ORDER BY s.display_name,s.id OFFSET 1000 LIMIT 1),
    'departments',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',x.id,'name',x.name)
      ORDER BY x.name,x.id) FROM (SELECT d.id,d.name FROM people.departments d
      JOIN effective_departments e ON e.id=d.id AND e.effectively_active
      WHERE d.tenant_id=p_tenant_id AND d.is_active ORDER BY d.name,d.id LIMIT 1000) x),'[]'::jsonb),
    'departments_truncated',EXISTS(SELECT 1 FROM people.departments d JOIN effective_departments e
      ON e.id=d.id AND e.effectively_active WHERE d.tenant_id=p_tenant_id AND d.is_active
      ORDER BY d.name,d.id OFFSET 1000 LIMIT 1),
    'jobs',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',x.id,'name',x.name,
        'department_id',x.department_id) ORDER BY x.name,x.id) FROM (SELECT j.id,j.name,j.department_id
      FROM people.jobs j LEFT JOIN effective_departments e ON e.id=j.department_id
      WHERE j.tenant_id=p_tenant_id AND j.is_active
        AND (j.department_id IS NULL OR e.effectively_active)
      ORDER BY j.name,j.id LIMIT 1000) x),'[]'::jsonb),
    'jobs_truncated',EXISTS(SELECT 1 FROM people.jobs j LEFT JOIN effective_departments e ON e.id=j.department_id
      WHERE j.tenant_id=p_tenant_id AND j.is_active AND (j.department_id IS NULL OR e.effectively_active)
      ORDER BY j.name,j.id OFFSET 1000 LIMIT 1),
    'managers',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',x.id,'name',x.full_name)
      ORDER BY x.full_name,x.id) FROM (SELECT e.id,e.full_name FROM people.employees e
      WHERE e.tenant_id=p_tenant_id AND e.workforce_status='active' AND e.id<>v_employee_id
        AND EXISTS (SELECT 1 FROM people.employments active_employment
          WHERE active_employment.tenant_id=e.tenant_id AND active_employment.employee_id=e.id
            AND active_employment.employment_status='active' AND active_employment.start_date<=v_today)
      ORDER BY e.full_name,e.id LIMIT 1000) x),'[]'::jsonb),
    'managers_truncated',EXISTS(SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id
      AND e.workforce_status='active' AND e.id<>v_employee_id
      AND EXISTS (SELECT 1 FROM people.employments active_employment
        WHERE active_employment.tenant_id=e.tenant_id AND active_employment.employee_id=e.id
          AND active_employment.employment_status='active' AND active_employment.start_date<=v_today)
      ORDER BY e.full_name,e.id OFFSET 1000 LIMIT 1)
  ) INTO v_result;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_work_assignment_options(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_work_assignment_options(uuid,uuid) TO authenticated;

CREATE FUNCTION public.schedule_people_work_assignment(p_tenant_id uuid,p_employment_id uuid,p_effective_date date,
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
          AND active_employment.employment_status='active' AND active_employment.start_date<=v_today)) THEN
      RAISE EXCEPTION 'people_assignment_manager_unavailable' USING ERRCODE='23503';
    END IF;
  END IF;
  v_previous_before := pg_catalog.jsonb_build_object('id',v_previous.id,'site_id',v_previous.site_id,
    'department_id',v_previous.department_id,'job_id',v_previous.job_id,
    'manager_employee_id',v_previous.manager_employee_id,'valid_from',v_previous.valid_from,
    'valid_until',v_previous.valid_until);
  UPDATE people.work_assignments SET valid_until=p_effective_date
    WHERE tenant_id=p_tenant_id AND id=v_previous.id;
  INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,department_id,job_id,manager_employee_id,valid_from)
    VALUES(p_tenant_id,p_employment_id,p_site_id,p_department_id,p_job_id,p_manager_employee_id,p_effective_date)
    RETURNING id INTO v_new_assignment_id;
  v_context := pg_catalog.jsonb_build_object('site_id',p_site_id,'department_id',p_department_id,
    'job_id',p_job_id,'manager_employee_id',p_manager_employee_id,'valid_from',p_effective_date,'valid_until',NULL);
  v_event := CASE WHEN p_effective_date=v_today THEN 'assignment.transferred' ELSE 'assignment.transfer_scheduled' END;
  INSERT INTO people.work_assignment_audit_events(tenant_id,employment_id,actor_user_id,event_key,assignment_id,details)
    VALUES(p_tenant_id,p_employment_id,v_actor,v_event,v_new_assignment_id,
      pg_catalog.jsonb_build_object('before',v_previous_before,'after',pg_catalog.jsonb_build_object(
        'previous_valid_until',p_effective_date,'new_assignment_id',v_new_assignment_id,'context',v_context)));
  RETURN pg_catalog.jsonb_build_object('assignment_id',v_new_assignment_id,'effective_date',p_effective_date,
    'state',CASE WHEN p_effective_date=v_today THEN 'transferred' ELSE 'scheduled' END);
END;
$function$;
REVOKE ALL ON FUNCTION public.schedule_people_work_assignment(uuid,uuid,date,uuid,uuid,uuid,uuid)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.schedule_people_work_assignment(uuid,uuid,date,uuid,uuid,uuid,uuid) TO authenticated;

CREATE FUNCTION public.cancel_people_work_assignment(p_tenant_id uuid,p_employment_id uuid,p_assignment_id uuid)
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
      'valid_from',a.valid_from,'valid_until',a.valid_until) END
  ) INTO v_result
  FROM people.employees e
  LEFT JOIN LATERAL (SELECT * FROM people.employments x WHERE x.tenant_id=e.tenant_id
    AND x.employee_id=e.id ORDER BY x.start_date DESC LIMIT 1) emp ON true
  LEFT JOIN platform_core.tenant_legal_entities le ON le.tenant_id=emp.tenant_id AND le.id=emp.employer_entity_id
  LEFT JOIN LATERAL (SELECT * FROM people.work_assignments x WHERE x.tenant_id=emp.tenant_id
    AND x.employment_id=emp.id AND x.valid_from<=v_today AND (x.valid_until IS NULL OR x.valid_until>v_today)
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
