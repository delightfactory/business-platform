-- Routine commercial limits use explicit provenance and an optional note.
-- The legacy reason-required command remains unchanged and compatible.
ALTER TABLE platform_core.tenant_capability_limit_audit_events
  ADD COLUMN change_source text NOT NULL DEFAULT 'legacy_rpc_reason',
  ADD COLUMN operator_note text,
  DROP CONSTRAINT tenant_capability_limit_audit_events_reason_check,
  ALTER COLUMN reason DROP NOT NULL,
  ADD CONSTRAINT tenant_limit_audit_source_check CHECK (
    (change_source='legacy_rpc_reason' AND coalesce(nullif(btrim(reason),''),'')<>'' AND length(reason)<=500)
    OR (change_source='operator_limit_editor' AND reason IS NULL)
  ),
  ADD CONSTRAINT tenant_limit_audit_note_check CHECK (
    operator_note IS NULL OR (btrim(operator_note)<>'' AND length(operator_note)<=500)
  );

CREATE FUNCTION public.set_tenant_capability_limit(
  p_tenant_id uuid, p_capability_key text, p_limit_key text,
  p_limit_mode text, p_limit_value integer,
  p_expected_valid_from timestamptz, p_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  actor uuid:=auth.uid(); now_at timestamptz; rows_n integer; usage_n integer;
  old_row platform_core.tenant_capability_limits%ROWTYPE;
  before_state jsonb; after_state jsonb; outcome text:='changed';
  note text:=nullif(btrim(p_note),''); over_capacity boolean;
BEGIN
  IF p_tenant_id IS NULL OR p_capability_key IS NULL OR p_limit_key IS NULL
    OR NOT ((p_capability_key='tenant.users' AND p_limit_key='max_users')
      OR (p_capability_key='tenant.sites' AND p_limit_key='max_sites')) THEN
    RAISE EXCEPTION 'commercial_limit_key_invalid' USING ERRCODE='22023';
  END IF;
  IF p_limit_mode IS NULL OR p_limit_mode NOT IN ('limited','unlimited')
    OR (p_limit_mode='limited' AND (p_limit_value IS NULL OR p_limit_value<=0))
    OR (p_limit_mode='unlimited' AND p_limit_value IS NOT NULL) THEN
    RAISE EXCEPTION 'commercial_limit_value_invalid' USING ERRCODE='22023';
  END IF;
  IF length(note)>500 THEN RAISE EXCEPTION 'commercial_limit_note_invalid' USING ERRCODE='22023'; END IF;
  IF actor IS NULL OR NOT public.current_operator_can_manage_commercial_access() THEN
    RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant_id::text,90427));
  IF NOT public.current_operator_can_manage_commercial_access() THEN
    RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM platform_core.tenants WHERE id=p_tenant_id) THEN
    RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE='P0002';
  END IF;
  now_at:=clock_timestamp();
  IF EXISTS(SELECT 1 FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key=p_capability_key
      AND l.limit_key=p_limit_key AND l.valid_from>now_at) THEN
    RAISE EXCEPTION 'commercial_limit_future_conflict' USING ERRCODE='23P01';
  END IF;
  SELECT count(*)::integer INTO rows_n FROM platform_core.tenant_capability_limits l
  WHERE l.tenant_id=p_tenant_id AND l.capability_key=p_capability_key AND l.limit_key=p_limit_key
    AND l.valid_from<=now_at AND (l.valid_until IS NULL OR l.valid_until>now_at);
  IF rows_n>1 THEN RAISE EXCEPTION 'commercial_limit_conflict' USING ERRCODE='55000'; END IF;
  IF rows_n=1 THEN
    SELECT * INTO old_row FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key=p_capability_key AND l.limit_key=p_limit_key
      AND l.valid_from<=now_at AND (l.valid_until IS NULL OR l.valid_until>now_at) FOR UPDATE;
  END IF;
  IF p_capability_key='tenant.users' THEN
    SELECT count(*)::integer INTO usage_n FROM platform_core.tenant_memberships
    WHERE tenant_id=p_tenant_id AND access_state='active';
  ELSE
    SELECT count(*)::integer INTO usage_n FROM platform_core.tenant_sites
    WHERE tenant_id=p_tenant_id AND is_active;
  END IF;

  -- Matching desired state is honest reconciliation, not attempt attribution.
  IF rows_n=1 AND old_row.limit_mode=p_limit_mode AND old_row.limit_value IS NOT DISTINCT FROM p_limit_value THEN
    outcome:='unchanged';
  ELSIF old_row.valid_from IS DISTINCT FROM p_expected_valid_from THEN outcome:='stale';
  END IF;
  IF outcome='changed' THEN
    IF rows_n=1 THEN
      before_state:=jsonb_build_object('mode',old_row.limit_mode,'value',old_row.limit_value,
        'valid_from',old_row.valid_from,'valid_until',old_row.valid_until,'usage',usage_n);
      UPDATE platform_core.tenant_capability_limits SET valid_until=now_at
      WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND limit_key=p_limit_key
        AND valid_from=old_row.valid_from;
    END IF;
    INSERT INTO platform_core.tenant_capability_limits
      (tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
    VALUES(p_tenant_id,p_capability_key,p_limit_key,p_limit_mode,p_limit_value,now_at,actor,
      'operator_commercial_access:limit_editor');
    after_state:=jsonb_build_object('mode',p_limit_mode,'value',p_limit_value,
      'valid_from',now_at,'valid_until',NULL,'usage',usage_n);
    INSERT INTO platform_core.tenant_capability_limit_audit_events
      (tenant_id,actor_user_id,capability_key,limit_key,effective_at,before_state,after_state,reason,change_source,operator_note)
    VALUES(p_tenant_id,actor,p_capability_key,p_limit_key,now_at,before_state,after_state,NULL,'operator_limit_editor',note);
  END IF;
  over_capacity:=CASE WHEN outcome='stale' THEN
    coalesce(old_row.limit_mode='limited' AND usage_n>old_row.limit_value,false)
    ELSE p_limit_mode='limited' AND usage_n>p_limit_value END;
  RETURN jsonb_build_object('outcome',outcome,'usage',usage_n,'over_capacity',over_capacity,
    'snapshot',public.platform_tenant_commercial_snapshot(p_tenant_id));
END;
$function$;
REVOKE ALL ON FUNCTION public.set_tenant_capability_limit(uuid,text,text,text,integer,timestamptz,text)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.set_tenant_capability_limit(uuid,text,text,text,integer,timestamptz,text) TO authenticated;
