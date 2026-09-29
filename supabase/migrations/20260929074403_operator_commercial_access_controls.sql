-- Commercial limit authority is independent from tenant setup and lifecycle authority.
ALTER TABLE platform_private.platform_operator_grants
  ADD COLUMN can_manage_commercial_access boolean NOT NULL DEFAULT false;
ALTER TABLE platform_private.platform_operator_grants
  DROP CONSTRAINT platform_operator_active_grant_has_capability;
ALTER TABLE platform_private.platform_operator_grants
  ADD CONSTRAINT platform_operator_active_grant_has_capability
  CHECK (NOT is_active OR can_manage_operators OR can_onboard_tenants
    OR can_manage_tenant_lifecycle OR can_manage_commercial_access);

DROP FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,boolean,text);

CREATE OR REPLACE FUNCTION platform_private.bootstrap_operator_manager(p_target_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  IF p_target_user_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id=p_target_user_id AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
  ) THEN RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email' USING ERRCODE='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g WHERE g.is_active AND g.can_manage_operators) THEN
    RAISE EXCEPTION 'A Platform Operator manager already exists; bootstrap is one-time' USING ERRCODE='55000';
  END IF;
  INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access)
  VALUES(p_target_user_id,true,true,true,true,true)
  ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=true,can_onboard_tenants=true,
    can_manage_tenant_lifecycle=true,can_manage_commercial_access=true,updated_at=pg_catalog.clock_timestamp();
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,target_user_id)
  VALUES('bootstrap','platform_bootstrap',p_target_user_id);
END;
$function$;

CREATE OR REPLACE FUNCTION platform_private.recover_operator_manager(p_target_user_id uuid,p_reason text,p_emergency boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  IF p_target_user_id IS NULL THEN RAISE EXCEPTION 'An existing Auth user is required' USING ERRCODE='22023'; END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' THEN RAISE EXCEPTION 'A non-empty recovery reason is required' USING ERRCODE='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412,115991);
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=p_target_user_id AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)))
    THEN RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email' USING ERRCODE='22023'; END IF;
  IF NOT p_emergency AND EXISTS (SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
      WHERE g.is_active AND g.can_manage_operators AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)))
    THEN RAISE EXCEPTION 'A recoverable manager is active; declare and explain an emergency to recover another' USING ERRCODE='55000'; END IF;
  INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access)
  VALUES(p_target_user_id,true,true,true,true,true)
  ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=true,can_onboard_tenants=true,
    can_manage_tenant_lifecycle=true,can_manage_commercial_access=true,updated_at=pg_catalog.clock_timestamp();
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,target_user_id,reason,is_emergency)
  VALUES('recovery','platform_bootstrap',p_target_user_id,pg_catalog.btrim(p_reason),p_emergency);
END;
$function$;

CREATE OR REPLACE FUNCTION public.current_operator_can_manage_commercial_access()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT EXISTS (SELECT 1 FROM auth.users u JOIN platform_private.platform_operator_grants g ON g.user_id=u.id
    WHERE u.id=(SELECT auth.uid()) AND g.is_active AND g.can_manage_commercial_access
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)));
$function$;
REVOKE ALL ON FUNCTION public.current_operator_can_manage_commercial_access() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.current_operator_can_manage_commercial_access() TO authenticated;

CREATE OR REPLACE FUNCTION public.platform_operator_grant_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_rows jsonb;
BEGIN
  IF NOT public.current_operator_can_manage_operators() THEN RAISE EXCEPTION 'platform_operator_manage_forbidden' USING ERRCODE='42501'; END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('user_id',g.user_id,'email',u.email,'is_active',g.is_active,
    'can_manage_operators',g.can_manage_operators,'can_onboard_tenants',g.can_onboard_tenants,
    'can_manage_tenant_lifecycle',g.can_manage_tenant_lifecycle,'can_manage_commercial_access',g.can_manage_commercial_access,
    'recoverable',u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
      AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)),
    'updated_at',g.updated_at) ORDER BY g.is_active DESC,u.email),'[]'::jsonb) INTO v_rows
  FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id;
  RETURN v_rows;
END;
$function$;

