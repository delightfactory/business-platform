-- Accept canonical opaque RGB colors while retaining all legacy presets, authorization and audit behavior.
ALTER TABLE platform_core.tenant_branding
  DROP CONSTRAINT tenant_branding_primary_color_key_check,
  ADD CONSTRAINT tenant_branding_primary_color_key_check
    CHECK (primary_color_key IN ('teal','blue','violet','emerald') OR primary_color_key ~ '^#[0-9a-f]{6}$');
CREATE OR REPLACE FUNCTION public.save_tenant_branding(
  p_tenant_id uuid, p_display_name text, p_primary_color_key text,
  p_logo_object_path text, p_remove_logo boolean, p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid()); v_display_name text := NULLIF(pg_catalog.btrim(p_display_name), '');
  v_color text := pg_catalog.lower(pg_catalog.btrim(p_primary_color_key)); v_reason text := NULLIF(pg_catalog.btrim(p_reason), '');
  v_previous platform_core.tenant_branding%ROWTYPE; v_exists boolean; v_tenant_name text;
  v_logo_path text; v_before jsonb; v_after jsonb;
BEGIN
  IF p_tenant_id IS NULL OR v_color IS NULL OR (v_color NOT IN ('teal', 'blue', 'violet', 'emerald') AND v_color !~ '^#[0-9a-f]{6}$') OR p_remove_logo IS NULL
    OR (p_remove_logo AND p_logo_object_path IS NOT NULL) THEN
    RAISE EXCEPTION 'tenant_branding_input_invalid' USING ERRCODE = '22023';
  END IF;
  IF v_display_name IS NOT NULL AND pg_catalog.length(v_display_name) > 160 THEN
    RAISE EXCEPTION 'tenant_branding_display_name_invalid' USING ERRCODE = '22023';
  END IF;
  IF v_reason IS NULL OR pg_catalog.length(v_reason) > 500 THEN
    RAISE EXCEPTION 'tenant_branding_reason_required' USING ERRCODE = '22023';
  END IF;
  IF v_actor IS NULL OR NOT platform_private.has_tenant_permission(p_tenant_id, v_actor, 'tenant.administer') THEN
    RAISE EXCEPTION 'tenant_branding_forbidden' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text, 90427));
  IF NOT platform_private.has_tenant_permission(p_tenant_id, v_actor, 'tenant.administer') THEN
    RAISE EXCEPTION 'tenant_branding_forbidden' USING ERRCODE = '42501';
  END IF;
  SELECT t.display_name INTO v_tenant_name FROM platform_core.tenants t
  WHERE t.id = p_tenant_id AND t.lifecycle_state = 'active' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_branding_unavailable' USING ERRCODE = 'P0002'; END IF;
  SELECT b.* INTO v_previous FROM platform_core.tenant_branding b
  WHERE b.tenant_id = p_tenant_id FOR UPDATE;
  v_exists := FOUND;
  v_logo_path := CASE WHEN p_remove_logo THEN NULL
    WHEN p_logo_object_path IS NOT NULL THEN p_logo_object_path
    ELSE v_previous.logo_object_path END;
  IF p_logo_object_path IS NOT NULL THEN
    IF p_logo_object_path !~ ('^tenants/' || p_tenant_id::text || '/logos/[0-9a-f-]{36}\.(png|jpg|webp)$')
      OR NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id = 'tenant-branding' AND o.name = p_logo_object_path) THEN
      RAISE EXCEPTION 'tenant_branding_logo_unavailable' USING ERRCODE = '22023';
    END IF;
  END IF;
  v_before := CASE WHEN v_exists THEN pg_catalog.jsonb_build_object(
      'display_name', v_previous.display_name, 'primary_color_key', v_previous.primary_color_key,
      'logo_object_path', v_previous.logo_object_path)
    ELSE pg_catalog.jsonb_build_object('display_name', NULL, 'primary_color_key', 'teal', 'logo_object_path', NULL) END;
  IF v_exists AND v_previous.display_name IS NOT DISTINCT FROM v_display_name
    AND v_previous.primary_color_key = v_color AND v_previous.logo_object_path IS NOT DISTINCT FROM v_logo_path THEN
    RETURN pg_catalog.jsonb_build_object('state', 'unchanged', 'old_logo_object_path', v_previous.logo_object_path,
      'logo_object_path', v_previous.logo_object_path, 'tenant_name', COALESCE(v_display_name, v_tenant_name));
  END IF;
  INSERT INTO platform_core.tenant_branding(tenant_id, display_name, primary_color_key, logo_object_path, updated_by_user_id)
    VALUES (p_tenant_id, v_display_name, v_color, v_logo_path, v_actor)
  ON CONFLICT (tenant_id) DO UPDATE SET display_name = EXCLUDED.display_name,
    primary_color_key = EXCLUDED.primary_color_key, logo_object_path = EXCLUDED.logo_object_path,
    updated_by_user_id = EXCLUDED.updated_by_user_id, updated_at = pg_catalog.clock_timestamp();
  v_after := pg_catalog.jsonb_build_object('display_name', v_display_name,
    'primary_color_key', v_color, 'logo_object_path', v_logo_path);
  INSERT INTO platform_core.tenant_branding_audit_events(tenant_id, actor_user_id, before_state, after_state, reason)
    VALUES (p_tenant_id, v_actor, v_before, v_after, v_reason);
  RETURN pg_catalog.jsonb_build_object('state', 'saved',
    'old_logo_object_path', v_previous.logo_object_path, 'logo_object_path', v_logo_path,
    'tenant_name', COALESCE(v_display_name, v_tenant_name));
END;
$function$;
REVOKE ALL ON FUNCTION public.save_tenant_branding(uuid, text, text, text, boolean, text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.save_tenant_branding(uuid, text, text, text, boolean, text) TO authenticated;
