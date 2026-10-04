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
 SELECT CASE WHEN p.direction='in' THEN 'out' ELSE 'in' END INTO next_dir FROM time.manual_punches p JOIN time.work_instances i ON i.tenant_id=p.tenant_id AND i.id=p.work_instance_id
 WHERE i.tenant_id=p_tenant AND i.employee_id=link.employee_id AND now() BETWEEN i.attribution_start AND i.attribution_end
 AND NOT EXISTS(SELECT 1 FROM time.punch_corrections c WHERE c.tenant_id=p.tenant_id AND c.punch_id=p.id AND c.action='exclude') ORDER BY p.happened_at DESC,p.id DESC LIMIT 1;
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

-- Bounded read surfaces remain available after source/entitlement disablement.
CREATE FUNCTION public.attendance_channel_access(p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('can_view',true,'can_manage',time.channel_operator_can(p_tenant,true),'can_review',platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.correct') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer'),'capture_enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()));
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_access(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_access(uuid) TO authenticated;

CREATE FUNCTION public.attendance_channel_sources(p_tenant uuid,p_limit integer DEFAULT 20,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE items jsonb;more boolean; BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 1000000 THEN RAISE EXCEPTION 'channel_page_invalid' USING ERRCODE='22023'; END IF;
 WITH page AS(SELECT s.* FROM time.channel_sources s WHERE s.tenant_id=p_tenant ORDER BY s.created_at DESC,s.id DESC LIMIT p_limit+1 OFFSET p_offset),list AS(SELECT * FROM page ORDER BY created_at DESC,id DESC LIMIT p_limit)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'kind',s.kind,'site_name',site.display_name,'enabled',v.enabled,'version',v.version,
 'last_success',health.last_success,'last_failure',health.last_failure,'unmapped_count',health.unmapped_count,'retry_count',health.retry_count,'review_count',health.review_count) ORDER BY s.created_at DESC,s.id DESC),'[]'::jsonb),(SELECT count(*)>p_limit FROM page) INTO items,more
 FROM list s LEFT JOIN platform_core.tenant_sites site ON site.tenant_id=s.tenant_id AND site.id=s.site_id
 LEFT JOIN LATERAL(SELECT enabled,version FROM time.channel_source_versions WHERE tenant_id=s.tenant_id AND source_id=s.id ORDER BY version DESC LIMIT 1)v ON true
 LEFT JOIN LATERAL(SELECT max(r.created_at) FILTER(WHERE r.state='accepted') last_success,max(r.created_at) FILTER(WHERE r.state IN('rejected','retry_failed')) last_failure,count(*) FILTER(WHERE r.state='unmapped') unmapped_count,count(*) FILTER(WHERE r.state IN('received','retrying','retry_failed')) retry_count,count(*) FILTER(WHERE e.review_required AND NOT EXISTS(SELECT 1 FROM time.channel_review_decisions d WHERE d.tenant_id=e.tenant_id AND d.event_id=e.id)) review_count
 FROM time.channel_events e JOIN LATERAL(SELECT state,created_at FROM time.channel_event_results WHERE tenant_id=e.tenant_id AND event_id=e.id AND state<>'duplicate' AND reason IS DISTINCT FROM 'conflict' ORDER BY id DESC LIMIT 1)r ON true WHERE e.tenant_id=s.tenant_id AND e.source_id=s.id)health ON true;
 RETURN jsonb_build_object('items',items,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_sources(uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_sources(uuid,integer,integer) TO authenticated;

CREATE FUNCTION public.attendance_channel_events(p_tenant uuid,p_source uuid,p_limit integer DEFAULT 20,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE items jsonb;more boolean; BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 1000000 THEN RAISE EXCEPTION 'channel_page_invalid' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM time.channel_sources WHERE tenant_id=p_tenant AND id=p_source) THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='P0002'; END IF;
 WITH page AS(SELECT * FROM time.channel_events WHERE tenant_id=p_tenant AND source_id=p_source ORDER BY received_at DESC,id DESC LIMIT p_limit+1 OFFSET p_offset),list AS(SELECT * FROM page ORDER BY received_at DESC,id DESC LIMIT p_limit)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'direction',e.direction,'happened_at',e.happened_at,'received_at',e.received_at,'state',r.state,'reason',r.reason,'employee_name',emp.full_name,'review_required',e.review_required AND NOT EXISTS(SELECT 1 FROM time.channel_review_decisions d WHERE d.tenant_id=e.tenant_id AND d.event_id=e.id),'work_instance_id',r.work_instance_id,'timezone_name',wi.timezone_name) ORDER BY e.received_at DESC,e.id DESC),'[]'::jsonb),(SELECT count(*)>p_limit FROM page) INTO items,more
 FROM list e JOIN LATERAL(SELECT * FROM time.channel_event_results WHERE tenant_id=e.tenant_id AND event_id=e.id AND state<>'duplicate' AND reason IS DISTINCT FROM 'conflict' ORDER BY id DESC LIMIT 1)r ON true
 LEFT JOIN people.employees emp ON emp.tenant_id=e.tenant_id AND emp.id=coalesce(r.employee_id,e.employee_id)
 LEFT JOIN time.work_instances wi ON wi.tenant_id=r.tenant_id AND wi.id=r.work_instance_id;
 RETURN jsonb_build_object('items',items,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_events(uuid,uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_events(uuid,uuid,integer,integer) TO authenticated;

CREATE TABLE time.channel_review_decisions(
 tenant_id uuid NOT NULL,event_id uuid NOT NULL,decision text NOT NULL CHECK(decision IN('accept','exclude')),reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 3 AND 500),actor_user_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,event_id),FOREIGN KEY(tenant_id,event_id) REFERENCES time.channel_events(tenant_id,id)
);
ALTER TABLE time.channel_review_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.channel_review_decisions FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER channel_review_append_only BEFORE UPDATE OR DELETE ON time.channel_review_decisions FOR EACH ROW EXECUTE FUNCTION time.prevent_attendance_mutation();

