-- Atomic correction of an already-approved Leave request.
-- Preserve historical facts and link an independently reviewed replacement.

ALTER TABLE leave.requests ADD COLUMN superseded_at timestamptz;
ALTER TABLE leave.requests DROP CONSTRAINT requests_state_check;
ALTER TABLE leave.requests ADD CONSTRAINT requests_state_check
  CHECK (state IN ('draft','submitted','approved','rejected','withdrawn','cancelled','superseded'));
ALTER TABLE leave.requests DROP CONSTRAINT leave_request_approval_state_check;
ALTER TABLE leave.requests ADD CONSTRAINT leave_request_approval_state_check CHECK (
  (state IN ('approved','cancelled','superseded') AND approved_at IS NOT NULL AND approved_by IS NOT NULL
    AND approved_preview_version IS NOT NULL AND approved_preview_version=current_preview_version)
  OR (state NOT IN ('approved','cancelled','superseded') AND approved_at IS NULL AND approved_by IS NULL
    AND approved_preview_version IS NULL));
ALTER TABLE leave.requests ADD CONSTRAINT leave_request_supersession_state_check CHECK (
  (state='superseded' AND superseded_at IS NOT NULL AND cancelled_at IS NULL)
  OR (state<>'superseded' AND superseded_at IS NULL));
ALTER TABLE leave.requests ADD CONSTRAINT leave_request_identity_for_correction_unique
  UNIQUE (tenant_id,id,employee_id,employment_id,employer_entity_id);

CREATE TABLE leave.request_corrections (
  tenant_id uuid NOT NULL, id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  original_request_id uuid NOT NULL, replacement_request_id uuid NOT NULL,
  employee_id uuid NOT NULL, employment_id uuid NOT NULL, employer_entity_id uuid NOT NULL,
  original_from_version integer NOT NULL CHECK(original_from_version>0),
  original_to_version integer NOT NULL CHECK(original_to_version=original_from_version+1),
  original_approved_preview_version integer NOT NULL CHECK(original_approved_preview_version>0),
  replacement_from_version integer NOT NULL CHECK(replacement_from_version>0),
  replacement_to_version integer NOT NULL CHECK(replacement_to_version=replacement_from_version+1),
  replacement_preview_version integer NOT NULL CHECK(replacement_preview_version>0),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  reason text NOT NULL CHECK(length(pg_catalog.btrim(reason)) BETWEEN 3 AND 500),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY(tenant_id,id), UNIQUE(tenant_id,id,original_request_id,replacement_request_id),
  UNIQUE(tenant_id,original_request_id), UNIQUE(tenant_id,replacement_request_id),
  FOREIGN KEY(tenant_id,original_request_id,employee_id,employment_id,employer_entity_id)
    REFERENCES leave.requests(tenant_id,id,employee_id,employment_id,employer_entity_id) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,replacement_request_id,employee_id,employment_id,employer_entity_id)
    REFERENCES leave.requests(tenant_id,id,employee_id,employment_id,employer_entity_id) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,original_request_id,original_approved_preview_version)
    REFERENCES leave.request_previews(tenant_id,request_id,preview_version) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,replacement_request_id,replacement_preview_version)
    REFERENCES leave.request_previews(tenant_id,request_id,preview_version) ON DELETE RESTRICT,
  CHECK(original_request_id<>replacement_request_id));
CREATE INDEX leave_request_corrections_replacement ON leave.request_corrections(tenant_id,replacement_request_id);
ALTER TABLE leave.request_corrections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE leave.request_corrections FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_request_corrections_immutable BEFORE UPDATE OR DELETE ON leave.request_corrections
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();

CREATE FUNCTION leave.guard_request_correction_link() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE oldr leave.requests%ROWTYPE; newr leave.requests%ROWTYPE;
BEGIN
  SELECT * INTO oldr FROM leave.requests r WHERE r.tenant_id=NEW.tenant_id AND r.id=NEW.original_request_id;
  SELECT * INTO newr FROM leave.requests r WHERE r.tenant_id=NEW.tenant_id AND r.id=NEW.replacement_request_id;
  IF oldr.id IS NULL OR newr.id IS NULL OR oldr.state<>'approved' OR oldr.version<>NEW.original_from_version
    OR oldr.approved_preview_version<>NEW.original_approved_preview_version OR newr.state<>'submitted'
    OR newr.version<>NEW.replacement_from_version OR newr.current_preview_version<>NEW.replacement_preview_version
    OR ROW(oldr.employee_id,oldr.employment_id,oldr.employer_entity_id) IS DISTINCT FROM
       ROW(newr.employee_id,newr.employment_id,newr.employer_entity_id)
    OR ROW(oldr.employee_id,oldr.employment_id,oldr.employer_entity_id) IS DISTINCT FROM
       ROW(NEW.employee_id,NEW.employment_id,NEW.employer_entity_id) THEN
    RAISE EXCEPTION 'leave_correction_link_invalid' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION leave.guard_request_correction_link() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_request_correction_link_guard BEFORE INSERT ON leave.request_corrections
  FOR EACH ROW EXECUTE FUNCTION leave.guard_request_correction_link();

CREATE TABLE leave.correction_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, tenant_id uuid NOT NULL, correction_id uuid NOT NULL,
  original_request_id uuid NOT NULL, replacement_request_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK(event_key='hr.corrected'), from_state text NOT NULL CHECK(from_state='approved'),
  to_state text NOT NULL CHECK(to_state='superseded'),
  original_from_version integer NOT NULL, original_to_version integer NOT NULL,
  replacement_from_version integer NOT NULL, replacement_to_version integer NOT NULL,
  reason text NOT NULL CHECK(length(pg_catalog.btrim(reason)) BETWEEN 3 AND 500),
  operation_key text NOT NULL CHECK(length(pg_catalog.btrim(operation_key)) BETWEEN 1 AND 120),
  payload_hash text NOT NULL CHECK(payload_hash ~ '^[0-9a-f]{64}$'), result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY(tenant_id,correction_id,original_request_id,replacement_request_id)
    REFERENCES leave.request_corrections(tenant_id,id,original_request_id,replacement_request_id) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,original_request_id) REFERENCES leave.requests(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,replacement_request_id) REFERENCES leave.requests(tenant_id,id) ON DELETE RESTRICT,
  UNIQUE(tenant_id,actor_user_id,operation_key));
