CREATE TABLE time.work_policy_overrides (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employment_id uuid NOT NULL,
  policy_template_id uuid NOT NULL,
  policy_version integer NOT NULL,
  valid_from date NOT NULL,
  valid_until date NOT NULL,
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 3 AND 500),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  cancelled_at timestamptz,
  cancelled_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  cancel_reason text,
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,employment_id) REFERENCES people.employments(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,policy_template_id,policy_version) REFERENCES time.work_policy_versions(tenant_id,template_id,version) ON DELETE RESTRICT,
  CHECK (valid_until > valid_from),
  CHECK ((cancelled_at IS NULL AND cancelled_by IS NULL AND cancel_reason IS NULL)
      OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND length(btrim(cancel_reason)) BETWEEN 3 AND 500))
);
CREATE INDEX work_policy_overrides_employment_date_idx
  ON time.work_policy_overrides(tenant_id,employment_id,valid_from,valid_until)
  WHERE cancelled_at IS NULL;
ALTER TABLE time.work_policy_overrides ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.work_policy_overrides FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.assign_attendance_work_policy_override(
  p_tenant_id uuid,p_employment_id uuid,p_policy_id uuid,p_valid_from date,p_valid_through date,p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); emp people.employments%ROWTYPE; policy_version integer; policy_timezone text; override_id uuid;
BEGIN
  IF actor IS NULL OR NOT time.has_policy_permission(p_tenant_id,actor) THEN
    RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_valid_from IS NULL OR p_valid_through IS NULL OR p_valid_through<p_valid_from
     OR p_valid_through-p_valid_from>89 OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN
    RAISE EXCEPTION 'attendance_policy_override_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO emp FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id FOR UPDATE;
  IF NOT FOUND OR emp.employment_status<>'active' THEN
    RAISE EXCEPTION 'attendance_policy_override_employment_unavailable' USING ERRCODE='23514';
  END IF;
  SELECT t.head_version,v.timezone_name INTO policy_version,policy_timezone
    FROM time.work_policy_templates t JOIN time.work_policy_versions v
      ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version
    WHERE t.tenant_id=p_tenant_id AND t.id=p_policy_id AND t.is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'attendance_policy_override_policy_unavailable' USING ERRCODE='23503'; END IF;
  IF p_valid_from<(transaction_timestamp() AT TIME ZONE policy_timezone)::date THEN
    RAISE EXCEPTION 'attendance_policy_override_historical' USING ERRCODE='22023';
  END IF;
  IF emp.start_date>p_valid_from OR (emp.end_date IS NOT NULL AND emp.end_date<p_valid_through) THEN
    RAISE EXCEPTION 'attendance_policy_override_outside_employment' USING ERRCODE='23514';
  END IF;
  IF EXISTS (
    SELECT 1 FROM generate_series(p_valid_from,p_valid_through,interval '1 day') d(day)
    WHERE NOT EXISTS (
      SELECT 1 FROM people.work_assignments a
      JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id AND s.is_active
      WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
        AND d.day::date>=a.valid_from AND (a.valid_until IS NULL OR d.day::date<a.valid_until)
    )
  ) THEN RAISE EXCEPTION 'attendance_policy_override_assignment_unavailable' USING ERRCODE='23514'; END IF;
  IF EXISTS (SELECT 1 FROM time.work_policy_overrides o WHERE o.tenant_id=p_tenant_id AND o.employment_id=p_employment_id
      AND o.cancelled_at IS NULL AND daterange(o.valid_from,o.valid_until,'[)') && daterange(p_valid_from,p_valid_through+1,'[)')) THEN
    RAISE EXCEPTION 'attendance_policy_override_overlap' USING ERRCODE='23P01';
  END IF;
  IF EXISTS (SELECT 1 FROM time.work_instances i WHERE i.tenant_id=p_tenant_id AND i.employment_id=p_employment_id
      AND i.operational_date BETWEEN p_valid_from AND p_valid_through) THEN
    RAISE EXCEPTION 'attendance_policy_override_materialized_date' USING ERRCODE='23514';
  END IF;
  INSERT INTO time.work_policy_overrides(tenant_id,employment_id,policy_template_id,policy_version,valid_from,valid_until,reason,created_by)
    VALUES(p_tenant_id,p_employment_id,p_policy_id,policy_version,p_valid_from,p_valid_through+1,btrim(p_reason),actor)
    RETURNING id INTO override_id;
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
    VALUES(p_tenant_id,actor,'work_policy.override.created',NULL,jsonb_build_object(
      'override_id',override_id,'employment_id',p_employment_id,'policy_id',p_policy_id,'policy_version',policy_version,
      'valid_from',p_valid_from,'valid_through',p_valid_through,'reason',btrim(p_reason)));
  RETURN jsonb_build_object('override_id',override_id,'policy_version',policy_version,'valid_from',p_valid_from,'valid_through',p_valid_through);
