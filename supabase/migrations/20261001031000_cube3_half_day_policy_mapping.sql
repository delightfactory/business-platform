-- Halfday Slice A0: immutable Time policy mapping configuration and private preview calculator.
-- Keeps the legacy 20-argument public RPC signature and routes both writers through one private version inserter.
ALTER TABLE time.work_policy_versions
  ADD COLUMN fixed_break_start time,
  ADD COLUMN fixed_break_end time,
  ADD COLUMN flexible_halfday_break_minutes integer;

ALTER TABLE time.work_policy_versions
  ADD CONSTRAINT work_policy_halfday_break_pair CHECK ((fixed_break_start IS NULL) = (fixed_break_end IS NULL)),
  ADD CONSTRAINT work_policy_flexible_halfday_break_range CHECK (flexible_halfday_break_minutes IS NULL OR flexible_halfday_break_minutes BETWEEN 0 AND 360),
  ADD CONSTRAINT work_policy_halfday_mapping_kind CHECK (
    (schedule_kind='fixed' AND flexible_halfday_break_minutes IS NULL) OR
    (schedule_kind='flexible' AND fixed_break_start IS NULL AND fixed_break_end IS NULL)
  );

CREATE OR REPLACE FUNCTION public.time_work_policy_catalog(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
    OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'people.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance_policy.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'))
 THEN RAISE EXCEPTION 'time_policy_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'is_active',t.is_active,'head_version',t.head_version,'name',v.name,'schedule_kind',v.schedule_kind,'timezone_name',v.timezone_name,'work_days',v.work_days,'shift_start',v.shift_start,'shift_end',v.shift_end,'ends_next_day',v.ends_next_day,'break_minutes',v.break_minutes,'fixed_break_start',v.fixed_break_start,'fixed_break_end',v.fixed_break_end,'flexible_halfday_break_minutes',v.flexible_halfday_break_minutes,'required_minutes',v.required_minutes,'earliest_punch',v.earliest_punch,'latest_punch',v.latest_punch,'attribution_before_minutes',v.attribution_before_minutes,'attribution_after_minutes',v.attribution_after_minutes,'overtime_enabled',v.overtime_enabled,'overtime_minimum_minutes',v.overtime_minimum_minutes,'overtime_rounding_minutes',v.overtime_rounding_minutes,'auto_approve_clean',v.auto_approve_clean) ORDER BY t.code),'[]'::jsonb)
 INTO rows FROM time.work_policy_templates t JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version WHERE t.tenant_id=p_tenant_id;
 RETURN jsonb_build_object('items',rows,'can_manage',time.has_policy_permission(p_tenant_id,actor));
