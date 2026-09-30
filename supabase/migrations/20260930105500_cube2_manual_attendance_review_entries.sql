CREATE OR REPLACE FUNCTION public.record_manual_attendance_punch_local(p_tenant_id uuid,p_instance_id uuid,p_direction text,p_local_time timestamp,p_request_key uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); wi time.work_instances%ROWTYPE; resolved timestamptz; old time.manual_punches%ROWTYPE; fingerprint text; punch_id uuid; interpretation_id uuid; manager boolean;
BEGIN
 manager:=platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer');
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',now()) OR (NOT manager AND NOT platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct')) THEN RAISE EXCEPTION 'attendance_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF p_direction IS NULL OR p_direction NOT IN('in','out') OR p_request_key IS NULL THEN RAISE EXCEPTION 'attendance_punch_input_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 resolved:=time.resolve_local(p_local_time,wi.timezone_name);
 IF resolved IS NULL THEN RAISE EXCEPTION 'attendance_local_time_ambiguous_or_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM time.manual_punches WHERE tenant_id=p_tenant_id AND request_key=p_request_key;
 IF FOUND THEN
  IF old.payload_fingerprint<>md5(p_instance_id::text||'|'||p_direction||'|'||resolved::text)
     AND old.payload_fingerprint<>md5(p_instance_id::text||'|'||p_direction||'|'||resolved::text||'|'||btrim(coalesce(p_reason,''))) THEN
   RAISE EXCEPTION 'attendance_idempotency_conflict' USING ERRCODE='23505';
  END IF;
  RETURN jsonb_build_object('state','unchanged','punch_id',old.id);
 END IF;
 IF NOT manager AND wi.status NOT IN('needs_review','approved') THEN RAISE EXCEPTION 'attendance_review_entry_not_available' USING ERRCODE='42501'; END IF;
 IF (NOT manager OR wi.status<>'open') AND length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_punch_input_invalid' USING ERRCODE='22023'; END IF;
 IF manager AND wi.status='open' THEN RETURN public.record_manual_attendance_punch(p_tenant_id,p_instance_id,p_direction,resolved,p_request_key); END IF;
 fingerprint:=md5(p_instance_id::text||'|'||p_direction||'|'||resolved::text||'|'||btrim(p_reason));
 INSERT INTO time.manual_punches(tenant_id,work_instance_id,direction,happened_at,request_key,payload_fingerprint,actor_user_id) VALUES(p_tenant_id,p_instance_id,p_direction,resolved,p_request_key,fingerprint,actor) RETURNING id INTO punch_id;
 interpretation_id:=time.interpret_work_instance(p_tenant_id,p_instance_id,actor);
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details) VALUES(p_tenant_id,actor,'manual_punch.review_entry',p_instance_id,jsonb_build_object('punch_id',punch_id,'direction',p_direction,'happened_at',resolved,'reason',btrim(p_reason),'interpretation_id',interpretation_id));
 RETURN jsonb_build_object('state','recorded','punch_id',punch_id,'interpretation_id',interpretation_id);
END $f$;
REVOKE ALL ON FUNCTION public.record_manual_attendance_punch_local(uuid,uuid,text,timestamp,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.record_manual_attendance_punch_local(uuid,uuid,text,timestamp,uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.record_manual_attendance_punch_local(uuid,uuid,text,timestamp,uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.record_manual_attendance_punch(uuid,uuid,text,timestamptz,uuid) FROM PUBLIC,anon,authenticated,service_role;
