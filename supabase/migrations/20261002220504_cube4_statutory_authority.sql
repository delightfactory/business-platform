-- Frozen Payroll section21: explicit Compliance capability, never inherited.
-- No statutory pack is seeded, verified, activated or altered.
ALTER TABLE platform_private.platform_operator_grants ADD COLUMN can_manage_statutory_rules boolean NOT NULL DEFAULT false;
ALTER TABLE platform_private.platform_operator_grants DROP CONSTRAINT platform_operator_active_grant_has_capability;
ALTER TABLE platform_private.platform_operator_grants ADD CONSTRAINT platform_operator_active_grant_has_capability CHECK(NOT is_active OR can_manage_operators OR can_onboard_tenants OR can_manage_tenant_lifecycle OR can_manage_commercial_access OR can_manage_statutory_rules);
ALTER TABLE platform_private.platform_operator_grants ADD CONSTRAINT statutory_authority_requires_active_operator CHECK(is_active OR NOT can_manage_statutory_rules);
CREATE FUNCTION public.current_operator_can_manage_statutory_rules()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT EXISTS (SELECT 1 FROM auth.users u JOIN platform_private.platform_operator_grants g ON g.user_id=u.id
    WHERE u.id=(SELECT auth.uid()) AND g.is_active AND g.can_manage_statutory_rules
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)));
$function$;
CREATE OR REPLACE FUNCTION public.platform_operator_grant_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_rows jsonb;
BEGIN
  IF NOT public.current_operator_can_manage_operators() THEN RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501'; END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('user_id',g.user_id,'email',u.email,'is_active',g.is_active,
    'can_manage_operators',g.can_manage_operators,'can_onboard_tenants',g.can_onboard_tenants,
    'can_manage_tenant_lifecycle',g.can_manage_tenant_lifecycle,'can_manage_commercial_access',g.can_manage_commercial_access,'can_manage_statutory_rules',g.can_manage_statutory_rules,
    'recoverable',u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)),
    'updated_at',g.updated_at) ORDER BY g.is_active DESC,u.email),'[]'::jsonb) INTO v_rows
  FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id;
  RETURN v_rows;
END;
$function$;
CREATE FUNCTION public.change_platform_operator_authority(
  p_target_email text,p_action text,p_can_manage_operators boolean,p_can_onboard_tenants boolean,
  p_can_manage_tenant_lifecycle boolean,p_can_manage_commercial_access boolean,p_can_manage_statutory_rules boolean,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid()); v_target uuid; v_email text;
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action)); v_email_input text := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  v_before jsonb; v_after jsonb; v_exists boolean; v_active boolean;
  v_old_manage boolean; v_old_onboard boolean; v_old_lifecycle boolean; v_old_commercial boolean; v_old_statutory boolean;
  v_new_active boolean; v_new_manage boolean; v_new_onboard boolean; v_new_lifecycle boolean; v_new_commercial boolean; v_new_statutory boolean;
  v_target_recoverable boolean; v_other_manager boolean; v_audit_action text;