CREATE FUNCTION time.has_unresolved_channel_review(p_tenant uuid,p_instance uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT EXISTS(SELECT 1 FROM time.manual_punches p JOIN time.channel_events e ON e.tenant_id=p.tenant_id AND p.source_event_key='channel:'||e.source_id::text||':'||e.id::text
 WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance AND e.review_required
 AND NOT EXISTS(SELECT 1 FROM time.channel_review_decisions d WHERE d.tenant_id=e.tenant_id AND d.event_id=e.id)
 AND NOT EXISTS(SELECT 1 FROM time.punch_corrections c WHERE c.tenant_id=p.tenant_id AND c.punch_id=p.id AND c.action='exclude'));
$f$;
REVOKE ALL ON FUNCTION time.has_unresolved_channel_review(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION time.mark_channel_review_interpretation() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF time.has_unresolved_channel_review(NEW.tenant_id,NEW.work_instance_id) THEN NEW.state:='needs_review';NEW.exception_code:='channel_location_review';NEW.owner_permission:='attendance.correct'; END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION time.mark_channel_review_interpretation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER zz_channel_review_before_interpretation BEFORE INSERT ON time.interpretations FOR EACH ROW EXECUTE FUNCTION time.mark_channel_review_interpretation();
CREATE FUNCTION time.guard_channel_review_fact() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF time.has_unresolved_channel_review(NEW.tenant_id,NEW.work_instance_id) THEN RAISE EXCEPTION 'attendance_channel_review_required' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION time.guard_channel_review_fact() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER zz_channel_review_before_fact BEFORE INSERT ON time.attendance_facts FOR EACH ROW EXECUTE FUNCTION time.guard_channel_review_fact();

CREATE FUNCTION public.attendance_channel_review(p_tenant uuid,p_event uuid,p_decision text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ev time.channel_events%ROWTYPE;punch uuid;instance uuid;BEGIN
 IF NOT (platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.correct') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'channel_review_forbidden' USING ERRCODE='42501'; END IF;
 IF p_decision IS NULL OR p_decision NOT IN('accept','exclude') OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'channel_review_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO ev FROM time.channel_events WHERE tenant_id=p_tenant AND id=p_event FOR UPDATE;
 IF NOT FOUND OR NOT ev.review_required THEN RAISE EXCEPTION 'channel_review_not_found' USING ERRCODE='P0002'; END IF;
 IF EXISTS(SELECT 1 FROM time.channel_review_decisions WHERE tenant_id=p_tenant AND event_id=p_event) THEN RETURN jsonb_build_object('state','unchanged'); END IF;
 SELECT canonical_punch_id,work_instance_id INTO punch,instance FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event AND canonical_punch_id IS NOT NULL ORDER BY id DESC LIMIT 1;
 IF punch IS NULL THEN RAISE EXCEPTION 'channel_review_not_ready' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM time.work_instances WHERE tenant_id=p_tenant AND id=instance FOR UPDATE;
 INSERT INTO time.channel_review_decisions(tenant_id,event_id,decision,reason,actor_user_id) VALUES(p_tenant,p_event,p_decision,btrim(p_reason),auth.uid());
 IF p_decision='exclude' THEN PERFORM public.correct_manual_attendance_punch(p_tenant,instance,punch,'exclude',NULL,NULL,p_reason);
 ELSE PERFORM time.interpret_work_instance(p_tenant,instance,auth.uid()); END IF;
 RETURN jsonb_build_object('state','reviewed','work_instance_id',instance);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_review(uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_review(uuid,uuid,text,text) TO authenticated;

CREATE FUNCTION public.attendance_channel_source_detail(p_tenant uuid,p_source uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE result jsonb;BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('id',s.id,'name',s.name,'kind',s.kind,'site_id',s.site_id,'site_name',site.display_name,'enabled',v.enabled,'version',v.version,'config',CASE WHEN time.channel_operator_can(p_tenant,true) THEN v.config ELSE NULL END,
 'versions',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.version DESC),'[]'::jsonb) FROM(SELECT version,enabled,reason,created_at FROM time.channel_source_versions WHERE tenant_id=p_tenant AND source_id=p_source ORDER BY version DESC LIMIT 10)x)) INTO result
 FROM time.channel_sources s JOIN LATERAL(SELECT * FROM time.channel_source_versions WHERE tenant_id=s.tenant_id AND source_id=s.id ORDER BY version DESC LIMIT 1)v ON true
 LEFT JOIN platform_core.tenant_sites site ON site.tenant_id=s.tenant_id AND site.id=s.site_id WHERE s.tenant_id=p_tenant AND s.id=p_source;
 IF result IS NULL THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='P0002'; END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_source_detail(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_source_detail(uuid,uuid) TO authenticated;

CREATE FUNCTION public.attendance_channel_event_detail(p_tenant uuid,p_event uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE result jsonb;BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('id',e.id,'source_id',e.source_id,'source_name',s.name,'kind',s.kind,'external_key',CASE WHEN time.channel_operator_can(p_tenant,true) THEN e.external_key END,
 'event_key',CASE WHEN time.channel_operator_can(p_tenant,true) THEN e.event_key END,'direction',e.direction,'happened_at',e.happened_at,'received_at',e.received_at,'validation',e.validation,'source_version',e.source_version,'review_required',e.review_required AND NOT EXISTS(SELECT 1 FROM time.channel_review_decisions d WHERE d.tenant_id=e.tenant_id AND d.event_id=e.id),
 'results',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id DESC),'[]'::jsonb) FROM(SELECT id,state,reason,canonical_punch_id,work_instance_id,created_at FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event ORDER BY id DESC LIMIT 20)x)) INTO result
 FROM time.channel_events e JOIN time.channel_sources s ON s.tenant_id=e.tenant_id AND s.id=e.source_id WHERE e.tenant_id=p_tenant AND e.id=p_event;
 IF result IS NULL THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_event_detail(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_event_detail(uuid,uuid) TO authenticated;

CREATE FUNCTION public.attendance_channel_options(p_tenant uuid,p_search text DEFAULT '',p_limit integer DEFAULT 20) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE employees jsonb;sites jsonb;BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 OR p_search IS NULL OR length(p_search)>100 THEN RAISE EXCEPTION 'channel_page_invalid' USING ERRCODE='22023'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.full_name,e.id),'[]'::jsonb) INTO employees FROM(SELECT id,full_name,employee_code FROM people.employees WHERE tenant_id=p_tenant AND (p_search='' OR full_name ILIKE '%'||p_search||'%' OR employee_code ILIKE '%'||p_search||'%') ORDER BY full_name,id LIMIT p_limit)e;
 SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.display_name,s.id),'[]'::jsonb) INTO sites FROM(SELECT id,display_name FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND is_active AND (p_search='' OR display_name ILIKE '%'||p_search||'%') ORDER BY display_name,id LIMIT p_limit)s;
 RETURN jsonb_build_object('employees',employees,'sites',sites,'limited',true);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_options(uuid,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_options(uuid,text,integer) TO authenticated;
CREATE TABLE time.channel_replay_observations(
 tenant_id uuid NOT NULL,event_id uuid NOT NULL,id bigint GENERATED ALWAYS AS IDENTITY,state text NOT NULL CHECK(state IN('duplicate','conflict')),actor_user_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),FOREIGN KEY(tenant_id,event_id) REFERENCES time.channel_events(tenant_id,id)
);
ALTER TABLE time.channel_replay_observations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.channel_replay_observations FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE time.channel_replay_observations_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER channel_replay_append_only BEFORE UPDATE OR DELETE ON time.channel_replay_observations FOR EACH ROW EXECUTE FUNCTION time.prevent_attendance_mutation();

