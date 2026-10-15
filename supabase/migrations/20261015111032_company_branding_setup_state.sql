-- Default-looking values do not prove that branding has never been saved.
-- Add one read-only fact to the existing authorized snapshot; preserve all guards.
DO $migration$
DECLARE
  definition text := pg_catalog.pg_get_functiondef('public.tenant_branding_snapshot(uuid)'::regprocedure);
  anchor constant text := $anchor$'logo_object_path', b.logo_object_path,$anchor$;
BEGIN
  IF length(definition)-length(replace(definition,anchor,'')) <> length(anchor) THEN
    RAISE EXCEPTION 'unexpected_company_branding_snapshot_definition';
  END IF;
  EXECUTE replace(definition,anchor,anchor || E'\n    ''has_saved_branding'', b.tenant_id IS NOT NULL,');
END;
$migration$;
NOTIFY pgrst, 'reload schema';