END $f$;
REVOKE ALL ON FUNCTION public.time_work_policy_catalog(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.time_work_policy_catalog(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.people_work_policy_panel(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); items jsonb; options jsonb; overrides jsonb;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) OR NOT platform_private.has_people_permission(p_tenant_id,actor,'people.view') THEN RAISE EXCEPTION 'time_policy_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('assignment_id',a.id,'policy_id',a.work_policy_template_id,'version',a.work_policy_version,'name',v.name,'code',t.code,'valid_from',a.valid_from,'valid_until',a.valid_until) ORDER BY a.valid_from DESC),'[]'::jsonb) INTO items FROM people.work_assignments a LEFT JOIN time.work_policy_templates t ON t.tenant_id=a.tenant_id AND t.id=a.work_policy_template_id LEFT JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id AND v.template_id=a.work_policy_template_id AND v.version=a.work_policy_version WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'name',v.name,'version',v.version,'schedule_kind',v.schedule_kind,'timezone_name',v.timezone_name,'shift_start',v.shift_start,'shift_end',v.shift_end,'ends_next_day',v.ends_next_day,'break_minutes',v.break_minutes,'fixed_break_start',v.fixed_break_start,'fixed_break_end',v.fixed_break_end,'required_minutes',v.required_minutes,'flexible_halfday_break_minutes',v.flexible_halfday_break_minutes) ORDER BY t.code),'[]'::jsonb) INTO options FROM time.work_policy_templates t JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version WHERE t.tenant_id=p_tenant_id AND t.is_active;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',o.id,'policy_id',o.policy_template_id,'version',o.policy_version,'name',v.name,'code',t.code,'valid_from',o.valid_from,'valid_through',o.valid_until-1,'reason',o.reason,'cancelled_at',o.cancelled_at,'can_cancel',o.cancelled_at IS NULL AND o.valid_from>(transaction_timestamp() AT TIME ZONE v.timezone_name)::date) ORDER BY o.valid_from DESC,o.created_at DESC),'[]'::jsonb) INTO overrides FROM (SELECT * FROM time.work_policy_overrides WHERE tenant_id=p_tenant_id AND employment_id=p_employment_id ORDER BY valid_from DESC,created_at DESC LIMIT 50) o JOIN time.work_policy_templates t ON t.tenant_id=o.tenant_id AND t.id=o.policy_template_id JOIN time.work_policy_versions v ON v.tenant_id=o.tenant_id AND v.template_id=o.policy_template_id AND v.version=o.policy_version;
 RETURN jsonb_build_object('history',items,'options',options,'overrides',overrides,'can_assign',platform_private.has_people_permission(p_tenant_id,actor,'org_context.manage'),'can_manage_catalog',time.has_policy_permission(p_tenant_id,actor));
END $f$;
REVOKE ALL ON FUNCTION public.people_work_policy_panel(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_work_policy_panel(uuid,uuid) TO authenticated;

-- Internal writer: full policy validation and immutable INSERT happen once, including mapping fields.
CREATE OR REPLACE FUNCTION time.save_work_policy_version(
  p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],
  p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,
  p_before integer,p_after integer,p_overtime_enabled boolean,p_overtime_minimum integer,p_overtime_rounding integer,
  p_auto_approve_clean boolean,p_fixed_break_start time,p_fixed_break_end time,p_flexible_halfday_break_minutes integer,
  p_require_mapping boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); template_id uuid; version_n integer; shift_minutes integer; break_offset integer; break_length integer;
