-- A first Admin invitation is a recoverable intent, not an active Tenant.
CREATE TABLE platform_core.tenant_admin_onboarding_intents (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  created_by_operator_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  target_email text NOT NULL CHECK (
    target_email = pg_catalog.lower(pg_catalog.btrim(target_email))
    AND target_email <> '' AND pg_catalog.length(target_email) <= 254
  ),
  tenant_name text NOT NULL CHECK (pg_catalog.btrim(tenant_name) <> '' AND pg_catalog.length(tenant_name) <= 160),
  legal_entity_name text NOT NULL CHECK (pg_catalog.btrim(legal_entity_name) <> '' AND pg_catalog.length(legal_entity_name) <= 160),
  site_name text NOT NULL CHECK (pg_catalog.btrim(site_name) <> '' AND pg_catalog.length(site_name) <= 160),
  seat_limit_mode text NOT NULL CHECK (seat_limit_mode IN ('limited', 'unlimited')),
  seat_limit integer,
  site_limit_mode text NOT NULL CHECK (site_limit_mode IN ('limited', 'unlimited')),
  site_limit integer,
  lifecycle_state text NOT NULL DEFAULT 'pending' CHECK (lifecycle_state IN ('pending', 'accepted', 'expired', 'revoked')),
  delivery_state text NOT NULL DEFAULT 'sending' CHECK (delivery_state IN ('sending', 'sent', 'failed')),
  delivery_error_code text CHECK (delivery_error_code IS NULL OR pg_catalog.length(delivery_error_code) <= 80),
  issuance integer NOT NULL DEFAULT 1 CHECK (issuance > 0),
  expires_at timestamptz NOT NULL,
  accepted_user_id uuid REFERENCES auth.users (id) ON DELETE RESTRICT,
  accepted_at timestamptz,
  tenant_id uuid UNIQUE REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  result_snapshot jsonb,
  idempotency_key uuid NOT NULL,
  request_signature jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  UNIQUE (created_by_operator_id, idempotency_key),
  CHECK (
    (seat_limit_mode = 'limited' AND seat_limit IS NOT NULL AND seat_limit > 0)
    OR (seat_limit_mode = 'unlimited' AND seat_limit IS NULL)
  ),
  CHECK (
    (site_limit_mode = 'limited' AND site_limit IS NOT NULL AND site_limit > 0)
    OR (site_limit_mode = 'unlimited' AND site_limit IS NULL)
  ),
  CHECK (
    (lifecycle_state = 'accepted' AND accepted_user_id IS NOT NULL AND accepted_at IS NOT NULL AND tenant_id IS NOT NULL)
    OR (lifecycle_state <> 'accepted' AND accepted_user_id IS NULL AND accepted_at IS NULL AND tenant_id IS NULL)
  )
);
CREATE INDEX tenant_admin_invite_operator_history_idx
  ON platform_core.tenant_admin_onboarding_intents (created_by_operator_id, created_at DESC);
ALTER TABLE platform_core.tenant_admin_onboarding_intents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_admin_onboarding_intents FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_core.tenant_admin_invitation_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invitation_id uuid NOT NULL REFERENCES platform_core.tenant_admin_onboarding_intents (id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users (id) ON DELETE RESTRICT,
  actor_class text NOT NULL CHECK (actor_class IN ('platform_operator', 'invited_user', 'system')),
  action text NOT NULL CHECK (action IN ('created', 'delivery_sent', 'delivery_failed', 'reissued', 'revoked', 'expired', 'credential_ready', 'accepted')),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CHECK ((actor_class = 'system' AND actor_user_id IS NULL) OR (actor_class <> 'system' AND actor_user_id IS NOT NULL))
);
ALTER TABLE platform_core.tenant_admin_invitation_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_admin_invitation_audit FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_private.platform_auth_password_readiness (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  source_invitation_id uuid NOT NULL REFERENCES platform_core.tenant_admin_onboarding_intents (id) ON DELETE RESTRICT,
  source_issuance integer NOT NULL CHECK (source_issuance > 0),
  marked_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp()
);
REVOKE ALL ON TABLE platform_private.platform_auth_password_readiness FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.prevent_tenant_invitation_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $function$
BEGIN
  RAISE EXCEPTION 'Tenant invitation audit is append-only' USING ERRCODE = '55000';
