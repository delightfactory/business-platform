-- P1: bind pending capture to exact trusted work context; preserve same-link prior receipts.
ALTER TABLE time.channel_events ADD COLUMN capture_context jsonb;
CREATE OR REPLACE FUNCTION time.mobile_context(p_tenant uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE link people.employee_user_links%ROWTYPE;site uuid;site_name text;zone text;assignment uuid;employment uuid;policy uuid;policy_version integer;context jsonb;
src time.channel_sources%ROWTYPE;version time.channel_source_versions%ROWTYPE;reason text;next_dir text;scope text;history jsonb;
BEGIN
 IF NOT platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.self.capture') THEN RAISE EXCEPTION 'channel_self_forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO link FROM people.employee_user_links WHERE tenant_id=p_tenant AND user_id=auth.uid() AND unlinked_at IS NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('available',false,'reason','link','scope',p_tenant::text||':'||auth.uid()::text,'next_direction','in','geofence_required',false,'policy_version',0,'retention_seconds',60,'history','[]'::jsonb); END IF;
 SELECT a.site_id,s.display_name,v.timezone_name,a.id,e.id,v.template_id,v.version INTO site,site_name,zone,assignment,employment,policy,policy_version FROM people.work_assignments a
 JOIN people.employments e ON e.tenant_id=a.tenant_id AND e.id=a.employment_id
 JOIN people.employees emp ON emp.tenant_id=e.tenant_id AND emp.id=e.employee_id
 JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id AND s.is_active
 JOIN time.work_policy_versions base_policy ON base_policy.tenant_id=a.tenant_id AND base_policy.template_id=a.work_policy_template_id AND base_policy.version=a.work_policy_version
 LEFT JOIN LATERAL(SELECT o.policy_template_id,o.policy_version FROM time.work_policy_overrides o WHERE o.tenant_id=a.tenant_id AND o.employment_id=a.employment_id AND o.cancelled_at IS NULL
 AND o.valid_from<=(now() AT TIME ZONE base_policy.timezone_name)::date AND o.valid_until>(now() AT TIME ZONE base_policy.timezone_name)::date ORDER BY o.valid_from DESC LIMIT 1)override_policy ON true
 JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id AND v.template_id=coalesce(override_policy.policy_template_id,a.work_policy_template_id) AND v.version=coalesce(override_policy.policy_version,a.work_policy_version)
 WHERE a.tenant_id=p_tenant AND e.employee_id=link.employee_id AND emp.workforce_status='active'
 AND (now() AT TIME ZONE v.timezone_name)::date>=a.valid_from AND (a.valid_until IS NULL OR (now() AT TIME ZONE v.timezone_name)::date<a.valid_until)
 AND (now() AT TIME ZONE v.timezone_name)::date>=e.start_date AND (e.end_date IS NULL OR (now() AT TIME ZONE v.timezone_name)::date<=e.end_date)
 ORDER BY a.valid_from DESC,a.id DESC LIMIT 1;
 SELECT * INTO src FROM time.channel_sources WHERE tenant_id=p_tenant AND kind='mobile' AND site_id=site;
 SELECT * INTO version FROM time.channel_source_versions WHERE tenant_id=p_tenant AND source_id=src.id ORDER BY version DESC LIMIT 1;
 context:=jsonb_build_object('employee_id',link.employee_id,'employment_id',employment,'assignment_id',assignment,'site_id',site,'source_id',src.id,'work_policy_id',policy,'work_policy_version',policy_version);
 -- Source configuration version stays separate so a same-source version change remains policy_changed.
 scope:=p_tenant::text||':'||auth.uid()::text||':'||link.id::text||':'||md5(context::text);
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
 RETURN jsonb_build_object('scope',scope,'available',reason IS NULL,'reason',reason,'next_direction',coalesce(next_dir,'in'),'site_name',site_name,'timezone_name',zone,'source_id',src.id,'capture_context',context,
 'geofence_required',coalesce((version.config->>'geofence')::boolean,false),'policy_version',coalesce(version.version,0),'retention_seconds',coalesce((version.config->>'retention_seconds')::integer,60),'history',history);
END $f$;

CREATE OR REPLACE FUNCTION public.attendance_mobile_snapshot(p_tenant uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT time.mobile_context(p_tenant)-'source_id'-'capture_context';
$f$;

CREATE OR REPLACE FUNCTION public.attendance_mobile_punch(p_tenant uuid,p_attempt jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;selected_context jsonb;src uuid;version time.channel_source_versions%ROWTYPE;prior time.channel_events%ROWTYPE;link people.employee_user_links%ROWTYPE;
 aid uuid;happened timestamptz;direction text;requested_version integer;fp text;validation text;event_id uuid;res jsonb;BEGIN
 ctx:=time.mobile_context(p_tenant);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||auth.uid()::text,505));
 ctx:=time.mobile_context(p_tenant);
 IF (SELECT count(*) FROM time.mobile_capture_requests WHERE tenant_id=p_tenant AND actor_user_id=auth.uid() AND received_at>clock_timestamp()-interval '1 minute')>=20 THEN RETURN jsonb_build_object('state','blocked','reason','rate'); END IF;
 INSERT INTO time.mobile_capture_requests(tenant_id,actor_user_id) VALUES(p_tenant,auth.uid());
 IF p_attempt IS NULL OR pg_column_size(p_attempt)>4096 OR jsonb_typeof(p_attempt) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('state','rejected','reason','time'); END IF;
 BEGIN aid:=(p_attempt->>'id')::uuid;direction:=p_attempt->>'direction';happened:=(p_attempt->>'happened_at')::timestamptz;requested_version:=(p_attempt->>'policy_version')::integer;
 EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN RETURN jsonb_build_object('state','rejected','reason','time'); END;
 IF aid IS NULL OR direction IS NULL OR direction NOT IN('in','out') OR happened IS NULL OR NOT isfinite(happened) OR requested_version IS NULL OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_attempt) key WHERE key NOT IN('id','direction','happened_at','scope','policy_version','location')) THEN RETURN jsonb_build_object('state','rejected','reason','time'); END IF;
 SELECT * INTO link FROM people.employee_user_links WHERE tenant_id=p_tenant AND user_id=auth.uid() AND unlinked_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('state','blocked','reason','link'); END IF;
 fp:=md5(p_attempt::text);
 -- A legitimate receipt belongs to its stored context, even after the current assignment/source changes.
 SELECT * INTO prior FROM time.channel_events e WHERE e.tenant_id=p_tenant AND e.event_key=aid::text AND e.actor_user_id=auth.uid() AND e.link_id IS NOT NULL ORDER BY e.received_at,e.id LIMIT 1;
 IF FOUND THEN
  IF prior.link_id<>link.id OR prior.employee_id<>link.employee_id OR prior.scope IS DISTINCT FROM p_attempt->>'scope' THEN RETURN jsonb_build_object('state','blocked','reason','scope_changed'); END IF;
  IF prior.payload_fingerprint<>fp THEN RETURN jsonb_build_object('state','rejected','reason','conflict'); END IF;
  SELECT jsonb_build_object('state',CASE WHEN er.state='accepted' THEN 'duplicate' ELSE er.state END,'reason',er.reason,'review',prior.review_required,'next_direction',ctx->>'next_direction') INTO res
  FROM time.channel_event_results er WHERE er.tenant_id=p_tenant AND er.event_id=prior.id ORDER BY er.id DESC LIMIT 1;
  RETURN res;
 END IF;
 IF EXISTS(SELECT 1 FROM time.mobile_attempt_cancellations c WHERE c.tenant_id=p_tenant AND c.attempt_id=aid AND c.actor_user_id=auth.uid() AND c.scope=p_attempt->>'scope'
 AND split_part(c.scope,':',3)=link.id::text) THEN RETURN jsonb_build_object('state','rejected','reason','cancelled'); END IF;
 -- People mutations lock Employee/Employment before the effective Assignment.
 PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=link.employee_id FOR UPDATE;
 PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=link.employee_id ORDER BY e.start_date,e.id FOR UPDATE;
 ctx:=time.mobile_context(p_tenant);
 IF ctx->>'scope' IS DISTINCT FROM p_attempt->>'scope' THEN RETURN jsonb_build_object('state','rejected','reason','scope_changed'); END IF;
 IF NOT (ctx->>'available')::boolean THEN RETURN jsonb_build_object('state','blocked','reason',ctx->>'reason'); END IF;
 selected_context:=ctx->'capture_context';src:=(selected_context->>'source_id')::uuid;
 PERFORM 1 FROM people.work_assignments a WHERE a.tenant_id=p_tenant AND a.id=(selected_context->>'assignment_id')::uuid FOR UPDATE;
 PERFORM 1 FROM time.channel_sources s WHERE s.tenant_id=p_tenant AND s.id=src FOR UPDATE;
 -- Blocking row locks may expose committed changes: compare the whole selection, never mix old src with new ctx.
 ctx:=time.mobile_context(p_tenant);
 IF ctx->>'scope' IS DISTINCT FROM p_attempt->>'scope' OR ctx->'capture_context' IS DISTINCT FROM selected_context OR ctx->>'source_id' IS DISTINCT FROM src::text THEN RETURN jsonb_build_object('state','rejected','reason','scope_changed'); END IF;
 IF NOT (ctx->>'available')::boolean THEN RETURN jsonb_build_object('state','blocked','reason',ctx->>'reason'); END IF;
 SELECT * INTO version FROM time.channel_source_versions v WHERE v.tenant_id=p_tenant AND v.source_id=src ORDER BY v.version DESC LIMIT 1;
 IF version.version IS DISTINCT FROM requested_version OR version.version IS DISTINCT FROM (ctx->>'policy_version')::integer THEN RETURN jsonb_build_object('state','rejected','reason','policy_changed'); END IF;
 IF happened<now()-interval '10 minutes' OR happened>now()+interval '5 seconds' THEN RETURN jsonb_build_object('state','rejected','reason','time'); END IF;
 IF direction<>ctx->>'next_direction' THEN RETURN jsonb_build_object('state','rejected','reason','direction'); END IF;
 validation:=time.channel_geofence_result(version.config,p_attempt->'location',now());
 INSERT INTO time.channel_events(tenant_id,source_id,source_version,event_key,external_key,direction,happened_at,payload_fingerprint,actor_user_id,employee_id,site_id,link_id,scope,validation,review_required,capture_context)
 VALUES(p_tenant,src,version.version,aid::text,link.employee_id::text,direction,happened,fp,auth.uid(),link.employee_id,(selected_context->>'site_id')::uuid,link.id,p_attempt->>'scope',validation,validation NOT IN('inside','not_required') AND version.config->>'failure_action'='review',selected_context) RETURNING id INTO event_id;
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

