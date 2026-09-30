-- Preserve the public queue contract while keeping the day-wide work in two
-- aggregates. The page walks employee codes and enriches only its 51 rows.
CREATE INDEX people_employees_attendance_queue_order_idx
  ON people.employees(tenant_id, employee_code, id);
CREATE INDEX work_instances_employee_day_queue_idx
  ON time.work_instances(tenant_id, employee_id, operational_date, id);

CREATE OR REPLACE FUNCTION public.attendance_review_queue(
 p_tenant_id uuid,p_operational_date date,p_filter text DEFAULT 'all',p_after text DEFAULT NULL,p_limit integer DEFAULT 50
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); summary jsonb; rows jsonb; next_code text; more boolean;
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

 -- This scan is independent of the cursor and filter, as required by the
 -- existing count contract. Latest interpretations and fact existence are
 -- read only where they affect the counts.
 WITH day_counts AS (
   SELECT count(*) FILTER(WHERE i.status='needs_review')::integer needs_review,
     count(*) FILTER(WHERE i.status='needs_review' OR (i.status='ready' AND q.exception_code IS NOT NULL))::integer exception_count,
     count(*) FILTER(WHERE i.status='ready' AND q.state='ready' AND q.exception_code IS NULL
       AND NOT EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id))::integer clean_ready
   FROM time.work_instances i
   LEFT JOIN LATERAL (
     SELECT x.state,x.exception_code FROM time.interpretations x
     WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id AND i.status='ready'
     ORDER BY x.version DESC LIMIT 1
   ) q ON true
   WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_operational_date
 ), overtime_counts AS (
   SELECT count(*)::integer overtime_pending
   FROM time.work_instances i
   JOIN time.attendance_overtime_candidates c ON c.tenant_id=i.tenant_id AND c.work_instance_id=i.id
   JOIN LATERAL (
     SELECT f.id FROM time.attendance_facts f
     WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id
     ORDER BY f.version DESC LIMIT 1
   ) latest ON latest.id=c.attendance_fact_id
   LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
   WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_operational_date AND i.status='approved'
     AND (r.id IS NULL OR (r.decision='approved' AND NOT EXISTS(
       SELECT 1 FROM time.attendance_overtime_classification_events cl
       WHERE cl.tenant_id=c.tenant_id AND cl.candidate_id=c.id)))
 )
 SELECT jsonb_build_object('needs_review',d.needs_review,'exception_count',d.exception_count,
   'clean_ready',d.clean_ready,'overtime_pending',o.overtime_pending)
 INTO summary FROM day_counts d CROSS JOIN overtime_counts o;

 -- The filter is applied before the page limit. For the overtime filter and
 -- approved rows in all, EXISTS stops at one pending candidate; the full
 -- candidate count is computed only for the selected page.
 WITH batch AS MATERIALIZED (
   SELECT i.id,i.operational_date,i.status,i.timezone_name,e.employee_code,e.full_name,
     q.state interpretation_state,q.exception_code,q.owner_permission,
     q.worked_minutes,q.late_minutes,q.early_leave_minutes, facts.has_fact
   FROM people.employees e
   JOIN time.work_instances i ON i.tenant_id=e.tenant_id AND i.employee_id=e.id
     AND i.operational_date=p_operational_date
   LEFT JOIN LATERAL (
     SELECT x.state,x.exception_code,x.owner_permission,x.worked_minutes,x.late_minutes,x.early_leave_minutes
     FROM time.interpretations x WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id
     ORDER BY x.version DESC LIMIT 1
   ) q ON true
   CROSS JOIN LATERAL (
     SELECT EXISTS(SELECT 1 FROM time.attendance_facts f
       WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id) has_fact
   ) facts
   WHERE e.tenant_id=p_tenant_id AND (p_after IS NULL OR e.employee_code>p_after)
     AND CASE p_filter
       WHEN 'exceptions' THEN i.status='needs_review' OR (i.status='ready' AND q.exception_code IS NOT NULL)
       WHEN 'ready' THEN i.status='ready' AND q.state='ready' AND q.exception_code IS NULL AND NOT facts.has_fact
       ELSE (p_filter='all' AND i.status IN('ready','needs_review')) OR
         (i.status='approved' AND EXISTS(
           SELECT 1 FROM time.attendance_overtime_candidates c
           JOIN LATERAL (
             SELECT f.id FROM time.attendance_facts f
             WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id
             ORDER BY f.version DESC LIMIT 1
           ) latest ON latest.id=c.attendance_fact_id
           LEFT JOIN time.attendance_overtime_review_events r
             ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
           WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id
             AND (r.id IS NULL OR (r.decision='approved' AND NOT EXISTS(
               SELECT 1 FROM time.attendance_overtime_classification_events cl
                WHERE cl.tenant_id=c.tenant_id AND cl.candidate_id=c.id))))) END
   ORDER BY e.employee_code,i.id LIMIT p_limit+1
 ), enriched AS (
   SELECT b.*,
     (SELECT count(*)::integer FROM time.attendance_overtime_candidates c
       JOIN LATERAL (
         SELECT f.id FROM time.attendance_facts f
         WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id
         ORDER BY f.version DESC LIMIT 1
       ) latest ON latest.id=c.attendance_fact_id
       LEFT JOIN time.attendance_overtime_review_events r
         ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
       WHERE c.tenant_id=p_tenant_id AND c.work_instance_id=b.id AND b.status='approved'
         AND (r.id IS NULL OR (r.decision='approved' AND NOT EXISTS(
           SELECT 1 FROM time.attendance_overtime_classification_events cl
           WHERE cl.tenant_id=c.tenant_id AND cl.candidate_id=c.id)))) overtime_pending_count
   FROM batch b ORDER BY b.employee_code,b.id LIMIT p_limit
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'operational_date',operational_date,'status',status,'timezone_name',timezone_name,
    'employee_code',employee_code,'full_name',full_name,'exception_code',exception_code,'owner_permission',owner_permission,
    'worked_minutes',worked_minutes,'late_minutes',late_minutes,'early_leave_minutes',early_leave_minutes,
    'overtime_pending_count',overtime_pending_count,
    'can_bulk_approve',status='ready' AND interpretation_state='ready' AND exception_code IS NULL AND NOT has_fact)
    ORDER BY employee_code,id),'[]'::jsonb),
   max(employee_code),(SELECT count(*)>p_limit FROM batch)
 INTO rows,next_code,more FROM enriched;
 RETURN jsonb_build_object('items',rows,'counts',summary,'filter',p_filter,'limit',p_limit,
   'next_cursor',CASE WHEN more THEN next_code END,'has_more',more);
END $f$;

REVOKE ALL ON FUNCTION public.attendance_review_queue(uuid,date,text,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_review_queue(uuid,date,text,text,integer) TO authenticated;
