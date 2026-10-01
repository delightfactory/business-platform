-- Cube 3 Slice 3A: bounded request submission, reads, withdrawal and HR rejection.
-- Approval, balance consumption, cancellation, corrections and Attendance integration are not implemented here.
-- Request dates are capped at 732 per call for bounded processing; this is not a statutory eligibility limit.

ALTER TABLE leave.types ADD COLUMN is_active boolean NOT NULL DEFAULT true;
CREATE OR REPLACE FUNCTION public.leave_configuration_snapshot(p_tenant uuid,p_employer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE out_cal jsonb; out_types jsonb; out_periods jsonb;
BEGIN
  PERFORM leave.authorized(p_tenant,'leave.view',false);
  SELECT coalesce(jsonb_agg(jsonb_build_object('calendar_id',c.id,'code',c.code,'name',c.name,'versions',
    (SELECT coalesce(jsonb_agg(jsonb_build_object('id',v.id,'version',v.version,'effective_from',v.effective_from,
      'effective_until',v.effective_until,'timezone',v.timezone,'source',v.source,'rest_weekdays',
      (SELECT coalesce(jsonb_agg(r.weekday ORDER BY r.weekday),'[]'::jsonb) FROM leave.calendar_rest_days r
        WHERE r.tenant_id=v.tenant_id AND r.calendar_version_id=v.id),'holidays',
      (SELECT coalesce(jsonb_agg(jsonb_build_object('date',h.holiday_date,'name',h.name,'source',h.source)
        ORDER BY h.holiday_date),'[]'::jsonb) FROM leave.calendar_holidays h
        WHERE h.tenant_id=v.tenant_id AND h.calendar_version_id=v.id)) ORDER BY v.version DESC),'[]'::jsonb)
      FROM leave.calendar_versions v WHERE v.tenant_id=c.tenant_id AND v.calendar_id=c.id))
      ORDER BY c.code),'[]'::jsonb) INTO out_cal
    FROM leave.calendars c WHERE c.tenant_id=p_tenant AND c.employer_entity_id=p_employer;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'name',t.name,'is_active',t.is_active,
    'versions',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',v.id,'version',v.version,
      'effective_from',v.effective_from,'effective_until',v.effective_until,'pay_effect',v.pay_effect,
      'balance_mode',v.balance_mode,'day_count_basis',v.day_count_basis,'half_day_allowed',v.half_day_allowed,
      'source',v.source) ORDER BY v.version DESC),'[]'::jsonb)
      FROM leave.type_versions v WHERE v.tenant_id=t.tenant_id AND v.leave_type_id=t.id))
      ORDER BY t.code),'[]'::jsonb) INTO out_types
    FROM leave.types t WHERE t.tenant_id=p_tenant AND t.employer_entity_id=p_employer;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'calendar_id',calendar_id,'starts_on',starts_on,
    'ends_on',ends_on,'label',label) ORDER BY starts_on,id),'[]'::jsonb) INTO out_periods
    FROM leave.year_periods WHERE tenant_id=p_tenant AND employer_entity_id=p_employer;
  RETURN jsonb_build_object('calendars',out_cal,'types',out_types,'year_periods',out_periods);
END $f$;
REVOKE ALL ON FUNCTION public.leave_configuration_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_configuration_snapshot(uuid,uuid) TO authenticated;
ALTER TABLE leave.config_audit_events
  DROP CONSTRAINT config_audit_events_object_kind_check,
  DROP CONSTRAINT config_audit_events_action_check;
ALTER TABLE leave.config_audit_events
  ADD CONSTRAINT config_audit_events_object_kind_check
    CHECK (object_kind IN ('calendar_version','year_period','leave_type_version','leave_type')),
  ADD CONSTRAINT config_audit_events_action_check
    CHECK (action IN ('created','superseded','activated','deactivated'));

CREATE TABLE leave.requests (
  tenant_id uuid NOT NULL,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  employee_id uuid NOT NULL,
  employment_id uuid NOT NULL,
  employer_entity_id uuid NOT NULL,
  leave_type_id uuid NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  is_half_day boolean NOT NULL DEFAULT false,
  request_source text NOT NULL CHECK (request_source IN ('employee','hr')),
  state text NOT NULL DEFAULT 'submitted' CHECK (state IN ('draft','submitted','rejected','withdrawn')),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  current_preview_version integer NOT NULL DEFAULT 1 CHECK (current_preview_version > 0),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  submitted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  submitted_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  reason text NOT NULL CHECK (length(pg_catalog.btrim(reason)) BETWEEN 3 AND 500),
  owner_queue text NOT NULL DEFAULT 'leave.approval' CHECK (owner_queue = 'leave.approval'),
  owner_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,employment_id) REFERENCES people.employments(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,employer_entity_id) REFERENCES platform_core.tenant_legal_entities(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,leave_type_id,employer_entity_id)
    REFERENCES leave.types(tenant_id,id,employer_entity_id) ON DELETE RESTRICT,
  CHECK (end_date >= start_date)
);
CREATE INDEX leave_requests_employee_history ON leave.requests(tenant_id,employee_id,created_at DESC,id DESC);
CREATE INDEX leave_requests_submitted_queue ON leave.requests(tenant_id,submitted_at,id) WHERE state='submitted';
CREATE INDEX leave_requests_employment_range ON leave.requests(tenant_id,employment_id,start_date,end_date);

