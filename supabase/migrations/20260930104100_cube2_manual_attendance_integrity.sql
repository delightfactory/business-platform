ALTER TABLE time.interpretations ADD COLUMN IF NOT EXISTS owner_permission text;
DO $f$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint WHERE conname='attendance_interpretation_owner_permission_check' AND conrelid='time.interpretations'::regclass) THEN
  ALTER TABLE time.interpretations ADD CONSTRAINT attendance_interpretation_owner_permission_check CHECK(owner_permission IS NULL OR owner_permission='attendance.correct');
 END IF;
END $f$;

CREATE OR REPLACE FUNCTION time.interpret_work_instance(p_tenant uuid,p_instance uuid,p_actor uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi time.work_instances%ROWTYPE; n integer; ni integer; no integer; fin timestamptz; fout timestamptz; st text; exc text; ver integer; interp uuid; fp text;
BEGIN
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_instance FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 WITH active AS (
  SELECT p.id,coalesce(c.new_direction,p.direction) d,coalesce(c.new_happened_at,p.happened_at) at FROM time.manual_punches p
  LEFT JOIN LATERAL(SELECT q.* FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id ORDER BY q.created_at DESC,q.id DESC LIMIT 1)c ON c.action='replace'
  WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance AND NOT EXISTS(SELECT 1 FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id AND q.action='exclude')
 ) SELECT count(*)::int,count(*) FILTER(WHERE d='in')::int,count(*) FILTER(WHERE d='out')::int,min(at) FILTER(WHERE d='in'),max(at) FILTER(WHERE d='out') INTO n,ni,no,fin,fout FROM active;
 st:='open'; exc:=NULL;
 IF wi.expected_start IS NULL OR wi.expected_end IS NULL OR wi.attribution_start IS NULL OR wi.attribution_end IS NULL THEN st:='needs_review';exc:='ambiguous_local_time';
 ELSIF n>2 OR ni>1 OR no>1 THEN st:='needs_review';exc:='conflicting_punches';
 ELSIF ni=1 AND no=1 THEN IF fin>=fout OR fin<wi.attribution_start OR fout>wi.attribution_end THEN st:='needs_review';exc:='outside_window';ELSE st:='ready';END IF;
 ELSIF now()>wi.attribution_end THEN st:='needs_review';exc:='missing_punch'; END IF;
 SELECT coalesce(max(version),0)+1 INTO ver FROM time.interpretations WHERE tenant_id=p_tenant AND work_instance_id=p_instance;
 fp:=md5(coalesce((SELECT string_agg(p.id::text||':'||p.direction||':'||p.happened_at::text||':'||coalesce(c.action,'')||':'||coalesce(c.new_direction,'')||':'||coalesce(c.new_happened_at::text,''),',' ORDER BY p.id) FROM time.manual_punches p LEFT JOIN LATERAL(SELECT q.* FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id ORDER BY q.created_at DESC,q.id DESC LIMIT 1)c ON true WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance),'')||coalesce(wi.expected_start::text,'null')||coalesce(wi.expected_end::text,'null'));
 INSERT INTO time.interpretations(tenant_id,work_instance_id,version,state,first_in,last_out,worked_minutes,exception_code,owner_permission,input_fingerprint,created_by) VALUES(p_tenant,p_instance,ver,st,fin,fout,CASE WHEN st='ready' THEN greatest(0,(extract(epoch FROM(fout-fin))/60)::int) END,exc,CASE WHEN st='needs_review' THEN 'attendance.correct' END,fp,p_actor) RETURNING id INTO interp;
 UPDATE time.work_instances SET status=CASE WHEN EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=p_tenant AND f.work_instance_id=p_instance) THEN 'needs_review' ELSE st END WHERE tenant_id=p_tenant AND id=p_instance;
 RETURN interp;
