-- Explicit historical Leave admission, with factual correction obligations.
-- No synthetic final-source binding, amount, financial approval or G6 release.
CREATE TABLE payroll.historical_leave_admissions(
 tenant_id uuid NOT NULL,request_id uuid NOT NULL,approved_preview_version integer NOT NULL,
 approved_request_version integer NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 3 AND 500),
 operation_key text NOT NULL,created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 PRIMARY KEY(tenant_id,request_id),
 FOREIGN KEY(tenant_id,request_id) REFERENCES leave.requests(tenant_id,id)
);
ALTER TABLE payroll.historical_leave_admissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.historical_leave_admissions FORCE ROW LEVEL SECURITY;
CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.historical_leave_admissions
 FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
REVOKE ALL ON payroll.historical_leave_admissions FROM PUBLIC,anon,authenticated,service_role;

-- Same evidence shape, distinct origin: its absence snapshot is not a binding.
CREATE TABLE payroll.historical_leave_observations(
 LIKE payroll.bound_source_correction_observations INCLUDING DEFAULTS INCLUDING CONSTRAINTS,
 PRIMARY KEY(tenant_id,id),
 UNIQUE(tenant_id,output_id,source_domain,source_date,source_key,current_event_fingerprint),
 FOREIGN KEY(tenant_id,employer_id,output_id) REFERENCES payroll.final_contexts(tenant_id,employer_id,id),
 FOREIGN KEY(tenant_id,output_id,employment_id) REFERENCES payroll.final_employees(tenant_id,output_id,employment_id),
 FOREIGN KEY(tenant_id,requirement_id) REFERENCES payroll.correction_requirements(tenant_id,id),
 CHECK(source_domain='leave' AND original_binding_identity->>'origin'='historical_addition')
);
ALTER TABLE payroll.historical_leave_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.historical_leave_observations FORCE ROW LEVEL SECURITY;
CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.historical_leave_observations
 FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
REVOKE ALL ON payroll.historical_leave_observations FROM PUBLIC,anon,authenticated,service_role;
CREATE VIEW payroll.source_correction_observations AS
 SELECT * FROM payroll.bound_source_correction_observations
 UNION ALL SELECT * FROM payroll.historical_leave_observations;
