-- Explicit nominal-day classification for reviewed Time facts. No writer or
-- public approval route is introduced here; the next writer consumes this seam.
-- The expanded canonical source deliberately invalidates older input fingerprints.
CREATE FUNCTION platform_private.approved_leave_classification_context(p_tenant uuid,p_instance uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'tenant_id',r.tenant_id,'request_id',r.id,'employee_id',r.employee_id,'employment_id',r.employment_id,
  'employer_entity_id',d.employer_entity_id,'approved_preview_version',r.approved_preview_version,
  'leave_date',d.leave_date,'leave_type_id',r.leave_type_id,'is_half_day',r.is_half_day,
  'half_day_part',d.half_day_part,'units',d.units,'pay_effect',d.pay_effect,'reference_only',true,
  'type_version_id',d.type_version_id,'calendar_version_id',d.calendar_version_id,
  'mapping_state',d.halfday_mapping_state,'mapping_snapshot',d.halfday_mapping_snapshot,
  'policy_template_id',d.halfday_policy_template_id,'policy_version',d.halfday_policy_version,
  'algorithm_version',d.halfday_algorithm_version
 ) ORDER BY r.id,d.leave_date),'[]'::jsonb)
 FROM "time".work_instances i
 JOIN people.employments e ON e.tenant_id=i.tenant_id AND e.id=i.employment_id AND e.employee_id=i.employee_id
 JOIN leave.requests r ON r.tenant_id=i.tenant_id AND r.employee_id=i.employee_id
  AND r.employment_id=i.employment_id AND r.employer_entity_id=e.employer_entity_id
  AND r.state='approved' AND r.approved_preview_version IS NOT NULL AND r.cancelled_at IS NULL
 JOIN leave.request_days d ON d.tenant_id=r.tenant_id AND d.request_id=r.id
  AND d.preview_version=r.approved_preview_version AND d.employer_entity_id=r.employer_entity_id
 WHERE i.tenant_id=p_tenant AND i.id=p_instance AND d.leave_date=i.operational_date AND d.eligible AND d.units>0
