-- Initial absence approval accepts retained raw evidence only when each source
-- is excluded by the same append-only correction rule used by interpretation.
CREATE OR REPLACE FUNCTION public.approve_attendance_absence(p_tenant_id uuid,p_instance_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); i time.work_instances%ROWTYPE; e_id uuid; q time.interpretations%ROWTYPE; fact_id uuid; version_n integer;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_approve_forbidden' USING ERRCODE='42501'; END IF;
 IF length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_absence_reason_required' USING ERRCODE='22023'; END IF;
 SELECT employment_id INTO e_id FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 PERFORM 1 FROM people.employments WHERE tenant_id=p_tenant_id AND id=e_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_employment_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE;
 IF NOT FOUND OR i.employment_id IS DISTINCT FROM e_id THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF NOT FOUND OR q.state<>'needs_review' OR q.exception_code<>'absence_candidate'
  OR EXISTS(SELECT 1 FROM time.attendance_facts f WHERE f.tenant_id=p_tenant_id AND f.work_instance_id=p_instance_id)
  OR EXISTS(SELECT 1 FROM time.manual_punches p WHERE p.tenant_id=p_tenant_id AND p.work_instance_id=p_instance_id
    AND NOT EXISTS(SELECT 1 FROM time.punch_corrections c WHERE c.tenant_id=p.tenant_id AND c.punch_id=p.id AND c.action='exclude'))
 THEN RAISE EXCEPTION 'attendance_absence_not_eligible' USING ERRCODE='23514'; END IF;
 SELECT coalesce(max(version),0)+1 INTO version_n FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id;
 INSERT INTO time.attendance_facts(tenant_id,work_instance_id,version,interpretation_id,reason,fact,actor_user_id)
 VALUES(p_tenant_id,p_instance_id,version_n,q.id,btrim(p_reason),jsonb_build_object('outcome','absence','absence_units',1,'operational_date',i.operational_date,'employee_id',i.employee_id,'assignment_id',i.assignment_id,'site_id',i.site_id,'timezone_name',i.timezone_name,'expected_start',i.expected_start,'expected_end',i.expected_end,'late_minutes',NULL,'early_leave_minutes',NULL,'worked_minutes',0),actor) RETURNING id INTO fact_id;
 UPDATE time.work_instances SET status='approved' WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,'attendance.absence.approved',p_instance_id,jsonb_build_object('fact_id',fact_id,'version',version_n,'absence_units',1,'reason',btrim(p_reason)));
 RETURN jsonb_build_object('state','approved_absence','fact_id',fact_id,'version',version_n,'absence_units',1);
END $f$;
REVOKE ALL ON FUNCTION public.approve_attendance_absence(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.approve_attendance_absence(uuid,uuid,text) TO authenticated;

-- An absence correction is a new immutable fact linked to the exact current fact.
CREATE FUNCTION public.correct_attendance_absence(p_tenant_id uuid,p_instance_id uuid,p_corrects_fact_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); i time.work_instances%ROWTYPE; e_id uuid; q time.interpretations%ROWTYPE; latest_fact time.attendance_facts%ROWTYPE; fact_id uuid; version_n integer;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now())
  OR NOT ((platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') AND platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve')) OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'))
 THEN RAISE EXCEPTION 'attendance_absence_correct_forbidden' USING ERRCODE='42501'; END IF;
 IF p_corrects_fact_id IS NULL OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_absence_correction_input_invalid' USING ERRCODE='22023'; END IF;
 SELECT employment_id INTO e_id FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 PERFORM 1 FROM people.employments WHERE tenant_id=p_tenant_id AND id=e_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_employment_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE;
 IF NOT FOUND OR i.employment_id IS DISTINCT FROM e_id THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF NOT FOUND OR q.state<>'needs_review' OR q.exception_code<>'absence_candidate'
  OR EXISTS(SELECT 1 FROM time.manual_punches p WHERE p.tenant_id=p_tenant_id AND p.work_instance_id=p_instance_id
    AND NOT EXISTS(SELECT 1 FROM time.punch_corrections c WHERE c.tenant_id=p.tenant_id AND c.punch_id=p.id AND c.action='exclude'))
 THEN RAISE EXCEPTION 'attendance_absence_not_eligible' USING ERRCODE='23514'; END IF;
 SELECT * INTO latest_fact FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF NOT FOUND OR latest_fact.id IS DISTINCT FROM p_corrects_fact_id THEN RAISE EXCEPTION 'attendance_fact_version_stale' USING ERRCODE='40001'; END IF;
 IF latest_fact.interpretation_id=q.id THEN RAISE EXCEPTION 'attendance_fact_no_new_interpretation' USING ERRCODE='23514'; END IF;
 SELECT coalesce(max(version),0)+1 INTO version_n FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id;
 INSERT INTO time.attendance_facts(tenant_id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id)
 VALUES(p_tenant_id,p_instance_id,version_n,q.id,latest_fact.id,btrim(p_reason),jsonb_build_object('outcome','absence','absence_units',1,'operational_date',i.operational_date,'employee_id',i.employee_id,'assignment_id',i.assignment_id,'site_id',i.site_id,'timezone_name',i.timezone_name,'expected_start',i.expected_start,'expected_end',i.expected_end,'late_minutes',NULL,'early_leave_minutes',NULL,'worked_minutes',0),actor) RETURNING id INTO fact_id;
 UPDATE time.work_instances SET status='approved' WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,'attendance.absence.corrected',p_instance_id,jsonb_build_object('fact_id',fact_id,'version',version_n,'corrects_fact_id',latest_fact.id,'absence_units',1,'reason',btrim(p_reason)));
 RETURN jsonb_build_object('state','approved_absence','fact_id',fact_id,'version',version_n,'corrects_fact_id',latest_fact.id,'absence_units',1);
END $f$;
REVOKE ALL ON FUNCTION public.correct_attendance_absence(uuid,uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.correct_attendance_absence(uuid,uuid,uuid,text) TO authenticated;