END $f$;
REVOKE ALL ON FUNCTION time.interpret_work_instance(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION time.refresh_expired_work_instance(p_tenant uuid,p_instance uuid,p_actor uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi time.work_instances%ROWTYPE; latest_state text; interpretation_id uuid;
BEGIN
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_instance FOR UPDATE;
 IF NOT FOUND OR wi.attribution_end IS NULL OR now()<=wi.attribution_end THEN RETURN; END IF;
 SELECT state INTO latest_state FROM time.interpretations WHERE tenant_id=p_tenant AND work_instance_id=p_instance ORDER BY version DESC LIMIT 1;
 IF latest_state IS DISTINCT FROM 'needs_review' AND latest_state IS DISTINCT FROM 'ready' THEN
  interpretation_id:=time.interpret_work_instance(p_tenant,p_instance,p_actor);
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
  SELECT p_tenant,p_actor,'attendance.exception.detected',p_instance,jsonb_build_object('interpretation_id',id,'exception_code',exception_code)
  FROM time.interpretations WHERE tenant_id=p_tenant AND id=interpretation_id AND state='needs_review';
 END IF;
END $f$;
REVOKE ALL ON FUNCTION time.refresh_expired_work_instance(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.attendance_open_day(p_tenant_id uuid,p_date date,p_after text DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb; cursor_next text; more boolean; instance_id uuid;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_date IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'attendance_day_input_invalid' USING ERRCODE='22023'; END IF;
 WITH candidates AS (
  SELECT e.employee_code,e.full_name,e.id employee_id,emp.id employment_id,a.id assignment_id,a.site_id,a.work_policy_template_id policy_id,a.work_policy_version version,
   v.timezone_name,v.work_days,v.shift_start,v.shift_end,v.ends_next_day,v.attribution_before_minutes,v.attribution_after_minutes,
   time.resolve_local(p_date+v.shift_start,v.timezone_name) starts,
   time.resolve_local((p_date+CASE WHEN v.ends_next_day THEN 1 ELSE 0 END)+v.shift_end,v.timezone_name) ends
  FROM people.work_assignments a JOIN people.employments emp ON emp.tenant_id=a.tenant_id AND emp.id=a.employment_id
  JOIN people.employees e ON e.tenant_id=emp.tenant_id AND e.id=emp.employee_id
  JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id
  JOIN time.work_policy_templates t ON t.tenant_id=a.tenant_id AND t.id=a.work_policy_template_id
  JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=a.work_policy_version
  WHERE a.tenant_id=p_tenant_id AND p_date>=a.valid_from AND (a.valid_until IS NULL OR p_date<a.valid_until)
   AND p_date>=emp.start_date AND (emp.end_date IS NULL OR p_date<=emp.end_date) AND v.schedule_kind='fixed'
   AND p_date<=(now() AT TIME ZONE v.timezone_name)::date AND extract(dow FROM p_date)::int+1=ANY(v.work_days) AND (p_after IS NULL OR e.employee_code>p_after)
  ORDER BY e.employee_code,e.id LIMIT p_limit+1
 ), visible AS (SELECT * FROM candidates ORDER BY employee_code,employee_id LIMIT p_limit), inserted AS (
  INSERT INTO time.work_instances(tenant_id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by)
  SELECT p_tenant_id,c.assignment_id,c.employment_id,c.employee_id,c.site_id,p_date,c.policy_id,c.version,c.timezone_name,c.starts,c.ends,
   CASE WHEN c.starts IS NULL THEN NULL ELSE c.starts-make_interval(mins=>c.attribution_before_minutes) END,
   CASE WHEN c.ends IS NULL THEN NULL ELSE c.ends+make_interval(mins=>c.attribution_after_minutes) END,
   CASE WHEN c.starts IS NULL OR c.ends IS NULL THEN 'needs_review' ELSE 'open' END,actor FROM visible c
  ON CONFLICT(tenant_id,assignment_id,operational_date) DO NOTHING RETURNING id,assignment_id,status,timezone_name,expected_start,expected_end
 ), initial_exceptions AS (
  INSERT INTO time.interpretations(tenant_id,work_instance_id,version,state,exception_code,owner_permission,input_fingerprint,created_by)
  SELECT p_tenant_id,i.id,1,'needs_review','ambiguous_local_time','attendance.correct',md5(i.id::text||'ambiguous-local-time'),actor FROM inserted i WHERE i.expected_start IS NULL OR i.expected_end IS NULL
  RETURNING id
 ), opened_audit AS (
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
  SELECT p_tenant_id,actor,'work_instance.opened',i.id,jsonb_build_object('operational_date',p_date) FROM inserted i RETURNING id
 ), page AS (
  SELECT n.id,p_date operational_date,n.status,n.timezone_name,c.employee_code,c.full_name,n.expected_start,n.expected_end FROM inserted n JOIN visible c ON c.assignment_id=n.assignment_id
  UNION ALL
  SELECT i.id,i.operational_date,i.status,i.timezone_name,e.employee_code,e.full_name,i.expected_start,i.expected_end FROM time.work_instances i
  JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id JOIN visible c ON c.assignment_id=i.assignment_id
  WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_date AND NOT EXISTS(SELECT 1 FROM inserted n WHERE n.id=i.id)
 ) SELECT coalesce(jsonb_agg(to_jsonb(page) ORDER BY employee_code),'[]'::jsonb),max(employee_code),(SELECT count(*)>p_limit FROM candidates) INTO rows,cursor_next,more FROM page;
 FOR instance_id IN SELECT (item->>'id')::uuid FROM jsonb_array_elements(rows) AS item LOOP
  PERFORM time.refresh_expired_work_instance(p_tenant_id,instance_id,actor);
 END LOOP;
 SELECT coalesce(jsonb_agg(jsonb_set(item.value,'{status}',to_jsonb(i.status)) ORDER BY item.ordinality),'[]'::jsonb) INTO rows
 FROM jsonb_array_elements(rows) WITH ORDINALITY item(value,ordinality) JOIN time.work_instances i ON i.tenant_id=p_tenant_id AND i.id=(item.value->>'id')::uuid;
 RETURN jsonb_build_object('items',rows,'next_cursor',CASE WHEN more THEN cursor_next END,'has_more',more,'limit',p_limit);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_open_day(uuid,date,text,integer) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.attendance_open_day(uuid,date,text,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.record_manual_attendance_punch(p_tenant_id uuid,p_instance_id uuid,p_direction text,p_happened_at timestamptz,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); old time.manual_punches%ROWTYPE; fingerprint text; punch_id uuid; interpretation_id uuid;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage')  OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_direction IS NULL OR p_direction NOT IN('in','out') OR p_happened_at IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'attendance_punch_input_invalid' USING ERRCODE='22023'; END IF;
 fingerprint:=md5(p_instance_id::text||'|'||p_direction||'|'||p_happened_at::text);
 PERFORM 1 FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO old FROM time.manual_punches WHERE tenant_id=p_tenant_id AND request_key=p_request_key;
 IF FOUND THEN IF old.payload_fingerprint<>fingerprint THEN RAISE EXCEPTION 'attendance_idempotency_conflict' USING ERRCODE='23505'; END IF; RETURN jsonb_build_object('state','unchanged','punch_id',old.id); END IF;
 INSERT INTO time.manual_punches(tenant_id,work_instance_id,direction,happened_at,request_key,payload_fingerprint,actor_user_id) VALUES(p_tenant_id,p_instance_id,p_direction,p_happened_at,p_request_key,fingerprint,actor) RETURNING id INTO punch_id;
 interpretation_id:=time.interpret_work_instance(p_tenant_id,p_instance_id,actor);
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,'manual_punch.recorded',p_instance_id,jsonb_build_object('punch_id',punch_id,'direction',p_direction,'happened_at',p_happened_at,'interpretation_id',interpretation_id));
 RETURN jsonb_build_object('state','recorded','punch_id',punch_id,'interpretation_id',interpretation_id);
END $f$;
REVOKE ALL ON FUNCTION public.record_manual_attendance_punch(uuid,uuid,text,timestamptz,uuid) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.record_manual_attendance_punch(uuid,uuid,text,timestamptz,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.record_manual_attendance_punch_local(p_tenant_id uuid,p_instance_id uuid,p_direction text,p_local_time timestamp,p_request_key uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); wi time.work_instances%ROWTYPE; resolved timestamptz; old time.manual_punches%ROWTYPE; fingerprint text; punch_id uuid; interpretation_id uuid; manager boolean;
BEGIN
 manager:=platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer');
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR (NOT manager AND NOT platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct')) THEN RAISE EXCEPTION 'attendance_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_direction IS NULL OR p_direction NOT IN('in','out') OR p_request_key IS NULL OR (NOT manager AND length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500) THEN RAISE EXCEPTION 'attendance_punch_input_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 IF NOT manager AND wi.status NOT IN('needs_review','approved') THEN RAISE EXCEPTION 'attendance_review_entry_not_available' USING ERRCODE='42501'; END IF;
 resolved:=time.resolve_local(p_local_time,wi.timezone_name);
 IF resolved IS NULL THEN RAISE EXCEPTION 'attendance_local_time_ambiguous_or_invalid' USING ERRCODE='22023'; END IF;
 IF manager THEN RETURN public.record_manual_attendance_punch(p_tenant_id,p_instance_id,p_direction,resolved,p_request_key); END IF;
 fingerprint:=md5(p_instance_id::text||'|'||p_direction||'|'||resolved::text||'|'||btrim(p_reason));
 SELECT * INTO old FROM time.manual_punches WHERE tenant_id=p_tenant_id AND request_key=p_request_key;
 IF FOUND THEN IF old.payload_fingerprint<>fingerprint THEN RAISE EXCEPTION 'attendance_idempotency_conflict' USING ERRCODE='23505'; END IF; RETURN jsonb_build_object('state','unchanged','punch_id',old.id); END IF;
 INSERT INTO time.manual_punches(tenant_id,work_instance_id,direction,happened_at,request_key,payload_fingerprint,actor_user_id) VALUES(p_tenant_id,p_instance_id,p_direction,resolved,p_request_key,fingerprint,actor) RETURNING id INTO punch_id;
 interpretation_id:=time.interpret_work_instance(p_tenant_id,p_instance_id,actor);
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,'manual_punch.review_entry',p_instance_id,jsonb_build_object('punch_id',punch_id,'direction',p_direction,'happened_at',resolved,'reason',btrim(p_reason),'interpretation_id',interpretation_id));
 RETURN jsonb_build_object('state','recorded','punch_id',punch_id,'interpretation_id',interpretation_id);
END $f$;
REVOKE ALL ON FUNCTION public.record_manual_attendance_punch_local(uuid,uuid,text,timestamp,uuid,text) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.record_manual_attendance_punch_local(uuid,uuid,text,timestamp,uuid,text) TO authenticated;