CREATE INDEX leave_correction_events_request ON leave.correction_events(tenant_id,original_request_id,id);
ALTER TABLE leave.correction_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE leave.correction_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE leave.correction_events_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_correction_events_append_only BEFORE UPDATE OR DELETE ON leave.correction_events
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();

ALTER TABLE leave.ledger_entries ADD COLUMN correction_id uuid;
ALTER TABLE leave.ledger_entries ADD CONSTRAINT leave_ledger_correction_fk
  FOREIGN KEY(tenant_id,correction_id) REFERENCES leave.request_corrections(tenant_id,id) ON DELETE RESTRICT;
ALTER TABLE leave.ledger_entries DROP CONSTRAINT ledger_entries_entry_kind_check;
ALTER TABLE leave.ledger_entries ADD CONSTRAINT ledger_entries_entry_kind_check CHECK
  (entry_kind IN ('opening','annual_grant','adjustment','leave_consumption','cancellation_reversal','correction_reversal'));
ALTER TABLE leave.ledger_entries DROP CONSTRAINT ledger_entries_check;
ALTER TABLE leave.ledger_entries ADD CONSTRAINT ledger_entries_check CHECK (
  delta_days<>0 AND delta_days::text NOT IN ('NaN','Infinity','-Infinity') AND (
    (entry_kind IN ('opening','annual_grant') AND delta_days>0 AND reversal_of_entry_id IS NULL AND correction_id IS NULL)
    OR (entry_kind='adjustment' AND reversal_of_entry_id IS NULL AND correction_id IS NULL)
    OR (entry_kind='leave_consumption' AND delta_days<0 AND reversal_of_entry_id IS NULL AND correction_id IS NULL)
    OR (entry_kind='cancellation_reversal' AND delta_days>0 AND reversal_of_entry_id IS NOT NULL AND correction_id IS NULL)
    OR (entry_kind='correction_reversal' AND delta_days>0 AND reversal_of_entry_id IS NOT NULL AND correction_id IS NOT NULL)));
DROP INDEX leave.leave_ledger_one_cancellation_reversal;
CREATE UNIQUE INDEX leave_ledger_one_request_reversal ON leave.ledger_entries(tenant_id,reversal_of_entry_id)
  WHERE entry_kind IN ('cancellation_reversal','correction_reversal');

CREATE OR REPLACE FUNCTION leave.guard_cancellation_reversal() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE original leave.ledger_entries%ROWTYPE; allocation leave.request_consumptions%ROWTYPE;
BEGIN
  IF NEW.entry_kind NOT IN ('cancellation_reversal','correction_reversal') THEN
    IF NEW.reversal_of_entry_id IS NOT NULL OR NEW.correction_id IS NOT NULL THEN
      RAISE EXCEPTION 'leave_reversal_reference_invalid' USING ERRCODE='23514'; END IF; RETURN NEW; END IF;
  IF NEW.reversal_of_entry_id IS NULL THEN RAISE EXCEPTION 'leave_reversal_reference_required' USING ERRCODE='23514'; END IF;
  SELECT * INTO original FROM leave.ledger_entries l WHERE l.tenant_id=NEW.tenant_id AND l.account_id=NEW.account_id
    AND l.id=NEW.reversal_of_entry_id;
  IF NOT FOUND OR original.entry_kind<>'leave_consumption' OR original.delta_days>=0
    OR original.leave_type_id<>NEW.leave_type_id OR NEW.delta_days<>-original.delta_days THEN
    RAISE EXCEPTION 'leave_reversal_must_exactly_match_consumption' USING ERRCODE='23514'; END IF;
  SELECT * INTO allocation FROM leave.request_consumptions c WHERE c.tenant_id=NEW.tenant_id
    AND c.ledger_entry_id=original.id AND c.account_id=original.account_id AND c.leave_type_id=original.leave_type_id;
  IF NOT FOUND OR NEW.delta_days<>allocation.units THEN RAISE EXCEPTION 'leave_reversal_allocation_unavailable' USING ERRCODE='23514'; END IF;
  IF NEW.entry_kind='cancellation_reversal' THEN
    IF NEW.correction_id IS NOT NULL THEN RAISE EXCEPTION 'leave_reversal_reference_invalid' USING ERRCODE='23514'; END IF;
  ELSE
    IF NEW.correction_id IS NULL OR NOT EXISTS(SELECT 1 FROM leave.request_corrections c
      WHERE c.tenant_id=NEW.tenant_id AND c.id=NEW.correction_id AND c.original_request_id=allocation.request_id
        AND c.original_approved_preview_version=allocation.preview_version) THEN
      RAISE EXCEPTION 'leave_correction_reversal_unavailable' USING ERRCODE='23514'; END IF;
  END IF; RETURN NEW;
END $f$;

