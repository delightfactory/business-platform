-- UI-only history labels from each stored event Site and captured Time policy, never current assignment.
CREATE OR REPLACE FUNCTION public.attendance_mobile_snapshot(p_tenant uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;history jsonb;BEGIN
 ctx:=time.mobile_context(p_tenant);
 SELECT coalesce(jsonb_agg(h.item||jsonb_build_object('site_name',s.display_name,'timezone_name',coalesce(h.item->>'timezone_name',v.timezone_name,'UTC'),'timezone_is_fallback',(h.item->>'timezone_name' IS NULL AND v.timezone_name IS NULL)) ORDER BY h.ordinality),'[]'::jsonb) INTO history
 FROM jsonb_array_elements(ctx->'history') WITH ORDINALITY h(item,ordinality)
 JOIN time.channel_events e ON e.tenant_id=p_tenant AND e.id=(h.item->>'id')::uuid
 LEFT JOIN platform_core.tenant_sites s ON s.tenant_id=e.tenant_id AND s.id=e.site_id
 LEFT JOIN time.work_policy_versions v ON v.tenant_id=e.tenant_id AND v.template_id=(e.capture_context->>'work_policy_id')::uuid AND v.version=(e.capture_context->>'work_policy_version')::integer;
 RETURN (ctx-'source_id'-'capture_context')||jsonb_build_object('history',history);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_mobile_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_mobile_snapshot(uuid) TO authenticated;
