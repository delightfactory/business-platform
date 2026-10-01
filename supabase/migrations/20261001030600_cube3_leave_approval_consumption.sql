-- Slice 3B1 draft: atomic approval, immutable per-day FIFO consumption and explicit
-- preview refresh. Cancellation APIs/reversals are intentionally deferred.

ALTER TABLE leave.requests
  ADD COLUMN approved_at timestamptz,
  ADD COLUMN approved_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  ADD COLUMN approved_preview_version integer,
  ADD COLUMN cancelled_at timestamptz;
ALTER TABLE leave.requests DROP CONSTRAINT requests_state_check;
ALTER TABLE leave.requests ADD CONSTRAINT requests_state_check
  CHECK (state IN ('draft','submitted','approved','rejected','withdrawn','cancelled'));
ALTER TABLE leave.requests ADD CONSTRAINT leave_request_approved_preview_fk
  FOREIGN KEY (tenant_id,id,approved_preview_version)
  REFERENCES leave.request_previews(tenant_id,request_id,preview_version) ON DELETE RESTRICT;
ALTER TABLE leave.requests ADD CONSTRAINT leave_request_approval_state_check CHECK (
  (state IN ('approved','cancelled') AND approved_at IS NOT NULL AND approved_by IS NOT NULL
    AND approved_preview_version IS NOT NULL AND approved_preview_version=current_preview_version)
  OR (state NOT IN ('approved','cancelled') AND approved_at IS NULL AND approved_by IS NULL
    AND approved_preview_version IS NULL)
);
ALTER TABLE leave.requests ADD CONSTRAINT leave_request_cancellation_state_check CHECK (
  (state='cancelled' AND cancelled_at IS NOT NULL) OR (state<>'cancelled' AND cancelled_at IS NULL)
);

ALTER TABLE leave.request_events DROP CONSTRAINT request_events_event_key_check;
ALTER TABLE leave.request_events ADD CONSTRAINT request_events_event_key_check CHECK (
  event_key IN ('employee.submitted','hr.recorded_submitted','employee.withdrawn','hr.rejected',
    'hr.approved','request.preview_refreshed'));
ALTER TABLE leave.request_events DROP CONSTRAINT request_events_to_state_check;
ALTER TABLE leave.request_events ADD CONSTRAINT request_events_to_state_check
  CHECK (to_state IN ('submitted','approved','withdrawn','rejected'));

-- Preserve existing entry kinds and their signs. A reversal self-link belongs to
-- the later cancellation slice, so this slice only introduces negative consumption.
ALTER TABLE leave.ledger_entries DROP CONSTRAINT ledger_entries_entry_kind_check;
ALTER TABLE leave.ledger_entries ADD CONSTRAINT ledger_entries_entry_kind_check
  CHECK (entry_kind IN ('opening','annual_grant','adjustment','leave_consumption'));
ALTER TABLE leave.ledger_entries DROP CONSTRAINT ledger_entries_check;
ALTER TABLE leave.ledger_entries ADD CONSTRAINT ledger_entries_check CHECK (
  delta_days<>0 AND (
    (entry_kind IN ('opening','annual_grant') AND delta_days>0)
    OR (entry_kind='adjustment')
    OR (entry_kind='leave_consumption' AND delta_days<0)
  )
);

ALTER TABLE leave.ledger_entries ADD CONSTRAINT leave_ledger_entry_account_id_unique
  UNIQUE (tenant_id,account_id,id);
CREATE TABLE leave.request_consumptions (
  tenant_id uuid NOT NULL,
  request_id uuid NOT NULL,
  preview_version integer NOT NULL,
  leave_date date NOT NULL,
  leave_type_id uuid NOT NULL,
  account_id uuid NOT NULL,
  ledger_entry_id uuid NOT NULL,
  units numeric(5,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id,request_id,preview_version,leave_date,account_id),
  UNIQUE (tenant_id,ledger_entry_id),
  FOREIGN KEY (tenant_id,request_id,preview_version,leave_date)
    REFERENCES leave.request_days(tenant_id,request_id,preview_version,leave_date) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,account_id,leave_type_id)
    REFERENCES leave.accounts(tenant_id,id,leave_type_id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,account_id,ledger_entry_id)
    REFERENCES leave.ledger_entries(tenant_id,account_id,id) ON DELETE RESTRICT,
  CHECK (units>0 AND units::text NOT IN ('NaN','Infinity','-Infinity'))
);
ALTER TABLE leave.request_consumptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE leave.request_consumptions FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_request_consumptions_immutable BEFORE UPDATE OR DELETE ON leave.request_consumptions
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();