END $f$;
REVOKE ALL ON FUNCTION public.assign_attendance_work_policy_override(uuid,uuid,uuid,date,date,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.assign_attendance_work_policy_override(uuid,uuid,uuid,date,date,text) TO authenticated;

CREATE FUNCTION time.guard_work_instance_policy_override()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE expected_policy uuid; expected_version integer;
BEGIN
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=NEW.tenant_id AND e.id=NEW.employment_id FOR UPDATE;
  SELECT o.policy_template_id,o.policy_version INTO expected_policy,expected_version
    FROM time.work_policy_overrides o WHERE o.tenant_id=NEW.tenant_id AND o.employment_id=NEW.employment_id
      AND o.cancelled_at IS NULL AND o.valid_from<=NEW.operational_date AND o.valid_until>NEW.operational_date
    ORDER BY o.valid_from DESC LIMIT 1;
  IF FOUND AND (NEW.policy_template_id,NEW.policy_version) IS DISTINCT FROM (expected_policy,expected_version) THEN
    RAISE EXCEPTION 'attendance_override_policy_mismatch' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION time.guard_work_instance_policy_override() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER work_instance_policy_override_guard BEFORE INSERT ON time.work_instances
FOR EACH ROW EXECUTE FUNCTION time.guard_work_instance_policy_override();

CREATE FUNCTION public.cancel_attendance_work_policy_override(p_tenant_id uuid,p_override_id uuid,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); row_override time.work_policy_overrides%ROWTYPE; emp people.employments%ROWTYPE; policy_timezone text;
BEGIN
  IF actor IS NULL OR NOT time.has_policy_permission(p_tenant_id,actor) THEN RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501'; END IF;
  IF length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_policy_override_cancel_reason_required' USING ERRCODE='22023'; END IF;
  SELECT * INTO row_override FROM time.work_policy_overrides WHERE tenant_id=p_tenant_id AND id=p_override_id FOR UPDATE;
  IF NOT FOUND OR row_override.cancelled_at IS NOT NULL THEN RAISE EXCEPTION 'attendance_policy_override_not_cancellable' USING ERRCODE='23514'; END IF;
  SELECT * INTO emp FROM people.employments WHERE tenant_id=p_tenant_id AND id=row_override.employment_id FOR UPDATE;
  SELECT timezone_name INTO policy_timezone FROM time.work_policy_versions WHERE tenant_id=p_tenant_id AND template_id=row_override.policy_template_id AND version=row_override.policy_version;
  IF row_override.valid_from<=(transaction_timestamp() AT TIME ZONE policy_timezone)::date THEN RAISE EXCEPTION 'attendance_policy_override_already_effective' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM time.work_instances i WHERE i.tenant_id=p_tenant_id AND i.employment_id=row_override.employment_id AND i.operational_date>=row_override.valid_from AND i.operational_date<row_override.valid_until) THEN
    RAISE EXCEPTION 'attendance_policy_override_materialized_date' USING ERRCODE='23514';
  END IF;
  UPDATE time.work_policy_overrides SET cancelled_at=transaction_timestamp(),cancelled_by=actor,cancel_reason=btrim(p_reason)
    WHERE tenant_id=p_tenant_id AND id=p_override_id;
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
    VALUES(p_tenant_id,actor,'work_policy.override.cancelled',NULL,jsonb_build_object('override_id',p_override_id,'employment_id',row_override.employment_id,'policy_id',row_override.policy_template_id,'policy_version',row_override.policy_version,'valid_from',row_override.valid_from,'valid_through',row_override.valid_until-1,'reason',btrim(p_reason)));
