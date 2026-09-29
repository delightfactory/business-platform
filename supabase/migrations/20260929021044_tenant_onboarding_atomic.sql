ALTER TABLE platform_private.platform_operator_grants
  ADD COLUMN can_onboard_tenants boolean NOT NULL DEFAULT false;

WITH selected_manager AS (
  SELECT candidate.user_id
  FROM platform_private.platform_operator_grants AS candidate
  JOIN auth.users AS auth_user ON auth_user.id = candidate.user_id
  WHERE candidate.is_active
    AND candidate.can_manage_operators
    AND auth_user.deleted_at IS NULL
    AND auth_user.email_confirmed_at IS NOT NULL
    AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  ORDER BY candidate.created_at, candidate.user_id
  LIMIT 1
), granted AS (
  UPDATE platform_private.platform_operator_grants AS grant_row
  SET can_onboard_tenants = true
  FROM selected_manager
  WHERE grant_row.user_id = selected_manager.user_id
    AND NOT grant_row.can_onboard_tenants
  RETURNING grant_row.user_id
)
INSERT INTO platform_private.platform_operator_audit_events (
  action, actor_class, target_user_id, reason
)
SELECT
  'grant', 'platform_bootstrap', granted.user_id,
  'Migration 20260929021044 grants can_onboard_tenants to the existing recoverable Platform Operator manager.'
FROM granted;

CREATE SCHEMA platform_core;
REVOKE ALL ON SCHEMA platform_core FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_core.tenants (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  display_name text NOT NULL CHECK (pg_catalog.btrim(display_name) <> '' AND pg_catalog.length(display_name) <= 160),
  lifecycle_state text NOT NULL DEFAULT 'active' CHECK (lifecycle_state IN ('active', 'suspended', 'archived')),
  created_by_operator_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp()
);

CREATE TABLE platform_core.tenant_capability_limits (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  capability_key text NOT NULL CHECK (capability_key IN ('tenant.users', 'tenant.sites')),
  limit_key text NOT NULL CHECK (limit_key IN ('max_users', 'max_sites')),
  limit_mode text NOT NULL CHECK (limit_mode IN ('limited', 'unlimited')),
  limit_value integer,
  valid_from timestamptz NOT NULL,
  valid_until timestamptz,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  provenance text NOT NULL CHECK (provenance <> ''),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id, capability_key, limit_key, valid_from),
  CHECK ((capability_key = 'tenant.users' AND limit_key = 'max_users')
      OR (capability_key = 'tenant.sites' AND limit_key = 'max_sites')),
  CHECK ((limit_mode = 'limited' AND limit_value IS NOT NULL AND limit_value > 0)
      OR (limit_mode = 'unlimited' AND limit_value IS NULL)),
  CHECK (valid_until IS NULL OR valid_until > valid_from)
);
CREATE UNIQUE INDEX tenant_capability_limit_one_current_idx
  ON platform_core.tenant_capability_limits (tenant_id, capability_key, limit_key)
  WHERE valid_until IS NULL;

CREATE FUNCTION platform_core.prevent_tenant_capability_limit_overlap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(NEW.tenant_id::text || ':' || NEW.capability_key || ':' || NEW.limit_key, 35191)
  );
  IF EXISTS (
    SELECT 1
    FROM platform_core.tenant_capability_limits AS existing
    WHERE existing.tenant_id = NEW.tenant_id
      AND existing.capability_key = NEW.capability_key
      AND existing.limit_key = NEW.limit_key
      AND (TG_OP = 'INSERT' OR existing.valid_from <> OLD.valid_from)
      AND (existing.valid_until IS NULL OR existing.valid_until > NEW.valid_from)
      AND (NEW.valid_until IS NULL OR NEW.valid_until > existing.valid_from)
  ) THEN
    RAISE EXCEPTION 'Tenant capability limit validity intervals cannot overlap'
      USING ERRCODE = '23P01';
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER tenant_capability_limit_no_overlap
BEFORE INSERT OR UPDATE ON platform_core.tenant_capability_limits
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_capability_limit_overlap();
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_capability_limit_overlap() FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_core.tenant_legal_entities (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  display_name text NOT NULL CHECK (pg_catalog.btrim(display_name) <> '' AND pg_catalog.length(display_name) <= 160),
  is_default boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id, id)
);
CREATE UNIQUE INDEX tenant_legal_entity_one_default_idx
  ON platform_core.tenant_legal_entities (tenant_id) WHERE is_default;

