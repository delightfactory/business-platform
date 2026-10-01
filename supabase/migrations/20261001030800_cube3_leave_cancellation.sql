-- Slice 3B2: request/review cancellation, exact ledger reversal, and authorized HR close.
-- Time facts are never changed here; captured facts require a separate Time reconciliation.

ALTER TABLE leave.ledger_entries
  ADD COLUMN reversal_of_entry_id uuid;
ALTER TABLE leave.ledger_entries
  ADD CONSTRAINT leave_ledger_reversal_entry_fk
  FOREIGN KEY (tenant_id,account_id,reversal_of_entry_id)
  REFERENCES leave.ledger_entries(tenant_id,account_id,id) ON DELETE RESTRICT;
ALTER TABLE leave.ledger_entries DROP CONSTRAINT ledger_entries_entry_kind_check;
ALTER TABLE leave.ledger_entries ADD CONSTRAINT ledger_entries_entry_kind_check
  CHECK (entry_kind IN ('opening','annual_grant','adjustment','leave_consumption','cancellation_reversal'));
ALTER TABLE leave.ledger_entries DROP CONSTRAINT ledger_entries_check;
ALTER TABLE leave.ledger_entries ADD CONSTRAINT ledger_entries_check CHECK (
  delta_days<>0 AND (
    (entry_kind IN ('opening','annual_grant') AND delta_days>0)
    OR entry_kind='adjustment'
    OR (entry_kind='leave_consumption' AND delta_days<0 AND reversal_of_entry_id IS NULL)
    OR (entry_kind='cancellation_reversal' AND delta_days>0 AND reversal_of_entry_id IS NOT NULL)
  )
);
CREATE UNIQUE INDEX leave_ledger_one_cancellation_reversal
  ON leave.ledger_entries(tenant_id,reversal_of_entry_id)
  WHERE entry_kind='cancellation_reversal';

CREATE TABLE leave.cancellation_requests (
  tenant_id uuid NOT NULL,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  request_id uuid NOT NULL,
  requested_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  requester_kind text NOT NULL CHECK (requester_kind IN ('employee','hr')),
  requested_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  reason text NOT NULL CHECK (length(pg_catalog.btrim(reason)) BETWEEN 3 AND 500),
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','accepted','rejected')),
  version integer NOT NULL DEFAULT 1 CHECK (version>0),
  decided_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  decided_at timestamptz,
  decision_reason text CHECK (decision_reason IS NULL OR length(pg_catalog.btrim(decision_reason)) BETWEEN 3 AND 500),
  PRIMARY KEY (tenant_id,id),
  UNIQUE (tenant_id,id,request_id),
  FOREIGN KEY (tenant_id,request_id) REFERENCES leave.requests(tenant_id,id) ON DELETE RESTRICT,
  CHECK (
    (state='pending' AND decided_by IS NULL AND decided_at IS NULL AND decision_reason IS NULL)
    OR (state IN ('accepted','rejected') AND decided_by IS NOT NULL AND decided_at IS NOT NULL
      AND decision_reason IS NOT NULL)
  )
);
CREATE UNIQUE INDEX leave_one_pending_cancellation_per_request
  ON leave.cancellation_requests(tenant_id,request_id) WHERE state='pending';
CREATE INDEX leave_cancellation_queue
  ON leave.cancellation_requests(tenant_id,requested_at,id) WHERE state='pending';
ALTER TABLE leave.cancellation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE leave.cancellation_requests FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE leave.cancellation_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  request_id uuid NOT NULL,
  cancellation_id uuid,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN (
    'employee.requested','hr.requested','hr.accepted','hr.rejected','hr.direct_cancelled')),
  from_state text,
  to_state text NOT NULL CHECK (to_state IN ('pending','accepted','rejected','cancelled')),
  from_version integer,
  to_version integer NOT NULL CHECK (to_version>0),
  reason text NOT NULL CHECK (length(pg_catalog.btrim(reason)) BETWEEN 3 AND 500),
  operation_key text NOT NULL CHECK (length(pg_catalog.btrim(operation_key)) BETWEEN 1 AND 120),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  result jsonb NOT NULL,
  time_reconciliation_required boolean NOT NULL DEFAULT false,
  time_fact_refs jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (pg_catalog.jsonb_typeof(time_fact_refs)='array'),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,request_id) REFERENCES leave.requests(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,cancellation_id,request_id)
    REFERENCES leave.cancellation_requests(tenant_id,id,request_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id,actor_user_id,operation_key),
  CHECK ((event_key IN ('employee.requested','hr.requested') AND to_state='pending' AND cancellation_id IS NOT NULL)
      OR (event_key='hr.accepted' AND to_state='accepted' AND cancellation_id IS NOT NULL)
      OR (event_key='hr.rejected' AND to_state='rejected' AND cancellation_id IS NOT NULL)
      OR (event_key='hr.direct_cancelled' AND to_state='cancelled' AND cancellation_id IS NULL)),
  CHECK (NOT time_reconciliation_required OR pg_catalog.jsonb_array_length(time_fact_refs)>0)
);
CREATE INDEX leave_cancellation_events_request ON leave.cancellation_events(tenant_id,request_id,id);
ALTER TABLE leave.cancellation_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE leave.cancellation_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE leave.cancellation_events_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_cancellation_events_append_only BEFORE UPDATE OR DELETE ON leave.cancellation_events
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();

