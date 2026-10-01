-- Reciprocal Leave/Time work-instance guard for the approved source evidence.
-- Time writers retain their existing locks; this guard takes no additional locks.

CREATE OR REPLACE FUNCTION platform_private.approved_leave_conflicts_with_work_instance(
  p_tenant_id uuid,p_instance_id uuid
) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $f$
  SELECT EXISTS (
    SELECT 1
    FROM time.work_instances i
    JOIN leave.requests r
      ON r.tenant_id=i.tenant_id
     AND r.employee_id=i.employee_id
     AND r.employment_id=i.employment_id
    JOIN leave.request_days d
      ON d.tenant_id=r.tenant_id
     AND d.request_id=r.id
     AND d.preview_version=r.approved_preview_version
    WHERE i.tenant_id=p_tenant_id AND i.id=p_instance_id
      AND r.state='approved' AND r.approved_preview_version IS NOT NULL
      AND r.cancelled_at IS NULL
      AND d.leave_date=i.operational_date
      AND d.eligible AND d.units>0
  );
$f$;
REVOKE ALL ON FUNCTION platform_private.approved_leave_conflicts_with_work_instance(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role;

-- Fail closed if any source definition or exact anchor differs from the qualified HEAD.
DO $guard$
DECLARE
  target regprocedure;
  source text;
  anchor text;
  replacement text;
  occurrences integer;
BEGIN
  target:=to_regprocedure('public.approve_attendance_fact(uuid,uuid,uuid,text)');
  IF target IS NULL THEN RAISE EXCEPTION 'Time guard target missing: approve_attendance_fact' USING ERRCODE='55000'; END IF;
  source:=pg_get_functiondef(target);
  anchor:='SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=p_instance_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION ''attendance_instance_missing'' USING ERRCODE=''P0002''; END IF;';
  replacement:=anchor||E'\n IF platform_private.approved_leave_conflicts_with_work_instance(p_tenant_id,p_instance_id) THEN RAISE EXCEPTION ''leave_conflict_review_required'' USING ERRCODE=''23514''; END IF;';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, approve_attendance_fact',occurrences USING ERRCODE='55000'; END IF;
  EXECUTE replace(source,anchor,replacement);

  target:=to_regprocedure('public.approve_attendance_absence(uuid,uuid,text)');
  IF target IS NULL THEN RAISE EXCEPTION 'Time guard target missing: approve_attendance_absence' USING ERRCODE='55000'; END IF;
  source:=pg_get_functiondef(target);
  anchor:='IF NOT FOUND OR i.employment_id IS DISTINCT FROM e_id THEN RAISE EXCEPTION ''attendance_instance_missing'' USING ERRCODE=''P0002''; END IF;';
  replacement:=anchor||E'\n IF platform_private.approved_leave_conflicts_with_work_instance(p_tenant_id,p_instance_id) THEN RAISE EXCEPTION ''leave_conflict_review_required'' USING ERRCODE=''23514''; END IF;';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, approve_attendance_absence',occurrences USING ERRCODE='55000'; END IF;
  EXECUTE replace(source,anchor,replacement);

  target:=to_regprocedure('public.correct_attendance_absence(uuid,uuid,uuid,text)');
  IF target IS NULL THEN RAISE EXCEPTION 'Time guard target missing: correct_attendance_absence' USING ERRCODE='55000'; END IF;
  source:=pg_get_functiondef(target);
  anchor:='IF NOT FOUND OR i.employment_id IS DISTINCT FROM e_id THEN RAISE EXCEPTION ''attendance_instance_missing'' USING ERRCODE=''P0002''; END IF;';
  replacement:=anchor||E'\n IF platform_private.approved_leave_conflicts_with_work_instance(p_tenant_id,p_instance_id) THEN RAISE EXCEPTION ''leave_conflict_review_required'' USING ERRCODE=''23514''; END IF;';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, correct_attendance_absence',occurrences USING ERRCODE='55000'; END IF;
  EXECUTE replace(source,anchor,replacement);

  target:=to_regprocedure('time.auto_approve_clean_work_instance(uuid,uuid,uuid)');
  IF target IS NULL THEN RAISE EXCEPTION 'Time guard target missing: auto_approve_clean_work_instance' USING ERRCODE='55000'; END IF;
  source:=pg_get_functiondef(target);
  anchor:='IF NOT FOUND OR NOT wi.auto_approve_clean OR wi.status<>''ready''';
  replacement:='IF NOT FOUND OR platform_private.approved_leave_conflicts_with_work_instance(p_tenant,p_instance) OR NOT wi.auto_approve_clean OR wi.status<>''ready''';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, auto_approve_clean_work_instance',occurrences USING ERRCODE='55000'; END IF;
  EXECUTE replace(source,anchor,replacement);

  target:=to_regprocedure('public.approve_attendance_facts_bulk(uuid,date,uuid[])');
  IF target IS NULL THEN RAISE EXCEPTION 'Time guard target missing: approve_attendance_facts_bulk' USING ERRCODE='55000'; END IF;
  source:=pg_get_functiondef(target);
  anchor:='ORDER BY i.id FOR UPDATE;';
  replacement:='ORDER BY i.operational_date,i.id FOR UPDATE;';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, approve_attendance_facts_bulk',occurrences USING ERRCODE='55000'; END IF;
  EXECUTE replace(source,anchor,replacement);

  -- Preserve the dedicated conflict reason in bulk item results and audit rows.
  source:=pg_get_functiondef(target);
  anchor:='reason_code text; err_code text;';
  replacement:='reason_code text; err_code text; err_message text;';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, bulk declaration',occurrences USING ERRCODE='55000'; END IF;
  source:=replace(source,anchor,replacement);
  anchor:='GET STACKED DIAGNOSTICS err_code=RETURNED_SQLSTATE;';
  replacement:='GET STACKED DIAGNOSTICS err_code=RETURNED_SQLSTATE, err_message=MESSAGE_TEXT;';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, bulk diagnostics',occurrences USING ERRCODE='55000'; END IF;
  source:=replace(source,anchor,replacement);
  anchor:='reason_code:=CASE WHEN err_code=''42501'' THEN ''access_changed'' WHEN err_code=''P0002'' THEN ''record_unavailable'' ELSE ''not_clean_or_stale'' END;';
  replacement:='reason_code:=CASE WHEN err_code=''23514'' AND err_message=''leave_conflict_review_required'' THEN ''leave_conflict_review_required'' WHEN err_code=''42501'' THEN ''access_changed'' WHEN err_code=''P0002'' THEN ''record_unavailable'' ELSE ''not_clean_or_stale'' END;';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'Time guard anchor count %, bulk reason mapping',occurrences USING ERRCODE='55000'; END IF;
  EXECUTE replace(source,anchor,replacement);
END
$guard$;

