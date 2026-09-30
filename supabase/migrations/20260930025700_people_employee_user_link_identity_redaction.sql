CREATE OR REPLACE FUNCTION public.people_employee_user_link_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
  v_can_see_identity boolean;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id) THEN
    RAISE EXCEPTION 'people_employee_unavailable' USING ERRCODE='P0002';
  END IF;
  v_can_see_identity := platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage');
  SELECT CASE WHEN v_can_see_identity THEN
    pg_catalog.jsonb_build_object('linked',l.id IS NOT NULL,'identity_visible',true,'link_id',l.id,'user_id',l.user_id,
      'email',u.email,'display_name',COALESCE(NULLIF(pg_catalog.btrim(u.raw_user_meta_data->>'full_name'),''),u.email),
      'linked_at',l.linked_at)
    ELSE pg_catalog.jsonb_build_object('linked',l.id IS NOT NULL,'identity_visible',false) END
    INTO v_result
  FROM (SELECT 1) x
  LEFT JOIN people.employee_user_links l ON l.tenant_id=p_tenant_id AND l.employee_id=p_employee_id AND l.unlinked_at IS NULL
  LEFT JOIN auth.users u ON u.id=l.user_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_user_link_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_user_link_snapshot(uuid,uuid) TO authenticated;
