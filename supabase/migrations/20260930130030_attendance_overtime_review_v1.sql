ALTER TABLE time.work_policy_versions
  ADD COLUMN overtime_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN overtime_minimum_minutes integer NOT NULL DEFAULT 30 CHECK (overtime_minimum_minutes BETWEEN 15 AND 480),
  ADD COLUMN overtime_rounding_minutes integer NOT NULL DEFAULT 15 CHECK (overtime_rounding_minutes BETWEEN 5 AND 60 AND overtime_rounding_minutes <= overtime_minimum_minutes);

ALTER TABLE time.work_instances
  ADD COLUMN overtime_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN overtime_minimum_minutes integer NOT NULL DEFAULT 30 CHECK (overtime_minimum_minutes BETWEEN 15 AND 480),
  ADD COLUMN overtime_rounding_minutes integer NOT NULL DEFAULT 15 CHECK (overtime_rounding_minutes BETWEEN 5 AND 60 AND overtime_rounding_minutes <= overtime_minimum_minutes);
UPDATE time.work_instances i SET overtime_enabled=v.overtime_enabled,
  overtime_minimum_minutes=v.overtime_minimum_minutes,
  overtime_rounding_minutes=v.overtime_rounding_minutes
FROM time.work_policy_versions v
WHERE v.tenant_id=i.tenant_id AND v.template_id=i.policy_template_id AND v.version=i.policy_version;

DROP FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer);
CREATE FUNCTION public.save_time_work_policy(
  p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],
  p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,
  p_before integer,p_after integer,p_overtime_enabled boolean,p_overtime_minimum integer,p_overtime_rounding integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); template_id uuid; version_n integer;
BEGIN
 IF NOT time.has_policy_permission(p_tenant_id,actor) THEN RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_code IS NULL OR btrim(p_code)='' OR length(btrim(p_code))>32 OR p_name IS NULL OR btrim(p_name)='' OR length(btrim(p_name))>100
 OR p_kind IS NULL OR p_kind NOT IN('fixed','flexible') OR p_timezone IS NULL OR cardinality(p_work_days) NOT BETWEEN 1 AND 7
 OR p_before NOT BETWEEN 0 AND 720 OR p_after NOT BETWEEN 0 AND 720 OR p_break NOT BETWEEN 0 AND 360
 OR (p_required IS NOT NULL AND p_required NOT BETWEEN 60 AND 960) OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone)
 OR p_overtime_enabled IS NULL OR p_overtime_minimum NOT BETWEEN 15 AND 480
 OR p_overtime_rounding NOT BETWEEN 5 AND 60 OR p_overtime_rounding>p_overtime_minimum
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
 INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,required_minutes,earliest_punch,latest_punch,attribution_before_minutes,attribution_after_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes)
 VALUES(p_tenant_id,template_id,version_n,btrim(p_name),p_kind,p_timezone,p_work_days,p_start,p_end,coalesce(p_next_day,false),p_break,p_required,p_earliest,p_latest,p_before,p_after,actor,p_overtime_enabled,p_overtime_minimum,p_overtime_rounding);
 INSERT INTO time.work_policy_audit_events(tenant_id,actor_user_id,event_key,template_id,version,details)
 VALUES(p_tenant_id,actor,CASE WHEN version_n=1 THEN 'policy.created' ELSE 'policy.versioned' END,template_id,version_n,
   jsonb_build_object('code',upper(btrim(p_code)),'name',btrim(p_name),'kind',p_kind,'overtime_enabled',p_overtime_enabled,'overtime_minimum_minutes',p_overtime_minimum,'overtime_rounding_minutes',p_overtime_rounding));
 RETURN jsonb_build_object('id',template_id,'version',version_n);