END;
$function$;
CREATE TRIGGER tenant_invitation_audit_append_only
BEFORE UPDATE OR DELETE ON platform_core.tenant_admin_invitation_audit
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_invitation_audit_mutation();
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_invitation_audit_mutation() FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.provision_tenant_with_admin(
  p_operator_user_id uuid,
  p_admin_user_id uuid,
  p_tenant_name text,
  p_legal_entity_name text,
  p_site_name text,
  p_seat_limit_mode text,
  p_seat_limit integer,
  p_site_limit_mode text,
  p_site_limit integer,
  p_idempotency_key uuid DEFAULT NULL,
  p_invitation_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_tenant uuid;
  v_entity uuid;
  v_site uuid;
  v_role uuid;
  v_admin_email text;
  v_authorized_operator uuid;
  v_result jsonb;
BEGIN
  SELECT grant_row.user_id INTO v_authorized_operator
  FROM platform_private.platform_operator_grants AS grant_row
  JOIN auth.users AS operator_user ON operator_user.id = grant_row.user_id
  WHERE grant_row.user_id = p_operator_user_id
    AND grant_row.is_active AND grant_row.can_onboard_tenants
    AND operator_user.deleted_at IS NULL
    AND operator_user.email_confirmed_at IS NOT NULL
    AND (operator_user.banned_until IS NULL OR operator_user.banned_until <= pg_catalog.now())
  FOR SHARE OF grant_row, operator_user;
  IF v_authorized_operator IS NULL THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT auth_user.email INTO v_admin_email
  FROM auth.users AS auth_user
  WHERE auth_user.id = p_admin_user_id
    AND auth_user.deleted_at IS NULL
    AND auth_user.email_confirmed_at IS NOT NULL
    AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  FOR SHARE;
  IF v_admin_email IS NULL THEN
    RAISE EXCEPTION 'onboarding_admin_not_found_or_unverified' USING ERRCODE = '22023';
  END IF;

  IF NOT (
    (p_seat_limit_mode = 'limited' AND p_seat_limit IS NOT NULL AND p_seat_limit > 0)
    OR (p_seat_limit_mode = 'unlimited' AND p_seat_limit IS NULL)
  ) OR NOT (
    (p_site_limit_mode = 'limited' AND p_site_limit IS NOT NULL AND p_site_limit > 0)
    OR (p_site_limit_mode = 'unlimited' AND p_site_limit IS NULL)
  ) THEN
    RAISE EXCEPTION 'onboarding_invalid_limit' USING ERRCODE = '22023';
  END IF;

  INSERT INTO platform_core.tenants (display_name, created_by_operator_id)
  VALUES (pg_catalog.btrim(p_tenant_name), p_operator_user_id)
  RETURNING id INTO v_tenant;
  INSERT INTO platform_core.tenant_capability_limits (
    tenant_id, capability_key, limit_key, limit_mode, limit_value,
    valid_from, valid_until, actor_user_id, provenance
  ) VALUES
    (v_tenant, 'tenant.users', 'max_users', p_seat_limit_mode, p_seat_limit,
      pg_catalog.transaction_timestamp(), NULL, p_operator_user_id, 'platform.tenant.onboard'),
    (v_tenant, 'tenant.sites', 'max_sites', p_site_limit_mode, p_site_limit,
      pg_catalog.transaction_timestamp(), NULL, p_operator_user_id, 'platform.tenant.onboard');
  INSERT INTO platform_core.tenant_legal_entities (tenant_id, display_name, is_default)
  VALUES (v_tenant, COALESCE(NULLIF(pg_catalog.btrim(p_legal_entity_name), ''), pg_catalog.btrim(p_tenant_name)), true)
  RETURNING id INTO v_entity;
  INSERT INTO platform_core.tenant_sites (tenant_id, legal_entity_id, display_name, is_default)
  VALUES (v_tenant, v_entity, pg_catalog.btrim(p_site_name), true)
  RETURNING id INTO v_site;
  INSERT INTO platform_core.tenant_roles (
    tenant_id, role_key, role_version, permission_snapshot, protects_tenant_admin
  ) VALUES (
    v_tenant, 'tenant.owner_admin.v1', 1,
    ARRAY['tenant.administer', 'tenant.members.manage', 'tenant.sites.manage', 'tenant.legal_entities.manage']::text[], true
  ) RETURNING role_id INTO v_role;
  INSERT INTO platform_core.tenant_memberships (tenant_id, user_id, access_state, created_by_operator_id)
  VALUES (v_tenant, p_admin_user_id, 'active', p_operator_user_id);
  INSERT INTO platform_core.membership_roles (tenant_id, user_id, role_id)
  VALUES (v_tenant, p_admin_user_id, v_role);

  v_result := pg_catalog.jsonb_build_object(
    'tenant_id', v_tenant,
    'tenant_name', pg_catalog.btrim(p_tenant_name),
    'legal_entity_id', v_entity,
    'legal_entity_name', COALESCE(NULLIF(pg_catalog.btrim(p_legal_entity_name), ''), pg_catalog.btrim(p_tenant_name)),
    'site_id', v_site,
    'site_name', pg_catalog.btrim(p_site_name),
    'admin_email', pg_catalog.lower(v_admin_email),
    'seat_limit_mode', p_seat_limit_mode,
    'seat_limit', p_seat_limit,
    'seat_usage', 1,
    'site_limit_mode', p_site_limit_mode,
    'site_limit', p_site_limit,
    'site_usage', 1
  );
  INSERT INTO platform_core.audit_events (event_key, tenant_id, actor_user_id, subject_user_id, details)
  VALUES (
    'platform.tenant.onboard', v_tenant, p_operator_user_id, p_admin_user_id,
    pg_catalog.jsonb_build_object(
      'idempotency_key', p_idempotency_key,
      'invitation_id', p_invitation_id,
      'seat_limit_mode', p_seat_limit_mode,
      'seat_limit', p_seat_limit,
      'site_limit_mode', p_site_limit_mode,
      'site_limit', p_site_limit,
      'role_snapshot_key', 'tenant.owner_admin.v1',
      'role_snapshot_version', 1
    )
  );
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION platform_core.provision_tenant_with_admin(uuid, uuid, text, text, text, text, integer, text, integer, uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.onboard_tenant(
  p_idempotency_key uuid,
  p_tenant_name text,
  p_legal_entity_name text,
  p_site_name text,
  p_admin_email text,
  p_seat_limit_mode text,
  p_seat_limit integer,
  p_site_limit_mode text,
  p_site_limit integer
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_admin uuid;
  v_admin_confirmed timestamptz;
  v_signature jsonb;
  v_existing_signature jsonb;
  v_existing_result jsonb;
  v_result jsonb;
  v_rows integer;
  v_tenant_name text := pg_catalog.btrim(p_tenant_name);
  v_entity_name text := COALESCE(NULLIF(pg_catalog.btrim(p_legal_entity_name), ''), pg_catalog.btrim(p_tenant_name));
  v_site_name text := pg_catalog.btrim(p_site_name);
  v_admin_email text := pg_catalog.lower(pg_catalog.btrim(p_admin_email));
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM platform_private.platform_operator_grants AS grant_row
    JOIN auth.users AS operator_user ON operator_user.id = grant_row.user_id
    WHERE grant_row.user_id = v_actor AND grant_row.is_active AND grant_row.can_onboard_tenants
      AND operator_user.deleted_at IS NULL AND operator_user.email_confirmed_at IS NOT NULL
      AND (operator_user.banned_until IS NULL OR operator_user.banned_until <= pg_catalog.now())
  ) THEN RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE = '42501'; END IF;
  IF p_idempotency_key IS NULL OR COALESCE(v_tenant_name, '') = '' OR pg_catalog.length(v_tenant_name) > 160
     OR pg_catalog.length(v_entity_name) > 160 OR COALESCE(v_site_name, '') = '' OR pg_catalog.length(v_site_name) > 160
     OR COALESCE(v_admin_email, '') = '' OR pg_catalog.length(v_admin_email) > 254 THEN
    RAISE EXCEPTION 'onboarding_required_fields_invalid' USING ERRCODE = '22023';
  END IF;
  IF NOT ((p_seat_limit_mode = 'limited' AND p_seat_limit IS NOT NULL AND p_seat_limit > 0) OR (p_seat_limit_mode = 'unlimited' AND p_seat_limit IS NULL))
     OR NOT ((p_site_limit_mode = 'limited' AND p_site_limit IS NOT NULL AND p_site_limit > 0) OR (p_site_limit_mode = 'unlimited' AND p_site_limit IS NULL)) THEN
    RAISE EXCEPTION 'onboarding_invalid_limit' USING ERRCODE = '22023';
  END IF;
  v_signature := pg_catalog.jsonb_build_object('tenant_name',v_tenant_name,'legal_entity_name',v_entity_name,'site_name',v_site_name,
    'admin_email',v_admin_email,'seat_limit_mode',p_seat_limit_mode,'seat_limit',p_seat_limit,'site_limit_mode',p_site_limit_mode,'site_limit',p_site_limit);
  INSERT INTO platform_core.tenant_onboarding_idempotency(actor_user_id,idempotency_key,request_signature)
  VALUES(v_actor,p_idempotency_key,v_signature) ON CONFLICT(actor_user_id,idempotency_key) DO NOTHING;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    SELECT request_signature,result_snapshot INTO v_existing_signature,v_existing_result FROM platform_core.tenant_onboarding_idempotency
    WHERE actor_user_id=v_actor AND idempotency_key=p_idempotency_key FOR UPDATE;
    IF v_existing_signature IS DISTINCT FROM v_signature THEN RAISE EXCEPTION 'onboarding_idempotency_conflict' USING ERRCODE='P0001'; END IF;
    IF v_existing_result IS NULL THEN RAISE EXCEPTION 'onboarding_idempotency_incomplete' USING ERRCODE='55000'; END IF;
    RETURN v_existing_result;
  END IF;
  SELECT auth_user.id, auth_user.email_confirmed_at INTO v_admin, v_admin_confirmed
  FROM auth.users AS auth_user WHERE pg_catalog.lower(auth_user.email)=v_admin_email
    AND auth_user.deleted_at IS NULL AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now()) LIMIT 1;
  IF v_admin IS NULL THEN RAISE EXCEPTION 'onboarding_admin_not_found_or_disabled' USING ERRCODE='22023'; END IF;
  IF v_admin_confirmed IS NULL THEN RAISE EXCEPTION 'onboarding_admin_email_unverified' USING ERRCODE='22023'; END IF;
  v_result := platform_core.provision_tenant_with_admin(v_actor,v_admin,v_tenant_name,v_entity_name,v_site_name,
    p_seat_limit_mode,p_seat_limit,p_site_limit_mode,p_site_limit,p_idempotency_key,NULL);
  UPDATE platform_core.tenant_onboarding_idempotency SET tenant_id=(v_result->>'tenant_id')::uuid,result_snapshot=v_result
  WHERE actor_user_id=v_actor AND idempotency_key=p_idempotency_key;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.onboard_tenant(uuid,text,text,text,text,text,integer,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.onboard_tenant(uuid,text,text,text,text,text,integer,text,integer) TO authenticated;

CREATE FUNCTION public.create_tenant_admin_invitation(
  p_idempotency_key uuid, p_tenant_name text, p_legal_entity_name text, p_site_name text,
  p_target_email text, p_seat_limit_mode text, p_seat_limit integer, p_site_limit_mode text, p_site_limit integer
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid()); v_email text := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  v_signature jsonb; v_id uuid; v_existing platform_core.tenant_admin_onboarding_intents%ROWTYPE; v_rows integer;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_actor AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_idempotency_key IS NULL OR v_email='' OR pg_catalog.length(v_email)>254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    OR COALESCE(pg_catalog.btrim(p_tenant_name),'')='' OR pg_catalog.length(pg_catalog.btrim(p_tenant_name))>160
    OR pg_catalog.length(COALESCE(NULLIF(pg_catalog.btrim(p_legal_entity_name),''),pg_catalog.btrim(p_tenant_name)))>160
    OR COALESCE(pg_catalog.btrim(p_site_name),'')='' OR pg_catalog.length(pg_catalog.btrim(p_site_name))>160
    OR NOT ((p_seat_limit_mode='limited' AND p_seat_limit IS NOT NULL AND p_seat_limit>0) OR (p_seat_limit_mode='unlimited' AND p_seat_limit IS NULL))
    OR NOT ((p_site_limit_mode='limited' AND p_site_limit IS NOT NULL AND p_site_limit>0) OR (p_site_limit_mode='unlimited' AND p_site_limit IS NULL)) THEN
    RAISE EXCEPTION 'tenant_admin_invite_invalid_request' USING ERRCODE='22023';
  END IF;
  v_signature := pg_catalog.jsonb_build_object('tenant_name',pg_catalog.btrim(p_tenant_name),
    'legal_entity_name',COALESCE(NULLIF(pg_catalog.btrim(p_legal_entity_name),''),pg_catalog.btrim(p_tenant_name)),
    'site_name',pg_catalog.btrim(p_site_name),'target_email',v_email,'seat_limit_mode',p_seat_limit_mode,
    'seat_limit',p_seat_limit,'site_limit_mode',p_site_limit_mode,'site_limit',p_site_limit);
  INSERT INTO platform_core.tenant_admin_onboarding_intents(created_by_operator_id,target_email,tenant_name,legal_entity_name,site_name,
    seat_limit_mode,seat_limit,site_limit_mode,site_limit,expires_at,idempotency_key,request_signature)
  VALUES(v_actor,v_email,pg_catalog.btrim(p_tenant_name),v_signature->>'legal_entity_name',pg_catalog.btrim(p_site_name),
    p_seat_limit_mode,p_seat_limit,p_site_limit_mode,p_site_limit,pg_catalog.now()+interval '7 days',p_idempotency_key,v_signature)
  ON CONFLICT(created_by_operator_id,idempotency_key) DO NOTHING RETURNING id INTO v_id;
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  IF v_rows=0 THEN
    SELECT * INTO STRICT v_existing FROM platform_core.tenant_admin_onboarding_intents
    WHERE created_by_operator_id=v_actor AND idempotency_key=p_idempotency_key FOR UPDATE;
    IF v_existing.request_signature IS DISTINCT FROM v_signature THEN RAISE EXCEPTION 'tenant_admin_invite_idempotency_conflict' USING ERRCODE='P0001'; END IF;
    IF v_existing.lifecycle_state='pending' AND v_existing.expires_at<=pg_catalog.now() THEN
      UPDATE platform_core.tenant_admin_onboarding_intents SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp() WHERE id=v_existing.id;
      INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_class,action,details)
        VALUES(v_existing.id,'system','expired',pg_catalog.jsonb_build_object('issuance',v_existing.issuance));
      v_existing.lifecycle_state := 'expired';
    END IF;
    RETURN pg_catalog.jsonb_build_object('id',v_existing.id,'issuance',v_existing.issuance,'target_email',v_existing.target_email,
      'delivery_state',v_existing.delivery_state,'lifecycle_state',v_existing.lifecycle_state,'created',false);
  END IF;
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_user_id,actor_class,action,details)
  VALUES(v_id,v_actor,'platform_operator','created',pg_catalog.jsonb_build_object('issuance',1));
  RETURN pg_catalog.jsonb_build_object('id',v_id,'issuance',1,'target_email',v_email,'delivery_state','sending','lifecycle_state','pending','created',true);
