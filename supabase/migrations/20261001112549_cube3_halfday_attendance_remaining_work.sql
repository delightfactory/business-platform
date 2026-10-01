-- A2.1: narrow approved mapped half-day Leave ↔ worked Attendance integration.
-- Preserve immutable approved facts and require current interpretation evidence.

ALTER TABLE time.interpretations
  ADD COLUMN leave_evidence jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN leave_units numeric(3,1) NOT NULL DEFAULT 0,
  ADD COLUMN leave_compatibility_state text NOT NULL DEFAULT 'none',
  ADD CONSTRAINT interpretations_leave_evidence_array CHECK (jsonb_typeof(leave_evidence)='array'),
  ADD CONSTRAINT interpretations_leave_units_check CHECK (leave_units BETWEEN 0 AND 1 AND leave_units*2=trunc(leave_units*2)),
  ADD CONSTRAINT interpretations_leave_compatibility_state_check
    CHECK (leave_compatibility_state IN ('none','compatible','review_required','full_coverage'));

-- Exact approved source identity and immutable approved-preview mapping. This helper
-- is read-only and takes no Leave locks when called under the existing Time WI lock.
CREATE FUNCTION platform_private.approved_leave_context(p_tenant uuid,p_instance uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'request_id',r.id,'employee_id',r.employee_id,'employment_id',r.employment_id,
   'approved_preview_version',r.approved_preview_version,'leave_date',d.leave_date,
   'leave_type_id',r.leave_type_id,'is_half_day',r.is_half_day,'half_day_part',d.half_day_part,
   'units',d.units,
   'type_version_id',d.type_version_id,'calendar_version_id',d.calendar_version_id,
   'mapping_state',d.halfday_mapping_state,'mapping_snapshot',d.halfday_mapping_snapshot,
   'policy_template_id',d.halfday_policy_template_id,'policy_version',d.halfday_policy_version,
   'algorithm_version',d.halfday_algorithm_version
 ) ORDER BY r.id,d.leave_date),'[]'::jsonb)
 FROM time.work_instances i
 JOIN leave.requests r ON r.tenant_id=i.tenant_id AND r.employee_id=i.employee_id
   AND r.employment_id=i.employment_id AND r.state='approved'
   AND r.approved_preview_version IS NOT NULL AND r.cancelled_at IS NULL
 JOIN leave.request_days d ON d.tenant_id=r.tenant_id AND d.request_id=r.id
   AND d.preview_version=r.approved_preview_version
 WHERE i.tenant_id=p_tenant AND i.id=p_instance AND d.leave_date=i.operational_date
   AND d.eligible AND d.units>0