CREATE OR REPLACE FUNCTION leave.guard_request_transition() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE is_refresh boolean; is_approval boolean; is_terminal boolean;
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
    OR OLD.state<>'submitted' OR NEW.version<>OLD.version+1 THEN
    RAISE EXCEPTION 'leave_request_transition_invalid' USING ERRCODE='55000';
  END IF;
  is_refresh:=NEW.state='submitted' AND NEW.current_preview_version=OLD.current_preview_version+1
    AND NEW.approved_at IS NOT DISTINCT FROM OLD.approved_at
    AND NEW.approved_by IS NOT DISTINCT FROM OLD.approved_by
    AND NEW.approved_preview_version IS NOT DISTINCT FROM OLD.approved_preview_version
    AND NEW.cancelled_at IS NOT DISTINCT FROM OLD.cancelled_at;
  is_approval:=NEW.state='approved' AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NOT NULL AND NEW.approved_by IS NOT NULL
    AND NEW.approved_preview_version=NEW.current_preview_version AND NEW.cancelled_at IS NULL;
  is_terminal:=NEW.state IN ('withdrawn','rejected')
    AND NEW.current_preview_version=OLD.current_preview_version
    AND NEW.approved_at IS NULL AND NEW.approved_by IS NULL
    AND NEW.approved_preview_version IS NULL AND NEW.cancelled_at IS NULL;
  IF NOT (is_refresh OR is_approval OR is_terminal) THEN
    RAISE EXCEPTION 'leave_request_transition_invalid' USING ERRCODE='55000';
  END IF;
  NEW.updated_at:=pg_catalog.transaction_timestamp();
  RETURN NEW;
END $f$;

CREATE OR REPLACE FUNCTION leave.request_preview_snapshot(p_tenant uuid,p_request uuid,p_version integer)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
  SELECT pg_catalog.jsonb_build_object('total_units',p.total_units,'days',
    coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'leave_date',d.leave_date,'year_period_id',d.year_period_id,
      'calendar_version_id',d.calendar_version_id,'leave_type_id',d.leave_type_id,
      'type_version_id',d.type_version_id,'day_count_basis',d.day_count_basis,
      'pay_effect',d.pay_effect,'balance_mode',d.balance_mode,
      'is_weekly_rest',d.is_weekly_rest,'holiday_name',d.holiday_name,
      'eligible',d.eligible,'units',d.units,'is_half_day',d.is_half_day)
      ORDER BY d.leave_date),'[]'::jsonb))
  FROM leave.request_previews p
  LEFT JOIN leave.request_days d ON d.tenant_id=p.tenant_id AND d.request_id=p.request_id
    AND d.preview_version=p.preview_version
  WHERE p.tenant_id=p_tenant AND p.request_id=p_request AND p.preview_version=p_version
  GROUP BY p.total_units
