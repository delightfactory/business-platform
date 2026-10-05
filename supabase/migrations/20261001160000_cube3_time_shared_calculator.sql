-- Cube 3 shared interpretation calculators.
-- Bounded extraction: the existing private writer and the A2.1 Leave trigger now
-- delegate to two side-effect-free helpers. Observable Time/Leave behavior, the
-- authoritative input fingerprint, permissions and every write path stay intact.

CREATE FUNCTION "time".calculate_interpretation_values(
  p_instance jsonb,p_policy jsonb,p_effective_punches jsonb,p_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 inst "time".work_instances%ROWTYPE;
 n integer; ni integer; no integer; fin timestamptz; fout timestamptz;
 st text; exc text;
 gross_minutes integer; net_minutes integer; late_n integer; early_n integer;
 scheduled_break integer; applied_break integer;
 break_start time; break_end time;
 break_start_local timestamp; break_end_local timestamp; shift_start_local timestamp;
 break_start_at timestamptz; break_end_at timestamptz;
 overlap_seconds numeric; policy_found boolean;
 required_key text;
BEGIN
 -- Server callers supply the complete normalized punch set and the frozen policy
 -- matching this instance's tenant/template/version, or NULL for a missing row.
 -- Structurally bad inputs are rejected instead of being read as empty evidence.
 IF p_instance IS NULL OR jsonb_typeof(p_instance)<>'object'
    OR p_effective_punches IS NULL OR jsonb_typeof(p_effective_punches)<>'array'
    OR p_at IS NULL THEN
  RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
 END IF;
 FOREACH required_key IN ARRAY ARRAY['schedule_kind','operational_date','timezone_name',
   'expected_start','expected_end','attribution_start','attribution_end','required_minutes',
   'break_minutes','lateness_grace_minutes','early_leave_grace_minutes'] LOOP
  IF p_instance->required_key IS NULL THEN
   RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
  END IF;
 END LOOP;
 IF p_instance->>'schedule_kind' IS NULL OR p_instance->>'schedule_kind' NOT IN('fixed','flexible') THEN
  RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
 END IF;
 FOREACH required_key IN ARRAY ARRAY['operational_date','timezone_name','break_minutes',
   'lateness_grace_minutes','early_leave_grace_minutes'] LOOP
  IF p_instance->>required_key IS NULL THEN
   RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
  END IF;
 END LOOP;
 IF p_policy IS NOT NULL AND (jsonb_typeof(p_policy)<>'object'
    OR p_policy->'fixed_break_start' IS NULL OR p_policy->'fixed_break_end' IS NULL) THEN
  RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
 END IF;
 IF EXISTS(
   SELECT 1 FROM jsonb_array_elements(p_effective_punches) x(value)
   WHERE jsonb_typeof(x.value)<>'object'
      OR x.value->>'id' IS NULL
      OR x.value->>'direction' IS NULL OR x.value->>'direction' NOT IN('in','out')
      OR x.value->>'happened_at' IS NULL) THEN
  RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
 END IF;
 IF EXISTS(
   SELECT 1 FROM jsonb_array_elements(p_effective_punches) x(value)
   WHERE (x.value->>'id')::uuid IS NULL OR (x.value->>'happened_at')::timestamptz IS NULL) THEN
  RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
 END IF;

 inst:=jsonb_populate_record(NULL::"time".work_instances,p_instance);

 SELECT count(*),count(*) FILTER(WHERE x.value->>'direction'='in'),
        count(*) FILTER(WHERE x.value->>'direction'='out'),
        min((x.value->>'happened_at')::timestamptz) FILTER(WHERE x.value->>'direction'='in'),
        max((x.value->>'happened_at')::timestamptz) FILTER(WHERE x.value->>'direction'='out')
 INTO n,ni,no,fin,fout
 FROM jsonb_array_elements(p_effective_punches) x(value);

 st:='open'; exc:=NULL; gross_minutes:=NULL; net_minutes:=NULL;
 late_n:=NULL; early_n:=NULL;
 scheduled_break:=inst.break_minutes;
 applied_break:=inst.break_minutes; -- preserves legacy aggregate-break behavior

 policy_found:=p_policy IS NOT NULL;
 IF policy_found THEN
  break_start:=(p_policy->>'fixed_break_start')::time;
  break_end:=(p_policy->>'fixed_break_end')::time;
 END IF;

 IF inst.attribution_start IS NULL OR inst.attribution_end IS NULL
    OR (inst.schedule_kind='fixed' AND
        (inst.expected_start IS NULL OR inst.expected_end IS NULL)) THEN
  st:='needs_review'; exc:='ambiguous_local_time';
 ELSIF n>2 OR ni>1 OR no>1 THEN
  st:='needs_review'; exc:='conflicting_punches';
 ELSIF ni=1 AND no=1 THEN
  IF fin>=fout OR fin<inst.attribution_start OR fout>inst.attribution_end THEN
   st:='needs_review'; exc:='outside_window';
  ELSE
   gross_minutes:=greatest(0,(extract(epoch FROM(fout-fin))/60)::int);

   -- A fixed break with an explicit immutable placement is interpreted against
   -- the Work Instance's frozen policy version and local operational date.
   -- Missing placement retains the preexisting full-break subtraction.
   IF inst.schedule_kind='fixed' AND inst.break_minutes>0
      AND (break_start IS NOT NULL OR break_end IS NOT NULL) THEN
    IF NOT policy_found OR break_start IS NULL OR break_end IS NULL
       OR inst.timezone_name IS NULL
       OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names z
                     WHERE z.name=inst.timezone_name) THEN
      st:='needs_review'; exc:='break_placement_invalid';
    ELSE
      shift_start_local:=inst.expected_start AT TIME ZONE inst.timezone_name;
      break_start_local:=inst.operational_date+break_start;
      WHILE break_start_local<shift_start_local LOOP
        break_start_local:=break_start_local+interval '1 day';
      END LOOP;
      break_end_local:=inst.operational_date+break_end;
      WHILE break_end_local<=break_start_local LOOP
        break_end_local:=break_end_local+interval '1 day';
      END LOOP;
      break_start_at:="time".resolve_local(break_start_local,inst.timezone_name);
      break_end_at:="time".resolve_local(break_end_local,inst.timezone_name);

      IF break_start_at IS NULL OR break_end_at IS NULL
         OR break_end_at<=break_start_at
         OR break_start_at<inst.expected_start
         OR break_end_at>inst.expected_end
         OR mod(extract(epoch FROM (break_end_at-break_start_at)),60)<>0
         OR extract(epoch FROM (break_end_at-break_start_at))/60<>inst.break_minutes THEN
        st:='needs_review'; exc:='break_placement_invalid';
      ELSE
        overlap_seconds:=greatest(
          0::numeric,
          extract(epoch FROM (least(fout,break_end_at)-greatest(fin,break_start_at)))
        );
        -- Match the interpreter's established elapsed-minute cast: fractional
        -- minutes round to integer minutes; do not reject second-resolution punches.
        applied_break:=(overlap_seconds/60)::integer;
      END IF;
    END IF;
   ELSIF inst.schedule_kind='fixed' AND inst.break_minutes=0
      AND policy_found AND (break_start IS NOT NULL OR break_end IS NOT NULL) THEN
     st:='needs_review'; exc:='break_placement_invalid';
   END IF;

   IF st='open' THEN
    st:='ready';
    net_minutes:=greatest(0,gross_minutes-applied_break);
    IF inst.schedule_kind='fixed' THEN
     late_n:=greatest(0,(extract(epoch FROM(fin-inst.expected_start))/60)::int-inst.lateness_grace_minutes);
     early_n:=greatest(0,(extract(epoch FROM(inst.expected_end-fout))/60)::int-inst.early_leave_grace_minutes);
    ELSIF net_minutes<inst.required_minutes THEN
     exc:='short_workday';
    END IF;
   END IF;
  END IF;
 ELSIF p_at>inst.attribution_end THEN
  st:='needs_review'; exc:=CASE WHEN n=0 THEN 'absence_candidate' ELSE 'missing_punch' END;
 END IF;

 RETURN jsonb_build_object(
  'state',st,
  'exception_code',exc,
  'owner_permission',
    CASE WHEN exc='short_workday' THEN 'attendance.approve'
         WHEN st='needs_review' THEN
           CASE WHEN exc='absence_candidate' THEN 'attendance.approve'
                ELSE 'attendance.correct' END END,
  'first_in',fin,
  'last_out',fout,
  'gross_worked_minutes',gross_minutes,
  'worked_minutes',net_minutes,
  'late_minutes',late_n,
  'early_leave_minutes',early_n,
  'scheduled_break_minutes',scheduled_break,
  'applied_break_minutes',
    CASE WHEN gross_minutes IS NULL OR exc='break_placement_invalid' THEN NULL ELSE applied_break END
 );
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow
   OR numeric_value_out_of_range THEN
 RAISE EXCEPTION 'calculate_interpretation_values_invalid_input' USING ERRCODE='22023';