END $f$;
REVOKE ALL ON FUNCTION public.cancel_attendance_work_policy_override(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.cancel_attendance_work_policy_override(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.people_work_policy_panel(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); items jsonb; options jsonb; overrides jsonb;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) OR NOT platform_private.has_people_permission(p_tenant_id,actor,'people.view') THEN RAISE EXCEPTION 'time_policy_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('assignment_id',a.id,'policy_id',a.work_policy_template_id,'version',a.work_policy_version,'name',v.name,'code',t.code,'valid_from',a.valid_from,'valid_until',a.valid_until) ORDER BY a.valid_from DESC),'[]'::jsonb) INTO items FROM people.work_assignments a LEFT JOIN time.work_policy_templates t ON t.tenant_id=a.tenant_id AND t.id=a.work_policy_template_id LEFT JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id AND v.template_id=a.work_policy_template_id AND v.version=a.work_policy_version WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'name',v.name,'version',v.version) ORDER BY t.code),'[]'::jsonb) INTO options FROM time.work_policy_templates t JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version WHERE t.tenant_id=p_tenant_id AND t.is_active;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',o.id,'policy_id',o.policy_template_id,'version',o.policy_version,'name',v.name,'code',t.code,'valid_from',o.valid_from,'valid_through',o.valid_until-1,'reason',o.reason,'cancelled_at',o.cancelled_at,'can_cancel',o.cancelled_at IS NULL AND o.valid_from>(transaction_timestamp() AT TIME ZONE v.timezone_name)::date) ORDER BY o.valid_from DESC,o.created_at DESC),'[]'::jsonb) INTO overrides FROM (SELECT * FROM time.work_policy_overrides WHERE tenant_id=p_tenant_id AND employment_id=p_employment_id ORDER BY valid_from DESC,created_at DESC LIMIT 50) o JOIN time.work_policy_templates t ON t.tenant_id=o.tenant_id AND t.id=o.policy_template_id JOIN time.work_policy_versions v ON v.tenant_id=o.tenant_id AND v.template_id=o.policy_template_id AND v.version=o.policy_version;
 RETURN jsonb_build_object('history',items,'options',options,'overrides',overrides,'can_assign',platform_private.has_people_permission(p_tenant_id,actor,'org_context.manage'),'can_manage_catalog',time.has_policy_permission(p_tenant_id,actor));
