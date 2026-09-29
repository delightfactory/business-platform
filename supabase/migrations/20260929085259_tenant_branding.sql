-- Private Tenant-scoped branding assets; Storage API remains the only object API.
INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES ('tenant-branding', 'tenant-branding', false, 2097152, ARRAY['image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  public = false,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE TABLE platform_core.tenant_branding (
  tenant_id uuid PRIMARY KEY REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  display_name text CHECK (display_name IS NULL OR (pg_catalog.btrim(display_name) <> '' AND pg_catalog.length(display_name) <= 160)),
  primary_color_key text NOT NULL DEFAULT 'teal' CHECK (primary_color_key IN ('teal', 'blue', 'violet', 'emerald')),
  logo_object_path text,
  updated_by_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
ALTER TABLE platform_core.tenant_branding ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_branding FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE platform_core.tenant_branding_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  before_state jsonb,
  after_state jsonb NOT NULL,
  reason text NOT NULL CHECK (pg_catalog.btrim(reason) <> '' AND pg_catalog.length(reason) <= 500),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
ALTER TABLE platform_core.tenant_branding_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_branding_audit_events FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION platform_core.prevent_tenant_branding_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $function$
BEGIN RAISE EXCEPTION 'tenant_branding_audit_append_only' USING ERRCODE = '55000'; END;
$function$;
CREATE TRIGGER tenant_branding_audit_append_only
BEFORE UPDATE OR DELETE ON platform_core.tenant_branding_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_branding_audit_mutation();
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_branding_audit_mutation() FROM PUBLIC, anon, authenticated, service_role;

-- Storage RLS invokes this narrow current-user helper; read is membership-scoped,
-- while every write requires the Tenant's existing protected Admin permission.
CREATE FUNCTION public.tenant_branding_storage_allowed(p_tenant_id_text text, p_for_write boolean)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_tenant_id uuid; v_actor uuid := (SELECT auth.uid());
BEGIN
  IF v_actor IS NULL OR p_for_write IS NULL
    OR p_tenant_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    RETURN false;
  END IF;
  BEGIN
    v_tenant_id := p_tenant_id_text::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN false;
  END;
  IF p_for_write THEN
    RETURN platform_private.has_tenant_permission(v_tenant_id, v_actor, 'tenant.administer');
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM platform_core.tenants t
    JOIN platform_core.tenant_memberships m ON m.tenant_id = t.id
    JOIN auth.users u ON u.id = m.user_id
    WHERE t.id = v_tenant_id AND t.lifecycle_state = 'active'
      AND m.user_id = v_actor AND m.access_state = 'active'
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until <= pg_catalog.now())
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_branding_storage_allowed(text, boolean) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.tenant_branding_storage_allowed(text, boolean) TO authenticated;

CREATE POLICY tenant_branding_object_read ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'tenant-branding'
  AND (storage.foldername(name))[1] = 'tenants'
  AND public.tenant_branding_storage_allowed((storage.foldername(name))[2], false)
);
CREATE POLICY tenant_branding_object_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'tenant-branding'
  AND (storage.foldername(name))[1] = 'tenants'
  AND (storage.foldername(name))[3] = 'logos'
  AND public.tenant_branding_storage_allowed((storage.foldername(name))[2], true)
  AND name ~ '^tenants/[0-9a-f-]{36}/logos/[0-9a-f-]{36}\.(png|jpg|webp)$'
);
CREATE FUNCTION public.tenant_branding_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_result jsonb;
BEGIN
  SELECT pg_catalog.jsonb_build_object(
    'tenant_id', t.id,
    'tenant_name', COALESCE(b.display_name, t.display_name),
    'display_name_override', b.display_name,
    'primary_color_key', COALESCE(b.primary_color_key, 'teal'),
    'logo_object_path', b.logo_object_path,
    'can_manage_branding', platform_private.has_tenant_permission(t.id, (SELECT auth.uid()), 'tenant.administer')
  ) INTO v_result
  FROM platform_core.tenants t
  JOIN platform_core.tenant_memberships m ON m.tenant_id = t.id
  JOIN auth.users u ON u.id = m.user_id
  LEFT JOIN platform_core.tenant_branding b ON b.tenant_id = t.id
  WHERE t.id = p_tenant_id AND t.lifecycle_state = 'active'
    AND m.user_id = (SELECT auth.uid()) AND m.access_state = 'active'
    AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until <= pg_catalog.now());
  IF v_result IS NULL THEN RAISE EXCEPTION 'tenant_branding_unavailable' USING ERRCODE = '42501'; END IF;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_branding_snapshot(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.tenant_branding_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.save_tenant_branding(
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
  IF p_tenant_id IS NULL OR v_color IS NULL OR v_color NOT IN ('teal', 'blue', 'violet', 'emerald') OR p_remove_logo IS NULL
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
