ALTER TABLE time.work_policy_versions
  ADD COLUMN IF NOT EXISTS lateness_grace_minutes integer NOT NULL DEFAULT 5 CHECK (lateness_grace_minutes BETWEEN 0 AND 60),
  ADD COLUMN IF NOT EXISTS early_leave_grace_minutes integer NOT NULL DEFAULT 5 CHECK (early_leave_grace_minutes BETWEEN 0 AND 60);

ALTER TABLE time.work_instances
  ADD COLUMN IF NOT EXISTS break_minutes integer NOT NULL DEFAULT 0 CHECK (break_minutes BETWEEN 0 AND 360),
  ADD COLUMN IF NOT EXISTS lateness_grace_minutes integer NOT NULL DEFAULT 5 CHECK (lateness_grace_minutes BETWEEN 0 AND 60),
  ADD COLUMN IF NOT EXISTS early_leave_grace_minutes integer NOT NULL DEFAULT 5 CHECK (early_leave_grace_minutes BETWEEN 0 AND 60);
UPDATE time.work_instances i SET break_minutes=v.break_minutes,
  lateness_grace_minutes=v.lateness_grace_minutes,
  early_leave_grace_minutes=v.early_leave_grace_minutes
FROM time.work_policy_versions v
WHERE v.tenant_id=i.tenant_id AND v.template_id=i.policy_template_id AND v.version=i.policy_version;

ALTER TABLE time.interpretations
  ADD COLUMN IF NOT EXISTS gross_worked_minutes integer,
  ADD COLUMN IF NOT EXISTS late_minutes integer,
  ADD COLUMN IF NOT EXISTS early_leave_minutes integer,
  ADD COLUMN IF NOT EXISTS scheduled_break_minutes integer;
ALTER TABLE time.interpretations DROP CONSTRAINT IF EXISTS attendance_interpretation_owner_permission_check;
ALTER TABLE time.interpretations DROP CONSTRAINT IF EXISTS interpretations_owner_permission_check;
ALTER TABLE time.interpretations ADD CONSTRAINT interpretations_owner_permission_check
  CHECK (owner_permission IS NULL OR owner_permission IN ('attendance.correct','attendance.approve'));

CREATE OR REPLACE FUNCTION time.interpret_work_instance(p_tenant uuid,p_instance uuid,p_actor uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi time.work_instances%ROWTYPE; n integer; ni integer; no integer; fin timestamptz; fout timestamptz;
 st text; exc text; ver integer; interp uuid; fp text; gross_minutes integer; net_minutes integer; late_n integer; early_n integer;
BEGIN
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_instance FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 WITH active AS (
  SELECT p.id,coalesce(c.new_direction,p.direction) d,coalesce(c.new_happened_at,p.happened_at) at
  FROM time.manual_punches p
  LEFT JOIN LATERAL(SELECT q.* FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id ORDER BY q.created_at DESC,q.id DESC LIMIT 1)c ON c.action='replace'
  WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance
   AND NOT EXISTS(SELECT 1 FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id AND q.action='exclude'))
 SELECT count(*)::int,count(*) FILTER(WHERE d='in')::int,count(*) FILTER(WHERE d='out')::int,
  min(at) FILTER(WHERE d='in'),max(at) FILTER(WHERE d='out') INTO n,ni,no,fin,fout FROM active;
 st:='open'; exc:=NULL; gross_minutes:=NULL; net_minutes:=NULL; late_n:=NULL; early_n:=NULL;
 IF wi.expected_start IS NULL OR wi.expected_end IS NULL OR wi.attribution_start IS NULL OR wi.attribution_end IS NULL THEN st:='needs_review';exc:='ambiguous_local_time';
 ELSIF n>2 OR ni>1 OR no>1 THEN st:='needs_review';exc:='conflicting_punches';
 ELSIF ni=1 AND no=1 THEN
  IF fin>=fout OR fin<wi.attribution_start OR fout>wi.attribution_end THEN st:='needs_review';exc:='outside_window';
  ELSE
   st:='ready';
   gross_minutes:=greatest(0,(extract(epoch FROM(fout-fin))/60)::int);
   net_minutes:=greatest(0,gross_minutes-wi.break_minutes);
   late_n:=greatest(0,(extract(epoch FROM(fin-wi.expected_start))/60)::int-wi.lateness_grace_minutes);
   early_n:=greatest(0,(extract(epoch FROM(wi.expected_end-fout))/60)::int-wi.early_leave_grace_minutes);
  END IF;
 ELSIF now()>wi.attribution_end THEN st:='needs_review';exc:=CASE WHEN n=0 THEN 'absence_candidate' ELSE 'missing_punch' END;
 END IF;
 SELECT coalesce(max(version),0)+1 INTO ver FROM time.interpretations WHERE tenant_id=p_tenant AND work_instance_id=p_instance;
 fp:=md5(coalesce((SELECT string_agg(p.id::text||':'||p.direction||':'||p.happened_at::text||':'||coalesce(c.action,'')||':'||coalesce(c.new_direction,'')||':'||coalesce(c.new_happened_at::text,''),',' ORDER BY p.id)
   FROM time.manual_punches p LEFT JOIN LATERAL(SELECT q.* FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id ORDER BY q.created_at DESC,q.id DESC LIMIT 1)c ON true
   WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance),'')||concat_ws(':',wi.expected_start,wi.expected_end,wi.break_minutes,wi.lateness_grace_minutes,wi.early_leave_grace_minutes));
 INSERT INTO time.interpretations(tenant_id,work_instance_id,version,state,first_in,last_out,worked_minutes,exception_code,owner_permission,input_fingerprint,created_by,gross_worked_minutes,late_minutes,early_leave_minutes,scheduled_break_minutes)
 VALUES(p_tenant,p_instance,ver,st,fin,fout,net_minutes,exc,CASE WHEN st='needs_review' THEN CASE WHEN exc='absence_candidate' THEN 'attendance.approve' ELSE 'attendance.correct' END END,fp,p_actor,gross_minutes,late_n,early_n,wi.break_minutes) RETURNING id INTO interp;
 UPDATE time.work_instances SET status=CASE WHEN EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=p_tenant AND f.work_instance_id=p_instance) THEN 'needs_review' ELSE st END WHERE tenant_id=p_tenant AND id=p_instance;
 RETURN interp;