BEGIN
 IF NOT time.has_policy_permission(p_tenant_id,actor) THEN RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_code IS NULL OR btrim(p_code)='' OR length(btrim(p_code))>32 OR p_name IS NULL OR btrim(p_name)='' OR length(btrim(p_name))>100
 OR p_kind IS NULL OR p_kind NOT IN('fixed','flexible') OR p_timezone IS NULL OR cardinality(p_work_days) NOT BETWEEN 1 AND 7
 OR p_before NOT BETWEEN 0 AND 720 OR p_after NOT BETWEEN 0 AND 720 OR p_break NOT BETWEEN 0 AND 360
 OR (p_required IS NOT NULL AND p_required NOT BETWEEN 60 AND 960) OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone)
 OR p_overtime_enabled IS NULL OR p_overtime_minimum NOT BETWEEN 15 AND 480 OR p_overtime_rounding NOT BETWEEN 5 AND 60
 OR p_overtime_rounding>p_overtime_minimum OR p_auto_approve_clean IS NULL
 THEN RAISE EXCEPTION 'time_policy_input_invalid' USING ERRCODE='22023'; END IF;
 IF p_kind='fixed' THEN
   IF p_flexible_halfday_break_minutes IS NOT NULL OR ((p_fixed_break_start IS NULL)<>(p_fixed_break_end IS NULL)) THEN RAISE EXCEPTION 'time_policy_halfday_mapping_invalid' USING ERRCODE='22023'; END IF;
   IF p_require_mapping AND (p_start IS NULL OR p_end IS NULL OR extract(second FROM p_start)<>0 OR extract(second FROM p_end)<>0) THEN RAISE EXCEPTION 'time_policy_halfday_mapping_invalid' USING ERRCODE='22023'; END IF;
   IF p_require_mapping AND p_break>0 AND (p_fixed_break_start IS NULL OR p_fixed_break_end IS NULL) THEN RAISE EXCEPTION 'time_policy_halfday_mapping_required' USING ERRCODE='22023'; END IF;
   IF p_fixed_break_start IS NOT NULL THEN
     shift_minutes:=((extract(epoch FROM (p_end-p_start))/60)::integer + CASE WHEN coalesce(p_next_day,false) OR p_end<=p_start THEN 1440 ELSE 0 END);
     break_length:=((extract(epoch FROM (p_fixed_break_end-p_fixed_break_start))/60)::integer + CASE WHEN p_fixed_break_end<=p_fixed_break_start THEN 1440 ELSE 0 END);
     break_offset:=((extract(epoch FROM (p_fixed_break_start-p_start))/60)::integer + CASE WHEN p_fixed_break_start<p_start THEN 1440 ELSE 0 END);
     IF p_start IS NULL OR p_end IS NULL OR extract(second FROM p_start)<>0 OR extract(second FROM p_end)<>0
        OR extract(second FROM p_fixed_break_start)<>0 OR extract(second FROM p_fixed_break_end)<>0
        OR shift_minutes NOT BETWEEN 1 AND 1440 OR break_length<>p_break OR break_offset<0 OR break_offset+break_length>shift_minutes THEN
       RAISE EXCEPTION 'time_policy_halfday_mapping_invalid' USING ERRCODE='22023'; END IF;
   ELSIF p_break=0 AND p_fixed_break_end IS NOT NULL THEN RAISE EXCEPTION 'time_policy_halfday_mapping_invalid' USING ERRCODE='22023'; END IF;
 ELSE
   IF p_fixed_break_start IS NOT NULL OR p_fixed_break_end IS NOT NULL OR p_require_mapping AND p_flexible_halfday_break_minutes IS NULL
      OR (p_flexible_halfday_break_minutes IS NOT NULL AND p_flexible_halfday_break_minutes NOT BETWEEN 0 AND 360) THEN
     RAISE EXCEPTION 'time_policy_halfday_mapping_invalid' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_template_id IS NULL THEN
  INSERT INTO time.work_policy_templates(tenant_id,code) VALUES(p_tenant_id,upper(btrim(p_code))) RETURNING id INTO template_id; version_n:=1;
 ELSE
  SELECT t.head_version+1 INTO version_n FROM time.work_policy_templates t WHERE t.tenant_id=p_tenant_id AND t.id=p_template_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'time_policy_not_found' USING ERRCODE='P0002'; END IF;
  template_id:=p_template_id; UPDATE time.work_policy_templates SET head_version=version_n WHERE tenant_id=p_tenant_id AND id=template_id;
 END IF;
 INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,required_minutes,earliest_punch,latest_punch,attribution_before_minutes,attribution_after_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes,auto_approve_clean,fixed_break_start,fixed_break_end,flexible_halfday_break_minutes)
 VALUES(p_tenant_id,template_id,version_n,btrim(p_name),p_kind,p_timezone,p_work_days,p_start,p_end,coalesce(p_next_day,false),p_break,p_required,p_earliest,p_latest,p_before,p_after,actor,p_overtime_enabled,p_overtime_minimum,p_overtime_rounding,p_auto_approve_clean,p_fixed_break_start,p_fixed_break_end,p_flexible_halfday_break_minutes);
 INSERT INTO time.work_policy_audit_events(tenant_id,actor_user_id,event_key,template_id,version,details)
 VALUES(p_tenant_id,actor,CASE WHEN version_n=1 THEN 'policy.created' ELSE 'policy.versioned' END,template_id,version_n,
   jsonb_build_object('code',upper(btrim(p_code)),'name',btrim(p_name),'kind',p_kind,'overtime_enabled',p_overtime_enabled,'overtime_minimum_minutes',p_overtime_minimum,'overtime_rounding_minutes',p_overtime_rounding,'auto_approve_clean',p_auto_approve_clean,'fixed_break_start',p_fixed_break_start,'fixed_break_end',p_fixed_break_end,'flexible_halfday_break_minutes',p_flexible_halfday_break_minutes));
 RETURN jsonb_build_object('id',template_id,'version',version_n);
