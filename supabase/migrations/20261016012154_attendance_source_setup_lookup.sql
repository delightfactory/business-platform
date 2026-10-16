-- Read-only setup lookup. Includes stopped sources: the unique mobile/site
-- constraint also includes them, so a stopped source must be edited, not replaced.
CREATE FUNCTION public.attendance_channel_mobile_site_lookup(
 p_tenant uuid, p_search text DEFAULT '', p_limit integer DEFAULT 20, p_site uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE result jsonb; pattern text;
BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN
  RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501';
 END IF;
 IF p_search IS NULL OR length(p_search)>100 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 THEN
  RAISE EXCEPTION 'channel_page_invalid' USING ERRCODE='22023';
 END IF;
 pattern := '%' || replace(replace(replace(p_search,'\','\\'),'%','\%'),'_','\_') || '%';
 WITH page AS (
  SELECT s.id,s.display_name FROM platform_core.tenant_sites s
  WHERE s.tenant_id=p_tenant AND s.is_active AND (p_site IS NULL OR s.id=p_site)
   AND s.display_name ILIKE pattern ESCAPE '\'
  ORDER BY s.display_name,s.id LIMIT p_limit+1
 ), limited AS (SELECT * FROM page ORDER BY display_name,id LIMIT p_limit)
 SELECT jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object(
  'id',s.id,'display_name',s.display_name,'source',CASE WHEN c.id IS NULL THEN NULL ELSE
   jsonb_build_object('id',c.id,'name',c.name,'enabled',v.enabled) END
 ) ORDER BY s.display_name,s.id),'[]'::jsonb),'has_more',(SELECT count(*)>p_limit FROM page)) INTO result
 FROM limited s LEFT JOIN time.channel_sources c ON c.tenant_id=p_tenant AND c.site_id=s.id AND c.kind='mobile'
 LEFT JOIN LATERAL (SELECT enabled FROM time.channel_source_versions
  WHERE tenant_id=p_tenant AND source_id=c.id ORDER BY version DESC LIMIT 1) v ON true;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_mobile_site_lookup(uuid,text,integer,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_mobile_site_lookup(uuid,text,integer,uuid) TO authenticated;
