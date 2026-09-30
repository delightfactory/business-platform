CREATE OR REPLACE FUNCTION public.people_compensation_options(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_employment people.employments%ROWTYPE;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_current people.compensation_versions%ROWTYPE; v_pending people.compensation_versions%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'compensation_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_employment FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_compensation_employment_not_found' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_current FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
      AND c.valid_from<=v_today AND (c.valid_until IS NULL OR c.valid_until>v_today)
    ORDER BY c.valid_from DESC,c.id DESC LIMIT 1;
  SELECT * INTO v_pending FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id AND c.valid_from>v_today
      AND EXISTS (SELECT 1 FROM people.compensation_versions prior_version
        WHERE prior_version.tenant_id=c.tenant_id AND prior_version.employment_id=c.employment_id
          AND prior_version.valid_from<c.valid_from AND prior_version.valid_until=c.valid_from)
    ORDER BY c.valid_from,c.id LIMIT 1;
  RETURN pg_catalog.jsonb_build_object(
    'pay_basis',v_employment.pay_basis,'employment_status',v_employment.employment_status,
    'employment_start',v_employment.start_date,'has_current',v_current.id IS NOT NULL,
    'current_valid_from',v_current.valid_from,
    'effective_date_min',CASE WHEN v_current.id IS NULL THEN NULL
      WHEN v_employment.start_date=v_today AND v_current.valid_from=v_today AND NOT EXISTS (
        SELECT 1 FROM people.compensation_versions prior_version
        WHERE prior_version.tenant_id=p_tenant_id AND prior_version.employment_id=p_employment_id
          AND prior_version.id<>v_current.id) THEN v_today ELSE v_current.valid_from+1 END,
    'effective_date_default',CASE WHEN v_employment.start_date=v_today AND v_current.valid_from=v_today
      AND NOT EXISTS (SELECT 1 FROM people.compensation_versions prior_version
        WHERE prior_version.tenant_id=p_tenant_id AND prior_version.employment_id=p_employment_id
          AND prior_version.id<>v_current.id) THEN v_today
      WHEN v_current.valid_from>=v_today THEN v_current.valid_from+1 ELSE v_today END,
    'pending',CASE WHEN v_pending.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object(
      'id',v_pending.id,'valid_from',v_pending.valid_from) END
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.people_compensation_options(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_compensation_options(uuid,uuid) TO authenticated;