CREATE TABLE platform_core.tenant_sites (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  legal_entity_id uuid NOT NULL,
  display_name text NOT NULL CHECK (pg_catalog.btrim(display_name) <> '' AND pg_catalog.length(display_name) <= 160),
  is_default boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id, id),
  CONSTRAINT tenant_site_entity_same_tenant_fk
    FOREIGN KEY (tenant_id, legal_entity_id)
    REFERENCES platform_core.tenant_legal_entities (tenant_id, id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX tenant_site_one_default_idx
  ON platform_core.tenant_sites (tenant_id) WHERE is_default;

CREATE TABLE platform_core.tenant_roles (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  role_id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  role_key text NOT NULL,
  role_version integer NOT NULL CHECK (role_version > 0),
  permission_snapshot text[] NOT NULL,
  protects_tenant_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id, role_id),
  UNIQUE (tenant_id, role_key, role_version),
  CONSTRAINT tenant_role_snapshot_shape CHECK (
    (NOT protects_tenant_admin OR permission_snapshot @> ARRAY['tenant.administer']::text[])
    AND (role_key <> 'tenant.owner_admin.v1'
      OR (role_version = 1 AND protects_tenant_admin
        AND permission_snapshot @> ARRAY['tenant.administer', 'tenant.members.manage', 'tenant.sites.manage', 'tenant.legal_entities.manage']::text[]))
  )
);

CREATE TABLE platform_core.tenant_memberships (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  access_state text NOT NULL DEFAULT 'active' CHECK (access_state IN ('active', 'inactive')),
  created_by_operator_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id, user_id)
);

CREATE TABLE platform_core.membership_roles (
  tenant_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id, user_id, role_id),
  FOREIGN KEY (tenant_id, user_id)
    REFERENCES platform_core.tenant_memberships (tenant_id, user_id) ON DELETE CASCADE,
  FOREIGN KEY (tenant_id, role_id)
    REFERENCES platform_core.tenant_roles (tenant_id, role_id) ON DELETE RESTRICT
);

CREATE TABLE platform_core.tenant_onboarding_idempotency (
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  idempotency_key uuid NOT NULL,
  request_signature jsonb NOT NULL,
  tenant_id uuid REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  result_snapshot jsonb,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (actor_user_id, idempotency_key),
  CONSTRAINT tenant_onboarding_idempotency_result_shape CHECK (
    (tenant_id IS NULL AND result_snapshot IS NULL)
    OR (tenant_id IS NOT NULL AND result_snapshot IS NOT NULL)
  )
);

CREATE TABLE platform_core.audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_key text NOT NULL CHECK (event_key = 'platform.tenant.onboard'),
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants (id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  subject_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  details jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  UNIQUE (event_key, tenant_id)
);

ALTER TABLE platform_core.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.tenant_capability_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.tenant_legal_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.tenant_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.tenant_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.membership_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.tenant_onboarding_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA platform_core FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA platform_core FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.prevent_tenant_role_snapshot_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $function$
BEGIN
  RAISE EXCEPTION 'Tenant role snapshots are immutable; add a new role version instead'
    USING ERRCODE = '55000';
