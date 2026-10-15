-- A stale editor is an application conflict, not a serialization failure.
-- Preserve the existing transaction, access checks and exact expected-set guard.
DO $migration$
DECLARE
  definition text := pg_catalog.pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[],text[])'::regprocedure);
  old_error constant text := $anchor$'tenant_people_role_bundle_stale' USING ERRCODE='40001'$anchor$;
  new_error constant text := $anchor$'tenant_people_role_bundle_stale' USING ERRCODE='PT409'$anchor$;
BEGIN
  IF length(definition)-length(replace(definition,old_error,'')) <> 2*length(old_error) THEN
    RAISE EXCEPTION 'unexpected_company_work_stale_definition';
  END IF;
  EXECUTE replace(definition,old_error,new_error);
END;
$migration$;
NOTIFY pgrst, 'reload schema';