CREATE OR REPLACE FUNCTION leave.request_replay(p_tenant uuid,p_actor uuid,p_key text,p_action text,p_hash text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE old leave.request_events%ROWTYPE;
BEGIN
  IF EXISTS(SELECT 1 FROM leave.correction_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=p_actor AND e.operation_key=p_key)
     OR EXISTS(SELECT 1 FROM leave.cancellation_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=p_actor AND e.operation_key=p_key) THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
  SELECT * INTO old FROM leave.request_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=p_actor AND e.operation_key=p_key;
  IF NOT FOUND THEN
    IF p_key LIKE 'leave-internal:%' THEN RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
    RETURN NULL; END IF;
  IF old.event_key IS DISTINCT FROM p_action OR old.payload_hash IS DISTINCT FROM p_hash THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF; RETURN old.result;
END $f$;
CREATE OR REPLACE FUNCTION leave.cancellation_replay(p_tenant uuid,p_actor uuid,p_key text,p_action text,p_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE old leave.cancellation_events%ROWTYPE; request_replay jsonb;
BEGIN
  IF EXISTS(SELECT 1 FROM leave.correction_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=p_actor AND e.operation_key=p_key)
    THEN RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
  SELECT * INTO old FROM leave.cancellation_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=p_actor AND e.operation_key=p_key;
  IF FOUND THEN
    IF old.event_key IS DISTINCT FROM p_action OR old.payload_hash IS DISTINCT FROM p_hash THEN
      RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF; RETURN old.result; END IF;
  request_replay:=leave.request_replay(p_tenant,p_actor,p_key,p_action,p_hash);
  IF request_replay IS NOT NULL THEN RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
  RETURN NULL;
END $f$;

CREATE OR REPLACE FUNCTION leave.guard_request_transition() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE is_refresh boolean; is_approval boolean; is_terminal boolean; is_cancellation boolean; is_supersession boolean;
BEGIN
  IF ROW(NEW.tenant_id,NEW.id,NEW.employee_id,NEW.employment_id,NEW.employer_entity_id,NEW.leave_type_id,
      NEW.start_date,NEW.end_date,NEW.is_half_day,NEW.half_day_part,NEW.request_source,NEW.created_by,NEW.submitted_by,
      NEW.submitted_at,NEW.reason,NEW.owner_queue,NEW.owner_user_id,NEW.created_at)
     IS DISTINCT FROM ROW(OLD.tenant_id,OLD.id,OLD.employee_id,OLD.employment_id,OLD.employer_entity_id,OLD.leave_type_id,
      OLD.start_date,OLD.end_date,OLD.is_half_day,OLD.half_day_part,OLD.request_source,OLD.created_by,OLD.submitted_by,
      OLD.submitted_at,OLD.reason,OLD.owner_queue,OLD.owner_user_id,OLD.created_at)
     OR NEW.version<>OLD.version+1 THEN RAISE EXCEPTION 'leave_request_transition_invalid' USING ERRCODE='55000'; END IF;
  is_refresh:=OLD.state='submitted' AND NEW.state='submitted' AND NEW.current_preview_version=OLD.current_preview_version+1
    AND NEW.approved_at IS NOT DISTINCT FROM OLD.approved_at AND NEW.approved_by IS NOT DISTINCT FROM OLD.approved_by
    AND NEW.approved_preview_version IS NOT DISTINCT FROM OLD.approved_preview_version
    AND NEW.cancelled_at IS NOT DISTINCT FROM OLD.cancelled_at AND NEW.superseded_at IS NULL;
  is_approval:=OLD.state='submitted' AND NEW.state='approved' AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NOT NULL AND NEW.approved_by IS NOT NULL AND NEW.approved_preview_version=NEW.current_preview_version
    AND NEW.cancelled_at IS NULL AND NEW.superseded_at IS NULL;
  is_terminal:=OLD.state='submitted' AND NEW.state IN ('withdrawn','rejected') AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NULL AND NEW.approved_by IS NULL AND NEW.approved_preview_version IS NULL
    AND NEW.cancelled_at IS NULL AND NEW.superseded_at IS NULL;
  is_cancellation:=OLD.state='approved' AND NEW.state='cancelled' AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NOT DISTINCT FROM OLD.approved_at AND NEW.approved_by IS NOT DISTINCT FROM OLD.approved_by
    AND NEW.approved_preview_version IS NOT DISTINCT FROM OLD.approved_preview_version
    AND NEW.cancelled_at IS NOT NULL AND NEW.superseded_at IS NULL;
  is_supersession:=OLD.state='approved' AND NEW.state='superseded' AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NOT DISTINCT FROM OLD.approved_at AND NEW.approved_by IS NOT DISTINCT FROM OLD.approved_by
    AND NEW.approved_preview_version IS NOT DISTINCT FROM OLD.approved_preview_version
    AND NEW.cancelled_at IS NULL AND NEW.superseded_at IS NOT NULL
    AND EXISTS(SELECT 1 FROM leave.request_corrections c WHERE c.tenant_id=NEW.tenant_id
      AND c.original_request_id=NEW.id AND c.original_from_version=OLD.version AND c.original_to_version=NEW.version
      AND EXISTS(SELECT 1 FROM leave.requests nr WHERE nr.tenant_id=c.tenant_id
        AND nr.id=c.replacement_request_id AND nr.state='approved'));
  IF NOT (is_refresh OR is_approval OR is_terminal OR is_cancellation OR is_supersession) THEN
    RAISE EXCEPTION 'leave_request_transition_invalid' USING ERRCODE='55000'; END IF;
  NEW.updated_at:=pg_catalog.transaction_timestamp(); RETURN NEW;
END $f$;

-- Dedicated correction path. It does not expose an overlap bypass flag and cannot
-- change Time facts; any captured Time fact remains a fail-closed conflict.
CREATE FUNCTION public.leave_correct_approved_request(
  p_tenant uuid,p_original_request uuid,p_original_expected_version integer,p_original_preview_version integer,
  p_replacement_request uuid,p_replacement_expected_version integer,p_replacement_preview_version integer,
  p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); oldr leave.requests%ROWTYPE; newr leave.requests%ROWTYPE;
  employment people.employments%ROWTYPE; employer_active boolean; payload jsonb; payload_hash text;
  prior leave.correction_events%ROWTYPE; corr uuid; result jsonb; consumption_row record; ac record;
  need numeric(8,2); bal numeric(10,2); take_units numeric(8,2); ledger_id uuid; conflicts jsonb;
  config_calendar uuid; config_type uuid; computed jsonb; stored jsonb; approval_key text;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_original_request IS NULL OR p_replacement_request IS NULL
     OR p_original_request=p_replacement_request OR p_original_expected_version IS NULL OR p_original_expected_version<=0
     OR p_original_preview_version IS NULL OR p_original_preview_version<=0
     OR p_replacement_expected_version IS NULL OR p_replacement_expected_version<=0
     OR p_replacement_preview_version IS NULL OR p_replacement_preview_version<=0
     OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
     OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_correction_input_invalid' USING ERRCODE='22023'; END IF;
  IF pg_catalog.btrim(p_idempotency_key) LIKE 'leave-internal:%' THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  SELECT * INTO oldr FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id=p_original_request;
  SELECT * INTO newr FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id=p_replacement_request;
  IF oldr.id IS NULL OR newr.id IS NULL OR ROW(oldr.employee_id,oldr.employment_id,oldr.employer_entity_id)
      IS DISTINCT FROM ROW(newr.employee_id,newr.employment_id,newr.employer_entity_id) THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=oldr.employee_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=oldr.employee_id
    AND e.start_date<=greatest(oldr.end_date,newr.end_date)
    AND (e.end_date IS NULL OR e.end_date>=least(oldr.start_date,newr.start_date)) ORDER BY e.id FOR UPDATE;
  SELECT * INTO employment FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=oldr.employment_id
    AND e.employee_id=oldr.employee_id;
  IF NOT FOUND OR employment.id<>newr.employment_id OR employment.employer_entity_id<>oldr.employer_entity_id THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  SELECT e.is_active INTO employer_active FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.id=oldr.employer_entity_id FOR UPDATE;
  IF NOT coalesce(employer_active,false) THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  payload:=pg_catalog.jsonb_build_object('action','hr.corrected','tenant',p_tenant,'original',p_original_request,
    'original_version',p_original_expected_version,'original_preview',p_original_preview_version,
    'replacement',p_replacement_request,'replacement_version',p_replacement_expected_version,
    'replacement_preview',p_replacement_preview_version,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  SELECT * INTO prior FROM leave.correction_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=actor
    AND e.operation_key=pg_catalog.btrim(p_idempotency_key);
  IF FOUND THEN
    IF prior.event_key<>'hr.corrected' OR prior.payload_hash<>payload_hash THEN
      RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF; RETURN prior.result; END IF;
  IF EXISTS(SELECT 1 FROM leave.cancellation_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=actor
      AND e.operation_key=pg_catalog.btrim(p_idempotency_key)) OR EXISTS(SELECT 1 FROM leave.request_events e
      WHERE e.tenant_id=p_tenant AND e.actor_user_id=actor AND e.operation_key=pg_catalog.btrim(p_idempotency_key)) THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
  -- Lock the union in global order: all relevant calendars by id, then both
  -- distinct types by id. Reversing old/new argument order cannot invert locks.
  FOR config_calendar IN SELECT DISTINCT yp.calendar_id FROM leave.year_periods yp
    WHERE yp.tenant_id=p_tenant AND yp.employer_entity_id=oldr.employer_entity_id
      AND ((yp.starts_on<=oldr.end_date AND yp.ends_on>=oldr.start_date)
        OR (yp.starts_on<=newr.end_date AND yp.ends_on>=newr.start_date))
    ORDER BY yp.calendar_id
  LOOP
    PERFORM 1 FROM leave.calendars c WHERE c.tenant_id=p_tenant AND c.id=config_calendar FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'leave_calendar_unavailable' USING ERRCODE='23503'; END IF;
  END LOOP;
  FOR config_type IN SELECT DISTINCT t.id FROM leave.types t
    WHERE t.tenant_id=p_tenant AND t.id IN (oldr.leave_type_id,newr.leave_type_id) ORDER BY t.id
  LOOP
    PERFORM 1 FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=config_type FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503'; END IF;
  END LOOP;
  PERFORM 1 FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id IN (oldr.id,newr.id) ORDER BY r.id FOR UPDATE;
  SELECT * INTO oldr FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id=p_original_request;
  SELECT * INTO newr FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id=p_replacement_request;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  SELECT * INTO prior FROM leave.correction_events e WHERE e.tenant_id=p_tenant AND e.actor_user_id=actor
    AND e.operation_key=pg_catalog.btrim(p_idempotency_key);
  IF FOUND THEN
    IF prior.payload_hash<>payload_hash THEN RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
    RETURN prior.result; END IF;
  IF EXISTS(SELECT 1 FROM leave.cancellation_requests c WHERE c.tenant_id=p_tenant
      AND c.request_id=oldr.id AND c.state='pending') THEN RAISE EXCEPTION 'leave_cancellation_pending' USING ERRCODE='23514'; END IF;
  IF oldr.state<>'approved' OR oldr.version<>p_original_expected_version
      OR oldr.approved_preview_version<>p_original_preview_version OR newr.state<>'submitted'
      OR newr.version<>p_replacement_expected_version OR newr.current_preview_version<>p_replacement_preview_version THEN
    RAISE EXCEPTION 'leave_request_version_conflict' USING ERRCODE='PT409'; END IF;
  IF employment.employment_status<>'active' OR employment.start_date>least(oldr.start_date,newr.start_date)
      OR (employment.end_date IS NOT NULL AND employment.end_date<greatest(oldr.end_date,newr.end_date)) THEN
    RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS(SELECT 1 FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=newr.leave_type_id
      AND t.employer_entity_id=newr.employer_entity_id AND t.is_active) THEN
    RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23514'; END IF;
  computed:=leave.request_preview_with_mapping(p_tenant,newr.employer_entity_id,newr.employment_id,
    newr.leave_type_id,newr.start_date,newr.end_date,newr.is_half_day,
    (SELECT d.half_day_part FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=newr.id
      AND d.preview_version=newr.current_preview_version AND d.is_half_day LIMIT 1));
  stored:=leave.request_preview_snapshot(p_tenant,newr.id,newr.current_preview_version);
  IF computed IS DISTINCT FROM stored THEN
    RETURN pg_catalog.jsonb_build_object('state','refresh_required','request_id',newr.id,
      'request_version',newr.version,'stored_preview_version',newr.current_preview_version,
      'stored_preview',stored,'current_preview',computed); END IF;
  IF EXISTS(SELECT 1 FROM leave.request_days d JOIN leave.requests q ON q.tenant_id=d.tenant_id AND q.id=d.request_id
      WHERE d.tenant_id=p_tenant AND q.employee_id=newr.employee_id AND q.state='approved'
        AND q.id NOT IN(oldr.id,newr.id) AND d.preview_version=q.approved_preview_version AND d.eligible AND d.units>0
        AND EXISTS(SELECT 1 FROM leave.request_days nd WHERE nd.tenant_id=p_tenant AND nd.request_id=newr.id
          AND nd.preview_version=newr.current_preview_version AND nd.leave_date=d.leave_date AND nd.eligible AND nd.units>0)) THEN
    RAISE EXCEPTION 'leave_request_overlap' USING ERRCODE='23514'; END IF;
  PERFORM 1 FROM time.work_instances i WHERE i.tenant_id=p_tenant AND i.employment_id=oldr.employment_id
    AND i.operational_date BETWEEN least(oldr.start_date,newr.start_date) AND greatest(oldr.end_date,newr.end_date)
    AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant
      AND ((d.request_id=oldr.id AND d.preview_version=oldr.approved_preview_version)
        OR (d.request_id=newr.id AND d.preview_version=newr.current_preview_version))
      AND d.leave_date=i.operational_date AND d.eligible AND d.units>0)
    ORDER BY i.operational_date,i.id FOR NO KEY UPDATE;
  computed:=leave.request_preview_with_mapping(p_tenant,newr.employer_entity_id,newr.employment_id,
    newr.leave_type_id,newr.start_date,newr.end_date,newr.is_half_day,
    (SELECT d.half_day_part FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=newr.id
      AND d.preview_version=newr.current_preview_version AND d.is_half_day LIMIT 1));
  stored:=leave.request_preview_snapshot(p_tenant,newr.id,newr.current_preview_version);
  IF computed IS DISTINCT FROM stored THEN
    RETURN pg_catalog.jsonb_build_object('state','refresh_required','request_id',newr.id,
      'request_version',newr.version,'stored_preview_version',newr.current_preview_version,
      'stored_preview',stored,'current_preview',computed); END IF;
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('work_instance_id',i.id,'operational_date',i.operational_date,
      'attendance_fact_id',f.id,'attendance_fact_version',f.version,'outcome',f.fact->>'outcome') ORDER BY i.operational_date,i.id)
    INTO conflicts FROM time.work_instances i JOIN LATERAL (SELECT x.id,x.version,x.fact FROM time.attendance_facts x
      WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id ORDER BY x.version DESC LIMIT 1) f ON true
    WHERE i.tenant_id=p_tenant AND i.employment_id=oldr.employment_id
      AND i.operational_date BETWEEN least(oldr.start_date,newr.start_date) AND greatest(oldr.end_date,newr.end_date)
      AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant
        AND ((d.request_id=oldr.id AND d.preview_version=oldr.approved_preview_version)
          OR (d.request_id=newr.id AND d.preview_version=newr.current_preview_version))
        AND d.leave_date=i.operational_date AND d.eligible AND d.units>0);
  IF conflicts IS NOT NULL THEN RAISE EXCEPTION 'leave_attendance_fact_conflict' USING ERRCODE='23514',DETAIL=conflicts::text; END IF;
  IF newr.is_half_day AND platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',pg_catalog.now())
    AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=newr.id
      AND d.preview_version=newr.current_preview_version AND d.is_half_day AND d.eligible
      AND d.halfday_mapping_state IS DISTINCT FROM 'mapped') THEN
    RAISE EXCEPTION 'leave_half_day_mapping_required' USING ERRCODE='23514'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant::text||oldr.employee_id::text,90429));
  PERFORM 1 FROM leave.accounts a JOIN leave.year_periods yp ON yp.tenant_id=a.tenant_id AND yp.id=a.year_period_id
    WHERE a.tenant_id=p_tenant AND a.employee_id=oldr.employee_id AND a.employer_entity_id=oldr.employer_entity_id
      AND ((a.leave_type_id=oldr.leave_type_id AND EXISTS(SELECT 1 FROM leave.request_consumptions c
          WHERE c.tenant_id=p_tenant AND c.request_id=oldr.id AND c.preview_version=oldr.approved_preview_version AND c.account_id=a.id))
        OR (a.leave_type_id=newr.leave_type_id AND yp.starts_on<=newr.end_date)) ORDER BY yp.starts_on,a.id FOR UPDATE OF a;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  corr:=pg_catalog.gen_random_uuid();
  INSERT INTO leave.request_corrections(tenant_id,id,original_request_id,replacement_request_id,employee_id,employment_id,
      employer_entity_id,original_from_version,original_to_version,original_approved_preview_version,
      replacement_from_version,replacement_to_version,replacement_preview_version,created_by,reason)
    VALUES(p_tenant,corr,oldr.id,newr.id,oldr.employee_id,oldr.employment_id,oldr.employer_entity_id,
      oldr.version,oldr.version+1,oldr.approved_preview_version,newr.version,newr.version+1,newr.current_preview_version,
      actor,pg_catalog.btrim(p_reason));
  FOR consumption_row IN SELECT c.*,l.source_version_id FROM leave.request_consumptions c JOIN leave.ledger_entries l
      ON l.tenant_id=c.tenant_id AND l.id=c.ledger_entry_id WHERE c.tenant_id=p_tenant
        AND c.request_id=oldr.id AND c.preview_version=oldr.approved_preview_version ORDER BY c.leave_date,c.account_id
  LOOP
    INSERT INTO leave.ledger_entries(tenant_id,account_id,leave_type_id,entry_kind,delta_days,source_version_id,
      source_reference,idempotency_key,reason,actor_user_id,reversal_of_entry_id,correction_id)
    VALUES(p_tenant,consumption_row.account_id,consumption_row.leave_type_id,'correction_reversal',consumption_row.units,consumption_row.source_version_id,
      'leave.correction:'||corr::text||':original:'||oldr.id::text,
      'leave:correct:'||corr::text||':reverse:'||consumption_row.ledger_entry_id::text,pg_catalog.btrim(p_reason),actor,consumption_row.ledger_entry_id,corr);
  END LOOP;
  FOR consumption_row IN SELECT * FROM leave.request_days x WHERE x.tenant_id=p_tenant AND x.request_id=newr.id
      AND x.preview_version=newr.current_preview_version ORDER BY x.leave_date
  LOOP
    IF NOT consumption_row.eligible OR consumption_row.units=0 OR consumption_row.balance_mode='untracked' THEN CONTINUE; END IF;
    need:=consumption_row.units;
    FOR ac IN SELECT a.id FROM leave.accounts a JOIN leave.year_periods yp ON yp.tenant_id=a.tenant_id AND yp.id=a.year_period_id
      WHERE a.tenant_id=p_tenant AND a.employee_id=newr.employee_id AND a.employer_entity_id=newr.employer_entity_id
        AND a.leave_type_id=newr.leave_type_id AND yp.starts_on<=consumption_row.leave_date ORDER BY yp.starts_on,a.id
    LOOP
      SELECT coalesce(pg_catalog.sum(l.delta_days),0) INTO bal FROM leave.ledger_entries l
        WHERE l.tenant_id=p_tenant AND l.account_id=ac.id;
      IF bal<0 THEN RAISE EXCEPTION 'leave_balance_invariant_violation' USING ERRCODE='23514'; END IF;
      take_units:=least(need,bal);
      IF take_units>0 THEN
        INSERT INTO leave.ledger_entries(tenant_id,account_id,leave_type_id,entry_kind,delta_days,source_version_id,
          source_reference,idempotency_key,reason,actor_user_id)
        VALUES(p_tenant,ac.id,newr.leave_type_id,'leave_consumption',-take_units,consumption_row.type_version_id,
          'leave.request:'||newr.id::text||':preview:'||newr.current_preview_version::text||':date:'||pg_catalog.to_char(consumption_row.leave_date,'YYYYMMDD'),
          'leave:consume:'||newr.id::text||':v'||newr.current_preview_version::text||':'||pg_catalog.to_char(consumption_row.leave_date,'YYYYMMDD')||':'||ac.id::text,
          pg_catalog.btrim(newr.reason),actor) RETURNING id INTO ledger_id;
        INSERT INTO leave.request_consumptions(tenant_id,request_id,preview_version,leave_date,leave_type_id,account_id,ledger_entry_id,units)
          VALUES(p_tenant,newr.id,newr.current_preview_version,consumption_row.leave_date,newr.leave_type_id,ac.id,ledger_id,take_units);
        need:=need-take_units;
      END IF; EXIT WHEN need=0;
    END LOOP;
    IF need>0 THEN RAISE EXCEPTION 'leave_balance_insufficient' USING ERRCODE='23514',
      DETAIL=pg_catalog.jsonb_build_object('date',consumption_row.leave_date,'required',consumption_row.units,'shortfall',need)::text; END IF;
  END LOOP;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  UPDATE leave.requests SET state='approved',version=version+1,approved_at=pg_catalog.transaction_timestamp(),
    approved_by=actor,approved_preview_version=newr.current_preview_version WHERE tenant_id=p_tenant AND id=newr.id;
  UPDATE leave.requests SET state='superseded',version=version+1,superseded_at=pg_catalog.transaction_timestamp()
    WHERE tenant_id=p_tenant AND id=oldr.id;
  result:=pg_catalog.jsonb_build_object('state','corrected','correction_id',corr,
    'original',leave.request_json(p_tenant,oldr.id,oldr.approved_preview_version),
    'replacement',leave.request_json(p_tenant,newr.id,newr.current_preview_version),
    'reversals',(SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',l.id,
      'reversal_of_entry_id',l.reversal_of_entry_id,'account_id',l.account_id,'units',l.delta_days)
      ORDER BY l.account_id,l.id),'[]'::jsonb) FROM leave.ledger_entries l WHERE l.tenant_id=p_tenant AND l.correction_id=corr));
  INSERT INTO leave.correction_events(tenant_id,correction_id,original_request_id,replacement_request_id,actor_user_id,
      event_key,from_state,to_state,original_from_version,original_to_version,replacement_from_version,replacement_to_version,
      reason,operation_key,payload_hash,result)
    VALUES(p_tenant,corr,oldr.id,newr.id,actor,'hr.corrected','approved','superseded',oldr.version,oldr.version+1,
      newr.version,newr.version+1,pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  -- All external command replay boundaries reserve this internal namespace.
  approval_key:='leave-internal:correction-approval:'||corr::text;
  INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
    from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,newr.id,actor,'hr.approved','submitted','approved',newr.version,newr.version+1,
    pg_catalog.btrim(p_reason),approval_key,payload_hash,result->'replacement');
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_correct_approved_request(uuid,uuid,integer,integer,uuid,integer,integer,text,text)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_correct_approved_request(uuid,uuid,integer,integer,uuid,integer,integer,text,text)
  TO authenticated;

