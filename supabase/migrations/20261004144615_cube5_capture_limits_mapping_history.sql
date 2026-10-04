CREATE OR REPLACE FUNCTION public.attendance_channel_reprocess(p_tenant uuid,p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE enabled boolean; BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM 1 FROM time.channel_sources s JOIN time.channel_events e ON e.tenant_id=s.tenant_id AND e.source_id=s.id WHERE e.tenant_id=p_tenant AND e.id=p_event FOR UPDATE OF s;
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 SELECT v.enabled INTO enabled FROM time.channel_events e JOIN time.channel_sources s ON s.tenant_id=e.tenant_id AND s.id=e.source_id
 JOIN LATERAL(SELECT cv.enabled FROM time.channel_source_versions cv WHERE cv.tenant_id=s.tenant_id AND cv.source_id=s.id ORDER BY cv.version DESC LIMIT 1)v ON true WHERE e.tenant_id=p_tenant AND e.id=p_event;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 IF NOT enabled OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) THEN RETURN jsonb_build_object('state','blocked','reason','disabled'); END IF;
 RETURN time.channel_process(p_tenant,p_event,auth.uid());
END $f$;
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
  WITH heads AS(SELECT DISTINCT ON(valid_from,valid_until) * FROM time.channel_mappings WHERE tenant_id=p_tenant AND source_id=ev.source_id AND external_key=ev.external_key ORDER BY valid_from,valid_until,created_at DESC,id DESC)
  SELECT count(*)::integer INTO mapping_count FROM heads WHERE active AND ev.happened_at>=valid_from AND (valid_until IS NULL OR ev.happened_at<valid_until);
  IF mapping_count=1 THEN
   WITH heads AS(SELECT DISTINCT ON(valid_from,valid_until) * FROM time.channel_mappings WHERE tenant_id=p_tenant AND source_id=ev.source_id AND external_key=ev.external_key ORDER BY valid_from,valid_until,created_at DESC,id DESC)
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

CREATE TABLE time.mobile_capture_requests(
 tenant_id uuid NOT NULL,actor_user_id uuid NOT NULL REFERENCES auth.users(id),id bigint GENERATED ALWAYS AS IDENTITY,received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(tenant_id,id),FOREIGN KEY(tenant_id) REFERENCES platform_core.tenants(id)
);
CREATE INDEX mobile_capture_rate_idx ON time.mobile_capture_requests(tenant_id,actor_user_id,received_at DESC);
ALTER TABLE time.mobile_capture_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.mobile_capture_requests FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE time.mobile_capture_requests_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER mobile_capture_request_append_only BEFORE UPDATE OR DELETE ON time.mobile_capture_requests FOR EACH ROW EXECUTE FUNCTION time.prevent_attendance_mutation();

