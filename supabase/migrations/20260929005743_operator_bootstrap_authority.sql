-- Platform Operator authority is separate from Tenant membership and Auth metadata.
CREATE SCHEMA platform_private;
REVOKE ALL ON SCHEMA platform_private FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_private.platform_operator_grants (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE RESTRICT,
  is_active boolean NOT NULL DEFAULT true,
  can_manage_operators boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CONSTRAINT platform_operator_manager_must_be_active
    CHECK (is_active OR NOT can_manage_operators)
);

COMMENT ON TABLE platform_private.platform_operator_grants IS
  'Application-owned Platform Operator authority; distinct from Tenant roles and infrastructure credentials.';

CREATE INDEX platform_operator_active_manager_idx
  ON platform_private.platform_operator_grants (user_id)
  WHERE is_active AND can_manage_operators;

ALTER TABLE platform_private.platform_operator_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_private.platform_operator_grants
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_private.platform_operator_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  action text NOT NULL CHECK (action IN ('bootstrap', 'recovery', 'grant', 'revoke')),
  actor_class text NOT NULL CHECK (actor_class IN ('platform_bootstrap', 'platform_operator')),
  actor_user_id uuid REFERENCES auth.users (id) ON DELETE RESTRICT,
  target_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  reason text,
  is_emergency boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CONSTRAINT platform_operator_audit_actor_shape CHECK (
    (actor_class = 'platform_bootstrap' AND actor_user_id IS NULL)
    OR (actor_class = 'platform_operator' AND actor_user_id IS NOT NULL)
  ),
  CONSTRAINT platform_operator_recovery_requires_reason CHECK (
    action <> 'recovery' OR COALESCE(NULLIF(btrim(reason), ''), '') <> ''
  ),
  CONSTRAINT platform_operator_emergency_requires_recovery CHECK (
    NOT is_emergency OR action = 'recovery'
  )
);

COMMENT ON TABLE platform_private.platform_operator_audit_events IS
  'Append-only audit evidence for Platform Operator authority changes.';

ALTER TABLE platform_private.platform_operator_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_private.platform_operator_audit_events
  FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_private.prevent_last_operator_manager_removal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_other_manager_exists boolean;
BEGIN
  -- Serialize all authority-row changes so concurrent revocations cannot each
  -- observe the other manager and remove both.
  PERFORM pg_catalog.pg_advisory_xact_lock(772412, 115991);

  IF TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    RAISE EXCEPTION 'A Platform Operator grant cannot be reassigned to another Auth user'
      USING ERRCODE = '23514';
  END IF;

  IF OLD.is_active AND OLD.can_manage_operators
     AND (TG_OP = 'DELETE' OR NOT NEW.is_active OR NOT NEW.can_manage_operators)
     AND EXISTS (
       SELECT 1
       FROM auth.users AS old_auth_user
       WHERE old_auth_user.id = OLD.user_id
         AND old_auth_user.deleted_at IS NULL
         AND old_auth_user.email_confirmed_at IS NOT NULL
         AND (old_auth_user.banned_until IS NULL OR old_auth_user.banned_until <= pg_catalog.now())
     ) THEN
    SELECT EXISTS (
      SELECT 1
      FROM platform_private.platform_operator_grants AS grant_row
      JOIN auth.users AS auth_user ON auth_user.id = grant_row.user_id
      WHERE grant_row.user_id <> OLD.user_id
        AND grant_row.is_active
        AND grant_row.can_manage_operators
        AND auth_user.deleted_at IS NULL
        AND auth_user.email_confirmed_at IS NOT NULL
        AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
    ) INTO v_other_manager_exists;

    IF NOT v_other_manager_exists THEN
      RAISE EXCEPTION 'The final active Platform Operator manager cannot be removed'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER platform_operator_last_manager_guard
BEFORE UPDATE OR DELETE ON platform_private.platform_operator_grants
FOR EACH ROW EXECUTE FUNCTION platform_private.prevent_last_operator_manager_removal();

CREATE FUNCTION platform_private.prevent_operator_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION 'Platform Operator audit events are append-only'
    USING ERRCODE = '55000';
END;
$function$;

CREATE TRIGGER platform_operator_audit_append_only
BEFORE UPDATE OR DELETE ON platform_private.platform_operator_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_private.prevent_operator_audit_mutation();

CREATE FUNCTION platform_private.bootstrap_operator_manager(p_target_user_id uuid)
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
    SELECT 1
    FROM auth.users AS auth_user
    WHERE auth_user.id = p_target_user_id
      AND auth_user.deleted_at IS NULL
      AND auth_user.email_confirmed_at IS NOT NULL
      AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  ) THEN
    RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM platform_private.platform_operator_grants AS grant_row
    WHERE grant_row.is_active AND grant_row.can_manage_operators
  ) THEN
    RAISE EXCEPTION 'A Platform Operator manager already exists; bootstrap is one-time'
      USING ERRCODE = '55000';
  END IF;

  INSERT INTO platform_private.platform_operator_grants (
    user_id, is_active, can_manage_operators
  ) VALUES (p_target_user_id, true, true)
  ON CONFLICT (user_id) DO UPDATE
    SET is_active = true,
        can_manage_operators = true,
        updated_at = pg_catalog.clock_timestamp();

  INSERT INTO platform_private.platform_operator_audit_events (
    action, actor_class, target_user_id
  ) VALUES ('bootstrap', 'platform_bootstrap', p_target_user_id);
END;
$function$;

CREATE FUNCTION platform_private.recover_operator_manager(
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
    SELECT 1
    FROM auth.users AS auth_user
    WHERE auth_user.id = p_target_user_id
      AND auth_user.deleted_at IS NULL
      AND auth_user.email_confirmed_at IS NOT NULL
      AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
  ) THEN
    RAISE EXCEPTION 'The target must be an existing, enabled Auth user with a verified email'
      USING ERRCODE = '22023';
  END IF;

  IF NOT p_emergency AND EXISTS (
    SELECT 1
    FROM platform_private.platform_operator_grants AS grant_row
    WHERE grant_row.is_active AND grant_row.can_manage_operators
  ) THEN
    RAISE EXCEPTION 'A manager is active; declare and explain an emergency to recover another'
      USING ERRCODE = '55000';
  END IF;

  INSERT INTO platform_private.platform_operator_grants (
    user_id, is_active, can_manage_operators
  ) VALUES (p_target_user_id, true, true)
  ON CONFLICT (user_id) DO UPDATE
    SET is_active = true,
        can_manage_operators = true,
        updated_at = pg_catalog.clock_timestamp();

  INSERT INTO platform_private.platform_operator_audit_events (
    action, actor_class, target_user_id, reason, is_emergency
  ) VALUES ('recovery', 'platform_bootstrap', p_target_user_id, p_reason, p_emergency);
END;
$function$;

REVOKE ALL ON FUNCTION platform_private.prevent_last_operator_manager_removal() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION platform_private.prevent_operator_audit_mutation() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION platform_private.bootstrap_operator_manager(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION platform_private.recover_operator_manager(uuid, text, boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION platform_private.bootstrap_operator_manager(uuid) TO postgres;
GRANT EXECUTE ON FUNCTION platform_private.recover_operator_manager(uuid, text, boolean) TO postgres;
