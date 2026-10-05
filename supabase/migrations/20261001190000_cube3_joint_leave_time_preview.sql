-- Prospective read seam for the joint coordinator. It performs no transitions,
-- interpretation refresh, fact insertion, or balance consumption.
CREATE FUNCTION platform_private.leave_time_prospective_context(
 p_tenant uuid,p_instance uuid,p_remove_request uuid,p_add_request uuid
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 WITH retained AS (
  SELECT value source FROM jsonb_array_elements(
   platform_private.approved_leave_classification_context(p_tenant,p_instance))
  WHERE p_remove_request IS NULL OR value->>'request_id'<>p_remove_request::text
 ), added AS (
  SELECT jsonb_build_object(
   'tenant_id',r.tenant_id,'request_id',r.id,'employee_id',r.employee_id,
   'employment_id',r.employment_id,'employer_entity_id',r.employer_entity_id,
   'approved_preview_version',r.current_preview_version,'leave_date',d.leave_date,
   'leave_type_id',r.leave_type_id,'is_half_day',r.is_half_day,
   'half_day_part',d.half_day_part,'units',d.units,'pay_effect',d.pay_effect,
   'reference_only',true,'type_version_id',d.type_version_id,
   'calendar_version_id',d.calendar_version_id,'mapping_state',d.halfday_mapping_state,
   'mapping_snapshot',d.halfday_mapping_snapshot,'policy_template_id',d.halfday_policy_template_id,
   'policy_version',d.halfday_policy_version,'algorithm_version',d.halfday_algorithm_version) source
  FROM time.work_instances i
  JOIN people.employments e ON e.tenant_id=i.tenant_id AND e.id=i.employment_id
   AND e.employee_id=i.employee_id
  JOIN leave.requests r ON r.tenant_id=i.tenant_id AND r.id=p_add_request
   AND r.employee_id=i.employee_id AND r.employment_id=i.employment_id
   AND r.employer_entity_id=e.employer_entity_id AND r.state='submitted'
  JOIN leave.request_days d ON d.tenant_id=r.tenant_id AND d.request_id=r.id
   AND d.preview_version=r.current_preview_version AND d.employer_entity_id=r.employer_entity_id
   AND d.leave_date=i.operational_date AND d.eligible AND d.units>0
  WHERE i.tenant_id=p_tenant AND i.id=p_instance
 )
 SELECT coalesce(jsonb_agg(source ORDER BY source->>'request_id',source->>'leave_date'),'[]'::jsonb)
 FROM (SELECT source FROM retained UNION ALL SELECT source FROM added) sources
$f$;
REVOKE ALL ON FUNCTION platform_private.leave_time_prospective_context(uuid,uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION platform_private.leave_time_review_plan(
 p_tenant uuid,p_action text,p_request uuid,p_replacement uuid,p_as_of timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE r leave.requests%ROWTYPE; replacement leave.requests%ROWTYPE;
 target leave.requests%ROWTYPE; wi record; current_input jsonb; proposed jsonb;
 classification jsonb; items jsonb:='[]'; dates jsonb; missing_dates jsonb;
 cancellation jsonb; computed jsonb; stored jsonb; plan jsonb;
 remove_id uuid; add_id uuid;
BEGIN
 IF p_action IS NULL OR p_action NOT IN('approve','replace','cancel_reconcile')
  OR p_request IS NULL OR p_as_of IS NULL
  OR (p_action='replace') IS DISTINCT FROM (p_replacement IS NOT NULL)
  OR p_request=p_replacement THEN
  RAISE EXCEPTION 'leave_time_review_input_invalid' USING ERRCODE='22023';
 END IF;
 SELECT * INTO r FROM leave.requests WHERE tenant_id=p_tenant AND id=p_request;
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
 IF p_action='approve' THEN
  IF r.state<>'submitted' THEN RAISE EXCEPTION 'leave_request_not_approvable' USING ERRCODE='23514'; END IF;
  target:=r; add_id:=r.id;
 ELSIF p_action='replace' THEN
  IF r.state<>'approved' THEN RAISE EXCEPTION 'leave_request_not_replaceable' USING ERRCODE='23514'; END IF;
  SELECT * INTO replacement FROM leave.requests WHERE tenant_id=p_tenant AND id=p_replacement;
  IF NOT FOUND OR replacement.employee_id IS DISTINCT FROM r.employee_id
   OR replacement.employer_entity_id IS DISTINCT FROM r.employer_entity_id THEN
   RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  IF replacement.state<>'submitted' THEN RAISE EXCEPTION 'leave_request_not_approvable' USING ERRCODE='23514'; END IF;
  target:=replacement; remove_id:=r.id; add_id:=replacement.id;
 ELSE
  IF r.state<>'cancelled' THEN RAISE EXCEPTION 'leave_request_not_cancelled' USING ERRCODE='23514'; END IF;
  SELECT to_jsonb(e) INTO cancellation FROM leave.cancellation_events e
   WHERE e.tenant_id=p_tenant AND e.request_id=r.id AND e.to_state='cancelled'
    AND e.to_version=r.version ORDER BY e.id DESC LIMIT 1;
  IF cancellation IS NULL THEN RAISE EXCEPTION 'leave_cancellation_source_missing' USING ERRCODE='P0002'; END IF;
  remove_id:=r.id;
 END IF;
 IF add_id IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM people.employments e
   JOIN platform_core.tenant_legal_entities employer ON employer.tenant_id=e.tenant_id
    AND employer.id=e.employer_entity_id AND employer.is_active
   JOIN leave.types t ON t.tenant_id=e.tenant_id AND t.id=target.leave_type_id
    AND t.employer_entity_id=e.employer_entity_id AND t.is_active
   WHERE e.tenant_id=p_tenant AND e.id=target.employment_id
    AND e.employee_id=target.employee_id AND e.employer_entity_id=target.employer_entity_id
    AND e.employment_status='active' AND e.start_date<=target.start_date
    AND (e.end_date IS NULL OR e.end_date>=target.end_date)) THEN
   RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514';
  END IF;
  computed:=leave.request_preview_with_mapping(p_tenant,target.employer_entity_id,
   target.employment_id,target.leave_type_id,target.start_date,target.end_date,
   target.is_half_day,target.half_day_part);
  stored:=leave.request_preview_snapshot(p_tenant,target.id,target.current_preview_version);
  IF computed IS DISTINCT FROM stored THEN
   RETURN jsonb_build_object('state','refresh_required','request_id',target.id,
    'request_version',target.version,'stored_preview_version',target.current_preview_version,
    'stored_preview',stored,'current_preview',computed);
  END IF;
 END IF;
 SELECT coalesce(jsonb_agg(d.leave_date ORDER BY d.leave_date),'[]') INTO dates
 FROM (SELECT DISTINCT leave_date FROM leave.request_days
  WHERE tenant_id=p_tenant AND (
   (request_id=r.id AND preview_version=coalesce(r.approved_preview_version,r.current_preview_version))
   OR (request_id=replacement.id AND preview_version=replacement.current_preview_version))) d;
 IF jsonb_array_length(dates)>62 THEN RAISE EXCEPTION 'leave_time_plan_too_large' USING ERRCODE='22023'; END IF;
 FOR wi IN SELECT i.id,i.operational_date FROM time.work_instances i
  WHERE i.tenant_id=p_tenant AND i.employee_id=r.employee_id
   AND i.employment_id IN(r.employment_id,replacement.employment_id)
   AND i.operational_date IN(SELECT value::date FROM jsonb_array_elements_text(dates))
  ORDER BY i.operational_date,i.id
 LOOP
  IF jsonb_array_length(items)>=62 THEN RAISE EXCEPTION 'leave_time_plan_too_large' USING ERRCODE='22023'; END IF;
  current_input:=time.attendance_classification_input(p_tenant,wi.id,p_as_of)->'plan';
  IF current_input IS NULL OR current_input->'input'->>'employer_id' IS DISTINCT FROM r.employer_entity_id::text THEN
   RAISE EXCEPTION 'leave_time_instance_unavailable' USING ERRCODE='P0002';
  END IF;
  proposed:=platform_private.leave_time_prospective_context(p_tenant,wi.id,remove_id,add_id);
  classification:=time.classify_attendance_values(current_input->'input'->'instance',
   current_input->'input'->'policy',current_input->'input'->'punches',proposed,
   r.employer_entity_id,p_as_of);
  items:=items||jsonb_build_array(jsonb_build_object(
   'work_instance_id',wi.id,'operational_date',wi.operational_date,
   'expected_fact',current_input->'expected_fact','expected_interpretation',current_input->'expected_q',
   'expected_input_fingerprint',current_input->'input_fingerprint',
   'current_context_hash',current_input->>'context_hash',
   'current_classification',current_input->'classification','proposed_classification',classification,
   'server_input',(current_input->'input')-'as_of','prospective_context',proposed));
 END LOOP;
 SELECT coalesce(jsonb_agg(value ORDER BY value),'[]') INTO missing_dates
 FROM jsonb_array_elements_text(dates) day(value)
 WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(items) item
  WHERE item->>'operational_date'=day.value);
 plan:=jsonb_build_object('contract_version',1,'state','reviewed','action',p_action,
  'tenant_id',p_tenant,'employee_id',r.employee_id,'employer_entity_id',r.employer_entity_id,
  'request',jsonb_build_object('id',r.id,'version',r.version,'preview_version',r.current_preview_version,
   'approved_preview_version',r.approved_preview_version,'employment_id',r.employment_id),
  'replacement',CASE WHEN replacement.id IS NOT NULL THEN jsonb_build_object(
   'id',replacement.id,'version',replacement.version,'preview_version',replacement.current_preview_version,
   'employment_id',replacement.employment_id) END,
  'cancellation_event',cancellation,'affected_dates',dates,
  'dates_without_work_instance',missing_dates,'items',items,
  'all_classifications_eligible',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(items) item
   WHERE (item->'proposed_classification'->>'approval_eligible')::boolean IS DISTINCT FROM true));
 RETURN jsonb_build_object('plan',plan,'plan_hash',encode(sha256(convert_to(plan::text,'UTF8')),'hex'));