CREATE FUNCTION public.change_platform_operator_grant(
  p_target_email text,p_action text,p_can_manage_operators boolean,p_can_onboard_tenants boolean,
  p_can_manage_tenant_lifecycle boolean,p_can_manage_commercial_access boolean,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid()); v_target uuid; v_email text;
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action)); v_email_input text := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  v_before jsonb; v_after jsonb; v_exists boolean; v_active boolean;
  v_old_manage boolean; v_old_onboard boolean; v_old_lifecycle boolean; v_old_commercial boolean;
  v_new_active boolean; v_new_manage boolean; v_new_onboard boolean; v_new_lifecycle boolean; v_new_commercial boolean;
  v_target_recoverable boolean; v_other_manager boolean; v_audit_action text;
BEGIN
  IF v_action IS NULL OR v_action NOT IN ('grant','update','revoke') THEN RAISE EXCEPTION 'platform_operator_action_invalid' USING ERRCODE='22023'; END IF;
  IF v_email_input IS NULL OR v_email_input='' OR pg_catalog.length(v_email_input)>254 OR v_email_input !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'platform_operator_email_invalid' USING ERRCODE='22023'; END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' OR pg_catalog.length(pg_catalog.btrim(p_reason))>500 THEN
    RAISE EXCEPTION 'platform_operator_reason_required' USING ERRCODE='22023'; END IF;
  IF v_action IN ('grant','update') AND NOT (COALESCE(p_can_manage_operators,false) OR COALESCE(p_can_onboard_tenants,false)
    OR COALESCE(p_can_manage_tenant_lifecycle,false) OR COALESCE(p_can_manage_commercial_access,false)) THEN
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
  SELECT true,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access,
    pg_catalog.jsonb_build_object('is_active',is_active,'can_manage_operators',can_manage_operators,'can_onboard_tenants',can_onboard_tenants,
      'can_manage_tenant_lifecycle',can_manage_tenant_lifecycle,'can_manage_commercial_access',can_manage_commercial_access)
  INTO v_exists,v_active,v_old_manage,v_old_onboard,v_old_lifecycle,v_old_commercial,v_before
  FROM platform_private.platform_operator_grants WHERE user_id=v_target FOR UPDATE;
  v_exists:=COALESCE(v_exists,false); v_active:=COALESCE(v_active,false); v_old_manage:=COALESCE(v_old_manage,false);
  v_old_onboard:=COALESCE(v_old_onboard,false); v_old_lifecycle:=COALESCE(v_old_lifecycle,false); v_old_commercial:=COALESCE(v_old_commercial,false);
  IF v_action='grant' AND v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-active','user_id',v_target); END IF;
  IF v_action='update' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','not-active','user_id',v_target); END IF;
  IF v_action='revoke' AND NOT v_active THEN RETURN pg_catalog.jsonb_build_object('state','already-revoked','user_id',v_target); END IF;
  v_new_active:=v_action<>'revoke'; v_new_manage:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_operators,false) END;
  v_new_onboard:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_onboard_tenants,false) END;
  v_new_lifecycle:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_tenant_lifecycle,false) END;
  v_new_commercial:=CASE WHEN v_action='revoke' THEN false ELSE COALESCE(p_can_manage_commercial_access,false) END;
  v_after:=pg_catalog.jsonb_build_object('is_active',v_new_active,'can_manage_operators',v_new_manage,'can_onboard_tenants',v_new_onboard,
    'can_manage_tenant_lifecycle',v_new_lifecycle,'can_manage_commercial_access',v_new_commercial);
  IF v_exists AND v_active=v_new_active AND v_old_manage=v_new_manage AND v_old_onboard=v_new_onboard
    AND v_old_lifecycle=v_new_lifecycle AND v_old_commercial=v_new_commercial THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','user_id',v_target); END IF;
  IF v_target_recoverable AND v_old_manage AND NOT v_new_manage THEN
    SELECT EXISTS (SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
      WHERE g.user_id<>v_target AND g.is_active AND g.can_manage_operators AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
        AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
        AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))) INTO v_other_manager;
    IF NOT v_other_manager THEN RAISE EXCEPTION 'platform_operator_last_manager' USING ERRCODE='23514'; END IF;
  END IF;
  IF v_action='revoke' THEN
    UPDATE platform_private.platform_operator_grants SET is_active=false,can_manage_operators=false,can_onboard_tenants=false,
      can_manage_tenant_lifecycle=false,can_manage_commercial_access=false,updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action:='operator_grant_revoked';
  ELSIF v_action='grant' THEN
    INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access)
    VALUES(v_target,true,v_new_manage,v_new_onboard,v_new_lifecycle,v_new_commercial)
    ON CONFLICT(user_id) DO UPDATE SET is_active=true,can_manage_operators=EXCLUDED.can_manage_operators,
      can_onboard_tenants=EXCLUDED.can_onboard_tenants,can_manage_tenant_lifecycle=EXCLUDED.can_manage_tenant_lifecycle,
      can_manage_commercial_access=EXCLUDED.can_manage_commercial_access,updated_at=pg_catalog.clock_timestamp();
    v_audit_action:=CASE WHEN v_exists THEN 'operator_grant_updated' ELSE 'operator_grant_created' END;
  ELSE
    UPDATE platform_private.platform_operator_grants SET can_manage_operators=v_new_manage,can_onboard_tenants=v_new_onboard,
      can_manage_tenant_lifecycle=v_new_lifecycle,can_manage_commercial_access=v_new_commercial,updated_at=pg_catalog.clock_timestamp() WHERE user_id=v_target;
    v_audit_action:='operator_grant_updated';
  END IF;
  INSERT INTO platform_private.platform_operator_audit_events(action,actor_class,actor_user_id,target_user_id,reason,before_state,after_state)
    VALUES(v_audit_action,'platform_operator',v_actor,v_target,pg_catalog.btrim(p_reason),COALESCE(v_before,'null'::jsonb),v_after);
  RETURN pg_catalog.jsonb_build_object('state',v_action,'user_id',v_target,'email',v_email,'is_active',v_new_active,
    'can_manage_operators',v_new_manage,'can_onboard_tenants',v_new_onboard,'can_manage_tenant_lifecycle',v_new_lifecycle,
    'can_manage_commercial_access',v_new_commercial);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,boolean,boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_platform_operator_grant(text,text,boolean,boolean,boolean,boolean,text) TO authenticated;