END;
$function$;
REVOKE ALL ON FUNCTION public.create_tenant_admin_invitation(uuid,text,text,text,text,text,integer,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.create_tenant_admin_invitation(uuid,text,text,text,text,text,integer,text,integer) TO authenticated;

CREATE FUNCTION public.record_tenant_admin_invitation_delivery(p_invitation_id uuid,p_issuance integer,p_succeeded boolean,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent platform_core.tenant_admin_onboarding_intents%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_actor AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_intent FROM platform_core.tenant_admin_onboarding_intents WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR v_intent.created_by_operator_id<>v_actor OR v_intent.lifecycle_state<>'pending' OR v_intent.issuance<>p_issuance THEN
    RAISE EXCEPTION 'tenant_admin_invite_stale_issuance' USING ERRCODE='P0001';
  END IF;
  UPDATE platform_core.tenant_admin_onboarding_intents SET delivery_state=CASE WHEN p_succeeded THEN 'sent' ELSE 'failed' END,
    delivery_error_code=CASE WHEN p_succeeded THEN NULL ELSE COALESCE(NULLIF(p_error_code,''),'delivery_failed') END,
    updated_at=pg_catalog.clock_timestamp() WHERE id=p_invitation_id;
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_user_id,actor_class,action,details)
  VALUES(p_invitation_id,v_actor,'platform_operator',CASE WHEN p_succeeded THEN 'delivery_sent' ELSE 'delivery_failed' END,
    pg_catalog.jsonb_build_object('issuance',p_issuance,'error_code',CASE WHEN p_succeeded THEN NULL ELSE COALESCE(NULLIF(p_error_code,''),'delivery_failed') END));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_tenant_admin_invitation_delivery(uuid,integer,boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.record_tenant_admin_invitation_delivery(uuid,integer,boolean,text) TO authenticated;

CREATE FUNCTION public.reissue_tenant_admin_invitation(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent platform_core.tenant_admin_onboarding_intents%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_actor AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_intent FROM platform_core.tenant_admin_onboarding_intents WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR v_intent.created_by_operator_id<>v_actor OR v_intent.lifecycle_state<>'pending' THEN
    RAISE EXCEPTION 'tenant_admin_invite_reissue_forbidden' USING ERRCODE='42501';
  END IF;
  IF v_intent.expires_at<=pg_catalog.now() THEN
    UPDATE platform_core.tenant_admin_onboarding_intents SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp() WHERE id=p_invitation_id;
    INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_class,action,details)
      VALUES(p_invitation_id,'system','expired',pg_catalog.jsonb_build_object('issuance',v_intent.issuance));
    RETURN pg_catalog.jsonb_build_object('state','expired');
  END IF;
  UPDATE platform_core.tenant_admin_onboarding_intents SET issuance=issuance+1,expires_at=pg_catalog.now()+interval '7 days',
    delivery_state='sending',delivery_error_code=NULL,updated_at=pg_catalog.clock_timestamp()
  WHERE id=p_invitation_id RETURNING * INTO v_intent;
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_user_id,actor_class,action,details)
  VALUES(p_invitation_id,v_actor,'platform_operator','reissued',pg_catalog.jsonb_build_object('issuance',v_intent.issuance));
  RETURN pg_catalog.jsonb_build_object('id',v_intent.id,'issuance',v_intent.issuance,'target_email',v_intent.target_email,
    'delivery_state',v_intent.delivery_state,'lifecycle_state',v_intent.lifecycle_state);
END;
$function$;
REVOKE ALL ON FUNCTION public.reissue_tenant_admin_invitation(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.reissue_tenant_admin_invitation(uuid) TO authenticated;

CREATE FUNCTION public.revoke_tenant_admin_invitation(p_invitation_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent platform_core.tenant_admin_onboarding_intents%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_actor AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_intent FROM platform_core.tenant_admin_onboarding_intents WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR v_intent.lifecycle_state<>'pending' THEN RETURN false; END IF;
  UPDATE platform_core.tenant_admin_onboarding_intents SET lifecycle_state='revoked',updated_at=pg_catalog.clock_timestamp() WHERE id=p_invitation_id;
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_user_id,actor_class,action,details)
    VALUES(p_invitation_id,v_actor,'platform_operator','revoked',pg_catalog.jsonb_build_object('issuance',v_intent.issuance));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.revoke_tenant_admin_invitation(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.revoke_tenant_admin_invitation(uuid) TO authenticated;

CREATE FUNCTION public.tenant_admin_invitation_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_actor AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE='42501';
  END IF;
  WITH expired AS (
    UPDATE platform_core.tenant_admin_onboarding_intents
    SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE lifecycle_state='pending' AND expires_at<=pg_catalog.now()
    RETURNING id,issuance
  )
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_class,action,details)
  SELECT id,'system','expired',pg_catalog.jsonb_build_object('issuance',issuance) FROM expired;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',i.id,'target_email',i.target_email,'tenant_name',i.tenant_name,
    'lifecycle_state',i.lifecycle_state,
    'delivery_state',i.delivery_state,'issuance',i.issuance,'expires_at',i.expires_at,'created_by_operator_id',i.created_by_operator_id,
    'tenant_id',i.tenant_id,'result_snapshot',i.result_snapshot) ORDER BY i.created_at DESC),'[]'::jsonb)
  INTO v_result FROM platform_core.tenant_admin_onboarding_intents i;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_admin_invitation_list() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_admin_invitation_list() TO authenticated;

