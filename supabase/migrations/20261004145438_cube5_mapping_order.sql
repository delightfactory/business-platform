ALTER TABLE time.channel_mappings ADD COLUMN revision bigint GENERATED ALWAYS AS IDENTITY;
REVOKE ALL ON SEQUENCE time.channel_mappings_revision_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION time.channel_process(p_tenant uuid,p_event uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ev time.channel_events%ROWTYPE; mapping time.channel_mappings%ROWTYPE; mapping_count integer;last_result time.channel_event_results%ROWTYPE;
 emp uuid;site uuid;employee_code text;site_name text;res jsonb;state text;reason text;instance uuid;punch uuid;canonical_key text;
BEGIN
 SELECT * INTO ev FROM time.channel_events WHERE tenant_id=p_tenant AND id=p_event FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO last_result FROM time.channel_event_results er WHERE er.tenant_id=p_tenant AND er.event_id=p_event AND er.state<>'duplicate' AND er.reason IS DISTINCT FROM 'conflict' ORDER BY er.id DESC LIMIT 1;
 IF EXISTS(SELECT 1 FROM time.channel_event_results er WHERE er.tenant_id=p_tenant AND er.event_id=p_event AND er.state IN('accepted','duplicate') AND canonical_punch_id IS NOT NULL) THEN
  INSERT INTO time.channel_replay_observations(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,p_event,'duplicate',p_actor);
  RETURN jsonb_build_object('state','duplicate','review',ev.review_required);
 END IF;
 IF last_result.state='rejected' THEN RETURN jsonb_build_object('state','rejected','reason',last_result.reason); END IF;
 INSERT INTO time.channel_event_results(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,p_event,'retrying',p_actor);
 emp:=ev.employee_id;site:=ev.site_id;canonical_key:='channel:'||ev.source_id::text||':'||ev.id::text;
 IF emp IS NULL THEN
  -- Latest decision for each explicit validity interval; different intervals remain historically applicable.
  WITH heads AS(SELECT DISTINCT ON(valid_from,valid_until) * FROM time.channel_mappings WHERE tenant_id=p_tenant AND source_id=ev.source_id AND external_key=ev.external_key ORDER BY valid_from,valid_until,revision DESC)
  SELECT count(*)::integer INTO mapping_count FROM heads WHERE active AND ev.happened_at>=valid_from AND (valid_until IS NULL OR ev.happened_at<valid_until);
  IF mapping_count=1 THEN
   WITH heads AS(SELECT DISTINCT ON(valid_from,valid_until) * FROM time.channel_mappings WHERE tenant_id=p_tenant AND source_id=ev.source_id AND external_key=ev.external_key ORDER BY valid_from,valid_until,revision DESC)
   SELECT * INTO mapping FROM heads WHERE active AND ev.happened_at>=valid_from AND (valid_until IS NULL OR ev.happened_at<valid_until);
   emp:=mapping.employee_id;site:=mapping.site_id;
  END IF;
 END IF;
 state:='unmapped';reason:=CASE WHEN mapping_count>1 THEN 'mapping_ambiguous' ELSE 'mapping' END;
 IF emp IS NOT NULL AND site IS NOT NULL THEN
  BEGIN
   SELECT e.employee_code INTO employee_code FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=emp;
   SELECT s.display_name INTO site_name FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant AND s.id=site AND s.is_active;
   IF ev.direction='unknown' THEN state:='retry_failed';reason:='interpretation';
   ELSE
    res:=time.attendance_import_resolve_row(p_tenant,jsonb_build_object('employee_code',employee_code,'site_name',site_name,'happened_at',to_char(ev.happened_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'direction',ev.direction,'source_event_key',canonical_key),true,p_actor);
    IF res->>'status'='ready' THEN
     instance:=(res->>'instance_id')::uuid;
     IF NOT EXISTS(SELECT 1 FROM time.work_instances WHERE tenant_id=p_tenant AND id=instance AND employee_id=emp AND site_id=site) THEN RAISE EXCEPTION 'channel_identity_mismatch'; END IF;
     INSERT INTO time.manual_punches(tenant_id,work_instance_id,direction,happened_at,request_key,payload_fingerprint,actor_user_id,source_type,source_event_key)
     VALUES(p_tenant,instance,ev.direction,ev.happened_at,gen_random_uuid(),res->>'fingerprint',p_actor,(SELECT kind FROM time.channel_sources WHERE tenant_id=p_tenant AND id=ev.source_id),canonical_key) RETURNING id INTO punch;
     PERFORM time.interpret_work_instance(p_tenant,instance,p_actor);
     INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
     VALUES(p_tenant,p_actor,'attendance.channel.accepted',instance,jsonb_build_object('source_id',ev.source_id,'channel_event_id',ev.id,'validation',ev.validation,'review_required',ev.review_required));
     state:='accepted';reason:=CASE WHEN ev.review_required THEN ev.validation END;
    ELSE state:='retry_failed';reason:='interpretation'; END IF;
   END IF;
  EXCEPTION WHEN OTHERS THEN state:='retry_failed';reason:='interpretation';instance:=NULL;punch:=NULL; END;
 END IF;
 INSERT INTO time.channel_event_results(tenant_id,event_id,state,reason,canonical_punch_id,work_instance_id,employee_id,site_id,actor_user_id)
 VALUES(p_tenant,p_event,state,reason,punch,instance,emp,site,p_actor);
 RETURN jsonb_build_object('state',state,'reason',reason,'review',ev.review_required);
END $f$;
