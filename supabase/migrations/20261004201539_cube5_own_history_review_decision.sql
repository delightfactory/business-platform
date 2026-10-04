-- Own bounded history exposes latest persisted review separately from immutable capture acceptance.
CREATE OR REPLACE FUNCTION public.attendance_mobile_snapshot(p_tenant uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE ctx jsonb;history jsonb;BEGIN
 ctx:=time.mobile_context(p_tenant);
 SELECT coalesce(jsonb_agg(h.item||jsonb_build_object('review_decision',decision.summary,'review_required',e.review_required AND NOT EXISTS(SELECT 1 FROM time.channel_review_decisions d WHERE d.tenant_id=e.tenant_id AND d.event_id=e.id),'site_name',s.display_name,'timezone_name',coalesce(h.item->>'timezone_name',v.timezone_name,'UTC'),'timezone_is_fallback',(h.item->>'timezone_name' IS NULL AND v.timezone_name IS NULL)) ORDER BY h.ordinality),'[]'::jsonb) INTO history
 FROM jsonb_array_elements(ctx->'history') WITH ORDINALITY h(item,ordinality)
 JOIN time.channel_events e ON e.tenant_id=p_tenant AND e.id=(h.item->>'id')::uuid
 LEFT JOIN platform_core.tenant_sites s ON s.tenant_id=e.tenant_id AND s.id=e.site_id
 LEFT JOIN time.work_policy_versions v ON v.tenant_id=e.tenant_id AND v.template_id=(e.capture_context->>'work_policy_id')::uuid AND v.version=(e.capture_context->>'work_policy_version')::integer
 LEFT JOIN LATERAL(SELECT jsonb_build_object('decision',review.decision,'reason',review.reason,'created_at',review.created_at,'timezone_name',coalesce(h.item->>'timezone_name',v.timezone_name,'UTC'),
 'actor_label',CASE WHEN review.actor_user_id=auth.uid() THEN 'أنت' WHEN member.user_id IS NOT NULL AND actor.id IS NOT NULL THEN coalesce(employee.full_name,'مراجع من أعضاء الشركة') ELSE 'مراجع سابق' END)summary
 FROM time.channel_review_decisions review
 LEFT JOIN platform_core.tenant_memberships member ON member.tenant_id=review.tenant_id AND member.user_id=review.actor_user_id AND member.access_state='active'
 LEFT JOIN auth.users actor ON actor.id=member.user_id AND actor.deleted_at IS NULL AND actor.email_confirmed_at IS NOT NULL AND (actor.banned_until IS NULL OR actor.banned_until<=now())
 LEFT JOIN people.employee_user_links link ON link.tenant_id=member.tenant_id AND link.user_id=member.user_id AND link.unlinked_at IS NULL
 LEFT JOIN people.employees employee ON employee.tenant_id=link.tenant_id AND employee.id=link.employee_id
 WHERE review.tenant_id=e.tenant_id AND review.event_id=e.id ORDER BY review.created_at DESC LIMIT 1)decision ON true;
 RETURN (ctx-'source_id'-'capture_context')||jsonb_build_object('history',history);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_mobile_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_mobile_snapshot(uuid) TO authenticated;
