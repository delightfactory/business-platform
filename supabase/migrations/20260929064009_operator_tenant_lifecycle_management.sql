-- Tenant lifecycle authority is an independent Platform Operator capability.
ALTER TABLE platform_private.platform_operator_grants
  ADD COLUMN can_manage_tenant_lifecycle boolean NOT NULL DEFAULT false;
ALTER TABLE platform_private.platform_operator_grants
  DROP CONSTRAINT platform_operator_active_grant_has_capability;
ALTER TABLE platform_private.platform_operator_grants
  ADD CONSTRAINT platform_operator_active_grant_has_capability
  CHECK (NOT is_active OR can_manage_operators OR can_onboard_tenants OR can_manage_tenant_lifecycle);

-- Do not leave an older callable overload that silently drops the new capability.
DROP FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,text);

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
  INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle)
  VALUES(p_target_user_id,true,true,true,true)
  ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=true,can_onboard_tenants=true,
    can_manage_tenant_lifecycle=true,updated_at=pg_catalog.clock_timestamp();
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
    SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.is_active AND g.can_manage_operators AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
  ) THEN RAISE EXCEPTION 'A recoverable manager is active; declare and explain an emergency to recover another' USING ERRCODE='55000'; END IF;
  INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle)
  VALUES(p_target_user_id,true,true,true,true)
  ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=true,can_onboard_tenants=true,
    can_manage_tenant_lifecycle=true,updated_at=pg_catalog.clock_timestamp();
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,target_user_id,reason,is_emergency)
  VALUES('recovery','platform_bootstrap',p_target_user_id,pg_catalog.btrim(p_reason),p_emergency);
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_operator_grant_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_rows jsonb;
BEGIN
  IF NOT public.current_operator_can_manage_operators() THEN
    RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'user_id',g.user_id,'email',u.email,'is_active',g.is_active,
    'can_manage_operators',g.can_manage_operators,'can_onboard_tenants',g.can_onboard_tenants,
    'can_manage_tenant_lifecycle',g.can_manage_tenant_lifecycle,
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
  p_target_email text,p_action text,p_can_manage_operators boolean,p_can_onboard_tenants boolean,
  p_can_manage_tenant_lifecycle boolean,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid()); v_target uuid; v_email text;
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action));
  v_email_input text := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  v_before jsonb; v_after jsonb; v_exists boolean; v_active boolean;
  v_old_manage boolean; v_old_onboard boolean; v_old_lifecycle boolean;
  v_new_active boolean; v_new_manage boolean; v_new_onboard boolean; v_new_lifecycle boolean;
  v_target_recoverable boolean; v_other_manager boolean; v_audit_action text;