CREATE FUNCTION leave.guard_cancellation_transition() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'leave_cancellation_append_only' USING ERRCODE='55000'; END IF;
  IF ROW(NEW.tenant_id,NEW.id,NEW.request_id,NEW.requested_by,NEW.requester_kind,NEW.requested_at,NEW.reason)
      IS DISTINCT FROM
     ROW(OLD.tenant_id,OLD.id,OLD.request_id,OLD.requested_by,OLD.requester_kind,OLD.requested_at,OLD.reason)
     OR OLD.state<>'pending' OR NEW.state NOT IN ('accepted','rejected')
     OR NEW.version<>OLD.version+1 OR NEW.decided_by IS NULL OR NEW.decided_at IS NULL
     OR length(pg_catalog.btrim(coalesce(NEW.decision_reason,''))) NOT BETWEEN 3 AND 500 THEN
    RAISE EXCEPTION 'leave_cancellation_transition_invalid' USING ERRCODE='55000';
  END IF;
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION leave.guard_cancellation_transition() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_cancellation_transition_guard BEFORE UPDATE OR DELETE ON leave.cancellation_requests
  FOR EACH ROW EXECUTE FUNCTION leave.guard_cancellation_transition();

CREATE FUNCTION leave.guard_cancellation_reversal() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE original leave.ledger_entries%ROWTYPE; allocation leave.request_consumptions%ROWTYPE;
BEGIN
  IF NEW.entry_kind<>'cancellation_reversal' THEN
    IF NEW.reversal_of_entry_id IS NOT NULL THEN
      RAISE EXCEPTION 'leave_reversal_reference_invalid' USING ERRCODE='23514';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.reversal_of_entry_id IS NULL THEN
    RAISE EXCEPTION 'leave_reversal_reference_required' USING ERRCODE='23514';
  END IF;
  SELECT * INTO original FROM leave.ledger_entries x
    WHERE x.tenant_id=NEW.tenant_id AND x.account_id=NEW.account_id AND x.id=NEW.reversal_of_entry_id;
  IF NOT FOUND OR original.entry_kind<>'leave_consumption' OR original.delta_days>=0
     OR original.leave_type_id<>NEW.leave_type_id OR NEW.delta_days<>-original.delta_days THEN
    RAISE EXCEPTION 'leave_reversal_must_exactly_match_consumption' USING ERRCODE='23514';
  END IF;
  SELECT * INTO allocation FROM leave.request_consumptions c
    WHERE c.tenant_id=NEW.tenant_id AND c.ledger_entry_id=original.id
      AND c.account_id=original.account_id AND c.leave_type_id=original.leave_type_id;
  IF NOT FOUND OR NEW.delta_days<>allocation.units THEN
    RAISE EXCEPTION 'leave_reversal_allocation_unavailable' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION leave.guard_cancellation_reversal() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_cancellation_reversal_guard BEFORE INSERT ON leave.ledger_entries
  FOR EACH ROW EXECUTE FUNCTION leave.guard_cancellation_reversal();

