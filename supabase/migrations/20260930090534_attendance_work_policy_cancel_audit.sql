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
    'manager_employee_id',v_future.manager_employee_id,'work_policy_template_id',v_future.work_policy_template_id,'work_policy_version',v_future.work_policy_version,'valid_from',v_future.valid_from,'valid_until',v_future.valid_until);
  v_previous_before := pg_catalog.jsonb_build_object('id',v_previous.id,'valid_until',v_previous.valid_until);
  DELETE FROM people.work_assignments WHERE tenant_id=p_tenant_id AND id=v_future.id;
  UPDATE people.work_assignments SET valid_until=NULL WHERE tenant_id=p_tenant_id AND id=v_previous.id;
  IF v_future.work_policy_template_id IS NOT NULL THEN INSERT INTO time.work_policy_audit_events(tenant_id,actor_user_id,event_key,template_id,version,details) VALUES(p_tenant_id,v_actor,'policy.assignment_cancelled',v_future.work_policy_template_id,v_future.work_policy_version,pg_catalog.jsonb_build_object('employment_id',p_employment_id,'assignment_id',v_future.id,'effective_date',v_future.valid_from)); END IF;
  INSERT INTO people.work_assignment_audit_events(tenant_id,employment_id,actor_user_id,event_key,assignment_id,details)
    VALUES(p_tenant_id,p_employment_id,v_actor,'assignment.transfer_cancelled',v_future.id,
      pg_catalog.jsonb_build_object('cancelled',v_cancelled,'restored',v_previous_before ||
        pg_catalog.jsonb_build_object('valid_until',NULL)));
  RETURN pg_catalog.jsonb_build_object('assignment_id',v_future.id,'restored_assignment_id',v_previous.id,'state','cancelled');
END;
$function$;
REVOKE ALL ON FUNCTION public.cancel_people_work_assignment(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_people_work_assignment(uuid,uuid,uuid) TO authenticated;