REVOKE ALL ON payroll.source_correction_observations FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.observe_historical_leave(p_tenant uuid,p_request uuid,p_actor uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE request leave.requests%ROWTYPE; item record; envelope jsonb; prior payroll.historical_leave_observations%ROWTYPE;
 identity jsonb; version jsonb; digest text; requirement uuid; key text;
BEGIN
 SELECT * INTO request FROM leave.requests WHERE tenant_id=p_tenant AND id=p_request;
 IF request.id IS NULL OR request.state NOT IN('approved','cancelled','superseded') THEN RETURN;END IF;
 IF auth.uid() IS NULL OR p_actor IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'cube4_source_actor_required' USING ERRCODE='42501';END IF;
 FOR item IN
  SELECT context.id output_id,context.period_id,day_row.leave_date
  FROM leave.request_days day_row
  JOIN payroll.final_employees employee ON employee.tenant_id=p_tenant
   AND employee.employer_id=request.employer_entity_id AND employee.employment_id=request.employment_id
  JOIN payroll.final_contexts context ON context.tenant_id=employee.tenant_id AND context.id=employee.output_id
  CROSS JOIN LATERAL jsonb_array_elements(context.manifest->'employees') member
  WHERE day_row.tenant_id=p_tenant AND day_row.request_id=p_request
   AND day_row.preview_version=request.approved_preview_version
   AND context.manifest->'optional'->>'leave'='true'
   AND member->'employment'->>'id'=request.employment_id::text
   AND day_row.leave_date BETWEEN greatest((context.manifest->'period'->>'starts_on')::date,(member->'employment'->>'start_date')::date)
    AND least((context.manifest->'period'->>'ends_on')::date,COALESCE((member->'employment'->>'end_date')::date,(context.manifest->'period'->>'ends_on')::date))
   AND NOT EXISTS(SELECT 1 FROM payroll.output_successions succession WHERE succession.tenant_id=p_tenant AND succession.original_output=context.id)
   AND NOT EXISTS(SELECT 1 FROM payroll.final_source_bindings binding WHERE binding.tenant_id=p_tenant AND binding.output_id=context.id
    AND binding.source_domain='leave' AND binding.source_date=day_row.leave_date AND binding.source_identity->>'request_id'=p_request::text)
  ORDER BY context.id,day_row.leave_date
 LOOP
  key:='historical-leave:'||p_request::text||':'||item.leave_date::text;
  envelope:=payroll.bound_source_envelope(p_tenant,'leave',item.leave_date,p_request);
  IF envelope IS NULL THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
  IF EXISTS(SELECT 1 FROM payroll.historical_leave_observations observation WHERE observation.tenant_id=p_tenant
   AND observation.output_id=item.output_id AND observation.source_key=key AND observation.current_event_fingerprint=envelope->>'fingerprint') THEN CONTINUE;END IF;
  SELECT * INTO prior FROM payroll.historical_leave_observations observation WHERE observation.tenant_id=p_tenant
   AND observation.output_id=item.output_id AND observation.source_key=key ORDER BY observed_at,id LIMIT 1;
  identity:=COALESCE(prior.original_binding_identity,jsonb_build_object('origin','historical_addition','request_id',p_request,'date',item.leave_date,'absent_from_output',item.output_id));
  version:=COALESCE(prior.original_binding_version,jsonb_build_object('origin','historical_addition','admitted_preview',request.approved_preview_version));
  digest:=COALESCE(prior.original_binding_digest,encode(extensions.digest(jsonb_build_object('identity',identity,'version',version)::text,'sha256'),'hex'));
  INSERT INTO payroll.correction_requirements(tenant_id,employer_id,employment_id,period_id,reason,requested_by)
   VALUES(p_tenant,request.employer_entity_id,request.employment_id,item.period_id,'إضافة أو تغيير إجازة تاريخية بعد إقفال المسير؛ يلزم تصحيح أثرها.',p_actor) RETURNING id INTO requirement;
  INSERT INTO payroll.historical_leave_observations(tenant_id,employer_id,output_id,period_id,employment_id,source_domain,source_date,source_key,
   original_binding_digest,original_binding_identity,original_binding_version,current_source_identity,current_source_version,current_source_lineage,
   current_lineage_fingerprint,source_actor,requirement_id,current_event_fingerprint)
  VALUES(p_tenant,request.employer_entity_id,item.output_id,item.period_id,request.employment_id,'leave',item.leave_date,key,digest,identity,version,
   envelope->'identity',envelope->'version',envelope->'lineage',envelope->>'fingerprint',p_actor,requirement,envelope->>'fingerprint');
 END LOOP;
END $f$;
REVOKE ALL ON FUNCTION payroll.observe_historical_leave(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

-- Reuse the established approval validation/locking/receipt protocol. The new
-- intent differs in its payload hash; an ordinary approval key cannot replay it.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('public.leave_approve_request(uuid,uuid,integer,integer,text,text)'::regprocedure);
 definition:=replace(definition,'FUNCTION public.leave_approve_request(','FUNCTION public.leave_approve_historical_request(');
 anchor:='''reason'',pg_catalog.btrim(p_reason));';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_historical_approval_payload_anchor';END IF;
 definition:=replace(definition,anchor,'''reason'',pg_catalog.btrim(p_reason),''historical_payroll_correction'',true);');
 anchor:='UPDATE leave.requests SET state=''approved'',version=version+1,';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_historical_approval_state_anchor';END IF;
 definition:=replace(definition,anchor,
  'INSERT INTO payroll.historical_leave_admissions(tenant_id,request_id,approved_preview_version,approved_request_version,actor_id,reason,operation_key)
   VALUES(p_tenant,r.id,r.current_preview_version,r.version+1,actor,btrim(p_reason),btrim(p_idempotency_key)); '||anchor);
 EXECUTE definition;
END $patch$;
REVOKE ALL ON FUNCTION public.leave_approve_historical_request(uuid,uuid,integer,integer,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_approve_historical_request(uuid,uuid,integer,integer,text,text) TO authenticated;

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.guard_unbound_leave_approval()'::regprocedure);
 anchor:=' IF EXISTS(
  SELECT 1 FROM leave.request_days day_row';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_historical_guard_anchor';END IF;
 EXECUTE replace(definition,anchor,
  ' IF EXISTS(SELECT 1 FROM payroll.historical_leave_admissions admission WHERE admission.tenant_id=NEW.tenant_id AND admission.request_id=NEW.id
    AND admission.approved_preview_version=NEW.approved_preview_version AND admission.approved_request_version=NEW.version AND admission.actor_id=auth.uid()) THEN
    PERFORM payroll.observe_historical_leave(NEW.tenant_id,NEW.id,auth.uid()); RETURN NEW;END IF;'||anchor);
 definition:=pg_get_functiondef('payroll.observe_leave_source_transition()'::regprocedure);
 anchor:=' FOR day_row IN SELECT leave_date';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_historical_transition_anchor';END IF;
 EXECUTE replace(definition,anchor,' PERFORM payroll.observe_historical_leave(NEW.tenant_id,NEW.id,auth.uid());'||anchor);
END $patch$;

-- Restrict addition capture on later transitions to genuinely admitted requests.
-- Existing bound-source observers retain their original binding semantics.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.observe_historical_leave(uuid,uuid,uuid)'::regprocedure);
 anchor:=' SELECT * INTO request FROM leave.requests';
 EXECUTE replace(definition,anchor,' IF NOT EXISTS(SELECT 1 FROM payroll.historical_leave_admissions WHERE tenant_id=p_tenant AND request_id=p_request) THEN RETURN;END IF;'||anchor);
END $patch$;

-- Additions feed the existing source_change compiler, authority, paid/unpaid
-- routing, currentness and UI choices. Existing immutable binding rows stay put.
DO $patch$ DECLARE item record;definition text;BEGIN
 FOR item IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE (n.nspname='payroll' AND p.proname IN('compile_bound_source_observation','lock_correction_observation_sources','assert_correction_observations_current','correction_observation_covers_requirement','correction_requirement_is_current'))
   OR (n.nspname='public' AND p.proname IN('payroll_correction_proposal','payroll_correction_workspace','payroll_correction_choices','payroll_correction_reconcile'))
 LOOP
  definition:=pg_get_functiondef(item.oid);
  IF position('FROM payroll.bound_source_correction_observations' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_historical_observation_reader_anchor:%',item.oid::regprocedure;END IF;
  definition:=replace(definition,'FROM payroll.bound_source_correction_observations','FROM payroll.source_correction_observations');
  definition:=replace(definition,'JOIN payroll.bound_source_correction_observations','JOIN payroll.source_correction_observations');
  EXECUTE definition;
 END LOOP;
END $patch$;

CREATE OR REPLACE FUNCTION payroll.correction_observation_outputs(p_observation payroll.bound_source_correction_observations)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 WITH exact_outputs AS(
  SELECT binding.output_id FROM payroll.final_source_bindings binding
  WHERE binding.tenant_id=p_observation.tenant_id AND binding.employer_id=p_observation.employer_id
   AND binding.employment_id=p_observation.employment_id AND binding.source_domain=p_observation.source_domain
   AND binding.source_date=p_observation.source_date AND binding.source_key=p_observation.source_key
   AND binding.source_identity IS NOT DISTINCT FROM p_observation.original_binding_identity
   AND binding.source_version IS NOT DISTINCT FROM p_observation.original_binding_version
   AND binding.captured_digest=p_observation.original_binding_digest
  UNION
  SELECT observation.output_id FROM payroll.historical_leave_observations observation
  WHERE observation.tenant_id=p_observation.tenant_id AND observation.id=p_observation.id
   AND observation.employer_id=p_observation.employer_id AND observation.employment_id=p_observation.employment_id
   AND observation.original_binding_digest=p_observation.original_binding_digest
   AND observation.original_binding_identity=p_observation.original_binding_identity
   AND observation.original_binding_version=p_observation.original_binding_version
 )
 SELECT COALESCE(jsonb_agg(jsonb_build_object('id',context.id,'employer_id',context.employer_id,'period_id',context.period_id,
  'starts_on',period.starts_on,'ends_on',period.ends_on,'ever_paid',payroll.output_has_ever_paid(context.tenant_id,context.id)) ORDER BY context.id),'[]'::jsonb)
 FROM exact_outputs exact_output
 JOIN payroll.final_contexts context ON context.tenant_id=p_observation.tenant_id AND context.id=exact_output.output_id
 JOIN payroll.periods period ON period.tenant_id=context.tenant_id AND period.id=context.period_id
 WHERE NOT EXISTS(SELECT 1 FROM payroll.output_successions succession WHERE succession.tenant_id=context.tenant_id AND succession.original_output=context.id)
$f$;
CREATE FUNCTION payroll.correction_observation_outputs(p_observation payroll.source_correction_observations)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT payroll.correction_observation_outputs(jsonb_populate_record(NULL::payroll.bound_source_correction_observations,to_jsonb(p_observation)))
$f$;
REVOKE ALL ON FUNCTION payroll.correction_observation_outputs(payroll.source_correction_observations)
 FROM PUBLIC,anon,authenticated,service_role;