CREATE TABLE platform_core.tenant_capability_limit_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  capability_key text NOT NULL CHECK (capability_key IN ('tenant.users','tenant.sites')),
  limit_key text NOT NULL CHECK ((capability_key='tenant.users' AND limit_key='max_users') OR (capability_key='tenant.sites' AND limit_key='max_sites')),
  effective_at timestamptz NOT NULL,
  before_state jsonb,
  after_state jsonb NOT NULL,
  reason text NOT NULL CHECK (COALESCE(NULLIF(pg_catalog.btrim(reason),''),'')<>'' AND pg_catalog.length(reason)<=500),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
ALTER TABLE platform_core.tenant_capability_limit_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_capability_limit_audit_events FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX tenant_capability_limit_audit_tenant_time_idx ON platform_core.tenant_capability_limit_audit_events(tenant_id,created_at DESC);

CREATE FUNCTION platform_core.prevent_tenant_capability_limit_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'tenant_capability_limit_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER tenant_capability_limit_audit_append_only
BEFORE UPDATE OR DELETE ON platform_core.tenant_capability_limit_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_capability_limit_audit_mutation();
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_capability_limit_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.platform_tenant_commercial_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_rows jsonb;
BEGIN
  IF NOT public.current_operator_can_manage_commercial_access() THEN RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501'; END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('tenant_id',t.id,'display_name',t.display_name,
    'lifecycle_state',t.lifecycle_state) ORDER BY t.display_name,t.id),'[]'::jsonb) INTO v_rows FROM platform_core.tenants t;
  RETURN v_rows;
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_tenant_commercial_list() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_commercial_list() TO authenticated;