CREATE OR REPLACE FUNCTION time.validate_channel_config(p_kind text,p_config jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE k text; BEGIN
 IF jsonb_typeof(p_config) IS DISTINCT FROM 'object' OR p_config IS NULL THEN RETURN false; END IF;
 IF p_kind='external' THEN RETURN p_config='{}'::jsonb; END IF;
 IF p_kind IS DISTINCT FROM 'mobile' OR jsonb_typeof(p_config->'geofence') IS DISTINCT FROM 'boolean' OR jsonb_typeof(p_config->'retention_seconds') IS DISTINCT FROM 'number'
 OR (p_config->>'retention_seconds')::numeric NOT BETWEEN 60 AND 2592000 OR (p_config->>'retention_seconds')::numeric<>trunc((p_config->>'retention_seconds')::numeric) THEN RETURN false; END IF;
 IF NOT (p_config->>'geofence')::boolean THEN RETURN NOT EXISTS(SELECT 1 FROM jsonb_object_keys(p_config) key WHERE key NOT IN ('geofence','retention_seconds')); END IF;
 FOREACH k IN ARRAY ARRAY['latitude','longitude','radius_m','tolerance_m','max_accuracy_m','max_age_seconds'] LOOP
  IF jsonb_typeof(p_config->k) IS DISTINCT FROM 'number' THEN RETURN false; END IF;
 END LOOP;
 RETURN coalesce((p_config->>'latitude')::numeric BETWEEN -90 AND 90 AND (p_config->>'longitude')::numeric BETWEEN -180 AND 180
 AND (p_config->>'radius_m')::numeric BETWEEN 10 AND 10000 AND (p_config->>'tolerance_m')::numeric BETWEEN 0 AND 500
 AND (p_config->>'max_accuracy_m')::numeric BETWEEN 1 AND 500 AND (p_config->>'max_age_seconds')::numeric BETWEEN 5 AND 600
 AND p_config->>'failure_action' IN('reject','review') AND NOT EXISTS(SELECT 1 FROM jsonb_object_keys(p_config) key WHERE key NOT IN('geofence','retention_seconds','latitude','longitude','radius_m','tolerance_m','max_accuracy_m','max_age_seconds','failure_action')),false);
EXCEPTION WHEN OTHERS THEN RETURN false; END $f$;
CREATE OR REPLACE FUNCTION time.channel_geofence_result(p_config jsonb,p_evidence jsonb,p_at timestamptz)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE lat double precision; lon double precision; acc double precision; captured timestamptz; distance double precision; BEGIN
 IF NOT (p_config->>'geofence')::boolean THEN RETURN 'not_required'; END IF;
 IF p_evidence IS NULL OR p_evidence='null'::jsonb THEN RETURN 'unavailable'; END IF;
 IF jsonb_typeof(p_evidence) IS DISTINCT FROM 'object' OR jsonb_typeof(p_evidence->'latitude') IS DISTINCT FROM 'number' OR jsonb_typeof(p_evidence->'longitude') IS DISTINCT FROM 'number' OR jsonb_typeof(p_evidence->'accuracy') IS DISTINCT FROM 'number' OR jsonb_typeof(p_evidence->'captured_at') IS DISTINCT FROM 'string' OR NOT p_evidence ?& ARRAY['latitude','longitude','accuracy','captured_at']
 OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_evidence) key WHERE key NOT IN ('latitude','longitude','accuracy','captured_at')) THEN RETURN 'unavailable'; END IF;
 lat:=(p_evidence->>'latitude')::double precision;lon:=(p_evidence->>'longitude')::double precision;acc:=(p_evidence->>'accuracy')::double precision;captured:=(p_evidence->>'captured_at')::timestamptz;
 IF lat NOT BETWEEN -90 AND 90 OR lon NOT BETWEEN -180 AND 180 OR acc NOT BETWEEN 0 AND 100000 OR captured IS NULL THEN RETURN 'unavailable'; END IF;
 IF captured>p_at+interval '5 seconds' OR captured<p_at-make_interval(secs=>(p_config->>'max_age_seconds')::double precision) THEN RETURN 'stale'; END IF;
 IF acc>(p_config->>'max_accuracy_m')::double precision THEN RETURN 'accuracy'; END IF;
 distance:=6371000*2*asin(sqrt(least(1.0,power(sin(radians(lat-(p_config->>'latitude')::double precision)/2),2)+cos(radians(lat))*cos(radians((p_config->>'latitude')::double precision))*power(sin(radians(lon-(p_config->>'longitude')::double precision)/2),2))));
 IF distance>(p_config->>'radius_m')::double precision+(p_config->>'tolerance_m')::double precision THEN RETURN 'outside'; END IF;
 RETURN 'inside';