-- All mutators serialize on the approved parent before the optional cancellation
-- header and then the original accounts. Employee NO KEY UPDATE preserves the
-- Attendance FK KEY SHARE insert path used by WorkInstance creation.
CREATE FUNCTION leave.lock_cancellation_parent(p_tenant uuid,p_request uuid)
RETURNS leave.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE initial leave.requests%ROWTYPE; locked leave.requests%ROWTYPE; employment people.employments%ROWTYPE;
BEGIN
  SELECT * INTO initial FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=initial.employee_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  SELECT * INTO employment FROM people.employments e
    WHERE e.tenant_id=p_tenant AND e.id=initial.employment_id AND e.employee_id=initial.employee_id FOR UPDATE;
  IF NOT FOUND OR employment.employer_entity_id<>initial.employer_entity_id THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  PERFORM 1 FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.id=initial.employer_entity_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM leave.lock_request_configuration(p_tenant,initial.employer_entity_id,initial.leave_type_id,
    initial.start_date,initial.end_date);
  SELECT * INTO locked FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id=p_request FOR UPDATE;
  IF NOT FOUND OR ROW(locked.employee_id,locked.employment_id,locked.employer_entity_id,locked.leave_type_id,
      locked.start_date,locked.end_date,locked.approved_preview_version)
      IS DISTINCT FROM
     ROW(initial.employee_id,initial.employment_id,initial.employer_entity_id,initial.leave_type_id,
      initial.start_date,initial.end_date,initial.approved_preview_version) THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  RETURN locked;
