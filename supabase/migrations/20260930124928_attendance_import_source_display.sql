CREATE OR REPLACE FUNCTION public.attendance_instance_detail(p_tenant_id uuid,p_instance_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb; enabled boolean;
BEGIN
 IF NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_view_forbidden' USING ERRCODE='42501'; END IF;
 enabled:=platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now());
 SELECT jsonb_build_object(
  'instance',to_jsonb(i)||jsonb_build_object('employee_code',e.employee_code,'employee_name',e.full_name,'policy_name',v.name),
  'punches',coalesce((SELECT jsonb_agg(jsonb_build_object('id',p.id,'direction',coalesce(c.new_direction,p.direction),'happened_at',coalesce(c.new_happened_at,p.happened_at),'original_direction',p.direction,'original_at',p.happened_at,'corrected',c.id IS NOT NULL,'excluded',x.id IS NOT NULL,'source_type',p.source_type,'source_event_key',p.source_event_key) ORDER BY coalesce(c.new_happened_at,p.happened_at),p.id)
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