END;
$function$;
CREATE TRIGGER tenant_role_snapshot_immutable
BEFORE UPDATE OR DELETE ON platform_core.tenant_roles
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_role_snapshot_mutation();
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_role_snapshot_mutation() FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.prevent_last_tenant_admin_removal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_replacement_exists boolean;
BEGIN
  IF TG_OP = 'UPDATE'
     AND (NEW.tenant_id IS DISTINCT FROM OLD.tenant_id OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
    RAISE EXCEPTION 'Tenant membership identity cannot be reassigned'
      USING ERRCODE = '23514';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(OLD.tenant_id::text, 90427)
  );

  IF TG_TABLE_NAME = 'tenant_memberships' THEN
    IF OLD.access_state = 'active'
       AND EXISTS (
         SELECT 1 FROM platform_core.membership_roles AS assignment
         JOIN platform_core.tenant_roles AS role_snapshot USING (tenant_id, role_id)
         WHERE assignment.tenant_id = OLD.tenant_id AND assignment.user_id = OLD.user_id
           AND role_snapshot.protects_tenant_admin
       )
       AND (TG_OP = 'DELETE' OR NEW.access_state <> 'active') THEN
      SELECT EXISTS (
        SELECT 1
        FROM platform_core.tenant_memberships AS membership
        JOIN auth.users AS auth_user ON auth_user.id = membership.user_id
        JOIN platform_core.membership_roles AS assignment
          ON assignment.tenant_id = membership.tenant_id AND assignment.user_id = membership.user_id
        JOIN platform_core.tenant_roles AS role_snapshot
          ON role_snapshot.tenant_id = assignment.tenant_id AND role_snapshot.role_id = assignment.role_id
        WHERE membership.tenant_id = OLD.tenant_id
          AND membership.user_id <> OLD.user_id
          AND membership.access_state = 'active'
          AND role_snapshot.protects_tenant_admin
          AND auth_user.deleted_at IS NULL
          AND auth_user.email_confirmed_at IS NOT NULL
          AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
      ) INTO v_replacement_exists;

      IF NOT v_replacement_exists THEN
        RAISE EXCEPTION 'The final active Tenant administrator cannot be removed'
          USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'membership_roles'
     AND EXISTS (
       SELECT 1 FROM platform_core.tenant_roles AS role_snapshot
       WHERE role_snapshot.tenant_id = OLD.tenant_id
         AND role_snapshot.role_id = OLD.role_id
         AND role_snapshot.protects_tenant_admin
     )
     AND (TG_OP = 'DELETE'
       OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.role_id IS DISTINCT FROM OLD.role_id) THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(OLD.tenant_id::text, 90427)
    );
    IF NOT EXISTS (
      SELECT 1
      FROM platform_core.tenant_memberships AS membership
      JOIN auth.users AS auth_user ON auth_user.id = membership.user_id
      JOIN platform_core.membership_roles AS assignment
        ON assignment.tenant_id = membership.tenant_id AND assignment.user_id = membership.user_id
      JOIN platform_core.tenant_roles AS role_snapshot
        ON role_snapshot.tenant_id = assignment.tenant_id AND role_snapshot.role_id = assignment.role_id
      WHERE membership.tenant_id = OLD.tenant_id
        AND (membership.user_id <> OLD.user_id OR assignment.role_id <> OLD.role_id)
        AND membership.access_state = 'active'
        AND role_snapshot.protects_tenant_admin
        AND auth_user.deleted_at IS NULL
        AND auth_user.email_confirmed_at IS NOT NULL
        AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
    ) THEN
      RAISE EXCEPTION 'The final active Tenant administrator cannot be removed'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER tenant_membership_last_admin_guard
BEFORE UPDATE OR DELETE ON platform_core.tenant_memberships
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_last_tenant_admin_removal();
CREATE TRIGGER membership_role_last_admin_guard
BEFORE UPDATE OR DELETE ON platform_core.membership_roles
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_last_tenant_admin_removal();
REVOKE ALL ON FUNCTION platform_core.prevent_last_tenant_admin_removal() FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.prevent_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION 'Platform Core audit events are append-only'
    USING ERRCODE = '55000';
END;
$function$;

CREATE TRIGGER platform_core_audit_append_only
BEFORE UPDATE OR DELETE ON platform_core.audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_audit_mutation();
REVOKE ALL ON FUNCTION platform_core.prevent_audit_mutation() FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION platform_private.bootstrap_operator_manager(p_target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'An existing Auth user is required'
      USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412, 115991);
  IF NOT EXISTS (
    SELECT 1 FROM auth.users AS auth_user
    WHERE auth_user.id = p_target_user_id
      AND auth_user.deleted_at IS NULL
      AND auth_user.email_confirmed_at IS NOT NULL
      AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  ) THEN
    RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email'
      USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM platform_private.platform_operator_grants AS grant_row
    WHERE grant_row.is_active AND grant_row.can_manage_operators
  ) THEN
    RAISE EXCEPTION 'A Platform Operator manager already exists; bootstrap is one-time'
      USING ERRCODE = '55000';
  END IF;
  INSERT INTO platform_private.platform_operator_grants (
    user_id, is_active, can_manage_operators, can_onboard_tenants
  ) VALUES (p_target_user_id, true, true, true)
  ON CONFLICT (user_id) DO UPDATE
    SET is_active = true,
        can_manage_operators = true,
        can_onboard_tenants = true,
        updated_at = pg_catalog.clock_timestamp();
  INSERT INTO platform_private.platform_operator_audit_events (
    action, actor_class, target_user_id
  ) VALUES ('bootstrap', 'platform_bootstrap', p_target_user_id);
