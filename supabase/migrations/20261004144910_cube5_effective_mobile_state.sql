CREATE OR REPLACE FUNCTION time.mobile_context(p_tenant uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE link people.employee_user_links%ROWTYPE;site uuid;site_name text;zone text;src time.channel_sources%ROWTYPE;version time.channel_source_versions%ROWTYPE;reason text;next_dir text;scope text;history jsonb;
BEGIN
 IF NOT platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.self.capture') THEN RAISE EXCEPTION 'channel_self_forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO link FROM people.employee_user_links WHERE tenant_id=p_tenant AND user_id=auth.uid() AND unlinked_at IS NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('available',false,'reason','link','scope',p_tenant::text||':'||auth.uid()::text,'next_direction','in','geofence_required',false,'policy_version',0,'retention_seconds',60,'history','[]'::jsonb); END IF;
 SELECT a.site_id,s.display_name,v.timezone_name INTO site,site_name,zone FROM people.work_assignments a
 JOIN people.employments e ON e.tenant_id=a.tenant_id AND e.id=a.employment_id
 JOIN people.employees emp ON emp.tenant_id=e.tenant_id AND emp.id=e.employee_id
 JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id AND s.is_active
 JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id AND v.template_id=a.work_policy_template_id AND v.version=a.work_policy_version
 WHERE a.tenant_id=p_tenant AND e.employee_id=link.employee_id AND emp.workforce_status='active'
 AND (now() AT TIME ZONE v.timezone_name)::date>=a.valid_from AND (a.valid_until IS NULL OR (now() AT TIME ZONE v.timezone_name)::date<a.valid_until)
 AND (now() AT TIME ZONE v.timezone_name)::date>=e.start_date AND (e.end_date IS NULL OR (now() AT TIME ZONE v.timezone_name)::date<=e.end_date)
 ORDER BY a.valid_from DESC LIMIT 1;
 SELECT * INTO src FROM time.channel_sources WHERE tenant_id=p_tenant AND kind='mobile' AND site_id=site;
 SELECT * INTO version FROM time.channel_source_versions WHERE tenant_id=p_tenant AND source_id=src.id ORDER BY version DESC LIMIT 1;
 scope:=p_tenant::text||':'||auth.uid()::text||':'||link.id::text;
 SELECT CASE WHEN coalesce(c.new_direction,p.direction)='in' THEN 'out' ELSE 'in' END INTO next_dir FROM time.manual_punches p JOIN time.work_instances i ON i.tenant_id=p.tenant_id AND i.id=p.work_instance_id
 LEFT JOIN LATERAL(SELECT pc.new_direction,pc.new_happened_at FROM time.punch_corrections pc WHERE pc.tenant_id=p.tenant_id AND pc.punch_id=p.id AND pc.action='replace' ORDER BY pc.created_at DESC,pc.id DESC LIMIT 1)c ON true
 WHERE i.tenant_id=p_tenant AND i.employee_id=link.employee_id AND now() BETWEEN i.attribution_start AND i.attribution_end
 AND NOT EXISTS(SELECT 1 FROM time.punch_corrections c WHERE c.tenant_id=p.tenant_id AND c.punch_id=p.id AND c.action='exclude') ORDER BY coalesce(c.new_happened_at,p.happened_at) DESC,p.id DESC LIMIT 1;
 reason:=CASE WHEN site IS NULL THEN 'assignment' WHEN src.id IS NULL OR version.version IS NULL THEN 'unconfigured' WHEN NOT version.enabled THEN 'disabled'
 WHEN NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',now()) OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) THEN 'entitlement' END;
 SELECT coalesce(jsonb_agg(to_jsonb(h) ORDER BY h.received_at DESC,h.id DESC),'[]'::jsonb) INTO history FROM (
 SELECT e.id,e.direction,e.happened_at,e.received_at,r.state,r.reason,wi.timezone_name FROM time.channel_events e
 JOIN LATERAL(SELECT er.state,er.reason FROM time.channel_event_results er WHERE er.tenant_id=e.tenant_id AND er.event_id=e.id ORDER BY er.id DESC LIMIT 1)r ON true
 LEFT JOIN LATERAL(SELECT i.timezone_name FROM time.channel_event_results cr JOIN time.work_instances i ON i.tenant_id=cr.tenant_id AND i.id=cr.work_instance_id WHERE cr.tenant_id=e.tenant_id AND cr.event_id=e.id ORDER BY cr.id DESC LIMIT 1)wi ON true
 WHERE e.tenant_id=p_tenant AND e.employee_id=link.employee_id AND e.actor_user_id=auth.uid() ORDER BY e.received_at DESC,e.id DESC LIMIT 20)h;
 RETURN jsonb_build_object('scope',scope,'available',reason IS NULL,'reason',reason,'next_direction',coalesce(next_dir,'in'),'site_name',site_name,'timezone_name',zone,'source_id',src.id,
 'geofence_required',coalesce((version.config->>'geofence')::boolean,false),'policy_version',coalesce(version.version,0),'retention_seconds',coalesce((version.config->>'retention_seconds')::integer,60),'history',history);
END $f$;
CREATE OR REPLACE FUNCTION public.attendance_channel_event_detail(p_tenant uuid,p_event uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE result jsonb;BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('id',e.id,'source_id',e.source_id,'source_name',s.name,'kind',s.kind,'external_key',CASE WHEN time.channel_operator_can(p_tenant,true) THEN e.external_key END,
 'event_key',CASE WHEN time.channel_operator_can(p_tenant,true) THEN e.event_key END,'direction',e.direction,'happened_at',e.happened_at,'received_at',e.received_at,'validation',e.validation,'source_version',e.source_version,'review_required',e.review_required AND NOT EXISTS(SELECT 1 FROM time.channel_review_decisions d WHERE d.tenant_id=e.tenant_id AND d.event_id=e.id),
 'replays',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id DESC),'[]'::jsonb) FROM(SELECT id,state,created_at FROM time.channel_replay_observations WHERE tenant_id=p_tenant AND event_id=p_event ORDER BY id DESC LIMIT 20)x),
 'results',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id DESC),'[]'::jsonb) FROM(SELECT id,state,reason,canonical_punch_id,work_instance_id,created_at FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event ORDER BY id DESC LIMIT 20)x)) INTO result
 FROM time.channel_events e JOIN time.channel_sources s ON s.tenant_id=e.tenant_id AND s.id=e.source_id WHERE e.tenant_id=p_tenant AND e.id=p_event;
 IF result IS NULL THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 RETURN result;
