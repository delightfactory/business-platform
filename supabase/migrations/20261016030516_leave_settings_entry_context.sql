-- Additive leave setup entry context; preserve read authorization and historical entities.
CREATE OR REPLACE FUNCTION public.leave_configuration_employers(
  p_tenant uuid,p_query text DEFAULT '',p_after_name text DEFAULT NULL,p_after_id uuid DEFAULT NULL,p_limit integer DEFAULT 50
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $f$
DECLARE lim integer:=p_limit; query_text text:=pg_catalog.btrim(p_query); items jsonb; more boolean;
  next_name text; next_id uuid; unique_id uuid;
BEGIN
  PERFORM leave.authorized_hr_read(p_tenant);
  IF query_text IS NULL OR pg_catalog.length(query_text)>120 OR lim IS NULL OR lim NOT BETWEEN 1 AND 100
    OR ((p_after_name IS NULL)<>(p_after_id IS NULL))
    OR (p_after_name IS NOT NULL AND (pg_catalog.length(p_after_name)>160 OR p_after_name='')) THEN
    RAISE EXCEPTION 'leave_configuration_employers_input_invalid' USING ERRCODE='22023';
  END IF;
  -- Global uniqueness is independent of search, cursor and active status.
  SELECT CASE WHEN pg_catalog.count(*)=1 THEN (pg_catalog.array_agg(e.id))[1] END INTO unique_id
  FROM (SELECT id FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant LIMIT 2) e;
  WITH page AS MATERIALIZED (
    SELECT e.id,e.display_name,e.is_active
    FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant
      AND (query_text='' OR pg_catalog.strpos(pg_catalog.lower(e.display_name),pg_catalog.lower(query_text))>0)
      AND (p_after_name IS NULL OR (e.display_name,e.id)>(p_after_name,p_after_id))
    ORDER BY e.display_name,e.id LIMIT lim+1
  ), numbered AS MATERIALIZED (
    SELECT p.*,pg_catalog.row_number() OVER(ORDER BY p.display_name,p.id) rn FROM page p
  )
  SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',id,'display_name',display_name,'is_active',is_active)
      ORDER BY rn) FILTER(WHERE rn<=lim),'[]'::jsonb),
    EXISTS(SELECT 1 FROM numbered WHERE rn>lim),
    (SELECT display_name FROM numbered WHERE rn=lim),(SELECT id FROM numbered WHERE rn=lim)
  INTO items,more,next_name,next_id FROM numbered;
  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'has_more',more,'unique_employer',unique_id,
    'next_after_name',CASE WHEN more THEN next_name END,'next_after_id',CASE WHEN more THEN next_id END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_configuration_employers(uuid,text,text,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_configuration_employers(uuid,text,text,uuid,integer) TO authenticated;