END $f$;
REVOKE ALL ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer,boolean,integer,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.time_work_policy_catalog(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
    OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'people.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance_policy.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'))
 THEN RAISE EXCEPTION 'time_policy_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'is_active',t.is_active,'head_version',t.head_version,'name',v.name,'schedule_kind',v.schedule_kind,'timezone_name',v.timezone_name,'work_days',v.work_days,'shift_start',v.shift_start,'shift_end',v.shift_end,'ends_next_day',v.ends_next_day,'break_minutes',v.break_minutes,'required_minutes',v.required_minutes,'earliest_punch',v.earliest_punch,'latest_punch',v.latest_punch,'attribution_before_minutes',v.attribution_before_minutes,'attribution_after_minutes',v.attribution_after_minutes,'overtime_enabled',v.overtime_enabled,'overtime_minimum_minutes',v.overtime_minimum_minutes,'overtime_rounding_minutes',v.overtime_rounding_minutes) ORDER BY t.code),'[]'::jsonb)
 INTO rows FROM time.work_policy_templates t JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version WHERE t.tenant_id=p_tenant_id;
 RETURN jsonb_build_object('items',rows,'can_manage',time.has_policy_permission(p_tenant_id,actor));
END $f$;
REVOKE ALL ON FUNCTION public.time_work_policy_catalog(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.time_work_policy_catalog(uuid) TO authenticated;

CREATE FUNCTION time.snapshot_overtime_policy_on_instance()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  SELECT v.overtime_enabled,v.overtime_minimum_minutes,v.overtime_rounding_minutes
    INTO NEW.overtime_enabled,NEW.overtime_minimum_minutes,NEW.overtime_rounding_minutes
  FROM time.work_policy_versions v
  WHERE v.tenant_id=NEW.tenant_id AND v.template_id=NEW.policy_template_id AND v.version=NEW.policy_version;
  IF NOT FOUND THEN RAISE EXCEPTION 'attendance_policy_version_missing' USING ERRCODE='23503'; END IF;
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION time.snapshot_overtime_policy_on_instance() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER work_instance_overtime_policy_snapshot BEFORE INSERT ON time.work_instances
FOR EACH ROW EXECUTE FUNCTION time.snapshot_overtime_policy_on_instance();

CREATE TABLE time.attendance_overtime_candidates(
  tenant_id uuid NOT NULL,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  work_instance_id uuid NOT NULL,
  attendance_fact_id uuid NOT NULL,
  policy_template_id uuid NOT NULL,
  policy_version integer NOT NULL,
  raw_minutes integer NOT NULL CHECK(raw_minutes>0),
  candidate_minutes integer NOT NULL CHECK(candidate_minutes>0 AND candidate_minutes<=raw_minutes),
  category text NOT NULL CHECK(category IN('ordinary')),
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  PRIMARY KEY(tenant_id,id), UNIQUE(tenant_id,attendance_fact_id),
  FOREIGN KEY(tenant_id,work_instance_id) REFERENCES time.work_instances(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,attendance_fact_id) REFERENCES time.attendance_facts(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,policy_template_id,policy_version) REFERENCES time.work_policy_versions(tenant_id,template_id,version) ON DELETE RESTRICT
);
CREATE INDEX attendance_overtime_candidates_instance_idx ON time.attendance_overtime_candidates(tenant_id,work_instance_id,created_at DESC);
ALTER TABLE time.attendance_overtime_candidates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.attendance_overtime_candidates FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE time.attendance_overtime_review_events(
  tenant_id uuid NOT NULL,
  id bigint GENERATED ALWAYS AS IDENTITY,
  candidate_id uuid NOT NULL,
  decision text NOT NULL CHECK(decision IN('approved','rejected','superseded')),
  reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 3 AND 500),
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  PRIMARY KEY(tenant_id,id), UNIQUE(tenant_id,candidate_id),
  FOREIGN KEY(tenant_id,candidate_id) REFERENCES time.attendance_overtime_candidates(tenant_id,id) ON DELETE RESTRICT
);
ALTER TABLE time.attendance_overtime_review_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.attendance_overtime_review_events FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION time.prevent_overtime_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN RAISE EXCEPTION 'attendance_overtime_history_append_only' USING ERRCODE='55000'; END $f$;
REVOKE ALL ON FUNCTION time.prevent_overtime_mutation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER attendance_overtime_candidates_append_only BEFORE UPDATE OR DELETE ON time.attendance_overtime_candidates FOR EACH ROW EXECUTE FUNCTION time.prevent_overtime_mutation();
CREATE TRIGGER attendance_overtime_review_append_only BEFORE UPDATE OR DELETE ON time.attendance_overtime_review_events FOR EACH ROW EXECUTE FUNCTION time.prevent_overtime_mutation();

