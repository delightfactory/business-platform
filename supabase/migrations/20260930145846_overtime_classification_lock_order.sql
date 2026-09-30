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
CREATE OR REPLACE FUNCTION public.classify_attendance_overtime(
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
