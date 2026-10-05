-- Restore the three live/source function-definition differences verified on the original PostgreSQL database.
-- Preserve the catalog no-op update path, the marker-recovery audit detail, and the legacy RPC authorization order.
CREATE OR REPLACE FUNCTION people.validate_work_assignment_catalog()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_department_available boolean; v_job people.jobs%ROWTYPE;
BEGIN
  IF TG_OP='UPDATE'
    AND NEW.tenant_id IS NOT DISTINCT FROM OLD.tenant_id
    AND NEW.id IS NOT DISTINCT FROM OLD.id
    AND NEW.employment_id IS NOT DISTINCT FROM OLD.employment_id
    AND NEW.site_id IS NOT DISTINCT FROM OLD.site_id
    AND NEW.department_id IS NOT DISTINCT FROM OLD.department_id
    AND NEW.job_id IS NOT DISTINCT FROM OLD.job_id
    AND NEW.manager_employee_id IS NOT DISTINCT FROM OLD.manager_employee_id
    AND NEW.valid_from IS NOT DISTINCT FROM OLD.valid_from THEN
    RETURN NEW;
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(NEW.tenant_id::text,0));
  IF NEW.department_id IS NOT NULL THEN
    WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
      SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
      WHERE d.tenant_id=NEW.tenant_id AND d.id=NEW.department_id
      UNION ALL
      SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
      FROM people.departments parent JOIN ancestors chain
        ON parent.tenant_id=NEW.tenant_id AND parent.id=chain.parent_id
      WHERE NOT parent.id=ANY(chain.path)
    ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_department_available FROM ancestors;
    IF NOT v_department_available THEN RAISE EXCEPTION 'people_assignment_department_unavailable' USING ERRCODE='23503'; END IF;
  END IF;
  IF NEW.job_id IS NOT NULL THEN
    SELECT * INTO v_job FROM people.jobs j WHERE j.tenant_id=NEW.tenant_id AND j.id=NEW.job_id;
    IF NOT FOUND OR NOT v_job.is_active THEN RAISE EXCEPTION 'people_assignment_job_unavailable' USING ERRCODE='23503'; END IF;
    IF v_job.department_id IS NOT NULL AND v_job.department_id IS DISTINCT FROM NEW.department_id THEN
      RAISE EXCEPTION 'people_assignment_job_department_mismatch' USING ERRCODE='23514';
    END IF;
    IF v_job.department_id IS NOT NULL THEN
      WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
        SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
        WHERE d.tenant_id=NEW.tenant_id AND d.id=v_job.department_id
        UNION ALL
        SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
        FROM people.departments parent JOIN ancestors chain
          ON parent.tenant_id=NEW.tenant_id AND parent.id=chain.parent_id
        WHERE NOT parent.id=ANY(chain.path)
      ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_department_available FROM ancestors;
      IF NOT v_department_available THEN RAISE EXCEPTION 'people_assignment_job_unavailable' USING ERRCODE='23503'; END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION people.validate_work_assignment_catalog() FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.prepare_people_employee_account_provision(p_tenant_id uuid, p_employee_id uuid, p_intent_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_tenant_state text; v_workforce_state text; v_marked_user_id uuid;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i WHERE i.tenant_id=p_tenant_id
    AND i.employee_id=p_employee_id AND i.id=p_intent_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_account_operation_unavailable' USING ERRCODE='P0002'; END IF;
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=p_tenant_id;
  SELECT workforce_status INTO v_workforce_state FROM people.employees WHERE tenant_id=p_tenant_id AND id=p_employee_id;
  IF v_tenant_state IS DISTINCT FROM 'active' OR v_workforce_state IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'people_employee_account_subject_unavailable' USING ERRCODE='42501';
  END IF;
  IF v_intent.state='pending' THEN
    SELECT u.id INTO v_marked_user_id FROM auth.users u WHERE pg_catalog.lower(u.email)=v_intent.target_email
      AND u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
      AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text;
    IF v_marked_user_id IS NOT NULL THEN
      UPDATE people.employee_account_provision_intents SET state='user_created',auth_user_id=v_marked_user_id,
        updated_at=pg_catalog.clock_timestamp() WHERE tenant_id=p_tenant_id AND id=p_intent_id;
      INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
        VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_auth_user_captured',
          pg_catalog.jsonb_build_object('auth_user_id',v_marked_user_id,'capture_source','server_marker_recovery'));
      v_intent.state:='user_created'; v_intent.auth_user_id:=v_marked_user_id;
    ELSIF EXISTS (SELECT 1 FROM auth.users u WHERE pg_catalog.lower(u.email)=v_intent.target_email) THEN
      UPDATE people.employee_account_provision_intents SET state='manual_review',last_error_code='email_conflict',updated_at=pg_catalog.clock_timestamp()
        WHERE tenant_id=p_tenant_id AND id=p_intent_id;
      INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
        VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_manual_review',pg_catalog.jsonb_build_object('reason','email_conflict'));
      RETURN pg_catalog.jsonb_build_object('intent_id',p_intent_id,'state','manual_review','target_email',v_intent.target_email);
    END IF;
  END IF;
  IF v_intent.state='user_created' AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=v_intent.auth_user_id
    AND pg_catalog.lower(u.email)=v_intent.target_email
    AND u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
    AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text) THEN
    UPDATE people.employee_account_provision_intents SET state='manual_review',last_error_code='marker_conflict',updated_at=pg_catalog.clock_timestamp()
      WHERE tenant_id=p_tenant_id AND id=p_intent_id;
    INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
      VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_manual_review',pg_catalog.jsonb_build_object('reason','marker_conflict'));
    RETURN pg_catalog.jsonb_build_object('intent_id',p_intent_id,'state','manual_review','target_email',v_intent.target_email);
  END IF;
  IF v_intent.state NOT IN ('pending','user_created') THEN
    RETURN pg_catalog.jsonb_build_object('intent_id',p_intent_id,'state',v_intent.state,'target_email',v_intent.target_email);
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_intent.id,'state',v_intent.state,'target_email',v_intent.target_email,
    'auth_marker',v_intent.auth_marker,'auth_user_id',v_intent.auth_user_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.prepare_people_employee_account_provision(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.prepare_people_employee_account_provision(uuid,uuid,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.record_manual_attendance_punch_local(p_tenant_id uuid, p_instance_id uuid, p_direction text, p_local_time timestamp without time zone, p_request_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE wi time.work_instances%ROWTYPE; resolved timestamptz;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,auth.uid(),'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'attendance_manage_forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 resolved:=time.resolve_local(p_local_time,wi.timezone_name);
 IF resolved IS NULL THEN RAISE EXCEPTION 'attendance_local_time_ambiguous_or_invalid' USING ERRCODE='22023'; END IF;
 RETURN public.record_manual_attendance_punch(p_tenant_id,p_instance_id,p_direction,resolved,p_request_key);
END $function$;
REVOKE ALL ON FUNCTION public.record_manual_attendance_punch_local(uuid,uuid,text,timestamp,uuid) FROM PUBLIC,anon,authenticated,service_role;