CREATE FUNCTION time.create_overtime_candidate_for_fact()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi time.work_instances%ROWTYPE; raw_n integer; candidate_n integer; latest_candidate uuid;
BEGIN
  SELECT * INTO wi FROM time.work_instances WHERE tenant_id=NEW.tenant_id AND id=NEW.work_instance_id FOR UPDATE;
  IF NOT FOUND THEN RETURN NEW; END IF;
  FOR latest_candidate IN
    SELECT c.id FROM time.attendance_overtime_candidates c
    WHERE c.tenant_id=NEW.tenant_id AND c.work_instance_id=NEW.work_instance_id
      AND NOT EXISTS(SELECT 1 FROM time.attendance_overtime_review_events r WHERE r.tenant_id=c.tenant_id AND r.candidate_id=c.id)
    FOR UPDATE
  LOOP
    INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id)
    VALUES(NEW.tenant_id,latest_candidate,'superseded','استُبدلت نتيجة الحضور بنسخة أحدث.',NEW.actor_user_id);
    INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
    VALUES(NEW.tenant_id,NEW.actor_user_id,'overtime.candidate.superseded',NEW.work_instance_id,jsonb_build_object('candidate_id',latest_candidate,'attendance_fact_id',NEW.id));
  END LOOP;
  IF NOT wi.overtime_enabled OR NEW.fact->>'outcome' IS DISTINCT FROM 'worked' THEN RETURN NEW; END IF;
  IF wi.schedule_kind='fixed' AND wi.expected_end IS NOT NULL AND NULLIF(NEW.fact->>'last_out','') IS NOT NULL THEN
    raw_n:=greatest(0,floor(extract(epoch FROM ((NEW.fact->>'last_out')::timestamptz-wi.expected_end))/60)::integer);
  ELSIF wi.schedule_kind='flexible' AND wi.required_minutes IS NOT NULL THEN
    raw_n:=greatest(0,coalesce(NULLIF(NEW.fact->>'worked_minutes','')::integer,0)-wi.required_minutes);
  ELSE RETURN NEW; END IF;
  IF raw_n<wi.overtime_minimum_minutes THEN RETURN NEW; END IF;
  candidate_n:=(raw_n/wi.overtime_rounding_minutes)*wi.overtime_rounding_minutes;
  IF candidate_n<=0 THEN RETURN NEW; END IF;
  INSERT INTO time.attendance_overtime_candidates(tenant_id,work_instance_id,attendance_fact_id,policy_template_id,policy_version,raw_minutes,candidate_minutes,category,actor_user_id)
  VALUES(NEW.tenant_id,NEW.work_instance_id,NEW.id,wi.policy_template_id,wi.policy_version,raw_n,candidate_n,'ordinary',NEW.actor_user_id);
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
  VALUES(NEW.tenant_id,NEW.actor_user_id,'overtime.candidate.created',NEW.work_instance_id,jsonb_build_object('attendance_fact_id',NEW.id,'raw_minutes',raw_n,'candidate_minutes',candidate_n,'category','ordinary','policy_template_id',wi.policy_template_id,'policy_version',wi.policy_version));
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION time.create_overtime_candidate_for_fact() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER attendance_fact_overtime_candidate AFTER INSERT ON time.attendance_facts
FOR EACH ROW EXECUTE FUNCTION time.create_overtime_candidate_for_fact();