END $f$;
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
 IF (version.config->>'geofence')::boolean AND p_attempt->'location' IS NOT NULL AND p_attempt->'location'<>'null'::jsonb AND pg_column_size(p_attempt->'location')<=512
 AND jsonb_typeof(p_attempt->'location'->'latitude')='number' AND jsonb_typeof(p_attempt->'location'->'longitude')='number' AND jsonb_typeof(p_attempt->'location'->'accuracy')='number' AND jsonb_typeof(p_attempt->'location'->'captured_at')='string'
 AND NOT EXISTS(SELECT 1 FROM jsonb_object_keys(p_attempt->'location') key WHERE key NOT IN('latitude','longitude','accuracy','captured_at')) THEN
 INSERT INTO time.channel_location_evidence(tenant_id,event_id,evidence,expires_at) VALUES(p_tenant,event_id,p_attempt->'location',now()+make_interval(secs=>(version.config->>'retention_seconds')::double precision)); END IF;
 IF validation NOT IN('inside','not_required') AND version.config->>'failure_action'='reject' THEN
  INSERT INTO time.channel_event_results(tenant_id,event_id,state,reason,actor_user_id) VALUES(p_tenant,event_id,'rejected',validation,auth.uid());
  RETURN jsonb_build_object('state','rejected','reason',validation,'next_direction',ctx->>'next_direction');
 END IF;
 res:=time.channel_process(p_tenant,event_id,auth.uid());ctx:=time.mobile_context(p_tenant);
 RETURN res||jsonb_build_object('next_direction',ctx->>'next_direction');
END $f$;

CREATE FUNCTION public.attendance_channel_mappings(p_tenant uuid,p_source uuid,p_limit integer DEFAULT 20,p_offset integer DEFAULT 0) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE items jsonb;more boolean;BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 1000000 THEN RAISE EXCEPTION 'channel_page_invalid' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM time.channel_sources WHERE tenant_id=p_tenant AND id=p_source) THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='P0002'; END IF;
 WITH page AS(SELECT * FROM time.channel_mappings WHERE tenant_id=p_tenant AND source_id=p_source ORDER BY created_at DESC,id DESC LIMIT p_limit+1 OFFSET p_offset),list AS(SELECT * FROM page ORDER BY created_at DESC,id DESC LIMIT p_limit)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',m.id,'external_key',m.external_key,'employee_id',m.employee_id,'employee_name',e.full_name,'site_id',m.site_id,'site_name',s.display_name,'valid_from',m.valid_from,'valid_until',m.valid_until,'active',m.active,'created_at',m.created_at) ORDER BY m.created_at DESC,m.id DESC),'[]'::jsonb),(SELECT count(*)>p_limit FROM page) INTO items,more
 FROM list m JOIN people.employees e ON e.tenant_id=m.tenant_id AND e.id=m.employee_id JOIN platform_core.tenant_sites s ON s.tenant_id=m.tenant_id AND s.id=m.site_id;
 RETURN jsonb_build_object('items',items,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_mappings(uuid,uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_mappings(uuid,uuid,integer,integer) TO authenticated;
