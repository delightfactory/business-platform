CREATE OR REPLACE FUNCTION public.attendance_unassigned_evidence_queue(p_tenant_id uuid,p_after uuid DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb; has_more boolean; next_cursor uuid;
BEGIN
 IF actor IS NULL OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_unassigned_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'attendance_unassigned_limit_invalid' USING ERRCODE='22023'; END IF;
 WITH page AS (
   SELECT e.id,e.employee_id,e.source_employee_code,e.source_employee_name,e.site_id,e.source_site_name,e.direction,e.happened_at,e.source_type,e.source_event_key,e.created_at,
     r.id IS NOT NULL AS resolved,r.work_instance_id,r.reason AS resolution_reason,r.created_at AS resolved_at
   FROM time.unassigned_attendance_evidence e LEFT JOIN time.unassigned_attendance_resolutions r ON r.tenant_id=e.tenant_id AND r.unassigned_evidence_id=e.id
   WHERE e.tenant_id=p_tenant_id AND (p_after IS NULL OR e.id<p_after)
   ORDER BY e.id DESC LIMIT p_limit+1
 ), list AS (SELECT * FROM page ORDER BY id DESC LIMIT p_limit)
 SELECT coalesce(jsonb_agg(to_jsonb(list) ORDER BY list.id DESC),'[]'::jsonb),
   (SELECT count(*)>p_limit FROM page), (SELECT id FROM list ORDER BY id ASC LIMIT 1)
 INTO result,has_more,next_cursor FROM list;
 RETURN jsonb_build_object('items',coalesce(result,'[]'::jsonb),'has_more',coalesce(has_more,false),'next_cursor',CASE WHEN has_more THEN next_cursor::text ELSE NULL END);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_unassigned_evidence_queue(uuid,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_unassigned_evidence_queue(uuid,uuid,integer) TO authenticated;