CREATE FUNCTION public.validate_tenant_admin_invitation(p_invitation_id uuid,p_issuance integer)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_email text; v_password_ready boolean;
BEGIN
  SELECT i.target_email INTO v_email FROM platform_core.tenant_admin_onboarding_intents i
  JOIN platform_private.platform_operator_grants g ON g.user_id=i.created_by_operator_id
  JOIN auth.users issuer ON issuer.id=g.user_id
  WHERE i.id=p_invitation_id AND i.issuance=p_issuance AND i.lifecycle_state='pending' AND i.expires_at>pg_catalog.now()
    AND g.is_active AND g.can_onboard_tenants AND issuer.deleted_at IS NULL AND issuer.email_confirmed_at IS NOT NULL
    AND (issuer.banned_until IS NULL OR issuer.banned_until<=pg_catalog.now());
  IF v_email IS NULL THEN RETURN 'unavailable'; END IF;
  SELECT (u.encrypted_password IS NOT NULL AND u.encrypted_password <> '')
    AND (u.invited_at IS NULL OR EXISTS (SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
    INTO v_password_ready
  FROM auth.users u WHERE u.id=v_actor AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND pg_catalog.lower(u.email)=v_email;
  IF NOT FOUND THEN RETURN 'identity_mismatch'; END IF;
  RETURN CASE WHEN v_password_ready THEN 'ready' ELSE 'password_required' END;
END;
$function$;
REVOKE ALL ON FUNCTION public.validate_tenant_admin_invitation(uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.validate_tenant_admin_invitation(uuid,integer) TO authenticated;

CREATE FUNCTION public.accept_tenant_admin_invitation(p_invitation_id uuid,p_issuance integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent platform_core.tenant_admin_onboarding_intents%ROWTYPE;
  v_result jsonb; v_operator_ok boolean;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'tenant_admin_invite_identity_required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=v_actor AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'tenant_admin_invite_identity_unverified' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_intent FROM platform_core.tenant_admin_onboarding_intents WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_admin_invite_unavailable' USING ERRCODE='P0001'; END IF;
  IF v_intent.issuance<>p_issuance THEN RAISE EXCEPTION 'tenant_admin_invite_stale_issuance' USING ERRCODE='P0001'; END IF;
  IF v_intent.lifecycle_state='accepted' AND v_intent.accepted_user_id=v_actor THEN RETURN v_intent.result_snapshot; END IF;
  IF v_intent.lifecycle_state<>'pending' THEN RAISE EXCEPTION 'tenant_admin_invite_unavailable' USING ERRCODE='P0001'; END IF;
  IF v_intent.expires_at<=pg_catalog.now() THEN
    UPDATE platform_core.tenant_admin_onboarding_intents SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp() WHERE id=p_invitation_id;
    INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_class,action,details)
      VALUES(p_invitation_id,'system','expired',pg_catalog.jsonb_build_object('issuance',v_intent.issuance));
    RETURN pg_catalog.jsonb_build_object('state','expired');
  END IF;
  SELECT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_intent.created_by_operator_id AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) INTO v_operator_ok;
  IF NOT v_operator_ok THEN RAISE EXCEPTION 'tenant_admin_invite_issuer_authority_lost' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=v_actor AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND pg_catalog.lower(u.email)=v_intent.target_email) THEN
    RAISE EXCEPTION 'tenant_admin_invite_identity_mismatch' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=v_actor AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
    AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))) THEN
    RAISE EXCEPTION 'tenant_admin_invite_password_required' USING ERRCODE='42501';
  END IF;
  v_result := platform_core.provision_tenant_with_admin(v_intent.created_by_operator_id,v_actor,v_intent.tenant_name,v_intent.legal_entity_name,
    v_intent.site_name,v_intent.seat_limit_mode,v_intent.seat_limit,v_intent.site_limit_mode,v_intent.site_limit,NULL,p_invitation_id);
  UPDATE platform_core.tenant_admin_onboarding_intents SET lifecycle_state='accepted',accepted_user_id=v_actor,
    accepted_at=pg_catalog.clock_timestamp(),tenant_id=(v_result->>'tenant_id')::uuid,result_snapshot=v_result,updated_at=pg_catalog.clock_timestamp()
  WHERE id=p_invitation_id;
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_user_id,actor_class,action,details)
    VALUES(p_invitation_id,v_actor,'invited_user','accepted',pg_catalog.jsonb_build_object('issuance',p_issuance,'tenant_id',v_result->>'tenant_id'));
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.accept_tenant_admin_invitation(uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.accept_tenant_admin_invitation(uuid,integer) TO authenticated;

CREATE FUNCTION public.record_tenant_admin_password_readiness(p_invitation_id uuid,p_issuance integer,p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_intent platform_core.tenant_admin_onboarding_intents%ROWTYPE; v_email text;
BEGIN
  SELECT * INTO v_intent FROM platform_core.tenant_admin_onboarding_intents i
  WHERE i.id=p_invitation_id AND i.issuance=p_issuance AND i.lifecycle_state='pending' AND i.expires_at>pg_catalog.now()
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_admin_invite_unavailable' USING ERRCODE='P0001'; END IF;
  SELECT u.email INTO v_email FROM auth.users u
  WHERE u.id=p_user_id AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
    AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>'' AND u.invited_at IS NOT NULL;
  IF v_email IS NULL OR pg_catalog.lower(v_email)<>v_intent.target_email THEN
    RAISE EXCEPTION 'tenant_admin_invite_identity_mismatch' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_intent.created_by_operator_id AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'tenant_admin_invite_issuer_authority_lost' USING ERRCODE='42501';
  END IF;
  INSERT INTO platform_private.platform_auth_password_readiness(user_id,source_invitation_id,source_issuance)
  VALUES(p_user_id,p_invitation_id,p_issuance)
  ON CONFLICT(user_id) DO NOTHING;
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_user_id,actor_class,action,details)
  VALUES(p_invitation_id,p_user_id,'invited_user','credential_ready',pg_catalog.jsonb_build_object('issuance',p_issuance));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_tenant_admin_password_readiness(uuid,integer,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_tenant_admin_password_readiness(uuid,integer,uuid) TO service_role;
