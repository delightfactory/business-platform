CREATE TABLE people.compensation_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  employment_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN (
    'compensation.changed','compensation.change_cancelled','compensation.initial_corrected')),
  subject_version_id uuid NOT NULL,
  details jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,employment_id) REFERENCES people.employments(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX compensation_audit_employment_idx
  ON people.compensation_audit_events(tenant_id,employment_id,created_at DESC);
ALTER TABLE people.compensation_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.compensation_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE people.compensation_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION people.prevent_compensation_audit_mutation() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'compensation_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER compensation_audit_append_only BEFORE UPDATE OR DELETE ON people.compensation_audit_events
FOR EACH ROW EXECUTE FUNCTION people.prevent_compensation_audit_mutation();
REVOKE ALL ON FUNCTION people.prevent_compensation_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.people_compensation_history(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb; v_pay_basis text;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.view') THEN
    RAISE EXCEPTION 'compensation_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT e.pay_basis INTO v_pay_basis FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'people_compensation_employment_not_found' USING ERRCODE='P0002';
  END IF;
  WITH versions AS (
    SELECT c.*,pg_catalog.row_number() OVER (ORDER BY c.valid_from DESC,c.id DESC) ordinal
    FROM people.compensation_versions c WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
    ORDER BY c.valid_from DESC,c.id DESC LIMIT 101
  )
  SELECT pg_catalog.jsonb_build_object(
    'pay_basis',v_pay_basis,
    'items',COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',v.id,'amount',v.amount,'currency',v.currency_code,'valid_from',v.valid_from,'valid_until',v.valid_until,
      'status',CASE WHEN v.valid_from>v_today THEN 'scheduled'
        WHEN v.valid_until IS NOT NULL AND v.valid_until<=v_today THEN 'past' ELSE 'current' END
    ) ORDER BY v.valid_from DESC,v.id DESC) FILTER (WHERE v.ordinal<=100),'[]'::jsonb),
    'truncated',COALESCE(pg_catalog.bool_or(v.ordinal>100),false)
  ) INTO v_result FROM versions v;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_compensation_history(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_compensation_history(uuid,uuid) TO authenticated;

CREATE FUNCTION public.people_compensation_options(p_tenant_id uuid,p_employment_id uuid)
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

CREATE FUNCTION public.change_people_compensation(p_tenant_id uuid,p_employment_id uuid,p_effective_date date,p_amount numeric)
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

CREATE FUNCTION public.cancel_people_compensation_change(p_tenant_id uuid,p_employment_id uuid,p_version_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_employment people.employments%ROWTYPE; v_pending people.compensation_versions%ROWTYPE;
  v_previous people.compensation_versions%ROWTYPE; v_cancelled jsonb; v_previous_before jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'compensation_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_employment FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_compensation_employment_not_found' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_pending FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id AND c.id=p_version_id AND c.valid_from>v_today
    FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_compensation_not_future' USING ERRCODE='23514'; END IF;
  SELECT * INTO v_previous FROM people.compensation_versions c WHERE c.tenant_id=p_tenant_id
    AND c.employment_id=p_employment_id AND c.valid_until=v_pending.valid_from AND c.valid_from<v_pending.valid_from
    ORDER BY c.valid_from DESC,c.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_compensation_previous_not_found' USING ERRCODE='23514'; END IF;
  v_cancelled := pg_catalog.jsonb_build_object('id',v_pending.id,'amount',v_pending.amount,
    'currency',v_pending.currency_code,'valid_from',v_pending.valid_from,'valid_until',v_pending.valid_until);
  v_previous_before := pg_catalog.jsonb_build_object('id',v_previous.id,'valid_until',v_previous.valid_until);
  DELETE FROM people.compensation_versions WHERE tenant_id=p_tenant_id AND id=v_pending.id;
  UPDATE people.compensation_versions SET valid_until=NULL WHERE tenant_id=p_tenant_id AND id=v_previous.id;
  INSERT INTO people.compensation_audit_events(tenant_id,employment_id,actor_user_id,event_key,subject_version_id,details)
    VALUES(p_tenant_id,p_employment_id,v_actor,'compensation.change_cancelled',v_pending.id,
      pg_catalog.jsonb_build_object('cancelled',v_cancelled,'restored',v_previous_before || pg_catalog.jsonb_build_object('valid_until',NULL)));
  RETURN pg_catalog.jsonb_build_object('version_id',v_pending.id,'restored_version_id',v_previous.id,'state','cancelled');
END;
$function$;
REVOKE ALL ON FUNCTION public.cancel_people_compensation_change(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_people_compensation_change(uuid,uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.people_compensation_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
  v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.view') THEN
    RAISE EXCEPTION 'compensation_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object('amount',c.amount,'currency',c.currency_code,
    'valid_from',c.valid_from,'valid_until',c.valid_until,'pay_basis',emp.pay_basis)
  INTO v_result FROM people.employees e
  JOIN LATERAL (SELECT * FROM people.employments x WHERE x.tenant_id=e.tenant_id AND x.employee_id=e.id
    ORDER BY x.start_date DESC LIMIT 1) emp ON true
  JOIN LATERAL (SELECT * FROM people.compensation_versions x WHERE x.tenant_id=emp.tenant_id
    AND x.employment_id=emp.id AND x.valid_from<=v_today AND (x.valid_until IS NULL OR x.valid_until>v_today)
    ORDER BY x.valid_from DESC,x.id DESC LIMIT 1) c ON true
  WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_compensation_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_compensation_snapshot(uuid,uuid) TO authenticated;
