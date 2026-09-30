CREATE OR REPLACE FUNCTION public.people_employee_user_link_options(p_tenant_id uuid,p_employee_id uuid,p_query text DEFAULT '',p_page integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_query text := pg_catalog.left(pg_catalog.btrim(COALESCE(p_query,'')),100);
  v_page integer := LEAST(1000,GREATEST(1,COALESCE(p_page,1))); v_rows jsonb; v_more boolean;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage') THEN
    RAISE EXCEPTION 'people_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id) THEN
    RAISE EXCEPTION 'people_employee_unavailable' USING ERRCODE='P0002';
  END IF;
  WITH candidates AS (
    SELECT m.user_id,u.email,COALESCE(NULLIF(pg_catalog.btrim(u.raw_user_meta_data->>'full_name'),''),u.email) AS display_name
    FROM platform_core.tenant_memberships m JOIN platform_core.tenants t ON t.id=m.tenant_id
    JOIN auth.users u ON u.id=m.user_id
    WHERE m.tenant_id=p_tenant_id AND m.access_state='active' AND t.lifecycle_state='active'
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND NOT EXISTS (SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id
        AND l.user_id=m.user_id AND l.unlinked_at IS NULL)
      AND (v_query='' OR u.email ILIKE '%'||v_query||'%' OR u.raw_user_meta_data->>'full_name' ILIKE '%'||v_query||'%')
    ORDER BY pg_catalog.lower(COALESCE(NULLIF(u.raw_user_meta_data->>'full_name',''),u.email)),m.user_id
    OFFSET (v_page-1)*50 LIMIT 51
  )
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('user_id',user_id,'email',email,'display_name',display_name)
    ORDER BY pg_catalog.lower(display_name),user_id) FILTER (WHERE ordinal<=50),'[]'::jsonb),
    COALESCE(pg_catalog.bool_or(ordinal>50),false)
    INTO v_rows,v_more FROM (SELECT *,pg_catalog.row_number() OVER (ORDER BY pg_catalog.lower(display_name),user_id) ordinal FROM candidates) q;
  RETURN pg_catalog.jsonb_build_object('items',v_rows,'page',v_page,'page_size',50,'has_more',v_more);
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_user_link_options(uuid,uuid,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_user_link_options(uuid,uuid,text,integer) TO authenticated;