BEGIN
  IF v_action IS NULL OR v_action NOT IN ('grant','update','revoke') THEN RAISE EXCEPTION 'platform_operator_action_invalid' USING ERRCODE='22023'; END IF;
  IF v_email_input IS NULL OR v_email_input='' OR pg_catalog.length(v_email_input)>254 OR v_email_input !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'platform_operator_email_invalid' USING ERRCODE='22023';
  END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' OR pg_catalog.length(pg_catalog.btrim(p_reason))>500 THEN
    RAISE EXCEPTION 'platform_operator_reason_required' USING ERRCODE='22023';
  END IF;
  IF v_action IN ('grant','update') AND NOT (COALESCE(p_can_manage_operators,false) OR COALESCE(p_can_onboard_tenants,false) OR COALESCE(p_can_manage_tenant_lifecycle,false)) THEN
    RAISE EXCEPTION 'platform_operator_capability_required' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF NOT public.current_operator_can_manage_operators() THEN RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501'; END IF;
  SELECT id,email INTO v_target,v_email FROM auth.users WHERE pg_catalog.lower(email)=v_email_input;
  IF NOT FOUND THEN RAISE EXCEPTION 'platform_operator_target_unavailable' USING ERRCODE='22023'; END IF;
  SELECT deleted_at IS NULL AND email_confirmed_at IS NOT NULL AND (banned_until IS NULL OR banned_until<=pg_catalog.now())
      AND encrypted_password IS NOT NULL AND encrypted_password<>''
      AND (invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=auth.users.id))
    INTO v_target_recoverable FROM auth.users WHERE id=v_target;
  IF v_action IN ('grant','update') AND NOT v_target_recoverable THEN RAISE EXCEPTION 'platform_operator_target_unavailable' USING ERRCODE='22023'; END IF;
  SELECT true,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,
    pg_catalog.jsonb_build_object('is_active',is_active,'can_manage_operators',can_manage_operators,
      'can_onboard_tenants',can_onboard_tenants,'can_manage_tenant_lifecycle',can_manage_tenant_lifecycle)
  INTO v_exists,v_active,v_old_manage,v_old_onboard,v_old_lifecycle,v_before
  FROM platform_private.platform_operator_grants WHERE user_id=v_target FOR UPDATE;
  v_exists:=COALESCE(v_exists,false); v_active:=COALESCE(v_active,false);
  v_old_manage:=COALESCE(v_old_manage,false); v_old_onboard:=COALESCE(v_old_onboard,false); v_old_lifecycle:=COALESCE(v_old_lifecycle,false);
  IF v_action='grant' AND v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-active','user_id',v_target); END IF;
  IF v_action='update' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','not-active','user_id',v_target); END IF;
  IF v_action='revoke' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-revoked','user_id',v_target); END IF;
  v_new_active:=v_action<>'revoke';
  v_new_manage:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_operators,false) END;
  v_new_onboard:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_onboard_tenants,false) END;
  v_new_lifecycle:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_tenant_lifecycle,false) END;
  v_after:=pg_catalog.jsonb_build_object('is_active',v_new_active,'can_manage_operators',v_new_manage,
    'can_onboard_tenants',v_new_onboard,'can_manage_tenant_lifecycle',v_new_lifecycle);
  IF v_exists AND v_active=v_new_active AND v_old_manage=v_new_manage AND v_old_onboard=v_new_onboard AND v_old_lifecycle=v_new_lifecycle THEN
    RETURN pg_catalog.jsonb_build_object('state','unchanged','user_id',v_target);
  END IF;
  IF v_target_recoverable AND v_old_manage AND NOT v_new_manage THEN
    SELECT EXISTS (
      SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
      WHERE g.user_id<>v_target AND g.is_active AND g.can_manage_operators AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
        AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
        AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
    ) INTO v_other_manager;
    IF NOT v_other_manager THEN RAISE EXCEPTION 'platform_operator_last_manager' USING ERRCODE='23514'; END IF;
  END IF;
  IF v_action='revoke' THEN
    UPDATE platform_private.platform_operator_grants SET is_active=false,can_manage_operators=false,can_onboard_tenants=false,
      can_manage_tenant_lifecycle=false,updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action:='operator_grant_revoked';
  ELSIF v_action='grant' THEN
    INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle)
    VALUES(v_target,true,v_new_manage,v_new_onboard,v_new_lifecycle)
    ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=EXCLUDED.can_manage_operators,
      can_onboard_tenants=EXCLUDED.can_onboard_tenants,can_manage_tenant_lifecycle=EXCLUDED.can_manage_tenant_lifecycle,updated_at=pg_catalog.clock_timestamp();
    v_audit_action:=CASE WHEN v_exists THEN 'operator_grant_updated' ELSE 'operator_grant_created' END;
  ELSE
    UPDATE platform_private.platform_operator_grants SET can_manage_operators=v_new_manage,can_onboard_tenants=v_new_onboard,
      can_manage_tenant_lifecycle=v_new_lifecycle,updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action:='operator_grant_updated';
  END IF;
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,actor_user_id,target_user_id,reason,before_state,after_state)
  VALUES(v_audit_action,'platform_operator',v_actor,v_target,pg_catalog.btrim(p_reason),COALESCE(v_before,'null'::jsonb),v_after);
  RETURN pg_catalog.jsonb_build_object('state',v_action,'user_id',v_target,'email',v_email,'is_active',v_new_active,
    'can_manage_operators',v_new_manage,'can_onboard_tenants',v_new_onboard,'can_manage_tenant_lifecycle',v_new_lifecycle);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,boolean,text) TO authenticated;

CREATE FUNCTION public.current_operator_can_manage_tenant_lifecycle()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT EXISTS (
    SELECT 1 FROM auth.users u JOIN platform_private.platform_operator_grants g ON g.user_id=u.id
    WHERE u.id=(SELECT auth.uid()) AND g.is_active AND g.can_manage_tenant_lifecycle
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
  );