CREATE OR REPLACE FUNCTION public.attendance_mobile_punch(p_tenant uuid,p_attempt jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;src uuid;version time.channel_source_versions%ROWTYPE;prior time.channel_events%ROWTYPE;link people.employee_user_links%ROWTYPE;
 aid uuid;happened timestamptz;direction text;fp text;validation text;event_id uuid;res jsonb;BEGIN
 ctx:=time.mobile_context(p_tenant);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||auth.uid()::text,505));
 ctx:=time.mobile_context(p_tenant);
 IF (SELECT count(*) FROM time.mobile_capture_requests WHERE tenant_id=p_tenant AND actor_user_id=auth.uid() AND received_at>clock_timestamp()-interval '1 minute')>=20 THEN RETURN jsonb_build_object('state','blocked','reason','rate'); END IF;
 INSERT INTO time.mobile_capture_requests(tenant_id,actor_user_id) VALUES(p_tenant,auth.uid());
 IF p_attempt IS NULL OR pg_column_size(p_attempt)>4096 OR jsonb_typeof(p_attempt) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('state','rejected','reason','time'); END IF;
 BEGIN aid:=(p_attempt->>'id')::uuid;direction:=p_attempt->>'direction';happened:=(p_attempt->>'happened_at')::timestamptz;
 EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow THEN RETURN jsonb_build_object('state','rejected','reason','time'); END;
 IF aid IS NULL OR direction IS NULL OR direction NOT IN('in','out') OR happened IS NULL OR NOT isfinite(happened) OR jsonb_typeof(p_attempt)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_attempt) key WHERE key NOT IN('id','direction','happened_at','scope','policy_version','location')) THEN RETURN jsonb_build_object('state','rejected','reason','time'); END IF;
 IF ctx->>'scope' IS DISTINCT FROM p_attempt->>'scope' THEN RETURN jsonb_build_object('state','blocked','reason','scope_changed'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||auth.uid()::text,505));
 SELECT * INTO link FROM people.employee_user_links WHERE tenant_id=p_tenant AND user_id=auth.uid() AND unlinked_at IS NULL FOR UPDATE;
 ctx:=time.mobile_context(p_tenant);
 IF ctx->>'scope' IS DISTINCT FROM p_attempt->>'scope' THEN RETURN jsonb_build_object('state','blocked','reason','scope_changed'); END IF;
 IF EXISTS(SELECT 1 FROM time.mobile_attempt_cancellations WHERE tenant_id=p_tenant AND attempt_id=aid AND actor_user_id=auth.uid()) THEN RETURN jsonb_build_object('state','rejected','reason','cancelled'); END IF;
 fp:=md5(p_attempt::text);
 SELECT * INTO prior FROM time.channel_events WHERE tenant_id=p_tenant AND event_key=aid::text AND actor_user_id=auth.uid() AND scope=p_attempt->>'scope';
 IF FOUND THEN
  IF prior.payload_fingerprint<>fp THEN RETURN jsonb_build_object('state','rejected','reason','conflict'); END IF;
  SELECT jsonb_build_object('state',CASE WHEN state='accepted' THEN 'duplicate' ELSE state END,'reason',reason,'review',prior.review_required,'next_direction',ctx->>'next_direction') INTO res
  FROM time.channel_event_results er WHERE er.tenant_id=p_tenant AND er.event_id=prior.id ORDER BY er.id DESC LIMIT 1;
  RETURN res;
 END IF;
 IF NOT (ctx->>'available')::boolean THEN RETURN jsonb_build_object('state','blocked','reason',ctx->>'reason'); END IF;
 IF happened<now()-interval '10 minutes' OR happened>now()+interval '5 seconds' THEN RETURN jsonb_build_object('state','rejected','reason','time'); END IF;
 IF direction<>ctx->>'next_direction' THEN RETURN jsonb_build_object('state','rejected','reason','direction'); END IF;
 src:=(ctx->>'source_id')::uuid;
 PERFORM 1 FROM time.channel_sources WHERE tenant_id=p_tenant AND id=src FOR UPDATE;
 SELECT * INTO version FROM time.channel_source_versions WHERE tenant_id=p_tenant AND source_id=src ORDER BY version DESC LIMIT 1;
 ctx:=time.mobile_context(p_tenant);
 IF NOT (ctx->>'available')::boolean THEN RETURN jsonb_build_object('state','blocked','reason',ctx->>'reason'); END IF;
 IF version.version IS DISTINCT FROM (p_attempt->>'policy_version')::integer THEN RETURN jsonb_build_object('state','rejected','reason','policy_changed'); END IF;
 validation:=time.channel_geofence_result(version.config,p_attempt->'location',now());
 INSERT INTO time.channel_events(tenant_id,source_id,source_version,event_key,external_key,direction,happened_at,payload_fingerprint,actor_user_id,employee_id,site_id,link_id,scope,validation,review_required)
 VALUES(p_tenant,src,version.version,aid::text,link.employee_id::text,direction,happened,fp,auth.uid(),link.employee_id,(SELECT site_id FROM time.channel_sources WHERE tenant_id=p_tenant AND id=src),link.id,p_attempt->>'scope',validation,validation NOT IN('inside','not_required') AND version.config->>'failure_action'='review') RETURNING id INTO event_id;
 INSERT INTO time.channel_event_results(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,event_id,'received',auth.uid());
 IF (version.config->>'geofence')::boolean AND p_attempt->'location' IS NOT NULL AND p_attempt->'location'<>'null'::jsonb AND pg_column_size(p_attempt->'location')<=512 THEN
 INSERT INTO time.channel_location_evidence(tenant_id,event_id,evidence,expires_at) VALUES(p_tenant,event_id,p_attempt->'location',now()+make_interval(secs=>(version.config->>'retention_seconds')::double precision)); END IF;
 IF validation NOT IN('inside','not_required') AND version.config->>'failure_action'='reject' THEN
  INSERT INTO time.channel_event_results(tenant_id,event_id,state,reason,actor_user_id) VALUES(p_tenant,event_id,'rejected',validation,auth.uid());
  RETURN jsonb_build_object('state','rejected','reason',validation,'next_direction',ctx->>'next_direction');
 END IF;
 res:=time.channel_process(p_tenant,event_id,auth.uid());ctx:=time.mobile_context(p_tenant);
 RETURN res||jsonb_build_object('next_direction',ctx->>'next_direction');
END $f$;