CREATE OR REPLACE FUNCTION public.attendance_mobile_attempt(p_tenant uuid,p_attempt_id uuid,p_scope text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;link people.employee_user_links%ROWTYPE;ev time.channel_events%ROWTYPE;result jsonb;BEGIN
 ctx:=time.mobile_context(p_tenant);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||auth.uid()::text,505));
 ctx:=time.mobile_context(p_tenant);
 SELECT * INTO link FROM people.employee_user_links WHERE tenant_id=p_tenant AND user_id=auth.uid() AND unlinked_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('state','blocked','reason','link'); END IF;
 SELECT * INTO ev FROM time.channel_events e WHERE e.tenant_id=p_tenant AND e.event_key=p_attempt_id::text AND e.actor_user_id=auth.uid() AND e.link_id IS NOT NULL ORDER BY e.received_at,e.id LIMIT 1;
 IF FOUND THEN
  IF ev.link_id<>link.id OR ev.employee_id<>link.employee_id OR ev.scope IS DISTINCT FROM p_scope THEN RETURN jsonb_build_object('state','blocked','reason','scope_changed'); END IF;
  SELECT jsonb_build_object('state',r.state,'reason',r.reason,'review',ev.review_required,'next_direction',ctx->>'next_direction') INTO result
  FROM time.channel_event_results r WHERE r.tenant_id=p_tenant AND r.event_id=ev.id ORDER BY r.id DESC LIMIT 1;
  RETURN result;
 END IF;
 IF EXISTS(SELECT 1 FROM time.mobile_attempt_cancellations c WHERE c.tenant_id=p_tenant AND c.attempt_id=p_attempt_id AND c.actor_user_id=auth.uid() AND c.scope=p_scope AND split_part(c.scope,':',3)=link.id::text) THEN RETURN jsonb_build_object('state','rejected','reason','cancelled'); END IF;
 IF ctx->>'scope' IS DISTINCT FROM p_scope THEN RETURN jsonb_build_object('state','rejected','reason','scope_changed'); END IF;
 INSERT INTO time.mobile_attempt_cancellations(tenant_id,attempt_id,actor_user_id,scope) VALUES(p_tenant,p_attempt_id,auth.uid(),p_scope) ON CONFLICT DO NOTHING;
 RETURN jsonb_build_object('state','rejected','reason','cancelled');
END $f$;

REVOKE ALL ON FUNCTION time.mobile_context(uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.attendance_mobile_snapshot(uuid),public.attendance_mobile_punch(uuid,jsonb),public.attendance_mobile_attempt(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_mobile_snapshot(uuid),public.attendance_mobile_punch(uuid,jsonb),public.attendance_mobile_attempt(uuid,uuid,text) TO authenticated;