$f$;
REVOKE ALL ON FUNCTION platform_private.approved_leave_context(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role;

-- Preserve the qualified 31110 fingerprint inputs and add canonical approved Leave
-- identity/mapping. Cancellation removes the approved context and changes the digest.
CREATE OR REPLACE FUNCTION time.work_instance_interpretation_fingerprint(p_tenant uuid,p_instance uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fingerprint$
 SELECT pg_catalog.md5(
   coalesce((
     SELECT string_agg(
       p.id::text||':'||p.direction||':'||p.happened_at::text||':'||
       coalesce(c.action,'')||':'||coalesce(c.new_direction,'')||':'||
       coalesce(c.new_happened_at::text,''),',' ORDER BY p.id
     )
     FROM time.manual_punches p
     LEFT JOIN LATERAL(
       SELECT q.* FROM time.punch_corrections q WHERE q.tenant_id=p.tenant_id
         AND q.punch_id=p.id ORDER BY q.created_at DESC,q.id DESC LIMIT 1
     ) c ON true
     WHERE p.tenant_id=wi.tenant_id AND p.work_instance_id=wi.id
   ),'')
   ||pg_catalog.concat_ws(':',wi.tenant_id,wi.id,wi.schedule_kind,wi.operational_date,
     wi.timezone_name,wi.expected_start,wi.expected_end,wi.attribution_start,wi.attribution_end,
     wi.required_minutes,wi.break_minutes,wi.lateness_grace_minutes,wi.early_leave_grace_minutes,
     wi.policy_template_id,wi.policy_version,policy.fixed_break_start,policy.fixed_break_end)
   ||'|leave='||platform_private.approved_leave_context(p_tenant,p_instance)::text
 )
 FROM time.work_instances wi
 JOIN time.work_policy_versions policy ON policy.tenant_id=wi.tenant_id
   AND policy.template_id=wi.policy_template_id AND policy.version=wi.policy_version
 WHERE wi.tenant_id=p_tenant AND wi.id=p_instance
$fingerprint$;
REVOKE ALL ON FUNCTION time.work_instance_interpretation_fingerprint(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role;

-- Leave approval allows only two persisted, same-policy, complementary fixed halves
-- whose excused UTC intervals are disjoint. Flexible half-day has no clock part.
CREATE FUNCTION leave.complementary_approved_halfday_parts(
  p_tenant uuid,p_request_a uuid,p_request_b uuid,p_date date
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT coalesce(
   ra.employee_id=rb.employee_id AND ra.employment_id=rb.employment_id
   AND a.is_half_day AND b.is_half_day AND a.units=0.5 AND b.units=0.5
   AND a.halfday_mapping_state='mapped' AND b.halfday_mapping_state='mapped'
   AND a.halfday_policy_template_id=b.halfday_policy_template_id
   AND a.halfday_policy_version=b.halfday_policy_version
   AND a.halfday_algorithm_version=b.halfday_algorithm_version
   AND a.half_day_part IN ('first','second') AND b.half_day_part IN ('first','second')
   AND a.half_day_part<>b.half_day_part
   AND a.halfday_mapping_snapshot->'mapping'->>'schedule_kind'='fixed'
   AND b.halfday_mapping_snapshot->'mapping'->>'schedule_kind'='fixed'
   AND NOT EXISTS (
     SELECT 1 FROM jsonb_array_elements(a.halfday_mapping_snapshot->'mapping'->'excused_intervals') ai
     CROSS JOIN jsonb_array_elements(b.halfday_mapping_snapshot->'mapping'->'excused_intervals') bi
     WHERE tstzrange((ai.value->>'start_at')::timestamptz,(ai.value->>'end_at')::timestamptz,'[)')
        && tstzrange((bi.value->>'start_at')::timestamptz,(bi.value->>'end_at')::timestamptz,'[)')
   ),false)
 FROM leave.request_days a
 JOIN leave.requests ra ON ra.tenant_id=a.tenant_id AND ra.id=a.request_id
 CROSS JOIN leave.request_days b
 JOIN leave.requests rb ON rb.tenant_id=b.tenant_id AND rb.id=b.request_id
 WHERE a.tenant_id=p_tenant AND a.request_id=p_request_a AND a.leave_date=p_date
   AND a.preview_version=ra.current_preview_version
   AND b.tenant_id=p_tenant AND b.request_id=p_request_b AND b.leave_date=p_date
   AND b.preview_version=rb.approved_preview_version
   AND rb.state='approved' AND rb.cancelled_at IS NULL
$f$;
REVOKE ALL ON FUNCTION leave.complementary_approved_halfday_parts(uuid,uuid,uuid,date)
  FROM PUBLIC,anon,authenticated,service_role;

-- Add a Time-side compatibility proof to each new interpretation. The underlying
-- interpreter still owns punch pairing, DST resolution, and actual break overlap.
CREATE FUNCTION time.snapshot_approved_leave_on_interpretation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi time.work_instances%ROWTYPE; policy time.work_policy_versions%ROWTYPE;
  context jsonb; source jsonb; snapshot jsonb; mapping jsonb; interval_row jsonb;
  n_sources integer; total_units numeric; kind text; source_part text;
  mapping_state text; threshold integer; half_break integer; observed_break_seconds numeric;
  excused_seconds numeric; covered_seconds numeric; envelope_seconds numeric;
  missing_before numeric; missing_after numeric; p_start timestamptz; p_end timestamptz;
BEGIN
 SELECT * INTO wi FROM time.work_instances WHERE tenant_id=NEW.tenant_id AND id=NEW.work_instance_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
 context:=platform_private.approved_leave_context(NEW.tenant_id,NEW.work_instance_id);
 -- Preserve Leave-only/Attendance-off behavior. Enabling Attendance later changes the
 -- shared input fingerprint and the next interpretation must explicitly review it.
 IF NOT platform_private.tenant_capability_is_enabled(NEW.tenant_id,'hr.attendance',pg_catalog.now()) THEN
   NEW.leave_evidence:='[]'::jsonb; NEW.leave_units:=0; NEW.leave_compatibility_state:='none';
   RETURN NEW;
 END IF;
 NEW.leave_evidence:=context;
 SELECT count(*)::integer,coalesce(sum((x.value->>'units')::numeric),0)
   INTO n_sources,total_units FROM jsonb_array_elements(context) x(value);
 NEW.leave_units:=total_units;
 NEW.leave_compatibility_state:='none';
 IF n_sources=0 THEN RETURN NEW; END IF;
 NEW.leave_compatibility_state:='review_required';
 IF total_units>=1 OR n_sources<>1 OR total_units<>0.5 THEN
   NEW.leave_compatibility_state:='full_coverage';
   NEW.state:='needs_review'; NEW.owner_permission:='attendance.correct';
   NEW.exception_code:='leave_full_date_covered';
   RETURN NEW;
 END IF;
 -- Leave cannot resolve an independent punch/window/break exception. Preserve its
 -- original recovery diagnostic and owner; only valid ready observations can be
 -- evaluated against the approved half-day obligation below.
 IF NEW.state IS DISTINCT FROM 'ready' AND NEW.exception_code IS NOT NULL THEN
   RETURN NEW;
 END IF;
 NEW.state:='needs_review';
 NEW.owner_permission:='attendance.correct';
 NEW.exception_code:='leave_mapping_review_required';
 source:=context->0;
 IF (source->>'is_half_day')::boolean IS DISTINCT FROM true
    OR source->>'mapping_state' IS DISTINCT FROM 'mapped'
    OR source->>'policy_template_id' IS DISTINCT FROM wi.policy_template_id::text
    OR source->>'policy_version' IS DISTINCT FROM wi.policy_version::text
    OR source->>'algorithm_version' IS DISTINCT FROM 'leave-halfday-v1' THEN
   RETURN NEW;
 END IF;
 snapshot:=source->'mapping_snapshot';
 mapping:=snapshot->'mapping';
 kind:=mapping->>'schedule_kind';
 IF kind='fixed' THEN
   IF source->>'half_day_part' NOT IN ('first','second')
      OR jsonb_typeof(mapping->'excused_intervals') IS DISTINCT FROM 'array'
      OR jsonb_typeof(mapping->'remaining_intervals') IS DISTINCT FROM 'array'
      OR jsonb_typeof(mapping->'break_interval') IS DISTINCT FROM 'array'
      OR NEW.first_in IS NULL OR NEW.last_out IS NULL OR NEW.gross_worked_minutes IS NULL THEN
     RETURN NEW;
   END IF;
   p_start:=NEW.first_in; p_end:=NEW.last_out;
   envelope_seconds:=extract(epoch FROM (p_end-p_start));
   IF envelope_seconds<=0 THEN RETURN NEW; END IF;
   SELECT coalesce(sum(greatest(0,extract(epoch FROM
      (least(p_end,(x.value->>'end_at')::timestamptz)-greatest(p_start,(x.value->>'start_at')::timestamptz))))),0)
     INTO excused_seconds FROM jsonb_array_elements(mapping->'excused_intervals') x(value);
   SELECT coalesce(sum(greatest(0,extract(epoch FROM
      (least(p_end,(x.value->>'end_at')::timestamptz)-greatest(p_start,(x.value->>'start_at')::timestamptz))))),0)
     INTO covered_seconds
     FROM jsonb_array_elements((mapping->'remaining_intervals')||(mapping->'break_interval')) x(value);
   SELECT coalesce(sum(greatest(0,extract(epoch FROM
      (least(p_end,(x.value->>'end_at')::timestamptz)-greatest(p_start,(x.value->>'start_at')::timestamptz))))),0)
     INTO observed_break_seconds FROM jsonb_array_elements(mapping->'break_interval') x(value);
   -- An approved fixed half-day only excuses its stored spans. The actual punch
   -- envelope must be fully covered by remaining-work spans plus the configured break.
   IF excused_seconds<>0 OR covered_seconds<>envelope_seconds
      OR NEW.applied_break_minutes IS DISTINCT FROM (observed_break_seconds/60)::integer
      OR NEW.worked_minutes IS DISTINCT FROM greatest(0,NEW.gross_worked_minutes-NEW.applied_break_minutes) THEN
     RETURN NEW;
   END IF;
   SELECT coalesce(sum(greatest(0,extract(epoch FROM
      (least(p_start,(x.value->>'end_at')::timestamptz)-(x.value->>'start_at')::timestamptz)))),0)
     INTO missing_before FROM jsonb_array_elements(mapping->'remaining_intervals') x(value);
   SELECT coalesce(sum(greatest(0,extract(epoch FROM
      ((x.value->>'end_at')::timestamptz-greatest(p_end,(x.value->>'start_at')::timestamptz))))),0)
     INTO missing_after FROM jsonb_array_elements(mapping->'remaining_intervals') x(value);
   NEW.late_minutes:=greatest(0,(missing_before/60)::integer-wi.lateness_grace_minutes);
   NEW.early_leave_minutes:=greatest(0,(missing_after/60)::integer-wi.early_leave_grace_minutes);
   NEW.leave_compatibility_state:='compatible';
   NEW.state:='ready'; NEW.exception_code:=NULL; NEW.owner_permission:=NULL;
   RETURN NEW;
 ELSIF kind='flexible' THEN
   IF source->>'half_day_part' IS NOT NULL OR NEW.gross_worked_minutes IS NULL
      OR mapping->>'state' IS DISTINCT FROM 'mapped'
      OR source->>'policy_template_id' IS NULL OR source->>'policy_version' IS NULL THEN
     RETURN NEW;
   END IF;
   SELECT v.required_minutes,v.flexible_halfday_break_minutes INTO threshold,half_break
     FROM time.work_policy_versions v WHERE v.tenant_id=wi.tenant_id
       AND v.template_id=wi.policy_template_id AND v.version=wi.policy_version
       AND v.schedule_kind='flexible';
   IF NOT FOUND OR threshold IS NULL OR half_break IS NULL
      OR mapping->>'remaining_net_threshold_minutes' IS DISTINCT FROM ((threshold+1)/2)::text
      OR mapping->>'halfday_break_minutes' IS DISTINCT FROM half_break::text THEN
     RETURN NEW;
   END IF;
   -- Flexible schedules have no clock part/break interval: use only the explicit
   -- immutable half-day break deduction, never half of the full-day aggregate.
   NEW.applied_break_minutes:=half_break;
   NEW.worked_minutes:=greatest(0,NEW.gross_worked_minutes-half_break);
   IF NEW.worked_minutes<(threshold+1)/2 THEN
     NEW.exception_code:='leave_remaining_half_threshold_not_met';
     NEW.owner_permission:='attendance.correct';
     RETURN NEW;
   END IF;
   NEW.leave_compatibility_state:='compatible';
   NEW.state:='ready'; NEW.exception_code:=NULL; NEW.owner_permission:=NULL;
   RETURN NEW;
 END IF;
 RETURN NEW;
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow
    OR numeric_value_out_of_range THEN
 NEW.leave_compatibility_state:='review_required'; NEW.state:='needs_review';
 NEW.exception_code:='leave_mapping_review_required'; NEW.owner_permission:='attendance.correct';
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION time.snapshot_approved_leave_on_interpretation()
  FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER time_interpretation_approved_leave_snapshot
  BEFORE INSERT ON time.interpretations
  FOR EACH ROW EXECUTE FUNCTION time.snapshot_approved_leave_on_interpretation();

-- The existing interpreter's trailing WorkInstance status assignment uses its local
-- pre-trigger state. Reconcile it with the inserted immutable interpretation only
-- when this new Leave snapshot applies; approved facts remain approved.
CREATE FUNCTION time.sync_work_instance_leave_interpretation_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE latest_state text;
BEGIN
 IF NEW.status='approved' THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM time.attendance_facts f
   WHERE f.tenant_id=NEW.tenant_id AND f.work_instance_id=NEW.id) THEN RETURN NEW; END IF;
 SELECT q.state INTO latest_state FROM time.interpretations q
  WHERE q.tenant_id=NEW.tenant_id AND q.work_instance_id=NEW.id
  ORDER BY q.version DESC LIMIT 1;
 IF latest_state IS NOT NULL AND EXISTS(
   SELECT 1 FROM time.interpretations q WHERE q.tenant_id=NEW.tenant_id
    AND q.work_instance_id=NEW.id ORDER BY q.version DESC LIMIT 1
 ) AND EXISTS(
   SELECT 1 FROM time.interpretations q WHERE q.tenant_id=NEW.tenant_id
    AND q.work_instance_id=NEW.id AND q.version=(SELECT max(z.version) FROM time.interpretations z
      WHERE z.tenant_id=NEW.tenant_id AND z.work_instance_id=NEW.id)
      AND jsonb_array_length(q.leave_evidence)>0
 ) THEN NEW.status:=latest_state; END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION time.sync_work_instance_leave_interpretation_status()
  FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER time_work_instance_sync_leave_interpretation_status
  BEFORE UPDATE OF status ON time.work_instances
  FOR EACH ROW EXECUTE FUNCTION time.sync_work_instance_leave_interpretation_status();

-- The existing WorkInstance guard now permits only a current, matching interpretation
-- that proved one mapped half-day compatible. Full-day, flexible-unmapped, stale,
-- cancellation-changed, and two-half full-coverage cases remain conflicts.
CREATE OR REPLACE FUNCTION platform_private.approved_leave_conflicts_with_work_instance(
  p_tenant_id uuid,p_instance_id uuid
) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE context jsonb; q time.interpretations%ROWTYPE; current_fp text;
BEGIN
 context:=platform_private.approved_leave_context(p_tenant_id,p_instance_id);
 SELECT * INTO q FROM time.interpretations x WHERE x.tenant_id=p_tenant_id
   AND x.work_instance_id=p_instance_id ORDER BY x.version DESC LIMIT 1;
 IF NOT FOUND THEN RETURN jsonb_array_length(context)>0; END IF;
 current_fp:=time.work_instance_interpretation_fingerprint(p_tenant_id,p_instance_id);
 IF jsonb_array_length(context)=0 THEN
   -- There is no current approved Leave conflict. Manual/automatic fact paths
   -- still reject a disappeared source through their shared fingerprint gate.
   RETURN false;
 END IF;
 IF q.input_fingerprint IS DISTINCT FROM current_fp
    OR q.leave_evidence IS DISTINCT FROM context THEN RETURN true; END IF;
 RETURN q.state IS DISTINCT FROM 'ready'
   OR q.leave_compatibility_state IS DISTINCT FROM 'compatible'
   OR q.leave_units IS DISTINCT FROM 0.5;
END $f$;
REVOKE ALL ON FUNCTION platform_private.approved_leave_conflicts_with_work_instance(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role;

-- Keep a fact approval from committing an interpretation made before a newly approved
-- half-day/cancellation/policy fingerprint. Reject stale evidence under the held WI lock.
DO $manual$ DECLARE def text; anchor text; repl text; n integer;
BEGIN
 def:=pg_catalog.pg_get_functiondef('public.approve_attendance_fact(uuid,uuid,uuid,text)'::regprocedure);
 anchor:='IF platform_private.approved_leave_conflicts_with_work_instance(p_tenant_id,p_instance_id) THEN RAISE EXCEPTION ''leave_conflict_review_required'' USING ERRCODE=''23514''; END IF;';
 repl:=anchor || E'\n SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant_id AND work_instance_id=p_instance_id ORDER BY version DESC LIMIT 1;' ||
   E'\n IF FOUND AND q.input_fingerprint IS DISTINCT FROM time.work_instance_interpretation_fingerprint(p_tenant_id,p_instance_id) THEN RAISE EXCEPTION ''attendance_interpretation_stale'' USING ERRCODE=''PT409''; END IF;\n ';
 n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
 IF n<>1 THEN RAISE EXCEPTION 'A2.1 approve-fact interpretation anchor count %',n USING ERRCODE='55000'; END IF;
 EXECUTE replace(def,anchor,repl);
END $manual$;

-- A stale interpretation is a per-item skip in the existing bulk operation,
-- including the HTTP-safe deterministic conflict returned by manual approval.
DO $bulk_stale$ DECLARE def text; anchor text; repl text; n integer;
BEGIN
 def:=pg_catalog.pg_get_functiondef('public.approve_attendance_facts_bulk(uuid,date,uuid[])'::regprocedure);
 anchor:='IF err_code NOT IN(''42501'',''P0002'',''23514'',''40001'',''22023'') THEN RAISE; END IF;';
 repl:='IF err_code NOT IN(''42501'',''P0002'',''23514'',''40001'',''PT409'',''22023'') THEN RAISE; END IF;';
 n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
 IF n<>1 THEN RAISE EXCEPTION 'A2.1 bulk stale exception anchor count %',n USING ERRCODE='55000'; END IF;
 def:=replace(def,anchor,repl);
 -- Preserve the concrete Leave conflict even when a new Leave-aware
 -- interpretation no longer passes the generic ready precheck.
 anchor:='ELSIF NOT EXISTS(';
 repl:='ELSIF platform_private.approved_leave_conflicts_with_work_instance(p_tenant_id,item) THEN reason_code:=''leave_conflict_review_required'';' || E'\n   ' || anchor;
 n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
 IF n<>1 THEN RAISE EXCEPTION 'A2.1 bulk Leave conflict precheck anchor count %',n USING ERRCODE='55000'; END IF;
 EXECUTE replace(def,anchor,repl);
END $bulk_stale$;

-- Facts carry the exact approved Leave source preview and versioned mapping beside
-- gross/net/applied-break metrics. Old approved facts are never rewritten or backfilled.
DO $facts$ DECLARE target regprocedure; def text; anchor text; repl text; n integer;
BEGIN
 FOREACH target IN ARRAY ARRAY[
   'public.approve_attendance_fact(uuid,uuid,uuid,text)'::regprocedure,
   'time.auto_approve_clean_work_instance(uuid,uuid,uuid)'::regprocedure
 ] LOOP
   def:=pg_catalog.pg_get_functiondef(target);
   anchor:='''applied_break_minutes'',q.applied_break_minutes,''worked_minutes'',q.worked_minutes';
   repl:=anchor||',''leave_units'',q.leave_units,''leave_sources'',q.leave_evidence,''leave_compatibility_state'',q.leave_compatibility_state';
   n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
   IF n<>1 THEN RAISE EXCEPTION 'A2.1 fact Leave provenance anchor count % for %',n,target USING ERRCODE='55000'; END IF;
   EXECUTE replace(def,anchor,repl);
 END LOOP;

 target:='public.attendance_open_day(uuid,date,text,integer)'::regprocedure;
 def:=pg_catalog.pg_get_functiondef(target);
 anchor:='''applied_break_minutes'',q.applied_break_minutes,''exception_code'',q.exception_code';
 repl:='''applied_break_minutes'',q.applied_break_minutes,''leave_units'',q.leave_units,''leave_evidence'',q.leave_evidence,''leave_compatibility_state'',q.leave_compatibility_state,''exception_code'',q.exception_code';
 n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
 IF n<>1 THEN RAISE EXCEPTION 'A2.1 open-day Leave evidence anchor count %',n USING ERRCODE='55000'; END IF;
 EXECUTE replace(def,anchor,repl);

 target:='public.attendance_day_list(uuid,date,text,integer)'::regprocedure;
 def:=pg_catalog.pg_get_functiondef(target);
 anchor:='q.late_minutes,q.early_leave_minutes,q.worked_minutes,q.gross_worked_minutes,q.scheduled_break_minutes,q.applied_break_minutes,q.exception_code';
 repl:='q.late_minutes,q.early_leave_minutes,q.worked_minutes,q.gross_worked_minutes,q.scheduled_break_minutes,q.applied_break_minutes,q.leave_units,q.leave_evidence,q.leave_compatibility_state,q.exception_code';
 n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
 IF n<>1 THEN RAISE EXCEPTION 'A2.1 day-list Leave evidence anchor count %',n USING ERRCODE='55000'; END IF;
 EXECUTE replace(def,anchor,repl);
END $facts$;

-- Replace the broad Leave overlap condition with the single narrow complementary-fixed
-- exception. Same part, different policy/version, flexible, unmapped, or full-day stays blocked.
DO $leave_overlap$ DECLARE def text; anchor text; repl text; n integer;
BEGIN
 def:=pg_catalog.pg_get_functiondef('public.leave_approve_request(uuid,uuid,integer,integer,text,text)'::regprocedure);
 anchor:='AND own.eligible AND own.units>0)';
 repl:='AND own.eligible AND own.units>0' || E'\n' ||
   '          AND NOT leave.complementary_approved_halfday_parts(p_tenant,r.id,other.id,own.leave_date))';
 n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
 IF n<>1 THEN RAISE EXCEPTION 'A2.1 Leave overlap anchor count %',n USING ERRCODE='55000'; END IF;
 EXECUTE replace(def,anchor,repl);
END $leave_overlap$;

-- A linked replacement of one reviewed half obeys the same overlap rule as an
-- ordinary approval. The unchanged complementary half remains approved evidence.
DO $correction_overlap$ DECLARE def text; anchor text; repl text; n integer;
BEGIN
 def:=pg_catalog.pg_get_functiondef('public.leave_correct_approved_request(uuid,uuid,integer,integer,uuid,integer,integer,text,text)'::regprocedure);
 anchor:='AND nd.leave_date=d.leave_date AND nd.eligible AND nd.units>0))';
 repl:='AND nd.leave_date=d.leave_date AND nd.eligible AND nd.units>0' || E'\n' ||
   '          AND NOT leave.complementary_approved_halfday_parts(p_tenant,newr.id,q.id,nd.leave_date)))';
 n:=(length(def)-length(replace(def,anchor,'')))/length(anchor);
 IF n<>1 THEN RAISE EXCEPTION 'A2.1 correction overlap anchor count %',n USING ERRCODE='55000'; END IF;
 EXECUTE replace(def,anchor,repl);
END $correction_overlap$;
