ALTER TABLE people.compensation_audit_events DROP CONSTRAINT compensation_audit_events_event_key_check;
ALTER TABLE people.compensation_audit_events ADD CONSTRAINT compensation_audit_events_event_key_check CHECK (event_key IN (
  'compensation.changed','compensation.change_cancelled','compensation.initial_corrected'));
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
CREATE OR REPLACE FUNCTION public.change_people_compensation(p_tenant_id uuid,p_employment_id uuid,p_effective_date date,p_amount numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_employment people.employments%ROWTYPE; v_previous people.compensation_versions%ROWTYPE;
  v_new_id uuid; v_before jsonb; v_after jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'compensation_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR p_employment_id IS NULL OR p_effective_date IS NULL
    OR p_amount IS NULL OR p_amount<0 OR p_amount>999999999999.99 OR p_amount<>pg_catalog.round(p_amount,2) THEN
    RAISE EXCEPTION 'people_compensation_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_employment FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_compensation_employment_not_found' USING ERRCODE='P0002'; END IF;
  IF v_employment.employment_status<>'active' THEN
    RAISE EXCEPTION 'people_compensation_employment_inactive' USING ERRCODE='23514';
  END IF;
  IF p_effective_date<v_employment.start_date THEN RAISE EXCEPTION 'people_compensation_before_employment' USING ERRCODE='23514'; END IF;
  IF v_employment.end_date IS NOT NULL AND p_effective_date>v_employment.end_date THEN
    RAISE EXCEPTION 'people_compensation_after_employment_end' USING ERRCODE='23514';
  END IF;
  IF EXISTS (SELECT 1 FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id AND c.valid_from>v_today) THEN
    RAISE EXCEPTION 'people_compensation_future_exists' USING ERRCODE='23514';
  END IF;
  SELECT * INTO v_previous FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
      AND c.valid_from<=v_today AND (c.valid_until IS NULL OR c.valid_until>v_today)
    ORDER BY c.valid_from DESC,c.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND OR v_previous.valid_until IS NOT NULL THEN
    RAISE EXCEPTION 'people_compensation_current_missing' USING ERRCODE='23514';
  END IF;
  IF p_effective_date=v_today AND v_employment.start_date=v_today AND v_previous.valid_from=v_today
    AND NOT EXISTS (SELECT 1 FROM people.compensation_versions other_version
      WHERE other_version.tenant_id=p_tenant_id AND other_version.employment_id=p_employment_id
        AND other_version.id<>v_previous.id) THEN
    v_before := pg_catalog.jsonb_build_object('id',v_previous.id,'amount',v_previous.amount,
      'currency',v_previous.currency_code,'valid_from',v_previous.valid_from,'valid_until',v_previous.valid_until);
    UPDATE people.compensation_versions SET amount=p_amount WHERE tenant_id=p_tenant_id AND id=v_previous.id;
    v_after := pg_catalog.jsonb_build_object('id',v_previous.id,'amount',p_amount,
      'currency',v_previous.currency_code,'valid_from',v_previous.valid_from,'valid_until',v_previous.valid_until);
    INSERT INTO people.compensation_audit_events(tenant_id,employment_id,actor_user_id,event_key,subject_version_id,details)
      VALUES(p_tenant_id,p_employment_id,v_actor,'compensation.initial_corrected',v_previous.id,
        pg_catalog.jsonb_build_object('before',v_before,'after',v_after));
    RETURN pg_catalog.jsonb_build_object('version_id',v_previous.id,'state','initial_corrected',
      'effective_date',p_effective_date);
  END IF;
  IF p_effective_date<v_today AND p_effective_date<=v_previous.valid_from THEN
    RAISE EXCEPTION 'people_compensation_backdate_outside_current_version' USING ERRCODE='22023';
  END IF;
  IF p_effective_date<=v_previous.valid_from THEN
    RAISE EXCEPTION 'people_compensation_before_current_start' USING ERRCODE='22023';
  END IF;
  v_before := pg_catalog.jsonb_build_object('id',v_previous.id,'amount',v_previous.amount,
    'currency',v_previous.currency_code,'valid_from',v_previous.valid_from,'valid_until',v_previous.valid_until);
  UPDATE people.compensation_versions SET valid_until=p_effective_date
    WHERE tenant_id=p_tenant_id AND id=v_previous.id;
  INSERT INTO people.compensation_versions(tenant_id,employment_id,amount,currency_code,valid_from)
    VALUES(p_tenant_id,p_employment_id,p_amount,'EGP',p_effective_date) RETURNING id INTO v_new_id;
  v_after := pg_catalog.jsonb_build_object('id',v_new_id,'amount',p_amount,'currency','EGP',
    'valid_from',p_effective_date,'valid_until',NULL,'prior_version_id',v_previous.id);
  INSERT INTO people.compensation_audit_events(tenant_id,employment_id,actor_user_id,event_key,subject_version_id,details)
    VALUES(p_tenant_id,p_employment_id,v_actor,'compensation.changed',v_new_id,
      pg_catalog.jsonb_build_object('before',v_before,'after',v_after));
  RETURN pg_catalog.jsonb_build_object('version_id',v_new_id,
    'state',CASE WHEN p_effective_date<v_today THEN 'corrected'
      WHEN p_effective_date=v_today THEN 'changed' ELSE 'scheduled' END,
    'effective_date',p_effective_date);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_people_compensation(uuid,uuid,date,numeric) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_people_compensation(uuid,uuid,date,numeric) TO authenticated;