-- A request may later receive an explicit refreshed preview without rewriting what was first submitted.
CREATE TABLE leave.request_previews (
  tenant_id uuid NOT NULL,
  request_id uuid NOT NULL,
  preview_version integer NOT NULL CHECK (preview_version > 0),
  total_units numeric(8,2) NOT NULL CHECK (total_units > 0),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id,request_id,preview_version),
  FOREIGN KEY (tenant_id,request_id) REFERENCES leave.requests(tenant_id,id) ON DELETE RESTRICT
);
ALTER TABLE leave.requests ADD CONSTRAINT leave_requests_current_preview_fk
  FOREIGN KEY (tenant_id,id,current_preview_version)
  REFERENCES leave.request_previews(tenant_id,request_id,preview_version)
  DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE leave.request_days (
  tenant_id uuid NOT NULL,
  request_id uuid NOT NULL,
  preview_version integer NOT NULL,
  leave_date date NOT NULL,
  employer_entity_id uuid NOT NULL,
  year_period_id uuid NOT NULL,
  calendar_version_id uuid NOT NULL,
  leave_type_id uuid NOT NULL,
  type_version_id uuid NOT NULL,
  day_count_basis text NOT NULL CHECK (day_count_basis IN ('working_days','calendar_days')),
  pay_effect text NOT NULL CHECK (pay_effect IN ('paid','unpaid')),
  balance_mode text NOT NULL CHECK (balance_mode IN ('tracked','untracked')),
  is_weekly_rest boolean NOT NULL,
  holiday_name text,
  eligible boolean NOT NULL,
  units numeric(5,2) NOT NULL CHECK (units >= 0 AND units <= 1),
  is_half_day boolean NOT NULL DEFAULT false,
  PRIMARY KEY (tenant_id,request_id,preview_version,leave_date),
  FOREIGN KEY (tenant_id,request_id,preview_version)
    REFERENCES leave.request_previews(tenant_id,request_id,preview_version) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,year_period_id,employer_entity_id)
    REFERENCES leave.year_periods(tenant_id,id,employer_entity_id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,calendar_version_id) REFERENCES leave.calendar_versions(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,leave_type_id) REFERENCES leave.types(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,type_version_id,leave_type_id)
    REFERENCES leave.type_versions(tenant_id,id,leave_type_id) ON DELETE RESTRICT,
  CHECK (NOT is_half_day OR (units IN (0,0.5) AND eligible)),
  CHECK (day_count_basis <> 'working_days' OR eligible = (NOT is_weekly_rest AND holiday_name IS NULL))
);
CREATE INDEX leave_request_days_date_request ON leave.request_days(tenant_id,leave_date,request_id,preview_version);
CREATE INDEX leave_request_days_period_request ON leave.request_days(tenant_id,year_period_id,request_id,preview_version);

CREATE TABLE leave.request_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  request_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN ('employee.submitted','hr.recorded_submitted','employee.withdrawn','hr.rejected')),
  from_state text,
  to_state text NOT NULL CHECK (to_state IN ('submitted','withdrawn','rejected')),
  from_version integer,
  to_version integer NOT NULL CHECK (to_version > 0),
  reason text NOT NULL CHECK (length(pg_catalog.btrim(reason)) BETWEEN 3 AND 500),
  operation_key text NOT NULL CHECK (length(pg_catalog.btrim(operation_key)) BETWEEN 1 AND 120),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,request_id) REFERENCES leave.requests(tenant_id,id) ON DELETE RESTRICT,
  UNIQUE (tenant_id,actor_user_id,operation_key)
);
CREATE INDEX leave_request_events_request_id ON leave.request_events(tenant_id,request_id,id);

