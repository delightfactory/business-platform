CREATE TABLE time.attendance_overtime_classification_events(
 tenant_id uuid NOT NULL,
 id uuid NOT NULL DEFAULT gen_random_uuid(),
 candidate_id uuid NOT NULL,
 version integer NOT NULL CHECK(version>0),
 review_event_id bigint NOT NULL,
 ordinary_day_minutes integer NOT NULL CHECK(ordinary_day_minutes>=0),
 ordinary_night_minutes integer NOT NULL CHECK(ordinary_night_minutes>=0),
 weekly_rest_minutes integer NOT NULL CHECK(weekly_rest_minutes>=0),
 official_holiday_minutes integer NOT NULL CHECK(official_holiday_minutes>=0),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 3 AND 500),
 request_fingerprint text NOT NULL,
 actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 PRIMARY KEY(tenant_id,id), UNIQUE(tenant_id,candidate_id,version), UNIQUE(tenant_id,candidate_id,request_fingerprint),
 FOREIGN KEY(tenant_id,candidate_id) REFERENCES time.attendance_overtime_candidates(tenant_id,id) ON DELETE RESTRICT,
 FOREIGN KEY(tenant_id,review_event_id) REFERENCES time.attendance_overtime_review_events(tenant_id,id) ON DELETE RESTRICT
);
CREATE INDEX attendance_overtime_class_latest_idx ON time.attendance_overtime_classification_events(tenant_id,candidate_id,version DESC);
ALTER TABLE time.attendance_overtime_classification_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON time.attendance_overtime_classification_events FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER attendance_overtime_classification_append_only BEFORE UPDATE OR DELETE ON time.attendance_overtime_classification_events FOR EACH ROW EXECUTE FUNCTION time.prevent_overtime_mutation();

CREATE OR REPLACE FUNCTION public.review_attendance_overtime(p_tenant_id uuid,p_candidate_id uuid,p_decision text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); wi time.work_instances%ROWTYPE; c time.attendance_overtime_candidates%ROWTYPE; latest_fact uuid; event_id bigint;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_overtime_review_forbidden' USING ERRCODE='42501'; END IF;
 IF p_decision IS NULL OR p_decision NOT IN('approved','rejected') OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_overtime_review_input_invalid' USING ERRCODE='22023'; END IF;
 IF p_decision='approved' THEN RAISE EXCEPTION 'attendance_overtime_classification_required' USING ERRCODE='23514'; END IF;
 SELECT * INTO c FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND id=p_candidate_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_overtime_candidate_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=c.work_instance_id FOR UPDATE;
 SELECT * INTO c FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND id=p_candidate_id FOR UPDATE;
 SELECT f.id INTO latest_fact FROM time.attendance_facts f WHERE f.tenant_id=p_tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1;
 IF EXISTS(SELECT 1 FROM time.attendance_overtime_review_events r WHERE r.tenant_id=p_tenant_id AND r.candidate_id=p_candidate_id) THEN RAISE EXCEPTION 'attendance_overtime_already_reviewed' USING ERRCODE='23514'; END IF;
 IF latest_fact IS DISTINCT FROM c.attendance_fact_id OR wi.status<>'approved' THEN RAISE EXCEPTION 'attendance_overtime_candidate_stale' USING ERRCODE='40001'; END IF;
 INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id) VALUES(p_tenant_id,p_candidate_id,'rejected',btrim(p_reason),actor) RETURNING id INTO event_id;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
 VALUES(p_tenant_id,actor,'overtime.candidate.rejected',c.work_instance_id,jsonb_build_object('candidate_id',p_candidate_id,'attendance_fact_id',c.attendance_fact_id,'candidate_minutes',c.candidate_minutes,'reason',btrim(p_reason),'review_event_id',event_id));
 RETURN jsonb_build_object('candidate_id',p_candidate_id,'decision','rejected','candidate_minutes',c.candidate_minutes);