END $f$;
REVOKE ALL ON FUNCTION "time".calculate_interpretation_values(jsonb,jsonb,jsonb,timestamptz)
 FROM PUBLIC,anon,authenticated,service_role;

-- A2.1 compatibility proof, extracted from the BEFORE INSERT Leave snapshot trigger.
CREATE FUNCTION "time".apply_leave_context_to_interpretation(
  p_value "time".interpretations,p_instance "time".work_instances,
  p_policy "time".work_policy_versions,p_context jsonb,p_attendance_enabled boolean
) RETURNS "time".interpretations LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 v_value "time".interpretations%ROWTYPE;
 source jsonb; snapshot jsonb; mapping jsonb;
 n_sources integer; total_units numeric; kind text;
 threshold integer; half_break integer; observed_break_seconds numeric;
 excused_seconds numeric; covered_seconds numeric; envelope_seconds numeric;
 missing_before numeric; missing_after numeric; p_start timestamptz; p_end timestamptz;
BEGIN
 -- Policy identity is a trusted server-reader precondition, as in the writer's
 -- exact tenant/template/version lookup; preview readers must enforce it too.
 IF p_attendance_enabled IS NULL OR p_context IS NULL
    OR jsonb_typeof(p_context) IS DISTINCT FROM 'array'
    OR p_value.state IS NULL OR p_instance.schedule_kind IS NULL THEN
  RAISE EXCEPTION 'apply_leave_context_invalid_input' USING ERRCODE='22023';
 END IF;
 v_value:=p_value;
 -- Preserve Leave-only/Attendance-off behavior. Enabling Attendance later changes the
 -- shared input fingerprint and the next interpretation must explicitly review it.
 IF NOT p_attendance_enabled THEN
  v_value.leave_evidence:='[]'::jsonb; v_value.leave_units:=0; v_value.leave_compatibility_state:='none';
  RETURN v_value;
 END IF;
 v_value.leave_evidence:=p_context;
 SELECT count(*)::integer,coalesce(sum((x.value->>'units')::numeric),0)
  INTO n_sources,total_units FROM jsonb_array_elements(p_context) x(value);
 v_value.leave_units:=total_units;
 v_value.leave_compatibility_state:='none';
 IF n_sources=0 THEN RETURN v_value; END IF;
 v_value.leave_compatibility_state:='review_required';
 IF total_units>=1 OR n_sources<>1 OR total_units<>0.5 THEN
  v_value.leave_compatibility_state:='full_coverage';
  v_value.state:='needs_review'; v_value.owner_permission:='attendance.correct';
  v_value.exception_code:='leave_full_date_covered';
  RETURN v_value;
 END IF;
 -- Leave cannot resolve an independent punch/window/break exception. Preserve its
 -- original recovery diagnostic and owner; only valid ready observations can be
 -- evaluated against the approved half-day obligation below.
 IF v_value.state IS DISTINCT FROM 'ready' AND v_value.exception_code IS NOT NULL THEN
  RETURN v_value;
 END IF;
 v_value.state:='needs_review';
 v_value.owner_permission:='attendance.correct';
 v_value.exception_code:='leave_mapping_review_required';
 source:=p_context->0;
 IF (source->>'is_half_day')::boolean IS DISTINCT FROM true
    OR source->>'mapping_state' IS DISTINCT FROM 'mapped'
    OR source->>'policy_template_id' IS DISTINCT FROM p_instance.policy_template_id::text
    OR source->>'policy_version' IS DISTINCT FROM p_instance.policy_version::text
    OR source->>'algorithm_version' IS DISTINCT FROM 'leave-halfday-v1' THEN
  RETURN v_value;
 END IF;
 snapshot:=source->'mapping_snapshot';
 mapping:=snapshot->'mapping';
 kind:=mapping->>'schedule_kind';
 IF kind='fixed' THEN
  IF source->>'half_day_part' NOT IN ('first','second')
     OR jsonb_typeof(mapping->'excused_intervals') IS DISTINCT FROM 'array'
     OR jsonb_typeof(mapping->'remaining_intervals') IS DISTINCT FROM 'array'
     OR jsonb_typeof(mapping->'break_interval') IS DISTINCT FROM 'array'
     OR v_value.first_in IS NULL OR v_value.last_out IS NULL OR v_value.gross_worked_minutes IS NULL THEN
   RETURN v_value;
  END IF;
  p_start:=v_value.first_in; p_end:=v_value.last_out;
  envelope_seconds:=extract(epoch FROM (p_end-p_start));
  IF envelope_seconds<=0 THEN RETURN v_value; END IF;
  SELECT coalesce(sum(greatest(0,extract(epoch FROM
     (least(p_end,(x.value->>'end_at')::timestamptz)-greatest(p_start,(x.value->>'start_at')::timestamptz))))),0)
    INTO excused_seconds FROM jsonb_array_elements(mapping->'excused_intervals') x(value);
  SELECT coalesce(sum(greatest(0,extract(epoch FROM
     (least(p_end,(x.value->>'end_at')::timestamptz)-greatest(p_start,(x.value->>'start_at')::timestamptz))))),0)
    INTO covered_seconds
    FROM jsonb_array_elements((mapping->'remaining_intervals')||(mapping->'break_interval')) x(value);
  SELECT coalesce(sum(greatest(0,extract(epoch FROM
     (least(p_end,(x.value->>'end_at')::timestamptz)-greatest(p_start,(x.value->>'start_at')::timestamptz))))),0)
    INTO observed_break_seconds FROM jsonb_array_elements(mapping->'break_interval') x(value);
  -- An approved fixed half-day only excuses its stored spans. The actual punch
  -- envelope must be fully covered by remaining-work spans plus the configured break.
  IF excused_seconds<>0 OR covered_seconds<>envelope_seconds
     OR v_value.applied_break_minutes IS DISTINCT FROM (observed_break_seconds/60)::integer
     OR v_value.worked_minutes IS DISTINCT FROM greatest(0,v_value.gross_worked_minutes-v_value.applied_break_minutes) THEN
   RETURN v_value;
  END IF;
  SELECT coalesce(sum(greatest(0,extract(epoch FROM
     (least(p_start,(x.value->>'end_at')::timestamptz)-(x.value->>'start_at')::timestamptz)))),0)
    INTO missing_before FROM jsonb_array_elements(mapping->'remaining_intervals') x(value);
  SELECT coalesce(sum(greatest(0,extract(epoch FROM
     ((x.value->>'end_at')::timestamptz-greatest(p_end,(x.value->>'start_at')::timestamptz))))),0)
    INTO missing_after FROM jsonb_array_elements(mapping->'remaining_intervals') x(value);
  v_value.late_minutes:=greatest(0,(missing_before/60)::integer-p_instance.lateness_grace_minutes);
  v_value.early_leave_minutes:=greatest(0,(missing_after/60)::integer-p_instance.early_leave_grace_minutes);
  v_value.leave_compatibility_state:='compatible';
  v_value.state:='ready'; v_value.exception_code:=NULL; v_value.owner_permission:=NULL;
  RETURN v_value;
 ELSIF kind='flexible' THEN
  IF source->>'half_day_part' IS NOT NULL OR v_value.gross_worked_minutes IS NULL
     OR mapping->>'state' IS DISTINCT FROM 'mapped'
     OR source->>'policy_template_id' IS NULL OR source->>'policy_version' IS NULL THEN
   RETURN v_value;
  END IF;
  IF p_policy IS NULL OR p_policy.tenant_id IS NULL
     OR p_policy.schedule_kind IS DISTINCT FROM 'flexible'
     OR p_policy.required_minutes IS NULL
     OR p_policy.flexible_halfday_break_minutes IS NULL THEN
   RETURN v_value;
  END IF;
  threshold:=p_policy.required_minutes; half_break:=p_policy.flexible_halfday_break_minutes;
  IF mapping->>'remaining_net_threshold_minutes' IS DISTINCT FROM ((threshold+1)/2)::text
     OR mapping->>'halfday_break_minutes' IS DISTINCT FROM half_break::text THEN
   RETURN v_value;
  END IF;
  -- Flexible schedules have no clock part/break interval: use only the explicit
  -- immutable half-day break deduction, never half of the full-day aggregate.
  v_value.applied_break_minutes:=half_break;
  v_value.worked_minutes:=greatest(0,v_value.gross_worked_minutes-half_break);
  IF v_value.worked_minutes<(threshold+1)/2 THEN
   v_value.exception_code:='leave_remaining_half_threshold_not_met';
   v_value.owner_permission:='attendance.correct';
   RETURN v_value;
  END IF;
  v_value.leave_compatibility_state:='compatible';
  v_value.state:='ready'; v_value.exception_code:=NULL; v_value.owner_permission:=NULL;
  RETURN v_value;
 END IF;
 RETURN v_value;
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow
   OR numeric_value_out_of_range THEN
 v_value.leave_compatibility_state:='review_required'; v_value.state:='needs_review';
 v_value.exception_code:='leave_mapping_review_required'; v_value.owner_permission:='attendance.correct';
 RETURN v_value;