$f$;
REVOKE ALL ON FUNCTION leave.request_preview_snapshot(uuid,uuid,integer)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION leave.request_json(p_tenant uuid,p_request uuid,p_preview integer DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
  SELECT pg_catalog.jsonb_build_object('id',r.id,'employee_id',r.employee_id,
    'employee_code',e.employee_code,'employee_name',e.full_name,'employment_id',r.employment_id,
    'employer_entity_id',r.employer_entity_id,'leave_type_id',r.leave_type_id,'leave_type_name',t.name,
    'start_date',r.start_date,'end_date',r.end_date,'total_units',p.total_units,
    'is_half_day',r.is_half_day,'state',r.state,'version',r.version,
    'preview_version',p.preview_version,'request_source',r.request_source,'reason',r.reason,
    'owner_queue',r.owner_queue,'submitted_at',r.submitted_at,'created_at',r.created_at,
    'approved_at',r.approved_at,'approved_by',r.approved_by,
    'approved_preview_version',r.approved_preview_version,'cancelled_at',r.cancelled_at,
    'days',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'date',d.leave_date,'year_period_id',d.year_period_id,'calendar_version_id',d.calendar_version_id,
      'type_version_id',d.type_version_id,'day_count_basis',d.day_count_basis,'pay_effect',d.pay_effect,
      'balance_mode',d.balance_mode,'is_weekly_rest',d.is_weekly_rest,'holiday_name',d.holiday_name,
      'eligible',d.eligible,'units',d.units,'is_half_day',d.is_half_day) ORDER BY d.leave_date)
      FROM leave.request_days d WHERE d.tenant_id=r.tenant_id AND d.request_id=r.id
        AND d.preview_version=p.preview_version),'[]'::jsonb),
    'consumptions',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'date',c.leave_date,'account_id',c.account_id,'ledger_entry_id',c.ledger_entry_id,
      'units',c.units,'period_starts_on',yp.starts_on) ORDER BY c.leave_date,yp.starts_on,c.account_id)
      FROM leave.request_consumptions c JOIN leave.accounts a
        ON a.tenant_id=c.tenant_id AND a.id=c.account_id
      JOIN leave.year_periods yp ON yp.tenant_id=a.tenant_id AND yp.id=a.year_period_id
      WHERE c.tenant_id=r.tenant_id AND c.request_id=r.id
        AND c.preview_version=r.approved_preview_version),'[]'::jsonb))
  FROM leave.requests r JOIN people.employees e ON e.tenant_id=r.tenant_id AND e.id=r.employee_id
  JOIN leave.types t ON t.tenant_id=r.tenant_id AND t.id=r.leave_type_id
  JOIN leave.request_previews p ON p.tenant_id=r.tenant_id AND p.request_id=r.id
    AND p.preview_version=coalesce(p_preview,r.current_preview_version)
  WHERE r.tenant_id=p_tenant AND r.id=p_request