END $f$;
REVOKE ALL ON FUNCTION public.review_attendance_overtime(uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.review_attendance_overtime(uuid,uuid,text,text) TO authenticated;

CREATE FUNCTION public.classify_attendance_overtime(
 p_tenant_id uuid,p_candidate_id uuid,p_ordinary_day integer,p_ordinary_night integer,p_weekly_rest integer,p_official_holiday integer,p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); c time.attendance_overtime_candidates%ROWTYPE; wi time.work_instances%ROWTYPE; latest_fact uuid; decision_event time.attendance_overtime_review_events%ROWTYPE; had_decision boolean; class_id uuid; class_version integer; fingerprint text;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_overtime_review_forbidden' USING ERRCODE='42501'; END IF;
 IF p_ordinary_day IS NULL OR p_ordinary_day<0 OR p_ordinary_night IS NULL OR p_ordinary_night<0 OR p_weekly_rest IS NULL OR p_weekly_rest<0
   OR p_official_holiday IS NULL OR p_official_holiday<0 OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN
   RAISE EXCEPTION 'attendance_overtime_classification_invalid' USING ERRCODE='22023';
 END IF;
 SELECT * INTO c FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND id=p_candidate_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_overtime_candidate_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=c.work_instance_id FOR UPDATE;
 SELECT * INTO c FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND id=p_candidate_id FOR UPDATE;
 SELECT f.id INTO latest_fact FROM time.attendance_facts f WHERE f.tenant_id=p_tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1;
 IF latest_fact IS DISTINCT FROM c.attendance_fact_id OR wi.status<>'approved' THEN RAISE EXCEPTION 'attendance_overtime_candidate_stale' USING ERRCODE='40001'; END IF;
 IF p_ordinary_day+p_ordinary_night+p_weekly_rest+p_official_holiday<>c.candidate_minutes THEN RAISE EXCEPTION 'attendance_overtime_classification_sum_invalid' USING ERRCODE='23514'; END IF;
 SELECT * INTO decision_event FROM time.attendance_overtime_review_events r WHERE r.tenant_id=p_tenant_id AND r.candidate_id=p_candidate_id;
 had_decision:=FOUND;
 IF FOUND AND decision_event.decision<>'approved' THEN RAISE EXCEPTION 'attendance_overtime_already_reviewed' USING ERRCODE='23514'; END IF;
 fingerprint:=md5(concat_ws(':',p_ordinary_day,p_ordinary_night,p_weekly_rest,p_official_holiday,btrim(p_reason)));
 SELECT id,version INTO class_id,class_version FROM time.attendance_overtime_classification_events WHERE tenant_id=p_tenant_id AND candidate_id=p_candidate_id AND request_fingerprint=fingerprint;
 IF FOUND THEN RETURN jsonb_build_object('candidate_id',p_candidate_id,'decision','approved','classification_id',class_id,'classification_version',class_version,'unchanged',true); END IF;
 IF NOT had_decision THEN
   INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id) VALUES(p_tenant_id,p_candidate_id,'approved',btrim(p_reason),actor) RETURNING * INTO decision_event;
 END IF;
 SELECT coalesce(max(version),0)+1 INTO class_version FROM time.attendance_overtime_classification_events WHERE tenant_id=p_tenant_id AND candidate_id=p_candidate_id;
 INSERT INTO time.attendance_overtime_classification_events(tenant_id,candidate_id,version,review_event_id,ordinary_day_minutes,ordinary_night_minutes,weekly_rest_minutes,official_holiday_minutes,reason,request_fingerprint,actor_user_id)
 VALUES(p_tenant_id,p_candidate_id,class_version,decision_event.id,p_ordinary_day,p_ordinary_night,p_weekly_rest,p_official_holiday,btrim(p_reason),fingerprint,actor) RETURNING id INTO class_id;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
 VALUES(p_tenant_id,actor,'overtime.candidate.classified',c.work_instance_id,jsonb_build_object('candidate_id',p_candidate_id,'attendance_fact_id',c.attendance_fact_id,'candidate_minutes',c.candidate_minutes,'classification_version',class_version,'classification_event_id',class_id,'ordinary_day_minutes',p_ordinary_day,'ordinary_night_minutes',p_ordinary_night,'weekly_rest_minutes',p_weekly_rest,'official_holiday_minutes',p_official_holiday,'reason',btrim(p_reason)));
 RETURN jsonb_build_object('candidate_id',p_candidate_id,'decision','approved','classification_id',class_id,'classification_version',class_version,'unchanged',false);