END $f$;
REVOKE ALL ON FUNCTION time.save_work_policy_version(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer,boolean,time,time,integer,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.save_time_work_policy(
  p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],
  p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,
  p_before integer,p_after integer,p_overtime_enabled boolean,p_overtime_minimum integer,p_overtime_rounding integer,
  p_auto_approve_clean boolean
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
 SELECT time.save_work_policy_version($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,NULL,NULL,NULL,false)
$f$;
REVOKE ALL ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer,boolean) TO authenticated;

-- Distinct name prevents overload/default-argument ambiguity for legacy callers.
CREATE FUNCTION public.save_time_work_policy_with_leave_mapping(
  p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],
  p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,
  p_before integer,p_after integer,p_overtime_enabled boolean,p_overtime_minimum integer,p_overtime_rounding integer,
  p_auto_approve_clean boolean,p_fixed_break_start time,p_fixed_break_end time,p_flexible_halfday_break_minutes integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 RETURN time.save_work_policy_version(p_tenant_id,p_template_id,p_code,p_name,p_kind,p_timezone,p_work_days,p_start,p_end,p_next_day,p_break,p_required,p_earliest,p_latest,p_before,p_after,p_overtime_enabled,p_overtime_minimum,p_overtime_rounding,p_auto_approve_clean,p_fixed_break_start,p_fixed_break_end,p_flexible_halfday_break_minutes,true);