CREATE FUNCTION public.platform_tenant_commercial_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_tenant jsonb; v_limits jsonb; v_users integer; v_sites integer; v_now timestamptz:=pg_catalog.clock_timestamp();
BEGIN
  IF NOT public.current_operator_can_manage_commercial_access() THEN RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501'; END IF;
  SELECT pg_catalog.jsonb_build_object('tenant_id',t.id,'display_name',t.display_name,'lifecycle_state',t.lifecycle_state) INTO v_tenant
    FROM platform_core.tenants t WHERE t.id=p_tenant_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE='P0002'; END IF;
  SELECT pg_catalog.count(*)::integer INTO v_users FROM platform_core.tenant_memberships m WHERE m.tenant_id=p_tenant_id AND m.access_state='active';
  SELECT pg_catalog.count(*)::integer INTO v_sites FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('capability_key',wanted.capability_key,'limit_key',wanted.limit_key,
    'status',CASE WHEN current_rows.n>1 THEN 'conflict' WHEN future_rows.n>0 THEN 'future_conflict'
      WHEN current_rows.n=0 THEN 'missing' ELSE 'effective' END,
    'mode',current_rows.limit_mode,'value',current_rows.limit_value,'valid_from',current_rows.valid_from,'effective_at',v_now,
    'usage',CASE WHEN wanted.capability_key='tenant.users' THEN v_users ELSE v_sites END)
    ORDER BY wanted.capability_key),'[]'::jsonb) INTO v_limits
  FROM (VALUES ('tenant.users','max_users'),('tenant.sites','max_sites')) AS wanted(capability_key,limit_key)
  LEFT JOIN LATERAL (SELECT pg_catalog.count(*)::integer n,pg_catalog.min(l.limit_mode) limit_mode,pg_catalog.min(l.limit_value) limit_value,
      pg_catalog.min(l.valid_from) valid_from FROM platform_core.tenant_capability_limits l
      WHERE l.tenant_id=p_tenant_id AND l.capability_key=wanted.capability_key AND l.limit_key=wanted.limit_key
        AND l.valid_from<=v_now AND (l.valid_until IS NULL OR l.valid_until>v_now)) current_rows ON true
  LEFT JOIN LATERAL (SELECT pg_catalog.count(*)::integer n FROM platform_core.tenant_capability_limits l
      WHERE l.tenant_id=p_tenant_id AND l.capability_key=wanted.capability_key AND l.limit_key=wanted.limit_key AND l.valid_from>v_now) future_rows ON true;
  RETURN v_tenant || pg_catalog.jsonb_build_object('limits',v_limits);
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_tenant_commercial_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_commercial_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.change_tenant_capability_limit(
  p_tenant_id uuid,p_capability_key text,p_limit_key text,p_limit_mode text,p_limit_value integer,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid:=(SELECT auth.uid()); v_now timestamptz; v_rows integer; v_future integer; v_old platform_core.tenant_capability_limits%ROWTYPE;
  v_before jsonb; v_after jsonb; v_usage integer;
BEGIN
  IF p_tenant_id IS NULL OR NOT ((p_capability_key='tenant.users' AND p_limit_key='max_users') OR (p_capability_key='tenant.sites' AND p_limit_key='max_sites'))
    THEN RAISE EXCEPTION 'commercial_limit_key_invalid' USING ERRCODE='22023'; END IF;
  IF p_limit_mode NOT IN ('limited','unlimited') OR (p_limit_mode='limited' AND (p_limit_value IS NULL OR p_limit_value<=0))
    OR (p_limit_mode='unlimited' AND p_limit_value IS NOT NULL) THEN RAISE EXCEPTION 'commercial_limit_value_invalid' USING ERRCODE='22023'; END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason),''),'')='' OR pg_catalog.length(pg_catalog.btrim(p_reason))>500
    THEN RAISE EXCEPTION 'commercial_limit_reason_required' USING ERRCODE='22023'; END IF;
  IF v_actor IS NULL OR NOT public.current_operator_can_manage_commercial_access() THEN RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT public.current_operator_can_manage_commercial_access() THEN RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM platform_core.tenants WHERE id=p_tenant_id) THEN RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE='P0002'; END IF;
  v_now:=pg_catalog.clock_timestamp();
  IF p_capability_key='tenant.users' THEN
    SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant_id AND access_state='active';
  ELSE
    SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_sites WHERE tenant_id=p_tenant_id AND is_active;
  END IF;
  SELECT pg_catalog.count(*)::integer INTO v_future FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key=p_capability_key AND l.limit_key=p_limit_key AND l.valid_from>v_now;
  IF v_future>0 THEN RAISE EXCEPTION 'commercial_limit_future_conflict' USING ERRCODE='23P01'; END IF;
  SELECT pg_catalog.count(*)::integer INTO v_rows FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key=p_capability_key AND l.limit_key=p_limit_key
      AND l.valid_from<=v_now AND (l.valid_until IS NULL OR l.valid_until>v_now);
  IF v_rows>1 THEN RAISE EXCEPTION 'commercial_limit_conflict' USING ERRCODE='55000'; END IF;
  IF v_rows=1 THEN
    SELECT * INTO v_old FROM platform_core.tenant_capability_limits l WHERE l.tenant_id=p_tenant_id AND l.capability_key=p_capability_key
      AND l.limit_key=p_limit_key AND l.valid_from<=v_now AND (l.valid_until IS NULL OR l.valid_until>v_now) FOR UPDATE;
    v_before:=pg_catalog.jsonb_build_object('mode',v_old.limit_mode,'value',v_old.limit_value,'valid_from',v_old.valid_from,'valid_until',v_old.valid_until,'usage',v_usage);
    UPDATE platform_core.tenant_capability_limits SET valid_until=v_now WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key
      AND limit_key=p_limit_key AND valid_from=v_old.valid_from;
  END IF;
  INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
  VALUES(p_tenant_id,p_capability_key,p_limit_key,p_limit_mode,p_limit_value,v_now,v_actor,'operator_commercial_access:'||pg_catalog.btrim(p_reason));
  v_after:=pg_catalog.jsonb_build_object('mode',p_limit_mode,'value',p_limit_value,'valid_from',v_now,'valid_until',NULL,'usage',v_usage);
  INSERT INTO platform_core.tenant_capability_limit_audit_events(tenant_id,actor_user_id,capability_key,limit_key,effective_at,before_state,after_state,reason)
  VALUES(p_tenant_id,v_actor,p_capability_key,p_limit_key,v_now,v_before,v_after,pg_catalog.btrim(p_reason));
  RETURN pg_catalog.jsonb_build_object('tenant_id',p_tenant_id,'capability_key',p_capability_key,'limit_key',p_limit_key,
    'mode',p_limit_mode,'value',p_limit_value,'effective_at',v_now,'usage',v_usage,'over_capacity',p_limit_mode='limited' AND v_usage>p_limit_value);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_tenant_capability_limit(uuid,text,text,text,integer,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_tenant_capability_limit(uuid,text,text,text,integer,text) TO authenticated;

-- Evaluate seat/site limits at the time acquired after the shared tenant mutation lock.
CREATE OR REPLACE FUNCTION public.accept_tenant_member_invitation(p_invitation_id uuid,p_issuance integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_inv platform_core.tenant_member_invitations%ROWTYPE; v_tenant_state text; v_lock_tenant uuid;
  v_now timestamptz;
  v_limit_mode text; v_limit integer; v_count integer; v_membership_state text; v_role uuid; v_email text; v_ready boolean;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'tenant_member_identity_required' USING ERRCODE='42501'; END IF;
  SELECT tenant_id INTO v_lock_tenant FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_lock_tenant::text,90427));
  v_now:=pg_catalog.clock_timestamp();
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  IF v_inv.issuance<>p_issuance THEN RAISE EXCEPTION 'tenant_member_invite_stale_issuance' USING ERRCODE='P0001'; END IF;
  IF v_inv.lifecycle_state='accepted' AND v_inv.accepted_user_id=v_actor THEN RETURN pg_catalog.jsonb_build_object('state','accepted','tenant_id',v_inv.tenant_id); END IF;
  IF v_inv.lifecycle_state<>'pending' THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  IF v_inv.expires_at<=pg_catalog.now() THEN
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
    INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
      VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'expired',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
    RETURN pg_catalog.jsonb_build_object('state','expired');
  END IF;
  IF NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_inv.created_by_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_issuer_authority_lost' USING ERRCODE='42501';
  END IF;
  SELECT u.email,u.encrypted_password IS NOT NULL AND u.encrypted_password<>'' AND
    (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
    INTO v_email,v_ready FROM auth.users u WHERE u.id=v_actor AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now());
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_identity_unverified' USING ERRCODE='42501'; END IF;
  IF pg_catalog.lower(v_email)<>v_inv.target_email THEN RAISE EXCEPTION 'tenant_member_identity_mismatch' USING ERRCODE='42501'; END IF;
  IF NOT v_ready THEN RAISE EXCEPTION 'tenant_member_password_required' USING ERRCODE='42501'; END IF;
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=v_inv.tenant_id FOR UPDATE;
  IF v_tenant_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'tenant_member_tenant_unavailable' USING ERRCODE='42501'; END IF;
  SELECT access_state INTO v_membership_state FROM platform_core.tenant_memberships WHERE tenant_id=v_inv.tenant_id AND user_id=v_actor FOR UPDATE;
  IF v_membership_state='active' THEN
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='accepted',accepted_user_id=v_actor,accepted_at=pg_catalog.clock_timestamp(),updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
    INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,subject_user_id,target_email,action,details)
      VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_actor,v_inv.target_email,'already_member',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
    RETURN pg_catalog.jsonb_build_object('state','already_member','tenant_id',v_inv.tenant_id);
  END IF;
  IF v_membership_state='inactive' AND EXISTS (
    SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
    WHERE mr.tenant_id=v_inv.tenant_id AND mr.user_id=v_actor AND r.protects_tenant_admin
  ) THEN RAISE EXCEPTION 'tenant_member_admin_requires_governed_change' USING ERRCODE='42501'; END IF;
  SELECT limit_mode,limit_value INTO v_limit_mode,v_limit FROM platform_core.tenant_capability_limits
    WHERE tenant_id=v_inv.tenant_id AND capability_key='tenant.users' AND valid_from<=v_now
      AND (valid_until IS NULL OR valid_until>v_now);
  IF NOT FOUND OR v_limit_mode NOT IN ('limited','unlimited') OR (v_limit_mode='limited' AND (v_limit IS NULL OR v_limit<=0)) THEN
    RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000';
  END IF;
  SELECT pg_catalog.count(*)::integer INTO v_count FROM platform_core.tenant_memberships WHERE tenant_id=v_inv.tenant_id AND access_state='active';
  IF v_limit_mode='limited' AND v_count>=v_limit AND v_membership_state IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'tenant_member_limit_full' USING ERRCODE='P0001';
  END IF;
  SELECT role_id INTO v_role FROM platform_core.tenant_roles WHERE tenant_id=v_inv.tenant_id AND role_key='tenant.member.v1' AND role_version=1;
  IF v_role IS NULL THEN RAISE EXCEPTION 'tenant_member_role_unavailable' USING ERRCODE='55000'; END IF;
  IF v_membership_state='inactive' THEN
    UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id=v_inv.tenant_id AND user_id=v_actor;
    DELETE FROM platform_core.membership_roles WHERE tenant_id=v_inv.tenant_id AND user_id=v_actor;
  ELSE
    INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
      VALUES(v_inv.tenant_id,v_actor,'active',v_inv.created_by_user_id);
  END IF;
  INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(v_inv.tenant_id,v_actor,v_role)
    ON CONFLICT DO NOTHING;
  UPDATE platform_core.tenant_member_invitations SET lifecycle_state='accepted',accepted_user_id=v_actor,accepted_at=pg_catalog.clock_timestamp(),updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,subject_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_actor,v_inv.target_email,CASE WHEN v_membership_state='inactive' THEN 'reactivated' ELSE 'accepted' END,
      pg_catalog.jsonb_build_object('issuance',v_inv.issuance,'role','tenant.member.v1'));
  RETURN pg_catalog.jsonb_build_object('state','accepted','tenant_id',v_inv.tenant_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.accept_tenant_member_invitation(uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.accept_tenant_member_invitation(uuid,integer) TO authenticated;
CREATE OR REPLACE FUNCTION public.set_tenant_member_access(p_tenant_id uuid,p_user_id uuid,p_access_state text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_previous text; v_limit_mode text; v_limit integer; v_usage integer; v_role uuid;
  v_now timestamptz;
BEGIN
  IF p_access_state NOT IN ('active','inactive') THEN RAISE EXCEPTION 'tenant_membership_state_invalid' USING ERRCODE='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  v_now:=pg_catalog.clock_timestamp();
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501'; END IF;
  SELECT access_state INTO v_previous FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant_id AND user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_membership_not_found' USING ERRCODE='P0002'; END IF;
  IF v_previous=p_access_state THEN RETURN true; END IF;
  IF EXISTS (
    SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING (tenant_id,role_id)
    WHERE mr.tenant_id=p_tenant_id AND mr.user_id=p_user_id AND r.protects_tenant_admin
  ) THEN
    RAISE EXCEPTION 'tenant_member_admin_requires_governed_change' USING ERRCODE='42501';
  END IF;
  IF p_access_state='active' THEN
    IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=p_user_id AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
      RAISE EXCEPTION 'tenant_member_target_unavailable' USING ERRCODE='42501';
    END IF;
    SELECT limit_mode,limit_value INTO v_limit_mode,v_limit FROM platform_core.tenant_capability_limits WHERE tenant_id=p_tenant_id AND capability_key='tenant.users'
      AND valid_from<=v_now AND (valid_until IS NULL OR valid_until>v_now);
    IF NOT FOUND OR v_limit_mode NOT IN ('limited','unlimited') OR (v_limit_mode='limited' AND (v_limit IS NULL OR v_limit<=0)) THEN RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000'; END IF;
    SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant_id AND access_state='active';
    IF v_limit_mode='limited' AND v_usage>=v_limit THEN RAISE EXCEPTION 'tenant_member_limit_full' USING ERRCODE='P0001'; END IF;
    INSERT INTO platform_core.tenant_roles(tenant_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
      VALUES(p_tenant_id,'tenant.member.v1',1,ARRAY[]::text[],false) ON CONFLICT(tenant_id,role_key,role_version) DO NOTHING;
    SELECT role_id INTO v_role FROM platform_core.tenant_roles WHERE tenant_id=p_tenant_id AND role_key='tenant.member.v1' AND role_version=1;
    IF v_role IS NULL THEN RAISE EXCEPTION 'tenant_member_role_unavailable' USING ERRCODE='55000'; END IF;
    DELETE FROM platform_core.membership_roles WHERE tenant_id=p_tenant_id AND user_id=p_user_id;
    INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(p_tenant_id,p_user_id,v_role);
  END IF;
  UPDATE platform_core.tenant_memberships SET access_state=p_access_state WHERE tenant_id=p_tenant_id AND user_id=p_user_id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,actor_user_id,subject_user_id,action,details)
    VALUES(p_tenant_id,v_actor,p_user_id,CASE WHEN p_access_state='active' THEN 'reactivated' ELSE 'deactivated' END,
      pg_catalog.jsonb_build_object('from',v_previous,'to',p_access_state));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.set_tenant_member_access(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.set_tenant_member_access(uuid,uuid,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.manage_tenant_site(
  p_tenant_id uuid,p_action text,p_site_id uuid,p_legal_entity_id uuid,p_display_name text,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action));
  v_display text := NULLIF(pg_catalog.btrim(p_display_name),'');
  v_reason text := NULLIF(pg_catalog.btrim(p_reason),'');
  v_site uuid; v_current_entity uuid; v_current_display text; v_is_active boolean; v_is_default boolean;
  v_now timestamptz;
  v_limit_mode text; v_limit_value integer; v_limit_count integer; v_usage integer;
  v_before jsonb; v_after jsonb;
  v_previous_default uuid; v_make_default boolean;
BEGIN
  IF p_tenant_id IS NULL OR v_action IS NULL OR v_action NOT IN ('create','update','default','deactivate','reactivate') THEN
    RAISE EXCEPTION 'tenant_site_input_invalid' USING ERRCODE='22023';
  END IF;
  IF v_action<>'create' AND p_legal_entity_id IS NOT NULL THEN
    RAISE EXCEPTION 'tenant_site_move_not_supported' USING ERRCODE='0A000';
  END IF;
  IF v_reason IS NULL OR pg_catalog.length(v_reason)>500 THEN RAISE EXCEPTION 'tenant_identity_reason_required' USING ERRCODE='22023'; END IF;
  IF v_action IN ('create','update') AND (v_display IS NULL OR pg_catalog.length(v_display)>160) THEN
    RAISE EXCEPTION 'tenant_site_name_invalid' USING ERRCODE='22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  v_now:=pg_catalog.clock_timestamp();
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.sites.manage') THEN
    RAISE EXCEPTION 'tenant_sites_manage_forbidden' USING ERRCODE='42501';
  END IF;

  IF v_action='create' THEN
    IF p_legal_entity_id IS NULL OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.id=p_legal_entity_id AND e.is_active) THEN
      RAISE EXCEPTION 'tenant_site_entity_unavailable' USING ERRCODE='23503';
    END IF;
    SELECT count(*)::integer,pg_catalog.max(l.limit_mode),pg_catalog.max(l.limit_value)
      INTO v_limit_count,v_limit_mode,v_limit_value
    FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.sites' AND l.limit_key='max_sites'
      AND l.valid_from<=v_now
      AND (l.valid_until IS NULL OR l.valid_until>v_now);
    IF v_limit_count<>1 OR v_limit_mode NOT IN ('limited','unlimited') THEN RAISE EXCEPTION 'tenant_sites_limit_unavailable' USING ERRCODE='55000'; END IF;
    SELECT count(*)::integer INTO v_usage FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active;
    IF v_limit_mode='limited' AND v_usage>=v_limit_value THEN RAISE EXCEPTION 'tenant_sites_capacity_reached' USING ERRCODE='23514'; END IF;
    SELECT NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active AND s.is_default)
      INTO v_make_default;
    INSERT INTO platform_core.tenant_sites(tenant_id,legal_entity_id,display_name,is_default)
    VALUES(p_tenant_id,p_legal_entity_id,v_display,v_make_default) RETURNING id INTO v_site;
    v_after:=pg_catalog.jsonb_build_object('legal_entity_id',p_legal_entity_id,'display_name',v_display,'is_active',true,'is_default',v_make_default);
    INSERT INTO platform_core.tenant_entities_sites_audit_events(tenant_id,actor_user_id,resource_type,resource_id,action,before_state,after_state,reason)
    VALUES(p_tenant_id,v_actor,'site',v_site,'created',NULL,v_after,v_reason);
    RETURN pg_catalog.jsonb_build_object('state','created','site_id',v_site);
  END IF;

  SELECT legal_entity_id,display_name,is_active,is_default INTO v_current_entity,v_current_display,v_is_active,v_is_default
  FROM platform_core.tenant_sites WHERE tenant_id=p_tenant_id AND id=p_site_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_site_not_found' USING ERRCODE='P0002'; END IF;
  v_site:=p_site_id;
  v_before:=pg_catalog.jsonb_build_object('legal_entity_id',v_current_entity,'display_name',v_current_display,'is_active',v_is_active,'is_default',v_is_default);

  IF v_action='update' THEN
    IF v_display IS NOT DISTINCT FROM v_current_display THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    UPDATE platform_core.tenant_sites SET display_name=v_display WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('display_name',v_display);
  ELSIF v_action='default' THEN
    IF NOT v_is_active OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.id=v_current_entity AND e.is_active) THEN
      RAISE EXCEPTION 'tenant_site_inactive' USING ERRCODE='23514';
    END IF;
    IF v_is_default THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    SELECT id INTO v_previous_default FROM platform_core.tenant_sites WHERE tenant_id=p_tenant_id AND is_default;
    UPDATE platform_core.tenant_sites SET is_default=false WHERE tenant_id=p_tenant_id AND is_default;
    UPDATE platform_core.tenant_sites SET is_default=true WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_default',true,'previous_default_id',v_previous_default);
  ELSIF v_action='deactivate' THEN
    IF NOT v_is_active THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    UPDATE platform_core.tenant_sites SET is_active=false,is_default=false WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_active',false,'is_default',false);
  ELSE
    IF v_is_active THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.id=v_current_entity AND e.is_active) THEN
      RAISE EXCEPTION 'tenant_site_entity_unavailable' USING ERRCODE='23503';
    END IF;
    SELECT count(*)::integer,pg_catalog.max(l.limit_mode),pg_catalog.max(l.limit_value)
      INTO v_limit_count,v_limit_mode,v_limit_value
    FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.sites' AND l.limit_key='max_sites'
      AND l.valid_from<=v_now
      AND (l.valid_until IS NULL OR l.valid_until>v_now);
    IF v_limit_count<>1 OR v_limit_mode NOT IN ('limited','unlimited') THEN RAISE EXCEPTION 'tenant_sites_limit_unavailable' USING ERRCODE='55000'; END IF;
    SELECT count(*)::integer INTO v_usage FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active;
    IF v_limit_mode='limited' AND v_usage>=v_limit_value THEN RAISE EXCEPTION 'tenant_sites_capacity_reached' USING ERRCODE='23514'; END IF;
    SELECT NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active AND s.is_default)
      INTO v_make_default;
    UPDATE platform_core.tenant_sites SET is_active=true,is_default=v_make_default WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_active',true,'is_default',v_make_default);
  END IF;

  INSERT INTO platform_core.tenant_entities_sites_audit_events(tenant_id,actor_user_id,resource_type,resource_id,action,before_state,after_state,reason)
  VALUES(p_tenant_id,v_actor,'site',v_site,
    CASE WHEN v_action='update' THEN 'updated' WHEN v_action='default' THEN 'default_changed' WHEN v_action='deactivate' THEN 'deactivated' ELSE 'reactivated' END,
    v_before,v_after,v_reason);
  RETURN pg_catalog.jsonb_build_object('state',CASE WHEN v_action='update' THEN 'updated' ELSE v_action END,'site_id',v_site);
END;
$function$;
REVOKE ALL ON FUNCTION public.manage_tenant_site(uuid,text,uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.manage_tenant_site(uuid,text,uuid,uuid,text,text) TO authenticated;
