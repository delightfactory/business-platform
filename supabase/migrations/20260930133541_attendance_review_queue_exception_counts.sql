CREATE OR REPLACE FUNCTION public.attendance_review_queue(
 p_tenant_id uuid,p_operational_date date,p_filter text DEFAULT 'all',p_after text DEFAULT NULL,p_limit integer DEFAULT 50
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb; summary jsonb; rows jsonb; next_code text; more boolean;
BEGIN
 IF actor IS NULL OR p_operational_date IS NULL OR p_filter IS NULL OR p_filter NOT IN('all','exceptions','ready','overtime')
   OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR length(coalesce(p_after,''))>64
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view')
     OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage')
     OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct')
     OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve')
     OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN
   RAISE EXCEPTION 'attendance_review_queue_forbidden' USING ERRCODE='42501';
 END IF;
 WITH base AS (
   SELECT i.id,i.operational_date,i.status,e.employee_code,e.full_name,q.state interpretation_state,
     q.exception_code,q.owner_permission,q.worked_minutes,q.late_minutes,q.early_leave_minutes,
     (SELECT count(*)::integer FROM time.attendance_overtime_candidates c
       JOIN LATERAL(SELECT f.id FROM time.attendance_facts f WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1) f ON f.id=c.attendance_fact_id
       LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
       WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id AND r.id IS NULL AND i.status='approved') overtime_pending_count,
     EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id) has_fact
   FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
   LEFT JOIN LATERAL(SELECT x.* FROM time.interpretations x WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id ORDER BY x.version DESC LIMIT 1)q ON true
   WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_operational_date
 ), counts AS (
   SELECT count(*) FILTER(WHERE status='needs_review')::integer needs_review,
     count(*) FILTER(WHERE status='needs_review' OR (status='ready' AND exception_code IS NOT NULL))::integer exception_count,
     count(*) FILTER(WHERE status='ready' AND interpretation_state='ready' AND exception_code IS NULL AND NOT has_fact)::integer clean_ready,
     coalesce(sum(overtime_pending_count),0)::integer overtime_pending
   FROM base
 ) SELECT jsonb_build_object('needs_review',needs_review,'exception_count',exception_count,'clean_ready',clean_ready,'overtime_pending',overtime_pending) INTO summary FROM counts;

 WITH base AS (
   SELECT i.id,i.operational_date,i.status,i.timezone_name,e.employee_code,e.full_name,q.state interpretation_state,
     q.exception_code,q.owner_permission,q.worked_minutes,q.late_minutes,q.early_leave_minutes,
     (SELECT count(*)::integer FROM time.attendance_overtime_candidates c
       JOIN LATERAL(SELECT f.id FROM time.attendance_facts f WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1) f ON f.id=c.attendance_fact_id
       LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
       WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id AND r.id IS NULL AND i.status='approved') overtime_pending_count,
     EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id) has_fact
   FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
   LEFT JOIN LATERAL(SELECT x.* FROM time.interpretations x WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id ORDER BY x.version DESC LIMIT 1)q ON true
   WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_operational_date
 ), filtered AS (
   SELECT b.*, (status='ready' AND interpretation_state='ready' AND exception_code IS NULL AND NOT has_fact) can_bulk_approve
   FROM base b
   WHERE (p_after IS NULL OR employee_code>p_after)
     AND CASE p_filter
       WHEN 'exceptions' THEN status='needs_review' OR (status='ready' AND exception_code IS NOT NULL)
       WHEN 'ready' THEN status='ready' AND interpretation_state='ready' AND exception_code IS NULL AND NOT has_fact
       WHEN 'overtime' THEN overtime_pending_count>0
       ELSE status IN('ready','needs_review') OR overtime_pending_count>0 END
 ), batch AS (SELECT * FROM filtered ORDER BY employee_code,id LIMIT p_limit+1), visible AS (SELECT * FROM batch ORDER BY employee_code,id LIMIT p_limit)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'operational_date',operational_date,'status',status,'timezone_name',timezone_name,
    'employee_code',employee_code,'full_name',full_name,'exception_code',exception_code,'owner_permission',owner_permission,
    'worked_minutes',worked_minutes,'late_minutes',late_minutes,'early_leave_minutes',early_leave_minutes,
    'overtime_pending_count',overtime_pending_count,'can_bulk_approve',can_bulk_approve) ORDER BY employee_code,id),'[]'::jsonb),
   max(employee_code),(SELECT count(*)>p_limit FROM batch)
 INTO rows,next_code,more FROM visible;
 RETURN jsonb_build_object('items',rows,'counts',summary,'filter',p_filter,'limit',p_limit,'next_cursor',CASE WHEN more THEN next_code END,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_review_queue(uuid,date,text,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_review_queue(uuid,date,text,text,integer) TO authenticated;