$f$;
REVOKE ALL ON FUNCTION leave.request_json(uuid,uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION leave.request_summary(p_tenant uuid,p_request uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT pg_catalog.jsonb_build_object('id',r.id,'employee_id',r.employee_id,
   'employee_code',e.employee_code,'employee_name',e.full_name,'employment_id',r.employment_id,
   'employer_entity_id',r.employer_entity_id,'leave_type_id',r.leave_type_id,'leave_type_name',t.name,
   'start_date',r.start_date,'end_date',r.end_date,'total_units',p.total_units,
   'is_half_day',r.is_half_day,'state',r.state,'version',r.version,
   'preview_version',p.preview_version,'request_source',r.request_source,'reason',r.reason,
   'owner_queue',r.owner_queue,'submitted_at',r.submitted_at,'created_at',r.created_at,
   'approved_at',r.approved_at,'approved_by',r.approved_by,'cancelled_at',r.cancelled_at)
 FROM leave.requests r
 JOIN people.employees e ON e.tenant_id=r.tenant_id AND e.id=r.employee_id
 JOIN leave.types t ON t.tenant_id=r.tenant_id AND t.id=r.leave_type_id
 JOIN leave.request_previews p ON p.tenant_id=r.tenant_id AND p.request_id=r.id
   AND p.preview_version=r.current_preview_version
 WHERE r.tenant_id=p_tenant AND r.id=p_request
$f$;
REVOKE ALL ON FUNCTION leave.request_summary(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_refresh_request_preview(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; emp people.employments%ROWTYPE;
  employee uuid; linked_employee uuid; employer_active boolean; use_self boolean;
  payload jsonb; payload_hash text; replay jsonb; computed jsonb; new_preview integer; result jsonb;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_request IS NULL OR p_expected_version IS NULL
    OR p_expected_version<=0 OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_preview_refresh_input_invalid' USING ERRCODE='22023';
  END IF;
  use_self:=NOT platform_private.has_tenant_permission(p_tenant,actor,'leave.approve');
  IF use_self THEN
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
  ELSE
    actor:=leave.authorized(p_tenant,'leave.approve',true);
  END IF;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  IF use_self THEN
    SELECT l.employee_id INTO employee FROM people.employee_user_links l
      WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
    IF employee IS DISTINCT FROM r.employee_id THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=r.employee_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  IF use_self THEN
    SELECT l.employee_id INTO linked_employee FROM people.employee_user_links l
      WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL FOR UPDATE;
    IF linked_employee IS DISTINCT FROM r.employee_id OR
       NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
    IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',pg_catalog.now())
       OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',pg_catalog.now()) THEN
      RAISE EXCEPTION 'leave_new_work_disabled' USING ERRCODE='55000';
    END IF;
  END IF;
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=r.employee_id
    AND e.start_date<=r.end_date AND (e.end_date IS NULL OR e.end_date>=r.start_date)
    ORDER BY e.id FOR UPDATE;
  SELECT * INTO emp FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=r.employment_id
    AND e.employee_id=r.employee_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
    SELECT e.is_active INTO employer_active FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant AND e.id=emp.employer_entity_id FOR UPDATE;
    IF NOT coalesce(employer_active,false) THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
    IF emp.employer_entity_id<>r.employer_entity_id THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
  IF use_self THEN
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
  ELSE
    actor:=leave.authorized(p_tenant,'leave.approve',true);
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  payload:=pg_catalog.jsonb_build_object('action','request.preview_refreshed','tenant',p_tenant,
    'request',p_request,'version',p_expected_version,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  PERFORM leave.lock_request_configuration(p_tenant,emp.employer_entity_id,r.leave_type_id,r.start_date,r.end_date);
  PERFORM 1 FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request FOR UPDATE;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  IF use_self THEN
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
  ELSE
    actor:=leave.authorized(p_tenant,'leave.approve',true);
  END IF;
  replay:=leave.request_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),
    'request.preview_refreshed',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF r.state<>'submitted' THEN RAISE EXCEPTION 'leave_request_not_refreshable' USING ERRCODE='23514'; END IF;
  IF r.version<>p_expected_version THEN RAISE EXCEPTION 'leave_request_version_conflict' USING ERRCODE='40001'; END IF;
  IF emp.employment_status<>'active' OR emp.start_date>r.start_date
     OR (emp.end_date IS NOT NULL AND emp.end_date<r.end_date)
     OR emp.employer_entity_id<>r.employer_entity_id THEN
    RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514';
  END IF;
  computed:=leave.request_preview(p_tenant,r.employer_entity_id,r.leave_type_id,
    r.start_date,r.end_date,r.is_half_day);
  IF use_self THEN
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request')
       OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',pg_catalog.now())
       OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',pg_catalog.now()) THEN
      RAISE EXCEPTION 'leave_new_work_disabled' USING ERRCODE='55000';
    END IF;
  ELSE
    actor:=leave.authorized(p_tenant,'leave.approve',true);
  END IF;
  new_preview:=r.current_preview_version+1;
  INSERT INTO leave.request_previews(tenant_id,request_id,preview_version,total_units,created_by)
  VALUES(p_tenant,p_request,new_preview,(computed->>'total_units')::numeric,actor);
  INSERT INTO leave.request_days(tenant_id,request_id,preview_version,leave_date,employer_entity_id,
    year_period_id,calendar_version_id,leave_type_id,type_version_id,day_count_basis,pay_effect,
    balance_mode,is_weekly_rest,holiday_name,eligible,units,is_half_day)
  SELECT p_tenant,p_request,new_preview,(x->>'leave_date')::date,r.employer_entity_id,
    (x->>'year_period_id')::uuid,(x->>'calendar_version_id')::uuid,(x->>'leave_type_id')::uuid,
    (x->>'type_version_id')::uuid,x->>'day_count_basis',x->>'pay_effect',x->>'balance_mode',
    (x->>'is_weekly_rest')::boolean,x->>'holiday_name',(x->>'eligible')::boolean,
    (x->>'units')::numeric,(x->>'is_half_day')::boolean
  FROM pg_catalog.jsonb_array_elements(computed->'days') x;
  UPDATE leave.requests SET current_preview_version=new_preview,version=version+1
    WHERE tenant_id=p_tenant AND id=p_request;
  result:=pg_catalog.jsonb_build_object('state','refreshed',
    'request',leave.request_json(p_tenant,p_request,new_preview));
  INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
    from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,p_request,actor,'request.preview_refreshed','submitted','submitted',r.version,r.version+1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_refresh_request_preview(uuid,uuid,integer,text,text)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_refresh_request_preview(uuid,uuid,integer,text,text)
  TO authenticated;

CREATE FUNCTION public.leave_approve_request(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reviewed_preview_version integer,
  p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; emp people.employments%ROWTYPE;
  employer_active boolean; payload jsonb; payload_hash text; replay jsonb; result jsonb;
  computed jsonb; stored jsonb; charge_day record; charge_account record; need numeric(8,2); available numeric(10,2);
  take_units numeric(8,2); balance_now numeric(10,2); entry_id uuid; conflicting jsonb;
BEGIN
  IF p_tenant IS NULL OR p_request IS NULL OR p_expected_version IS NULL OR p_expected_version<=0
    OR p_reviewed_preview_version IS NULL OR p_reviewed_preview_version<=0
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_approval_input_invalid' USING ERRCODE='22023';
  END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=r.employee_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=r.employee_id
    AND e.start_date<=r.end_date AND (e.end_date IS NULL OR e.end_date>=r.start_date)
    ORDER BY e.id FOR UPDATE;
  SELECT * INTO emp FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=r.employment_id
    AND e.employee_id=r.employee_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
    SELECT e.is_active INTO employer_active FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant AND e.id=emp.employer_entity_id FOR UPDATE;
    IF NOT coalesce(employer_active,false) THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
    IF emp.employer_entity_id<>r.employer_entity_id THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  payload:=pg_catalog.jsonb_build_object('action','hr.approved','tenant',p_tenant,
    'request',p_request,'version',p_expected_version,'preview_version',p_reviewed_preview_version,
    'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  PERFORM leave.lock_request_configuration(p_tenant,emp.employer_entity_id,r.leave_type_id,r.start_date,r.end_date);
  PERFORM 1 FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request FOR UPDATE;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  replay:=leave.request_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),'hr.approved',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF r.state<>'submitted' THEN RAISE EXCEPTION 'leave_request_not_approvable' USING ERRCODE='23514'; END IF;
  IF r.version<>p_expected_version OR r.current_preview_version<>p_reviewed_preview_version THEN
    RAISE EXCEPTION 'leave_request_version_conflict' USING ERRCODE='40001';
  END IF;
  IF emp.employment_status<>'active' OR emp.start_date>r.start_date
     OR (emp.end_date IS NOT NULL AND emp.end_date<r.end_date)
     OR emp.employer_entity_id<>r.employer_entity_id THEN
    RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM leave.types t WHERE t.tenant_id=p_tenant
      AND t.id=r.leave_type_id AND t.employer_entity_id=r.employer_entity_id AND t.is_active) THEN
    RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23514';
  END IF;
  computed:=leave.request_preview(p_tenant,r.employer_entity_id,r.leave_type_id,
    r.start_date,r.end_date,r.is_half_day);
  stored:=leave.request_preview_snapshot(p_tenant,p_request,r.current_preview_version);
  IF computed IS DISTINCT FROM stored THEN
    RETURN pg_catalog.jsonb_build_object('state','refresh_required','request_id',p_request,
      'request_version',r.version,'stored_preview_version',r.current_preview_version,
      'stored_preview',stored,'current_preview',computed);
  END IF;
  IF EXISTS (
    SELECT 1 FROM leave.request_days d
    JOIN leave.requests other ON other.tenant_id=d.tenant_id AND other.id=d.request_id
    WHERE d.tenant_id=p_tenant AND other.employee_id=r.employee_id
      AND other.state='approved' AND other.id<>r.id
      AND d.preview_version=other.approved_preview_version AND d.eligible AND d.units>0
      AND EXISTS(SELECT 1 FROM leave.request_days own
        WHERE own.tenant_id=p_tenant AND own.request_id=r.id
          AND own.preview_version=r.current_preview_version AND own.leave_date=d.leave_date
          AND own.eligible AND own.units>0)
  ) THEN
    RAISE EXCEPTION 'leave_request_overlap' USING ERRCODE='23514';
  END IF;
  -- Read current immutable Time evidence independent of the Attendance entitlement.
  -- Acquire WorkInstance locks after request/configuration locks; Time write paths must
  -- adopt the shared Employment -> WorkInstance prefix to close the remaining race.
  PERFORM 1 FROM time.work_instances i
    WHERE i.tenant_id=p_tenant AND i.employment_id=r.employment_id
      AND i.operational_date BETWEEN r.start_date AND r.end_date
      AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant
        AND d.request_id=r.id AND d.preview_version=r.current_preview_version
        AND d.leave_date=i.operational_date AND d.eligible AND d.units>0)
    ORDER BY i.operational_date,i.id FOR NO KEY UPDATE;
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'work_instance_id',i.id,'operational_date',i.operational_date,
      'attendance_fact_id',latest.id,'attendance_fact_version',latest.version,
      'outcome',latest.fact->>'outcome') ORDER BY i.operational_date,i.id)
    INTO conflicting
  FROM time.work_instances i
  JOIN LATERAL (SELECT f.id,f.version,f.fact FROM time.attendance_facts f
    WHERE f.tenant_id=i.tenant_id AND f.work_instance_id=i.id
    ORDER BY f.version DESC LIMIT 1) latest ON true
  WHERE i.tenant_id=p_tenant AND i.employment_id=r.employment_id
    AND i.operational_date BETWEEN r.start_date AND r.end_date
    AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant
      AND d.request_id=r.id AND d.preview_version=r.current_preview_version
      AND d.leave_date=i.operational_date AND d.eligible AND d.units>0);
  IF conflicting IS NOT NULL THEN
    RAISE EXCEPTION 'leave_attendance_fact_conflict' USING ERRCODE='23514',
      DETAIL=conflicting::text;
  END IF;
  IF r.is_half_day AND platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',pg_catalog.now()) THEN
    RAISE EXCEPTION 'leave_half_day_mapping_required' USING ERRCODE='23514';
  END IF;
  -- Serialize all ledger writers on the established employee key. Lock every
  -- potentially chargeable account before reading any balance, in FIFO order.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||r.employee_id::text,90429));
  PERFORM 1 FROM leave.accounts a JOIN leave.year_periods yp
    ON yp.tenant_id=a.tenant_id AND yp.id=a.year_period_id
    WHERE a.tenant_id=p_tenant AND a.employer_entity_id=r.employer_entity_id
      AND a.employee_id=r.employee_id AND a.leave_type_id=r.leave_type_id
      AND yp.starts_on<=r.end_date
    ORDER BY yp.starts_on,a.id FOR UPDATE OF a;
  FOR charge_day IN SELECT * FROM leave.request_days x WHERE x.tenant_id=p_tenant
      AND x.request_id=r.id AND x.preview_version=r.current_preview_version
      ORDER BY x.leave_date
  LOOP
    IF NOT charge_day.eligible OR charge_day.units=0 OR charge_day.balance_mode='untracked' THEN CONTINUE; END IF;
    need:=charge_day.units;
    FOR charge_account IN SELECT ac.id,yp.starts_on FROM leave.accounts ac
      JOIN leave.year_periods yp ON yp.tenant_id=ac.tenant_id AND yp.id=ac.year_period_id
      WHERE ac.tenant_id=p_tenant AND ac.employer_entity_id=r.employer_entity_id
        AND ac.employee_id=r.employee_id AND ac.leave_type_id=r.leave_type_id
        AND yp.starts_on<=charge_day.leave_date
      ORDER BY yp.starts_on,ac.id
    LOOP
      SELECT coalesce(pg_catalog.sum(le.delta_days),0) INTO balance_now
        FROM leave.ledger_entries le WHERE le.tenant_id=p_tenant AND le.account_id=charge_account.id;
      IF balance_now<0 THEN RAISE EXCEPTION 'leave_balance_invariant_violation' USING ERRCODE='23514'; END IF;
      available:=balance_now;
      take_units:=least(need,available);
      IF take_units>0 THEN
        INSERT INTO leave.ledger_entries(tenant_id,account_id,leave_type_id,entry_kind,delta_days,
          source_version_id,source_reference,idempotency_key,reason,actor_user_id)
        VALUES(p_tenant,charge_account.id,r.leave_type_id,'leave_consumption',-take_units,charge_day.type_version_id,
          'leave.request:'||r.id::text||':preview:'||r.current_preview_version::text||':date:'||
            pg_catalog.to_char(charge_day.leave_date,'YYYYMMDD'),
          'leave:consume:'||r.id::text||':v'||r.current_preview_version::text||':'||
            pg_catalog.to_char(charge_day.leave_date,'YYYYMMDD')||':'||charge_account.id::text,
          pg_catalog.btrim(r.reason),actor)
        RETURNING id INTO entry_id;
        INSERT INTO leave.request_consumptions(tenant_id,request_id,preview_version,leave_date,
          leave_type_id,account_id,ledger_entry_id,units)
        VALUES(p_tenant,r.id,r.current_preview_version,charge_day.leave_date,r.leave_type_id,charge_account.id,entry_id,take_units);
        need:=need-take_units;
      END IF;
      EXIT WHEN need=0;
    END LOOP;
    IF need>0 THEN
      RAISE EXCEPTION 'leave_balance_insufficient' USING ERRCODE='23514',
        DETAIL=pg_catalog.jsonb_build_object('date',charge_day.leave_date,'required',charge_day.units,'shortfall',need)::text;
    END IF;
  END LOOP;
  actor:=leave.authorized(p_tenant,'leave.approve',true);
  UPDATE leave.requests SET state='approved',version=version+1,
    approved_at=pg_catalog.transaction_timestamp(),approved_by=actor,
    approved_preview_version=r.current_preview_version
  WHERE tenant_id=p_tenant AND id=r.id;
  result:=leave.request_json(p_tenant,r.id,r.current_preview_version);
  INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
    from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,r.id,actor,'hr.approved','submitted','approved',r.version,r.version+1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_approve_request(uuid,uuid,integer,integer,text,text)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_approve_request(uuid,uuid,integer,integer,text,text)
  TO authenticated;

