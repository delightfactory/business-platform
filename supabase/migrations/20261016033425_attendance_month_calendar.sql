-- Read saved workday state in one bounded month; never materialize workdays.
CREATE FUNCTION public.attendance_month_calendar(p_tenant_id uuid,p_month date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $f$
DECLARE actor uuid:=auth.uid(); days jsonb;
BEGIN
  IF NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view')
    OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage')
    OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct')
    OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve')
    OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN
    RAISE EXCEPTION 'attendance_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_month IS NULL OR p_month<'2000-01-01'::date OR p_month>'2100-12-01'::date
    OR pg_catalog.date_part('day',p_month::timestamp)<>1 THEN
    RAISE EXCEPTION 'attendance_month_invalid' USING ERRCODE='22023';
  END IF;
  SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(d) ORDER BY d.date),'[]'::jsonb) INTO days
  FROM (
    SELECT i.operational_date AS date,
      pg_catalog.count(*) FILTER(WHERE i.status='open') AS open,
      pg_catalog.count(*) FILTER(WHERE i.status='ready') AS ready,
      pg_catalog.count(*) FILTER(WHERE i.status='needs_review') AS needs_review,
      pg_catalog.count(*) FILTER(WHERE i.status='approved') AS approved
    FROM time.work_instances i
    WHERE i.tenant_id=p_tenant_id AND i.operational_date>=p_month
      AND i.operational_date<(p_month+interval '1 month')::date
    GROUP BY i.operational_date
  ) d;
  RETURN pg_catalog.jsonb_build_object('month',pg_catalog.to_char(p_month,'YYYY-MM'),'days',days);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_month_calendar(uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_month_calendar(uuid,date) TO authenticated;
