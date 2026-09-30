ALTER TABLE platform_core.tenant_membership_audit_events
  DROP CONSTRAINT tenant_membership_audit_events_action_check;
ALTER TABLE platform_core.tenant_membership_audit_events
  ADD CONSTRAINT tenant_membership_audit_events_action_check
  CHECK (action IN (
    'invitation_created','delivery_sent','delivery_failed','reissued','revoked','expired','accepted',
    'already_member','deactivated','reactivated','credential_ready','admin_role_promoted','admin_role_demoted',
    'people_role_bundles_changed'
  ));

CREATE FUNCTION platform_private.people_role_bundle_catalog()
RETURNS TABLE(role_key text, role_version integer, permission_snapshot text[])
LANGUAGE sql IMMUTABLE SET search_path = '' AS $function$
  SELECT bundle.role_key, 1, bundle.permission_snapshot
  FROM (VALUES
    ('people.reader.v1'::text, ARRAY['people.view']::text[]),
    ('people.operations.v1'::text, ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage']::text[]),
    ('people.compensation_reader.v1'::text, ARRAY['people.view','compensation.view']::text[]),
    ('people.compensation_manager.v1'::text, ARRAY['people.view','compensation.view','compensation.manage']::text[]),
    ('people.import_operator.v1'::text, ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','workforce_import.execute']::text[])
  ) AS bundle(role_key, permission_snapshot);
$function$;
REVOKE ALL ON FUNCTION platform_private.people_role_bundle_catalog() FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.set_tenant_member_people_bundles(
  p_tenant_id uuid,
  p_user_id uuid,
  p_bundle_keys text[]
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_tenant_state text;
  v_target_access text;
  v_before text[];
  v_requested text[];
BEGIN
  IF p_tenant_id IS NULL OR p_user_id IS NULL OR p_bundle_keys IS NULL
     OR pg_catalog.cardinality(p_bundle_keys) > 5
     OR EXISTS (SELECT 1 FROM pg_catalog.unnest(p_bundle_keys) AS supplied(key) WHERE supplied.key IS NULL OR supplied.key = '')
     OR pg_catalog.cardinality(p_bundle_keys) <> (SELECT pg_catalog.count(DISTINCT key)::integer FROM pg_catalog.unnest(p_bundle_keys) AS supplied(key)) THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_input_invalid' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text, 90427));
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id = p_tenant_id;
  IF NOT FOUND OR v_tenant_state <> 'active' THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_tenant_unavailable' USING ERRCODE = '55000';
  END IF;
  IF v_actor IS NULL OR NOT platform_private.has_tenant_permission(p_tenant_id, v_actor, 'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT membership.access_state INTO v_target_access
  FROM platform_core.tenant_memberships AS membership
  JOIN auth.users AS target ON target.id = membership.user_id
  WHERE membership.tenant_id = p_tenant_id AND membership.user_id = p_user_id
    AND target.deleted_at IS NULL AND target.email_confirmed_at IS NOT NULL
    AND (target.banned_until IS NULL OR target.banned_until <= pg_catalog.now())
  FOR UPDATE OF membership;
  IF NOT FOUND OR v_target_access <> 'active' THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_target_unavailable' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (
    SELECT 1 FROM platform_core.membership_roles AS assignment
    JOIN platform_core.tenant_roles AS role_snapshot USING (tenant_id, role_id)
    WHERE assignment.tenant_id = p_tenant_id AND assignment.user_id = p_user_id
      AND role_snapshot.protects_tenant_admin
  ) THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_admin_protected' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_catalog.unnest(p_bundle_keys) AS requested(key)
    WHERE NOT EXISTS (SELECT 1 FROM platform_private.people_role_bundle_catalog() AS bundle WHERE bundle.role_key = requested.key)
  ) THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_unknown' USING ERRCODE = '22023';
  END IF;

  INSERT INTO platform_core.tenant_roles(tenant_id, role_key, role_version, permission_snapshot, protects_tenant_admin)
  SELECT p_tenant_id, bundle.role_key, bundle.role_version, bundle.permission_snapshot, false
  FROM platform_private.people_role_bundle_catalog() AS bundle
  ON CONFLICT (tenant_id, role_key, role_version) DO NOTHING;
  IF EXISTS (
    SELECT 1 FROM platform_private.people_role_bundle_catalog() AS bundle
    JOIN platform_core.tenant_roles AS role_snapshot
      ON role_snapshot.tenant_id = p_tenant_id AND role_snapshot.role_key = bundle.role_key
      AND role_snapshot.role_version = bundle.role_version
    WHERE role_snapshot.permission_snapshot IS DISTINCT FROM bundle.permission_snapshot
      OR role_snapshot.protects_tenant_admin
  ) THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_catalog_unavailable' USING ERRCODE = '55000';
  END IF;

  SELECT COALESCE(pg_catalog.array_agg(role_snapshot.role_key ORDER BY role_snapshot.role_key), ARRAY[]::text[])
  INTO v_before
  FROM platform_core.membership_roles AS assignment
  JOIN platform_core.tenant_roles AS role_snapshot USING (tenant_id, role_id)
  WHERE assignment.tenant_id = p_tenant_id AND assignment.user_id = p_user_id
    AND role_snapshot.role_key IN (SELECT role_key FROM platform_private.people_role_bundle_catalog());
  SELECT COALESCE(pg_catalog.array_agg(key ORDER BY key), ARRAY[]::text[])
  INTO v_requested FROM pg_catalog.unnest(p_bundle_keys) AS requested(key);

  IF v_before IS NOT DISTINCT FROM v_requested THEN
    RETURN pg_catalog.jsonb_build_object('state', 'unchanged', 'bundle_keys', v_requested);
  END IF;

  DELETE FROM platform_core.membership_roles AS assignment
  USING platform_core.tenant_roles AS role_snapshot
  WHERE assignment.tenant_id = p_tenant_id AND assignment.user_id = p_user_id
    AND role_snapshot.tenant_id = assignment.tenant_id AND role_snapshot.role_id = assignment.role_id
    AND role_snapshot.role_key IN (SELECT role_key FROM platform_private.people_role_bundle_catalog());

  INSERT INTO platform_core.membership_roles(tenant_id, user_id, role_id)
  SELECT p_tenant_id, p_user_id, role_snapshot.role_id
  FROM platform_core.tenant_roles AS role_snapshot
  WHERE role_snapshot.tenant_id = p_tenant_id
    AND role_snapshot.role_key = ANY(v_requested)
    AND role_snapshot.role_version = 1;

  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id, actor_user_id, subject_user_id, action, details)
  VALUES (p_tenant_id, v_actor, p_user_id, 'people_role_bundles_changed',
    pg_catalog.jsonb_build_object('before', v_before, 'after', v_requested));

  RETURN pg_catalog.jsonb_build_object('state', 'updated', 'bundle_keys', v_requested);
END;
$function$;
REVOKE ALL ON FUNCTION public.set_tenant_member_people_bundles(uuid, uuid, text[]) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.set_tenant_member_people_bundles(uuid, uuid, text[]) TO authenticated;
