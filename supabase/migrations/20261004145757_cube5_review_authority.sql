CREATE OR REPLACE FUNCTION public.attendance_channel_review(p_tenant uuid,p_event uuid,p_decision text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE ev time.channel_events%ROWTYPE;punch uuid;instance uuid;BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.correct') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'channel_review_forbidden' USING ERRCODE='42501'; END IF;
 IF p_decision IS NULL OR p_decision NOT IN('accept','exclude') OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'channel_review_invalid' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 SELECT * INTO ev FROM time.channel_events WHERE tenant_id=p_tenant AND id=p_event FOR UPDATE;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.correct') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'channel_review_forbidden' USING ERRCODE='42501'; END IF;
 IF NOT FOUND OR NOT ev.review_required THEN RAISE EXCEPTION 'channel_review_not_found' USING ERRCODE='P0002'; END IF;
 IF EXISTS(SELECT 1 FROM time.channel_review_decisions WHERE tenant_id=p_tenant AND event_id=p_event) THEN RETURN jsonb_build_object('state','unchanged'); END IF;
 SELECT canonical_punch_id,work_instance_id INTO punch,instance FROM time.channel_event_results WHERE tenant_id=p_tenant AND event_id=p_event AND canonical_punch_id IS NOT NULL ORDER BY id DESC LIMIT 1;
 IF punch IS NULL THEN RAISE EXCEPTION 'channel_review_not_ready' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM time.work_instances WHERE tenant_id=p_tenant AND id=instance FOR UPDATE;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',now()) OR NOT (platform_private.has_tenant_permission(p_tenant,auth.uid(),'attendance.correct') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'tenant.administer')) THEN RAISE EXCEPTION 'channel_review_forbidden' USING ERRCODE='42501'; END IF;
 INSERT INTO time.channel_review_decisions(tenant_id,event_id,decision,reason,actor_user_id) VALUES(p_tenant,p_event,p_decision,btrim(p_reason),auth.uid());
 IF p_decision='exclude' THEN PERFORM public.correct_manual_attendance_punch(p_tenant,instance,punch,'exclude',NULL,NULL,p_reason);
 ELSE PERFORM time.interpret_work_instance(p_tenant,instance,auth.uid()); END IF;
 RETURN jsonb_build_object('state','reviewed','work_instance_id',instance);
END $f$;
