-- Vendor-neutral evidence gateway. No vendor transport, biometric data or financial rules.
ALTER TABLE time.manual_punches DROP CONSTRAINT manual_punches_source_type_check;
ALTER TABLE time.manual_punches ADD CONSTRAINT manual_punches_source_type_check CHECK(source_type IN ('manual','import','mobile','external'));

CREATE TABLE time.channel_sources(
 tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id), id uuid NOT NULL DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 100), kind text NOT NULL CHECK(kind IN ('mobile','external')),
 site_id uuid, created_by uuid NOT NULL REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id), FOREIGN KEY(tenant_id,site_id) REFERENCES platform_core.tenant_sites(tenant_id,id),
 CHECK(kind<>'mobile' OR site_id IS NOT NULL)
);
CREATE UNIQUE INDEX channel_mobile_site_idx ON time.channel_sources(tenant_id,site_id) WHERE kind='mobile';
CREATE TABLE time.channel_source_versions(
 tenant_id uuid NOT NULL,source_id uuid NOT NULL,version integer NOT NULL CHECK(version>0),enabled boolean NOT NULL,
 config jsonb NOT NULL,reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 3 AND 500),
 actor_user_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,source_id,version),FOREIGN KEY(tenant_id,source_id) REFERENCES time.channel_sources(tenant_id,id)
);
CREATE TABLE time.channel_mappings(
 tenant_id uuid NOT NULL,source_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),external_key text NOT NULL CHECK(length(btrim(external_key)) BETWEEN 1 AND 100),
 employee_id uuid NOT NULL,site_id uuid NOT NULL,valid_from timestamptz NOT NULL,valid_until timestamptz,
 active boolean NOT NULL,actor_user_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),FOREIGN KEY(tenant_id,source_id) REFERENCES time.channel_sources(tenant_id,id),
 FOREIGN KEY(tenant_id,employee_id) REFERENCES people.employees(tenant_id,id),FOREIGN KEY(tenant_id,site_id) REFERENCES platform_core.tenant_sites(tenant_id,id),
 CHECK(valid_until IS NULL OR valid_until>valid_from)
);
CREATE INDEX channel_mapping_lookup_idx ON time.channel_mappings(tenant_id,source_id,external_key,created_at DESC,id DESC);
CREATE TABLE time.channel_events(
 tenant_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),source_id uuid NOT NULL,source_version integer NOT NULL,
 event_key text NOT NULL CHECK(length(btrim(event_key)) BETWEEN 1 AND 100),external_key text NOT NULL CHECK(length(btrim(external_key)) BETWEEN 1 AND 100),
 direction text NOT NULL CHECK(direction IN('in','out','unknown')),happened_at timestamptz NOT NULL,received_at timestamptz NOT NULL DEFAULT now(),
 device_key text CHECK(length(device_key)<=64),payload_fingerprint text NOT NULL,actor_user_id uuid NOT NULL REFERENCES auth.users(id),
 employee_id uuid,site_id uuid,link_id uuid,scope text,validation text,review_required boolean NOT NULL DEFAULT false,
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,source_id,event_key),
 FOREIGN KEY(tenant_id,source_id,source_version) REFERENCES time.channel_source_versions(tenant_id,source_id,version),
 FOREIGN KEY(tenant_id,employee_id) REFERENCES people.employees(tenant_id,id),FOREIGN KEY(tenant_id,site_id) REFERENCES platform_core.tenant_sites(tenant_id,id),
 FOREIGN KEY(tenant_id,link_id) REFERENCES people.employee_user_links(tenant_id,id)
);
CREATE TABLE time.channel_event_results(
 tenant_id uuid NOT NULL,event_id uuid NOT NULL,id bigint GENERATED ALWAYS AS IDENTITY, state text NOT NULL CHECK(state IN('received','accepted','duplicate','rejected','unmapped','retrying','retry_failed')),
 reason text,canonical_punch_id uuid,work_instance_id uuid,employee_id uuid,site_id uuid,
 actor_user_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),FOREIGN KEY(tenant_id,event_id) REFERENCES time.channel_events(tenant_id,id),
 FOREIGN KEY(tenant_id,canonical_punch_id) REFERENCES time.manual_punches(tenant_id,id),
 FOREIGN KEY(tenant_id,work_instance_id) REFERENCES time.work_instances(tenant_id,id),
 FOREIGN KEY(tenant_id,employee_id) REFERENCES people.employees(tenant_id,id),FOREIGN KEY(tenant_id,site_id) REFERENCES platform_core.tenant_sites(tenant_id,id)
);
CREATE INDEX channel_results_event_idx ON time.channel_event_results(tenant_id,event_id,id DESC);
CREATE INDEX channel_events_page_idx ON time.channel_events(tenant_id,source_id,received_at DESC,id DESC);
CREATE TABLE time.channel_location_evidence(
 tenant_id uuid NOT NULL,event_id uuid NOT NULL,evidence jsonb NOT NULL,expires_at timestamptz NOT NULL,
 PRIMARY KEY(tenant_id,event_id),FOREIGN KEY(tenant_id,event_id) REFERENCES time.channel_events(tenant_id,id)
);
CREATE TABLE time.mobile_attempt_cancellations(
 tenant_id uuid NOT NULL,attempt_id uuid NOT NULL,actor_user_id uuid NOT NULL REFERENCES auth.users(id),scope text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,attempt_id,actor_user_id),FOREIGN KEY(tenant_id) REFERENCES platform_core.tenants(id)
);
ALTER TABLE time.mobile_attempt_cancellations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.mobile_attempt_cancellations FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER mobile_attempt_cancellation_append_only BEFORE UPDATE OR DELETE ON time.mobile_attempt_cancellations FOR EACH ROW EXECUTE FUNCTION time.prevent_attendance_mutation();
DO $f$ DECLARE tbl text; BEGIN
 FOREACH tbl IN ARRAY ARRAY['channel_sources','channel_source_versions','channel_mappings','channel_events','channel_event_results','channel_location_evidence'] LOOP
  EXECUTE format('ALTER TABLE time.%I ENABLE ROW LEVEL SECURITY',tbl);
  EXECUTE format('REVOKE ALL ON time.%I FROM PUBLIC,anon,authenticated,service_role',tbl);
  IF tbl<>'channel_location_evidence' THEN EXECUTE format('CREATE TRIGGER channel_append_only BEFORE UPDATE OR DELETE ON time.%I FOR EACH ROW EXECUTE FUNCTION time.prevent_attendance_mutation()',tbl); END IF;
 END LOOP;