$function$;
REVOKE ALL ON FUNCTION public.current_operator_can_manage_tenant_lifecycle() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.current_operator_can_manage_tenant_lifecycle() TO authenticated;

CREATE TABLE platform_core.tenant_lifecycle_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  from_state text NOT NULL CHECK (from_state IN ('active','suspended','archived')),
  to_state text NOT NULL CHECK (to_state IN ('active','suspended','archived')),
  reason text NOT NULL CHECK (COALESCE(NULLIF(pg_catalog.btrim(reason),''),'')<>'' AND pg_catalog.length(reason)<=500),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CHECK (from_state<>to_state)
);
ALTER TABLE platform_core.tenant_lifecycle_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_lifecycle_audit_events FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX tenant_lifecycle_audit_tenant_time_idx ON platform_core.tenant_lifecycle_audit_events(tenant_id,created_at DESC);

CREATE FUNCTION platform_core.prevent_tenant_lifecycle_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'Tenant lifecycle audit events are append-only' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_lifecycle_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER tenant_lifecycle_audit_append_only
BEFORE UPDATE OR DELETE ON platform_core.tenant_lifecycle_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_lifecycle_audit_mutation();

CREATE FUNCTION public.platform_tenant_lifecycle_list()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_rows jsonb;
BEGIN
  IF NOT public.current_operator_can_manage_tenant_lifecycle() THEN RAISE EXCEPTION 'tenant_lifecycle_forbidden' USING ERRCODE='42501'; END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'tenant_id',t.id,'tenant_name',t.display_name,'lifecycle_state',t.lifecycle_state
  ) ORDER BY t.display_name,t.id),'[]'::jsonb) INTO v_rows FROM platform_core.tenants t;
  RETURN v_rows;
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_tenant_lifecycle_list() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_lifecycle_list() TO authenticated;

CREATE FUNCTION public.change_tenant_lifecycle(p_tenant_id uuid,p_expected_state text,p_target_state text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_current_state text; v_name text;
BEGIN
  IF p_tenant_id IS NULL OR p_expected_state IS NULL OR p_expected_state NOT IN ('active','suspended','archived')
      OR p_target_state IS NULL OR p_target_state NOT IN ('active','suspended','archived') THEN
    RAISE EXCEPTION 'tenant_lifecycle_input_invalid' USING ERRCODE='22023';
  END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' OR pg_catalog.length(pg_catalog.btrim(p_reason))>500 THEN
    RAISE EXCEPTION 'tenant_lifecycle_reason_required' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT public.current_operator_can_manage_tenant_lifecycle() THEN RAISE EXCEPTION 'tenant_lifecycle_forbidden' USING ERRCODE='42501'; END IF;
  SELECT lifecycle_state,display_name INTO v_current_state,v_name FROM platform_core.tenants WHERE id=p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_lifecycle_tenant_not_found' USING ERRCODE='P0002'; END IF;
  IF v_current_state<>p_expected_state THEN RAISE EXCEPTION 'tenant_lifecycle_state_changed' USING ERRCODE='40001'; END IF;
  IF NOT (
    (v_current_state='active' AND p_target_state IN ('suspended','archived')) OR
    (v_current_state='suspended' AND p_target_state IN ('active','archived')) OR
    (v_current_state='archived' AND p_target_state='suspended')
  ) THEN RAISE EXCEPTION 'tenant_lifecycle_transition_invalid' USING ERRCODE='23514'; END IF;
  UPDATE platform_core.tenants SET lifecycle_state=p_target_state WHERE id=p_tenant_id;
  INSERT INTO platform_core.tenant_lifecycle_audit_events(tenant_id,actor_user_id,from_state,to_state,reason)
  VALUES(p_tenant_id,v_actor,v_current_state,p_target_state,pg_catalog.btrim(p_reason));
  RETURN pg_catalog.jsonb_build_object('tenant_id',p_tenant_id,'tenant_name',v_name,'from_state',v_current_state,'to_state',p_target_state);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_tenant_lifecycle(uuid,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_tenant_lifecycle(uuid,text,text,text) TO authenticated;

CREATE FUNCTION public.current_tenant_spaces()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'tenant_id',t.id,'tenant_name',t.display_name,'lifecycle_state',t.lifecycle_state
  ) ORDER BY t.display_name),'[]'::jsonb)
  FROM platform_core.tenant_memberships m JOIN platform_core.tenants t ON t.id=m.tenant_id JOIN auth.users u ON u.id=m.user_id
  WHERE m.user_id=(SELECT auth.uid()) AND m.access_state='active'
    AND t.lifecycle_state IN ('active','suspended')
    AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now());