EXCEPTION WHEN OTHERS THEN RETURN 'unavailable'; END $f$;
CREATE OR REPLACE FUNCTION public.attendance_channel_save_source(p_tenant uuid,p_source uuid,p_name text,p_kind text,p_site uuid,p_enabled boolean,p_config jsonb,p_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE src time.channel_sources%ROWTYPE; version_no integer; BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_enabled IS NULL OR p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 2 AND 100 OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 OR NOT coalesce(time.validate_channel_config(p_kind,p_config),false) THEN RAISE EXCEPTION 'channel_config_invalid' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_enabled AND NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) THEN RAISE EXCEPTION 'channel_entitlement_disabled' USING ERRCODE='42501'; END IF;
 IF p_site IS NOT NULL AND NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND id=p_site AND is_active) THEN RAISE EXCEPTION 'channel_site_invalid' USING ERRCODE='22023'; END IF;
 IF p_source IS NULL THEN
  INSERT INTO time.channel_sources(tenant_id,name,kind,site_id,created_by) VALUES(p_tenant,btrim(p_name),p_kind,p_site,auth.uid()) RETURNING * INTO src;
 ELSE
  SELECT * INTO src FROM time.channel_sources WHERE tenant_id=p_tenant AND id=p_source FOR UPDATE;
  IF NOT FOUND OR src.kind<>p_kind OR src.site_id IS DISTINCT FROM p_site OR src.name<>btrim(p_name) THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='22023'; END IF;
 END IF;
 SELECT coalesce(max(version),0)+1 INTO version_no FROM time.channel_source_versions WHERE tenant_id=p_tenant AND source_id=src.id;
 INSERT INTO time.channel_source_versions(tenant_id,source_id,version,enabled,config,reason,actor_user_id) VALUES(p_tenant,src.id,version_no,p_enabled,p_config,btrim(p_reason),auth.uid());
 RETURN src.id;