$f$;
REVOKE ALL ON FUNCTION platform_private.approved_leave_classification_context(uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

-- Established Attendance readers serialize this limited source shape. Richer
-- frozen metadata stays private until the reviewed-fact API applies Leave visibility.
CREATE OR REPLACE FUNCTION platform_private.approved_leave_context(p_tenant uuid,p_instance uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT coalesce(jsonb_agg(value-ARRAY['tenant_id','employer_entity_id','pay_effect','reference_only']
  ORDER BY value->>'request_id',value->>'leave_date'),'[]'::jsonb)
 FROM jsonb_array_elements(platform_private.approved_leave_classification_context(p_tenant,p_instance))
$f$;
REVOKE ALL ON FUNCTION platform_private.approved_leave_context(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$
DECLARE source text; anchor text:='platform_private.approved_leave_context(p_tenant,p_instance)::text';
BEGIN
 source:=pg_get_functiondef('"time".work_instance_interpretation_fingerprint(uuid,uuid)'::regprocedure);
 IF (length(source)-length(replace(source,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'attendance_classification_fingerprint_anchor_mismatch';
 END IF;
 EXECUTE replace(source,anchor,'platform_private.approved_leave_classification_context(p_tenant,p_instance)::text');
END $patch$;
REVOKE ALL ON FUNCTION "time".work_instance_interpretation_fingerprint(uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION "time".classify_attendance_values(
 p_instance jsonb,p_policy jsonb,p_effective_punches jsonb,p_context jsonb,
 p_employer uuid,p_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 base jsonb; observation jsonb; result jsonb; source jsonb; expected jsonb; stored jsonb;
 context_units numeric:=0; n_sources integer; n_punches integer; n_half integer:=0;
 parts text[]:=ARRAY[]::text[]; diagnostics jsonb; context_valid boolean:=true;
 mapping_keys text[]:=ARRAY['state','schedule_kind','part','excused_intervals','remaining_intervals',
  'break_interval','required_minutes','remaining_net_threshold_minutes','halfday_break_minutes',
  'scheduled_net_minutes','first_part_minutes','second_part_minutes'];
 wi "time".work_instances%ROWTYPE; policy "time".work_policy_versions%ROWTYPE;
BEGIN
 -- The server reader supplies exact frozen WI/policy identities, scoped Employer,
 -- canonical effective punches and approved (or prospective reviewed) day sources.
 IF p_context IS NULL OR jsonb_typeof(p_context) IS DISTINCT FROM 'array' OR p_employer IS NULL THEN
  RAISE EXCEPTION 'attendance_classification_invalid_input' USING ERRCODE='22023';
 END IF;
 base:="time".calculate_interpretation_values(p_instance,p_policy,p_effective_punches,p_at);
 wi:=jsonb_populate_record(NULL::"time".work_instances,p_instance);
 IF wi.tenant_id IS NULL OR wi.employee_id IS NULL OR wi.employment_id IS NULL THEN
  RAISE EXCEPTION 'attendance_classification_invalid_input' USING ERRCODE='22023';
 END IF;
 observation:=base;
 diagnostics:=CASE WHEN base->>'exception_code' IS NULL THEN '[]'::jsonb
  ELSE jsonb_build_array(base->>'exception_code') END;
 n_sources:=jsonb_array_length(p_context); n_punches:=jsonb_array_length(p_effective_punches);
 result:=jsonb_build_object('version',1,'kind','review_required','absence_units',NULL,
  'leave_units',0,'leave_sources',p_context,'context_hash',md5(p_context::text),
  'observations',base,'evaluated_observations',base,'diagnostics',diagnostics,'approval_eligible',false);

 IF n_sources>2 THEN context_valid:=false; END IF;
 FOR source IN SELECT value FROM jsonb_array_elements(p_context) LOOP
  IF jsonb_typeof(source) IS DISTINCT FROM 'object'
   OR source->>'tenant_id' IS DISTINCT FROM wi.tenant_id::text
   OR source->>'employee_id' IS DISTINCT FROM wi.employee_id::text
   OR source->>'employment_id' IS DISTINCT FROM wi.employment_id::text
   OR source->>'employer_entity_id' IS DISTINCT FROM p_employer::text
   OR source->>'leave_date' IS DISTINCT FROM wi.operational_date::text
   OR source->>'request_id' IS NULL OR source->>'type_version_id' IS NULL
   OR source->>'calendar_version_id' IS NULL OR source->>'approved_preview_version' IS NULL
   OR (source->>'approved_preview_version')::integer<1
   OR source->>'pay_effect' IS NULL OR source->>'pay_effect' NOT IN('paid','unpaid')
   OR (source->>'reference_only')::boolean IS DISTINCT FROM true
   OR source->>'units' IS NULL OR (source->>'units')::numeric NOT IN(0.5,1)
   OR (source->>'is_half_day')::boolean IS DISTINCT FROM ((source->>'units')::numeric=0.5) THEN
   context_valid:=false; CONTINUE;
  END IF;
  PERFORM (source->>'request_id')::uuid,(source->>'type_version_id')::uuid,(source->>'calendar_version_id')::uuid;
  context_units:=context_units+(source->>'units')::numeric;
  IF (source->>'units')::numeric=0.5 THEN
   n_half:=n_half+1;
   IF p_policy IS NULL OR source->>'mapping_state' IS DISTINCT FROM 'mapped'
    OR source->>'policy_template_id' IS DISTINCT FROM wi.policy_template_id::text
    OR source->>'policy_version' IS DISTINCT FROM wi.policy_version::text
    OR source->>'algorithm_version' IS DISTINCT FROM 'leave-halfday-v1' THEN
    context_valid:=false; CONTINUE;
   END IF;
   expected:="time".leave_halfday_mapping(p_policy||jsonb_build_object(
    'policy_template_id',wi.policy_template_id,'policy_version',wi.policy_version),wi.operational_date,source->>'half_day_part');
   stored:=source->'mapping_snapshot'->'mapping';
   -- Reusing the qualified constructor proves exact disjoint complementary spans,
   -- including odd-minute allocation/DST. Never infer full coverage from sum alone.
   IF expected->>'state' IS DISTINCT FROM 'mapped' OR jsonb_typeof(stored) IS DISTINCT FROM 'object'
    OR (SELECT jsonb_object_agg(key,value) FROM jsonb_each(expected) WHERE key=ANY(mapping_keys))
       IS DISTINCT FROM
       (SELECT jsonb_object_agg(key,value) FROM jsonb_each(coalesce(stored,'{}')) WHERE key=ANY(mapping_keys)) THEN
    context_valid:=false;
   END IF;
   parts:=array_append(parts,source->>'half_day_part');
  END IF;
 END LOOP;
 IF (SELECT count(DISTINCT value->>'request_id') FROM jsonb_array_elements(p_context))<>n_sources
  OR context_units>1 OR (n_sources=2 AND (n_half<>2 OR wi.schedule_kind<>'fixed'
   OR parts IS DISTINCT FROM ARRAY['first','second'] AND parts IS DISTINCT FROM ARRAY['second','first'])) THEN
  context_valid:=false;
 END IF;
 result:=result||jsonb_build_object('leave_units',context_units);
 IF NOT context_valid THEN
  RETURN result||jsonb_build_object('diagnostics',diagnostics||'"leave_coverage_source_review_required"'::jsonb);
 END IF;

 -- Independent observation errors survive even a fully excused nominal day.
 IF base->>'exception_code'='ambiguous_local_time' OR
  (n_punches>0 AND base->>'state' IS DISTINCT FROM 'ready') THEN
  RETURN result||jsonb_build_object('diagnostics',CASE WHEN diagnostics='[]'::jsonb
   THEN '["incomplete_observations"]'::jsonb ELSE diagnostics END);
 END IF;
 IF n_punches=0 AND base->>'exception_code' IS DISTINCT FROM 'absence_candidate' THEN
  RETURN result||jsonb_build_object('diagnostics','["awaiting_observation_window"]'::jsonb);
 END IF;
 IF context_units=1 THEN
  IF n_punches>0 THEN diagnostics:=diagnostics||'"observed_work_during_excused"'::jsonb; END IF;
  RETURN result||jsonb_build_object('kind','leave_covered','absence_units',0,
   'diagnostics',diagnostics,'approval_eligible',true);
 ELSIF n_punches=0 THEN
  RETURN result||jsonb_build_object('kind','absence','absence_units',1-context_units,'approval_eligible',true);
 END IF;
 IF context_units=0.5 THEN
  policy:=jsonb_populate_record(NULL::"time".work_policy_versions,p_policy);
  observation:=to_jsonb("time".apply_leave_context_to_interpretation(
   jsonb_populate_record(NULL::"time".interpretations,base),wi,policy,p_context,true));
  IF observation->>'leave_compatibility_state' IS DISTINCT FROM 'compatible' THEN
   RETURN result||jsonb_build_object('evaluated_observations',observation,
    'diagnostics',diagnostics||jsonb_build_array(observation->>'exception_code'));
  END IF;
 END IF;
 RETURN result||jsonb_build_object('kind','worked','absence_units',0,
  'evaluated_observations',observation,'approval_eligible',true);
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
 -- Malformed persisted domain evidence cannot authorize a new fact. The base
 -- calculator separately rejects programming input errors with 22023.
 IF result IS NULL THEN
  RAISE EXCEPTION 'attendance_classification_invalid_input' USING ERRCODE='22023';
 END IF;
 RETURN result||jsonb_build_object('diagnostics',diagnostics||'"leave_coverage_source_review_required"'::jsonb);
END $f$;
REVOKE ALL ON FUNCTION "time".classify_attendance_values(jsonb,jsonb,jsonb,jsonb,uuid,timestamptz)
 FROM PUBLIC,anon,authenticated,service_role;