DO $f$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['requests','request_previews','request_days','request_events'] LOOP
    EXECUTE pg_catalog.format('ALTER TABLE leave.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE pg_catalog.format('REVOKE ALL ON TABLE leave.%I FROM PUBLIC,anon,authenticated,service_role',t);
  END LOOP;
END $f$;
REVOKE ALL ON SEQUENCE leave.request_events_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.reject_request_fact_mutation() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN RAISE EXCEPTION 'leave_request_history_immutable' USING ERRCODE='55000'; END $f$;
REVOKE ALL ON FUNCTION leave.reject_request_fact_mutation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_request_preview_immutable BEFORE UPDATE OR DELETE ON leave.request_previews
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();
CREATE TRIGGER leave_request_days_immutable BEFORE UPDATE OR DELETE ON leave.request_days
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();
CREATE TRIGGER leave_request_events_append_only BEFORE UPDATE OR DELETE ON leave.request_events
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();

CREATE FUNCTION leave.guard_request_transition() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  IF ROW(NEW.tenant_id,NEW.id,NEW.employee_id,NEW.employment_id,NEW.employer_entity_id,
     NEW.leave_type_id,NEW.start_date,NEW.end_date,NEW.is_half_day,
    NEW.request_source,NEW.created_by,NEW.submitted_by,NEW.submitted_at,NEW.reason,
    NEW.owner_queue,NEW.owner_user_id,NEW.created_at)
    IS DISTINCT FROM
    ROW(OLD.tenant_id,OLD.id,OLD.employee_id,OLD.employment_id,OLD.employer_entity_id,
     OLD.leave_type_id,OLD.start_date,OLD.end_date,OLD.is_half_day,
    OLD.request_source,OLD.created_by,OLD.submitted_by,OLD.submitted_at,OLD.reason,
    OLD.owner_queue,OLD.owner_user_id,OLD.created_at)
    OR OLD.state<>'submitted' OR NEW.state NOT IN('withdrawn','rejected')
    OR NEW.version<>OLD.version+1 OR NEW.current_preview_version<OLD.current_preview_version THEN
    RAISE EXCEPTION 'leave_request_transition_invalid' USING ERRCODE='55000';
  END IF;
  NEW.updated_at:=pg_catalog.transaction_timestamp(); RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION leave.guard_request_transition() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_request_state_transition BEFORE UPDATE ON leave.requests
  FOR EACH ROW EXECUTE FUNCTION leave.guard_request_transition();
CREATE TRIGGER leave_request_no_delete BEFORE DELETE ON leave.requests
  FOR EACH ROW EXECUTE FUNCTION leave.reject_request_fact_mutation();

CREATE FUNCTION leave.request_actor_allowed(p_tenant uuid,p_actor uuid,p_permission text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
  SELECT platform_private.has_leave_self_permission(p_tenant,p_actor,p_permission)
$f$;
REVOKE ALL ON FUNCTION leave.request_actor_allowed(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION leave.request_hr_can_read(p_tenant uuid,p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
  SELECT platform_private.has_tenant_permission(p_tenant,p_actor,'leave.view')
      OR platform_private.has_tenant_permission(p_tenant,p_actor,'leave.manage')
      OR platform_private.has_tenant_permission(p_tenant,p_actor,'leave.approve')
$f$;
REVOKE ALL ON FUNCTION leave.request_hr_can_read(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION leave.request_assert_queue(p_tenant uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
    WHERE m.tenant_id=p_tenant AND m.access_state='active' AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND platform_private.has_tenant_permission(p_tenant,m.user_id,'leave.approve')) THEN
    RAISE EXCEPTION 'leave_approval_queue_unavailable' USING ERRCODE='23514';
  END IF;
END $f$;
REVOKE ALL ON FUNCTION leave.request_assert_queue(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.request_preview(p_tenant uuid,p_employer uuid,p_type uuid,p_start date,p_end date,p_half_day boolean)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE d date; yp leave.year_periods%ROWTYPE; cv leave.calendar_versions%ROWTYPE;
  tv leave.type_versions%ROWTYPE; snap jsonb; eligible boolean; units numeric(5,2);
  total numeric(8,2):=0; rows jsonb:='[]'::jsonb;
BEGIN
  IF p_start IS NULL OR p_end IS NULL OR p_end<p_start OR p_end-p_start>731
     OR p_half_day IS NULL OR (p_half_day AND p_start<>p_end) THEN
    RAISE EXCEPTION 'leave_request_range_invalid' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=p_type
    AND t.employer_entity_id=p_employer AND t.is_active) THEN
    RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503';
  END IF;
  FOR d IN SELECT g::date FROM pg_catalog.generate_series(p_start,p_end,interval '1 day') g LOOP
    SELECT * INTO yp FROM leave.year_periods y WHERE y.tenant_id=p_tenant
      AND y.employer_entity_id=p_employer AND y.starts_on<=d AND y.ends_on>=d;
    IF NOT FOUND THEN RAISE EXCEPTION 'leave_year_period_unavailable' USING ERRCODE='23514'; END IF;
    SELECT * INTO cv FROM leave.calendar_versions v WHERE v.tenant_id=p_tenant
      AND v.calendar_id=yp.calendar_id AND v.effective_from<=d
      AND (v.effective_until IS NULL OR v.effective_until>d);
    IF NOT FOUND THEN RAISE EXCEPTION 'leave_calendar_version_unavailable' USING ERRCODE='23514'; END IF;
    IF NOT EXISTS(SELECT 1 FROM leave.calendars c WHERE c.tenant_id=p_tenant AND c.id=yp.calendar_id
      AND c.employer_entity_id=p_employer AND c.is_active) THEN
      RAISE EXCEPTION 'leave_calendar_unavailable' USING ERRCODE='23514';
    END IF;
    SELECT * INTO tv FROM leave.type_versions v WHERE v.tenant_id=p_tenant
      AND v.leave_type_id=p_type AND v.effective_from<=d AND (v.effective_until IS NULL OR v.effective_until>d);
    IF NOT FOUND THEN RAISE EXCEPTION 'leave_type_version_unavailable' USING ERRCODE='23514'; END IF;
    IF p_half_day AND NOT tv.half_day_allowed THEN RAISE EXCEPTION 'leave_half_day_not_allowed' USING ERRCODE='23514'; END IF;
    snap:=leave.calendar_day_snapshot(p_tenant,yp.calendar_id,d);
    IF snap IS NULL OR snap->>'calendar_version_id' IS DISTINCT FROM cv.id::text THEN
      RAISE EXCEPTION 'leave_calendar_version_unavailable' USING ERRCODE='23514';
    END IF;
    eligible:=CASE WHEN tv.day_count_basis='calendar_days' THEN true
      ELSE NOT coalesce((snap->>'is_weekly_rest')::boolean,false) AND snap->>'holiday' IS NULL END;
    IF p_half_day AND NOT eligible THEN RAISE EXCEPTION 'leave_half_day_ineligible' USING ERRCODE='23514'; END IF;
    units:=CASE WHEN NOT eligible THEN 0 WHEN p_half_day THEN 0.5 ELSE 1 END;
    total:=total+units;
    rows:=rows||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'leave_date',d,'year_period_id',yp.id,'calendar_version_id',cv.id,'leave_type_id',p_type,
      'type_version_id',tv.id,'day_count_basis',tv.day_count_basis,'pay_effect',tv.pay_effect,
      'balance_mode',tv.balance_mode,'is_weekly_rest',coalesce((snap->>'is_weekly_rest')::boolean,false),
      'holiday_name',snap->>'holiday','eligible',eligible,'units',units,'is_half_day',p_half_day));
  END LOOP;
  IF total<=0 THEN RAISE EXCEPTION 'leave_request_zero_days' USING ERRCODE='23514'; END IF;
  RETURN pg_catalog.jsonb_build_object('days',rows,'total_units',total);
END $f$;
REVOKE ALL ON FUNCTION leave.request_preview(uuid,uuid,uuid,date,date,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.request_json(p_tenant uuid,p_request uuid,p_preview integer DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
  SELECT pg_catalog.jsonb_build_object('id',r.id,'employee_id',r.employee_id,
    'employee_code',e.employee_code,'employee_name',e.full_name,'employment_id',r.employment_id,
    'employer_entity_id',r.employer_entity_id,'leave_type_id',r.leave_type_id,'leave_type_name',t.name,
    'start_date',r.start_date,'end_date',r.end_date,'total_units',p.total_units,
    'is_half_day',r.is_half_day,'state',r.state,'version',r.version,
    'preview_version',p.preview_version,'request_source',r.request_source,'reason',r.reason,
    'owner_queue',r.owner_queue,'submitted_at',r.submitted_at,'created_at',r.created_at,
    'days',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'date',d.leave_date,'year_period_id',d.year_period_id,'calendar_version_id',d.calendar_version_id,
      'type_version_id',d.type_version_id,'day_count_basis',d.day_count_basis,'pay_effect',d.pay_effect,
      'balance_mode',d.balance_mode,'is_weekly_rest',d.is_weekly_rest,'holiday_name',d.holiday_name,
      'eligible',d.eligible,'units',d.units,'is_half_day',d.is_half_day) ORDER BY d.leave_date)
      FROM leave.request_days d WHERE d.tenant_id=r.tenant_id AND d.request_id=r.id
        AND d.preview_version=p.preview_version),'[]'::jsonb))
  FROM leave.requests r JOIN people.employees e ON e.tenant_id=r.tenant_id AND e.id=r.employee_id
  JOIN leave.types t ON t.tenant_id=r.tenant_id AND t.id=r.leave_type_id
  JOIN leave.request_previews p ON p.tenant_id=r.tenant_id AND p.request_id=r.id
    AND p.preview_version=coalesce(p_preview,r.current_preview_version)
  WHERE r.tenant_id=p_tenant AND r.id=p_request
$f$;
REVOKE ALL ON FUNCTION leave.request_json(uuid,uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.request_replay(p_tenant uuid,p_actor uuid,p_key text,p_action text,p_hash text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE old leave.request_events%ROWTYPE;
BEGIN
  SELECT * INTO old FROM leave.request_events e WHERE e.tenant_id=p_tenant
    AND e.actor_user_id=p_actor AND e.operation_key=p_key;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF old.event_key IS DISTINCT FROM p_action OR old.payload_hash IS DISTINCT FROM p_hash THEN
    RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505';
  END IF;
  RETURN old.result;
END $f$;
REVOKE ALL ON FUNCTION leave.request_replay(uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.lock_request_configuration(p_tenant uuid,p_employer uuid,p_type uuid,p_start date,p_end date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE calendar_id uuid;
BEGIN
  FOR calendar_id IN SELECT DISTINCT yp.calendar_id FROM leave.year_periods yp
    WHERE yp.tenant_id=p_tenant AND yp.employer_entity_id=p_employer
      AND yp.starts_on<=p_end AND yp.ends_on>=p_start ORDER BY yp.calendar_id LOOP
    PERFORM 1 FROM leave.calendars c WHERE c.tenant_id=p_tenant AND c.id=calendar_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'leave_calendar_unavailable' USING ERRCODE='23503'; END IF;
  END LOOP;
  PERFORM 1 FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=p_type FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503'; END IF;
END $f$;
REVOKE ALL ON FUNCTION leave.lock_request_configuration(uuid,uuid,uuid,date,date) FROM PUBLIC,anon,authenticated,service_role;

ALTER TABLE leave.config_audit_events
  ADD COLUMN operation_key text,
  ADD COLUMN payload_hash text,
  ADD CONSTRAINT config_audit_operation_key_pair CHECK (
    (operation_key IS NULL AND payload_hash IS NULL)
    OR (operation_key IS NOT NULL AND payload_hash IS NOT NULL
        AND length(pg_catalog.btrim(operation_key)) BETWEEN 1 AND 120
        AND payload_hash ~ '^[0-9a-f]{64}$'));
CREATE UNIQUE INDEX leave_config_audit_operation_key
  ON leave.config_audit_events(tenant_id,actor_user_id,operation_key) WHERE operation_key IS NOT NULL;

CREATE FUNCTION public.leave_set_type_active(
  p_tenant uuid,p_type uuid,p_is_active boolean,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employer uuid; old_active boolean; payload jsonb; payload_hash text;
  previous leave.config_audit_events%ROWTYPE; result jsonb;
BEGIN
  IF p_tenant IS NULL OR p_type IS NULL OR p_is_active IS NULL
     OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
     OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_type_activation_input_invalid' USING ERRCODE='22023';
  END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  SELECT t.employer_entity_id INTO employer FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=p_type;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503'; END IF;
  PERFORM 1 FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.id=employer FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  PERFORM 1 FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=p_type FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503'; END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  payload:=pg_catalog.jsonb_build_object('action',CASE WHEN p_is_active THEN 'type.activated' ELSE 'type.deactivated' END,
    'tenant',p_tenant,'type',p_type,'is_active',p_is_active,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  SELECT * INTO previous FROM leave.config_audit_events e
  WHERE e.tenant_id=p_tenant AND e.actor_user_id=actor AND e.operation_key=pg_catalog.btrim(p_idempotency_key);
  IF FOUND THEN
    IF previous.payload_hash IS DISTINCT FROM payload_hash OR previous.action IS DISTINCT FROM
       (CASE WHEN p_is_active THEN 'activated' ELSE 'deactivated' END) THEN
      RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505';
    END IF;
    RETURN previous.details->'result';
  END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',true);
  SELECT t.is_active INTO old_active FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=p_type;
  IF old_active=p_is_active THEN
    result:=pg_catalog.jsonb_build_object('state','unchanged','is_active',old_active,'leave_type_id',p_type);
    RETURN result;
  END IF;
  UPDATE leave.types SET is_active=p_is_active WHERE tenant_id=p_tenant AND id=p_type;
  result:=pg_catalog.jsonb_build_object('state','updated','is_active',p_is_active,'leave_type_id',p_type);
  INSERT INTO leave.config_audit_events(tenant_id,employer_entity_id,object_kind,object_id,action,
    actor_user_id,reason,details,operation_key,payload_hash)
  VALUES(p_tenant,employer,'leave_type',p_type,CASE WHEN p_is_active THEN 'activated' ELSE 'deactivated' END,
    actor,pg_catalog.btrim(p_reason),pg_catalog.jsonb_build_object('is_active',p_is_active,'result',result),
    pg_catalog.btrim(p_idempotency_key),payload_hash);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_set_type_active(uuid,uuid,boolean,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_set_type_active(uuid,uuid,boolean,text,text) TO authenticated;

CREATE FUNCTION public.leave_my_request_options(p_tenant uuid,p_start date,p_end date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employee uuid; employment people.employments%ROWTYPE; types jsonb;
BEGIN
  IF actor IS NULL OR NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
    RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_start IS NULL OR p_end IS NULL OR p_end<p_start OR p_end-p_start>731 THEN
    RAISE EXCEPTION 'leave_request_range_invalid' USING ERRCODE='22023';
  END IF;
  IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',pg_catalog.now())
     OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',pg_catalog.now()) THEN
    RAISE EXCEPTION 'leave_new_work_disabled' USING ERRCODE='55000';
  END IF;
  SELECT l.employee_id INTO employee FROM people.employee_user_links l
  WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
  IF employee IS NULL THEN RAISE EXCEPTION 'leave_self_link_required' USING ERRCODE='42501'; END IF;
  SELECT * INTO employment FROM people.employments e
  WHERE e.tenant_id=p_tenant AND e.employee_id=employee AND e.employment_status='active'
    AND e.start_date<=p_start AND (e.end_date IS NULL OR e.end_date>=p_end)
  ORDER BY e.id LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
  SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',t.id,'code',t.code,'name',t.name,'versions',(
        SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id',v.id,'version',v.version,'effective_from',v.effective_from,'effective_until',v.effective_until,
          'pay_effect',v.pay_effect,'balance_mode',v.balance_mode,'day_count_basis',v.day_count_basis,
          'half_day_allowed',v.half_day_allowed) ORDER BY v.effective_from),'[]'::jsonb)
        FROM leave.type_versions v WHERE v.tenant_id=t.tenant_id AND v.leave_type_id=t.id
          AND v.effective_from<=p_end AND (v.effective_until IS NULL OR v.effective_until>p_start)))
      ORDER BY t.code),'[]'::jsonb)
    INTO types FROM leave.types t
    WHERE t.tenant_id=p_tenant AND t.employer_entity_id=employment.employer_entity_id AND t.is_active
      AND EXISTS(SELECT 1 FROM leave.type_versions v WHERE v.tenant_id=t.tenant_id
        AND v.leave_type_id=t.id AND v.effective_from<=p_end
        AND (v.effective_until IS NULL OR v.effective_until>p_start));
  RETURN pg_catalog.jsonb_build_object('employee_id',employee,'employment_id',employment.id,
    'employer_entity_id',employment.employer_entity_id,'employment_start',employment.start_date,
    'employment_end',employment.end_date,'types',coalesce(types,'[]'::jsonb));
END $f$;
REVOKE ALL ON FUNCTION public.leave_my_request_options(uuid,date,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_request_options(uuid,date,date) TO authenticated;

CREATE FUNCTION public.leave_employee_options(
  p_tenant uuid,p_start date,p_end date,p_query text,p_limit integer DEFAULT 20,p_offset integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); lim integer:=least(50,greatest(1,coalesce(p_limit,20)));
  off integer:=coalesce(p_offset,0); items jsonb; more boolean; q text; pattern text;
BEGIN
  actor:=leave.authorized(p_tenant,'leave.manage',true);
  IF p_start IS NULL OR p_end IS NULL OR p_end<p_start OR p_end-p_start>731
     OR length(pg_catalog.btrim(coalesce(p_query,'')))<2 OR length(pg_catalog.btrim(p_query))>80
     OR off<0 THEN RAISE EXCEPTION 'leave_employee_options_input_invalid' USING ERRCODE='22023'; END IF;
  q:=pg_catalog.lower(pg_catalog.btrim(p_query));
  pattern:='%'||pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(q,'\','\\'),'%','\%'),'_','\_')||'%';
  WITH page AS MATERIALIZED (
    SELECT e.id employee_id,e.employee_code,e.full_name,em.id employment_id,em.employer_entity_id,
      ent.display_name employer_name,em.start_date employment_start,em.end_date employment_end
    FROM people.employees e JOIN people.employments em ON em.tenant_id=e.tenant_id AND em.employee_id=e.id
    JOIN platform_core.tenant_legal_entities ent ON ent.tenant_id=em.tenant_id
      AND ent.id=em.employer_entity_id AND ent.is_active
    WHERE e.tenant_id=p_tenant AND e.workforce_status='active' AND em.employment_status='active'
      AND em.start_date<=p_start AND (em.end_date IS NULL OR em.end_date>=p_end)
      AND (pg_catalog.lower(e.employee_code) LIKE pattern ESCAPE '\'
        OR pg_catalog.lower(e.full_name) LIKE pattern ESCAPE '\')
    ORDER BY e.employee_code,e.id,em.id OFFSET off LIMIT lim+1
  ), numbered AS MATERIALIZED (
    SELECT page.*,row_number() OVER(ORDER BY employee_code,employee_id,employment_id) rn FROM page
  )
  SELECT coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'employee_id',employee_id,'employee_code',employee_code,'employee_name',full_name,
      'employment_id',employment_id,'employer_entity_id',employer_entity_id,'employer_name',employer_name,
      'employment_start',employment_start,'employment_end',employment_end) ORDER BY rn)
      FROM numbered WHERE rn<=lim),'[]'::jsonb),EXISTS(SELECT 1 FROM numbered WHERE rn>lim)
    INTO items,more;
  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'offset',off,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.leave_employee_options(uuid,date,date,text,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_employee_options(uuid,date,date,text,integer,integer) TO authenticated;

CREATE FUNCTION leave.create_submitted_request(
  p_tenant uuid,p_employee uuid,p_employment people.employments,p_type uuid,p_start date,p_end date,
  p_half_day boolean,p_reason text,p_actor uuid,p_source text,p_key text,p_payload_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE preview jsonb; request_id uuid; result jsonb; day jsonb; employer_active boolean;
BEGIN
  IF p_source='employee' THEN
    IF NOT leave.request_actor_allowed(p_tenant,p_actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501';
    END IF;
    IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',pg_catalog.now())
       OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',pg_catalog.now()) THEN
      RAISE EXCEPTION 'leave_new_work_disabled' USING ERRCODE='55000';
    END IF;
  ELSE
    p_actor:=leave.authorized(p_tenant,'leave.manage',true);
  END IF;
  PERFORM leave.request_assert_queue(p_tenant);
  PERFORM leave.lock_request_configuration(p_tenant,p_employment.employer_entity_id,p_type,p_start,p_end);
  IF p_source='employee' THEN
    IF NOT leave.request_actor_allowed(p_tenant,p_actor,'leave.self.request') THEN
      RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501';
    END IF;
  ELSE
    p_actor:=leave.authorized(p_tenant,'leave.manage',true);
  END IF;
  PERFORM leave.request_assert_queue(p_tenant);
  SELECT e.is_active INTO employer_active FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.id=p_employment.employer_entity_id;
  IF NOT coalesce(employer_active,false) THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
  IF NOT EXISTS(SELECT 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=p_employment.id
    AND e.employee_id=p_employee AND e.employer_entity_id=p_employment.employer_entity_id
    AND e.employment_status='active' AND e.start_date<=p_start AND (e.end_date IS NULL OR e.end_date>=p_end)) THEN
    RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514';
  END IF;
  preview:=leave.request_preview(p_tenant,p_employment.employer_entity_id,p_type,p_start,p_end,p_half_day);
  INSERT INTO leave.requests(tenant_id,employee_id,employment_id,employer_entity_id,leave_type_id,
    start_date,end_date,is_half_day,request_source,state,version,current_preview_version,
    created_by,submitted_by,reason,owner_queue)
  VALUES(p_tenant,p_employee,p_employment.id,p_employment.employer_entity_id,p_type,p_start,p_end,
    p_half_day,p_source,'submitted',1,1,p_actor,p_actor,
    pg_catalog.btrim(p_reason),'leave.approval') RETURNING id INTO request_id;
  INSERT INTO leave.request_previews(tenant_id,request_id,preview_version,total_units,created_by)
    VALUES(p_tenant,request_id,1,(preview->>'total_units')::numeric,p_actor);
  FOR day IN SELECT value FROM pg_catalog.jsonb_array_elements(preview->'days') LOOP
    INSERT INTO leave.request_days(tenant_id,request_id,preview_version,leave_date,employer_entity_id,
      year_period_id,calendar_version_id,leave_type_id,type_version_id,day_count_basis,pay_effect,
      balance_mode,is_weekly_rest,holiday_name,eligible,units,is_half_day)
    VALUES(p_tenant,request_id,1,(day->>'leave_date')::date,p_employment.employer_entity_id,
      (day->>'year_period_id')::uuid,(day->>'calendar_version_id')::uuid,p_type,
      (day->>'type_version_id')::uuid,day->>'day_count_basis',day->>'pay_effect',day->>'balance_mode',
      (day->>'is_weekly_rest')::boolean,day->>'holiday_name',(day->>'eligible')::boolean,
      (day->>'units')::numeric,(day->>'is_half_day')::boolean);
  END LOOP;
  result:=leave.request_json(p_tenant,request_id,1);
  INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
    from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,request_id,p_actor,CASE WHEN p_source='employee' THEN 'employee.submitted' ELSE 'hr.recorded_submitted' END,
    NULL,'submitted',NULL,1,pg_catalog.btrim(p_reason),p_key,p_payload_hash,result);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION leave.create_submitted_request(uuid,uuid,people.employments,uuid,date,date,boolean,text,uuid,text,text,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_submit_own_request(
  p_tenant uuid,p_type uuid,p_start date,p_end date,p_half_day boolean,p_half_day_part text,
  p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employee uuid; link_id uuid; linked_employee uuid;
  emp people.employments%ROWTYPE; entity_active boolean; payload jsonb; payload_hash text; replay jsonb;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_type IS NULL OR p_half_day IS NULL
    OR p_start IS NULL OR p_end IS NULL OR p_end<p_start OR p_end-p_start>731
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_request_input_invalid' USING ERRCODE='22023';
  END IF;
  IF p_half_day_part IS NOT NULL THEN RAISE EXCEPTION 'leave_half_day_part_unavailable' USING ERRCODE='23514'; END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
    RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT l.employee_id,l.id INTO employee,link_id FROM people.employee_user_links l
    WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
  IF employee IS NULL THEN RAISE EXCEPTION 'leave_self_link_required' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=employee FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employee_unavailable' USING ERRCODE='23503'; END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501'; END IF;
  SELECT l.employee_id INTO linked_employee FROM people.employee_user_links l
    WHERE l.tenant_id=p_tenant AND l.id=link_id AND l.user_id=actor AND l.unlinked_at IS NULL FOR UPDATE;
  IF linked_employee IS DISTINCT FROM employee THEN RAISE EXCEPTION 'leave_self_link_required' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=employee
    AND e.start_date<=p_end AND (e.end_date IS NULL OR e.end_date>=p_start) ORDER BY e.id FOR UPDATE;
  SELECT * INTO emp FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=employee
    AND e.employment_status='active' AND e.start_date<=p_start AND (e.end_date IS NULL OR e.end_date>=p_end)
    ORDER BY e.id LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
  SELECT e.is_active INTO entity_active FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.id=emp.employer_entity_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501'; END IF;
  payload:=pg_catalog.jsonb_build_object('action','employee.submitted','tenant',p_tenant,
    'employee',employee,'employment',emp.id,'type',p_type,
    'start',p_start,'end',p_end,'half_day',p_half_day,'part',p_half_day_part,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  replay:=leave.request_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),'employee.submitted',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501'; END IF;
  RETURN leave.create_submitted_request(p_tenant,employee,emp,p_type,p_start,p_end,p_half_day,
    pg_catalog.btrim(p_reason),actor,'employee',pg_catalog.btrim(p_idempotency_key),payload_hash);
END $f$;
REVOKE ALL ON FUNCTION public.leave_submit_own_request(uuid,uuid,date,date,boolean,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_submit_own_request(uuid,uuid,date,date,boolean,text,text,text) TO authenticated;

CREATE FUNCTION public.leave_record_hr_request(
  p_tenant uuid,p_employee uuid,p_employment uuid,p_type uuid,p_start date,p_end date,
  p_half_day boolean,p_half_day_part text,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); emp people.employments%ROWTYPE; entity_active boolean;
  payload jsonb; payload_hash text; replay jsonb;
BEGIN
  IF p_tenant IS NULL OR p_employee IS NULL OR p_employment IS NULL OR p_type IS NULL OR p_start IS NULL
    OR p_end IS NULL OR p_end<p_start OR p_end-p_start>731 OR p_half_day IS NULL
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_request_input_invalid' USING ERRCODE='22023';
  END IF;
  IF p_half_day_part IS NOT NULL THEN RAISE EXCEPTION 'leave_half_day_part_unavailable' USING ERRCODE='23514'; END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=p_employee FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employee_unavailable' USING ERRCODE='23503'; END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=p_employee
    AND e.start_date<=p_end AND (e.end_date IS NULL OR e.end_date>=p_start) ORDER BY e.id FOR UPDATE;
  SELECT * INTO emp FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=p_employment
    AND e.employee_id=p_employee AND e.employment_status='active' AND e.start_date<=p_start
    AND (e.end_date IS NULL OR e.end_date>=p_end);
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
  SELECT e.is_active INTO entity_active FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.id=emp.employer_entity_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  actor:=leave.authorized(p_tenant,'leave.manage',false);
  payload:=pg_catalog.jsonb_build_object('action','hr.recorded_submitted','tenant',p_tenant,
    'employee',p_employee,'employment',p_employment,'type',p_type,'start',p_start,'end',p_end,
    'half_day',p_half_day,'part',p_half_day_part,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  replay:=leave.request_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),'hr.recorded_submitted',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  actor:=leave.authorized(p_tenant,'leave.manage',true);
  RETURN leave.create_submitted_request(p_tenant,p_employee,emp,p_type,p_start,p_end,p_half_day,
    pg_catalog.btrim(p_reason),actor,'hr',pg_catalog.btrim(p_idempotency_key),payload_hash);
END $f$;
REVOKE ALL ON FUNCTION public.leave_record_hr_request(uuid,uuid,uuid,uuid,date,date,boolean,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_record_hr_request(uuid,uuid,uuid,uuid,date,date,boolean,text,text,text) TO authenticated;

CREATE FUNCTION public.leave_my_requests(p_tenant uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employee uuid; lim integer:=least(100,greatest(1,coalesce(p_limit,50)));
  off integer:=coalesce(p_offset,0); items jsonb; more boolean;
BEGIN
  IF actor IS NULL OR NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.view') THEN
    RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501';
  END IF;
  IF off<0 THEN RAISE EXCEPTION 'leave_page_invalid' USING ERRCODE='22023'; END IF;
  SELECT l.employee_id INTO employee FROM people.employee_user_links l
    WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
  IF employee IS NULL THEN RAISE EXCEPTION 'leave_self_link_required' USING ERRCODE='42501'; END IF;
  WITH page AS MATERIALIZED (
    SELECT r.id,r.created_at FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.employee_id=employee
      ORDER BY r.created_at DESC,r.id DESC OFFSET off LIMIT lim+1
  ), numbered AS MATERIALIZED (
    SELECT page.id,row_number() OVER(ORDER BY page.created_at DESC,page.id DESC) rn FROM page
  )
  SELECT coalesce((SELECT pg_catalog.jsonb_agg(leave.request_json(p_tenant,id) ORDER BY rn)
    FROM numbered WHERE rn<=lim),'[]'::jsonb),EXISTS(SELECT 1 FROM numbered WHERE rn>lim)
    INTO items,more;
  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'offset',off,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.leave_my_requests(uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_requests(uuid,integer,integer) TO authenticated;

CREATE FUNCTION public.leave_request_detail(p_tenant uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employee uuid; r leave.requests%ROWTYPE;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_request IS NULL THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  IF leave.request_hr_can_read(p_tenant,actor) THEN
    PERFORM leave.authorized(p_tenant,CASE WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.view')
      THEN 'leave.view' WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.manage')
      THEN 'leave.manage' ELSE 'leave.approve' END,false);
  ELSE
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.view') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
    SELECT l.employee_id INTO employee FROM people.employee_user_links l
      WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
  END IF;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request
    AND (leave.request_hr_can_read(p_tenant,actor) OR x.employee_id=employee);
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  RETURN leave.request_json(p_tenant,p_request);
END $f$;
REVOKE ALL ON FUNCTION public.leave_request_detail(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_request_detail(uuid,uuid) TO authenticated;

CREATE FUNCTION public.leave_hr_queue(p_tenant uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); lim integer:=least(100,greatest(1,coalesce(p_limit,50)));
  off integer:=coalesce(p_offset,0); items jsonb; more boolean;
BEGIN
  IF actor IS NULL OR NOT leave.request_hr_can_read(p_tenant,actor) THEN
    RAISE EXCEPTION 'leave_forbidden' USING ERRCODE='42501';
  END IF;
  PERFORM leave.authorized(p_tenant,CASE WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.view')
    THEN 'leave.view' WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.manage')
    THEN 'leave.manage' ELSE 'leave.approve' END,false);
  IF off<0 THEN RAISE EXCEPTION 'leave_page_invalid' USING ERRCODE='22023'; END IF;
  WITH page AS MATERIALIZED (
    SELECT r.id,r.submitted_at FROM leave.requests r WHERE r.tenant_id=p_tenant AND r.state='submitted'
    ORDER BY r.submitted_at,r.id OFFSET off LIMIT lim+1
  ), numbered AS MATERIALIZED (
    SELECT page.id,row_number() OVER(ORDER BY page.submitted_at,page.id) rn FROM page
  )
  SELECT coalesce((SELECT pg_catalog.jsonb_agg(leave.request_json(p_tenant,id) ORDER BY rn)
    FROM numbered WHERE rn<=lim),'[]'::jsonb),EXISTS(SELECT 1 FROM numbered WHERE rn>lim)
    INTO items,more;
  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'offset',off,'has_more',more);
END $f$;
REVOKE ALL ON FUNCTION public.leave_hr_queue(uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_hr_queue(uuid,integer,integer) TO authenticated;

CREATE FUNCTION public.leave_withdraw_own_request(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; emp people.employments%ROWTYPE;
  employee uuid; linked_employee uuid; employer_active boolean; payload jsonb; payload_hash text; replay jsonb; result jsonb;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_request IS NULL OR p_expected_version IS NULL OR p_expected_version<=0
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_withdraw_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  employee:=r.employee_id;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=employee FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  SELECT l.employee_id INTO linked_employee FROM people.employee_user_links l
    WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL FOR UPDATE;
  IF linked_employee IS DISTINCT FROM employee THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=employee
    AND e.start_date<=r.end_date AND (e.end_date IS NULL OR e.end_date>=r.start_date) ORDER BY e.id FOR UPDATE;
  SELECT * INTO emp FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=r.employment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=p_tenant AND e.id=emp.employer_entity_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  payload:=pg_catalog.jsonb_build_object('action','employee.withdrawn','tenant',p_tenant,'request',p_request,
    'version',p_expected_version,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  replay:=leave.request_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),'employee.withdrawn',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM leave.lock_request_configuration(p_tenant,emp.employer_entity_id,r.leave_type_id,r.start_date,r.end_date);
  PERFORM 1 FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request FOR UPDATE;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request AND x.employee_id=employee;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  IF r.state<>'submitted' THEN RAISE EXCEPTION 'leave_request_not_withdrawable' USING ERRCODE='23514'; END IF;
  IF r.version<>p_expected_version THEN RAISE EXCEPTION 'leave_request_version_conflict' USING ERRCODE='40001'; END IF;
  UPDATE leave.requests SET state='withdrawn',version=version+1 WHERE tenant_id=p_tenant AND id=p_request;
  result:=leave.request_json(p_tenant,p_request);
  INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
    from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,p_request,actor,'employee.withdrawn','submitted','withdrawn',r.version,r.version+1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_withdraw_own_request(uuid,uuid,integer,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_withdraw_own_request(uuid,uuid,integer,text,text) TO authenticated;

CREATE FUNCTION public.leave_reject_request(
  p_tenant uuid,p_request uuid,p_expected_version integer,p_reason text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; emp people.employments%ROWTYPE;
  employer_active boolean; payload jsonb; payload_hash text; replay jsonb; result jsonb;
BEGIN
  IF p_tenant IS NULL OR p_request IS NULL OR p_expected_version IS NULL OR p_expected_version<=0
    OR length(pg_catalog.btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500
    OR length(pg_catalog.btrim(coalesce(p_idempotency_key,''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'leave_reject_input_invalid' USING ERRCODE='22023';
  END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=r.employee_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  PERFORM 1 FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=r.employee_id
    AND e.start_date<=r.end_date AND (e.end_date IS NULL OR e.end_date>=r.start_date) ORDER BY e.id FOR UPDATE;
  SELECT * INTO emp FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=r.employment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  PERFORM 1 FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=p_tenant AND e.id=emp.employer_entity_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_tenant::text||':'||actor::text||':'||pg_catalog.btrim(p_idempotency_key),90432));
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  payload:=pg_catalog.jsonb_build_object('action','hr.rejected','tenant',p_tenant,'request',p_request,
    'version',p_expected_version,'reason',pg_catalog.btrim(p_reason));
  payload_hash:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(payload::text,'UTF8')),'hex');
  replay:=leave.request_replay(p_tenant,actor,pg_catalog.btrim(p_idempotency_key),'hr.rejected',payload_hash);
  IF replay IS NOT NULL THEN RETURN replay; END IF;
  actor:=leave.authorized(p_tenant,'leave.approve',false);
  PERFORM leave.lock_request_configuration(p_tenant,emp.employer_entity_id,r.leave_type_id,r.start_date,r.end_date);
  PERFORM 1 FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request FOR UPDATE;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  IF r.state<>'submitted' THEN RAISE EXCEPTION 'leave_request_not_rejectable' USING ERRCODE='23514'; END IF;
  IF r.version<>p_expected_version THEN RAISE EXCEPTION 'leave_request_version_conflict' USING ERRCODE='40001'; END IF;
  UPDATE leave.requests SET state='rejected',version=version+1 WHERE tenant_id=p_tenant AND id=p_request;
  result:=leave.request_json(p_tenant,p_request);
  INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,
    from_version,to_version,reason,operation_key,payload_hash,result)
  VALUES(p_tenant,p_request,actor,'hr.rejected','submitted','rejected',r.version,r.version+1,
    pg_catalog.btrim(p_reason),pg_catalog.btrim(p_idempotency_key),payload_hash,result);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_reject_request(uuid,uuid,integer,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_reject_request(uuid,uuid,integer,text,text) TO authenticated;
