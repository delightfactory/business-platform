-- Direct, effective-dated decisions for the two bounded HR capabilities.
CREATE TABLE platform_core.tenant_capability_entitlements (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  capability_key text NOT NULL CHECK (capability_key IN ('hr.people', 'hr.payroll')),
  is_granted boolean NOT NULL,
  valid_from timestamptz NOT NULL,
  valid_until timestamptz,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  reason text NOT NULL CHECK (COALESCE(NULLIF(pg_catalog.btrim(reason), ''), '') <> '' AND pg_catalog.length(reason) <= 500),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
  PRIMARY KEY (tenant_id, capability_key, valid_from),
  CHECK (valid_until IS NULL OR valid_until > valid_from)
);
CREATE INDEX tenant_capability_entitlements_effective_idx
  ON platform_core.tenant_capability_entitlements(tenant_id, capability_key, valid_from, valid_until);
ALTER TABLE platform_core.tenant_capability_entitlements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_capability_entitlements FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.prevent_tenant_capability_entitlement_overlap()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(NEW.tenant_id::text || ':' || NEW.capability_key || ':entitlement', 35192)
  );
  IF EXISTS (
    SELECT 1 FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id = NEW.tenant_id AND e.capability_key = NEW.capability_key
      AND (TG_OP = 'INSERT' OR e.valid_from <> OLD.valid_from)
      AND (e.valid_until IS NULL OR e.valid_until > NEW.valid_from)
      AND (NEW.valid_until IS NULL OR NEW.valid_until > e.valid_from)
  ) THEN
    RAISE EXCEPTION 'tenant_entitlement_interval_overlap' USING ERRCODE = '23P01';
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER tenant_capability_entitlement_no_overlap
BEFORE INSERT OR UPDATE ON platform_core.tenant_capability_entitlements
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_capability_entitlement_overlap();
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_capability_entitlement_overlap() FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_core.tenant_capability_entitlement_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  capability_key text NOT NULL CHECK (capability_key IN ('hr.people', 'hr.payroll')),
  effective_at timestamptz NOT NULL,
  before_state jsonb,
  after_state jsonb NOT NULL,
  reason text NOT NULL CHECK (COALESCE(NULLIF(pg_catalog.btrim(reason), ''), '') <> '' AND pg_catalog.length(reason) <= 500),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_capability_entitlement_audit_events FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.prevent_tenant_capability_entitlement_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN RAISE EXCEPTION 'tenant_capability_entitlement_audit_append_only' USING ERRCODE = '55000'; END;
$function$;
CREATE TRIGGER tenant_capability_entitlement_audit_append_only
BEFORE UPDATE OR DELETE ON platform_core.tenant_capability_entitlement_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_capability_entitlement_audit_mutation();
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_capability_entitlement_audit_mutation() FROM PUBLIC, anon, authenticated, service_role;

