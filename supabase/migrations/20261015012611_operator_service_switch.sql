ALTER TABLE platform_core.tenant_capability_entitlements
  ADD COLUMN change_source text NOT NULL DEFAULT 'legacy_rpc_reason',
  ADD COLUMN operator_note text,
  ADD COLUMN plan_id uuid,
  ALTER COLUMN reason DROP NOT NULL,
  DROP CONSTRAINT tenant_capability_entitlements_reason_check,
  ADD CONSTRAINT tenant_entitlement_reason_source_check CHECK (
    (change_source='legacy_rpc_reason' AND coalesce(nullif(btrim(reason),''),'')<>'' AND length(reason)<=500)
    OR (change_source IN ('operator_switch','operator_plan') AND reason IS NULL AND plan_id IS NOT NULL)
  ),
  ADD CONSTRAINT tenant_entitlement_note_check CHECK (
    operator_note IS NULL OR (btrim(operator_note)<>'' AND length(operator_note)<=500)
  );
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events
  ADD COLUMN change_source text NOT NULL DEFAULT 'legacy_rpc_reason',
  ADD COLUMN operator_note text,
  ADD COLUMN plan_id uuid,
  ALTER COLUMN reason DROP NOT NULL,
  DROP CONSTRAINT tenant_capability_entitlement_audit_events_reason_check,
  ADD CONSTRAINT tenant_entitlement_audit_reason_source_check CHECK (
    (change_source='legacy_rpc_reason' AND coalesce(nullif(btrim(reason),''),'')<>'' AND length(reason)<=500)
    OR (change_source IN ('operator_switch','operator_plan') AND reason IS NULL AND plan_id IS NOT NULL)
  ),
  ADD CONSTRAINT tenant_entitlement_audit_note_check CHECK (
    operator_note IS NULL OR (btrim(operator_note)<>'' AND length(operator_note)<=500)
  );