$function$;
REVOKE ALL ON FUNCTION public.current_tenant_spaces() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.current_tenant_spaces() TO authenticated;

CREATE FUNCTION public.tenant_lifecycle_status(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_state text; v_name text;
BEGIN
  SELECT t.lifecycle_state,t.display_name INTO v_state,v_name
  FROM platform_core.tenants t JOIN platform_core.tenant_memberships m ON m.tenant_id=t.id
  JOIN auth.users u ON u.id=m.user_id
  WHERE t.id=p_tenant_id AND m.user_id=v_actor AND m.access_state='active'
    AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now());
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_lifecycle_status_forbidden' USING ERRCODE='42501'; END IF;
  IF v_state='archived' THEN RETURN pg_catalog.jsonb_build_object('lifecycle_state','archived'); END IF;
  IF v_state='active' THEN RETURN pg_catalog.jsonb_build_object('lifecycle_state','active'); END IF;
  RETURN pg_catalog.jsonb_build_object('tenant_id',p_tenant_id,'tenant_name',v_name,'lifecycle_state',v_state);
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_lifecycle_status(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_lifecycle_status(uuid) TO authenticated;

-- Recheck Tenant permission after taking the same lock as lifecycle changes.
CREATE OR REPLACE FUNCTION public.create_tenant_member_invitation(p_tenant_id uuid,p_target_email text,p_idempotency_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_email text := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  v_signature jsonb; v_row platform_core.tenant_member_invitations%ROWTYPE; v_existing jsonb;
BEGIN
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF v_email IS NULL OR v_email='' OR pg_catalog.length(v_email)>254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' OR p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'tenant_member_invite_invalid' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  v_signature := pg_catalog.jsonb_build_object('tenant_id',p_tenant_id,'target_email',v_email,'role','tenant.member.v1');
  SELECT * INTO v_row FROM platform_core.tenant_member_invitations WHERE created_by_user_id=v_actor AND idempotency_key=p_idempotency_key FOR UPDATE;
  IF FOUND THEN
    IF v_row.request_signature<>v_signature THEN RAISE EXCEPTION 'tenant_member_invite_idempotency_conflict' USING ERRCODE='P0001'; END IF;
    RETURN pg_catalog.jsonb_build_object('id',v_row.id,'issuance',v_row.issuance,'target_email',v_row.target_email,
      'lifecycle_state',v_row.lifecycle_state,'delivery_state',v_row.delivery_state,'created',false,'state','existing');
  END IF;
  SELECT pg_catalog.jsonb_build_object('id',m.user_id,'access_state',m.access_state) INTO v_existing
  FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
  WHERE m.tenant_id=p_tenant_id AND pg_catalog.lower(u.email)=v_email;
  IF v_existing->>'access_state'='active' THEN RETURN pg_catalog.jsonb_build_object('created',false,'state','already_member'); END IF;
  IF v_existing IS NOT NULL AND EXISTS (
    SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING (tenant_id,role_id)
    WHERE mr.tenant_id=p_tenant_id AND mr.user_id=(v_existing->>'id')::uuid AND r.protects_tenant_admin
  ) THEN RAISE EXCEPTION 'tenant_member_admin_requires_governed_change' USING ERRCODE='42501'; END IF;
  WITH expired AS (
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=p_tenant_id AND target_email=v_email AND lifecycle_state='pending' AND expires_at<=pg_catalog.now()
    RETURNING id,target_email,issuance
  )
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    SELECT p_tenant_id,id,v_actor,target_email,'expired',pg_catalog.jsonb_build_object('issuance',issuance) FROM expired;
  SELECT * INTO v_row FROM platform_core.tenant_member_invitations WHERE tenant_id=p_tenant_id AND target_email=v_email AND lifecycle_state='pending' FOR UPDATE;
  IF FOUND THEN RETURN pg_catalog.jsonb_build_object('id',v_row.id,'issuance',v_row.issuance,'target_email',v_row.target_email,
    'lifecycle_state',v_row.lifecycle_state,'delivery_state',v_row.delivery_state,'created',false,'state','pending_exists'); END IF;
  INSERT INTO platform_core.tenant_roles(tenant_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
  VALUES(p_tenant_id,'tenant.member.v1',1,ARRAY[]::text[],false) ON CONFLICT(tenant_id,role_key,role_version) DO NOTHING;
  INSERT INTO platform_core.tenant_member_invitations(tenant_id,target_email,created_by_user_id,expires_at,idempotency_key,request_signature)
    VALUES(p_tenant_id,v_email,v_actor,pg_catalog.transaction_timestamp()+interval '7 days',p_idempotency_key,v_signature) RETURNING * INTO v_row;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(p_tenant_id,v_row.id,v_actor,v_email,'invitation_created',pg_catalog.jsonb_build_object('issuance',1,'role','tenant.member.v1'));
  RETURN pg_catalog.jsonb_build_object('id',v_row.id,'issuance',v_row.issuance,'target_email',v_email,'lifecycle_state','pending',
    'delivery_state','sending','created',true,'state','created');
END;
$function$;

CREATE OR REPLACE FUNCTION public.tenant_member_access_list(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_rows jsonb; v_limits jsonb; v_usage integer; v_limit_rows integer;
BEGIN
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  WITH expired AS (
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=p_tenant_id AND lifecycle_state='pending' AND expires_at<=pg_catalog.now()
    RETURNING id,target_email,issuance
  )
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    SELECT p_tenant_id,id,v_actor,target_email,'expired',pg_catalog.jsonb_build_object('issuance',issuance) FROM expired;
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'user_id',m.user_id,'email',u.email,'access_state',m.access_state,
    'role_key',CASE WHEN pg_catalog.cardinality(role_rows.role_keys)=1 THEN role_rows.role_keys[1] ELSE NULL END,
    'roles',COALESCE(role_rows.roles,'[]'::jsonb),'protected_admin',COALESCE(role_rows.protected_admin,false)
  ) ORDER BY u.email) INTO v_rows
  FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
  LEFT JOIN LATERAL (
    SELECT pg_catalog.array_agg(r.role_key ORDER BY r.role_key,r.role_version) AS role_keys,
      pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('role_key',r.role_key,'role_version',r.role_version) ORDER BY r.role_key,r.role_version) AS roles,
      pg_catalog.bool_or(r.protects_tenant_admin) AS protected_admin
    FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r ON r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id
    WHERE mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id
  ) role_rows ON true WHERE m.tenant_id=p_tenant_id;
  SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_memberships m
  WHERE m.tenant_id=p_tenant_id AND m.access_state='active';
  SELECT pg_catalog.count(*)::integer INTO v_limit_rows FROM platform_core.tenant_capability_limits l
  WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.users'
    AND l.valid_from<=pg_catalog.transaction_timestamp() AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());
  IF v_limit_rows<>1 THEN RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000'; END IF;
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',i.id,'target_email',i.target_email,'lifecycle_state',i.lifecycle_state,
    'delivery_state',i.delivery_state,'issuance',i.issuance,'expires_at',i.expires_at) ORDER BY i.created_at DESC)
    INTO v_limits FROM platform_core.tenant_member_invitations i WHERE i.tenant_id=p_tenant_id;
  RETURN pg_catalog.jsonb_build_object('memberships',COALESCE(v_rows,'[]'::jsonb),'invitations',COALESCE(v_limits,'[]'::jsonb),
    'seat_usage',v_usage,'seat_limit',(SELECT pg_catalog.jsonb_build_object('mode',l.limit_mode,'value',l.limit_value)
      FROM platform_core.tenant_capability_limits l WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.users'
        AND l.valid_from<=pg_catalog.transaction_timestamp() AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp())));
