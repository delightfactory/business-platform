-- Expose existing financial permissions through explicit work bundles only.
-- Preserve the maintained grant implementation and its protected-role/audit rules.
DO $migration$
DECLARE
  definition text;
  catalog_anchor constant text := $anchor$('payroll.payment.recorder.v1'::text,ARRAY['payroll.view','payroll.payment_record']::text[])$anchor$;
  limit_anchor constant text := 'pg_catalog.cardinality(p_bundle_keys) > 24';
  signature_anchor constant text := 'p_bundle_keys text[])';
  expected_anchor constant text := '  INTO v_requested FROM pg_catalog.unnest(p_bundle_keys) AS requested(key);';
  expected_check constant text := $check$

  IF p_expected_bundle_keys IS NULL THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_stale' USING ERRCODE='40001';
  END IF;
  IF pg_catalog.cardinality(p_expected_bundle_keys) > (SELECT count(*) FROM platform_private.people_role_bundle_catalog())
     OR EXISTS (SELECT 1 FROM pg_catalog.unnest(p_expected_bundle_keys) AS supplied(key) WHERE supplied.key IS NULL OR supplied.key='')
     OR pg_catalog.cardinality(p_expected_bundle_keys) <> (SELECT count(DISTINCT key) FROM pg_catalog.unnest(p_expected_bundle_keys) AS supplied(key)) THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_input_invalid' USING ERRCODE='22023';
  END IF;
  IF v_before IS DISTINCT FROM (SELECT COALESCE(pg_catalog.array_agg(key ORDER BY key), ARRAY[]::text[]) FROM pg_catalog.unnest(p_expected_bundle_keys) AS supplied(key)) THEN
    RAISE EXCEPTION 'tenant_people_role_bundle_stale' USING ERRCODE='40001';
  END IF;
$check$;
BEGIN
  IF (SELECT count(*) FROM platform_private.people_role_bundle_catalog()) <> 25
     OR EXISTS (SELECT 1 FROM platform_private.people_role_bundle_catalog() WHERE role_key IN ('payroll.finalizer.v1','payroll.exporter.v1')) THEN
    RAISE EXCEPTION 'unexpected_company_work_catalog';
  END IF;
  definition := pg_catalog.pg_get_functiondef('platform_private.people_role_bundle_catalog()'::regprocedure);
  IF (length(definition)-length(replace(definition,catalog_anchor,''))) <> length(catalog_anchor) THEN
    RAISE EXCEPTION 'unexpected_company_work_catalog_anchor';
  END IF;
  EXECUTE replace(definition,catalog_anchor,catalog_anchor || $rows$,('payroll.finalizer.v1'::text,ARRAY['payroll.view','payroll.lock']::text[]),('payroll.exporter.v1'::text,ARRAY['payroll.view','payroll.export']::text[])$rows$);

  definition := replace(pg_catalog.pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure),E'\r','');
  IF (length(definition)-length(replace(definition,limit_anchor,''))) <> length(limit_anchor)
     OR strpos(definition,'tenant_people_role_bundle_admin_protected') > 0 THEN
    RAISE EXCEPTION 'unexpected_company_work_grant_definition';
  END IF;
  definition := replace(definition,limit_anchor,'pg_catalog.cardinality(p_bundle_keys) > (SELECT count(*) FROM platform_private.people_role_bundle_catalog())');
  EXECUTE definition;

  IF (length(definition)-length(replace(definition,signature_anchor,''))) <> length(signature_anchor)
     OR (length(definition)-length(replace(definition,expected_anchor,''))) <> length(expected_anchor) THEN
    RAISE EXCEPTION 'unexpected_company_work_expected_anchor';
  END IF;
  definition := replace(definition,signature_anchor,'p_bundle_keys text[], p_expected_bundle_keys text[])');
  definition := replace(definition,expected_anchor,expected_anchor || expected_check);
  EXECUTE definition;
  EXECUTE 'REVOKE ALL ON FUNCTION public.set_tenant_member_people_bundles(uuid,uuid,text[],text[]) FROM PUBLIC,anon,authenticated,service_role';
  EXECUTE 'GRANT EXECUTE ON FUNCTION public.set_tenant_member_people_bundles(uuid,uuid,text[],text[]) TO authenticated';
END;
$migration$;

NOTIFY pgrst, 'reload schema';
