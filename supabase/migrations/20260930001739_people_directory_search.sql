-- A bounded directory query keeps workforce growth from loading every employee at once.
CREATE FUNCTION public.people_directory_page(p_tenant_id uuid,p_query text DEFAULT NULL,p_page integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid());
  v_query text := COALESCE(pg_catalog.btrim(p_query),'');
  v_items jsonb; v_has_more boolean;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF pg_catalog.length(v_query)>100 OR p_page IS NULL OR p_page NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'people_directory_query_invalid' USING ERRCODE='22023';
  END IF;
  WITH page_keys AS (
    SELECT e.id,e.full_name
    FROM people.employees e
    WHERE e.tenant_id=p_tenant_id
      AND (v_query='' OR pg_catalog.strpos(pg_catalog.lower(e.employee_code),pg_catalog.lower(v_query))>0
        OR pg_catalog.strpos(pg_catalog.lower(e.full_name),pg_catalog.lower(v_query))>0)
    ORDER BY e.full_name,e.id
    LIMIT 26 OFFSET (p_page-1)*25
  ), numbered AS (
    SELECT k.id,k.full_name,pg_catalog.row_number() OVER (ORDER BY k.full_name,k.id) AS ordinal
    FROM page_keys k
  )
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',e.id,'code',e.employee_code,'name',e.full_name,
      'status',CASE WHEN e.workforce_status='active' AND emp.start_date>v_today
        THEN 'scheduled' ELSE e.workforce_status END,
      'employer',le.display_name,'site',s.display_name,'start_date',emp.start_date
    ) ORDER BY e.full_name,e.id) FILTER (WHERE n.ordinal<=25),'[]'::jsonb),
    COALESCE(pg_catalog.bool_or(n.ordinal>25),false)
    INTO v_items,v_has_more
  FROM numbered n
  JOIN people.employees e ON e.tenant_id=p_tenant_id AND e.id=n.id
  LEFT JOIN LATERAL (SELECT * FROM people.employments current_emp
    WHERE current_emp.tenant_id=e.tenant_id AND current_emp.employee_id=e.id
      AND current_emp.employment_status='active'
    ORDER BY current_emp.start_date DESC LIMIT 1) emp ON true
  LEFT JOIN platform_core.tenant_legal_entities le
    ON le.tenant_id=emp.tenant_id AND le.id=emp.employer_entity_id
  LEFT JOIN LATERAL (SELECT * FROM people.work_assignments a
    WHERE a.tenant_id=emp.tenant_id AND a.employment_id=emp.id
      AND a.valid_from<=v_today AND (a.valid_until IS NULL OR a.valid_until>v_today)
    ORDER BY a.valid_from DESC LIMIT 1) assignment ON true
  LEFT JOIN platform_core.tenant_sites s
    ON s.tenant_id=assignment.tenant_id AND s.id=assignment.site_id;
  RETURN pg_catalog.jsonb_build_object('items',v_items,'has_more',v_has_more,'page',p_page);
END;
$function$;
REVOKE ALL ON FUNCTION public.people_directory_page(uuid,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_directory_page(uuid,text,integer) TO authenticated;
