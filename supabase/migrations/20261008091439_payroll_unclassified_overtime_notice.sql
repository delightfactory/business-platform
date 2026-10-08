-- Original UX plan7.5: scoped informational attendance-source read only.
-- Does not change legacy projection, classification, payroll calculation or writes.
CREATE FUNCTION public.payroll_unclassified_overtime(
 p_tenant uuid, p_employer uuid, p_period uuid,
 p_after_date date DEFAULT NULL, p_after_employee_code text DEFAULT NULL,
 p_after_instance uuid DEFAULT NULL, p_limit integer DEFAULT 20
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
 actor uuid := auth.uid();
 bounds payroll.periods%ROWTYPE;
 result jsonb;
BEGIN
 PERFORM public.payroll_run_access(p_tenant);
 IF actor IS NULL OR NOT (
   platform_private.has_tenant_permission(p_tenant,actor,'attendance.view') OR
   platform_private.has_tenant_permission(p_tenant,actor,'attendance.manage') OR
   platform_private.has_tenant_permission(p_tenant,actor,'attendance.correct') OR
   platform_private.has_tenant_permission(p_tenant,actor,'attendance.approve') OR
   platform_private.has_tenant_permission(p_tenant,actor,'tenant.administer')
 ) THEN RAISE EXCEPTION 'payroll_overtime_view_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 OR
   num_nonnulls(p_after_date,p_after_employee_code,p_after_instance) NOT IN (0,3) OR
   (p_after_employee_code IS NOT NULL AND (p_after_employee_code='' OR length(p_after_employee_code)>64))
 THEN RAISE EXCEPTION 'payroll_overtime_input_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO bounds FROM payroll.periods
 WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF NOT FOUND OR NOT EXISTS (
   SELECT 1 FROM platform_core.tenant_legal_entities
   WHERE tenant_id=p_tenant AND id=p_employer AND is_active
 ) THEN RAISE EXCEPTION 'payroll_overtime_scope_forbidden' USING ERRCODE='42501'; END IF;
 IF p_after_date IS NOT NULL AND (p_after_date<bounds.starts_on OR p_after_date>bounds.ends_on)
 THEN RAISE EXCEPTION 'payroll_overtime_input_invalid' USING ERRCODE='22023'; END IF;
 -- A resolved item may disappear from the warning list; its source scope still validates.
 IF p_after_instance IS NOT NULL AND NOT EXISTS (
   SELECT 1 FROM time.work_instances i
   JOIN people.employments h ON h.tenant_id=i.tenant_id AND h.id=i.employment_id AND h.employee_id=i.employee_id
   JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
   WHERE i.tenant_id=p_tenant AND i.id=p_after_instance AND h.employer_entity_id=p_employer
     AND i.operational_date=p_after_date AND e.employee_code=p_after_employee_code
 ) THEN RAISE EXCEPTION 'payroll_overtime_cursor_forbidden' USING ERRCODE='42501'; END IF;
 WITH eligible AS (
   SELECT i.id work_instance_id,i.operational_date,e.employee_code,
     overtime.unclassified_count,overtime.unclassified_minutes,
     coalesce((time.attendance_fact_context_status(p_tenant,i.id)->>'classification_reconciliation_required')::boolean,false) reconciliation_required
   FROM time.work_instances i
   JOIN people.employments h ON h.tenant_id=i.tenant_id AND h.id=i.employment_id AND h.employee_id=i.employee_id
   JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
   JOIN LATERAL (
     SELECT af.id,af.fact FROM time.attendance_facts af
     WHERE af.tenant_id=i.tenant_id AND af.work_instance_id=i.id ORDER BY af.version DESC LIMIT 1
   ) fact ON true
   JOIN LATERAL (
     SELECT count(*)::integer unclassified_count,coalesce(sum(oc.candidate_minutes),0) unclassified_minutes
     FROM time.attendance_overtime_candidates oc
     LEFT JOIN time.attendance_overtime_review_events review ON review.tenant_id=oc.tenant_id AND review.candidate_id=oc.id
     LEFT JOIN LATERAL (
       SELECT ce.id FROM time.attendance_overtime_classification_events ce
       WHERE ce.tenant_id=oc.tenant_id AND ce.candidate_id=oc.id ORDER BY ce.version DESC LIMIT 1
     ) classification ON true
     WHERE oc.tenant_id=i.tenant_id AND oc.work_instance_id=i.id AND oc.attendance_fact_id=fact.id
       AND classification.id IS NULL AND coalesce(review.decision,'pending')<>'rejected'
   ) overtime ON overtime.unclassified_count>0
   WHERE i.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND i.status='approved'
     AND i.operational_date BETWEEN bounds.starts_on AND bounds.ends_on
     AND fact.fact->>'outcome' IN ('worked','absence','leave_covered')
 ), batch AS (
   SELECT * FROM eligible
   WHERE p_after_date IS NULL OR (operational_date,employee_code,work_instance_id)>(p_after_date,p_after_employee_code,p_after_instance)
   ORDER BY operational_date,employee_code,work_instance_id LIMIT p_limit+1
 ), visible AS (
   SELECT * FROM batch ORDER BY operational_date,employee_code,work_instance_id LIMIT p_limit
 )
 SELECT jsonb_build_object(
   'contract_version',1,
   'period',jsonb_build_object('id',bounds.id,'starts_on',bounds.starts_on,'ends_on',bounds.ends_on),
   'totals',(SELECT jsonb_build_object('instances',count(*),'minutes',coalesce(sum(unclassified_minutes),0),'reconciliation_required',count(*) FILTER(WHERE reconciliation_required)) FROM eligible),
   'items',coalesce((SELECT jsonb_agg(to_jsonb(v) ORDER BY v.operational_date,v.employee_code,v.work_instance_id) FROM visible v),'[]'::jsonb),
   'has_more',(SELECT count(*)>p_limit FROM batch),
   'next_cursor',CASE WHEN (SELECT count(*)>p_limit FROM batch) THEN (
     SELECT jsonb_build_object('operational_date',operational_date,'employee_code',employee_code,'work_instance_id',work_instance_id)
     FROM visible ORDER BY operational_date DESC,employee_code DESC,work_instance_id DESC LIMIT 1
   ) END
 ) INTO result;
 RETURN result;
END
$function$;
REVOKE ALL ON FUNCTION public.payroll_unclassified_overtime(uuid,uuid,uuid,date,text,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_unclassified_overtime(uuid,uuid,uuid,date,text,uuid,integer) TO authenticated;