BEGIN
  IF v_action IS NULL OR v_action NOT IN ('grant','update','revoke') THEN RAISE EXCEPTION 'platform_operator_action_invalid' USING ERRCODE='22023'; END IF;
  IF v_email_input IS NULL OR v_email_input='' OR pg_catalog.length(v_email_input)>254 OR v_email_input !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'platform_operator_email_invalid' USING ERRCODE='22023'; END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' OR pg_catalog.length(pg_catalog.btrim(p_reason))>500 THEN
    RAISE EXCEPTION 'platform_operator_reason_required' USING ERRCODE='22023'; END IF;
  IF v_action IN ('grant','update') AND NOT (COALESCE(p_can_manage_operators,false) OR COALESCE(p_can_onboard_tenants,false)
    OR COALESCE(p_can_manage_tenant_lifecycle,false) OR COALESCE(p_can_manage_commercial_access,false) OR COALESCE(p_can_manage_statutory_rules,false)) THEN
    RAISE EXCEPTION 'platform_operator_capability_required' USING ERRCODE='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF NOT public.current_operator_can_manage_operators() THEN RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501'; END IF;
  SELECT id,email INTO v_target,v_email FROM auth.users WHERE pg_catalog.lower(email)=v_email_input;
  IF NOT FOUND THEN RAISE EXCEPTION 'platform_operator_target_unavailable' USING ERRCODE='22023'; END IF;
  SELECT deleted_at IS NULL AND email_confirmed_at IS NOT NULL AND (banned_until IS NULL OR banned_until<=pg_catalog.now())
      AND encrypted_password IS NOT NULL AND encrypted_password<>''
      AND (invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=auth.users.id))
    INTO v_target_recoverable FROM auth.users WHERE id=v_target;
  IF v_action IN ('grant','update') AND NOT v_target_recoverable THEN RAISE EXCEPTION 'platform_operator_target_unavailable' USING ERRCODE='22023'; END IF;
  SELECT true,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access,can_manage_statutory_rules,
    pg_catalog.jsonb_build_object('is_active',is_active,'can_manage_operators',can_manage_operators,'can_onboard_tenants',can_onboard_tenants,
      'can_manage_tenant_lifecycle',can_manage_tenant_lifecycle,'can_manage_commercial_access',can_manage_commercial_access,'can_manage_statutory_rules',can_manage_statutory_rules)
  INTO v_exists,v_active,v_old_manage,v_old_onboard,v_old_lifecycle,v_old_commercial,v_old_statutory,v_before
  FROM platform_private.platform_operator_grants WHERE user_id=v_target FOR UPDATE;
  v_exists:=COALESCE(v_exists,false); v_active:=COALESCE(v_active,false); v_old_manage:=COALESCE(v_old_manage,false);
  v_old_onboard:=COALESCE(v_old_onboard,false); v_old_lifecycle:=COALESCE(v_old_lifecycle,false); v_old_commercial:=COALESCE(v_old_commercial,false); v_old_statutory:=COALESCE(v_old_statutory,false);
  IF v_action='grant' AND v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-active','user_id',v_target); END IF;
  IF v_action='update' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','not-active','user_id',v_target); END IF;
  IF v_action='revoke' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-revoked','user_id',v_target); END IF;
  v_new_active:=v_action<>'revoke'; v_new_manage:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_operators,false) END;
  v_new_onboard:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_onboard_tenants,false) END;
  v_new_lifecycle:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_tenant_lifecycle,false) END;
  v_new_commercial:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_commercial_access,false) END;
  v_new_statutory:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_statutory_rules,false) END;
  v_after:=pg_catalog.jsonb_build_object('is_active',v_new_active,'can_manage_operators',v_new_manage,'can_onboard_tenants',v_new_onboard,
    'can_manage_tenant_lifecycle',v_new_lifecycle,'can_manage_commercial_access',v_new_commercial,'can_manage_statutory_rules',v_new_statutory);
  IF v_exists AND v_active=v_new_active AND v_old_manage=v_new_manage AND v_old_onboard=v_new_onboard
    AND v_old_lifecycle=v_new_lifecycle AND v_old_commercial=v_new_commercial AND v_old_statutory=v_new_statutory THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','user_id',v_target); END IF;
  IF v_target_recoverable AND v_old_manage AND NOT v_new_manage THEN
    SELECT EXISTS (SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
      WHERE g.user_id<>v_target AND g.is_active AND g.can_manage_operators AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
        AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
        AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))) INTO v_other_manager;
    IF NOT v_other_manager THEN RAISE EXCEPTION 'platform_operator_last_manager' USING ERRCODE='23514'; END IF;
  END IF;
  IF v_action='revoke' THEN
    UPDATE platform_private.platform_operator_grants SET is_active=false,can_manage_operators=false,can_onboard_tenants=false,
      can_manage_tenant_lifecycle=false,can_manage_commercial_access=false,can_manage_statutory_rules=false,updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action:='operator_grant_revoked';
  ELSIF v_action='grant' THEN
    INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access,can_manage_statutory_rules)
    VALUES(v_target,true,v_new_manage,v_new_onboard,v_new_lifecycle,v_new_commercial,v_new_statutory)
    ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=EXCLUDED.can_manage_operators,
      can_onboard_tenants=EXCLUDED.can_onboard_tenants,can_manage_tenant_lifecycle=EXCLUDED.can_manage_tenant_lifecycle,
      can_manage_commercial_access=EXCLUDED.can_manage_commercial_access,can_manage_statutory_rules=EXCLUDED.can_manage_statutory_rules,updated_at=pg_catalog.clock_timestamp();
    v_audit_action:=CASE WHEN v_exists THEN 'operator_grant_updated' ELSE 'operator_grant_created' END;
  ELSE
    UPDATE platform_private.platform_operator_grants SET can_manage_operators=v_new_manage,can_onboard_tenants=v_new_onboard,
      can_manage_tenant_lifecycle=v_new_lifecycle,can_manage_commercial_access=v_new_commercial,can_manage_statutory_rules=v_new_statutory,updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action:='operator_grant_updated';
  END IF;
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,actor_user_id,target_user_id,reason,before_state,after_state)
    VALUES(v_audit_action,'platform_operator',v_actor,v_target,pg_catalog.btrim(p_reason),COALESCE(v_before,'null'::jsonb),v_after);
  RETURN pg_catalog.jsonb_build_object('state',v_action,'user_id',v_target,'email',v_email,'is_active',v_new_active,
    'can_manage_operators',v_new_manage,'can_onboard_tenants',v_new_onboard,'can_manage_tenant_lifecycle',v_new_lifecycle,
    'can_manage_commercial_access',v_new_commercial,'can_manage_statutory_rules',v_new_statutory);
END;
$function$;

-- Retain the old named endpoint for existing clients. Updating its four tasks
-- preserves explicitly granted Compliance; revoke/reactivation clears it.
CREATE OR REPLACE FUNCTION public.change_platform_operator_grant(
 p_target_email text,p_action text,p_can_manage_operators boolean,p_can_onboard_tenants boolean,
 p_can_manage_tenant_lifecycle boolean,p_can_manage_commercial_access boolean,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE compliance boolean:=false;
BEGIN
 PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
 IF NOT public.current_operator_can_manage_operators() THEN RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501';END IF;
 IF pg_catalog.lower(pg_catalog.btrim(p_action))='update' THEN
  SELECT g.can_manage_statutory_rules INTO compliance FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
  WHERE pg_catalog.lower(u.email)=pg_catalog.lower(pg_catalog.btrim(p_target_email)) AND g.is_active;
 END IF;
 RETURN public.change_platform_operator_authority(p_target_email,p_action,p_can_manage_operators,p_can_onboard_tenants,
  p_can_manage_tenant_lifecycle,p_can_manage_commercial_access,coalesce(compliance,false),p_reason);
END $f$;
REVOKE ALL ON FUNCTION public.change_platform_operator_authority(text,text,boolean,boolean,boolean,boolean,boolean,text),
 public.current_operator_can_manage_statutory_rules() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_platform_operator_authority(text,text,boolean,boolean,boolean,boolean,boolean,text),
 public.current_operator_can_manage_statutory_rules() TO authenticated;