END $f$;
REVOKE ALL ON SEQUENCE time.channel_event_results_id_seq FROM PUBLIC,anon,authenticated,service_role;

-- Preserve all previously approved role snapshots and append one narrow self-service bundle.
DO $f$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('platform_private.people_role_bundle_catalog()'::regprocedure);
 IF definition NOT LIKE '%employee.leave.self.v1%' THEN RAISE EXCEPTION 'channel_role_catalog_unexpected'; END IF;
 definition:=replace(definition,'''employee.leave.self.v1''::text,','''employee.attendance.self.v1''::text,ARRAY[''attendance.self.capture'']::text[]), ('||'''employee.leave.self.v1''::text,');
 EXECUTE definition;
END $f$;
REVOKE ALL ON FUNCTION platform_private.people_role_bundle_catalog() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION time.channel_operator_can(p_tenant uuid,p_write boolean DEFAULT false)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')
 OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.manage')
 OR (NOT p_write AND (platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.view') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.correct') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.approve')));
$f$;
REVOKE ALL ON FUNCTION time.channel_operator_can(uuid,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION time.validate_channel_config(p_kind text,p_config jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE k text; BEGIN
 IF jsonb_typeof(p_config)<>'object' OR p_config IS NULL THEN RETURN false; END IF;
 IF p_kind='external' THEN RETURN p_config='{}'::jsonb; END IF;
 IF p_kind<>'mobile' OR jsonb_typeof(p_config->'geofence')<>'boolean' OR jsonb_typeof(p_config->'retention_seconds')<>'number'
 OR (p_config->>'retention_seconds')::numeric NOT BETWEEN 60 AND 2592000 OR (p_config->>'retention_seconds')::numeric<>trunc((p_config->>'retention_seconds')::numeric) THEN RETURN false; END IF;
 IF NOT (p_config->>'geofence')::boolean THEN RETURN NOT EXISTS(SELECT 1 FROM jsonb_object_keys(p_config) key WHERE key NOT IN ('geofence','retention_seconds')); END IF;
 FOREACH k IN ARRAY ARRAY['latitude','longitude','radius_m','tolerance_m','max_accuracy_m','max_age_seconds'] LOOP
  IF jsonb_typeof(p_config->k)<>'number' THEN RETURN false; END IF;
 END LOOP;
 RETURN (p_config->>'latitude')::numeric BETWEEN -90 AND 90 AND (p_config->>'longitude')::numeric BETWEEN -180 AND 180
 AND (p_config->>'radius_m')::numeric BETWEEN 10 AND 10000 AND (p_config->>'tolerance_m')::numeric BETWEEN 0 AND 500
 AND (p_config->>'max_accuracy_m')::numeric BETWEEN 1 AND 500 AND (p_config->>'max_age_seconds')::numeric BETWEEN 5 AND 600
 AND p_config->>'failure_action' IN('reject','review') AND NOT EXISTS(SELECT 1 FROM jsonb_object_keys(p_config) key WHERE key NOT IN('geofence','retention_seconds','latitude','longitude','radius_m','tolerance_m','max_accuracy_m','max_age_seconds','failure_action'));
EXCEPTION WHEN OTHERS THEN RETURN false; END $f$;
REVOKE ALL ON FUNCTION time.validate_channel_config(text,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION time.channel_geofence_result(p_config jsonb,p_evidence jsonb,p_at timestamptz)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE lat double precision; lon double precision; acc double precision; captured timestamptz; distance double precision; BEGIN
 IF NOT (p_config->>'geofence')::boolean THEN RETURN 'not_required'; END IF;
 IF p_evidence IS NULL OR p_evidence='null'::jsonb THEN RETURN 'unavailable'; END IF;
 IF jsonb_typeof(p_evidence)<>'object' OR NOT p_evidence ?& ARRAY['latitude','longitude','accuracy','captured_at']
 OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_evidence) key WHERE key NOT IN ('latitude','longitude','accuracy','captured_at')) THEN RETURN 'unavailable'; END IF;
 lat:=(p_evidence->>'latitude')::double precision;lon:=(p_evidence->>'longitude')::double precision;acc:=(p_evidence->>'accuracy')::double precision;captured:=(p_evidence->>'captured_at')::timestamptz;
 IF lat NOT BETWEEN -90 AND 90 OR lon NOT BETWEEN -180 AND 180 OR acc NOT BETWEEN 0 AND 100000 OR captured IS NULL THEN RETURN 'unavailable'; END IF;
 IF captured>p_at+interval '5 seconds' OR captured<p_at-make_interval(secs=>(p_config->>'max_age_seconds')::double precision) THEN RETURN 'stale'; END IF;
 IF acc>(p_config->>'max_accuracy_m')::double precision THEN RETURN 'accuracy'; END IF;
 distance:=6371000*2*asin(sqrt(least(1.0,power(sin(radians(lat-(p_config->>'latitude')::double precision)/2),2)+cos(radians(lat))*cos(radians((p_config->>'latitude')::double precision))*power(sin(radians(lon-(p_config->>'longitude')::double precision)/2),2))));
 IF distance>(p_config->>'radius_m')::double precision+(p_config->>'tolerance_m')::double precision THEN RETURN 'outside'; END IF;
 RETURN 'inside';
EXCEPTION WHEN OTHERS THEN RETURN 'unavailable'; END $f$;
REVOKE ALL ON FUNCTION time.channel_geofence_result(jsonb,jsonb,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.attendance_channel_save_source(p_tenant uuid,p_source uuid,p_name text,p_kind text,p_site uuid,p_enabled boolean,p_config jsonb,p_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE src time.channel_sources%ROWTYPE; version_no integer; BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_enabled IS NULL OR p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 2 AND 100 OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 OR NOT time.validate_channel_config(p_kind,p_config) THEN RAISE EXCEPTION 'channel_config_invalid' USING ERRCODE='22023'; END IF;
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
REVOKE ALL ON FUNCTION public.attendance_channel_save_source(uuid,uuid,text,text,uuid,boolean,jsonb,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_save_source(uuid,uuid,text,text,uuid,boolean,jsonb,text) TO authenticated;

CREATE FUNCTION public.attendance_channel_map(p_tenant uuid,p_source uuid,p_external_key text,p_employee uuid,p_site uuid,p_valid_from timestamptz,p_valid_until timestamptz,p_active boolean)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE result uuid; BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_external_key IS NULL OR length(btrim(p_external_key)) NOT BETWEEN 1 AND 100 OR p_valid_from IS NULL OR p_active IS NULL OR (p_valid_until IS NOT NULL AND p_valid_until<=p_valid_from) THEN RAISE EXCEPTION 'channel_mapping_invalid' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM time.channel_sources WHERE tenant_id=p_tenant AND id=p_source AND kind='external' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee) OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND id=p_site AND is_active) THEN RAISE EXCEPTION 'channel_mapping_scope_invalid' USING ERRCODE='22023'; END IF;
 INSERT INTO time.channel_mappings(tenant_id,source_id,external_key,employee_id,site_id,valid_from,valid_until,active,actor_user_id)
 VALUES(p_tenant,p_source,btrim(p_external_key),p_employee,p_site,p_valid_from,p_valid_until,p_active,auth.uid()) RETURNING id INTO result;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_map(uuid,uuid,text,uuid,uuid,timestamptz,timestamptz,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_map(uuid,uuid,text,uuid,uuid,timestamptz,timestamptz,boolean) TO authenticated;

CREATE FUNCTION time.channel_process(p_tenant uuid,p_event uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ev time.channel_events%ROWTYPE; mapping time.channel_mappings%ROWTYPE; last_result time.channel_event_results%ROWTYPE;
 emp uuid;site uuid;employee_code text;site_name text;res jsonb;state text;reason text;instance uuid;punch uuid;canonical_key text;
BEGIN
 SELECT * INTO ev FROM time.channel_events WHERE tenant_id=p_tenant AND id=p_event FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO last_result FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event ORDER BY id DESC LIMIT 1;
 IF EXISTS(SELECT 1 FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event AND state IN('accepted','duplicate') AND canonical_punch_id IS NOT NULL) THEN
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
REVOKE ALL ON FUNCTION time.channel_process(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.attendance_channel_submit(p_tenant uuid,p_source uuid,p_event_key text,p_external_key text,p_happened_at timestamptz,p_direction text,p_device_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE source time.channel_source_versions%ROWTYPE;prior time.channel_events%ROWTYPE;fp text;event_id uuid;BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 IF p_event_key IS NULL OR length(btrim(p_event_key)) NOT BETWEEN 1 AND 100 OR p_external_key IS NULL OR length(btrim(p_external_key)) NOT BETWEEN 1 AND 100 OR p_direction IS NULL OR p_direction NOT IN('in','out','unknown') OR p_happened_at IS NULL OR NOT isfinite(p_happened_at) OR p_happened_at>now()+interval '5 minutes' OR length(p_device_key)>64 THEN RAISE EXCEPTION 'channel_event_invalid' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM time.channel_sources WHERE tenant_id=p_tenant AND id=p_source AND kind='external' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_source_invalid' USING ERRCODE='22023'; END IF;
 fp:=md5(jsonb_build_array(btrim(p_external_key),p_happened_at,p_direction,p_device_key)::text);
 SELECT * INTO prior FROM time.channel_events WHERE tenant_id=p_tenant AND source_id=p_source AND event_key=btrim(p_event_key);
 IF FOUND THEN
  IF prior.payload_fingerprint<>fp THEN
   INSERT INTO time.channel_event_results(tenant_id,event_id,state,reason,actor_user_id) VALUES(p_tenant,prior.id,'rejected','conflict',auth.uid());
   RETURN jsonb_build_object('state','rejected','reason','conflict');
  END IF;
  INSERT INTO time.channel_event_results(tenant_id,event_id,state,reason,actor_user_id) VALUES(p_tenant,prior.id,'duplicate',NULL,auth.uid());
  RETURN jsonb_build_object('state','duplicate','event_id',prior.id);
 END IF;
 SELECT * INTO source FROM time.channel_source_versions WHERE tenant_id=p_tenant AND source_id=p_source ORDER BY version DESC LIMIT 1;
 IF NOT source.enabled OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) THEN RETURN jsonb_build_object('state','blocked','reason','disabled'); END IF;
 INSERT INTO time.channel_events(tenant_id,source_id,source_version,event_key,external_key,direction,happened_at,device_key,payload_fingerprint,actor_user_id)
 VALUES(p_tenant,p_source,source.version,btrim(p_event_key),btrim(p_external_key),p_direction,p_happened_at,p_device_key,fp,auth.uid()) RETURNING id INTO event_id;
 INSERT INTO time.channel_event_results(tenant_id,event_id,state,actor_user_id) VALUES(p_tenant,event_id,'received',auth.uid());
 RETURN time.channel_process(p_tenant,event_id,auth.uid())||jsonb_build_object('event_id',event_id);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_submit(uuid,uuid,text,text,timestamptz,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_submit(uuid,uuid,text,text,timestamptz,text,text) TO authenticated;

CREATE FUNCTION public.attendance_channel_reprocess(p_tenant uuid,p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE enabled boolean; BEGIN
 IF NOT time.channel_operator_can(p_tenant,true) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 SELECT v.enabled INTO enabled FROM time.channel_events e JOIN time.channel_sources s ON s.tenant_id=e.tenant_id AND s.id=e.source_id
 JOIN LATERAL(SELECT enabled FROM time.channel_source_versions WHERE tenant_id=s.tenant_id AND source_id=s.id ORDER BY version DESC LIMIT 1)v ON true WHERE e.tenant_id=p_tenant AND e.id=p_event;
 IF NOT FOUND THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 IF NOT enabled OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) THEN RETURN jsonb_build_object('state','blocked','reason','disabled'); END IF;
 RETURN time.channel_process(p_tenant,p_event,auth.uid());
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_reprocess(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_reprocess(uuid,uuid) TO authenticated;

-- Exact current linked identity and effective Site; no client Employee/Site IDs accepted.
CREATE FUNCTION time.mobile_context(p_tenant uuid)
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
 JOIN LATERAL(SELECT state,reason FROM time.channel_event_results WHERE tenant_id=e.tenant_id AND event_id=e.id ORDER BY id DESC LIMIT 1)r ON true
 LEFT JOIN LATERAL(SELECT i.timezone_name FROM time.channel_event_results cr JOIN time.work_instances i ON i.tenant_id=cr.tenant_id AND i.id=cr.work_instance_id WHERE cr.tenant_id=e.tenant_id AND cr.event_id=e.id ORDER BY cr.id DESC LIMIT 1)wi ON true
 WHERE e.tenant_id=p_tenant AND e.employee_id=link.employee_id AND e.actor_user_id=auth.uid() ORDER BY e.received_at DESC,e.id DESC LIMIT 20)h;
 RETURN jsonb_build_object('scope',scope,'available',reason IS NULL,'reason',reason,'next_direction',coalesce(next_dir,'in'),'site_name',site_name,'timezone_name',zone,'source_id',src.id,
 'geofence_required',coalesce((version.config->>'geofence')::boolean,false),'policy_version',coalesce(version.version,0),'retention_seconds',coalesce((version.config->>'retention_seconds')::integer,60),'history',history);
END $f$;
REVOKE ALL ON FUNCTION time.mobile_context(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.attendance_mobile_snapshot(p_tenant uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$ SELECT time.mobile_context(p_tenant)-'source_id' $f$;
REVOKE ALL ON FUNCTION public.attendance_mobile_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_mobile_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.attendance_mobile_punch(p_tenant uuid,p_attempt jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;src uuid;version time.channel_source_versions%ROWTYPE;prior time.channel_events%ROWTYPE;link people.employee_user_links%ROWTYPE;
 aid uuid;happened timestamptz;direction text;fp text;validation text;event_id uuid;res jsonb;BEGIN
 ctx:=time.mobile_context(p_tenant);aid:=(p_attempt->>'id')::uuid;direction:=p_attempt->>'direction';happened:=(p_attempt->>'happened_at')::timestamptz;
 IF aid IS NULL OR direction IS NULL OR direction NOT IN('in','out') OR happened IS NULL OR NOT isfinite(happened) OR jsonb_typeof(p_attempt)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_attempt) key WHERE key NOT IN('id','direction','happened_at','scope','policy_version','location')) THEN RETURN jsonb_build_object('state','rejected','reason','time'); END IF;
 IF ctx->>'scope' IS DISTINCT FROM p_attempt->>'scope' THEN RETURN jsonb_build_object('state','blocked','reason','scope_changed'); END IF;
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
REVOKE ALL ON FUNCTION public.attendance_mobile_punch(uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_mobile_punch(uuid,jsonb) TO authenticated;

CREATE FUNCTION public.attendance_mobile_attempt(p_tenant uuid,p_attempt_id uuid,p_scope text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;result jsonb; BEGIN
 ctx:=time.mobile_context(p_tenant);
 IF ctx->>'scope' IS DISTINCT FROM p_scope THEN RETURN jsonb_build_object('state','blocked','reason','scope_changed'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||auth.uid()::text,505));
 ctx:=time.mobile_context(p_tenant);
 IF ctx->>'scope' IS DISTINCT FROM p_scope THEN RETURN jsonb_build_object('state','blocked','reason','scope_changed'); END IF;
 SELECT jsonb_build_object('state',r.state,'reason',r.reason,'review',e.review_required,'next_direction',ctx->>'next_direction') INTO result FROM time.channel_events e
 JOIN LATERAL(SELECT state,reason FROM time.channel_event_results WHERE tenant_id=e.tenant_id AND event_id=e.id ORDER BY id DESC LIMIT 1)r ON true
 WHERE e.tenant_id=p_tenant AND e.event_key=p_attempt_id::text AND e.actor_user_id=auth.uid() AND e.scope=p_scope;
 IF result IS NULL THEN
  -- Terminal receipt claim prevents a delayed request from recording after a new attempt starts.
  INSERT INTO time.mobile_attempt_cancellations(tenant_id,attempt_id,actor_user_id,scope) VALUES(p_tenant,p_attempt_id,auth.uid(),p_scope) ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('state','rejected','reason','cancelled');
 END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.attendance_mobile_attempt(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_mobile_attempt(uuid,uuid,text) TO authenticated;

-- Only the task-owned trusted maintenance connection can purge expired precise evidence.
-- Source event, policy version, validation and canonical history remain immutable.
CREATE FUNCTION time.purge_expired_channel_location(p_at timestamptz DEFAULT now()) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE n integer;BEGIN DELETE FROM time.channel_location_evidence WHERE expires_at<=p_at;GET DIAGNOSTICS n=ROW_COUNT;RETURN n;END $f$;
REVOKE ALL ON FUNCTION time.purge_expired_channel_location(timestamptz) FROM PUBLIC,anon,authenticated,service_role;
