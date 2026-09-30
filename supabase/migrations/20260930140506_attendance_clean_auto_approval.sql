ALTER TABLE time.work_policy_versions
  ADD COLUMN auto_approve_clean boolean NOT NULL DEFAULT false;

ALTER TABLE time.work_instances
  ADD COLUMN auto_approve_clean boolean NOT NULL DEFAULT false;

UPDATE time.work_instances i
SET auto_approve_clean=v.auto_approve_clean
FROM time.work_policy_versions v
WHERE v.tenant_id=i.tenant_id AND v.template_id=i.policy_template_id AND v.version=i.policy_version;

CREATE FUNCTION public.save_time_work_policy(
  p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],
  p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,
  p_before integer,p_after integer,p_overtime_enabled boolean,p_overtime_minimum integer,p_overtime_rounding integer,
  p_auto_approve_clean boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); template_id uuid; version_n integer;
BEGIN
 IF NOT time.has_policy_permission(p_tenant_id,actor) THEN RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_code IS NULL OR btrim(p_code)='' OR length(btrim(p_code))>32 OR p_name IS NULL OR btrim(p_name)='' OR length(btrim(p_name))>100
 OR p_kind IS NULL OR p_kind NOT IN('fixed','flexible') OR p_timezone IS NULL OR cardinality(p_work_days) NOT BETWEEN 1 AND 7
 OR p_before NOT BETWEEN 0 AND 720 OR p_after NOT BETWEEN 0 AND 720 OR p_break NOT BETWEEN 0 AND 360
 OR (p_required IS NOT NULL AND p_required NOT BETWEEN 60 AND 960) OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone)
 OR p_overtime_enabled IS NULL OR p_overtime_minimum NOT BETWEEN 15 AND 480
 OR p_overtime_rounding NOT BETWEEN 5 AND 60 OR p_overtime_rounding>p_overtime_minimum OR p_auto_approve_clean IS NULL
 THEN RAISE EXCEPTION 'time_policy_input_invalid' USING ERRCODE='22023'; END IF;
 IF p_template_id IS NULL THEN
  INSERT INTO time.work_policy_templates(tenant_id,code) VALUES(p_tenant_id,upper(btrim(p_code))) RETURNING id INTO template_id;
  version_n:=1;
 ELSE
  SELECT t.head_version+1 INTO version_n FROM time.work_policy_templates t WHERE t.tenant_id=p_tenant_id AND t.id=p_template_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'time_policy_not_found' USING ERRCODE='P0002'; END IF;
  template_id:=p_template_id;
  UPDATE time.work_policy_templates SET head_version=version_n WHERE tenant_id=p_tenant_id AND id=template_id;
 END IF;
 INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,required_minutes,earliest_punch,latest_punch,attribution_before_minutes,attribution_after_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes,auto_approve_clean)
 VALUES(p_tenant_id,template_id,version_n,btrim(p_name),p_kind,p_timezone,p_work_days,p_start,p_end,coalesce(p_next_day,false),p_break,p_required,p_earliest,p_latest,p_before,p_after,actor,p_overtime_enabled,p_overtime_minimum,p_overtime_rounding,p_auto_approve_clean);
 INSERT INTO time.work_policy_audit_events(tenant_id,actor_user_id,event_key,template_id,version,details)
 VALUES(p_tenant_id,actor,CASE WHEN version_n=1 THEN 'policy.created' ELSE 'policy.versioned' END,template_id,version_n,
   jsonb_build_object('code',upper(btrim(p_code)),'name',btrim(p_name),'kind',p_kind,'overtime_enabled',p_overtime_enabled,'overtime_minimum_minutes',p_overtime_minimum,'overtime_rounding_minutes',p_overtime_rounding,'auto_approve_clean',p_auto_approve_clean));
 RETURN jsonb_build_object('id',template_id,'version',version_n);
END $f$;
REVOKE ALL ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.time_work_policy_catalog(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
    OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'people.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance_policy.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'))
 THEN RAISE EXCEPTION 'time_policy_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'is_active',t.is_active,'head_version',t.head_version,'name',v.name,'schedule_kind',v.schedule_kind,'timezone_name',v.timezone_name,'work_days',v.work_days,'shift_start',v.shift_start,'shift_end',v.shift_end,'ends_next_day',v.ends_next_day,'break_minutes',v.break_minutes,'required_minutes',v.required_minutes,'earliest_punch',v.earliest_punch,'latest_punch',v.latest_punch,'attribution_before_minutes',v.attribution_before_minutes,'attribution_after_minutes',v.attribution_after_minutes,'overtime_enabled',v.overtime_enabled,'overtime_minimum_minutes',v.overtime_minimum_minutes,'overtime_rounding_minutes',v.overtime_rounding_minutes,'auto_approve_clean',v.auto_approve_clean) ORDER BY t.code),'[]'::jsonb)
 INTO rows FROM time.work_policy_templates t JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version WHERE t.tenant_id=p_tenant_id;
 RETURN jsonb_build_object('items',rows,'can_manage',time.has_policy_permission(p_tenant_id,actor));
