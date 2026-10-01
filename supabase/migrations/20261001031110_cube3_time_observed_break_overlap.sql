-- Cube 3 Time observation correction: subtract only the observed overlap with an
-- explicitly configured fixed break. Existing interpretations/facts remain immutable.
ALTER TABLE time.interpretations
  ADD COLUMN applied_break_minutes integer,
  ADD CONSTRAINT interpretations_applied_break_minutes_check
    CHECK (applied_break_minutes IS NULL OR applied_break_minutes BETWEEN 0 AND 360);

-- One authoritative input fingerprint is shared by interpretation and auto-approval.
-- It includes current raw punches/corrections and the immutable Work Instance/policy
-- identity, including the A0 fixed-break placement. Derived overlap is deterministic.
CREATE OR REPLACE FUNCTION time.work_instance_interpretation_fingerprint(p_tenant uuid,p_instance uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $fingerprint$
 SELECT pg_catalog.md5(
   coalesce((
     SELECT string_agg(
       p.id::text||':'||p.direction||':'||p.happened_at::text||':'||
       coalesce(c.action,'')||':'||coalesce(c.new_direction,'')||':'||
       coalesce(c.new_happened_at::text,''),
       ',' ORDER BY p.id
     )
     FROM time.manual_punches p
     LEFT JOIN LATERAL(
       SELECT q.* FROM time.punch_corrections q
       WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id
       ORDER BY q.created_at DESC,q.id DESC LIMIT 1
     ) c ON true
     WHERE p.tenant_id=p_instance_row.tenant_id
       AND p.work_instance_id=p_instance_row.id
   ),'')
   ||pg_catalog.concat_ws(':',
     p_instance_row.tenant_id,p_instance_row.id,
     p_instance_row.schedule_kind,p_instance_row.operational_date,
     p_instance_row.timezone_name,p_instance_row.expected_start,p_instance_row.expected_end,
     p_instance_row.attribution_start,p_instance_row.attribution_end,
     p_instance_row.required_minutes,p_instance_row.break_minutes,
     p_instance_row.lateness_grace_minutes,p_instance_row.early_leave_grace_minutes,
     p_instance_row.policy_template_id,p_instance_row.policy_version,
     policy.fixed_break_start,policy.fixed_break_end
   )
 )
 FROM time.work_instances p_instance_row
 JOIN time.work_policy_versions policy
   ON policy.tenant_id=p_instance_row.tenant_id
  AND policy.template_id=p_instance_row.policy_template_id
  AND policy.version=p_instance_row.policy_version
 WHERE p_instance_row.tenant_id=p_tenant AND p_instance_row.id=p_instance
$fingerprint$;
REVOKE ALL ON FUNCTION time.work_instance_interpretation_fingerprint(uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION time.interpret_work_instance(p_tenant uuid,p_instance uuid,p_actor uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 wi time.work_instances%ROWTYPE;
 n integer; ni integer; no integer; fin timestamptz; fout timestamptz;
 st text; exc text; ver integer; interp uuid; fp text;
 gross_minutes integer; net_minutes integer; late_n integer; early_n integer;
 scheduled_break integer; applied_break integer;
 break_start time; break_end time; break_start_local timestamp; break_end_local timestamp;
 shift_start_local timestamp; break_start_at timestamptz; break_end_at timestamptz;
 overlap_seconds numeric; policy_found boolean;
BEGIN
 SELECT * INTO wi FROM time.work_instances
 WHERE tenant_id=p_tenant AND id=p_instance FOR UPDATE;
 IF NOT FOUND THEN
  RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002';
 END IF;

 WITH active AS (
  SELECT p.id,coalesce(c.new_direction,p.direction) d,
         coalesce(c.new_happened_at,p.happened_at) at
  FROM time.manual_punches p
  LEFT JOIN LATERAL(
   SELECT q.* FROM time.punch_corrections q
   WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id
   ORDER BY q.created_at DESC,q.id DESC LIMIT 1
  ) c ON c.action='replace'
  WHERE p.tenant_id=p_tenant AND p.work_instance_id=p_instance
    AND NOT EXISTS(
      SELECT 1 FROM time.punch_corrections q
      WHERE q.tenant_id=p.tenant_id AND q.punch_id=p.id AND q.action='exclude'
    )
 )
 SELECT count(*)::int,count(*) FILTER(WHERE d='in')::int,
        count(*) FILTER(WHERE d='out')::int,
        min(at) FILTER(WHERE d='in'),max(at) FILTER(WHERE d='out')
 INTO n,ni,no,fin,fout FROM active;

 st:='open'; exc:=NULL; gross_minutes:=NULL; net_minutes:=NULL;
 late_n:=NULL; early_n:=NULL;
 scheduled_break:=wi.break_minutes;
 applied_break:=wi.break_minutes; -- preserves legacy aggregate-break behavior

 SELECT v.fixed_break_start,v.fixed_break_end
 INTO break_start,break_end
 FROM time.work_policy_versions v
 WHERE v.tenant_id=wi.tenant_id AND v.template_id=wi.policy_template_id
   AND v.version=wi.policy_version;
 policy_found:=FOUND;

 IF wi.attribution_start IS NULL OR wi.attribution_end IS NULL
    OR (wi.schedule_kind='fixed' AND
        (wi.expected_start IS NULL OR wi.expected_end IS NULL)) THEN
   st:='needs_review'; exc:='ambiguous_local_time';
 ELSIF n>2 OR ni>1 OR no>1 THEN
   st:='needs_review'; exc:='conflicting_punches';
 ELSIF ni=1 AND no=1 THEN
  IF fin>=fout OR fin<wi.attribution_start OR fout>wi.attribution_end THEN
   st:='needs_review'; exc:='outside_window';
  ELSE
   gross_minutes:=greatest(0,(extract(epoch FROM(fout-fin))/60)::int);

   -- A fixed break with an explicit immutable placement is interpreted against
   -- the Work Instance's frozen policy version and local operational date.
   -- Missing placement retains the preexisting full-break subtraction.
   IF wi.schedule_kind='fixed' AND wi.break_minutes>0
      AND (break_start IS NOT NULL OR break_end IS NOT NULL) THEN
    IF NOT policy_found OR break_start IS NULL OR break_end IS NULL
       OR wi.timezone_name IS NULL
       OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names z
                     WHERE z.name=wi.timezone_name) THEN
      st:='needs_review'; exc:='break_placement_invalid';
    ELSE
      shift_start_local:=wi.expected_start AT TIME ZONE wi.timezone_name;
      break_start_local:=wi.operational_date+break_start;
      WHILE break_start_local<shift_start_local LOOP
        break_start_local:=break_start_local+interval '1 day';
      END LOOP;
      break_end_local:=wi.operational_date+break_end;
      WHILE break_end_local<=break_start_local LOOP
        break_end_local:=break_end_local+interval '1 day';
      END LOOP;
      break_start_at:=time.resolve_local(break_start_local,wi.timezone_name);
      break_end_at:=time.resolve_local(break_end_local,wi.timezone_name);

      IF break_start_at IS NULL OR break_end_at IS NULL
         OR break_end_at<=break_start_at
         OR break_start_at<wi.expected_start
         OR break_end_at>wi.expected_end
         OR mod(extract(epoch FROM (break_end_at-break_start_at)),60)<>0
         OR extract(epoch FROM (break_end_at-break_start_at))/60<>wi.break_minutes THEN
        st:='needs_review'; exc:='break_placement_invalid';
      ELSE
        overlap_seconds:=greatest(
          0::numeric,
          extract(epoch FROM (least(fout,break_end_at)-greatest(fin,break_start_at)))
        );
        -- Match the interpreter's established elapsed-minute cast: fractional
        -- minutes round to integer minutes; do not reject second-resolution punches.
        applied_break:=(overlap_seconds/60)::integer;
      END IF;
    END IF;
   ELSIF wi.schedule_kind='fixed' AND wi.break_minutes=0
      AND policy_found AND (break_start IS NOT NULL OR break_end IS NOT NULL) THEN
     st:='needs_review'; exc:='break_placement_invalid';
   END IF;

   IF st='open' THEN
    st:='ready';
    net_minutes:=greatest(0,gross_minutes-applied_break);
    IF wi.schedule_kind='fixed' THEN
     late_n:=greatest(0,(extract(epoch FROM(fin-wi.expected_start))/60)::int-wi.lateness_grace_minutes);
     early_n:=greatest(0,(extract(epoch FROM(wi.expected_end-fout))/60)::int-wi.early_leave_grace_minutes);
    ELSIF net_minutes<wi.required_minutes THEN
     exc:='short_workday';
    END IF;
   END IF;
  END IF;
 ELSIF now()>wi.attribution_end THEN
   st:='needs_review'; exc:=CASE WHEN n=0 THEN 'absence_candidate' ELSE 'missing_punch' END;
 END IF;

 SELECT coalesce(max(version),0)+1 INTO ver
 FROM time.interpretations
 WHERE tenant_id=p_tenant AND work_instance_id=p_instance;

 fp:=time.work_instance_interpretation_fingerprint(p_tenant,p_instance);

 INSERT INTO time.interpretations(
   tenant_id,work_instance_id,version,state,first_in,last_out,worked_minutes,
   exception_code,owner_permission,input_fingerprint,created_by,
   gross_worked_minutes,late_minutes,early_leave_minutes,
   scheduled_break_minutes,applied_break_minutes
 )
 VALUES(
   p_tenant,p_instance,ver,st,fin,fout,net_minutes,exc,
   CASE WHEN exc='short_workday' THEN 'attendance.approve'
        WHEN st='needs_review' THEN
          CASE WHEN exc='absence_candidate' THEN 'attendance.approve'
               ELSE 'attendance.correct' END END,
   fp,p_actor,gross_minutes,late_n,early_n,scheduled_break,
   CASE WHEN gross_minutes IS NULL OR exc='break_placement_invalid' THEN NULL ELSE applied_break END
 ) RETURNING id INTO interp;

 UPDATE time.work_instances
 SET status=CASE WHEN EXISTS(
   SELECT 1 FROM time.attendance_facts f
   WHERE f.tenant_id=p_tenant AND f.work_instance_id=p_instance
 ) THEN 'needs_review' ELSE st END
 WHERE tenant_id=p_tenant AND id=p_instance;
 RETURN interp;
END $f$;
REVOKE ALL ON FUNCTION time.interpret_work_instance(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

-- Add the applied value to fact JSON and bounded list responses without replacing
-- their auth, lifecycle, or CAS bodies. Fail closed if upstream definitions drift.
DO $break_api$
DECLARE
 target regprocedure;
 source text;
 anchor text;
 replacement text;
 occurrences integer;
 start_pos integer; end_pos integer; end_anchor text;
BEGIN
 target:=to_regprocedure('public.approve_attendance_fact(uuid,uuid,uuid,text)');
 IF target IS NULL THEN RAISE EXCEPTION 'break migration target missing: approve fact' USING ERRCODE='55000'; END IF;
 source:=pg_catalog.pg_get_functiondef(target);
 anchor:='''scheduled_break_minutes'',q.scheduled_break_minutes,''worked_minutes'',q.worked_minutes';
 replacement:='''scheduled_break_minutes'',q.scheduled_break_minutes,''applied_break_minutes'',q.applied_break_minutes,''worked_minutes'',q.worked_minutes';
 occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
 IF occurrences<>1 THEN RAISE EXCEPTION 'break applied fact anchor count %',occurrences USING ERRCODE='55000'; END IF;
 EXECUTE replace(source,anchor,replacement);

 target:=to_regprocedure('public.attendance_day_list(uuid,date,text,integer)');
 IF target IS NULL THEN RAISE EXCEPTION 'break migration target missing: day list' USING ERRCODE='55000'; END IF;
 source:=pg_catalog.pg_get_functiondef(target);
 anchor:='q.late_minutes,q.early_leave_minutes,q.worked_minutes,q.gross_worked_minutes,q.scheduled_break_minutes,q.exception_code';
 replacement:='q.late_minutes,q.early_leave_minutes,q.worked_minutes,q.gross_worked_minutes,q.scheduled_break_minutes,q.applied_break_minutes,q.exception_code';
 occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
 IF occurrences<>1 THEN RAISE EXCEPTION 'break applied day list anchor count %',occurrences USING ERRCODE='55000'; END IF;
 EXECUTE replace(source,anchor,replacement);

 target:=to_regprocedure('public.attendance_open_day(uuid,date,text,integer)');
 IF target IS NULL THEN RAISE EXCEPTION 'break migration target missing: open day' USING ERRCODE='55000'; END IF;
 source:=pg_catalog.pg_get_functiondef(target);
 anchor:='''scheduled_break_minutes'',q.scheduled_break_minutes,''exception_code'',q.exception_code';
 replacement:='''scheduled_break_minutes'',q.scheduled_break_minutes,''applied_break_minutes'',q.applied_break_minutes,''exception_code'',q.exception_code';
 occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
 IF occurrences<>1 THEN RAISE EXCEPTION 'break applied open day anchor count %',occurrences USING ERRCODE='55000'; END IF;
 EXECUTE replace(source,anchor,replacement);

  -- Auto-approval compares the exact same raw input/configuration fingerprint.
  target:=to_regprocedure('time.auto_approve_clean_work_instance(uuid,uuid,uuid)');
  IF target IS NULL THEN RAISE EXCEPTION 'break migration target missing: auto approval' USING ERRCODE='55000'; END IF;
  source:=pg_catalog.pg_get_functiondef(target);
  anchor:='fingerprint:=md5(coalesce((';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'break auto fingerprint start anchor count %',occurrences USING ERRCODE='55000'; END IF;
  start_pos:=pg_catalog.strpos(source,anchor);
  end_anchor:='early_leave_grace_minutes));';
  occurrences:=(length(source)-length(replace(source,end_anchor,'')))/length(end_anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'break auto fingerprint end anchor count %',occurrences USING ERRCODE='55000'; END IF;
  end_pos:=pg_catalog.strpos(source,end_anchor);
  IF end_pos<=start_pos THEN RAISE EXCEPTION 'break auto fingerprint anchor order invalid' USING ERRCODE='55000'; END IF;
  source:=pg_catalog.substring(source,1,start_pos-1)
      ||'fingerprint:=time.work_instance_interpretation_fingerprint(p_tenant,p_instance);'
      ||pg_catalog.substring(source,end_pos+length(end_anchor));
  anchor:='''scheduled_break_minutes'',q.scheduled_break_minutes,''worked_minutes'',q.worked_minutes';
  replacement:='''scheduled_break_minutes'',q.scheduled_break_minutes,''applied_break_minutes'',q.applied_break_minutes,''worked_minutes'',q.worked_minutes';
  occurrences:=(length(source)-length(replace(source,anchor,'')))/length(anchor);
  IF occurrences<>1 THEN RAISE EXCEPTION 'break auto fact anchor count %',occurrences USING ERRCODE='55000'; END IF;
  EXECUTE replace(source,anchor,replacement);
END
$break_api$;
