-- Calendar review is observational. It neither changes Attendance nor certifies input coverage.
CREATE FUNCTION payroll.calendar_change_review(p_tenant uuid,p_employer uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $f$
 SELECT jsonb_build_object(
  'open_run_period_id',(SELECT r.period_id FROM payroll.runs r WHERE r.tenant_id=p_tenant AND r.employer_id=p_employer AND r.status IN('draft','review','approved') ORDER BY r.created_at,r.id LIMIT 1),
  'locked_history',EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer),
  'attendance_enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',statement_timestamp()),
  'pending_attendance_date',CASE WHEN platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',statement_timestamp()) THEN
   (SELECT i.operational_date FROM time.work_instances i JOIN people.employments h ON h.tenant_id=i.tenant_id AND h.id=i.employment_id
    WHERE i.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND i.status IN('open','ready','needs_review')
     AND EXISTS(SELECT 1 FROM payroll.periods p WHERE p.tenant_id=i.tenant_id AND p.employer_id=p_employer AND i.operational_date BETWEEN p.starts_on AND p.ends_on)
    ORDER BY i.operational_date,i.id LIMIT 1) END,
  'can_review_attendance',platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.view'));
$f$;
REVOKE ALL ON FUNCTION payroll.calendar_change_review(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;anchor text:='RETURN result||pg_catalog.jsonb_build_object(''readiness''';BEGIN
 definition:=pg_get_functiondef('public.payroll_workspace(uuid,uuid,date,integer)'::regprocedure);
 IF position(anchor IN definition)=0 OR position('calendar_change_review' IN definition)>0 THEN RAISE EXCEPTION 'unexpected_calendar_change_review_anchor';END IF;
 EXECUTE replace(definition,anchor,'result:=result||jsonb_build_object(''calendar_change_review'',payroll.calendar_change_review(p_tenant,p_employer)); '||anchor);
END $f$;
