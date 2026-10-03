-- Cube4: private observation bridge for a changed source already bound to a
-- final output.  This is evidence and responsibility only.  It deliberately
-- does not create a case, proposal, amount, ledger entry, amendment, payment,
-- or replacement output.
--
-- Hook/lock review:
--   * Time: deferred INSERT on fact/interpretation/overtime events and W status.
--     The observer reads the current WorkInstance/fact/interpretation set and
--     serializes only exact immutable binding rows in output/date/key order.
--     Existing Time writers retain their Employment ->
--     WorkInstance order; this bridge adds no W -> People/Employer/Payroll
--     head edge and no employer-wide/advisory lock. Binding replay readers
--     acquire no reverse source lock. Full append race graph still requires QA.
--   * Leave: DEFERRABLE AFTER UPDATE on requests, after the request's
--     cancellation/supersession event has been written.  It reads the event
--     envelope and approved day only.  It does not read or write the Leave
--     ledger and does not call a Payroll-permission capture helper.
--
-- This protects the observed authoritative writers listed above.  Other
-- historical/direct privileged writers and an append-versus-final-output race
-- are intentionally not claimed closed by this bounded bridge; the next
-- integration stage must qualify those paths.

CREATE TABLE payroll.bound_source_correction_observations(
  tenant_id uuid NOT NULL,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employer_id uuid NOT NULL,
  output_id uuid NOT NULL,
  period_id uuid NOT NULL,
  employment_id uuid NOT NULL,
  source_domain text NOT NULL CHECK(source_domain IN('time','leave')),
  source_date date NOT NULL,
  source_key text NOT NULL,
  original_binding_digest text NOT NULL CHECK(length(original_binding_digest)=64),
  original_binding_identity jsonb NOT NULL,
  original_binding_version jsonb NOT NULL,
  current_source_identity jsonb NOT NULL,
  current_source_version jsonb NOT NULL,
  current_source_lineage jsonb NOT NULL,
  current_lineage_fingerprint text NOT NULL CHECK(length(current_lineage_fingerprint)=64),
  source_actor uuid NOT NULL REFERENCES auth.users(id),
  requirement_id uuid NOT NULL,
  current_event_fingerprint text NOT NULL CHECK(length(current_event_fingerprint)=64),
  transaction_id xid8 NOT NULL DEFAULT pg_current_xact_id(),
  backend_pid integer NOT NULL DEFAULT pg_backend_pid(),
  observed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  PRIMARY KEY(tenant_id,id),
  UNIQUE(tenant_id,output_id,source_domain,source_date,source_key,current_event_fingerprint),
  FOREIGN KEY(tenant_id,employer_id,output_id) REFERENCES payroll.final_contexts(tenant_id,employer_id,id),
  FOREIGN KEY(tenant_id,output_id,employment_id) REFERENCES payroll.final_employees(tenant_id,output_id,employment_id),
  FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id),
  FOREIGN KEY(tenant_id,output_id,source_domain,source_date,source_key)
    REFERENCES payroll.final_source_bindings(tenant_id,output_id,source_domain,source_date,source_key),
  FOREIGN KEY(tenant_id,requirement_id) REFERENCES payroll.correction_requirements(tenant_id,id)
);
ALTER TABLE payroll.bound_source_correction_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.bound_source_correction_observations FORCE ROW LEVEL SECURITY;
CREATE TRIGGER payroll_bound_source_observation_immutable
  BEFORE UPDATE OR DELETE ON payroll.bound_source_correction_observations
  FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