CREATE FUNCTION public.set_tenant_capability_entitlements(
  p_tenant_id uuid, p_changes jsonb, p_expected jsonb, p_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  keys constant text[]:=ARRAY['hr.people','hr.payroll','hr.attendance','hr.leave','hr.employee_finance'];
  children constant text[]:=ARRAY['hr.payroll','hr.leave','hr.employee_finance'];
  actor uuid:=auth.uid(); now_at timestamptz; note text:=nullif(btrim(p_note),'');
  key text; item jsonb; state jsonb; wanted jsonb; parent jsonb; resume record;
  current_states jsonb:='{}'; requested jsonb:='{}'; plan jsonb:='{}'; public_plan jsonb;
  expiry timestamptz; parent_until timestamptz; granted boolean; duration text;
  rows_n integer; future_n integer; current_from timestamptz; current_until timestamptz;
  current_granted boolean; any_granted boolean; dependencies boolean:=false;
  plan_differs boolean:=false; all_match boolean:=true; stale boolean:=false; derived boolean;
  operation_id uuid; source text; before_state jsonb; after_state jsonb; changed jsonb:='[]';
  prior_kind text; prior_until timestamptz;
BEGIN
  IF p_tenant_id IS NULL OR jsonb_typeof(p_changes) IS DISTINCT FROM 'array'
    OR jsonb_typeof(p_expected) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
  END IF;
  IF jsonb_array_length(p_changes) NOT BETWEEN 1 AND 5
    OR (SELECT count(*) FROM jsonb_object_keys(p_expected))<>5 THEN
    RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
  END IF;
  FOREACH key IN ARRAY keys LOOP
    item:=p_expected->key;
    IF jsonb_typeof(item) IS DISTINCT FROM 'object' OR NOT (item ?& ARRAY['valid_from','is_granted'])
      OR jsonb_typeof(item->'valid_from') NOT IN ('string','null')
      OR jsonb_typeof(item->'is_granted') NOT IN ('boolean','null')
      OR ((item->>'valid_from' IS NULL)<>(item->>'is_granted' IS NULL)) THEN
      RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
    END IF;
    IF item->>'valid_from' IS NOT NULL AND NOT isfinite((item->>'valid_from')::timestamptz) THEN
      RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
    END IF;
  END LOOP;
  FOR item IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
    key:=item->>'capability_key'; duration:=item->>'duration';
    IF jsonb_typeof(item) IS DISTINCT FROM 'object' OR key IS NULL OR NOT key=ANY(keys)
      OR requested ? key OR jsonb_typeof(item->'is_granted') IS DISTINCT FROM 'boolean'
      OR duration IS NULL OR duration NOT IN ('resume','indefinite','last_day','exact')
      OR (duration='resume' AND NOT (item->>'is_granted')::boolean)
      OR (duration<>'last_day' AND item->>'last_day' IS NOT NULL)
      OR (duration<>'exact' AND item->>'valid_until' IS NOT NULL) THEN
      RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
    END IF;
    IF duration='last_day' AND (jsonb_typeof(item->'last_day') IS DISTINCT FROM 'string'
      OR item->>'last_day' !~ '^\d{4}-\d{2}-\d{2}$' OR NOT isfinite((item->>'last_day')::date)) THEN
      RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
    END IF;
    IF duration='exact' AND (NOT item ? 'valid_until'
      OR jsonb_typeof(item->'valid_until') NOT IN ('string','null')) THEN
      RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
    END IF;
    requested:=jsonb_set(requested,ARRAY[key],item);
    dependencies:=dependencies OR key='hr.people' OR key=ANY(children);
  END LOOP;
  IF length(note)>500 THEN RAISE EXCEPTION 'tenant_entitlement_note_invalid' USING ERRCODE='22023'; END IF;
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
  FOREACH key IN ARRAY keys LOOP
    SELECT count(*)::integer,bool_and(e.is_granted),bool_or(e.is_granted),min(e.valid_from),min(e.valid_until)
      INTO rows_n,current_granted,any_granted,current_from,current_until
    FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key=key
      AND e.valid_from<=now_at AND (e.valid_until IS NULL OR e.valid_until>now_at);
    SELECT count(*)::integer INTO future_n FROM platform_core.tenant_capability_entitlements e
    WHERE e.tenant_id=p_tenant_id AND e.capability_key=key AND e.valid_from>now_at;
    SELECT * INTO resume FROM platform_private.entitlement_resume(p_tenant_id,key,now_at);
    state:=jsonb_build_object('n',rows_n,'future_n',future_n,'is_granted',current_granted,
      'any_granted',any_granted,'valid_from',current_from,'valid_until',current_until,
      'resume_kind',resume.kind,'resume_until',resume.until_at);
    current_states:=jsonb_set(current_states,ARRAY[key],state);
    -- A corrupt direct input/parent cannot be used to derive a duration or plan.
    IF requested ? key OR key='hr.people' THEN
      IF future_n>0 THEN RAISE EXCEPTION 'tenant_entitlement_future_conflict' USING ERRCODE='23P01'; END IF;
      IF rows_n>1 THEN RAISE EXCEPTION 'tenant_entitlement_conflict' USING ERRCODE='55000'; END IF;
    END IF;
  END LOOP;

  -- People is resolved first. Exact timestamps are restricted to current,
  -- resumable or parent-derived instants, never an arbitrary browser timestamp.
  FOREACH key IN ARRAY keys LOOP
    IF NOT requested ? key THEN CONTINUE; END IF;
    item:=requested->key; state:=current_states->key;
    granted:=(item->>'is_granted')::boolean; duration:=item->>'duration'; expiry:=NULL;
    IF duration='last_day' THEN expiry:=(((item->>'last_day')::date+1)::timestamp AT TIME ZONE 'Africa/Cairo');
    ELSIF duration='resume' THEN
      IF state->>'resume_kind' IN ('expired','unknown') THEN
        RETURN jsonb_build_object('outcome','duration_required','capability_key',key,
          'snapshot',public.platform_tenant_entitlement_snapshot(p_tenant_id));
      END IF;
      expiry:=(state->>'resume_until')::timestamptz;
      IF key=ANY(children) AND state->>'resume_kind'='first' THEN
        parent:=coalesce(plan->'hr.people',current_states->'hr.people');
        IF coalesce((parent->>'is_granted')::boolean,false) THEN expiry:=(parent->>'valid_until')::timestamptz; END IF;
      END IF;
    ELSIF duration='exact' THEN
      expiry:=(item->>'valid_until')::timestamptz;
      parent:=coalesce(plan->'hr.people',current_states->'hr.people');
      IF NOT coalesce((
        ((state->>'n')::integer=1 AND granted=(state->>'is_granted')::boolean
          AND expiry IS NOT DISTINCT FROM (state->>'valid_until')::timestamptz)
        OR (granted AND state->>'resume_kind'='finite' AND expiry=(state->>'resume_until')::timestamptz)
        OR (granted AND state->>'resume_kind' IN ('first','indefinite') AND expiry IS NULL)
        OR (NOT granted AND expiry IS NULL)
        OR (granted AND key=ANY(children) AND (parent->>'valid_until') IS NOT NULL
          AND coalesce((parent->>'is_granted')::boolean,false)
          AND expiry IS NOT DISTINCT FROM (parent->>'valid_until')::timestamptz)
      ),false) THEN RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023'; END IF;
    END IF;
    IF expiry IS NOT NULL AND (NOT isfinite(expiry) OR expiry<=now_at) THEN
      RAISE EXCEPTION 'tenant_entitlement_expiry_invalid' USING ERRCODE='22023';
    END IF;
    wanted:=jsonb_build_object('capability_key',key,'is_granted',granted,'valid_until',expiry,
      'duration',duration,'last_day',item->>'last_day');
    plan:=jsonb_set(plan,ARRAY[key],wanted);
  END LOOP;
  -- Store the normalized intent so a shortened deadline needs fresh approval.
  requested:=plan;
  IF dependencies THEN
    parent:=coalesce(plan->'hr.people',current_states->'hr.people');
    IF NOT plan ? 'hr.people' AND NOT coalesce((parent->>'is_granted')::boolean,false)
      AND EXISTS(SELECT 1 FROM jsonb_each(plan) p WHERE p.key=ANY(children) AND (p.value->>'is_granted')::boolean) THEN
      state:=current_states->'hr.people';
      IF state->>'resume_kind' IN ('expired','unknown') THEN
        RETURN jsonb_build_object('outcome','duration_required','capability_key','hr.people',
          'snapshot',public.platform_tenant_entitlement_snapshot(p_tenant_id));
      END IF;
      parent:=jsonb_build_object('capability_key','hr.people','is_granted',true,
        'valid_until',(state->>'resume_until')::timestamptz,'duration','exact');
      plan:=jsonb_set(plan,ARRAY['hr.people'],parent);
    END IF;
    parent_until:=(parent->>'valid_until')::timestamptz;
    FOREACH key IN ARRAY children LOOP
      IF plan ? 'hr.people' AND (current_states->key->>'n')::integer>1
        AND coalesce((current_states->key->>'any_granted')::boolean,false) THEN
        RAISE EXCEPTION 'tenant_entitlement_conflict' USING ERRCODE='55000';
      END IF;
      wanted:=coalesce(plan->key,current_states->key);
      IF NOT coalesce((parent->>'is_granted')::boolean,false) THEN
        IF coalesce((wanted->>'is_granted')::boolean,false)
          OR (NOT plan ? key AND coalesce((wanted->>'any_granted')::boolean,false)) THEN
          plan:=jsonb_set(plan,ARRAY[key],jsonb_build_object('capability_key',key,'is_granted',false,
            'valid_until',NULL,'duration','exact'));
        END IF;
      ELSIF coalesce((wanted->>'is_granted')::boolean,false) AND parent_until IS NOT NULL
        AND ((wanted->>'valid_until') IS NULL OR (wanted->>'valid_until')::timestamptz>parent_until) THEN
        plan:=jsonb_set(plan,ARRAY[key],jsonb_build_object('capability_key',key,'is_granted',true,
          'valid_until',parent_until,'duration','exact'));
      END IF;
    END LOOP;
  END IF;

  -- Check every finally affected key, including dependency-derived siblings.
  FOREACH key IN ARRAY keys LOOP
    IF NOT plan ? key AND key<>'hr.people' THEN CONTINUE; END IF;
    state:=current_states->key;
    IF (state->>'future_n')::integer>0 THEN RAISE EXCEPTION 'tenant_entitlement_future_conflict' USING ERRCODE='23P01'; END IF;
    IF (state->>'n')::integer>1 THEN RAISE EXCEPTION 'tenant_entitlement_conflict' USING ERRCODE='55000'; END IF;
    stale:=stale OR (state->>'valid_from')::timestamptz IS DISTINCT FROM (p_expected->key->>'valid_from')::timestamptz
      OR (state->>'is_granted')::boolean IS DISTINCT FROM (p_expected->key->>'is_granted')::boolean;
    IF NOT plan ? key THEN CONTINUE; END IF;
    wanted:=plan->key;
    derived:=NOT requested ? key OR (wanted->>'is_granted')::boolean IS DISTINCT FROM (requested->key->>'is_granted')::boolean
      OR (wanted->>'valid_until')::timestamptz IS DISTINCT FROM (requested->key->>'valid_until')::timestamptz;
    plan_differs:=plan_differs OR derived;
    all_match:=all_match AND (state->>'n')::integer=1
      AND (wanted->>'is_granted')::boolean IS NOT DISTINCT FROM (state->>'is_granted')::boolean
      AND (wanted->>'valid_until')::timestamptz IS NOT DISTINCT FROM (state->>'valid_until')::timestamptz;
    plan:=jsonb_set(plan,ARRAY[key],wanted||jsonb_build_object('derived',derived,
      'last_day',(((wanted->>'valid_until')::timestamptz AT TIME ZONE 'Africa/Cairo')-interval '1 microsecond')::date));
  END LOOP;
  IF all_match AND NOT plan_differs THEN
    RETURN jsonb_build_object('outcome','unchanged','snapshot',public.platform_tenant_entitlement_snapshot(p_tenant_id));
  END IF;
  IF stale THEN RETURN jsonb_build_object('outcome','stale','snapshot',public.platform_tenant_entitlement_snapshot(p_tenant_id)); END IF;
  SELECT jsonb_agg(p.value ORDER BY p.key) INTO public_plan FROM jsonb_each(plan) p;
  IF plan_differs THEN RETURN jsonb_build_object('outcome','plan_required','plan',public_plan,
    'snapshot',public.platform_tenant_entitlement_snapshot(p_tenant_id)); END IF;

  operation_id:=gen_random_uuid();
  source:=CASE WHEN jsonb_array_length(public_plan)>1 THEN 'operator_plan' ELSE 'operator_switch' END;
  FOR item IN SELECT value FROM jsonb_array_elements(public_plan)
    ORDER BY CASE WHEN NOT (value->>'is_granted')::boolean AND value->>'capability_key'=ANY(children) THEN 0
      WHEN value->>'capability_key'='hr.people' THEN 1 ELSE 2 END,value->>'capability_key' LOOP
    key:=item->>'capability_key'; state:=current_states->key;
    granted:=(item->>'is_granted')::boolean; expiry:=(item->>'valid_until')::timestamptz;
    IF (state->>'n')::integer=1 AND granted IS NOT DISTINCT FROM (state->>'is_granted')::boolean
      AND expiry IS NOT DISTINCT FROM (state->>'valid_until')::timestamptz THEN CONTINUE; END IF;
    prior_kind:=NULL; prior_until:=NULL; before_state:=NULL;
    IF NOT granted THEN
      prior_kind:=CASE state->>'resume_kind' WHEN 'first' THEN 'none' WHEN 'indefinite' THEN 'indefinite'
        WHEN 'finite' THEN 'finite' WHEN 'expired' THEN 'finite' ELSE NULL END;
      IF prior_kind='finite' THEN prior_until:=(state->>'resume_until')::timestamptz; END IF;
    END IF;
    IF (state->>'n')::integer=1 THEN
      PERFORM 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id
        AND e.capability_key=key AND e.valid_from=(state->>'valid_from')::timestamptz FOR UPDATE;
      before_state:=jsonb_build_object('is_granted',(state->>'is_granted')::boolean,
        'valid_from',(state->>'valid_from')::timestamptz,'valid_until',(state->>'valid_until')::timestamptz);
      UPDATE platform_core.tenant_capability_entitlements SET valid_until=now_at
      WHERE tenant_id=p_tenant_id AND capability_key=key AND valid_from=(state->>'valid_from')::timestamptz;
    END IF;
    INSERT INTO platform_core.tenant_capability_entitlements
      (tenant_id,capability_key,is_granted,valid_from,valid_until,actor_user_id,reason,change_source,
        operator_note,plan_id,prior_grant_kind,prior_grant_until)
    VALUES(p_tenant_id,key,granted,now_at,expiry,actor,NULL,source,note,operation_id,prior_kind,prior_until);
    after_state:=jsonb_build_object('is_granted',granted,'valid_from',now_at,'valid_until',expiry);
    INSERT INTO platform_core.tenant_capability_entitlement_audit_events
      (tenant_id,actor_user_id,capability_key,effective_at,before_state,after_state,reason,change_source,operator_note,plan_id)
    VALUES(p_tenant_id,actor,key,now_at,before_state,after_state,NULL,source,note,operation_id);
    changed:=changed||jsonb_build_array(jsonb_build_object('capability_key',key,'before',before_state,'after',after_state));
  END LOOP;
  RETURN jsonb_build_object('outcome','changed','plan_id',operation_id,'effective_at',now_at,'changed',changed,
    'snapshot',public.platform_tenant_entitlement_snapshot(p_tenant_id));
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN
  RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023';
END;
$function$;
REVOKE ALL ON FUNCTION public.set_tenant_capability_entitlements(uuid,jsonb,jsonb,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.set_tenant_capability_entitlements(uuid,jsonb,jsonb,text) TO authenticated;