-- This evaluator is internal. Payroll additionally requires exactly one effective People grant.
CREATE FUNCTION platform_private.tenant_capability_is_enabled(p_tenant_id uuid, p_capability_key text, p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_count integer; v_granted boolean; v_people_count integer; v_people_granted boolean;
BEGIN
  IF p_capability_key NOT IN ('hr.people', 'hr.payroll') OR p_tenant_id IS NULL OR p_at IS NULL THEN RETURN false; END IF;
  SELECT pg_catalog.count(*)::integer, pg_catalog.bool_and(e.is_granted)
    INTO v_count, v_granted
    FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id = p_tenant_id AND e.capability_key = p_capability_key
      AND e.valid_from <= p_at AND (e.valid_until IS NULL OR e.valid_until > p_at);
  IF v_count <> 1 OR NOT COALESCE(v_granted, false) THEN RETURN false; END IF;
  IF p_capability_key = 'hr.payroll' THEN
    SELECT pg_catalog.count(*)::integer, pg_catalog.bool_and(e.is_granted)
      INTO v_people_count, v_people_granted
      FROM platform_core.tenant_capability_entitlements e
      WHERE e.tenant_id = p_tenant_id AND e.capability_key = 'hr.people'
        AND e.valid_from <= p_at AND (e.valid_until IS NULL OR e.valid_until > p_at);
    RETURN v_people_count = 1 AND COALESCE(v_people_granted, false);
  END IF;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION platform_private.tenant_capability_is_enabled(uuid, text, timestamptz) FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.platform_tenant_entitlement_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_tenant jsonb; v_decisions jsonb; v_now timestamptz := pg_catalog.clock_timestamp();
BEGIN
  IF NOT public.current_operator_can_manage_commercial_access() THEN
    RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE = '42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object('tenant_id', t.id, 'display_name', t.display_name, 'lifecycle_state', t.lifecycle_state)
    INTO v_tenant FROM platform_core.tenants t WHERE t.id = p_tenant_id;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE = 'P0002'; END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'capability_key', wanted.capability_key,
      'status', CASE WHEN current_rows.n > 1 THEN 'conflict' WHEN future_rows.n > 0 THEN 'future_conflict'
        WHEN current_rows.n = 0 THEN 'missing' ELSE 'effective' END,
      'is_granted', current_rows.is_granted,
      'valid_from', current_rows.valid_from,
      'valid_until', current_rows.valid_until,
      'effective_at', v_now,
      'evaluator_enabled', platform_private.tenant_capability_is_enabled(p_tenant_id, wanted.capability_key, v_now),
      'last_decision', expired_rows.is_granted,
      'last_decision_valid_from', expired_rows.valid_from,
      'last_decision_valid_until', expired_rows.valid_until
    ) ORDER BY wanted.capability_key), '[]'::jsonb)
    INTO v_decisions
    FROM (VALUES ('hr.people'), ('hr.payroll')) AS wanted(capability_key)
    LEFT JOIN LATERAL (
      SELECT pg_catalog.count(*)::integer n, pg_catalog.bool_and(e.is_granted) is_granted,
        pg_catalog.min(e.valid_from) valid_from, pg_catalog.min(e.valid_until) valid_until
      FROM platform_core.tenant_capability_entitlements e
      WHERE e.tenant_id = p_tenant_id AND e.capability_key = wanted.capability_key
        AND e.valid_from <= v_now AND (e.valid_until IS NULL OR e.valid_until > v_now)
    ) current_rows ON true
    LEFT JOIN LATERAL (
      SELECT pg_catalog.count(*)::integer n FROM platform_core.tenant_capability_entitlements e
      WHERE e.tenant_id = p_tenant_id AND e.capability_key = wanted.capability_key AND e.valid_from > v_now
    ) future_rows ON true
    LEFT JOIN LATERAL (
      SELECT e.is_granted, e.valid_from, e.valid_until FROM platform_core.tenant_capability_entitlements e
      WHERE e.tenant_id = p_tenant_id AND e.capability_key = wanted.capability_key
        AND e.valid_until IS NOT NULL AND e.valid_until <= v_now
      ORDER BY e.valid_until DESC LIMIT 1
    ) expired_rows ON true;
  RETURN v_tenant || pg_catalog.jsonb_build_object('entitlements', v_decisions);
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_tenant_entitlement_snapshot(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_entitlement_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.change_tenant_capability_entitlement(
  p_tenant_id uuid, p_capability_key text, p_is_granted boolean, p_valid_until date, p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid()); v_now timestamptz; v_valid_until timestamptz; v_old platform_core.tenant_capability_entitlements%ROWTYPE;
  v_rows integer; v_future integer; v_people_count integer; v_people_granted boolean; v_people_until timestamptz;
  v_before jsonb; v_after jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_capability_key NOT IN ('hr.people', 'hr.payroll') OR p_is_granted IS NULL THEN
    RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE = '22023';
  END IF;
  IF COALESCE(NULLIF(pg_catalog.btrim(p_reason), ''), '') = '' OR pg_catalog.length(pg_catalog.btrim(p_reason)) > 500 THEN
    RAISE EXCEPTION 'tenant_entitlement_reason_required' USING ERRCODE = '22023';
  END IF;
  IF v_actor IS NULL OR NOT public.current_operator_can_manage_commercial_access() THEN
    RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text, 90427));
  IF NOT public.current_operator_can_manage_commercial_access() THEN
    RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM platform_core.tenants t WHERE t.id = p_tenant_id) THEN
    RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE = 'P0002';
  END IF;
  v_now := pg_catalog.clock_timestamp();
  -- The form date is the final Cairo calendar day; expiration is next midnight in Cairo.
  IF p_valid_until IS NOT NULL THEN
    v_valid_until := ((p_valid_until + 1)::timestamp AT TIME ZONE 'Africa/Cairo');
  END IF;
  IF v_valid_until IS NOT NULL AND v_valid_until <= v_now THEN
    RAISE EXCEPTION 'tenant_entitlement_expiry_invalid' USING ERRCODE = '22023';
  END IF;
  SELECT pg_catalog.count(*)::integer INTO v_future FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id = p_tenant_id AND e.capability_key = p_capability_key AND e.valid_from > v_now;
  IF v_future > 0 THEN RAISE EXCEPTION 'tenant_entitlement_future_conflict' USING ERRCODE = '23P01'; END IF;
  SELECT pg_catalog.count(*)::integer INTO v_rows FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id = p_tenant_id AND e.capability_key = p_capability_key
      AND e.valid_from <= v_now AND (e.valid_until IS NULL OR e.valid_until > v_now);
  IF v_rows > 1 THEN RAISE EXCEPTION 'tenant_entitlement_conflict' USING ERRCODE = '55000'; END IF;

  IF p_capability_key = 'hr.payroll' AND p_is_granted THEN
    SELECT pg_catalog.count(*)::integer, pg_catalog.bool_and(e.is_granted), pg_catalog.max(e.valid_until)
      INTO v_people_count, v_people_granted, v_people_until
      FROM platform_core.tenant_capability_entitlements e
      WHERE e.tenant_id = p_tenant_id AND e.capability_key = 'hr.people'
        AND e.valid_from <= v_now AND (e.valid_until IS NULL OR e.valid_until > v_now);
    IF v_people_count <> 1 OR NOT COALESCE(v_people_granted, false) OR
      (v_people_until IS NOT NULL AND (v_valid_until IS NULL OR v_valid_until > v_people_until)) THEN
      RAISE EXCEPTION 'tenant_entitlement_people_required' USING ERRCODE = '23514';
    END IF;
  ELSIF p_capability_key = 'hr.people' AND v_rows = 1 THEN
    SELECT * INTO v_old FROM platform_core.tenant_capability_entitlements e
      WHERE e.tenant_id = p_tenant_id AND e.capability_key = 'hr.people'
        AND e.valid_from <= v_now AND (e.valid_until IS NULL OR e.valid_until > v_now) FOR UPDATE;
    IF (NOT p_is_granted AND EXISTS (SELECT 1 FROM platform_core.tenant_capability_entitlements payroll
          WHERE payroll.tenant_id = p_tenant_id AND payroll.capability_key = 'hr.payroll' AND payroll.is_granted
            AND payroll.valid_from <= v_now AND (payroll.valid_until IS NULL OR payroll.valid_until > v_now)))
      OR (p_is_granted AND v_valid_until IS NOT NULL AND (v_old.valid_until IS NULL OR v_valid_until < v_old.valid_until)
        AND EXISTS (SELECT 1 FROM platform_core.tenant_capability_entitlements payroll
          WHERE payroll.tenant_id = p_tenant_id AND payroll.capability_key = 'hr.payroll' AND payroll.is_granted
            AND payroll.valid_from < v_valid_until AND (payroll.valid_until IS NULL OR payroll.valid_until > v_valid_until))) THEN
      RAISE EXCEPTION 'tenant_entitlement_payroll_must_end_first' USING ERRCODE = '23514';
    END IF;
  END IF;

  IF v_rows = 1 AND NOT (p_capability_key = 'hr.people' AND v_old.tenant_id IS NOT NULL) THEN
    SELECT * INTO v_old FROM platform_core.tenant_capability_entitlements e
      WHERE e.tenant_id = p_tenant_id AND e.capability_key = p_capability_key
        AND e.valid_from <= v_now AND (e.valid_until IS NULL OR e.valid_until > v_now) FOR UPDATE;
  END IF;
  IF v_rows = 1 THEN
    v_before := pg_catalog.jsonb_build_object('is_granted', v_old.is_granted, 'valid_from', v_old.valid_from, 'valid_until', v_old.valid_until);
    UPDATE platform_core.tenant_capability_entitlements SET valid_until = v_now
      WHERE tenant_id = p_tenant_id AND capability_key = p_capability_key AND valid_from = v_old.valid_from;
  END IF;
  INSERT INTO platform_core.tenant_capability_entitlements(tenant_id, capability_key, is_granted, valid_from, valid_until, actor_user_id, reason)
    VALUES (p_tenant_id, p_capability_key, p_is_granted, v_now, v_valid_until, v_actor, pg_catalog.btrim(p_reason));
  v_after := pg_catalog.jsonb_build_object('is_granted', p_is_granted, 'valid_from', v_now, 'valid_until', v_valid_until);
  INSERT INTO platform_core.tenant_capability_entitlement_audit_events(tenant_id, actor_user_id, capability_key, effective_at, before_state, after_state, reason)
    VALUES (p_tenant_id, v_actor, p_capability_key, v_now, v_before, v_after, pg_catalog.btrim(p_reason));
  RETURN pg_catalog.jsonb_build_object('tenant_id', p_tenant_id, 'capability_key', p_capability_key,
    'is_granted', p_is_granted, 'effective_at', v_now, 'valid_until', v_valid_until);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_tenant_capability_entitlement(uuid, text, boolean, date, text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.change_tenant_capability_entitlement(uuid, text, boolean, date, text) TO authenticated;