END $f$;
REVOKE ALL ON FUNCTION public.time_work_policy_catalog(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.time_work_policy_catalog(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION time.snapshot_overtime_policy_on_instance()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  SELECT v.overtime_enabled,v.overtime_minimum_minutes,v.overtime_rounding_minutes,v.auto_approve_clean
    INTO NEW.overtime_enabled,NEW.overtime_minimum_minutes,NEW.overtime_rounding_minutes,NEW.auto_approve_clean
  FROM time.work_policy_versions v
  WHERE v.tenant_id=NEW.tenant_id AND v.template_id=NEW.policy_template_id AND v.version=NEW.policy_version;
  IF NOT FOUND THEN RAISE EXCEPTION 'attendance_policy_version_missing' USING ERRCODE='23503'; END IF;
  RETURN NEW;
END $f$;

CREATE FUNCTION time.auto_approve_clean_work_instance(p_tenant uuid,p_instance uuid,p_actor uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi time.work_instances%ROWTYPE; q time.interpretations%ROWTYPE; fact_id uuid; fingerprint text; version_n integer;
BEGIN
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_instance FOR UPDATE;
 IF NOT FOUND OR NOT wi.auto_approve_clean OR wi.status<>'ready' OR wi.attribution_end IS NULL
    OR clock_timestamp()<wi.attribution_end OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp())
    OR NOT (platform_private.has_tenant_permission(p_tenant,p_actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant,p_actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant,p_actor,'tenant.administer'))
    OR EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=p_tenant AND f.work_instance_id=p_instance)
 THEN RETURN false; END IF;
 SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant AND work_instance_id=p_instance ORDER BY version DESC LIMIT 1;
 IF NOT FOUND OR q.state<>'ready' OR q.exception_code IS NOT NULL THEN RETURN false; END IF;
 -- A tolerated slightly-future punch must settle before any immutable fact is written.
 IF EXISTS(
   SELECT 1 FROM time.manual_punches p
   LEFT JOIN LATERAL(SELECT c.* FROM time.punch_corrections c WHERE c.tenant_id=p.tenant_id AND c.punch_id=p.id ORDER BY c.created_at DESC,c.id DESC LIMIT 1)c ON true
   WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance AND coalesce(c.action,'')<>'exclude'
     AND coalesce(c.new_happened_at,p.happened_at)>clock_timestamp()
 ) THEN RETURN false; END IF;
 fingerprint:=md5(coalesce((SELECT string_agg(p.id::text||':'||p.direction||':'||p.happened_at::text||':'||coalesce(c.action,'')||':'||coalesce(c.new_direction,'')||':'||coalesce(c.new_happened_at::text,''),',' ORDER BY p.id)
   FROM time.manual_punches p LEFT JOIN LATERAL(SELECT c.* FROM time.punch_corrections c WHERE c.tenant_id=p.tenant_id AND c.punch_id=p.id ORDER BY c.created_at DESC,c.id DESC LIMIT 1)c ON true WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance),'')
   ||concat_ws(':',wi.schedule_kind,wi.expected_start,wi.expected_end,wi.attribution_start,wi.attribution_end,wi.required_minutes,wi.break_minutes,wi.lateness_grace_minutes,wi.early_leave_grace_minutes));
 IF q.input_fingerprint IS DISTINCT FROM fingerprint THEN RETURN false; END IF;
 SELECT coalesce(max(version),0)+1 INTO version_n FROM time.attendance_facts WHERE tenant_id=p_tenant AND work_instance_id=p_instance;
 IF version_n<>1 THEN RETURN false; END IF;
 INSERT INTO time.attendance_facts(tenant_id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id)
 VALUES(p_tenant,p_instance,version_n,q.id,NULL,NULL,jsonb_build_object('outcome','worked','schedule_kind',wi.schedule_kind,'required_minutes',wi.required_minutes,'interpretation_exception',q.exception_code,'operational_date',wi.operational_date,'employee_id',wi.employee_id,'assignment_id',wi.assignment_id,'site_id',wi.site_id,'timezone_name',wi.timezone_name,'expected_start',wi.expected_start,'expected_end',wi.expected_end,'first_in',q.first_in,'last_out',q.last_out,'gross_worked_minutes',q.gross_worked_minutes,'scheduled_break_minutes',q.scheduled_break_minutes,'worked_minutes',q.worked_minutes,'late_minutes',q.late_minutes,'early_leave_minutes',q.early_leave_minutes),p_actor)
 RETURNING id INTO fact_id;
 UPDATE time.work_instances SET status='approved' WHERE tenant_id=p_tenant AND id=p_instance;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
 VALUES(p_tenant,p_actor,'attendance.fact.auto_approved',p_instance,jsonb_build_object('fact_id',fact_id,'version',version_n,'interpretation_id',q.id,'policy_template_id',wi.policy_template_id,'policy_version',wi.policy_version,'attribution_end',wi.attribution_end,'mode','auto_approve_clean'));
 RETURN true;
END $f$;
REVOKE ALL ON FUNCTION time.auto_approve_clean_work_instance(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION time.refresh_expired_work_instance(p_tenant uuid,p_instance uuid,p_actor uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi time.work_instances%ROWTYPE; latest_state text; interpretation_id uuid;
BEGIN
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_instance FOR UPDATE;
 IF NOT FOUND OR wi.attribution_end IS NULL OR clock_timestamp()<=wi.attribution_end THEN RETURN; END IF;
 SELECT state INTO latest_state FROM time.interpretations WHERE tenant_id=p_tenant AND work_instance_id=p_instance ORDER BY version DESC LIMIT 1;
 IF latest_state IS DISTINCT FROM 'needs_review' AND latest_state IS DISTINCT FROM 'ready' THEN
  interpretation_id:=time.interpret_work_instance(p_tenant,p_instance,p_actor);
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
  SELECT p_tenant,p_actor,'attendance.exception.detected',p_instance,jsonb_build_object('interpretation_id',id,'exception_code',exception_code)
  FROM time.interpretations WHERE tenant_id=p_tenant AND id=interpretation_id AND state='needs_review';
 END IF;
 PERFORM time.auto_approve_clean_work_instance(p_tenant,p_instance,p_actor);
END $f$;
REVOKE ALL ON FUNCTION time.refresh_expired_work_instance(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
