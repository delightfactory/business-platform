-- Conditional B3: one authorized setup read, bounded by the employee's real site.
-- No own-capture impersonation, coordinates, business writes, audit or reservation.
CREATE FUNCTION public.people_employee_channel_readiness(p_tenant uuid,p_employee uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  employee jsonb;
  source_id uuid;
  source_enabled boolean;
  source_config jsonb;
BEGIN
  IF NOT time.channel_operator_can(p_tenant,false) THEN
    RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501';
  END IF;
  -- Reuse People visibility and its authoritative active/scheduled/ended context.
  employee := public.people_employee_snapshot(p_tenant,p_employee);
  IF employee IS NULL THEN
    RAISE EXCEPTION 'people_employee_unavailable' USING ERRCODE='P0002';
  END IF;
  IF employee->>'status' IS DISTINCT FROM 'active'
     OR employee->'employment'->>'status' IS DISTINCT FROM 'active'
     OR employee->'assignment'->>'site_id' IS NULL THEN
    RETURN pg_catalog.jsonb_build_object('state','work-unavailable');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM platform_core.tenant_sites site
    JOIN platform_core.tenant_legal_entities entity ON entity.tenant_id=site.tenant_id AND entity.id=site.legal_entity_id
    WHERE site.tenant_id=p_tenant AND site.id=(employee->'assignment'->>'site_id')::uuid
      AND site.is_active AND entity.is_active
  ) THEN
    RETURN pg_catalog.jsonb_build_object('state','site-inactive');
  END IF;
  SELECT s.id,v.enabled,v.config INTO source_id,source_enabled,source_config
  FROM time.channel_sources s
  LEFT JOIN LATERAL (
    SELECT x.enabled,x.config FROM time.channel_source_versions x
    WHERE x.tenant_id=s.tenant_id AND x.source_id=s.id ORDER BY x.version DESC LIMIT 1
  ) v ON true
  WHERE s.tenant_id=p_tenant AND s.kind='mobile'
    AND s.site_id=(employee->'assignment'->>'site_id')::uuid
  LIMIT 1;
  RETURN pg_catalog.jsonb_build_object('state',
    CASE WHEN source_id IS NULL THEN 'missing'
      WHEN source_enabled IS DISTINCT FROM true THEN 'disabled'
      WHEN time.validate_channel_config('mobile',source_config) IS DISTINCT FROM true THEN 'unconfigured'
      ELSE 'ready' END,
    'source_id',source_id,
    'capture_enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',pg_catalog.now()));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_channel_readiness(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_channel_readiness(uuid,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
