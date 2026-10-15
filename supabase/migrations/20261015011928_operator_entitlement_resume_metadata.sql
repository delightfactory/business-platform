-- Preserve the allocation that an ordinary OFF/ON must resume. Legacy rows
-- remain unknown; no historical decisions or audit events are rewritten.
ALTER TABLE platform_core.tenant_capability_entitlements
  ADD COLUMN prior_grant_kind text,
  ADD COLUMN prior_grant_until timestamptz,
  ADD CONSTRAINT tenant_entitlement_prior_grant_check CHECK (
    (prior_grant_kind IS NULL AND prior_grant_until IS NULL)
    OR (NOT is_granted AND prior_grant_kind IS NOT NULL AND (
      (prior_grant_kind IN ('none','indefinite') AND prior_grant_until IS NULL)
      OR (prior_grant_kind='finite' AND prior_grant_until IS NOT NULL)
    ))
  );

CREATE FUNCTION platform_private.entitlement_resume(
  p_tenant_id uuid, p_capability_key text, p_at timestamptz
) RETURNS TABLE(kind text, until_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
DECLARE previous platform_core.tenant_capability_entitlements%ROWTYPE;
BEGIN
  SELECT * INTO previous FROM platform_core.tenant_capability_entitlements e
  WHERE e.tenant_id=p_tenant_id AND e.capability_key=p_capability_key
    AND e.valid_from<=p_at ORDER BY e.valid_from DESC LIMIT 1;
  IF NOT FOUND THEN RETURN QUERY SELECT 'first'::text,NULL::timestamptz; RETURN; END IF;

  IF previous.is_granted THEN
    IF previous.valid_until IS NULL THEN kind:='indefinite';
    ELSIF previous.valid_until>p_at THEN kind:='finite'; until_at:=previous.valid_until;
    ELSE kind:='expired'; until_at:=previous.valid_until;
    END IF;
  ELSIF previous.prior_grant_kind='none' THEN kind:='first';
  ELSIF previous.prior_grant_kind='indefinite' THEN kind:='indefinite';
  ELSIF previous.prior_grant_kind='finite' THEN
    until_at:=previous.prior_grant_until;
    kind:=CASE WHEN until_at>p_at THEN 'finite' ELSE 'expired' END;
  ELSIF EXISTS (
    SELECT 1 FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id=p_tenant_id AND e.capability_key=p_capability_key
      AND e.is_granted AND e.valid_from<previous.valid_from
  ) THEN kind:='unknown';
  ELSE kind:='first';
  END IF;
  RETURN NEXT;
END;
$function$;
REVOKE ALL ON FUNCTION platform_private.entitlement_resume(uuid,text,timestamptz)
  FROM PUBLIC,anon,authenticated,service_role;

-- Retain the five-service evaluator and all existing fields. Last-day dates
-- are server-derived, inclusive Cairo dates; clients must not round deadlines.
CREATE OR REPLACE FUNCTION public.platform_tenant_entitlement_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE tenant jsonb; decisions jsonb; now_at timestamptz:=clock_timestamp();
BEGIN
  IF NOT public.current_operator_can_manage_commercial_access() THEN
    RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT jsonb_build_object('tenant_id',id,'display_name',display_name,'lifecycle_state',lifecycle_state)
  INTO tenant FROM platform_core.tenants WHERE id=p_tenant_id;
  IF tenant IS NULL THEN RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE='P0002'; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'capability_key',w.key,
    'status',CASE WHEN c.n>1 THEN 'conflict' WHEN f.n>0 THEN 'future_conflict'
      WHEN c.n=0 THEN 'missing' ELSE 'effective' END,
    'is_granted',c.granted,'valid_from',c.valid_from,'valid_until',c.valid_until,'effective_at',now_at,
    'evaluator_enabled',platform_private.tenant_capability_is_enabled(p_tenant_id,w.key,now_at),
    'last_decision',x.granted,'last_decision_valid_from',x.valid_from,'last_decision_valid_until',x.valid_until,
    'resume_kind',r.kind,'resume_until',r.until_at,
    'resume_last_day',((r.until_at AT TIME ZONE 'Africa/Cairo')-interval '1 microsecond')::date,
    'valid_until_last_day',((c.valid_until AT TIME ZONE 'Africa/Cairo')-interval '1 microsecond')::date
  ) ORDER BY w.key),'[]'::jsonb) INTO decisions
  FROM (VALUES('hr.people'),('hr.payroll'),('hr.attendance'),('hr.leave'),('hr.employee_finance')) w(key)
  LEFT JOIN LATERAL (
    SELECT count(*)::integer n,bool_and(e.is_granted) granted,min(e.valid_from) valid_from,min(e.valid_until) valid_until
    FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key=w.key
      AND e.valid_from<=now_at AND (e.valid_until IS NULL OR e.valid_until>now_at)
  ) c ON true
  LEFT JOIN LATERAL (
    SELECT count(*)::integer n FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id=p_tenant_id AND e.capability_key=w.key AND e.valid_from>now_at
  ) f ON true
  LEFT JOIN LATERAL (
    SELECT e.is_granted granted,e.valid_from,e.valid_until FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id=p_tenant_id AND e.capability_key=w.key AND e.valid_until IS NOT NULL AND e.valid_until<=now_at
    ORDER BY e.valid_until DESC LIMIT 1
  ) x ON true
  LEFT JOIN LATERAL platform_private.entitlement_resume(p_tenant_id,w.key,now_at) r ON true;
  RETURN tenant||jsonb_build_object('entitlements',decisions);
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_tenant_entitlement_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_entitlement_snapshot(uuid) TO authenticated;