REVOKE ALL ON payroll.bound_source_correction_observations FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.observe_bound_source_event(
  p_tenant uuid,p_domain text,p_source_date date,p_source_identity_key uuid,
  p_source_actor uuid,p_current_identity jsonb,p_current_version jsonb,
  p_current_lineage jsonb,p_event_fingerprint text,p_validity_changed boolean
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE b payroll.final_source_bindings%ROWTYPE; req uuid; reason text;
BEGIN
  IF p_domain NOT IN('time','leave') OR p_source_identity_key IS NULL
     OR p_event_fingerprint IS NULL THEN RAISE EXCEPTION 'cube4_source_event_invalid' USING ERRCODE='22023'; END IF;

  FOR b IN
    SELECT x.* FROM payroll.final_source_bindings x
    WHERE x.tenant_id=p_tenant AND x.source_domain=p_domain
      AND x.source_date=p_source_date
      AND (x.source_identity->>CASE WHEN p_domain='time' THEN 'work_instance_id' ELSE 'request_id' END)=p_source_identity_key::text
      -- A replacement output owns the next responsibility; do not observe the
      -- historical output a successor has already superseded.
      AND NOT EXISTS(SELECT 1 FROM payroll.output_successions s
        WHERE s.tenant_id=x.tenant_id AND s.original_output=x.output_id)
    ORDER BY x.output_id,x.source_date,x.source_key
    FOR UPDATE OF x
  LOOP
    -- Identity and version are compared against their exact binding shapes;
    -- an unrelated current-event envelope must not make an unchanged binding
    -- stale.  This is also the duplicate fast path, before any requirement
    -- insert.
    IF NOT (
      b.source_identity IS DISTINCT FROM p_current_identity
      OR b.source_version IS DISTINCT FROM p_current_version
      OR (p_domain='time' AND b.captured_payload->'overtime' IS DISTINCT FROM p_current_lineage->'overtime')
      OR p_validity_changed
    ) OR EXISTS(
      SELECT 1 FROM payroll.bound_source_correction_observations o
      WHERE o.tenant_id=b.tenant_id AND o.output_id=b.output_id
        AND o.source_domain=b.source_domain AND o.source_date=b.source_date
        AND o.source_key=b.source_key AND o.current_event_fingerprint=p_event_fingerprint)
    THEN CONTINUE; END IF;
    -- A source actor is required only after an exact affected binding exists.
    IF auth.uid() IS NULL OR p_source_actor IS NULL OR p_source_actor IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'cube4_source_actor_required' USING ERRCODE='42501'; END IF;
    reason:='تغير مصدر حضور أو إجازة مرتبط بهذا المسير؛ يلزم مراجعة التصحيح.';
    INSERT INTO payroll.correction_requirements(tenant_id,employer_id,employment_id,period_id,reason,requested_by)
    VALUES(b.tenant_id,b.employer_id,b.employment_id,b.period_id,reason,p_source_actor) RETURNING id INTO req;
    INSERT INTO payroll.bound_source_correction_observations(
      tenant_id,employer_id,output_id,period_id,employment_id,source_domain,
      source_date,source_key,original_binding_digest,original_binding_identity,
      original_binding_version,current_source_identity,current_source_version,current_source_lineage,current_lineage_fingerprint,
      source_actor,requirement_id,current_event_fingerprint)
    VALUES(b.tenant_id,b.employer_id,b.output_id,b.period_id,b.employment_id,b.source_domain,
      b.source_date,b.source_key,b.captured_digest,b.source_identity,b.source_version,
      p_current_identity,p_current_version,p_current_lineage,encode(extensions.digest(p_current_lineage::text,'sha256'),'hex'),
      p_source_actor,req,p_event_fingerprint)
    ;
  END LOOP;
END $f$;
REVOKE ALL ON FUNCTION payroll.observe_bound_source_event(uuid,text,date,uuid,uuid,jsonb,jsonb,jsonb,text,boolean)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.observe_time_work_instance(p_tenant uuid,p_instance uuid,p_source_actor uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE i time.work_instances%ROWTYPE; f time.attendance_facts%ROWTYPE;
  q time.interpretations%ROWTYPE; overtime jsonb; version jsonb; lineage jsonb; fp text;
BEGIN
  SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_instance;
  SELECT * INTO f FROM time.attendance_facts WHERE tenant_id=p_tenant AND work_instance_id=p_instance
    ORDER BY version DESC,id DESC LIMIT 1;
  SELECT * INTO q FROM time.interpretations WHERE tenant_id=p_tenant AND id=f.interpretation_id;
  IF i.id IS NULL OR f.id IS NULL OR q.id IS NULL THEN RETURN; END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('candidate_id',c.id,'minutes',c.candidate_minutes,
      'review_event_id',rv.id,'decision',COALESCE(rv.decision,'pending'),
      'classification_id',cl.id,'classification_version',cl.version,
      'ordinary_day_minutes',cl.ordinary_day_minutes,'ordinary_night_minutes',cl.ordinary_night_minutes,
      'weekly_rest_minutes',cl.weekly_rest_minutes,'official_holiday_minutes',cl.official_holiday_minutes)
      ORDER BY c.id),'[]'::jsonb) INTO overtime
    FROM time.attendance_overtime_candidates c
    LEFT JOIN time.attendance_overtime_review_events rv ON rv.tenant_id=c.tenant_id AND rv.candidate_id=c.id
    LEFT JOIN LATERAL(SELECT x.* FROM time.attendance_overtime_classification_events x
      WHERE x.tenant_id=c.tenant_id AND x.candidate_id=c.id ORDER BY x.version DESC LIMIT 1) cl ON true
    WHERE c.tenant_id=p_tenant AND c.work_instance_id=i.id AND c.attendance_fact_id=f.id;
  version:=jsonb_build_object('fact_version',f.version,'interpretation_version',q.version);
  lineage:=jsonb_build_object('work_instance_id',i.id,'operational_date',i.operational_date,
    'fact_id',f.id,'fact_version',f.version,'interpretation_id',q.id,'interpretation_version',q.version,
    'corrects_fact_id',f.corrects_fact_id,'fact',f.fact,'work_instance_status',i.status,'interpretation_state',q.state,'overtime',overtime);
  fp:=encode(extensions.digest(lineage::text,'sha256'),'hex');
  PERFORM payroll.observe_bound_source_event(p_tenant,'time',i.operational_date,i.id,
    p_source_actor,jsonb_build_object('work_instance_id',i.id,'fact_id',f.id,'interpretation_id',q.id),
    version,lineage,fp,i.status<>'approved' OR q.state<>'ready');