END $f$;
REVOKE ALL ON FUNCTION platform_private.leave_time_review_plan(uuid,text,uuid,uuid,timestamptz)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_time_correction_preview(
 p_tenant_id uuid,p_action text,p_request_id uuid,p_replacement_request_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid; result jsonb; plan jsonb; items jsonb;
BEGIN
 actor:=leave.authorized(p_tenant_id,'leave.approve',p_action IS DISTINCT FROM 'cancel_reconcile');
 IF NOT coalesce(platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()),false)
  OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')
   OR (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve')
    AND platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct'))) THEN
  RAISE EXCEPTION 'leave_time_review_forbidden' USING ERRCODE='42501';
 END IF;
 result:=platform_private.leave_time_review_plan(p_tenant_id,p_action,p_request_id,p_replacement_request_id,now());
 IF result->>'state'='refresh_required' THEN
  RETURN time.attendance_visible_json(result,
   platform_private.has_tenant_permission(p_tenant_id,actor,'leave.view')
    OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'));
 END IF;
 plan:=result->'plan';
 SELECT coalesce(jsonb_agg(item-ARRAY['server_input','prospective_context'] ORDER BY ordinal),'[]') INTO items
 FROM jsonb_array_elements(plan->'items') WITH ORDINALITY row(item,ordinal);
 RETURN time.attendance_visible_json((plan-'cancellation_event')||jsonb_build_object(
  'cancellation_event_id',plan->'cancellation_event'->'id',
  'cancellation_id',plan->'cancellation_event'->'cancellation_id',
  'items',items,'plan_hash',result->'plan_hash'),
  platform_private.has_tenant_permission(p_tenant_id,actor,'leave.view')
   OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'));
END $f$;
REVOKE ALL ON FUNCTION public.leave_time_correction_preview(uuid,text,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_time_correction_preview(uuid,text,uuid,uuid) TO authenticated;
