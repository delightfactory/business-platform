-- Recover activated direct employee accounts created before explicit password readiness existed.
-- This does not change their existing membership or employee link.
CREATE OR REPLACE FUNCTION public.record_people_employee_account_password_readiness(p_intent_id uuid,p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_intent people.employee_account_provision_intents%ROWTYPE;
  v_email text; v_confirmed timestamptz; v_banned timestamptz; v_deleted timestamptz; v_password text;
  v_ready people.employee_account_password_readiness%ROWTYPE;
BEGIN
  IF p_intent_id IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'people_employee_account_readiness_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i
    WHERE i.id=p_intent_id AND i.auth_user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'people_employee_account_readiness_identity_mismatch' USING ERRCODE='42501';
  END IF;
  IF v_intent.state NOT IN ('user_created','activated') THEN
    RAISE EXCEPTION 'people_employee_account_readiness_state_invalid' USING ERRCODE='23514';
  END IF;
  IF v_intent.state='activated' THEN
    SELECT * INTO v_ready FROM people.employee_account_password_readiness r
      WHERE r.tenant_id=v_intent.tenant_id AND r.intent_id=v_intent.id;
    IF FOUND AND v_ready.employee_id=v_intent.employee_id AND v_ready.user_id=p_user_id THEN RETURN true; END IF;
  END IF;
  SELECT u.email,u.email_confirmed_at,u.banned_until,u.deleted_at,u.encrypted_password
    INTO v_email,v_confirmed,v_banned,v_deleted,v_password
  FROM auth.users u WHERE u.id=p_user_id AND (
    v_intent.state='activated' OR (
      u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
      AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text
    )
  );
  IF NOT FOUND OR pg_catalog.lower(v_email)<>v_intent.target_email OR v_confirmed IS NULL OR v_deleted IS NOT NULL
    OR (v_banned IS NOT NULL AND v_banned>pg_catalog.now()) OR v_password IS NULL OR v_password='' THEN
    RAISE EXCEPTION 'people_employee_account_readiness_identity_unverified' USING ERRCODE='42501';
  END IF;
  INSERT INTO people.employee_account_password_readiness(tenant_id,intent_id,employee_id,user_id)
    VALUES(v_intent.tenant_id,v_intent.id,v_intent.employee_id,p_user_id)
    ON CONFLICT (tenant_id,intent_id) DO NOTHING;
  SELECT * INTO v_ready FROM people.employee_account_password_readiness r
    WHERE r.tenant_id=v_intent.tenant_id AND r.intent_id=v_intent.id;
  IF NOT FOUND OR v_ready.employee_id<>v_intent.employee_id OR v_ready.user_id<>p_user_id THEN
    RAISE EXCEPTION 'people_employee_account_readiness_conflict' USING ERRCODE='23505';
  END IF;
  INSERT INTO platform_private.platform_auth_password_readiness(user_id,source_workflow,source_invitation_id,source_issuance)
    VALUES(p_user_id,'people_employee_account',v_intent.id,1) ON CONFLICT (user_id) DO NOTHING;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_people_employee_account_password_readiness(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_people_employee_account_password_readiness(uuid,uuid) TO service_role;

-- The recipient may repair readiness only while signed into the exact verified Auth identity
-- recorded on this activated intent. User metadata may already have been intentionally cleared.
CREATE OR REPLACE FUNCTION public.people_employee_account_activation_snapshot(p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_email text; v_confirmed timestamptz; v_deleted timestamptz;
BEGIN
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i
    WHERE i.id=p_intent_id AND i.auth_user_id=v_actor;
  IF NOT FOUND OR v_actor IS NULL THEN RAISE EXCEPTION 'people_employee_account_activation_unavailable' USING ERRCODE='42501'; END IF;
  SELECT u.email,u.email_confirmed_at,u.deleted_at INTO v_email,v_confirmed,v_deleted FROM auth.users u
    WHERE u.id=v_actor AND (v_intent.state='activated' OR (
      u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
      AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text));
  IF NOT FOUND OR pg_catalog.lower(v_email)<>v_intent.target_email OR v_confirmed IS NULL OR v_deleted IS NOT NULL THEN
    RAISE EXCEPTION 'people_employee_account_activation_identity_unverified' USING ERRCODE='42501';
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_intent.id,'state',v_intent.state,'email',v_intent.target_email,
    'password_ready',EXISTS(SELECT 1 FROM people.employee_account_password_readiness r
      WHERE r.tenant_id=v_intent.tenant_id AND r.intent_id=v_intent.id AND r.employee_id=v_intent.employee_id AND r.user_id=v_actor),
    'tenant_name',(SELECT t.display_name FROM platform_core.tenants t WHERE t.id=v_intent.tenant_id),
    'employee_name',(SELECT e.full_name FROM people.employees e WHERE e.tenant_id=v_intent.tenant_id AND e.id=v_intent.employee_id));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_account_activation_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_account_activation_snapshot(uuid) TO authenticated;

-- HR recovery link is available only for an activated, still-linked account missing its exact readiness row.
CREATE FUNCTION public.prepare_people_employee_account_password_readiness_recovery(p_tenant_id uuid,p_employee_id uuid,p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_tenant_state text; v_workforce_state text; v_email text; v_confirmed timestamptz; v_banned timestamptz; v_deleted timestamptz;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i
    WHERE i.tenant_id=p_tenant_id AND i.employee_id=p_employee_id AND i.id=p_intent_id AND i.state='activated' FOR UPDATE;
  IF NOT FOUND OR EXISTS(SELECT 1 FROM people.employee_account_password_readiness r
    WHERE r.tenant_id=p_tenant_id AND r.intent_id=p_intent_id AND r.employee_id=p_employee_id AND r.user_id=v_intent.auth_user_id) THEN
    RAISE EXCEPTION 'people_employee_account_readiness_recovery_unavailable' USING ERRCODE='P0002';
  END IF;
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=p_tenant_id;
  SELECT workforce_status INTO v_workforce_state FROM people.employees WHERE tenant_id=p_tenant_id AND id=p_employee_id;
  IF v_tenant_state IS DISTINCT FROM 'active' OR v_workforce_state IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'people_employee_account_subject_unavailable' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id
    AND l.employee_id=p_employee_id AND l.user_id=v_intent.auth_user_id AND l.unlinked_at IS NULL) THEN
    RAISE EXCEPTION 'people_employee_account_readiness_recovery_unavailable' USING ERRCODE='42501';
  END IF;
  SELECT u.email,u.email_confirmed_at,u.banned_until,u.deleted_at INTO v_email,v_confirmed,v_banned,v_deleted
    FROM auth.users u WHERE u.id=v_intent.auth_user_id;
  IF NOT FOUND OR pg_catalog.lower(v_email)<>v_intent.target_email OR v_confirmed IS NULL OR v_deleted IS NOT NULL
    OR (v_banned IS NOT NULL AND v_banned>pg_catalog.now()) THEN
    RAISE EXCEPTION 'people_employee_account_readiness_recovery_unavailable' USING ERRCODE='42501';
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_intent.id,'target_email',v_intent.target_email,'auth_user_id',v_intent.auth_user_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.prepare_people_employee_account_password_readiness_recovery(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.prepare_people_employee_account_password_readiness_recovery(uuid,uuid,uuid) TO authenticated;

CREATE FUNCTION public.record_people_employee_account_readiness_delivery(p_tenant_id uuid,p_employee_id uuid,p_intent_id uuid,p_delivery_state text,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_user uuid;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_delivery_state NOT IN ('sent','failed','unknown') OR (p_error_code IS NOT NULL AND p_error_code !~ '^[a-zA-Z0-9_-]{1,80}$') THEN
    RAISE EXCEPTION 'people_employee_account_delivery_invalid' USING ERRCODE='22023';
  END IF;
  UPDATE people.employee_account_provision_intents i SET delivery_state=p_delivery_state,last_error_code=p_error_code,
    activation_attempts=i.activation_attempts+1,updated_at=pg_catalog.clock_timestamp()
    WHERE i.tenant_id=p_tenant_id AND i.employee_id=p_employee_id AND i.id=p_intent_id AND i.state='activated'
    RETURNING i.auth_user_id INTO v_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_account_readiness_recovery_unavailable' USING ERRCODE='P0002'; END IF;
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_readiness_delivery',
      pg_catalog.jsonb_build_object('state',p_delivery_state,'error_code',p_error_code,'auth_user_id',v_user));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_people_employee_account_readiness_delivery(uuid,uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.record_people_employee_account_readiness_delivery(uuid,uuid,uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.people_employee_account_provision_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object('intent_id',i.id,'state',i.state,'target_email',i.target_email,
    'delivery_state',i.delivery_state,'last_error_code',i.last_error_code,'activation_attempts',i.activation_attempts,
    'password_ready',EXISTS(SELECT 1 FROM people.employee_account_password_readiness r
      WHERE r.tenant_id=i.tenant_id AND r.intent_id=i.id AND r.employee_id=i.employee_id AND r.user_id=i.auth_user_id),
    'created_at',i.created_at,'updated_at',i.updated_at)
    INTO v_result FROM people.employee_account_provision_intents i WHERE i.tenant_id=p_tenant_id AND i.employee_id=p_employee_id
    ORDER BY i.created_at DESC LIMIT 1;
  RETURN COALESCE(v_result,pg_catalog.jsonb_build_object('state','none'));
END;
$function$;