END $f$;
REVOKE ALL ON FUNCTION public.people_work_policy_panel(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_work_policy_panel(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_open_day(p_tenant_id uuid,p_date date,p_after text DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb; cursor_next text; more boolean; instance_id uuid;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_date IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'attendance_day_input_invalid' USING ERRCODE='22023'; END IF;
 PERFORM emp.id FROM (
  SELECT emp.id employment_id,e.employee_code,e.id employee_id
  FROM people.work_assignments a JOIN people.employments emp ON emp.tenant_id=a.tenant_id AND emp.id=a.employment_id
  JOIN people.employees e ON e.tenant_id=emp.tenant_id AND e.id=emp.employee_id
  LEFT JOIN LATERAL(SELECT po.policy_template_id,po.policy_version FROM time.work_policy_overrides po WHERE po.tenant_id=a.tenant_id AND po.employment_id=emp.id AND po.cancelled_at IS NULL AND po.valid_from<=p_date AND po.valid_until>p_date ORDER BY po.valid_from DESC LIMIT 1)o ON true
  JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id AND v.template_id=coalesce(o.policy_template_id,a.work_policy_template_id) AND v.version=coalesce(o.policy_version,a.work_policy_version)
  WHERE a.tenant_id=p_tenant_id AND p_date>=a.valid_from AND (a.valid_until IS NULL OR p_date<a.valid_until)
   AND p_date>=emp.start_date AND (emp.end_date IS NULL OR p_date<=emp.end_date)
   AND p_date<=(now() AT TIME ZONE v.timezone_name)::date AND extract(dow FROM p_date)::int+1=ANY(v.work_days)
   AND (p_after IS NULL OR e.employee_code>p_after)
  ORDER BY e.employee_code,e.id LIMIT p_limit+1
 ) targets JOIN people.employments emp ON emp.tenant_id=p_tenant_id AND emp.id=targets.employment_id
 ORDER BY targets.employee_code,targets.employee_id FOR UPDATE OF emp;
 WITH candidates AS (
  SELECT e.employee_code,e.full_name,e.id employee_id,emp.id employment_id,a.id assignment_id,a.site_id,
   coalesce(o.policy_template_id,a.work_policy_template_id) policy_id,coalesce(o.policy_version,a.work_policy_version) version,
   v.timezone_name,v.schedule_kind,v.work_days,v.shift_start,v.shift_end,v.ends_next_day,v.break_minutes,v.required_minutes,v.earliest_punch,v.latest_punch,v.attribution_before_minutes,v.attribution_after_minutes,v.lateness_grace_minutes,v.early_leave_grace_minutes,
   CASE WHEN v.schedule_kind='fixed' THEN time.resolve_local(p_date+v.shift_start,v.timezone_name) ELSE time.resolve_local(p_date+coalesce(v.earliest_punch,'00:00:00'::time),v.timezone_name) END starts,
   CASE WHEN v.schedule_kind='fixed' THEN time.resolve_local((p_date+CASE WHEN v.ends_next_day THEN 1 ELSE 0 END)+v.shift_end,v.timezone_name) ELSE time.resolve_local(p_date+coalesce(v.latest_punch,'23:59:59'::time),v.timezone_name) END ends
  FROM people.work_assignments a JOIN people.employments emp ON emp.tenant_id=a.tenant_id AND emp.id=a.employment_id
  JOIN people.employees e ON e.tenant_id=emp.tenant_id AND e.id=emp.employee_id JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id
  LEFT JOIN LATERAL(SELECT po.policy_template_id,po.policy_version FROM time.work_policy_overrides po WHERE po.tenant_id=a.tenant_id AND po.employment_id=emp.id AND po.cancelled_at IS NULL AND po.valid_from<=p_date AND po.valid_until>p_date ORDER BY po.valid_from DESC LIMIT 1)o ON true
  JOIN time.work_policy_templates t ON t.tenant_id=a.tenant_id AND t.id=coalesce(o.policy_template_id,a.work_policy_template_id)
  JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=coalesce(o.policy_version,a.work_policy_version)
  WHERE a.tenant_id=p_tenant_id AND p_date>=a.valid_from AND (a.valid_until IS NULL OR p_date<a.valid_until) AND p_date>=emp.start_date AND (emp.end_date IS NULL OR p_date<=emp.end_date)
   AND v.schedule_kind IN('fixed','flexible') AND p_date<=(now() AT TIME ZONE v.timezone_name)::date AND extract(dow FROM p_date)::int+1=ANY(v.work_days) AND (p_after IS NULL OR e.employee_code>p_after)
  ORDER BY e.employee_code,e.id LIMIT p_limit+1
 ), visible AS (SELECT * FROM candidates ORDER BY employee_code,employee_id LIMIT p_limit), inserted AS (
  INSERT INTO time.work_instances(tenant_id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by,break_minutes,lateness_grace_minutes,early_leave_grace_minutes,schedule_kind,required_minutes)
  SELECT p_tenant_id,c.assignment_id,c.employment_id,c.employee_id,c.site_id,p_date,c.policy_id,c.version,c.timezone_name,
   CASE WHEN c.schedule_kind='fixed' THEN c.starts END,CASE WHEN c.schedule_kind='fixed' THEN c.ends END,
   CASE WHEN c.starts IS NULL THEN NULL WHEN c.schedule_kind='fixed' THEN c.starts-make_interval(mins=>c.attribution_before_minutes) ELSE c.starts END,
   CASE WHEN c.ends IS NULL THEN NULL WHEN c.schedule_kind='fixed' THEN c.ends+make_interval(mins=>c.attribution_after_minutes) ELSE c.ends END,
   CASE WHEN c.starts IS NULL OR c.ends IS NULL THEN 'needs_review' ELSE 'open' END,actor,c.break_minutes,c.lateness_grace_minutes,c.early_leave_grace_minutes,c.schedule_kind,c.required_minutes FROM visible c
  ON CONFLICT(tenant_id,assignment_id,operational_date) DO NOTHING RETURNING id,assignment_id,status,timezone_name,expected_start,expected_end,schedule_kind,attribution_start,attribution_end
 ), initial_exceptions AS (
  INSERT INTO time.interpretations(tenant_id,work_instance_id,version,state,exception_code,owner_permission,input_fingerprint,created_by)
  SELECT p_tenant_id,i.id,1,'needs_review','ambiguous_local_time','attendance.correct',md5(i.id::text||'ambiguous-local-time'),actor FROM inserted i
  WHERE i.attribution_start IS NULL OR i.attribution_end IS NULL OR (i.schedule_kind='fixed' AND (i.expected_start IS NULL OR i.expected_end IS NULL)) RETURNING id
 ), opened_audit AS (
  INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) SELECT p_tenant_id,actor,'work_instance.opened',i.id,jsonb_build_object('operational_date',p_date) FROM inserted i RETURNING id
 ), page AS (
  SELECT n.id,p_date operational_date,n.status,n.timezone_name,c.employee_code,c.full_name,n.expected_start,n.expected_end,n.schedule_kind,c.required_minutes FROM inserted n JOIN visible c ON c.assignment_id=n.assignment_id
  UNION ALL SELECT i.id,i.operational_date,i.status,i.timezone_name,e.employee_code,e.full_name,i.expected_start,i.expected_end,i.schedule_kind,i.required_minutes FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id JOIN visible c ON c.assignment_id=i.assignment_id
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