END $f$;
REVOKE ALL ON FUNCTION time.interpret_work_instance(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.attendance_day_list(p_tenant_id uuid,p_date date,p_after text DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb; next_code text; more boolean;
BEGIN
 IF NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_view_forbidden' USING ERRCODE='42501'; END IF;
 IF p_date IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'attendance_page_invalid' USING ERRCODE='22023'; END IF;
 WITH batch AS (
  SELECT i.id,i.operational_date,i.status,i.timezone_name,e.employee_code,e.full_name,i.expected_start,i.expected_end,
   q.late_minutes,q.early_leave_minutes,q.worked_minutes,q.gross_worked_minutes,q.scheduled_break_minutes,q.exception_code
  FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
  LEFT JOIN LATERAL(SELECT x.* FROM time.interpretations x WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id ORDER BY x.version DESC LIMIT 1)q ON true
  WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_date AND (p_after IS NULL OR e.employee_code>p_after)
  ORDER BY e.employee_code LIMIT p_limit+1
 ), visible AS (SELECT * FROM batch ORDER BY employee_code LIMIT p_limit)
 SELECT coalesce(jsonb_agg(to_jsonb(visible) ORDER BY employee_code),'[]'::jsonb),max(employee_code),(SELECT count(*)>p_limit FROM batch) INTO rows,next_code,more FROM visible;
 RETURN jsonb_build_object('items',rows,'next_cursor',CASE WHEN more THEN next_code END,'has_more',more,'limit',p_limit);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_day_list(uuid,date,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_day_list(uuid,date,text,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_open_day(p_tenant_id uuid,p_date date,p_after text DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb; cursor_next text; more boolean; instance_id uuid;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_date IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'attendance_day_input_invalid' USING ERRCODE='22023'; END IF;
 WITH candidates AS (
  SELECT e.employee_code,e.full_name,e.id employee_id,emp.id employment_id,a.id assignment_id,a.site_id,a.work_policy_template_id policy_id,a.work_policy_version version,
   v.timezone_name,v.work_days,v.shift_start,v.shift_end,v.ends_next_day,v.attribution_before_minutes,v.attribution_after_minutes,v.break_minutes,v.lateness_grace_minutes,v.early_leave_grace_minutes,
   time.resolve_local(p_date+v.shift_start,v.timezone_name) starts,
   time.resolve_local((p_date+CASE WHEN v.ends_next_day THEN 1 ELSE 0 END)+v.shift_end,v.timezone_name) ends
  FROM people.work_assignments a JOIN people.employments emp ON emp.tenant_id=a.tenant_id AND emp.id=a.employment_id
  JOIN people.employees e ON e.tenant_id=emp.tenant_id AND e.id=emp.employee_id JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id
  JOIN time.work_policy_templates t ON t.tenant_id=a.tenant_id AND t.id=a.work_policy_template_id JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=a.work_policy_version
  WHERE a.tenant_id=p_tenant_id AND p_date>=a.valid_from AND (a.valid_until IS NULL OR p_date<a.valid_until) AND p_date>=emp.start_date AND (emp.end_date IS NULL OR p_date<=emp.end_date)
   AND v.schedule_kind='fixed' AND p_date<=(now() AT TIME ZONE v.timezone_name)::date AND extract(dow FROM p_date)::int+1=ANY(v.work_days) AND (p_after IS NULL OR e.employee_code>p_after)
  ORDER BY e.employee_code,e.id LIMIT p_limit+1
 ), visible AS (SELECT * FROM candidates ORDER BY employee_code,employee_id LIMIT p_limit), inserted AS (
  INSERT INTO time.work_instances(tenant_id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by,break_minutes,lateness_grace_minutes,early_leave_grace_minutes)
  SELECT p_tenant_id,c.assignment_id,c.employment_id,c.employee_id,c.site_id,p_date,c.policy_id,c.version,c.timezone_name,c.starts,c.ends,
   CASE WHEN c.starts IS NULL THEN NULL ELSE c.starts-make_interval(mins=>c.attribution_before_minutes) END,CASE WHEN c.ends IS NULL THEN NULL ELSE c.ends+make_interval(mins=>c.attribution_after_minutes) END,
   CASE WHEN c.starts IS NULL OR c.ends IS NULL THEN 'needs_review' ELSE 'open' END,actor,c.break_minutes,c.lateness_grace_minutes,c.early_leave_grace_minutes FROM visible c
  ON CONFLICT(tenant_id,assignment_id,operational_date) DO NOTHING RETURNING id,assignment_id,status,timezone_name,expected_start,expected_end
 ), initial_exceptions AS (
  INSERT INTO time.interpretations(tenant_id,work_instance_id,version,state,exception_code,owner_permission,input_fingerprint,created_by)
  SELECT p_tenant_id,i.id,1,'needs_review','ambiguous_local_time','attendance.correct',md5(i.id::text||'ambiguous-local-time'),actor FROM inserted i WHERE i.expected_start IS NULL OR i.expected_end IS NULL RETURNING id
 ), opened_audit AS (
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) SELECT p_tenant_id,actor,'work_instance.opened',i.id,jsonb_build_object('operational_date',p_date) FROM inserted i RETURNING id
 ), page AS (
  SELECT n.id,p_date operational_date,n.status,n.timezone_name,c.employee_code,c.full_name,n.expected_start,n.expected_end FROM inserted n JOIN visible c ON c.assignment_id=n.assignment_id
  UNION ALL SELECT i.id,i.operational_date,i.status,i.timezone_name,e.employee_code,e.full_name,i.expected_start,i.expected_end FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id JOIN visible c ON c.assignment_id=i.assignment_id
  WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_date AND NOT EXISTS(SELECT 1 FROM inserted n WHERE n.id=i.id)
 ) SELECT coalesce(jsonb_agg(to_jsonb(page) ORDER BY employee_code),'[]'::jsonb),max(employee_code),(SELECT count(*)>p_limit FROM candidates) INTO rows,cursor_next,more FROM page;
 FOR instance_id IN SELECT (item->>'id')::uuid FROM jsonb_array_elements(rows) AS item LOOP PERFORM time.refresh_expired_work_instance(p_tenant_id,instance_id,actor); END LOOP;
 SELECT coalesce(jsonb_agg(item.value||jsonb_build_object('status',i.status,'late_minutes',q.late_minutes,'early_leave_minutes',q.early_leave_minutes,'worked_minutes',q.worked_minutes,'gross_worked_minutes',q.gross_worked_minutes,'scheduled_break_minutes',q.scheduled_break_minutes,'exception_code',q.exception_code) ORDER BY item.ordinality),'[]'::jsonb) INTO rows
 FROM jsonb_array_elements(rows) WITH ORDINALITY item(value,ordinality) JOIN time.work_instances i ON i.tenant_id=p_tenant_id AND i.id=(item.value->>'id')::uuid
 LEFT JOIN LATERAL(SELECT x.* FROM time.interpretations x WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id ORDER BY x.version DESC LIMIT 1)q ON true;
 RETURN jsonb_build_object('items',rows,'next_cursor',CASE WHEN more THEN cursor_next END,'has_more',more,'limit',p_limit);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_open_day(uuid,date,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_open_day(uuid,date,text,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.approve_attendance_fact(p_tenant_id uuid,p_instance_id uuid,p_corrects_fact_id uuid DEFAULT NULL,p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); i time.work_instances%ROWTYPE; q time.interpretations%ROWTYPE; version_n integer; fact_id uuid; latest_fact time.attendance_facts%ROWTYPE;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_approve_forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF NOT FOUND OR q.state<>'ready' THEN RAISE EXCEPTION 'attendance_instance_not_ready' USING ERRCODE='23514'; END IF;
 SELECT * INTO latest_fact FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF latest_fact.id IS DISTINCT FROM p_corrects_fact_id THEN RAISE EXCEPTION 'attendance_fact_version_stale' USING ERRCODE='40001'; END IF;
 IF p_corrects_fact_id IS NOT NULL AND latest_fact.interpretation_id=q.id THEN RAISE EXCEPTION 'attendance_fact_no_new_interpretation' USING ERRCODE='23514'; END IF;
 IF p_corrects_fact_id IS NOT NULL AND length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_fact_correction_reason_required' USING ERRCODE='22023'; END IF;
 SELECT coalesce(max(version),0)+1 INTO version_n FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id;
 INSERT INTO time.attendance_facts(tenant_id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id)
 VALUES(p_tenant_id,p_instance_id,version_n,q.id,p_corrects_fact_id,NULLIF(btrim(p_reason),''),jsonb_build_object('outcome','worked','operational_date',i.operational_date,'employee_id',i.employee_id,'assignment_id',i.assignment_id,'site_id',i.site_id,'timezone_name',i.timezone_name,'expected_start',i.expected_start,'expected_end',i.expected_end,'first_in',q.first_in,'last_out',q.last_out,'gross_worked_minutes',q.gross_worked_minutes,'scheduled_break_minutes',q.scheduled_break_minutes,'worked_minutes',q.worked_minutes,'late_minutes',q.late_minutes,'early_leave_minutes',q.early_leave_minutes),actor) RETURNING id INTO fact_id;
 UPDATE time.work_instances SET status='approved' WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,CASE WHEN p_corrects_fact_id IS NULL THEN 'attendance.fact.approved' ELSE 'attendance.fact.corrected' END,p_instance_id,jsonb_build_object('fact_id',fact_id,'version',version_n,'corrects_fact_id',p_corrects_fact_id,'reason',p_reason));
 RETURN jsonb_build_object('state','approved','fact_id',fact_id,'version',version_n);
END $f$;
REVOKE ALL ON FUNCTION public.approve_attendance_fact(uuid,uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.approve_attendance_fact(uuid,uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.approve_attendance_absence(p_tenant_id uuid,p_instance_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); i time.work_instances%ROWTYPE; q time.interpretations%ROWTYPE; fact_id uuid; version_n integer;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_approve_forbidden' USING ERRCODE='42501'; END IF;
 IF length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_absence_reason_required' USING ERRCODE='22023'; END IF;
 SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF q.state<>'needs_review' OR q.exception_code<>'absence_candidate' OR EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=p_tenant_id AND f.work_instance_id=p_instance_id)
  OR EXISTS(SELECT 1 FROM time.manual_punches p WHERE p.tenant_id=p_tenant_id AND p.work_instance_id=p_instance_id)
 THEN RAISE EXCEPTION 'attendance_absence_not_eligible' USING ERRCODE='23514'; END IF;
 SELECT coalesce(max(version),0)+1 INTO version_n FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id;
 INSERT INTO time.attendance_facts(tenant_id,work_instance_id,version,interpretation_id,reason,fact,actor_user_id)
 VALUES(p_tenant_id,p_instance_id,version_n,q.id,btrim(p_reason),jsonb_build_object('outcome','absence','absence_units',1,'operational_date',i.operational_date,'employee_id',i.employee_id,'assignment_id',i.assignment_id,'site_id',i.site_id,'timezone_name',i.timezone_name,'expected_start',i.expected_start,'expected_end',i.expected_end,'late_minutes',NULL,'early_leave_minutes',NULL,'worked_minutes',0),actor) RETURNING id INTO fact_id;
 UPDATE time.work_instances SET status='approved' WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,'attendance.absence.approved',p_instance_id,jsonb_build_object('fact_id',fact_id,'version',version_n,'absence_units',1,'reason',p_reason));
 RETURN jsonb_build_object('state','approved_absence','fact_id',fact_id,'version',version_n,'absence_units',1);
END $f$;
REVOKE ALL ON FUNCTION public.approve_attendance_absence(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.approve_attendance_absence(uuid,uuid,text) TO authenticated;


