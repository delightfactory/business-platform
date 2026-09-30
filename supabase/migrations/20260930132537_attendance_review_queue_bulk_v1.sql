CREATE FUNCTION public.attendance_review_queue(
 p_tenant_id uuid,p_operational_date date,p_filter text DEFAULT 'all',p_after text DEFAULT NULL,p_limit integer DEFAULT 50
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb; summary jsonb; rows jsonb; next_code text; more boolean;
BEGIN
 IF actor IS NULL OR p_operational_date IS NULL
   OR p_filter IS NULL OR p_filter NOT IN('all','exceptions','ready','overtime')
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
       WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id AND r.id IS NULL) overtime_pending_count,
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
       WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id AND r.id IS NULL) overtime_pending_count,
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

CREATE FUNCTION public.approve_attendance_facts_bulk(p_tenant_id uuid,p_operational_date date,p_instance_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); item uuid; approval jsonb; row_result jsonb:='[]'::jsonb; approved_n integer:=0; skipped_n integer:=0; reason_code text; err_code text;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN
   RAISE EXCEPTION 'attendance_bulk_approval_forbidden' USING ERRCODE='42501';
 END IF;
 IF p_operational_date IS NULL OR coalesce(cardinality(p_instance_ids),0) NOT BETWEEN 1 AND 50
   OR EXISTS(SELECT 1 FROM unnest(p_instance_ids) AS u(id) WHERE id IS NULL)
   OR cardinality(ARRAY(SELECT DISTINCT id FROM unnest(p_instance_ids) AS u(id)))<>cardinality(p_instance_ids) THEN
   RAISE EXCEPTION 'attendance_bulk_approval_input_invalid' USING ERRCODE='22023';
 END IF;

 -- Acquire locks in stable order; each item is still revalidated under the existing single-item approval RPC.
 PERFORM i.id FROM time.work_instances i WHERE i.tenant_id=p_tenant_id AND i.id=ANY(p_instance_ids) ORDER BY i.id FOR UPDATE;
 FOREACH item IN ARRAY p_instance_ids LOOP
   reason_code:=NULL;
   IF NOT EXISTS(SELECT 1 FROM time.work_instances i WHERE i.tenant_id=p_tenant_id AND i.id=item AND i.operational_date=p_operational_date) THEN
     reason_code:='record_unavailable';
   ELSIF NOT EXISTS(
     SELECT 1 FROM time.work_instances i
     JOIN LATERAL(SELECT q.state,q.exception_code FROM time.interpretations q WHERE q.tenant_id=i.tenant_id AND q.work_instance_id=i.id ORDER BY q.version DESC LIMIT 1) q ON true
     WHERE i.tenant_id=p_tenant_id AND i.id=item AND i.operational_date=p_operational_date AND i.status='ready'
       AND q.state='ready' AND q.exception_code IS NULL
       AND NOT EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id)
   ) THEN reason_code:='not_clean_or_stale';
   ELSE
     BEGIN
       approval:=public.approve_attendance_fact(p_tenant_id,item,NULL,NULL);
       approved_n:=approved_n+1;
       row_result:=row_result||jsonb_build_array(jsonb_build_object('instance_id',item,'state','approved','fact_id',approval->>'fact_id'));
     EXCEPTION WHEN OTHERS THEN
       GET STACKED DIAGNOSTICS err_code=RETURNED_SQLSTATE;
       IF err_code NOT IN('42501','P0002','23514','40001','22023') THEN RAISE; END IF;
       reason_code:=CASE WHEN err_code='42501' THEN 'access_changed' WHEN err_code='P0002' THEN 'record_unavailable' ELSE 'not_clean_or_stale' END;
     END;
   END IF;
   IF reason_code IS NOT NULL THEN
     skipped_n:=skipped_n+1;
     row_result:=row_result||jsonb_build_array(jsonb_build_object('instance_id',item,'state','skipped','reason_code',reason_code));
     IF EXISTS(SELECT 1 FROM time.work_instances i WHERE i.tenant_id=p_tenant_id AND i.id=item) THEN
       INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
       VALUES(p_tenant_id,actor,'attendance.bulk_approval.item_skipped',item,jsonb_build_object('operational_date',p_operational_date,'reason_code',reason_code));
     END IF;
   END IF;
 END LOOP;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,details)
 VALUES(p_tenant_id,actor,'attendance.bulk_approval.completed',jsonb_build_object('operational_date',p_operational_date,'requested_count',cardinality(p_instance_ids),'approved_count',approved_n,'skipped_count',skipped_n));
 RETURN jsonb_build_object('operational_date',p_operational_date,'requested_count',cardinality(p_instance_ids),'approved_count',approved_n,'skipped_count',skipped_n,'items',row_result);
END $f$;
REVOKE ALL ON FUNCTION public.approve_attendance_facts_bulk(uuid,date,uuid[]) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.approve_attendance_facts_bulk(uuid,date,uuid[]) TO authenticated;
