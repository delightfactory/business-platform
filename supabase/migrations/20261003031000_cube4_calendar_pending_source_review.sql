-- Reuse Time's current-fact and overtime review states; no source approval or consumption.
CREATE OR REPLACE FUNCTION payroll.calendar_change_review(p_tenant uuid,p_employer uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $f$
 SELECT jsonb_build_object(
  'open_run_period_id',(SELECT r.period_id FROM payroll.runs r WHERE r.tenant_id=p_tenant AND r.employer_id=p_employer AND r.status IN('draft','review','approved') ORDER BY r.created_at,r.id LIMIT 1),
  'locked_history',EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer),
  'attendance_enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',statement_timestamp()),
  'pending_attendance_date',CASE WHEN platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',statement_timestamp()) THEN
   (SELECT i.operational_date FROM time.work_instances i JOIN people.employments h ON h.tenant_id=i.tenant_id AND h.id=i.employment_id
    WHERE i.tenant_id=p_tenant AND h.employer_entity_id=p_employer
     AND EXISTS(SELECT 1 FROM payroll.periods p WHERE p.tenant_id=i.tenant_id AND p.employer_id=p_employer AND i.operational_date BETWEEN p.starts_on AND p.ends_on)
     AND(i.status IN('open','ready','needs_review') OR i.status='approved' AND(
      COALESCE((time.attendance_fact_context_status(i.tenant_id,i.id)->>'classification_reconciliation_required')::boolean,true)
      OR EXISTS(SELECT 1 FROM time.attendance_overtime_candidates c
       JOIN LATERAL(SELECT f.id FROM time.attendance_facts f WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1) latest ON latest.id=c.attendance_fact_id
       LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
       WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id AND(r.id IS NULL OR r.decision='approved' AND NOT EXISTS(SELECT 1 FROM time.attendance_overtime_classification_events cl WHERE cl.tenant_id=c.tenant_id AND cl.candidate_id=c.id)))))
    ORDER BY i.operational_date,i.id LIMIT 1) END,
  'can_review_attendance',platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.view')
   OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.manage')
   OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.correct')
   OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.approve')
   OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer'));
$f$;
REVOKE ALL ON FUNCTION payroll.calendar_change_review(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
