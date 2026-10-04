-- Bounded persisted review history under the unchanged event-detail tenant/auth guard. No emails or precise evidence.
CREATE OR REPLACE FUNCTION public.attendance_channel_event_detail(p_tenant uuid,p_event uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE result jsonb;BEGIN
 IF NOT time.channel_operator_can(p_tenant,false) THEN RAISE EXCEPTION 'channel_forbidden' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('id',e.id,'source_id',e.source_id,'source_name',s.name,'kind',s.kind,'external_key',CASE WHEN time.channel_operator_can(p_tenant,true) THEN e.external_key END,
 'event_key',CASE WHEN time.channel_operator_can(p_tenant,true) THEN e.event_key END,'direction',e.direction,'happened_at',e.happened_at,'received_at',e.received_at,'validation',e.validation,'source_version',e.source_version,'review_required',e.review_required AND NOT EXISTS(SELECT 1 FROM time.channel_review_decisions d WHERE d.tenant_id=e.tenant_id AND d.event_id=e.id),
 'review_decisions',(SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC),'[]'::jsonb) FROM (
 SELECT review.decision,review.reason,review.created_at,coalesce(wi.timezone_name,'UTC') AS timezone_name,
 CASE WHEN review.actor_user_id=auth.uid() THEN 'أنت'
 WHEN member.user_id IS NOT NULL AND actor.id IS NOT NULL THEN coalesce(employee.full_name,'مراجع من أعضاء الشركة')
 ELSE 'مراجع سابق' END AS actor_label
 FROM time.channel_review_decisions review
 LEFT JOIN platform_core.tenant_memberships member ON member.tenant_id=review.tenant_id AND member.user_id=review.actor_user_id AND member.access_state='active'
 LEFT JOIN auth.users actor ON actor.id=member.user_id AND actor.deleted_at IS NULL AND actor.email_confirmed_at IS NOT NULL AND (actor.banned_until IS NULL OR actor.banned_until<=now())
 LEFT JOIN people.employee_user_links link ON link.tenant_id=member.tenant_id AND link.user_id=member.user_id AND link.unlinked_at IS NULL
 LEFT JOIN people.employees employee ON employee.tenant_id=link.tenant_id AND employee.id=link.employee_id
 LEFT JOIN LATERAL(SELECT instance.timezone_name FROM time.channel_event_results er JOIN time.work_instances instance ON instance.tenant_id=er.tenant_id AND instance.id=er.work_instance_id WHERE er.tenant_id=review.tenant_id AND er.event_id=review.event_id ORDER BY er.id DESC LIMIT 1)wi ON true
 WHERE review.tenant_id=p_tenant AND review.event_id=p_event ORDER BY review.created_at DESC LIMIT 20)d),
 'replays',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id DESC),'[]'::jsonb) FROM(SELECT id,state,created_at FROM time.channel_replay_observations WHERE tenant_id=p_tenant AND event_id=p_event ORDER BY id DESC LIMIT 20)x),
 'results',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id DESC),'[]'::jsonb) FROM(SELECT id,state,reason,canonical_punch_id,work_instance_id,created_at FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event ORDER BY id DESC LIMIT 20)x)) INTO result
 FROM time.channel_events e JOIN time.channel_sources s ON s.tenant_id=e.tenant_id AND s.id=e.source_id WHERE e.tenant_id=p_tenant AND e.id=p_event;
 IF result IS NULL THEN RAISE EXCEPTION 'channel_event_missing' USING ERRCODE='P0002'; END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.attendance_channel_event_detail(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_channel_event_detail(uuid,uuid) TO authenticated;