-- Keep the existing Attendance protection and add a temporal guard for approved
-- Leave days. Employment termination and Leave approval share Employee/Employment locks.
CREATE OR REPLACE FUNCTION people.guard_materialized_employment_end()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $guard$
BEGIN
  IF (NEW.end_date IS DISTINCT FROM OLD.end_date
      OR NEW.employment_status IS DISTINCT FROM OLD.employment_status)
     AND NEW.end_date IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM time.work_instances i
       WHERE i.tenant_id = NEW.tenant_id AND i.employment_id = NEW.id
         AND i.operational_date > NEW.end_date
     ) THEN
    RAISE EXCEPTION 'people_employment_end_before_materialized_day'
      USING ERRCODE = '23514';
  END IF;
  IF (NEW.end_date IS DISTINCT FROM OLD.end_date
      OR NEW.employment_status IS DISTINCT FROM OLD.employment_status)
     AND (NEW.end_date IS NOT NULL OR NEW.employment_status='ended')
     AND EXISTS (
       SELECT 1 FROM leave.requests r
       JOIN leave.request_days d ON d.tenant_id=r.tenant_id AND d.request_id=r.id
         AND d.preview_version=r.approved_preview_version
       WHERE r.tenant_id=NEW.tenant_id AND r.employment_id=NEW.id AND r.state='approved'
         AND d.eligible AND d.units>0
         AND (NEW.end_date IS NULL OR d.leave_date>NEW.end_date)
     ) THEN
    RAISE EXCEPTION 'people_employment_end_before_approved_leave'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $guard$;