END $f$;
REVOKE ALL ON FUNCTION public.save_time_work_policy_with_leave_mapping(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer,boolean,time,time,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_time_work_policy_with_leave_mapping(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer,boolean,time,time,integer) TO authenticated;

-- Private pure calculator. It returns full, resolved evidence for preview; it creates no Leave or Attendance fact.
CREATE FUNCTION time.leave_halfday_mapping(p_policy jsonb,p_operational_date date,p_part text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 kind text; zone_name text; shift_start time; shift_end time; break_start time; break_end time;
 next_day boolean; gross_n integer; break_n integer; net_n integer; first_n integer; required_n integer; half_break_n integer;
 start_local timestamp; end_local timestamp; bstart_local timestamp; bend_local timestamp; split_local timestamp;
 start_at timestamptz; end_at timestamptz; bstart_at timestamptz; bend_at timestamptz; split_at timestamptz;
 remaining_first integer; span_n integer; span_start timestamptz; span_end timestamptz; cursor_at timestamptz;
 work_spans jsonb:='[]'::jsonb; excused_intervals jsonb:='[]'::jsonb; remaining_intervals jsonb:='[]'::jsonb;
 response_excused jsonb; response_remaining jsonb;
 break_interval jsonb:='[]'::jsonb; selected_intervals jsonb; review jsonb; provenance jsonb; span_item jsonb; interval_item jsonb; i integer; j integer;
BEGIN
 IF p_policy IS NULL OR p_operational_date IS NULL THEN RETURN jsonb_build_object('state','review_required','reason','policy_or_operational_date_missing','algorithm_version','leave-halfday-v1'); END IF;
 -- Cast only inside the protected body so malformed snapshot JSON returns review_required.
 kind:=p_policy->>'schedule_kind'; zone_name:=p_policy->>'timezone_name';
 shift_start:=(p_policy->>'shift_start')::time; shift_end:=(p_policy->>'shift_end')::time;
 break_start:=(p_policy->>'fixed_break_start')::time; break_end:=(p_policy->>'fixed_break_end')::time;
 next_day:=coalesce((p_policy->>'ends_next_day')::boolean,false);
 provenance:=jsonb_build_object('algorithm_version','leave-halfday-v1','operational_date',p_operational_date,
   'timezone_name',zone_name,'source_policy_template_id',coalesce(p_policy->'policy_template_id',p_policy->'id'),
   'source_policy_version',coalesce(p_policy->'policy_version',p_policy->'version',p_policy->'head_version'),
   'configured_policy',jsonb_build_object('schedule_kind',kind,'shift_start',p_policy->'shift_start','shift_end',p_policy->'shift_end',
     'ends_next_day',p_policy->'ends_next_day','break_minutes',p_policy->'break_minutes',
     'fixed_break_start',p_policy->'fixed_break_start','fixed_break_end',p_policy->'fixed_break_end',
     'required_minutes',p_policy->'required_minutes','flexible_halfday_break_minutes',p_policy->'flexible_halfday_break_minutes'));
 IF coalesce(p_policy->'policy_template_id',p_policy->'id') IS NULL OR coalesce(p_policy->'policy_template_id',p_policy->'id')='null'::jsonb
    OR coalesce(p_policy->'policy_version',p_policy->'version',p_policy->'head_version') IS NULL
    OR coalesce(p_policy->'policy_version',p_policy->'version',p_policy->'head_version')='null'::jsonb THEN
   RETURN provenance||jsonb_build_object('state','review_required','reason','policy_identity_missing'); END IF;
 IF zone_name IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=zone_name) THEN
   RETURN provenance||jsonb_build_object('state','review_required','reason','timezone_unavailable'); END IF;
 IF kind='flexible' THEN
   IF p_part IS NOT NULL THEN RETURN provenance||jsonb_build_object('state','review_required','reason','flexible_policy_has_no_part'); END IF;
   required_n:=(p_policy->>'required_minutes')::integer; half_break_n:=(p_policy->>'flexible_halfday_break_minutes')::integer;
   IF required_n IS NULL OR required_n NOT BETWEEN 60 AND 960 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','flexible_required_minutes_invalid'); END IF;
   IF half_break_n IS NULL OR half_break_n NOT BETWEEN 0 AND 360 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','flexible_halfday_break_unknown'); END IF;
   RETURN provenance||jsonb_build_object('state','mapped','schedule_kind','flexible','part',NULL,
     'required_minutes',required_n,'remaining_net_threshold_minutes',(required_n+1)/2,'halfday_break_minutes',half_break_n,
     'excused_intervals','[]'::jsonb,'remaining_intervals','[]'::jsonb,'break_interval','[]'::jsonb);
 END IF;
 IF kind<>'fixed' OR p_part IS NULL OR p_part NOT IN('first','second') THEN RETURN provenance||jsonb_build_object('state','review_required','reason','fixed_part_or_schedule_invalid'); END IF;
 IF shift_start IS NULL OR shift_end IS NULL OR extract(second FROM shift_start)<>0 OR extract(second FROM shift_end)<>0 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','fixed_policy_incomplete'); END IF;
 start_local:=p_operational_date+shift_start;
 gross_n:=((extract(epoch FROM (shift_end-shift_start))/60)::integer+CASE WHEN next_day OR shift_end<=shift_start THEN 1440 ELSE 0 END);
 end_local:=start_local+make_interval(mins=>gross_n);
 IF gross_n NOT BETWEEN 1 AND 1440 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','shift_duration_unsupported'); END IF;
 start_at:=time.resolve_local(start_local,zone_name); end_at:=time.resolve_local(end_local,zone_name);
 IF start_at IS NULL OR end_at IS NULL OR end_at<=start_at THEN RETURN provenance||jsonb_build_object('state','review_required','reason','local_time_gap_or_overlap'); END IF;
 IF mod(extract(epoch FROM (end_at-start_at)),60)<>0 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','timezone_transition_review_required'); END IF;
 gross_n:=(extract(epoch FROM (end_at-start_at))/60)::integer;
 break_n:=coalesce((p_policy->>'break_minutes')::integer,0);
 IF break_n NOT BETWEEN 0 AND 360 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','fixed_break_minutes_invalid'); END IF;
 IF break_n=0 THEN
   IF break_start IS NOT NULL OR break_end IS NOT NULL THEN RETURN provenance||jsonb_build_object('state','review_required','reason','zero_break_has_placement'); END IF;
   work_spans:=jsonb_build_array(jsonb_build_object('start_at',start_at,'end_at',end_at));
 ELSE
   IF break_start IS NULL OR break_end IS NULL OR extract(second FROM break_start)<>0 OR extract(second FROM break_end)<>0 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','fixed_break_placement_unknown'); END IF;
   bstart_local:=p_operational_date+break_start; WHILE bstart_local<start_local LOOP bstart_local:=bstart_local+interval '1 day'; END LOOP;
   break_n:=((extract(epoch FROM (break_end-break_start))/60)::integer+CASE WHEN break_end<=break_start THEN 1440 ELSE 0 END);
   bend_local:=bstart_local+make_interval(mins=>break_n);
   bstart_at:=time.resolve_local(bstart_local,zone_name); bend_at:=time.resolve_local(bend_local,zone_name);
   IF bstart_at IS NULL OR bend_at IS NULL THEN RETURN provenance||jsonb_build_object('state','review_required','reason','local_time_gap_or_overlap'); END IF;
   IF bstart_at<start_at OR bend_at>end_at OR bend_at<=bstart_at OR mod(extract(epoch FROM (bend_at-bstart_at)),60)<>0
      OR extract(epoch FROM (bend_at-bstart_at))/60<>coalesce((p_policy->>'break_minutes')::integer,0) THEN
     RETURN provenance||jsonb_build_object('state','review_required','reason','timezone_transition_review_required'); END IF;
   IF bstart_at>start_at THEN work_spans:=work_spans||jsonb_build_array(jsonb_build_object('start_at',start_at,'end_at',bstart_at)); END IF;
   IF end_at>bend_at THEN work_spans:=work_spans||jsonb_build_array(jsonb_build_object('start_at',bend_at,'end_at',end_at)); END IF;
   break_interval:=jsonb_build_array(jsonb_build_object('start_local',bstart_at AT TIME ZONE zone_name,'end_local',bend_at AT TIME ZONE zone_name,'start_at',bstart_at,'end_at',bend_at));
 END IF;
 net_n:=0;
 FOR i IN 0..jsonb_array_length(work_spans)-1 LOOP
   span_item:=work_spans->i; span_start:=(span_item->>'start_at')::timestamptz; span_end:=(span_item->>'end_at')::timestamptz;
   IF mod(extract(epoch FROM (span_end-span_start)),60)<>0 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','timezone_transition_review_required'); END IF;
   net_n:=net_n+(extract(epoch FROM (span_end-span_start))/60)::integer;
 END LOOP;
 IF net_n<2 THEN RETURN provenance||jsonb_build_object('state','review_required','reason','insufficient_net_work_minutes'); END IF;
 first_n:=net_n/2; remaining_first:=first_n; split_at:=NULL;
 FOR i IN 0..jsonb_array_length(work_spans)-1 LOOP
   span_item:=work_spans->i; span_start:=(span_item->>'start_at')::timestamptz; span_end:=(span_item->>'end_at')::timestamptz;
   span_n:=(extract(epoch FROM (span_end-span_start))/60)::integer;
   IF remaining_first>=span_n THEN
     excused_intervals:=excused_intervals||jsonb_build_array(jsonb_build_object('start_local',span_start AT TIME ZONE zone_name,'end_local',span_end AT TIME ZONE zone_name,'start_at',span_start,'end_at',span_end));
     remaining_first:=remaining_first-span_n;
     IF remaining_first=0 AND split_at IS NULL THEN split_at:=span_end; END IF;
   ELSIF remaining_first>0 THEN
     cursor_at:=span_start+make_interval(mins=>remaining_first); split_at:=cursor_at;
     excused_intervals:=excused_intervals||jsonb_build_array(jsonb_build_object('start_local',span_start AT TIME ZONE zone_name,'end_local',cursor_at AT TIME ZONE zone_name,'start_at',span_start,'end_at',cursor_at));
     remaining_intervals:=remaining_intervals||jsonb_build_array(jsonb_build_object('start_local',cursor_at AT TIME ZONE zone_name,'end_local',span_end AT TIME ZONE zone_name,'start_at',cursor_at,'end_at',span_end));
     remaining_first:=0;
   ELSE
     IF split_at IS NULL THEN split_at:=span_start; END IF;
     remaining_intervals:=remaining_intervals||jsonb_build_array(jsonb_build_object('start_local',span_start AT TIME ZONE zone_name,'end_local',span_end AT TIME ZONE zone_name,'start_at',span_start,'end_at',span_end));
   END IF;
 END LOOP;
 IF remaining_first<>0 OR split_at IS NULL THEN RETURN provenance||jsonb_build_object('state','review_required','reason','mapping_interval_construction_failed'); END IF;
 split_local:=split_at AT TIME ZONE zone_name;
 IF time.resolve_local(split_local,zone_name) IS DISTINCT FROM split_at THEN RETURN provenance||jsonb_build_object('state','review_required','reason','local_time_gap_or_overlap'); END IF;
 -- Validate every returned endpoint, including both halves and the break, through the established local resolver.
 FOR j IN 0..jsonb_array_length(excused_intervals)-1 LOOP
   interval_item:=excused_intervals->j;
   IF time.resolve_local((interval_item->>'start_local')::timestamp,zone_name) IS DISTINCT FROM (interval_item->>'start_at')::timestamptz OR
      time.resolve_local((interval_item->>'end_local')::timestamp,zone_name) IS DISTINCT FROM (interval_item->>'end_at')::timestamptz THEN
     RETURN provenance||jsonb_build_object('state','review_required','reason','local_time_gap_or_overlap'); END IF;
 END LOOP;
 FOR j IN 0..jsonb_array_length(remaining_intervals)-1 LOOP
   interval_item:=remaining_intervals->j;
   IF time.resolve_local((interval_item->>'start_local')::timestamp,zone_name) IS DISTINCT FROM (interval_item->>'start_at')::timestamptz OR
      time.resolve_local((interval_item->>'end_local')::timestamp,zone_name) IS DISTINCT FROM (interval_item->>'end_at')::timestamptz THEN
     RETURN provenance||jsonb_build_object('state','review_required','reason','local_time_gap_or_overlap'); END IF;
 END LOOP;
 IF jsonb_array_length(break_interval)>0 THEN
   interval_item:=break_interval->0;
   IF time.resolve_local((interval_item->>'start_local')::timestamp,zone_name) IS DISTINCT FROM (interval_item->>'start_at')::timestamptz OR
      time.resolve_local((interval_item->>'end_local')::timestamp,zone_name) IS DISTINCT FROM (interval_item->>'end_at')::timestamptz THEN
     RETURN provenance||jsonb_build_object('state','review_required','reason','local_time_gap_or_overlap'); END IF;
 END IF;
 response_excused:=CASE WHEN p_part='first' THEN excused_intervals ELSE remaining_intervals END;
 response_remaining:=CASE WHEN p_part='first' THEN remaining_intervals ELSE excused_intervals END;
 RETURN provenance||jsonb_build_object('state','mapped','schedule_kind','fixed','part',p_part,'scheduled_net_minutes',net_n,
   'first_part_minutes',first_n,'second_part_minutes',net_n-first_n,'split_local',split_local,'split_at',split_at,
   'excused_intervals',response_excused,'remaining_intervals',response_remaining,'break_interval',break_interval);
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
 RETURN jsonb_build_object('state','review_required','reason','policy_snapshot_invalid','algorithm_version','leave-halfday-v1');
END $f$;
REVOKE ALL ON FUNCTION time.leave_halfday_mapping(jsonb,date,text) FROM PUBLIC,anon,authenticated,service_role;