END;
$function$;

CREATE OR REPLACE FUNCTION public.reissue_tenant_member_invitation(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_tenant_id uuid; v_inv platform_core.tenant_member_invitations%ROWTYPE;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_tenant_id::text,90427));
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_inv.created_by_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_issuer_authority_lost' USING ERRCODE='42501';
  END IF;
  IF v_inv.lifecycle_state='pending' AND v_inv.expires_at<=pg_catalog.now() THEN
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
    INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
      VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'expired',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
    RETURN pg_catalog.jsonb_build_object('state','expired','created',false);
  END IF;
  IF v_inv.lifecycle_state<>'pending' THEN RETURN pg_catalog.jsonb_build_object('state',v_inv.lifecycle_state,'created',false); END IF;
  UPDATE platform_core.tenant_member_invitations SET issuance=issuance+1,expires_at=pg_catalog.transaction_timestamp()+interval '7 days',
    delivery_state='sending',delivery_error_code=NULL,updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id RETURNING * INTO v_inv;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'reissued',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
  RETURN pg_catalog.jsonb_build_object('id',v_inv.id,'issuance',v_inv.issuance,'target_email',v_inv.target_email,
    'lifecycle_state',v_inv.lifecycle_state,'delivery_state',v_inv.delivery_state,'created',true,'state','reissued');
