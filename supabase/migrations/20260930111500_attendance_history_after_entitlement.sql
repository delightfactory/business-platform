CREATE OR REPLACE FUNCTION public.time_attendance_access_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); enabled boolean; v boolean; m boolean; c boolean; a boolean;
BEGIN
 enabled:=platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now());
 v:=platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer');
 m:=enabled AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'));
 c:=enabled AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'));
 a:=enabled AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'));
 IF NOT v THEN RAISE EXCEPTION 'attendance_view_forbidden' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('can_view',v,'can_manage',m,'can_correct',c,'can_approve',a,'entitlement_enabled',enabled);
END $f$;
REVOKE ALL ON FUNCTION public.time_attendance_access_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.time_attendance_access_snapshot(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_day_list(p_tenant_id uuid,p_date date,p_after text DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb; next_code text; more boolean;
BEGIN
 IF NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_view_forbidden' USING ERRCODE='42501'; END IF;
 IF p_date IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'attendance_page_invalid' USING ERRCODE='22023'; END IF;
 WITH batch AS (
  SELECT i.id,i.operational_date,i.status,i.timezone_name,e.employee_code,e.full_name,i.expected_start,i.expected_end
  FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
  WHERE i.tenant_id=p_tenant_id AND i.operational_date=p_date AND (p_after IS NULL OR e.employee_code>p_after)
  ORDER BY e.employee_code LIMIT p_limit+1
 ), visible AS (SELECT * FROM batch ORDER BY employee_code LIMIT p_limit)
 SELECT coalesce(jsonb_agg(to_jsonb(visible) ORDER BY employee_code),'[]'::jsonb),max(employee_code),(SELECT count(*)>p_limit FROM batch)
 INTO rows,next_code,more FROM visible;
 RETURN jsonb_build_object('items',rows,'next_cursor',CASE WHEN more THEN next_code END,'has_more',more,'limit',p_limit);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_day_list(uuid,date,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_day_list(uuid,date,text,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_instance_detail(p_tenant_id uuid,p_instance_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb; enabled boolean;
BEGIN
 IF NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_view_forbidden' USING ERRCODE='42501'; END IF;
 enabled:=platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now());
 SELECT jsonb_build_object(
  'instance',to_jsonb(i)||jsonb_build_object('employee_code',e.employee_code,'employee_name',e.full_name,'policy_name',v.name),
  'punches',coalesce((SELECT jsonb_agg(jsonb_build_object('id',p.id,'direction',coalesce(c.new_direction,p.direction),'happened_at',coalesce(c.new_happened_at,p.happened_at),'original_direction',p.direction,'original_at',p.happened_at,'corrected',c.id IS NOT NULL,'excluded',x.id IS NOT NULL) ORDER BY coalesce(c.new_happened_at,p.happened_at),p.id)
    FROM time.manual_punches p
    LEFT JOIN LATERAL(SELECT q.* FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id ORDER BY q.created_at DESC,q.id DESC LIMIT 1)c ON c.action='replace'
    LEFT JOIN LATERAL(SELECT q.id FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id AND q.action='exclude' ORDER BY q.created_at DESC,q.id DESC LIMIT 1)x ON true
    WHERE p.tenant_id=i.tenant_id AND p.work_instance_id=i.id),'[]'::jsonb),
  'interpretation',(SELECT to_jsonb(q) FROM time.interpretations q WHERE q.tenant_id=i.tenant_id AND q.work_instance_id=i.id ORDER BY q.version DESC LIMIT 1),
  'facts',coalesce((SELECT jsonb_agg(to_jsonb(f) ORDER BY f.version DESC) FROM time.attendance_facts f WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id),'[]'::jsonb),
  'permissions',jsonb_build_object(
    'can_manage',enabled AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')),
    'can_correct',enabled AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')),
    'can_approve',enabled AND (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')),
    'entitlement_enabled',enabled)
 ) INTO result
 FROM time.work_instances i JOIN people.employees e ON e.tenant_id=i.tenant_id AND e.id=i.employee_id
 JOIN time.work_policy_versions v ON v.tenant_id=i.tenant_id AND v.template_id=i.policy_template_id AND v.version=i.policy_version
 WHERE i.tenant_id=p_tenant_id AND i.id=p_instance_id;
 IF result IS NULL THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.attendance_instance_detail(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_instance_detail(uuid,uuid) TO authenticated;

CREATE FUNCTION time.prevent_future_manual_punch()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF NEW.happened_at>pg_catalog.clock_timestamp()+interval '5 minutes' THEN RAISE EXCEPTION 'attendance_punch_in_future' USING ERRCODE='22023'; END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER manual_punch_not_future BEFORE INSERT ON time.manual_punches
FOR EACH ROW EXECUTE FUNCTION time.prevent_future_manual_punch();
REVOKE ALL ON FUNCTION time.prevent_future_manual_punch() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION time.prevent_future_manual_punch_correction()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF NEW.action='replace' AND NEW.new_happened_at>pg_catalog.clock_timestamp()+interval '5 minutes' THEN RAISE EXCEPTION 'attendance_punch_in_future' USING ERRCODE='22023'; END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER manual_punch_correction_not_future BEFORE INSERT ON time.punch_corrections
FOR EACH ROW EXECUTE FUNCTION time.prevent_future_manual_punch_correction();
REVOKE ALL ON FUNCTION time.prevent_future_manual_punch_correction() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.approve_attendance_fact(p_tenant_id uuid,p_instance_id uuid,p_corrects_fact_id uuid DEFAULT NULL,p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); i time.work_instances%ROWTYPE; q time.interpretations%ROWTYPE; version_n integer; fact_id uuid; latest_fact time.attendance_facts%ROWTYPE;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_approve_forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF NOT FOUND OR q.state<>'ready' THEN RAISE EXCEPTION 'attendance_instance_not_ready' USING ERRCODE='23514'; END IF;
 SELECT * INTO latest_fact FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;
 IF latest_fact.id IS DISTINCT FROM p_corrects_fact_id THEN RAISE EXCEPTION 'attendance_fact_version_stale' USING ERRCODE='40001'; END IF;
 IF p_corrects_fact_id IS NOT NULL AND latest_fact.interpretation_id=q.id THEN RAISE EXCEPTION 'attendance_fact_no_new_interpretation' USING ERRCODE='23514'; END IF;
 IF p_corrects_fact_id IS NOT NULL AND length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_fact_correction_reason_required' USING ERRCODE='22023'; END IF;
 SELECT coalesce(max(version),0)+1 INTO version_n FROM time.attendance_facts WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id;
 INSERT INTO time.attendance_facts(tenant_id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id) VALUES(p_tenant_id,p_instance_id,version_n,q.id,p_corrects_fact_id,NULLIF(btrim(p_reason),''),jsonb_build_object('operational_date',i.operational_date,'employee_id',i.employee_id,'assignment_id',i.assignment_id,'site_id',i.site_id,'timezone_name',i.timezone_name,'expected_start',i.expected_start,'expected_end',i.expected_end,'first_in',q.first_in,'last_out',q.last_out,'worked_minutes',q.worked_minutes),actor) RETURNING id INTO fact_id;
 UPDATE time.work_instances SET status='approved' WHERE tenant_id=p_tenant_id AND id=p_instance_id;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,CASE WHEN p_corrects_fact_id IS NULL THEN 'attendance.fact.approved' ELSE 'attendance.fact.corrected' END,p_instance_id,jsonb_build_object('fact_id',fact_id,'version',version_n,'corrects_fact_id',p_corrects_fact_id,'reason',p_reason));
 RETURN jsonb_build_object('state','approved','fact_id',fact_id,'version',version_n);
END $f$;
REVOKE ALL ON FUNCTION public.approve_attendance_fact(uuid,uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.approve_attendance_fact(uuid,uuid,uuid,text) TO authenticated;