CREATE FUNCTION public.review_attendance_overtime(p_tenant_id uuid,p_candidate_id uuid,p_decision text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); wi time.work_instances%ROWTYPE; c time.attendance_overtime_candidates%ROWTYPE; latest_fact uuid; event_id bigint;
BEGIN
  IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
     OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN
    RAISE EXCEPTION 'attendance_overtime_review_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_decision IS NULL OR p_decision NOT IN('approved','rejected') OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN
    RAISE EXCEPTION 'attendance_overtime_review_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO c FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND id=p_candidate_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'attendance_overtime_candidate_missing' USING ERRCODE='P0002'; END IF;
  SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=c.work_instance_id FOR UPDATE;
  SELECT * INTO c FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND id=p_candidate_id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM time.attendance_overtime_review_events r WHERE r.tenant_id=p_tenant_id AND r.candidate_id=p_candidate_id) THEN
    RAISE EXCEPTION 'attendance_overtime_already_reviewed' USING ERRCODE='23514';
  END IF;
  SELECT f.id INTO latest_fact FROM time.attendance_facts f WHERE f.tenant_id=p_tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1;
  IF latest_fact IS DISTINCT FROM c.attendance_fact_id OR wi.status<>'approved' THEN
    RAISE EXCEPTION 'attendance_overtime_candidate_stale' USING ERRCODE='40001';
  END IF;
  INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id)
  VALUES(p_tenant_id,p_candidate_id,p_decision,btrim(p_reason),actor) RETURNING id INTO event_id;
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
  VALUES(p_tenant_id,actor,'overtime.candidate.'||p_decision,c.work_instance_id,jsonb_build_object('candidate_id',p_candidate_id,'attendance_fact_id',c.attendance_fact_id,'candidate_minutes',c.candidate_minutes,'category',c.category,'reason',btrim(p_reason),'review_event_id',event_id));
  RETURN jsonb_build_object('candidate_id',p_candidate_id,'decision',p_decision,'candidate_minutes',c.candidate_minutes);
END $f$;
REVOKE ALL ON FUNCTION public.review_attendance_overtime(uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.review_attendance_overtime(uuid,uuid,text,text) TO authenticated;

CREATE FUNCTION public.attendance_overtime_instance_panel(p_tenant_id uuid,p_instance_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); base jsonb; items jsonb;
BEGIN
  base:=public.attendance_instance_detail(p_tenant_id,p_instance_id);
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',c.id,'attendance_fact_id',c.attendance_fact_id,'candidate_minutes',c.candidate_minutes,'raw_minutes',c.raw_minutes,'category',c.category,'created_at',c.created_at,'decision',coalesce(r.decision,'pending'),'reason',r.reason,'reviewed_at',r.created_at,'reviewer_id',r.actor_user_id) ORDER BY c.created_at DESC),'[]'::jsonb)
    INTO items FROM (SELECT * FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY created_at DESC LIMIT 50)c
    LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id;
  RETURN jsonb_build_object('items',items,'can_review',platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')));
END $f$;
REVOKE ALL ON FUNCTION public.attendance_overtime_instance_panel(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_overtime_instance_panel(uuid,uuid) TO authenticated;

CREATE FUNCTION public.attendance_overtime_day_summary(p_tenant_id uuid,p_operational_date date,p_instance_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); counts jsonb;
BEGIN
  IF actor IS NULL OR p_operational_date IS NULL OR coalesce(cardinality(p_instance_ids),0)>50
    OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN
    RAISE EXCEPTION 'attendance_overtime_day_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT coalesce(jsonb_object_agg(q.work_instance_id::text,q.pending_count),'{}'::jsonb) INTO counts FROM (
    SELECT c.work_instance_id,count(*)::integer pending_count FROM time.attendance_overtime_candidates c
    JOIN time.work_instances i ON i.tenant_id=c.tenant_id AND i.id=c.work_instance_id
    JOIN LATERAL(SELECT f.id FROM time.attendance_facts f WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1)latest ON latest.id=c.attendance_fact_id
    LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
    WHERE c.tenant_id=p_tenant_id AND i.operational_date=p_operational_date AND c.work_instance_id=ANY(coalesce(p_instance_ids,'{}'::uuid[])) AND r.id IS NULL AND i.status='approved'
    GROUP BY c.work_instance_id
  )q;
  RETURN jsonb_build_object('pending_by_instance',counts);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_overtime_day_summary(uuid,date,uuid[]) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_overtime_day_summary(uuid,date,uuid[]) TO authenticated;
