ALTER TABLE platform_private.platform_operator_grants
  ADD CONSTRAINT platform_operator_active_grant_has_capability
  CHECK (NOT is_active OR can_manage_operators OR can_onboard_tenants);

ALTER TABLE platform_private.platform_operator_audit_events
  ADD COLUMN before_state jsonb,
  ADD COLUMN after_state jsonb;

ALTER TABLE platform_private.platform_operator_audit_events
  DROP CONSTRAINT platform_operator_audit_events_action_check;
ALTER TABLE platform_private.platform_operator_audit_events
  ADD CONSTRAINT platform_operator_audit_events_action_check
  CHECK (action IN ('bootstrap','recovery','grant','revoke','operator_grant_created','operator_grant_updated','operator_grant_revoked'));
ALTER TABLE platform_private.platform_operator_audit_events
  ADD CONSTRAINT platform_operator_managed_grant_audit_complete
  CHECK (action NOT IN ('operator_grant_created','operator_grant_updated','operator_grant_revoked') OR
    (actor_class='platform_operator' AND actor_user_id IS NOT NULL
      AND COALESCE(NULLIF(pg_catalog.btrim(reason),''),'')<>''
      AND before_state IS NOT NULL AND after_state IS NOT NULL));

CREATE OR REPLACE FUNCTION platform_private.prevent_last_operator_manager_removal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_other_manager_exists boolean;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF TG_OP='UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    RAISE EXCEPTION 'platform_operator_grant_user_immutable' USING ERRCODE='23514';
  END IF;
  IF OLD.is_active AND OLD.can_manage_operators
     AND (TG_OP='DELETE' OR NOT NEW.is_active OR NOT NEW.can_manage_operators)
     AND EXISTS (
       SELECT 1 FROM auth.users u WHERE u.id=OLD.user_id AND u.deleted_at IS NULL
         AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
         AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
         AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
     ) THEN
    SELECT EXISTS (
      SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
      WHERE g.user_id<>OLD.user_id AND g.is_active AND g.can_manage_operators
        AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
        AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
        AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
        AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
    ) INTO v_other_manager_exists;
    IF NOT v_other_manager_exists THEN
      RAISE EXCEPTION 'The final active Platform Operator manager cannot be removed' USING ERRCODE='23514';
    END IF;
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION platform_private.bootstrap_operator_manager(p_target_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  IF p_target_user_id IS NULL THEN RAISE EXCEPTION 'An existing Auth user is required' USING ERRCODE='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id=p_target_user_id AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
  ) THEN RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g WHERE g.is_active AND g.can_manage_operators) THEN
    RAISE EXCEPTION 'A Platform Operator manager already exists; bootstrap is one-time' USING ERRCODE='55000';
  END IF;
  INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants)
  VALUES(p_target_user_id,true,true,true)
  ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=true,can_onboard_tenants=true,updated_at=pg_catalog.clock_timestamp();
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,target_user_id)
  VALUES('bootstrap','platform_bootstrap',p_target_user_id);
END;
$function$;

CREATE OR REPLACE FUNCTION platform_private.recover_operator_manager(
  p_target_user_id uuid,p_reason text,p_emergency boolean DEFAULT false
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  IF p_target_user_id IS NULL THEN RAISE EXCEPTION 'An existing Auth user is required' USING ERRCODE='22023'; END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' THEN
    RAISE EXCEPTION 'A non-empty recovery reason is required' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id=p_target_user_id AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
  ) THEN RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email' USING ERRCODE='22023'; END IF;
  IF NOT p_emergency AND EXISTS (
    SELECT 1 FROM platform_private.platform_operator_grants g
    JOIN auth.users u ON u.id=g.user_id
    WHERE g.is_active AND g.can_manage_operators
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS (
        SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id
      ))
  ) THEN
    RAISE EXCEPTION 'A recoverable manager is active; declare and explain an emergency to recover another' USING ERRCODE='55000';
  END IF;
  INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants)
  VALUES(p_target_user_id,true,true,true)
  ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=true,can_onboard_tenants=true,updated_at=pg_catalog.clock_timestamp();
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,target_user_id,reason,is_emergency)
  VALUES('recovery','platform_bootstrap',p_target_user_id,pg_catalog.btrim(p_reason),p_emergency);
END;
$function$;

CREATE FUNCTION public.current_operator_can_manage_operators()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT EXISTS (
    SELECT 1 FROM auth.users u JOIN platform_private.platform_operator_grants g ON g.user_id=u.id
    WHERE u.id=(SELECT auth.uid()) AND g.is_active AND g.can_manage_operators
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
  );
$function$;
REVOKE ALL ON FUNCTION public.current_operator_can_manage_operators() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.current_operator_can_manage_operators() TO authenticated;

CREATE FUNCTION public.platform_operator_grant_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_rows jsonb;
BEGIN
  IF NOT public.current_operator_can_manage_operators() THEN
    RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'user_id',g.user_id,'email',u.email,'is_active',g.is_active,
    'can_manage_operators',g.can_manage_operators,'can_onboard_tenants',g.can_onboard_tenants,
    'recoverable',u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)),
    'updated_at',g.updated_at
  ) ORDER BY g.is_active DESC,u.email),'[]'::jsonb) INTO v_rows
  FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id;
  RETURN v_rows;
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_operator_grant_list() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_operator_grant_list() TO authenticated;

