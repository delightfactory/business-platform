-- Read-only, nonfinancial Attendance-to-Payroll boundary. No publication ledger or Payroll consumer exists in Cube 2.
CREATE FUNCTION public.attendance_payroll_input_projection(
 p_tenant_id uuid,p_period_start date,p_period_end date,
 p_after_date date DEFAULT NULL,p_after_employee_code text DEFAULT NULL,p_after_instance_id uuid DEFAULT NULL,p_limit integer DEFAULT 100
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); items jsonb; more boolean; cursor_value jsonb;
BEGIN
 IF actor IS NULL OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view')
   OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage')
   OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct')
   OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve')
   OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN
   RAISE EXCEPTION 'attendance_payroll_projection_forbidden' USING ERRCODE='42501';
 END IF;
 IF p_period_start IS NULL OR p_period_end IS NULL OR p_period_end<p_period_start OR p_period_end-p_period_start>30
   OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
   OR (p_after_date IS NULL)<>(p_after_employee_code IS NULL)
   OR (p_after_date IS NULL)<>(p_after_instance_id IS NULL)
   OR coalesce(length(p_after_employee_code),0)>64
   OR (p_after_date IS NOT NULL AND (p_after_date<p_period_start OR p_after_date>p_period_end OR p_after_employee_code='')) THEN
   RAISE EXCEPTION 'attendance_payroll_projection_input_invalid' USING ERRCODE='22023';
 END IF;

 WITH current_facts AS (
   SELECT i.tenant_id,i.id work_instance_id,i.operational_date,i.employee_id,e.employee_code,
     i.employment_id,i.assignment_id,i.site_id,i.policy_template_id,i.policy_version,i.timezone_name,
     f.id attendance_fact_id,f.version attendance_fact_version,f.corrects_fact_id,f.reason correction_reason,
     f.fact,f.created_at approved_at
   FROM time.work_instances i
   JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
   JOIN LATERAL(SELECT af.* FROM time.attendance_facts af WHERE af.tenant_id=i.tenant_id AND af.work_instance_id=i.id ORDER BY af.version DESC LIMIT 1)f ON true
   WHERE i.tenant_id=p_tenant_id AND i.status='approved' AND i.operational_date BETWEEN p_period_start AND p_period_end
     AND f.fact->>'outcome' IN('worked','absence')
     AND (p_after_date IS NULL OR (i.operational_date,e.employee_code,i.id)>(p_after_date,p_after_employee_code,p_after_instance_id))
 ), projected AS (
   SELECT c.*,
     overtime.items overtime_quantities,
     md5(concat_ws('|',c.attendance_fact_id::text,c.attendance_fact_version::text,c.corrects_fact_id::text,
       c.policy_template_id::text,c.policy_version::text,overtime.version_keys)) input_version
   FROM current_facts c
   LEFT JOIN LATERAL(
     SELECT coalesce(jsonb_agg(jsonb_build_object(
       'overtime_candidate_id',oc.id,'attendance_fact_id',oc.attendance_fact_id,
       'decision_event_id',re.id,'category',oc.category,'minutes',oc.candidate_minutes,
       'approved_at',re.created_at,'reason',re.reason
     ) ORDER BY oc.id),'[]'::jsonb) items,
     coalesce(string_agg(oc.id::text||':'||re.id::text,',' ORDER BY oc.id),'') version_keys
     FROM time.attendance_overtime_candidates oc
     JOIN time.attendance_overtime_review_events re ON re.tenant_id=oc.tenant_id AND re.candidate_id=oc.id AND re.decision='approved'
     WHERE oc.tenant_id=c.tenant_id AND oc.work_instance_id=c.work_instance_id AND oc.attendance_fact_id=c.attendance_fact_id
   ) overtime ON true
 ), batch AS (
   SELECT * FROM projected ORDER BY operational_date,employee_code,work_instance_id LIMIT p_limit+1
 ), visible AS (
   SELECT * FROM batch ORDER BY operational_date,employee_code,work_instance_id LIMIT p_limit
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'work_instance_id',work_instance_id,'operational_date',operational_date,
   'employee_id',employee_id,'employee_code',employee_code,'employment_id',employment_id,
   'assignment_id',assignment_id,'site_id',site_id,
   'policy_version',jsonb_build_object('template_id',policy_template_id,'version',policy_version,'timezone_name',timezone_name),
   'attendance_fact_id',attendance_fact_id,'attendance_fact_version',attendance_fact_version,
   'corrects_fact_id',corrects_fact_id,'correction_reason',correction_reason,
   'approved_at',approved_at,'outcome',fact->>'outcome','absence_units',fact->'absence_units',
   'worked_minutes',fact->'worked_minutes','gross_worked_minutes',fact->'gross_worked_minutes',
   'scheduled_break_minutes',fact->'scheduled_break_minutes','late_minutes',fact->'late_minutes',
   'early_leave_minutes',fact->'early_leave_minutes','overtime_quantities',overtime_quantities,
   'input_version',input_version,'consumed',false
 ) ORDER BY operational_date,employee_code,work_instance_id),'[]'::jsonb),
   (SELECT count(*)>p_limit FROM batch),
   (SELECT jsonb_build_object('operational_date',operational_date,'employee_code',employee_code,'work_instance_id',work_instance_id)
    FROM visible ORDER BY operational_date DESC,employee_code DESC,work_instance_id DESC LIMIT 1)
 INTO items,more,cursor_value FROM visible;
 RETURN jsonb_build_object('contract_version',1,'boundary_status','projection_only','consumed',false,
   'period_start',p_period_start,'period_end',p_period_end,'items',items,'next_cursor',CASE WHEN more THEN cursor_value END,
   'has_more',more,'limit',p_limit);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_payroll_input_projection(uuid,date,date,date,text,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_payroll_input_projection(uuid,date,date,date,text,uuid,integer) TO authenticated;
