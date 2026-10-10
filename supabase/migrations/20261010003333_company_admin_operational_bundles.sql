-- Owner-approved: protected company administrators may opt into existing work bundles.
-- Preserve the current function, including catalog, limits, locking, checks and audit.
DO $migration$
DECLARE
  definition text := pg_catalog.pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure);
  protected_target_guard constant text := $guard$  IF EXISTS (
    SELECT 1 FROM platform_core.membership_roles AS assignment
    JOIN platform_core.tenant_roles AS role_snapshot USING (tenant_id, role_id)
    WHERE assignment.tenant_id = p_tenant_id AND assignment.user_id = p_user_id
      AND role_snapshot.protects_tenant_admin
  ) THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_admin_protected' USING ERRCODE = '42501';
  END IF;
$guard$;
  guard_to_remove text := pg_catalog.replace(protected_target_guard, E'\r', '');
BEGIN
  IF pg_catalog.strpos(definition, guard_to_remove) = 0 THEN
    guard_to_remove := pg_catalog.replace(guard_to_remove, E'\n', E'\r\n');
  END IF;
  IF pg_catalog.length(definition) - pg_catalog.length(pg_catalog.replace(definition, guard_to_remove, '')) <> pg_catalog.length(guard_to_remove)
     OR pg_catalog.strpos(pg_catalog.replace(definition, guard_to_remove, ''), 'tenant_people_role_bundle_admin_protected') > 0 THEN
    RAISE EXCEPTION 'unexpected_protected_target_bundle_guard';
  END IF;
  EXECUTE pg_catalog.replace(definition, guard_to_remove, '');
END;
$migration$;