END $f$;
CREATE OR REPLACE FUNCTION public.attendance_channel_map(p_tenant uuid,p_source uuid,p_external_key text,p_employee uuid,p_site uuid,p_valid_from timestamptz,p_valid_until timestamptz,p_active boolean)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE result uuid; BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_external_key IS NULL OR length(btrim(p_external_key)) NOT BETWEEN 1 AND 100 OR p_valid_from IS NULL OR p_active IS NULL OR (p_valid_until IS NOT NULL AND p_valid_until<=p_valid_from) THEN RAISE EXCEPTION 'channel_mapping_invalid' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM 1 FROM time.channel_sources WHERE tenant_id=p_tenant AND id=p_source AND kind='external' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='22023'; END IF;
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee) OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND id=p_site AND is_active) THEN RAISE EXCEPTION 'channel_mapping_scope_invalid' USING ERRCODE='22023'; END IF;
 INSERT INTO time.channel_mappings(tenant_id,source_id,external_key,employee_id,site_id,valid_from,valid_until,active,actor_user_id)
 VALUES(p_tenant,p_source,btrim(p_external_key),p_employee,p_site,p_valid_from,p_valid_until,p_active,auth.uid()) RETURNING id INTO result;
 RETURN result;
END $f$;
CREATE OR REPLACE FUNCTION time.channel_process(p_tenant uuid,p_event uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ev time.channel_events%ROWTYPE; mapping time.channel_mappings%ROWTYPE; last_result time.channel_event_results%ROWTYPE;
 emp uuid;site uuid;employee_code text;site_name text;res jsonb;state text;reason text;instance uuid;punch uuid;canonical_key text;
BEGIN
 SELECT * INTO ev FROM time.channel_events WHERE tenant_id=p_tenant AND id=p_event FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO last_result FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event AND state<>'duplicate' AND reason IS DISTINCT FROM 'conflict' ORDER BY id DESC LIMIT 1;
 IF EXISTS(SELECT 1 FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event AND state IN('accepted','duplicate') AND canonical_punch_id IS NOT NULL) THEN
  INSERT INTO time.channel_replay_observations(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,p_event,'duplicate',p_actor);
  RETURN jsonb_build_object('state','duplicate','review',ev.review_required);
 END IF;
 IF last_result.state='rejected' THEN RETURN jsonb_build_object('state','rejected','reason',last_result.reason); END IF;
 INSERT INTO time.channel_event_results(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,p_event,'retrying',p_actor);
 emp:=ev.employee_id;site:=ev.site_id;canonical_key:='channel:'||ev.source_id::text||':'||ev.id::text;
 IF emp IS NULL THEN
  SELECT * INTO mapping FROM time.channel_mappings WHERE tenant_id=p_tenant AND source_id=ev.source_id AND external_key=ev.external_key ORDER BY created_at DESC,id DESC LIMIT 1;
  IF FOUND AND mapping.active AND ev.happened_at>=mapping.valid_from AND (mapping.valid_until IS NULL OR ev.happened_at<mapping.valid_until) THEN emp:=mapping.employee_id;site:=mapping.site_id; END IF;
 END IF;
 state:='unmapped';reason:='mapping';
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
CREATE OR REPLACE FUNCTION public.attendance_channel_submit(p_tenant uuid,p_source uuid,p_event_key text,p_external_key text,p_happened_at timestamptz,p_direction text,p_device_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE source time.channel_source_versions%ROWTYPE;prior time.channel_events%ROWTYPE;fp text;event_id uuid;BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_event_key IS NULL OR length(btrim(p_event_key)) NOT BETWEEN 1 AND 100 OR p_external_key IS NULL OR length(btrim(p_external_key)) NOT BETWEEN 1 AND 100 OR p_direction IS NULL OR p_direction NOT IN('in','out','unknown') OR p_happened_at IS NULL OR NOT isfinite(p_happened_at) OR p_happened_at>now()+interval '5 minutes' OR length(p_device_key)>64 THEN RAISE EXCEPTION 'channel_event_invalid' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM 1 FROM time.channel_sources WHERE tenant_id=p_tenant AND id=p_source AND kind='external' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='22023'; END IF;
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 fp:=md5(jsonb_build_array(btrim(p_external_key),p_happened_at,p_direction,p_device_key)::text);
 SELECT * INTO prior FROM time.channel_events WHERE tenant_id=p_tenant AND source_id=p_source AND event_key=btrim(p_event_key);
 IF FOUND THEN
  IF prior.payload_fingerprint<>fp THEN
   INSERT INTO time.channel_replay_observations(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,prior.id,'conflict',auth.uid());
   RETURN jsonb_build_object('state','rejected','reason','conflict');
  END IF;
  INSERT INTO time.channel_replay_observations(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,prior.id,'duplicate',auth.uid());
  RETURN jsonb_build_object('state','duplicate','event_id',prior.id);
 END IF;
 SELECT * INTO source FROM time.channel_source_versions WHERE tenant_id=p_tenant AND source_id=p_source ORDER BY version DESC LIMIT 1;
 IF NOT source.enabled OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) THEN RETURN jsonb_build_object('state','blocked','reason','disabled'); END IF;
 INSERT INTO time.channel_events(tenant_id,source_id,source_version,event_key,external_key,direction,happened_at,device_key,payload_fingerprint,actor_user_id)
 VALUES(p_tenant,p_source,source.version,btrim(p_event_key),btrim(p_external_key),p_direction,p_happened_at,p_device_key,fp,auth.uid()) RETURNING id INTO event_id;
 INSERT INTO time.channel_event_results(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,event_id,'received',auth.uid());
 RETURN time.channel_process(p_tenant,event_id,auth.uid())||jsonb_build_object('event_id',event_id);
END $f$;
CREATE OR REPLACE FUNCTION public.attendance_channel_reprocess(p_tenant uuid,p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE enabled boolean; BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM 1 FROM time.channel_sources s JOIN time.channel_events e ON e.tenant_id=s.tenant_id AND e.source_id=s.id WHERE e.tenant_id=p_tenant AND e.id=p_event FOR UPDATE OF s;
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 SELECT v.enabled INTO enabled FROM time.channel_events e JOIN time.channel_sources s ON s.tenant_id=e.tenant_id AND s.id=e.source_id
 JOIN LATERAL(SELECT enabled FROM time.channel_source_versions WHERE tenant_id=s.tenant_id AND source_id=s.id ORDER BY version DESC LIMIT 1)v ON true WHERE e.tenant_id=p_tenant AND e.id=p_event;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 IF NOT enabled OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) THEN RETURN jsonb_build_object('state','blocked','reason','disabled'); END IF;
 RETURN time.channel_process(p_tenant,p_event,auth.uid());
END $f$;
CREATE OR REPLACE FUNCTION public.attendance_mobile_punch(p_tenant uuid,p_attempt jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;src uuid;version time.channel_source_versions%ROWTYPE;prior time.channel_events%ROWTYPE;link people.employee_user_links%ROWTYPE;
 aid uuid;happened timestamptz;direction text;fp text;validation text;event_id uuid;res jsonb;BEGIN
 ctx:=time.mobile_context(p_tenant);aid:=(p_attempt->>'id')::uuid;direction:=p_attempt->>'direction';happened:=(p_attempt->>'happened_at')::timestamptz;
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
  FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=prior.id ORDER BY id DESC LIMIT 1;
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