END $f$;
REVOKE ALL ON FUNCTION public.classify_attendance_overtime(uuid,uuid,integer,integer,integer,integer,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.classify_attendance_overtime(uuid,uuid,integer,integer,integer,integer,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.attendance_payroll_input_projection(
 p_tenant_id uuid,p_period_start date,p_period_end date,
 p_after_date date DEFAULT NULL,p_after_employee_code text DEFAULT NULL,p_after_instance_id uuid DEFAULT NULL,p_limit integer DEFAULT 100
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); items jsonb; more boolean; cursor_value jsonb;
BEGIN
 IF actor IS NULL OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_payroll_projection_forbidden' USING ERRCODE='42501'; END IF;
 IF p_period_start IS NULL OR p_period_end IS NULL OR p_period_end<p_period_start OR p_period_end-p_period_start>30 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
   OR (p_after_date IS NULL)<>(p_after_employee_code IS NULL) OR (p_after_date IS NULL)<>(p_after_instance_id IS NULL) OR coalesce(length(p_after_employee_code),0)>64
   OR (p_after_date IS NOT NULL AND (p_after_date<p_period_start OR p_after_date>p_period_end OR p_after_employee_code='')) THEN RAISE EXCEPTION 'attendance_payroll_projection_input_invalid' USING ERRCODE='22023'; END IF;
 WITH current_facts AS (
   SELECT i.tenant_id,i.id work_instance_id,i.operational_date,i.employee_id,e.employee_code,i.employment_id,i.assignment_id,i.site_id,i.policy_template_id,i.policy_version,i.timezone_name,
     f.id attendance_fact_id,f.version attendance_fact_version,f.corrects_fact_id,f.reason correction_reason,f.fact,f.created_at approved_at
   FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
   JOIN LATERAL(SELECT af.* FROM time.attendance_facts af WHERE af.tenant_id=i.tenant_id AND af.work_instance_id=i.id ORDER BY af.version DESC LIMIT 1)f ON true
   WHERE i.tenant_id=p_tenant_id AND i.status='approved' AND i.operational_date BETWEEN p_period_start AND p_period_end
     AND f.fact->>'outcome' IN('worked','absence')
     AND (p_after_date IS NULL OR (i.operational_date,e.employee_code,i.id)>(p_after_date,p_after_employee_code,p_after_instance_id))
 ), projected AS (
   SELECT c.*,overtime.items overtime_quantities,overtime.unclassified_count,overtime.unclassified_minutes,
     md5(concat_ws('|',c.attendance_fact_id::text,c.attendance_fact_version::text,c.corrects_fact_id::text,c.policy_template_id::text,c.policy_version::text,overtime.version_keys,overtime.unclassified_count::text,overtime.unclassified_minutes::text)) input_version
   FROM current_facts c LEFT JOIN LATERAL(
     SELECT coalesce(jsonb_agg(jsonb_build_object('overtime_candidate_id',x.id,'attendance_fact_id',x.attendance_fact_id,
       'classification_event_id',x.classification_id,'classification_version',x.classification_version,
       'minutes',x.candidate_minutes,'categories',jsonb_build_object('ordinary_day',x.ordinary_day_minutes,'ordinary_night',x.ordinary_night_minutes,'weekly_rest',x.weekly_rest_minutes,'official_holiday',x.official_holiday_minutes),
       'approved_at',x.classified_at,'reason',x.classification_reason) ORDER BY x.id) FILTER(WHERE x.decision='approved' AND x.classification_id IS NOT NULL),'[]'::jsonb) items,
       coalesce(string_agg(x.id::text||':'||coalesce(x.classification_id::text,'unclassified'),',' ORDER BY x.id),'') version_keys,
       count(*) FILTER(WHERE x.classification_id IS NULL AND coalesce(x.decision,'pending')<>'rejected')::integer unclassified_count,
       coalesce(sum(x.candidate_minutes) FILTER(WHERE x.classification_id IS NULL AND coalesce(x.decision,'pending')<>'rejected'),0)::integer unclassified_minutes
     FROM (
       SELECT oc.*,re.decision,cl.id classification_id,cl.version classification_version,cl.ordinary_day_minutes,cl.ordinary_night_minutes,cl.weekly_rest_minutes,cl.official_holiday_minutes,cl.created_at classified_at,cl.reason classification_reason
       FROM time.attendance_overtime_candidates oc
       LEFT JOIN time.attendance_overtime_review_events re ON re.tenant_id=oc.tenant_id AND re.candidate_id=oc.id
       LEFT JOIN LATERAL(SELECT ce.* FROM time.attendance_overtime_classification_events ce WHERE ce.tenant_id=oc.tenant_id AND ce.candidate_id=oc.id ORDER BY ce.version DESC LIMIT 1)cl ON true
       WHERE oc.tenant_id=c.tenant_id AND oc.work_instance_id=c.work_instance_id AND oc.attendance_fact_id=c.attendance_fact_id
     )x
   )overtime ON true
 ), batch AS (SELECT * FROM projected ORDER BY operational_date,employee_code,work_instance_id LIMIT p_limit+1), visible AS (SELECT * FROM batch ORDER BY operational_date,employee_code,work_instance_id LIMIT p_limit)
 SELECT coalesce(jsonb_agg(jsonb_build_object('work_instance_id',work_instance_id,'operational_date',operational_date,'employee_id',employee_id,'employee_code',employee_code,'employment_id',employment_id,'assignment_id',assignment_id,'site_id',site_id,
   'policy_version',jsonb_build_object('template_id',policy_template_id,'version',policy_version,'timezone_name',timezone_name),'attendance_fact_id',attendance_fact_id,'attendance_fact_version',attendance_fact_version,'corrects_fact_id',corrects_fact_id,'correction_reason',correction_reason,
   'approved_at',approved_at,'outcome',fact->>'outcome','absence_units',fact->'absence_units','worked_minutes',fact->'worked_minutes','gross_worked_minutes',fact->'gross_worked_minutes','scheduled_break_minutes',fact->'scheduled_break_minutes','late_minutes',fact->'late_minutes','early_leave_minutes',fact->'early_leave_minutes',
   'overtime_quantities',overtime_quantities,'unclassified_overtime_count',unclassified_count,'unclassified_overtime_minutes',unclassified_minutes,'input_version',input_version,'consumed',false) ORDER BY operational_date,employee_code,work_instance_id),'[]'::jsonb),
   (SELECT count(*)>p_limit FROM batch),(SELECT jsonb_build_object('operational_date',operational_date,'employee_code',employee_code,'work_instance_id',work_instance_id) FROM visible ORDER BY operational_date DESC,employee_code DESC,work_instance_id DESC LIMIT 1)
 INTO items,more,cursor_value FROM visible;
 RETURN jsonb_build_object('contract_version',1,'boundary_status','projection_only','consumed',false,'period_start',p_period_start,'period_end',p_period_end,'items',items,'next_cursor',CASE WHEN more THEN cursor_value END,'has_more',more,'limit',p_limit);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_payroll_input_projection(uuid,date,date,date,text,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_payroll_input_projection(uuid,date,date,date,text,uuid,integer) TO authenticated;
CREATE OR REPLACE FUNCTION public.attendance_overtime_instance_panel(p_tenant_id uuid,p_instance_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); base jsonb; items jsonb;
BEGIN
 base:=public.attendance_instance_detail(p_tenant_id,p_instance_id);
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',c.id,'attendance_fact_id',c.attendance_fact_id,'candidate_minutes',c.candidate_minutes,'raw_minutes',c.raw_minutes,'category',c.category,'created_at',c.created_at,
   'decision',CASE WHEN r.decision='rejected' THEN 'rejected' WHEN r.decision='superseded' THEN 'superseded' WHEN r.decision='approved' AND cl.id IS NOT NULL THEN 'approved' WHEN r.decision='approved' THEN 'classification_pending' ELSE 'pending' END,
   'reason',coalesce(cl.reason,r.reason),'reviewed_at',coalesce(cl.created_at,r.created_at),'reviewer_id',coalesce(cl.actor_user_id,r.actor_user_id),
   'classification',CASE WHEN cl.id IS NULL THEN NULL ELSE jsonb_build_object('id',cl.id,'version',cl.version,'ordinary_day_minutes',cl.ordinary_day_minutes,'ordinary_night_minutes',cl.ordinary_night_minutes,'weekly_rest_minutes',cl.weekly_rest_minutes,'official_holiday_minutes',cl.official_holiday_minutes,'reason',cl.reason,'created_at',cl.created_at) END) ORDER BY c.created_at DESC),'[]'::jsonb)
 INTO items FROM (SELECT * FROM time.attendance_overtime_candidates WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY created_at DESC LIMIT 50)c
 LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
 LEFT JOIN LATERAL(SELECT ce.* FROM time.attendance_overtime_classification_events ce WHERE ce.tenant_id=c.tenant_id AND ce.candidate_id=c.id ORDER BY ce.version DESC LIMIT 1)cl ON true;
 RETURN jsonb_build_object('items',items,'can_review',platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')));
END $f$;
REVOKE ALL ON FUNCTION public.attendance_overtime_instance_panel(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_overtime_instance_panel(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_overtime_day_summary(p_tenant_id uuid,p_operational_date date,p_instance_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); counts jsonb;
BEGIN
 IF actor IS NULL OR p_operational_date IS NULL OR coalesce(cardinality(p_instance_ids),0)>50
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_overtime_day_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_object_agg(q.work_instance_id::text,q.pending_count),'{}'::jsonb) INTO counts FROM (
  SELECT c.work_instance_id,count(*)::integer pending_count FROM time.attendance_overtime_candidates c JOIN time.work_instances i ON i.tenant_id=c.tenant_id AND i.id=c.work_instance_id
  JOIN LATERAL(SELECT f.id FROM time.attendance_facts f WHERE f.tenant_id=c.tenant_id AND f.work_instance_id=c.work_instance_id ORDER BY f.version DESC LIMIT 1)latest ON latest.id=c.attendance_fact_id
  LEFT JOIN time.attendance_overtime_review_events r ON r.tenant_id=c.tenant_id AND r.candidate_id=c.id
  LEFT JOIN LATERAL(SELECT ce.id FROM time.attendance_overtime_classification_events ce WHERE ce.tenant_id=c.tenant_id AND ce.candidate_id=c.id ORDER BY ce.version DESC LIMIT 1)cl ON true
  WHERE c.tenant_id=p_tenant_id AND i.operational_date=p_operational_date AND c.work_instance_id=ANY(coalesce(p_instance_ids,'{}'::uuid[])) AND i.status='approved'
    AND (r.id IS NULL OR (r.decision='approved' AND cl.id IS NULL)) GROUP BY c.work_instance_id
 )q;
 RETURN jsonb_build_object('pending_by_instance',counts);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_overtime_day_summary(uuid,date,uuid[]) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_overtime_day_summary(uuid,date,uuid[]) TO authenticated;

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
       WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id AND i.status='approved' AND (r.id IS NULL OR (r.decision='approved' AND NOT EXISTS(SELECT 1 FROM time.attendance_overtime_classification_events cl WHERE cl.tenant_id=c.tenant_id AND cl.candidate_id=c.id)))) overtime_pending_count,
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
       WHERE c.tenant_id=i.tenant_id AND c.work_instance_id=i.id AND i.status='approved' AND (r.id IS NULL OR (r.decision='approved' AND NOT EXISTS(SELECT 1 FROM time.attendance_overtime_classification_events cl WHERE cl.tenant_id=c.tenant_id AND cl.candidate_id=c.id)))) overtime_pending_count,
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