END $f$;
REVOKE ALL ON FUNCTION "time".apply_leave_context_to_interpretation(
  "time".interpretations,"time".work_instances,"time".work_policy_versions,jsonb,boolean)
 FROM PUBLIC,anon,authenticated,service_role;

-- Existing private writer: same lock, punch normalization, fingerprint and writes.
CREATE OR REPLACE FUNCTION "time".interpret_work_instance(p_tenant uuid,p_instance uuid,p_actor uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 wi "time".work_instances%ROWTYPE;
 policy "time".work_policy_versions%ROWTYPE;
 policy_found boolean;
 policy_json jsonb;
 punches jsonb; base jsonb; interp_values "time".interpretations;
 ver integer; interp uuid; fp text;
BEGIN
 SELECT * INTO wi FROM "time".work_instances
 WHERE tenant_id=p_tenant AND id=p_instance FOR UPDATE;
 IF NOT FOUND THEN
  RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002';
 END IF;

 WITH active AS (
  SELECT p.id,coalesce(c.new_direction,p.direction) d,
         coalesce(c.new_happened_at,p.happened_at) at
  FROM "time".manual_punches p
  LEFT JOIN LATERAL(
   SELECT q.* FROM "time".punch_corrections q
   WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id
   ORDER BY q.created_at DESC,q.id DESC LIMIT 1
  ) c ON c.action='replace'
  WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance
    AND NOT EXISTS(
      SELECT 1 FROM "time".punch_corrections q
      WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id AND q.action='exclude'
    )
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'direction',d,'happened_at',at) ORDER BY id),'[]'::jsonb)
 INTO punches FROM active;

 SELECT * INTO policy FROM "time".work_policy_versions v
  WHERE v.tenant_id=wi.tenant_id AND v.template_id=wi.policy_template_id AND v.version=wi.policy_version;
 policy_found:=FOUND;
 IF policy_found THEN policy_json:=to_jsonb(policy); END IF;

 base:="time".calculate_interpretation_values(to_jsonb(wi),policy_json,punches,pg_catalog.now());
 interp_values:=jsonb_populate_record(NULL::"time".interpretations,base);

 SELECT coalesce(max(version),0)+1 INTO ver
 FROM "time".interpretations
 WHERE tenant_id=p_tenant AND work_instance_id=p_instance;

 fp:="time".work_instance_interpretation_fingerprint(p_tenant,p_instance);

 INSERT INTO "time".interpretations(
   tenant_id,work_instance_id,version,state,first_in,last_out,worked_minutes,
   exception_code,owner_permission,input_fingerprint,created_by,
   gross_worked_minutes,late_minutes,early_leave_minutes,
   scheduled_break_minutes,applied_break_minutes
 )
 VALUES(
   p_tenant,p_instance,ver,interp_values.state,interp_values.first_in,interp_values.last_out,
   interp_values.worked_minutes,interp_values.exception_code,interp_values.owner_permission,
   fp,p_actor,interp_values.gross_worked_minutes,interp_values.late_minutes,
   interp_values.early_leave_minutes,interp_values.scheduled_break_minutes,
   interp_values.applied_break_minutes
 ) RETURNING id INTO interp;

 -- The trailing status uses the local pre-Leave-snapshot state; the existing
 -- AFTER Leave sync trigger reconciles it when approved Leave evidence exists.
 UPDATE "time".work_instances
 SET status=CASE WHEN EXISTS(
   SELECT 1 FROM "time".attendance_facts f
   WHERE f.tenant_id=p_tenant AND f.work_instance_id=p_instance
 ) THEN 'needs_review' ELSE interp_values.state END
 WHERE tenant_id=p_tenant AND id=p_instance;
 RETURN interp;