-- Correction lineage is included by the existing detail helper without exposing
-- the private relation directly. Existing JSON keys and request-day/consumption
-- semantics remain unchanged.
CREATE OR REPLACE FUNCTION leave.request_json(p_tenant uuid,p_request uuid,p_preview integer DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
  SELECT pg_catalog.jsonb_build_object('id',r.id,'employee_id',r.employee_id,
    'employee_code',e.employee_code,'employee_name',e.full_name,'employment_id',r.employment_id,
    'employer_entity_id',r.employer_entity_id,'leave_type_id',r.leave_type_id,'leave_type_name',t.name,
    'start_date',r.start_date,'end_date',r.end_date,'total_units',p.total_units,
    'is_half_day',r.is_half_day,'half_day_part',r.half_day_part,'state',r.state,'version',r.version,
    'preview_version',p.preview_version,'request_source',r.request_source,'reason',r.reason,
    'owner_queue',r.owner_queue,'submitted_at',r.submitted_at,'created_at',r.created_at,
    'approved_at',r.approved_at,'approved_by',r.approved_by,'approved_preview_version',r.approved_preview_version,
    'cancelled_at',r.cancelled_at,'superseded_at',r.superseded_at,
    'correction_links',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'correction_id',c.id,'role',CASE WHEN c.original_request_id=r.id THEN 'original' ELSE 'replacement' END,
      'original_request_id',c.original_request_id,'replacement_request_id',c.replacement_request_id,
      'original_from_version',c.original_from_version,'original_to_version',c.original_to_version,
      'original_approved_preview_version',c.original_approved_preview_version,
      'replacement_from_version',c.replacement_from_version,'replacement_to_version',c.replacement_to_version,
      'replacement_preview_version',c.replacement_preview_version,'reason',c.reason,'created_by',c.created_by,'created_at',c.created_at)
      ORDER BY c.created_at,c.id) FROM leave.request_corrections c WHERE c.tenant_id=r.tenant_id
        AND (c.original_request_id=r.id OR c.replacement_request_id=r.id)),'[]'::jsonb),
    'days',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'date',d.leave_date,'year_period_id',d.year_period_id,'calendar_version_id',d.calendar_version_id,
      'type_version_id',d.type_version_id,'day_count_basis',d.day_count_basis,'pay_effect',d.pay_effect,
      'balance_mode',d.balance_mode,'is_weekly_rest',d.is_weekly_rest,'holiday_name',d.holiday_name,
      'eligible',d.eligible,'units',d.units,'is_half_day',d.is_half_day,'half_day_part',d.half_day_part,
       'halfday_mapping_state',d.halfday_mapping_state,'halfday_mapping_snapshot',d.halfday_mapping_snapshot,
       'halfday_policy_template_id',d.halfday_policy_template_id,'halfday_policy_version',d.halfday_policy_version,
       'halfday_algorithm_version',d.halfday_algorithm_version) ORDER BY d.leave_date)
      FROM leave.request_days d WHERE d.tenant_id=r.tenant_id AND d.request_id=r.id
        AND d.preview_version=p.preview_version),'[]'::jsonb),
    'consumptions',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'date',c.leave_date,'account_id',c.account_id,'ledger_entry_id',c.ledger_entry_id,
      'units',c.units,'period_starts_on',yp.starts_on) ORDER BY c.leave_date,yp.starts_on,c.account_id)
      FROM leave.request_consumptions c JOIN leave.accounts a ON a.tenant_id=c.tenant_id AND a.id=c.account_id
      JOIN leave.year_periods yp ON yp.tenant_id=a.tenant_id AND yp.id=a.year_period_id
      WHERE c.tenant_id=r.tenant_id AND c.request_id=r.id AND c.preview_version=r.approved_preview_version),'[]'::jsonb))
  FROM leave.requests r JOIN people.employees e ON e.tenant_id=r.tenant_id AND e.id=r.employee_id
  JOIN leave.types t ON t.tenant_id=r.tenant_id AND t.id=r.leave_type_id
  JOIN leave.request_previews p ON p.tenant_id=r.tenant_id AND p.request_id=r.id
    AND p.preview_version=coalesce(p_preview,r.current_preview_version)
  WHERE r.tenant_id=p_tenant AND r.id=p_request