END $f$;
REVOKE ALL ON FUNCTION payroll.observe_time_work_instance(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.observe_time_source_append() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE wi uuid; actor uuid;
BEGIN
  IF TG_TABLE_NAME='work_instances' THEN wi:=NEW.id; actor:=auth.uid();
  ELSIF TG_TABLE_NAME='attendance_overtime_candidates' THEN wi:=NEW.work_instance_id; actor:=NEW.actor_user_id;
  ELSIF TG_TABLE_NAME IN('attendance_overtime_review_events','attendance_overtime_classification_events') THEN
    SELECT c.work_instance_id INTO wi FROM time.attendance_overtime_candidates c
      WHERE c.tenant_id=NEW.tenant_id AND c.id=NEW.candidate_id;
    actor:=NEW.actor_user_id;
  ELSE
    wi:=NEW.work_instance_id;
    IF TG_TABLE_NAME='attendance_facts' THEN actor:=NEW.actor_user_id;
    ELSE actor:=NEW.created_by; END IF;
  END IF;
  PERFORM payroll.observe_time_work_instance(NEW.tenant_id,wi,actor);
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION payroll.observe_time_source_append() FROM PUBLIC,anon,authenticated,service_role;
-- Deferred hooks observe the coherent command tail, after overtime candidate
-- creation and any same-command review/classification append.
CREATE CONSTRAINT TRIGGER payroll_observe_time_interpretation_append
  AFTER INSERT ON time.interpretations DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION payroll.observe_time_source_append();
CREATE CONSTRAINT TRIGGER payroll_observe_time_fact_append
  AFTER INSERT ON time.attendance_facts DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION payroll.observe_time_source_append();
CREATE CONSTRAINT TRIGGER payroll_observe_time_overtime_candidate_append
  AFTER INSERT ON time.attendance_overtime_candidates DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION payroll.observe_time_source_append();
CREATE CONSTRAINT TRIGGER payroll_observe_time_overtime_review_append
  AFTER INSERT ON time.attendance_overtime_review_events DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION payroll.observe_time_source_append();
CREATE CONSTRAINT TRIGGER payroll_observe_time_overtime_classification_append
  AFTER INSERT ON time.attendance_overtime_classification_events DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION payroll.observe_time_source_append();

CREATE CONSTRAINT TRIGGER payroll_observe_time_work_instance_status
  AFTER UPDATE OF status ON time.work_instances DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION payroll.observe_time_source_append();

CREATE FUNCTION payroll.observe_leave_source_transition() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE d record; ev record; correction record; version jsonb; lineage jsonb; fp text; actor uuid;
BEGIN
  IF NEW.state NOT IN('cancelled','superseded') OR OLD.state='cancelled' OR OLD.state='superseded' THEN RETURN NEW; END IF;
  SELECT x.* INTO ev FROM leave.cancellation_events x
    WHERE x.tenant_id=NEW.tenant_id AND x.request_id=NEW.id
      AND ((x.event_key='hr.direct_cancelled' AND x.to_state='cancelled') OR (x.event_key='hr.accepted' AND x.to_state='accepted'))
      ORDER BY x.to_version DESC,x.id DESC LIMIT 1;
  SELECT x.* INTO correction FROM leave.correction_events x
    WHERE x.tenant_id=NEW.tenant_id AND x.original_request_id=NEW.id
    AND x.event_key='hr.corrected' AND x.to_state='superseded'
    ORDER BY x.original_to_version DESC,x.id DESC LIMIT 1;
  actor:=COALESCE(ev.actor_user_id,correction.actor_user_id);

  FOR d IN SELECT x.* FROM leave.request_days x
    WHERE x.tenant_id=NEW.tenant_id AND x.request_id=NEW.id
      AND x.preview_version=NEW.approved_preview_version
  LOOP
    version:=jsonb_build_object('request_version',NEW.version,
      'approved_preview_version',NEW.approved_preview_version);
    -- Leave state is an authoritative validity boundary, while request/date
    -- identity remains the original binding identity.
    lineage:=jsonb_build_object('request_id',NEW.id,'employee_id',NEW.employee_id,
      'employment_id',NEW.employment_id,'employer_id',NEW.employer_entity_id,
      'date',d.leave_date,'original_units',d.units,'effective_units',0,
      'state',NEW.state,'cancellation_event_id',ev.id,'cancellation_id',ev.cancellation_id,
      'correction_id',correction.correction_id,'replacement_request_id',correction.replacement_request_id,
      'request_event_version',NEW.version);
    fp:=encode(extensions.digest(lineage::text,'sha256'),'hex');
    PERFORM payroll.observe_bound_source_event(NEW.tenant_id,'leave',d.leave_date,NEW.id,
      actor,jsonb_build_object('request_id',NEW.id,'date',d.leave_date),version,lineage,fp,true);
  END LOOP;
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION payroll.observe_leave_source_transition() FROM PUBLIC,anon,authenticated,service_role;
CREATE CONSTRAINT TRIGGER payroll_observe_leave_request_transition
  AFTER UPDATE OF state,version,approved_preview_version ON leave.requests
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  WHEN (OLD.state='approved' AND NEW.state IN('cancelled','superseded'))
  EXECUTE FUNCTION payroll.observe_leave_source_transition();