END;
$function$;

CREATE OR REPLACE FUNCTION platform_private.recover_operator_manager(
  p_target_user_id uuid,
  p_reason text,
  p_emergency boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'An existing Auth user is required'
      USING ERRCODE = '22023';
  END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason), ''), '') = '' THEN
    RAISE EXCEPTION 'A non-empty recovery reason is required'
      USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(772412, 115991);
  IF NOT EXISTS (
    SELECT 1 FROM auth.users AS auth_user
    WHERE auth_user.id = p_target_user_id
      AND auth_user.deleted_at IS NULL
      AND auth_user.email_confirmed_at IS NOT NULL
      AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  ) THEN
    RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email'
      USING ERRCODE = '22023';
  END IF;
  IF NOT p_emergency AND EXISTS (
    SELECT 1 FROM platform_private.platform_operator_grants AS grant_row
    WHERE grant_row.is_active AND grant_row.can_manage_operators
  ) THEN
    RAISE EXCEPTION 'A manager is active; declare and explain an emergency to recover another'
      USING ERRCODE = '55000';
  END IF;
  INSERT INTO platform_private.platform_operator_grants (
    user_id, is_active, can_manage_operators, can_onboard_tenants
  ) VALUES (p_target_user_id, true, true, true)
  ON CONFLICT (user_id) DO UPDATE
    SET is_active = true,
        can_manage_operators = true,
        can_onboard_tenants = true,
        updated_at = pg_catalog.clock_timestamp();
  INSERT INTO platform_private.platform_operator_audit_events (
    action, actor_class, target_user_id, reason, is_emergency
  ) VALUES ('recovery', 'platform_bootstrap', p_target_user_id, p_reason, p_emergency);
END;
$function$;