$f$;
REVOKE ALL ON FUNCTION leave.request_json(uuid,uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

-- The payroll projection preserves the original approved-day identity and adds
-- a correction link. Superseded quantities are retained but never effective.
CREATE OR REPLACE FUNCTION public.leave_payroll_facts(
  p_tenant uuid,p_employer uuid,p_from date,p_to date,
  p_after_date date DEFAULT NULL,p_after_request_id uuid DEFAULT NULL,p_limit integer DEFAULT 50
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); read_permission text; lim integer:=p_limit;
  items jsonb; more boolean; next_date date; next_request uuid;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_employer IS NULL OR p_from IS NULL OR p_to IS NULL
    OR p_to<p_from OR p_to-p_from>30 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR ((p_after_date IS NULL)<>(p_after_request_id IS NULL))
    OR (p_after_date IS NOT NULL AND (p_after_date<p_from OR p_after_date>p_to)) THEN
    RAISE EXCEPTION 'leave_payroll_facts_input_invalid' USING ERRCODE='22023'; END IF;
  read_permission:=CASE WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.view') THEN 'leave.view'
    WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.manage') THEN 'leave.manage'
    WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.approve') THEN 'leave.approve' ELSE 'leave.view' END;
  actor:=leave.authorized(p_tenant,read_permission,false);
  IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=p_tenant AND e.id=p_employer)
    THEN RAISE EXCEPTION 'leave_payroll_facts_unavailable' USING ERRCODE='P0002'; END IF;
  WITH page AS MATERIALIZED (
    SELECT r.tenant_id,r.id request_id,r.employee_id,r.employment_id,r.employer_entity_id,r.leave_type_id,
      r.state request_state,r.version request_version,r.approved_preview_version,r.approved_by,r.approved_at,
      r.cancelled_at,r.superseded_at,d.leave_date,d.year_period_id,d.calendar_version_id,d.type_version_id,
      d.day_count_basis,d.pay_effect,d.balance_mode,d.is_weekly_rest,d.holiday_name,d.eligible,
      d.units original_units,d.is_half_day,ce.id cancellation_event_id,ce.cancellation_id,ce.event_key cancellation_event_key,
      ce.reason cancellation_reason,coalesce(ce.time_reconciliation_required,false) time_reconciliation_required,
      corr.correction_id,corr.original_request_id,corr.replacement_request_id,corr.reason correction_reason,
      corr.created_by correction_actor,corr.created_at correction_created_at,
      corr.original_from_version,corr.original_to_version,corr.original_approved_preview_version,
      corr.replacement_from_version,corr.replacement_to_version,corr.replacement_preview_version,incoming.links incoming_correction_links,
      CASE WHEN r.id=corr.original_request_id THEN corr.replacement_request_id ELSE corr.original_request_id END linked_request_id,
      (SELECT ev.id FROM leave.correction_events ev WHERE ev.tenant_id=corr.tenant_id AND ev.correction_id=corr.correction_id
        ORDER BY ev.id DESC LIMIT 1) correction_event_id
    FROM leave.request_days d JOIN leave.requests r ON r.tenant_id=d.tenant_id AND r.id=d.request_id
      AND d.preview_version=r.approved_preview_version
    LEFT JOIN LATERAL (SELECT x.id,x.cancellation_id,x.event_key,x.reason,x.time_reconciliation_required
      FROM leave.cancellation_events x WHERE x.tenant_id=r.tenant_id AND x.request_id=r.id
        AND ((x.event_key='hr.accepted' AND x.to_state='accepted') OR (x.event_key='hr.direct_cancelled' AND x.to_state='cancelled'))
      ORDER BY x.id DESC LIMIT 1) ce ON true
    LEFT JOIN LATERAL (SELECT c.tenant_id,c.id correction_id,c.original_request_id,c.replacement_request_id,c.reason,c.created_by,c.created_at,
        c.original_from_version,c.original_to_version,c.original_approved_preview_version,
        c.replacement_from_version,c.replacement_to_version,c.replacement_preview_version
      FROM leave.request_corrections c WHERE c.tenant_id=r.tenant_id
        AND (c.original_request_id=r.id OR c.replacement_request_id=r.id)
       ORDER BY (c.original_request_id=r.id) DESC,c.created_at DESC,c.id DESC LIMIT 1) corr ON true
    LEFT JOIN LATERAL (SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'correction_id',c.id,'original_request_id',c.original_request_id,'replacement_request_id',c.replacement_request_id,
        'original_from_version',c.original_from_version,'original_to_version',c.original_to_version,
        'original_approved_preview_version',c.original_approved_preview_version,
        'replacement_from_version',c.replacement_from_version,'replacement_to_version',c.replacement_to_version,
        'replacement_preview_version',c.replacement_preview_version,'reason',c.reason,
        'actor_user_id',c.created_by,'created_at',c.created_at) ORDER BY c.created_at,c.id),'[]'::jsonb) links
      FROM leave.request_corrections c WHERE c.tenant_id=r.tenant_id AND c.replacement_request_id=r.id) incoming ON true
    WHERE d.tenant_id=p_tenant AND r.employer_entity_id=p_employer AND d.employer_entity_id=p_employer
      AND d.leave_date BETWEEN p_from AND p_to AND r.state IN ('approved','cancelled','superseded')
      AND r.approved_preview_version IS NOT NULL
      AND (p_after_date IS NULL OR (d.leave_date,r.id)>(p_after_date,p_after_request_id))
    ORDER BY d.leave_date,r.id LIMIT lim+1
  ), enriched AS MATERIALIZED (
    SELECT p.*,CASE WHEN p.request_state IN ('cancelled','superseded') THEN 0::numeric ELSE p.original_units END effective_units,
      coalesce(a.reversal_links,'[]'::jsonb) reversal_links,coalesce(a.correction_reversal_links,'[]'::jsonb) correction_reversal_links,
      pg_catalog.jsonb_build_object('source_key',p.request_id::text||':'||p.approved_preview_version::text||':'||pg_catalog.to_char(p.leave_date,'YYYYMMDD'),
        'source_kind','leave.approved_day','tenant_id',p.tenant_id,'request_id',p.request_id,'leave_date',p.leave_date,
        'employee_id',p.employee_id,'employment_id',p.employment_id,'employer_entity_id',p.employer_entity_id,
        'leave_type_id',p.leave_type_id,'type_version_id',p.type_version_id,'calendar_version_id',p.calendar_version_id,
        'year_period_id',p.year_period_id,'request_version',p.request_version,'approved_preview_version',p.approved_preview_version,
        'approved_by',p.approved_by,'approved_at',p.approved_at,'request_state',p.request_state,
        'cancelled_at',p.cancelled_at,'superseded_at',p.superseded_at,'day_count_basis',p.day_count_basis,
        'pay_effect',p.pay_effect,'balance_mode',p.balance_mode,'eligible',p.eligible,
        'is_weekly_rest',p.is_weekly_rest,'holiday_name',p.holiday_name,'is_half_day',p.is_half_day,
        'original_units',p.original_units,'effective_units',CASE WHEN p.request_state IN ('cancelled','superseded') THEN 0::numeric ELSE p.original_units END,
        'cancellation_event_id',p.cancellation_event_id,'cancellation_id',p.cancellation_id,
        'cancellation_event_key',p.cancellation_event_key,'cancellation_reason',p.cancellation_reason,
        'time_reconciliation_required',p.time_reconciliation_required,'reversal_links',coalesce(a.reversal_links,'[]'::jsonb))||pg_catalog.jsonb_build_object(
        'correction_id',p.correction_id,'original_request_id',p.original_request_id,
        'replacement_request_id',p.replacement_request_id,'linked_request_id',p.linked_request_id,
        'correction_event_id',p.correction_event_id,'correction_reason',p.correction_reason,
        'incoming_correction_links',p.incoming_correction_links,
        'correction_actor',p.correction_actor,'correction_created_at',p.correction_created_at,
        'correction_event_key',CASE WHEN p.correction_id IS NULL THEN NULL ELSE 'hr.corrected' END,
        'original_from_version',p.original_from_version,'original_to_version',p.original_to_version,
        'original_approved_preview_version',p.original_approved_preview_version,
        'replacement_from_version',p.replacement_from_version,'replacement_to_version',p.replacement_to_version,
        'replacement_preview_version',p.replacement_preview_version,
        'correction_reversal_links',coalesce(a.correction_reversal_links,'[]'::jsonb),
        'projection_only',true,'consumed_by_payroll',false) source_payload
    FROM page p LEFT JOIN LATERAL (
      SELECT coalesce(jsonb_agg(jsonb_build_object('account_id',c.account_id,'leave_type_id',c.leave_type_id,
        'consumed_ledger_entry_id',c.ledger_entry_id,'consumed_units',c.units,
        'reversal_entry_ids',coalesce(rv.entry_ids,'[]'::jsonb),'reversed_units',coalesce(rv.units,0::numeric))
        ORDER BY c.account_id,c.ledger_entry_id),'[]'::jsonb) reversal_links,
        coalesce(jsonb_agg(jsonb_build_object('account_id',c.account_id,'consumed_ledger_entry_id',c.ledger_entry_id,
          'reversal_entry_ids',coalesce(cr.entry_ids,'[]'::jsonb),'reversed_units',coalesce(cr.units,0::numeric))
          ORDER BY c.account_id,c.ledger_entry_id),'[]'::jsonb) correction_reversal_links
      FROM leave.request_consumptions c
      LEFT JOIN LATERAL (SELECT coalesce(jsonb_agg(l.id ORDER BY l.id),'[]'::jsonb) entry_ids,
          coalesce(sum(l.delta_days),0::numeric) units FROM leave.ledger_entries l
        WHERE l.tenant_id=c.tenant_id AND l.account_id=c.account_id AND l.entry_kind='cancellation_reversal'
          AND l.reversal_of_entry_id=c.ledger_entry_id) rv ON true
      LEFT JOIN LATERAL (SELECT coalesce(jsonb_agg(l.id ORDER BY l.id),'[]'::jsonb) entry_ids,
          coalesce(sum(l.delta_days),0::numeric) units FROM leave.ledger_entries l
        WHERE l.tenant_id=c.tenant_id AND l.account_id=c.account_id AND l.entry_kind='correction_reversal'
          AND l.reversal_of_entry_id=c.ledger_entry_id) cr ON true
      WHERE c.tenant_id=p.tenant_id AND c.request_id=p.request_id
        AND c.preview_version=p.approved_preview_version AND c.leave_date=p.leave_date) a ON true
  ), versioned AS MATERIALIZED (
    SELECT x.*,pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(x.source_payload::text,'UTF8')),'hex') source_version_hash,
      pg_catalog.row_number() OVER(ORDER BY x.leave_date,x.request_id) rn FROM enriched x
  )
  SELECT coalesce(pg_catalog.jsonb_agg(source_payload||pg_catalog.jsonb_build_object(
      'source_version',request_version,'source_version_hash',source_version_hash) ORDER BY rn) FILTER(WHERE rn<=lim),'[]'::jsonb),
    EXISTS(SELECT 1 FROM versioned WHERE rn>lim),(SELECT leave_date FROM versioned WHERE rn=lim),
    (SELECT request_id FROM versioned WHERE rn=lim) INTO items,more,next_date,next_request FROM versioned;
  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'has_more',more,
    'next_after_date',CASE WHEN more THEN next_date END,'next_after_request_id',CASE WHEN more THEN next_request END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_payroll_facts(uuid,uuid,date,date,date,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_payroll_facts(uuid,uuid,date,date,date,uuid,integer) TO authenticated;
