-- Correct pending-review and marker recovery rules for databases where the first local draft was applied.
CREATE OR REPLACE FUNCTION public.start_people_employee_account_provision(p_tenant_id uuid,p_employee_id uuid,p_target_email text,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_email text := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_target_email,'')));
  v_signature jsonb; v_existing people.employee_account_provision_intents%ROWTYPE; v_tenant_state text;
  v_workforce_state text; v_email_conflict boolean;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_request_key IS NULL OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'people_employee_account_request_invalid' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text||':people-account:'||p_employee_id::text,917541));
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=p_tenant_id FOR SHARE;
  IF v_tenant_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'people_employee_account_tenant_unavailable' USING ERRCODE='42501'; END IF;
  SELECT workforce_status INTO v_workforce_state FROM people.employees WHERE tenant_id=p_tenant_id AND id=p_employee_id FOR UPDATE;
  IF NOT FOUND OR v_workforce_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'people_employee_account_employee_unavailable' USING ERRCODE='42501'; END IF;
  IF EXISTS (SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id AND l.employee_id=p_employee_id AND l.unlinked_at IS NULL) THEN
    RAISE EXCEPTION 'people_employee_account_already_linked' USING ERRCODE='23505';
  END IF;
  v_signature:=pg_catalog.jsonb_build_object('tenant_id',p_tenant_id,'employee_id',p_employee_id,'target_email',v_email);
  SELECT * INTO v_existing FROM people.employee_account_provision_intents i
    WHERE i.created_by_user_id=v_actor AND i.request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing.request_signature IS DISTINCT FROM v_signature THEN RAISE EXCEPTION 'people_employee_account_request_key_conflict' USING ERRCODE='P0001'; END IF;
    RETURN pg_catalog.jsonb_build_object('intent_id',v_existing.id,'state',v_existing.state,'target_email',v_existing.target_email);
  END IF;
  IF EXISTS (SELECT 1 FROM people.employee_account_provision_intents i WHERE i.tenant_id=p_tenant_id
    AND i.employee_id=p_employee_id AND i.state IN ('pending','user_created','manual_review')) THEN
    RAISE EXCEPTION 'people_employee_account_operation_in_progress' USING ERRCODE='23505';
  END IF;
  v_email_conflict:=EXISTS (SELECT 1 FROM auth.users u WHERE pg_catalog.lower(u.email)=v_email);
  INSERT INTO people.employee_account_provision_intents(tenant_id,employee_id,created_by_user_id,request_key,request_signature,target_email)
    VALUES(p_tenant_id,p_employee_id,v_actor,p_request_key,v_signature,v_email) RETURNING * INTO v_existing;
  IF v_email_conflict THEN
    UPDATE people.employee_account_provision_intents SET state='manual_review',last_error_code='email_conflict',updated_at=pg_catalog.clock_timestamp()
      WHERE tenant_id=p_tenant_id AND id=v_existing.id;
    v_existing.state:='manual_review';
  END IF;
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,v_existing.id,p_employee_id,v_actor,'employee.account_requested',pg_catalog.jsonb_build_object('target_email',v_email));
  IF v_email_conflict THEN
    INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
      VALUES(p_tenant_id,v_existing.id,p_employee_id,v_actor,'employee.account_manual_review',pg_catalog.jsonb_build_object('reason','email_conflict'));
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_existing.id,'state',v_existing.state,'target_email',v_email);
END;
$function$;
REVOKE ALL ON FUNCTION public.start_people_employee_account_provision(uuid,uuid,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.start_people_employee_account_provision(uuid,uuid,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.prepare_people_employee_account_provision(p_tenant_id uuid,p_employee_id uuid,p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_tenant_state text; v_workforce_state text;
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
  IF v_intent.state='pending' AND EXISTS (SELECT 1 FROM auth.users u WHERE pg_catalog.lower(u.email)=v_intent.target_email) THEN
    UPDATE people.employee_account_provision_intents SET state='manual_review',last_error_code='email_conflict',updated_at=pg_catalog.clock_timestamp()
      WHERE tenant_id=p_tenant_id AND id=p_intent_id;
    INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
      VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_manual_review',pg_catalog.jsonb_build_object('reason','email_conflict'));
    RETURN pg_catalog.jsonb_build_object('intent_id',p_intent_id,'state','manual_review','target_email',v_intent.target_email);
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

CREATE OR REPLACE FUNCTION public.people_employee_account_activation_snapshot(p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_email text; v_confirmed timestamptz; v_deleted timestamptz;
BEGIN
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i WHERE i.id=p_intent_id AND i.auth_user_id=v_actor;
  IF NOT FOUND OR v_actor IS NULL THEN RAISE EXCEPTION 'people_employee_account_activation_unavailable' USING ERRCODE='42501'; END IF;
  SELECT u.email,u.email_confirmed_at,u.deleted_at INTO v_email,v_confirmed,v_deleted FROM auth.users u
    WHERE u.id=v_actor AND (v_intent.state='activated' OR (
      u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
      AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text));
  IF NOT FOUND OR pg_catalog.lower(v_email)<>v_intent.target_email OR v_confirmed IS NULL OR v_deleted IS NOT NULL THEN
    RAISE EXCEPTION 'people_employee_account_activation_identity_unverified' USING ERRCODE='42501';
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_intent.id,'state',v_intent.state,'email',v_intent.target_email,
    'tenant_name',(SELECT t.display_name FROM platform_core.tenants t WHERE t.id=v_intent.tenant_id),
    'employee_name',(SELECT e.full_name FROM people.employees e WHERE e.tenant_id=v_intent.tenant_id AND e.id=v_intent.employee_id));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_account_activation_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_account_activation_snapshot(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.defer_people_employee_account_activation(p_intent_id uuid,p_error_code text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
BEGIN
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i WHERE i.id=p_intent_id AND i.auth_user_id=v_actor FOR UPDATE;
  IF NOT FOUND OR v_actor IS NULL OR p_error_code IS NULL OR p_error_code !~ '^[a-zA-Z0-9_-]{1,80}$' THEN
    RAISE EXCEPTION 'people_employee_account_activation_unavailable' USING ERRCODE='42501';
  END IF;
  IF v_intent.state<>'user_created' THEN RAISE EXCEPTION 'people_employee_account_activation_state_invalid' USING ERRCODE='23514'; END IF;
  UPDATE people.employee_account_provision_intents SET last_error_code=p_error_code,updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=v_intent.tenant_id AND id=v_intent.id;
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(v_intent.tenant_id,v_intent.id,v_intent.employee_id,v_actor,'employee.account_activation_deferred',pg_catalog.jsonb_build_object('reason',p_error_code));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.defer_people_employee_account_activation(uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.defer_people_employee_account_activation(uuid,text) TO authenticated;