END $f$;
REVOKE ALL ON FUNCTION leave.lock_cancellation_parent(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.cancellation_json(p_tenant uuid,p_cancellation uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
  SELECT pg_catalog.jsonb_build_object('id',c.id,'request_id',c.request_id,'requested_by',c.requested_by,
    'requester_kind',c.requester_kind,'requested_at',c.requested_at,'reason',c.reason,
    'state',c.state,'version',c.version,'decided_by',c.decided_by,'decided_at',c.decided_at,
    'decision_reason',c.decision_reason)
  FROM leave.cancellation_requests c WHERE c.tenant_id=p_tenant AND c.id=p_cancellation
$f$;
REVOKE ALL ON FUNCTION leave.cancellation_json(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.cancellation_replay(p_tenant uuid,p_actor uuid,p_key text,p_action text,p_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE old leave.cancellation_events%ROWTYPE; request_replay jsonb;
BEGIN
  SELECT * INTO old FROM leave.cancellation_events e WHERE e.tenant_id=p_tenant
    AND e.actor_user_id=p_actor AND e.operation_key=p_key;
  IF FOUND THEN
    IF old.event_key IS DISTINCT FROM p_action OR old.payload_hash IS DISTINCT FROM p_hash THEN
      RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505';
    END IF;
    RETURN old.result;
  END IF;
  request_replay:=leave.request_replay(p_tenant,p_actor,p_key,p_action,p_hash);
  IF request_replay IS NOT NULL THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505';
  END IF;
  RETURN NULL;
END $f$;
REVOKE ALL ON FUNCTION leave.cancellation_replay(uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

-- Extend request operation-key checks so a key cannot be independently reused
-- across the already-existing request events and this cancellation event stream.
CREATE OR REPLACE FUNCTION leave.request_replay(p_tenant uuid,p_actor uuid,p_key text,p_action text,p_hash text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE old leave.request_events%ROWTYPE;
BEGIN
  IF EXISTS(SELECT 1 FROM leave.cancellation_events e WHERE e.tenant_id=p_tenant
      AND e.actor_user_id=p_actor AND e.operation_key=p_key) THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505';
  END IF;
  SELECT * INTO old FROM leave.request_events e WHERE e.tenant_id=p_tenant
    AND e.actor_user_id=p_actor AND e.operation_key=p_key;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF old.event_key IS DISTINCT FROM p_action OR old.payload_hash IS DISTINCT FROM p_hash THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505';
  END IF;
  RETURN old.result;
END $f$;
REVOKE ALL ON FUNCTION leave.request_replay(uuid,uuid,text,text,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION leave.guard_request_transition() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE is_refresh boolean; is_approval boolean; is_terminal boolean; is_cancellation boolean;
BEGIN
  IF ROW(NEW.tenant_id,NEW.id,NEW.employee_id,NEW.employment_id,NEW.employer_entity_id,
     NEW.leave_type_id,NEW.start_date,NEW.end_date,NEW.is_half_day,NEW.request_source,
     NEW.created_by,NEW.submitted_by,NEW.submitted_at,NEW.reason,NEW.owner_queue,
     NEW.owner_user_id,NEW.created_at)
    IS DISTINCT FROM
    ROW(OLD.tenant_id,OLD.id,OLD.employee_id,OLD.employment_id,OLD.employer_entity_id,
     OLD.leave_type_id,OLD.start_date,OLD.end_date,OLD.is_half_day,OLD.request_source,
     OLD.created_by,OLD.submitted_by,OLD.submitted_at,OLD.reason,OLD.owner_queue,
     OLD.owner_user_id,OLD.created_at)
    OR NEW.version<>OLD.version+1 THEN
    RAISE EXCEPTION 'leave_request_transition_invalid' USING ERRCODE='55000';
  END IF;
  is_refresh:=OLD.state='submitted' AND NEW.state='submitted'
    AND NEW.current_preview_version=OLD.current_preview_version+1
    AND NEW.approved_at IS NOT DISTINCT FROM OLD.approved_at
    AND NEW.approved_by IS NOT DISTINCT FROM OLD.approved_by
    AND NEW.approved_preview_version IS NOT DISTINCT FROM OLD.approved_preview_version
    AND NEW.cancelled_at IS NOT DISTINCT FROM OLD.cancelled_at;
  is_approval:=OLD.state='submitted' AND NEW.state='approved'
    AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NOT NULL AND NEW.approved_by IS NOT NULL
    AND NEW.approved_preview_version=NEW.current_preview_version AND NEW.cancelled_at IS NULL;
  is_terminal:=OLD.state='submitted' AND NEW.state IN ('withdrawn','rejected')
    AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NULL AND NEW.approved_by IS NULL
    AND NEW.approved_preview_version IS NULL AND NEW.cancelled_at IS NULL;
  is_cancellation:=OLD.state='approved' AND NEW.state='cancelled'
    AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NOT DISTINCT FROM OLD.approved_at
    AND NEW.approved_by IS NOT DISTINCT FROM OLD.approved_by
    AND NEW.approved_preview_version IS NOT DISTINCT FROM OLD.approved_preview_version
    AND NEW.cancelled_at IS NOT NULL;
  IF NOT (is_refresh OR is_approval OR is_terminal OR is_cancellation) THEN
    RAISE EXCEPTION 'leave_request_transition_invalid' USING ERRCODE='55000';
  END IF;
  NEW.updated_at:=pg_catalog.transaction_timestamp();
  RETURN NEW;
END $f$;

ALTER TABLE leave.request_events DROP CONSTRAINT request_events_event_key_check;
ALTER TABLE leave.request_events ADD CONSTRAINT request_events_event_key_check CHECK (
  event_key IN ('employee.submitted','hr.recorded_submitted','employee.withdrawn','hr.rejected',
    'hr.approved','request.preview_refreshed','hr.cancellation_accepted','hr.direct_cancelled'));
ALTER TABLE leave.request_events DROP CONSTRAINT request_events_to_state_check;
ALTER TABLE leave.request_events ADD CONSTRAINT request_events_to_state_check
  CHECK (to_state IN ('submitted','approved','withdrawn','rejected','cancelled'));

CREATE FUNCTION leave.request_cancellation_internal(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reason text,p_idempotency_key text,p_employee_only boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; current_employee uuid;
  employee_request boolean; payload jsonb; payload_hash text; replay jsonb;
  cancellation_id uuid; result jsonb;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_request IS NULL OR p_expected_version IS NULL OR p_expected_version<=0
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_cancellation_input_invalid' USING ERRCODE='22023';
  END IF;
  employee_request:=p_employee_only;
  IF employee_request THEN
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_forbidden' USING ERRCODE='42501';
    END IF;
  ELSE
    actor:=leave.authorized(p_tenant,'leave.manage',false);
  END IF;
  r:=leave.lock_cancellation_parent(p_tenant,p_request);
  IF employee_request THEN
    SELECT l.employee_id INTO current_employee FROM people.employee_user_links l
      WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
    IF current_employee IS DISTINCT FROM r.employee_id
       OR NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
  ELSE
    actor:=leave.authorized(p_tenant,'leave.manage',false);
  END IF;
  actor:=CASE WHEN employee_request THEN actor ELSE leave.authorized(p_tenant,'leave.manage',false) END;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  payload:=pg_catalog.jsonb_build_object('action',CASE WHEN employee_request THEN 'employee.requested' ELSE 'hr.requested' END,
    'tenant',p_tenant,'request',p_request,'version',p_expected_version,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  replay:=leave.cancellation_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),
    payload->>'action',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  PERFORM leave.request_assert_queue(p_tenant);
  IF r.state<>'approved' THEN RAISE EXCEPTION 'leave_cancellation_request_unavailable' USING ERRCODE='23514'; END IF;
  IF r.version<>p_expected_version THEN RAISE EXCEPTION 'leave_request_version_conflict' USING ERRCODE='40001'; END IF;
  IF EXISTS(SELECT 1 FROM leave.cancellation_requests c WHERE c.tenant_id=p_tenant
      AND c.request_id=p_request AND c.state='pending') THEN
    RAISE EXCEPTION 'leave_cancellation_pending' USING ERRCODE='23514';
  END IF;
  INSERT INTO leave.cancellation_requests(tenant_id,request_id,requested_by,requester_kind,reason)
  VALUES(p_tenant,p_request,actor,CASE WHEN employee_request THEN 'employee' ELSE 'hr' END,pg_catalog.btrim(p_reason))
  RETURNING id INTO cancellation_id;
  result:=pg_catalog.jsonb_build_object('state','pending','cancellation',leave.cancellation_json(p_tenant,cancellation_id),
    'request',leave.request_json(p_tenant,p_request));
  INSERT INTO leave.cancellation_events(tenant_id,request_id,cancellation_id,actor_user_id,event_key,
    from_state,to_state,from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,p_request,cancellation_id,actor,payload->>'action',NULL,'pending',NULL,1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION leave.request_cancellation_internal(uuid,uuid,integer,text,text,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_request_cancellation(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
  SELECT leave.request_cancellation_internal(p_tenant,p_request,p_expected_version,p_reason,p_idempotency_key,false)
$f$;
REVOKE ALL ON FUNCTION public.leave_request_cancellation(uuid,uuid,integer,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_request_cancellation(uuid,uuid,integer,text,text) TO authenticated;

CREATE FUNCTION public.leave_my_request_cancellation(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
  SELECT leave.request_cancellation_internal(p_tenant,p_request,p_expected_version,p_reason,p_idempotency_key,true)
$f$;
REVOKE ALL ON FUNCTION public.leave_my_request_cancellation(uuid,uuid,integer,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_request_cancellation(uuid,uuid,integer,text,text) TO authenticated;
CREATE FUNCTION leave.capture_cancellation_time_facts(p_tenant uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE r leave.requests%ROWTYPE; refs jsonb;
BEGIN
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  PERFORM 1 FROM time.work_instances i WHERE i.tenant_id=p_tenant AND i.employment_id=r.employment_id
    AND i.operational_date BETWEEN r.start_date AND r.end_date
    AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id
      AND d.preview_version=r.approved_preview_version AND d.leave_date=i.operational_date AND d.eligible AND d.units>0)
    ORDER BY i.operational_date,i.id FOR NO KEY UPDATE;
  SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'work_instance_id',i.id,'operational_date',i.operational_date,
      'attendance_fact_id',latest.id,'attendance_fact_version',latest.version,
      'outcome',latest.fact->>'outcome') ORDER BY i.operational_date,i.id),'[]'::jsonb)
    INTO refs
  FROM time.work_instances i
  JOIN LATERAL (SELECT f.id,f.version,f.fact FROM time.attendance_facts f
    WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id
    ORDER BY f.version DESC LIMIT 1) latest ON true
  WHERE i.tenant_id=p_tenant AND i.employment_id=r.employment_id
    AND i.operational_date BETWEEN r.start_date AND r.end_date
    AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id
      AND d.preview_version=r.approved_preview_version AND d.leave_date=i.operational_date AND d.eligible AND d.units>0);
  RETURN refs;
END $f$;
REVOKE ALL ON FUNCTION leave.capture_cancellation_time_facts(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.reverse_request_consumptions(p_tenant uuid,p_request uuid,
  p_actor uuid,p_reason text) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE c record; inserted integer:=0; balance_now numeric;
BEGIN
  -- Match Leave's established balance-writer advisory key and lock all allocated
  -- accounts before any ledger read or append.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||(SELECT r.employee_id::text FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.id=p_request),90429));
  PERFORM 1 FROM leave.accounts a JOIN (
      SELECT DISTINCT x.account_id,yp.starts_on FROM leave.request_consumptions x
      JOIN leave.accounts ax ON ax.tenant_id=x.tenant_id AND ax.id=x.account_id
      JOIN leave.year_periods yp ON yp.tenant_id=ax.tenant_id AND yp.id=ax.year_period_id
      JOIN leave.requests r ON r.tenant_id=x.tenant_id AND r.id=x.request_id
      WHERE x.tenant_id=p_tenant AND x.request_id=p_request AND x.preview_version=r.approved_preview_version
    ) allocated ON allocated.account_id=a.id
    WHERE a.tenant_id=p_tenant ORDER BY allocated.starts_on,a.id FOR UPDATE OF a;
  FOR c IN SELECT x.leave_date,x.leave_type_id,x.account_id,x.ledger_entry_id,x.units,
        le.source_version_id,yp.starts_on
      FROM leave.request_consumptions x
      JOIN leave.ledger_entries le ON le.tenant_id=x.tenant_id AND le.account_id=x.account_id AND le.id=x.ledger_entry_id
      JOIN leave.accounts a ON a.tenant_id=x.tenant_id AND a.id=x.account_id
      JOIN leave.year_periods yp ON yp.tenant_id=a.tenant_id AND yp.id=a.year_period_id
      JOIN leave.requests r ON r.tenant_id=x.tenant_id AND r.id=x.request_id
      WHERE x.tenant_id=p_tenant AND x.request_id=p_request AND x.preview_version=r.approved_preview_version
      ORDER BY x.leave_date,yp.starts_on,x.account_id
  LOOP
    IF c.units<>-(SELECT le.delta_days FROM leave.ledger_entries le
        WHERE le.tenant_id=p_tenant AND le.account_id=c.account_id AND le.id=c.ledger_entry_id)
       OR EXISTS(SELECT 1 FROM leave.ledger_entries rev WHERE rev.tenant_id=p_tenant
         AND rev.reversal_of_entry_id=c.ledger_entry_id AND rev.entry_kind='cancellation_reversal') THEN
      RAISE EXCEPTION 'leave_cancellation_reversal_invariant' USING ERRCODE='23514';
    END IF;
    INSERT INTO leave.ledger_entries(tenant_id,account_id,leave_type_id,entry_kind,delta_days,
      source_version_id,source_reference,idempotency_key,reason,actor_user_id,reversal_of_entry_id)
    VALUES(p_tenant,c.account_id,c.leave_type_id,'cancellation_reversal',c.units,c.source_version_id,
      'leave.cancellation:'||p_request::text||':consumption:'||c.ledger_entry_id::text,
      'leave:cancel:'||p_request::text||':'||c.ledger_entry_id::text,
      pg_catalog.btrim(p_reason),p_actor,c.ledger_entry_id);
    inserted:=inserted+1;
  END LOOP;
  RETURN inserted;
END $f$;
REVOKE ALL ON FUNCTION leave.reverse_request_consumptions(uuid,uuid,uuid,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_decide_cancellation(
  p_tenant uuid,p_cancellation uuid,p_expected_version integer,p_decision text,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); c leave.cancellation_requests%ROWTYPE; r leave.requests%ROWTYPE;
  payload jsonb; payload_hash text; replay jsonb; refs jsonb:='[]'::jsonb; result jsonb; reversal_count integer:=0;
  new_state text; event_key text;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_cancellation IS NULL OR p_expected_version IS NULL OR p_expected_version<=0
    OR p_decision IS NULL OR p_decision NOT IN ('accept','reject')
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_cancellation_decision_input_invalid' USING ERRCODE='22023';
  END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  SELECT * INTO c FROM leave.cancellation_requests x WHERE x.tenant_id=p_tenant AND x.id=p_cancellation;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_cancellation_unavailable' USING ERRCODE='P0002'; END IF;
  r:=leave.lock_cancellation_parent(p_tenant,c.request_id);
  SELECT * INTO c FROM leave.cancellation_requests x WHERE x.tenant_id=p_tenant AND x.id=p_cancellation FOR UPDATE;
  IF NOT FOUND OR c.request_id<>r.id THEN RAISE EXCEPTION 'leave_cancellation_unavailable' USING ERRCODE='P0002'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  event_key:=CASE WHEN p_decision='accept' THEN 'hr.accepted' ELSE 'hr.rejected' END;
  payload:=pg_catalog.jsonb_build_object('action',event_key,'tenant',p_tenant,'cancellation',p_cancellation,
    'version',p_expected_version,'decision',p_decision,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  replay:=leave.cancellation_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),event_key,payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF r.state<>'approved' OR c.state<>'pending' THEN
    RAISE EXCEPTION 'leave_cancellation_not_pending' USING ERRCODE='23514';
  END IF;
  IF c.version<>p_expected_version THEN RAISE EXCEPTION 'leave_cancellation_version_conflict' USING ERRCODE='40001'; END IF;
  new_state:=CASE WHEN p_decision='accept' THEN 'accepted' ELSE 'rejected' END;
  IF p_decision='accept' THEN
    refs:=leave.capture_cancellation_time_facts(p_tenant,r.id);
    reversal_count:=leave.reverse_request_consumptions(p_tenant,r.id,actor,p_reason);
    UPDATE leave.requests SET state='cancelled',version=version+1,cancelled_at=pg_catalog.transaction_timestamp()
      WHERE tenant_id=p_tenant AND id=r.id;
  END IF;
  UPDATE leave.cancellation_requests SET state=new_state,version=version+1,
    decided_by=actor,decided_at=pg_catalog.transaction_timestamp(),decision_reason=pg_catalog.btrim(p_reason)
    WHERE tenant_id=p_tenant AND id=c.id;
  result:=pg_catalog.jsonb_build_object('state',new_state,'cancellation',leave.cancellation_json(p_tenant,c.id),
    'request',leave.request_json(p_tenant,r.id),'reversal_count',reversal_count,
    'time_reconciliation_required',pg_catalog.jsonb_array_length(refs)>0,'time_fact_refs',refs);
  INSERT INTO leave.cancellation_events(tenant_id,request_id,cancellation_id,actor_user_id,event_key,
    from_state,to_state,from_version,to_version,reason,operation_key,payload_hash,result,
    time_reconciliation_required,time_fact_refs)
  VALUES(p_tenant,r.id,c.id,actor,event_key,'pending',new_state,c.version,c.version+1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result,
    pg_catalog.jsonb_array_length(refs)>0,refs);
  IF p_decision='accept' THEN
    INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
      from_version,to_version,reason,operation_key,payload_hash,result)
    VALUES(p_tenant,r.id,actor,'hr.cancellation_accepted','approved','cancelled',r.version,r.version+1,
      pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  END IF;
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_decide_cancellation(uuid,uuid,integer,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_decide_cancellation(uuid,uuid,integer,text,text,text) TO authenticated;

CREATE FUNCTION public.leave_cancel_approved_request(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; payload jsonb; payload_hash text;
  replay jsonb; refs jsonb; reversal_count integer; result jsonb;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_request IS NULL OR p_expected_version IS NULL OR p_expected_version<=0
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_cancel_input_invalid' USING ERRCODE='22023';
  END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  r:=leave.lock_cancellation_parent(p_tenant,p_request);
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  payload:=pg_catalog.jsonb_build_object('action','hr.direct_cancelled','tenant',p_tenant,
    'request',p_request,'version',p_expected_version,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  replay:=leave.cancellation_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),'hr.direct_cancelled',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF r.state<>'approved' THEN RAISE EXCEPTION 'leave_request_not_cancellable' USING ERRCODE='23514'; END IF;
  IF r.version<>p_expected_version THEN RAISE EXCEPTION 'leave_request_version_conflict' USING ERRCODE='40001'; END IF;
  IF EXISTS(SELECT 1 FROM leave.cancellation_requests c WHERE c.tenant_id=p_tenant
      AND c.request_id=p_request AND c.state='pending') THEN
    RAISE EXCEPTION 'leave_cancellation_pending' USING ERRCODE='23514';
  END IF;
  refs:=leave.capture_cancellation_time_facts(p_tenant,p_request);
  reversal_count:=leave.reverse_request_consumptions(p_tenant,p_request,actor,p_reason);
  UPDATE leave.requests SET state='cancelled',version=version+1,cancelled_at=pg_catalog.transaction_timestamp()
    WHERE tenant_id=p_tenant AND id=p_request;
  result:=pg_catalog.jsonb_build_object('state','cancelled','request',leave.request_json(p_tenant,p_request),
    'reversal_count',reversal_count,'time_reconciliation_required',pg_catalog.jsonb_array_length(refs)>0,
    'time_fact_refs',refs);
  INSERT INTO leave.cancellation_events(tenant_id,request_id,cancellation_id,actor_user_id,event_key,
    from_state,to_state,from_version,to_version,reason,operation_key,payload_hash,result,
    time_reconciliation_required,time_fact_refs)
  VALUES(p_tenant,p_request,NULL,actor,'hr.direct_cancelled','approved','cancelled',r.version,r.version+1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result,
    pg_catalog.jsonb_array_length(refs)>0,refs);
  INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
    from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,p_request,actor,'hr.direct_cancelled','approved','cancelled',r.version,r.version+1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_cancel_approved_request(uuid,uuid,integer,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_cancel_approved_request(uuid,uuid,integer,text,text) TO authenticated;

CREATE FUNCTION public.leave_cancellation_queue(p_tenant uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); lim integer:=least(100,greatest(1,coalesce(p_limit,50)));
  off integer:=coalesce(p_offset,0); items jsonb; more boolean;
BEGIN
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  IF off<0 THEN RAISE EXCEPTION 'leave_page_invalid' USING ERRCODE='22023'; END IF;
  WITH page AS MATERIALIZED (
    SELECT c.tenant_id,c.id,c.request_id,c.requested_by,c.requester_kind,c.requested_at,c.reason,c.version,
      r.employee_id,r.employment_id,r.employer_entity_id,r.leave_type_id,r.start_date,r.end_date,r.is_half_day,
      r.version request_version,e.employee_code,e.full_name,t.name leave_type_name
    FROM leave.cancellation_requests c
    JOIN leave.requests r ON r.tenant_id=c.tenant_id AND r.id=c.request_id
    JOIN people.employees e ON e.tenant_id=r.tenant_id AND e.id=r.employee_id
    JOIN leave.types t ON t.tenant_id=r.tenant_id AND t.id=r.leave_type_id
    WHERE c.tenant_id=p_tenant AND c.state='pending' AND r.state='approved'
    ORDER BY c.requested_at,c.id OFFSET off LIMIT lim+1
  ), numbered AS MATERIALIZED (
    SELECT page.*,pg_catalog.row_number() OVER(ORDER BY requested_at,id) rn FROM page
  )
  SELECT coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'cancellation_id',id,'request_id',request_id,'requester_id',requested_by,
      'requester_kind',requester_kind,'requested_at',requested_at,'reason',reason,
      'cancellation_version',version,'request_version',request_version,'employee_id',employee_id,
      'employee_code',employee_code,'employee_name',full_name,'employment_id',employment_id,
      'employer_entity_id',employer_entity_id,'leave_type_id',leave_type_id,
      'leave_type_name',leave_type_name,'start_date',start_date,'end_date',end_date,
      'is_half_day',is_half_day) ORDER BY rn) FROM numbered WHERE rn<=lim),'[]'::jsonb),
    EXISTS(SELECT 1 FROM numbered WHERE rn>lim) INTO items,more;
  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'offset',off,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.leave_cancellation_queue(uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_cancellation_queue(uuid,integer,integer) TO authenticated;

CREATE FUNCTION public.leave_cancellation_history(p_tenant uuid,p_request uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; employee uuid; hr_read boolean;
  lim integer:=least(100,greatest(1,coalesce(p_limit,50))); off integer:=coalesce(p_offset,0);
  items jsonb; more boolean;
BEGIN
  IF actor IS NULL OR p_request IS NULL OR off<0 THEN RAISE EXCEPTION 'leave_page_invalid' USING ERRCODE='22023'; END IF;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  hr_read:=leave.request_hr_can_read(p_tenant,actor);
  IF hr_read THEN
    actor:=leave.authorized(p_tenant,CASE WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.view') THEN 'leave.view'
      WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.manage') THEN 'leave.manage' ELSE 'leave.approve' END,false);
  ELSE
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.view') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
    SELECT l.employee_id INTO employee FROM people.employee_user_links l
      WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
    IF employee IS DISTINCT FROM r.employee_id THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  END IF;
  WITH page AS MATERIALIZED (
    SELECT ev.* FROM leave.cancellation_events ev WHERE ev.tenant_id=p_tenant AND ev.request_id=p_request
    ORDER BY ev.id OFFSET off LIMIT lim+1
  ), numbered AS MATERIALIZED (
    SELECT page.*,pg_catalog.row_number() OVER(ORDER BY id) rn FROM page
  )
  SELECT coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',id,'cancellation_id',cancellation_id,'actor_user_id',actor_user_id,'event_key',event_key,
      'from_state',from_state,'to_state',to_state,'from_version',from_version,'to_version',to_version,
      'reason',reason,'result',result,'time_reconciliation_required',time_reconciliation_required,
      'time_fact_refs',time_fact_refs,'created_at',created_at) ORDER BY id)
      FROM numbered WHERE rn<=lim),'[]'::jsonb),EXISTS(SELECT 1 FROM numbered WHERE rn>lim)
    INTO items,more;
  RETURN pg_catalog.jsonb_build_object('request_id',p_request,'items',items,'limit',lim,'offset',off,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.leave_cancellation_history(uuid,uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_cancellation_history(uuid,uuid,integer,integer) TO authenticated;

CREATE FUNCTION public.leave_my_cancellation_history(
  p_tenant uuid,p_request uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); request_employee uuid; current_employee uuid;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_request IS NULL THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.view') THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  SELECT r.employee_id INTO request_employee FROM leave.requests r
    WHERE r.tenant_id=p_tenant AND r.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=request_employee FOR NO KEY UPDATE;
  SELECT l.employee_id INTO current_employee FROM people.employee_user_links l
    WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
  IF current_employee IS DISTINCT FROM request_employee
     OR NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.view') THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  RETURN public.leave_cancellation_history(p_tenant,p_request,p_limit,p_offset);
END $f$;
REVOKE ALL ON FUNCTION public.leave_my_cancellation_history(uuid,uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_cancellation_history(uuid,uuid,integer,integer) TO authenticated;