CREATE FUNCTION public.change_platform_operator_grant(
  p_target_email text,p_action text,p_can_manage_operators boolean,p_can_onboard_tenants boolean,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_target uuid;
  v_email text;
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action));
  v_email_input text := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  v_before jsonb;
  v_after jsonb;
  v_exists boolean;
  v_active boolean;
  v_old_manage boolean;
  v_old_onboard boolean;
  v_new_active boolean;
  v_new_manage boolean;
  v_new_onboard boolean;
  v_target_recoverable boolean;
  v_other_manager boolean;
  v_audit_action text;
BEGIN
  IF v_action IS NULL OR v_action NOT IN ('grant','update','revoke') THEN
    RAISE EXCEPTION 'platform_operator_action_invalid' USING ERRCODE='22023';
  END IF;
  IF v_email_input IS NULL OR v_email_input='' OR pg_catalog.length(v_email_input)>254 OR v_email_input !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'platform_operator_email_invalid' USING ERRCODE='22023';
  END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' OR pg_catalog.length(pg_catalog.btrim(p_reason))>500 THEN
    RAISE EXCEPTION 'platform_operator_reason_required' USING ERRCODE='22023';
  END IF;
  IF v_action IN ('grant','update') AND COALESCE(p_can_manage_operators,false)=false AND COALESCE(p_can_onboard_tenants,false)=false THEN
    RAISE EXCEPTION 'platform_operator_capability_required' USING ERRCODE='22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF NOT public.current_operator_can_manage_operators() THEN
    RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT id,email INTO v_target,v_email FROM auth.users WHERE pg_catalog.lower(email)=v_email_input;
  IF NOT FOUND THEN RAISE EXCEPTION 'platform_operator_target_unavailable' USING ERRCODE='22023'; END IF;
  SELECT deleted_at IS NULL AND email_confirmed_at IS NOT NULL
      AND (banned_until IS NULL OR banned_until<=pg_catalog.now())
      AND encrypted_password IS NOT NULL AND encrypted_password<>''
      AND (invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=auth.users.id))
    INTO v_target_recoverable FROM auth.users WHERE id=v_target;
  IF v_action IN ('grant','update') AND NOT v_target_recoverable THEN
    RAISE EXCEPTION 'platform_operator_target_unavailable' USING ERRCODE='22023';
  END IF;

  SELECT true,is_active,can_manage_operators,can_onboard_tenants,
    pg_catalog.jsonb_build_object('is_active',is_active,'can_manage_operators',can_manage_operators,'can_onboard_tenants',can_onboard_tenants)
  INTO v_exists,v_active,v_old_manage,v_old_onboard,v_before
  FROM platform_private.platform_operator_grants WHERE user_id=v_target FOR UPDATE;
  v_exists := COALESCE(v_exists,false);
  v_active := COALESCE(v_active,false);
  v_old_manage := COALESCE(v_old_manage,false);
  v_old_onboard := COALESCE(v_old_onboard,false);

  IF v_action='grant' AND v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-active','user_id',v_target); END IF;
  IF v_action='update' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','not-active','user_id',v_target); END IF;
  IF v_action='revoke' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-revoked','user_id',v_target); END IF;

  v_new_active := v_action<>'revoke';
  v_new_manage := CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_operators,false) END;
  v_new_onboard := CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_onboard_tenants,false) END;
  v_after := pg_catalog.jsonb_build_object('is_active',v_new_active,'can_manage_operators',v_new_manage,'can_onboard_tenants',v_new_onboard);
  IF v_exists AND v_active=v_new_active AND v_old_manage=v_new_manage AND v_old_onboard=v_new_onboard THEN
    RETURN pg_catalog.jsonb_build_object('state','unchanged','user_id',v_target);
  END IF;

  IF v_target_recoverable AND v_old_manage AND NOT v_new_manage THEN
    SELECT EXISTS (
      SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
      WHERE g.user_id<>v_target AND g.is_active AND g.can_manage_operators
        AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
        AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
        AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
        AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
    ) INTO v_other_manager;
    IF NOT v_other_manager THEN RAISE EXCEPTION 'platform_operator_last_manager' USING ERRCODE='23514'; END IF;
  END IF;

  IF v_action='revoke' THEN
    UPDATE platform_private.platform_operator_grants SET is_active=false,can_manage_operators=false,can_onboard_tenants=false,
      updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action := 'operator_grant_revoked';
  ELSIF v_action='grant' THEN
    INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants)
    VALUES(v_target,true,v_new_manage,v_new_onboard)
    ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=EXCLUDED.can_manage_operators,
      can_onboard_tenants=EXCLUDED.can_onboard_tenants,updated_at=pg_catalog.clock_timestamp();
    v_audit_action := CASE WHEN v_exists THEN 'operator_grant_updated' ELSE 'operator_grant_created' END;
  ELSE
    UPDATE platform_private.platform_operator_grants SET can_manage_operators=v_new_manage,can_onboard_tenants=v_new_onboard,
      updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action := 'operator_grant_updated';
  END IF;

  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,actor_user_id,target_user_id,reason,before_state,after_state)
  VALUES(v_audit_action,'platform_operator',v_actor,v_target,pg_catalog.btrim(p_reason),COALESCE(v_before,'null'::jsonb),v_after);
  RETURN pg_catalog.jsonb_build_object('state',v_action,'user_id',v_target,'email',v_email,'is_active',v_new_active,
    'can_manage_operators',v_new_manage,'can_onboard_tenants',v_new_onboard);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,text) TO authenticated;
