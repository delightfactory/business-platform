-- Close the Leave configuration read permission gap and expose a bounded
-- keyset selector for all legal entities, including inactive historical references.

CREATE OR REPLACE FUNCTION leave.authorized_hr_read(p_tenant uuid)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $f$
DECLARE actor uuid:=auth.uid(); permission text;
BEGIN
  IF platform_private.has_tenant_permission(p_tenant,actor,'leave.view') THEN permission:='leave.view';
  ELSIF platform_private.has_tenant_permission(p_tenant,actor,'leave.manage') THEN permission:='leave.manage';
  ELSIF platform_private.has_tenant_permission(p_tenant,actor,'leave.approve') THEN permission:='leave.approve';
  ELSE permission:='leave.view'; END IF;
  RETURN leave.authorized(p_tenant,permission,false);
END $f$;
REVOKE ALL ON FUNCTION leave.authorized_hr_read(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.leave_configuration_snapshot(p_tenant uuid,p_employer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE out_cal jsonb; out_types jsonb; out_periods jsonb;
BEGIN
  PERFORM leave.authorized_hr_read(p_tenant);
  IF p_employer IS NULL OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant AND e.id=p_employer) THEN
    RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='P0002';
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('calendar_id',c.id,'code',c.code,'name',c.name,'versions',
    (SELECT coalesce(jsonb_agg(jsonb_build_object('id',v.id,'version',v.version,'effective_from',v.effective_from,
      'effective_until',v.effective_until,'timezone',v.timezone,'source',v.source,'rest_weekdays',
      (SELECT coalesce(jsonb_agg(r.weekday ORDER BY r.weekday),'[]'::jsonb) FROM leave.calendar_rest_days r
        WHERE r.tenant_id=v.tenant_id AND r.calendar_version_id=v.id),'holidays',
      (SELECT coalesce(jsonb_agg(jsonb_build_object('date',h.holiday_date,'name',h.name,'source',h.source)
        ORDER BY h.holiday_date),'[]'::jsonb) FROM leave.calendar_holidays h
        WHERE h.tenant_id=v.tenant_id AND h.calendar_version_id=v.id)) ORDER BY v.version DESC),'[]'::jsonb)
      FROM leave.calendar_versions v WHERE v.tenant_id=c.tenant_id AND v.calendar_id=c.id))
      ORDER BY c.code),'[]'::jsonb) INTO out_cal
    FROM leave.calendars c WHERE c.tenant_id=p_tenant AND c.employer_entity_id=p_employer;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'name',t.name,'is_active',t.is_active,
    'versions',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',v.id,'version',v.version,
      'effective_from',v.effective_from,'effective_until',v.effective_until,'pay_effect',v.pay_effect,
      'balance_mode',v.balance_mode,'day_count_basis',v.day_count_basis,'half_day_allowed',v.half_day_allowed,
      'source',v.source) ORDER BY v.version DESC),'[]'::jsonb)
      FROM leave.type_versions v WHERE v.tenant_id=t.tenant_id AND v.leave_type_id=t.id))
      ORDER BY t.code),'[]'::jsonb) INTO out_types
    FROM leave.types t WHERE t.tenant_id=p_tenant AND t.employer_entity_id=p_employer;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'calendar_id',calendar_id,'starts_on',starts_on,
    'ends_on',ends_on,'label',label) ORDER BY starts_on,id),'[]'::jsonb) INTO out_periods
    FROM leave.year_periods WHERE tenant_id=p_tenant AND employer_entity_id=p_employer;
  RETURN jsonb_build_object('calendars',out_cal,'types',out_types,'year_periods',out_periods);
END $f$;
REVOKE ALL ON FUNCTION public.leave_configuration_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_configuration_snapshot(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.leave_configuration_employers(
  p_tenant uuid,p_query text DEFAULT '',p_after_name text DEFAULT NULL,p_after_id uuid DEFAULT NULL,p_limit integer DEFAULT 50
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $f$
DECLARE lim integer:=p_limit; query_text text:=pg_catalog.btrim(p_query); items jsonb; more boolean;
  next_name text; next_id uuid;
BEGIN
  PERFORM leave.authorized_hr_read(p_tenant);
  IF query_text IS NULL OR pg_catalog.length(query_text)>120 OR lim IS NULL OR lim NOT BETWEEN 1 AND 100
    OR ((p_after_name IS NULL)<>(p_after_id IS NULL))
    OR (p_after_name IS NOT NULL AND (pg_catalog.length(p_after_name)>160 OR p_after_name='')) THEN
    RAISE EXCEPTION 'leave_configuration_employers_input_invalid' USING ERRCODE='22023';
  END IF;
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
  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'has_more',more,
    'next_after_name',CASE WHEN more THEN next_name END,'next_after_id',CASE WHEN more THEN next_id END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_configuration_employers(uuid,text,text,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_configuration_employers(uuid,text,text,uuid,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.leave_configuration_employer(p_tenant uuid,p_employer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $f$
DECLARE result jsonb;
BEGIN
  PERFORM leave.authorized_hr_read(p_tenant);
  IF p_employer IS NULL THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='P0002'; END IF;
  SELECT pg_catalog.jsonb_build_object('id',e.id,'display_name',e.display_name,'is_active',e.is_active)
    INTO result FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.id=p_employer;
  IF result IS NULL THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='P0002'; END IF;
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_configuration_employer(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_configuration_employer(uuid,uuid) TO authenticated;