REVOKE ALL ON FUNCTION platform_private.bootstrap_operator_manager(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION platform_private.recover_operator_manager(uuid, text, boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION platform_private.bootstrap_operator_manager(uuid) TO postgres;
GRANT EXECUTE ON FUNCTION platform_private.recover_operator_manager(uuid, text, boolean) TO postgres;

CREATE FUNCTION public.current_operator_can_onboard_tenants()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM platform_private.platform_operator_grants AS grant_row
    JOIN auth.users AS auth_user ON auth_user.id = grant_row.user_id
    WHERE grant_row.user_id = (SELECT auth.uid())
      AND grant_row.is_active
      AND grant_row.can_onboard_tenants
      AND auth_user.deleted_at IS NULL
      AND auth_user.email_confirmed_at IS NOT NULL
      AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  );
$function$;
REVOKE ALL ON FUNCTION public.current_operator_can_onboard_tenants() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.current_operator_can_onboard_tenants() TO authenticated;

CREATE FUNCTION public.onboard_tenant(
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
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_admin uuid;
  v_admin_confirmed timestamptz;
  v_signature jsonb;
  v_existing_signature jsonb;
  v_existing_result jsonb;
  v_tenant uuid;
  v_legal_entity uuid;
  v_site uuid;
  v_role_id uuid;
  v_result jsonb;
  v_rows integer;
  v_tenant_name text := pg_catalog.btrim(p_tenant_name);
  v_entity_name text := COALESCE(NULLIF(pg_catalog.btrim(p_legal_entity_name), ''), v_tenant_name);
  v_site_name text := pg_catalog.btrim(p_site_name);
  v_admin_email text := pg_catalog.lower(pg_catalog.btrim(p_admin_email));
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM platform_private.platform_operator_grants AS grant_row
    JOIN auth.users AS operator_user ON operator_user.id = grant_row.user_id
    WHERE grant_row.user_id = v_actor
      AND grant_row.is_active
      AND grant_row.can_onboard_tenants
      AND operator_user.deleted_at IS NULL
      AND operator_user.email_confirmed_at IS NOT NULL
      AND (operator_user.banned_until IS NULL OR operator_user.banned_until <= pg_catalog.now())
  ) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'onboarding_idempotency_key_required' USING ERRCODE = '22023';
  END IF;
  IF COALESCE(v_tenant_name, '') = '' OR pg_catalog.length(v_tenant_name) > 160
     OR pg_catalog.length(v_entity_name) > 160
     OR COALESCE(v_site_name, '') = '' OR pg_catalog.length(v_site_name) > 160
     OR COALESCE(v_admin_email, '') = '' OR pg_catalog.length(v_admin_email) > 254 THEN
    RAISE EXCEPTION 'onboarding_required_fields_invalid' USING ERRCODE = '22023';
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

  v_signature := pg_catalog.jsonb_build_object(
    'tenant_name', v_tenant_name,
    'legal_entity_name', v_entity_name,
    'site_name', v_site_name,
    'admin_email', v_admin_email,
    'seat_limit_mode', p_seat_limit_mode,
    'seat_limit', p_seat_limit,
    'site_limit_mode', p_site_limit_mode,
    'site_limit', p_site_limit
  );
  INSERT INTO platform_core.tenant_onboarding_idempotency (
    actor_user_id, idempotency_key, request_signature
  ) VALUES (v_actor, p_idempotency_key, v_signature)
  ON CONFLICT (actor_user_id, idempotency_key) DO NOTHING;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    SELECT request_signature, result_snapshot
    INTO v_existing_signature, v_existing_result
    FROM platform_core.tenant_onboarding_idempotency
    WHERE actor_user_id = v_actor AND idempotency_key = p_idempotency_key;
    IF v_existing_signature IS DISTINCT FROM v_signature THEN
      RAISE EXCEPTION 'onboarding_idempotency_conflict' USING ERRCODE = 'P0001';
    END IF;
    IF v_existing_result IS NULL THEN
      RAISE EXCEPTION 'onboarding_idempotency_incomplete' USING ERRCODE = '55000';
    END IF;
    RETURN v_existing_result;
  END IF;

  SELECT auth_user.id, auth_user.email_confirmed_at
  INTO v_admin, v_admin_confirmed
  FROM auth.users AS auth_user
  WHERE pg_catalog.lower(auth_user.email) = v_admin_email
    AND auth_user.deleted_at IS NULL
    AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  LIMIT 1;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'onboarding_admin_not_found_or_disabled' USING ERRCODE = '22023';
  END IF;
  IF v_admin_confirmed IS NULL THEN
    RAISE EXCEPTION 'onboarding_admin_email_unverified' USING ERRCODE = '22023';
  END IF;

  INSERT INTO platform_core.tenants (
    display_name, created_by_operator_id
  ) VALUES (
    v_tenant_name, v_actor
  ) RETURNING id INTO v_tenant;
  INSERT INTO platform_core.tenant_capability_limits (
    tenant_id, capability_key, limit_key, limit_mode, limit_value,
    valid_from, valid_until, actor_user_id, provenance
  ) VALUES
    (v_tenant, 'tenant.users', 'max_users', p_seat_limit_mode, p_seat_limit,
      pg_catalog.transaction_timestamp(), NULL, v_actor, 'platform.tenant.onboard'),
    (v_tenant, 'tenant.sites', 'max_sites', p_site_limit_mode, p_site_limit,
      pg_catalog.transaction_timestamp(), NULL, v_actor, 'platform.tenant.onboard');
  INSERT INTO platform_core.tenant_legal_entities (tenant_id, display_name, is_default)
  VALUES (v_tenant, v_entity_name, true) RETURNING id INTO v_legal_entity;
  INSERT INTO platform_core.tenant_sites (tenant_id, legal_entity_id, display_name, is_default)
  VALUES (v_tenant, v_legal_entity, v_site_name, true) RETURNING id INTO v_site;
  INSERT INTO platform_core.tenant_roles (
    tenant_id, role_key, role_version, permission_snapshot, protects_tenant_admin
  ) VALUES (
    v_tenant, 'tenant.owner_admin.v1', 1,
    ARRAY['tenant.administer', 'tenant.members.manage', 'tenant.sites.manage', 'tenant.legal_entities.manage']::text[],
    true
  ) RETURNING role_id INTO v_role_id;
  INSERT INTO platform_core.tenant_memberships (
    tenant_id, user_id, access_state, created_by_operator_id
  ) VALUES (
    v_tenant, v_admin, 'active', v_actor
  );
  INSERT INTO platform_core.membership_roles (tenant_id, user_id, role_id)
  VALUES (v_tenant, v_admin, v_role_id);

  v_result := pg_catalog.jsonb_build_object(
    'tenant_id', v_tenant,
    'tenant_name', v_tenant_name,
    'legal_entity_id', v_legal_entity,
    'legal_entity_name', v_entity_name,
    'site_id', v_site,
    'site_name', v_site_name,
    'admin_email', v_admin_email,
    'seat_limit_mode', p_seat_limit_mode,
    'seat_limit', p_seat_limit,
    'seat_usage', 1,
    'site_limit_mode', p_site_limit_mode,
    'site_limit', p_site_limit,
    'site_usage', 1
  );

  INSERT INTO platform_core.audit_events (
    event_key, tenant_id, actor_user_id, subject_user_id, details
  ) VALUES (
    'platform.tenant.onboard', v_tenant, v_actor, v_admin,
    pg_catalog.jsonb_build_object(
      'idempotency_key', p_idempotency_key,
      'seat_limit_mode', p_seat_limit_mode,
      'seat_limit', p_seat_limit,
      'site_limit_mode', p_site_limit_mode,
      'site_limit', p_site_limit,
      'role_snapshot_key', 'tenant.owner_admin.v1',
      'role_snapshot_version', 1
    )
  );
  UPDATE platform_core.tenant_onboarding_idempotency
  SET tenant_id = v_tenant, result_snapshot = v_result
  WHERE actor_user_id = v_actor AND idempotency_key = p_idempotency_key;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.onboard_tenant(uuid, text, text, text, text, text, integer, text, integer) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.onboard_tenant(uuid, text, text, text, text, text, integer, text, integer) TO authenticated;

CREATE FUNCTION public.tenant_onboarding_result(p_idempotency_key uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT request.result_snapshot
  FROM platform_core.tenant_onboarding_idempotency AS request
  JOIN platform_private.platform_operator_grants AS grant_row
    ON grant_row.user_id = request.actor_user_id
  JOIN auth.users AS operator_user ON operator_user.id = grant_row.user_id
  WHERE request.actor_user_id = (SELECT auth.uid())
    AND grant_row.is_active
    AND grant_row.can_onboard_tenants
    AND operator_user.deleted_at IS NULL
    AND operator_user.email_confirmed_at IS NOT NULL
    AND (operator_user.banned_until IS NULL OR operator_user.banned_until <= pg_catalog.now())
    AND request.idempotency_key = p_idempotency_key
    AND request.result_snapshot IS NOT NULL;
$function$;
REVOKE ALL ON FUNCTION public.tenant_onboarding_result(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.tenant_onboarding_result(uuid) TO authenticated;

CREATE FUNCTION public.tenant_admin_snapshot(p_tenant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_snapshot jsonb;
  v_seat_limit jsonb;
  v_site_limit jsonb;
  v_users_limit_count integer;
  v_sites_limit_count integer;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users AS auth_user
    WHERE auth_user.id = v_actor
      AND auth_user.deleted_at IS NULL
      AND auth_user.email_confirmed_at IS NOT NULL
      AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  ) OR NOT EXISTS (
    SELECT 1 FROM platform_core.tenant_memberships AS membership
    JOIN platform_core.membership_roles AS assignment
      ON assignment.tenant_id = membership.tenant_id AND assignment.user_id = membership.user_id
    JOIN platform_core.tenant_roles AS role_snapshot
      ON role_snapshot.tenant_id = assignment.tenant_id AND role_snapshot.role_id = assignment.role_id
    WHERE membership.tenant_id = p_tenant_id
      AND membership.user_id = v_actor
      AND membership.access_state = 'active'
      AND role_snapshot.protects_tenant_admin
      AND role_snapshot.permission_snapshot @> ARRAY['tenant.administer']::text[]
  ) THEN
    RAISE EXCEPTION 'tenant_snapshot_forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT
    pg_catalog.count(*) FILTER (WHERE capability_key = 'tenant.users')::integer,
    pg_catalog.count(*) FILTER (WHERE capability_key = 'tenant.sites')::integer
  INTO v_users_limit_count, v_sites_limit_count
  FROM platform_core.tenant_capability_limits AS capability_limit
  WHERE capability_limit.tenant_id = p_tenant_id
    AND capability_limit.valid_from <= pg_catalog.transaction_timestamp()
    AND (capability_limit.valid_until IS NULL OR capability_limit.valid_until > pg_catalog.transaction_timestamp());
  IF v_users_limit_count <> 1 OR v_sites_limit_count <> 1 THEN
    RAISE EXCEPTION 'tenant_snapshot_limits_unavailable' USING ERRCODE = '55000';
  END IF;

  SELECT pg_catalog.jsonb_build_object('mode', capability_limit.limit_mode, 'value', capability_limit.limit_value)
  INTO v_seat_limit
  FROM platform_core.tenant_capability_limits AS capability_limit
  WHERE capability_limit.tenant_id = p_tenant_id
    AND capability_limit.capability_key = 'tenant.users'
    AND capability_limit.valid_from <= pg_catalog.transaction_timestamp()
    AND (capability_limit.valid_until IS NULL OR capability_limit.valid_until > pg_catalog.transaction_timestamp());
  SELECT pg_catalog.jsonb_build_object('mode', capability_limit.limit_mode, 'value', capability_limit.limit_value)
  INTO v_site_limit
  FROM platform_core.tenant_capability_limits AS capability_limit
  WHERE capability_limit.tenant_id = p_tenant_id
    AND capability_limit.capability_key = 'tenant.sites'
    AND capability_limit.valid_from <= pg_catalog.transaction_timestamp()
    AND (capability_limit.valid_until IS NULL OR capability_limit.valid_until > pg_catalog.transaction_timestamp());

  SELECT pg_catalog.jsonb_build_object(
    'tenant_id', tenant.id,
    'tenant_name', tenant.display_name,
    'lifecycle_state', tenant.lifecycle_state,
    'seat_limit_mode', v_seat_limit ->> 'mode',
    'seat_limit', v_seat_limit -> 'value',
    'seat_usage', (SELECT pg_catalog.count(*) FROM platform_core.tenant_memberships AS membership WHERE membership.tenant_id = tenant.id AND membership.access_state = 'active'),
    'site_limit_mode', v_site_limit ->> 'mode',
    'site_limit', v_site_limit -> 'value',
    'site_usage', (SELECT pg_catalog.count(*) FROM platform_core.tenant_sites AS site WHERE site.tenant_id = tenant.id AND site.is_active),
    'default_legal_entity', (
      SELECT pg_catalog.jsonb_build_object('id', legal_entity.id, 'name', legal_entity.display_name)
      FROM platform_core.tenant_legal_entities AS legal_entity
      WHERE legal_entity.tenant_id = tenant.id AND legal_entity.is_default AND legal_entity.is_active
    ),
    'default_site', (
      SELECT pg_catalog.jsonb_build_object('id', site.id, 'name', site.display_name, 'legal_entity_id', site.legal_entity_id)
      FROM platform_core.tenant_sites AS site
      WHERE site.tenant_id = tenant.id AND site.is_default AND site.is_active
    )
  ) INTO v_snapshot
  FROM platform_core.tenants AS tenant
  WHERE tenant.id = p_tenant_id AND tenant.lifecycle_state = 'active';
  IF v_snapshot IS NULL THEN
    RAISE EXCEPTION 'tenant_snapshot_not_available' USING ERRCODE = 'P0002';
  END IF;
  RETURN v_snapshot;
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_admin_snapshot(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.tenant_admin_snapshot(uuid) TO authenticated;

COMMENT ON SCHEMA platform_core IS 'Private tenant-owned platform foundation data; access is through narrow authenticated RPCs.';
COMMENT ON FUNCTION public.onboard_tenant(uuid, text, text, text, text, text, integer, text, integer) IS
  'Atomically creates a Tenant, default Legal Entity/Site, protected Admin Membership, idempotency result, and required audit.';
  COMMENT ON FUNCTION public.tenant_admin_snapshot(uuid) IS
  'Reads a bounded initial Tenant snapshot for an active Tenant Owner/Admin membership only.';