END $f$;
REVOKE ALL ON FUNCTION "time".interpret_work_instance(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

-- Existing A2.1 trigger: still owns the Leave context read, the Attendance
-- capability gate and the Work Instance/policy reads, then delegates.
CREATE OR REPLACE FUNCTION "time".snapshot_approved_leave_on_interpretation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi "time".work_instances%ROWTYPE; policy "time".work_policy_versions%ROWTYPE;
  context jsonb; attendance_enabled boolean;
BEGIN
 SELECT * INTO wi FROM "time".work_instances WHERE tenant_id=NEW.tenant_id AND id=NEW.work_instance_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 context:=platform_private.approved_leave_context(NEW.tenant_id,NEW.work_instance_id);
 attendance_enabled:=platform_private.tenant_capability_is_enabled(NEW.tenant_id,'hr.attendance',pg_catalog.now());
 SELECT * INTO policy FROM "time".work_policy_versions v
  WHERE v.tenant_id=NEW.tenant_id AND v.template_id=wi.policy_template_id AND v.version=wi.policy_version;
 NEW:="time".apply_leave_context_to_interpretation(NEW,wi,policy,context,attendance_enabled);
 RETURN NEW;
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow
   OR numeric_value_out_of_range THEN
 NEW.leave_compatibility_state:='review_required'; NEW.state:='needs_review';
 NEW.exception_code:='leave_mapping_review_required'; NEW.owner_permission:='attendance.correct';
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION "time".snapshot_approved_leave_on_interpretation()
 FROM PUBLIC,anon,authenticated,service_role;
