CREATE OR REPLACE FUNCTION public.save_time_work_policy(p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,p_before integer,p_after integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); template_id uuid; version_n integer;
BEGIN
 IF NOT time.has_policy_permission(p_tenant_id,actor) THEN RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_code IS NULL OR btrim(p_code)='' OR length(btrim(p_code))>32 OR p_name IS NULL OR btrim(p_name)='' OR length(btrim(p_name))>100
 OR p_kind IS NULL OR p_kind NOT IN('fixed','flexible') OR p_timezone IS NULL OR cardinality(p_work_days) NOT BETWEEN 1 AND 7
 OR p_before NOT BETWEEN 0 AND 720 OR p_after NOT BETWEEN 0 AND 720 OR p_break NOT BETWEEN 0 AND 360
 OR (p_required IS NOT NULL AND p_required NOT BETWEEN 60 AND 960) OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone)
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
 INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,required_minutes,earliest_punch,latest_punch,attribution_before_minutes,attribution_after_minutes,created_by)
 VALUES(p_tenant_id,template_id,version_n,btrim(p_name),p_kind,p_timezone,p_work_days,p_start,p_end,coalesce(p_next_day,false),p_break,p_required,p_earliest,p_latest,p_before,p_after,actor);
 INSERT INTO time.work_policy_audit_events(tenant_id,actor_user_id,event_key,template_id,version,details)
 VALUES(p_tenant_id,actor,CASE WHEN version_n=1 THEN 'policy.created' ELSE 'policy.versioned' END,template_id,version_n,jsonb_build_object('code',upper(btrim(p_code)),'name',btrim(p_name),'kind',p_kind));
 RETURN jsonb_build_object('id',template_id,'version',version_n);
END $f$;
REVOKE ALL ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer) TO authenticated;