END;
$function$;

CREATE OR REPLACE FUNCTION public.revoke_tenant_member_invitation(p_invitation_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_tenant_id uuid; v_inv platform_core.tenant_member_invitations%ROWTYPE;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_tenant_id::text,90427));
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF v_inv.lifecycle_state<>'pending' THEN RETURN false; END IF;
  UPDATE platform_core.tenant_member_invitations SET lifecycle_state='revoked',updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'revoked',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_tenant_member_invitation_delivery(
  p_invitation_id uuid,p_issuance integer,p_actor_user_id uuid,p_succeeded boolean,p_error_code text
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_inv platform_core.tenant_member_invitations%ROWTYPE; v_tenant_id uuid;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='42501'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_tenant_id::text,90427));
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR v_inv.issuance<>p_issuance OR v_inv.lifecycle_state<>'pending'
      OR NOT platform_private.has_tenant_permission(v_inv.tenant_id,p_actor_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='42501';
  END IF;
  UPDATE platform_core.tenant_member_invitations SET delivery_state=CASE WHEN p_succeeded THEN 'sent' ELSE 'failed' END,
    delivery_error_code=CASE WHEN p_succeeded THEN NULL ELSE pg_catalog.left(COALESCE(p_error_code,'auth_invite_failed'),80) END,
    updated_at=pg_catalog.clock_timestamp() WHERE id=p_invitation_id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,p_actor_user_id,v_inv.target_email,CASE WHEN p_succeeded THEN 'delivery_sent' ELSE 'delivery_failed' END,
      pg_catalog.jsonb_build_object('issuance',p_issuance,'error_code',CASE WHEN p_succeeded THEN NULL ELSE pg_catalog.left(COALESCE(p_error_code,'auth_invite_failed'),80) END));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_tenant_member_invitation_delivery(uuid,integer,uuid,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.record_tenant_member_invitation_delivery(uuid,integer,uuid,boolean,text) TO service_role;

CREATE OR REPLACE FUNCTION public.record_tenant_member_password_readiness(p_invitation_id uuid,p_issuance integer,p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_inv platform_core.tenant_member_invitations%ROWTYPE; v_tenant_id uuid; v_email text;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_tenant_id::text,90427));
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id AND issuance=p_issuance
    AND lifecycle_state='pending' AND expires_at>pg_catalog.now() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  IF NOT EXISTS (SELECT 1 FROM platform_core.tenants t WHERE t.id=v_inv.tenant_id AND t.lifecycle_state='active') THEN
    RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='42501';
  END IF;
  SELECT u.email INTO v_email FROM auth.users u WHERE u.id=p_user_id AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND u.invited_at IS NOT NULL
    AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>'';
  IF v_email IS NULL OR pg_catalog.lower(v_email)<>v_inv.target_email THEN RAISE EXCEPTION 'tenant_member_invite_identity_mismatch' USING ERRCODE='42501'; END IF;
  IF NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_inv.created_by_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_issuer_authority_lost' USING ERRCODE='42501';
  END IF;
  INSERT INTO platform_private.platform_auth_password_readiness(user_id,source_workflow,source_invitation_id,source_issuance)
    VALUES(p_user_id,'tenant_member_invitation',p_invitation_id,p_issuance) ON CONFLICT(user_id) DO NOTHING;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,p_user_id,v_inv.target_email,'credential_ready',pg_catalog.jsonb_build_object('issuance',p_issuance));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_tenant_member_password_readiness(uuid,integer,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_tenant_member_password_readiness(uuid,integer,uuid) TO service_role;
