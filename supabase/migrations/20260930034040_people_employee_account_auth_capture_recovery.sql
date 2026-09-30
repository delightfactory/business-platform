-- Auth Admin may persist app_metadata after the auth.users INSERT trigger runs.
-- Recover only an Auth row bearing this intent's private random marker and target email.
CREATE OR REPLACE FUNCTION public.prepare_people_employee_account_provision(p_tenant_id uuid,p_employee_id uuid,p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
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
