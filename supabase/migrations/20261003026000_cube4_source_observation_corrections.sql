-- Cube4: consume an immutable bound Time/Leave observation through the existing
-- governed correction route. OBSERVE is reference/proof only: it never mutates
-- Time, Leave, the observation, the original output, or its source bindings.
--
-- Lock graph retained by this additive bridge:
--   correction/finalization H prefix -> exact Time W (operational_date,id) ->
--   correction rows. Leave approve/cancel/correct already takes the relevant H
--   parent locks, so no request-before-H edge is added. Observer transactions
--   retain their existing W/request -> immutable binding(output,date,key) edge.
-- Full append/writer interleavings remain a later qualification obligation.

-- One canonical private reader is used both by observation producers and by
-- proposal currentness. Capability state is intentionally not source state.
CREATE FUNCTION payroll.bound_source_envelope(
  p_tenant uuid,p_domain text,p_source_date date,p_source_id uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE i time.work_instances%ROWTYPE; fact time.attendance_facts%ROWTYPE;
 interpretation time.interpretations%ROWTYPE; request leave.requests%ROWTYPE;
 day_row leave.request_days%ROWTYPE; cancellation record; correction record;
 overtime jsonb; identity jsonb; version jsonb; lineage jsonb; actor uuid;
BEGIN
 IF p_domain='time' THEN
  SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_source_id AND operational_date=p_source_date;
  SELECT * INTO fact FROM time.attendance_facts WHERE tenant_id=p_tenant AND work_instance_id=p_source_id ORDER BY version DESC,id DESC LIMIT 1;
  SELECT * INTO interpretation FROM time.interpretations WHERE tenant_id=p_tenant AND id=fact.interpretation_id AND work_instance_id=p_source_id;
  IF i.id IS NULL OR fact.id IS NULL OR interpretation.id IS NULL THEN RETURN NULL;END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('candidate_id',candidate.id,'minutes',candidate.candidate_minutes,
    'review_event_id',review.id,'decision',COALESCE(review.decision,'pending'),
    'classification_id',classification.id,'classification_version',classification.version,
    'ordinary_day_minutes',classification.ordinary_day_minutes,'ordinary_night_minutes',classification.ordinary_night_minutes,
    'weekly_rest_minutes',classification.weekly_rest_minutes,'official_holiday_minutes',classification.official_holiday_minutes)
    ORDER BY candidate.id),'[]'::jsonb) INTO overtime
   FROM time.attendance_overtime_candidates candidate
   LEFT JOIN time.attendance_overtime_review_events review ON review.tenant_id=candidate.tenant_id AND review.candidate_id=candidate.id
   LEFT JOIN LATERAL(SELECT x.* FROM time.attendance_overtime_classification_events x WHERE x.tenant_id=candidate.tenant_id AND x.candidate_id=candidate.id ORDER BY x.version DESC LIMIT 1)classification ON true
   WHERE candidate.tenant_id=p_tenant AND candidate.work_instance_id=i.id AND candidate.attendance_fact_id=fact.id;
  identity:=jsonb_build_object('work_instance_id',i.id,'fact_id',fact.id,'interpretation_id',interpretation.id);
  version:=jsonb_build_object('fact_version',fact.version,'interpretation_version',interpretation.version);
  lineage:=jsonb_build_object('work_instance_id',i.id,'operational_date',i.operational_date,
   'fact_id',fact.id,'fact_version',fact.version,'interpretation_id',interpretation.id,'interpretation_version',interpretation.version,
   'corrects_fact_id',fact.corrects_fact_id,'fact',fact.fact,'work_instance_status',i.status,
   'interpretation_state',interpretation.state,'overtime',overtime);
  actor:=fact.actor_user_id;
  RETURN jsonb_build_object('identity',identity,'version',version,'lineage',lineage,
   'fingerprint',encode(extensions.digest(lineage::text,'sha256'),'hex'),'validity_changed',i.status<>'approved' OR interpretation.state<>'ready','actor',actor);
 ELSIF p_domain='leave' THEN
  SELECT * INTO request FROM leave.requests WHERE tenant_id=p_tenant AND id=p_source_id;
  SELECT * INTO day_row FROM leave.request_days WHERE tenant_id=p_tenant AND request_id=p_source_id
   AND preview_version=request.approved_preview_version AND leave_date=p_source_date;
  IF request.id IS NULL OR day_row.leave_date IS NULL THEN RETURN NULL;END IF;
  SELECT x.* INTO cancellation FROM leave.cancellation_events x WHERE x.tenant_id=p_tenant AND x.request_id=request.id
   AND ((x.event_key='hr.direct_cancelled' AND x.to_state='cancelled') OR (x.event_key='hr.accepted' AND x.to_state='accepted'))
   ORDER BY x.to_version DESC,x.id DESC LIMIT 1;
  SELECT x.* INTO correction FROM leave.correction_events x WHERE x.tenant_id=p_tenant AND x.original_request_id=request.id
   AND x.event_key='hr.corrected' AND x.to_state='superseded' ORDER BY x.original_to_version DESC,x.id DESC LIMIT 1;
  identity:=jsonb_build_object('request_id',request.id,'date',day_row.leave_date);
  version:=jsonb_build_object('request_version',request.version,'approved_preview_version',request.approved_preview_version);
  lineage:=jsonb_build_object('request_id',request.id,'employee_id',request.employee_id,'employment_id',request.employment_id,
   'employer_id',request.employer_entity_id,'date',day_row.leave_date,'original_units',day_row.units,
   'effective_units',CASE WHEN request.state IN('cancelled','superseded') THEN 0 ELSE day_row.units END,'state',request.state,
   'cancellation_event_id',cancellation.id,'cancellation_id',cancellation.cancellation_id,
   'correction_id',correction.correction_id,'replacement_request_id',correction.replacement_request_id,'request_event_version',request.version);
  actor:=COALESCE(cancellation.actor_user_id,correction.actor_user_id);
  RETURN jsonb_build_object('identity',identity,'version',version,'lineage',lineage,
   'fingerprint',encode(extensions.digest(lineage::text,'sha256'),'hex'),
   'validity_changed',request.state IN('cancelled','superseded'),'actor',actor);
 END IF;
 RAISE EXCEPTION 'cube4_source_event_invalid' USING ERRCODE='22023';
END $f$;

-- Replace the two narrow producer bodies so producer and consumer cannot drift.
CREATE OR REPLACE FUNCTION payroll.observe_time_work_instance(p_tenant uuid,p_instance uuid,p_source_actor uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE i time.work_instances%ROWTYPE; envelope jsonb;
BEGIN
 SELECT * INTO i FROM time.work_instances WHERE tenant_id=p_tenant AND id=p_instance;
 IF i.id IS NULL THEN RETURN;END IF;
 envelope:=payroll.bound_source_envelope(p_tenant,'time',i.operational_date,i.id);
 IF envelope IS NULL THEN RETURN;END IF;
 PERFORM payroll.observe_bound_source_event(p_tenant,'time',i.operational_date,i.id,p_source_actor,
  envelope->'identity',envelope->'version',envelope->'lineage',envelope->>'fingerprint',(envelope->>'validity_changed')::boolean);
END $f$;

CREATE OR REPLACE FUNCTION payroll.observe_leave_source_transition() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE day_row record; envelope jsonb;
BEGIN
 IF NEW.state NOT IN('cancelled','superseded') OR OLD.state IN('cancelled','superseded') THEN RETURN NEW;END IF;
 FOR day_row IN SELECT leave_date FROM leave.request_days WHERE tenant_id=NEW.tenant_id AND request_id=NEW.id AND preview_version=NEW.approved_preview_version LOOP
  envelope:=payroll.bound_source_envelope(NEW.tenant_id,'leave',day_row.leave_date,NEW.id);
  IF envelope IS NOT NULL THEN
   PERFORM payroll.observe_bound_source_event(NEW.tenant_id,'leave',day_row.leave_date,NEW.id,(envelope->>'actor')::uuid,
    envelope->'identity',envelope->'version',envelope->'lineage',envelope->>'fingerprint',true);
  END IF;
 END LOOP;
 RETURN NEW;
END $f$;

CREATE FUNCTION payroll.correction_observation_outputs(p_observation payroll.bound_source_correction_observations)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT COALESCE(jsonb_agg(jsonb_build_object('id',context.id,'employer_id',context.employer_id,'period_id',context.period_id,
  'starts_on',period.starts_on,'ends_on',period.ends_on,'ever_paid',payroll.output_has_ever_paid(context.tenant_id,context.id)) ORDER BY context.id),'[]'::jsonb)
 FROM payroll.final_source_bindings binding
 JOIN payroll.final_contexts context ON context.tenant_id=binding.tenant_id AND context.id=binding.output_id
 JOIN payroll.periods period ON period.tenant_id=context.tenant_id AND period.id=context.period_id
 WHERE binding.tenant_id=p_observation.tenant_id AND binding.employer_id=p_observation.employer_id
  AND binding.employment_id=p_observation.employment_id AND binding.source_domain=p_observation.source_domain
  AND binding.source_date=p_observation.source_date AND binding.source_key=p_observation.source_key
  AND binding.source_identity IS NOT DISTINCT FROM p_observation.original_binding_identity
  AND binding.source_version IS NOT DISTINCT FROM p_observation.original_binding_version
  AND binding.captured_digest=p_observation.original_binding_digest
  AND NOT EXISTS(SELECT 1 FROM payroll.output_successions succession WHERE succession.tenant_id=context.tenant_id AND succession.original_output=context.id)
$f$;

CREATE FUNCTION payroll.compile_bound_source_observation(p_tenant uuid,p_employer uuid,p_change jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE observation payroll.bound_source_correction_observations%ROWTYPE; envelope jsonb; affected jsonb; source_id uuid;
BEGIN
 IF jsonb_typeof(p_change) IS DISTINCT FROM 'object' OR p_change-ARRAY['type','source_id','expected_hash','fields']<>'{}'::jsonb
  OR p_change->>'type' IS DISTINCT FROM 'source_change' OR jsonb_typeof(p_change->'fields') IS DISTINCT FROM 'object'
  OR p_change->'fields'<>'{}'::jsonb OR COALESCE(p_change->>'source_id','')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  OR COALESCE(p_change->>'expected_hash','')!~'^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
 source_id:=(p_change->>'source_id')::uuid;
 SELECT * INTO observation FROM payroll.bound_source_correction_observations
  WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=source_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 envelope:=payroll.bound_source_envelope(observation.tenant_id,observation.source_domain,observation.source_date,
  (observation.original_binding_identity->>CASE observation.source_domain WHEN 'time' THEN 'work_instance_id' ELSE 'request_id' END)::uuid);
 IF envelope IS NULL OR p_change->>'expected_hash' IS DISTINCT FROM observation.current_lineage_fingerprint
  OR envelope->>'fingerprint' IS DISTINCT FROM observation.current_lineage_fingerprint
  OR envelope->'identity' IS DISTINCT FROM observation.current_source_identity OR envelope->'version' IS DISTINCT FROM observation.current_source_version
 THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
 affected:=payroll.correction_observation_outputs(observation);
 IF affected='[]'::jsonb THEN RAISE EXCEPTION 'payroll_correction_observation_unaffected' USING ERRCODE='23514';END IF;
 RETURN jsonb_build_object('source_table','bound_source_correction_observations','operation','OBSERVE',
  'old_row',jsonb_build_object('observation_id',observation.id,'binding_digest',observation.original_binding_digest,
   'identity',observation.original_binding_identity,'version',observation.original_binding_version),
  'new_row',jsonb_build_object('id',observation.id,'observation_id',observation.id,'requirement_id',observation.requirement_id,
   'source_domain',observation.source_domain,'source_date',observation.source_date,'source_key',observation.source_key,
   'identity',envelope->'identity','version',envelope->'version','expected_fingerprint',observation.current_lineage_fingerprint,
   'affected_outputs',affected));
END $f$;

-- Called only after the established H prefix. It adds exact Time W fences in
-- the same day/id order as calculation/finalization. Leave needs no request lock.
CREATE FUNCTION payroll.lock_correction_observation_sources(p_tenant uuid,p_employer uuid,p_changes jsonb,p_compiled boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE change jsonb; ids uuid[]:='{}'; source_id uuid; observation payroll.bound_source_correction_observations%ROWTYPE;
BEGIN
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) LOOP
  IF (NOT p_compiled AND change->>'type'='source_change') OR (p_compiled AND change->>'source_table'='bound_source_correction_observations' AND change->>'operation'='OBSERVE') THEN
   IF COALESCE(CASE WHEN p_compiled THEN change->'new_row'->>'observation_id' ELSE change->>'source_id' END,'')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   source_id:=CASE WHEN p_compiled THEN (change->'new_row'->>'observation_id')::uuid ELSE (change->>'source_id')::uuid END;
   SELECT * INTO observation FROM payroll.bound_source_correction_observations WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=source_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
   ids:=array_append(ids,source_id);
  END IF;
 END LOOP;
 PERFORM 1 FROM time.work_instances instance
 JOIN payroll.bound_source_correction_observations selected_observation ON selected_observation.tenant_id=instance.tenant_id
  AND selected_observation.source_domain='time' AND selected_observation.id=ANY(ids)
  AND instance.id=(selected_observation.original_binding_identity->>'work_instance_id')::uuid
 WHERE instance.tenant_id=p_tenant ORDER BY instance.operational_date,instance.id FOR UPDATE OF instance;
END $f$;

CREATE FUNCTION payroll.assert_correction_observations_current(p_tenant uuid,p_employer uuid,p_changes jsonb)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE change jsonb; observation payroll.bound_source_correction_observations%ROWTYPE; envelope jsonb; affected jsonb;
BEGIN
 FOR change IN SELECT value FROM jsonb_array_elements(p_changes) WHERE value->>'source_table'='bound_source_correction_observations' LOOP
  IF change->>'operation'<>'OBSERVE' THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  SELECT * INTO observation FROM payroll.bound_source_correction_observations WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=(change->'new_row'->>'observation_id')::uuid;
  IF NOT FOUND OR change->'new_row'->>'requirement_id' IS DISTINCT FROM observation.requirement_id::text
   OR change->'new_row'->>'expected_fingerprint' IS DISTINCT FROM observation.current_lineage_fingerprint THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
  envelope:=payroll.bound_source_envelope(observation.tenant_id,observation.source_domain,observation.source_date,
   (observation.original_binding_identity->>CASE observation.source_domain WHEN 'time' THEN 'work_instance_id' ELSE 'request_id' END)::uuid);
  affected:=payroll.correction_observation_outputs(observation);
  IF envelope IS NULL OR envelope->>'fingerprint' IS DISTINCT FROM observation.current_lineage_fingerprint
   OR envelope->'identity' IS DISTINCT FROM change->'new_row'->'identity' OR envelope->'version' IS DISTINCT FROM change->'new_row'->'version'
   OR affected IS DISTINCT FROM change->'new_row'->'affected_outputs' THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
 END LOOP;
END $f$;

-- Extend the existing typed compiler. The observation, not caller state, owns
-- the original output; the public proposal later proves its p_output is in the
-- exact binding-derived affected set.
DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('payroll.correction_typed_authority(uuid,jsonb)'::regprocedure);
 old:='kind:=x->>''type'';permission:=CASE';new:='kind:=x->>''type'';IF kind=''source_change'' THEN CONTINUE;END IF;permission:=CASE';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_typed_authority_anchor';END IF;EXECUTE replace(d,old,new);
 d:=pg_get_functiondef('payroll.compile_source_changes(uuid,uuid,jsonb,uuid)'::regprocedure);
 old:='kind:=change->>''type'';fields:=change->''fields'';old_row:=NULL;new_row:=NULL;';
 new:=old||'IF kind=''source_change'' THEN result:=result||jsonb_build_array(payroll.compile_bound_source_observation(p_tenant,p_employer,change));CONTINUE;END IF;';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_compile_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('payroll.correction_affected_outputs(uuid,uuid,jsonb,uuid)'::regprocedure);
 old:='AND(c.id=p_original OR EXISTS(';
 new:='AND((c.id=p_original AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_changes) selected WHERE selected->>''source_table''=''bound_source_correction_observations'')) OR EXISTS(';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_affected_original_anchor';END IF;d:=replace(d,old,new);
 old:='WHEN ''input_versions'' THEN EXISTS(';
 new:='WHEN ''bound_source_correction_observations'' THEN EXISTS(SELECT 1 FROM jsonb_array_elements(x->''new_row''->''affected_outputs'') exact_output WHERE exact_output->>''id''=c.id::text) WHEN ''input_versions'' THEN EXISTS(';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_affected_observation_anchor';END IF;EXECUTE replace(d,old,new);
 d:=pg_get_functiondef('payroll.assert_correction_material(uuid,jsonb,jsonb)'::regprocedure);
 old:='IF x->>''source_table''=''employees'' THEN';
 new:='IF x->>''source_table''=''bound_source_correction_observations'' THEN material:=EXISTS(SELECT 1 FROM jsonb_array_elements(p_outputs) output WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(x->''new_row''->''affected_outputs'') exact_output WHERE exact_output->>''id''=output->>''id'')); ELSIF x->>''source_table''=''employees'' THEN';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_material_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('payroll.correction_source_authority(uuid,uuid,jsonb)'::regprocedure);
 old:='ELSIF change->>''source_table'' IN(''input_heads'',''input_versions'') THEN';
 new:='ELSIF change->>''source_table''=''bound_source_correction_observations'' AND change->>''operation''=''OBSERVE'' THEN NULL; ELSIF change->>''source_table'' IN(''input_heads'',''input_versions'') THEN';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_source_authority_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

-- OBSERVE receives a normal indexed immutable source-effect proof and audit,
-- then continues without dynamic SQL or any physical source update.
CREATE OR REPLACE FUNCTION payroll.apply_correction_sources(p_case payroll.correction_cases,p_actor uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE proposal payroll.correction_proposals%ROWTYPE;change jsonb;source_table text;source_schema text;index_value integer:=0;columns text;count_value integer;
BEGIN
 IF p_case.status<>'approved' THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 proposal:=payroll.correction_current(p_case);PERFORM payroll.correction_source_authority(p_case.tenant_id,p_actor,proposal.source_changes);
 IF EXISTS(SELECT 1 FROM payroll.correction_source_effects WHERE tenant_id=p_case.tenant_id AND proposal_id=proposal.id) THEN RAISE EXCEPTION 'payroll_correction_already_applied' USING ERRCODE='23514';END IF;
 FOR change IN SELECT value FROM jsonb_array_elements(proposal.source_changes) LOOP
  index_value:=index_value+1;source_table:=change->>'source_table';
  IF source_table='bound_source_correction_observations' THEN
   IF change->>'operation'<>'OBSERVE' THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
   INSERT INTO payroll.correction_source_effects(tenant_id,case_id,proposal_id,change_index,transaction_id,backend_pid,affected_outputs,source_table,operation,old_row,new_row,actor_id)
    VALUES(p_case.tenant_id,p_case.id,proposal.id,index_value,pg_current_xact_id(),pg_backend_pid(),proposal.source_scope->'affected_outputs',source_table,'OBSERVE',change->'old_row',change->'new_row',p_actor);
   INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_case.tenant_id,p_case.employer_id,p_actor,'correction_source_observation_resolved',jsonb_build_object('case',p_case.id,'proposal',proposal.id,'change_index',index_value,'observation',change->'new_row'->>'observation_id','affected_outputs',proposal.source_scope->'affected_outputs'));
   CONTINUE;
  END IF;
  IF source_table='work_assignments' AND(change->>'operation'='INSERT' OR((change->'old_row')-ARRAY['valid_from','valid_until']) IS DISTINCT FROM((change->'new_row')-ARRAY['valid_from','valid_until'])) THEN PERFORM payroll.assert_correction_assignment(p_case.tenant_id,p_case.employer_id,change->'new_row');END IF;
  source_schema:=CASE WHEN source_table IN('input_heads','input_versions') THEN 'payroll' ELSE 'people' END;
  IF source_table NOT IN('employees','employments','compensation_versions','work_assignments','input_heads','input_versions') OR change->>'operation' NOT IN('INSERT','UPDATE') THEN RAISE EXCEPTION 'payroll_proposal_invalid' USING ERRCODE='22023';END IF;
  INSERT INTO payroll.correction_source_effects(tenant_id,case_id,proposal_id,change_index,transaction_id,backend_pid,affected_outputs,source_table,operation,old_row,new_row,actor_id) VALUES(p_case.tenant_id,p_case.id,proposal.id,index_value,pg_current_xact_id(),pg_backend_pid(),proposal.source_scope->'affected_outputs',source_table,change->>'operation',NULLIF(change->'old_row','null'::jsonb),change->'new_row',p_actor);
  IF change->>'operation'='INSERT' THEN EXECUTE format('INSERT INTO %I.%I SELECT (jsonb_populate_record(NULL::%I.%I,$1)).*',source_schema,source_table,source_schema,source_table) USING change->'new_row';
  ELSE
   SELECT string_agg(format('%I',key),',' ORDER BY key) INTO columns FROM jsonb_object_keys(change->'new_row')key WHERE key NOT IN('tenant_id','id') AND(change->'old_row'->key) IS DISTINCT FROM(change->'new_row'->key);
   IF columns IS NULL THEN RAISE EXCEPTION 'payroll_proposal_unchanged' USING ERRCODE='22023';END IF;
   EXECUTE format('UPDATE %I.%I r SET (%s)=(SELECT %s FROM jsonb_populate_record(NULL::%I.%I,$1)) WHERE r.tenant_id=$2 AND r.id=$3 AND to_jsonb(r)=$4',source_schema,source_table,columns,columns,source_schema,source_table) USING change->'new_row',p_case.tenant_id,(change->'new_row'->>'id')::uuid,change->'old_row';
   GET DIAGNOSTICS count_value=ROW_COUNT;IF count_value<>1 THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
  END IF;
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_case.tenant_id,p_case.employer_id,p_actor,'correction_source_applied',jsonb_build_object('case',p_case.id,'proposal',proposal.id,'change_index',index_value,'affected_outputs',proposal.source_scope->'affected_outputs','source',change));
 END LOOP;
 PERFORM payroll.correction_source_authority(p_case.tenant_id,p_actor,proposal.source_changes);
END $f$;

DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('payroll.overlay_correction(jsonb,jsonb,uuid)'::regprocedure);
 old:='new_row:=change->''new_row'';old_row:=change->''old_row'';key:=';new:='IF change->>''operation''=''OBSERVE'' THEN CONTINUE;END IF;new_row:=change->''new_row'';old_row:=change->''old_row'';key:=';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_overlay_anchor';END IF;EXECUTE replace(d,old,new);
 d:=pg_get_functiondef('payroll.correction_current(payroll.correction_cases)'::regprocedure);
 old:='scope:=payroll.correction_scope(p_case.tenant_id,p_case.employer_id);';
 new:='PERFORM payroll.lock_correction_observation_sources(p_case.tenant_id,p_case.employer_id,proposal.source_changes,true);PERFORM payroll.assert_correction_observations_current(p_case.tenant_id,p_case.employer_id,proposal.source_changes);scope:=payroll.correction_scope(p_case.tenant_id,p_case.employer_id);';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_current_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

-- Proposal receipt replay remains before fresh source validation. Preview and a
-- new save fence exact W, compile, and require the requested output to be real.
DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('public.payroll_correction_proposal(uuid,uuid,uuid,uuid,integer,jsonb,jsonb,uuid,text,text,text,text,uuid)'::regprocedure);
 old:='compiled:=payroll.compile_source_changes(p_tenant,p_employer,p_changes,a);affected:=payroll.correction_affected_outputs(p_tenant,p_employer,compiled,p_output);';
 new:='PERFORM payroll.lock_correction_observation_sources(p_tenant,p_employer,p_changes,false);compiled:=payroll.compile_source_changes(p_tenant,p_employer,p_changes,a);affected:=payroll.correction_affected_outputs(p_tenant,p_employer,compiled,p_output);IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(affected) requested WHERE requested->>''id''=p_output::text) THEN RAISE EXCEPTION ''payroll_correction_observation_unaffected'' USING ERRCODE=''23514'';END IF;';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_proposal_compile_anchor';END IF;d:=replace(d,old,new);
 old:='AND EXISTS(SELECT 1 FROM jsonb_array_elements(compiled)x WHERE COALESCE(x->''new_row''->>''employment_id'',CASE WHEN x->>''source_table''=''employments'' THEN x->''new_row''->>''id'' END)=r.employment_id::text) ON CONFLICT DO NOTHING;';
 new:='AND (EXISTS(SELECT 1 FROM jsonb_array_elements(compiled)x WHERE x->>''source_table''=''bound_source_correction_observations'' AND x->''new_row''->>''requirement_id''=r.id::text) OR (NOT EXISTS(SELECT 1 FROM payroll.bound_source_correction_observations owned WHERE owned.tenant_id=r.tenant_id AND owned.requirement_id=r.id) AND EXISTS(SELECT 1 FROM jsonb_array_elements(compiled)x WHERE x->>''source_table''<>''bound_source_correction_observations'' AND COALESCE(x->''new_row''->>''employment_id'',CASE WHEN x->>''source_table''=''employments'' THEN x->''new_row''->>''id'' END)=r.employment_id::text))) ON CONFLICT DO NOTHING;';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_requirement_link_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

-- Fresh source proof is mandatory even when same-transaction source effects
-- allow historical source_scope drift. The manifest still starts from the live
-- run_manifest; OBSERVE contributes no overlay.
DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('payroll.amendment_manifest(uuid,uuid)'::regprocedure);
 old:='SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run;';
 new:=old||'PERFORM payroll.assert_correction_observations_current(p_tenant,r.employer_id,(SELECT proposal.source_changes FROM payroll.amendment_runs amendment JOIN payroll.correction_proposals proposal ON proposal.tenant_id=amendment.tenant_id AND proposal.id=amendment.proposal_id WHERE amendment.tenant_id=p_tenant AND amendment.run_id=p_run));';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_amendment_current_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

-- Candidate approval and append already hold the relevant H and period Time W
-- fences. Validate only after successful receipt replay.
DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 old:='SELECT * INTO c FROM payroll.candidates WHERE tenant_id=p_tenant AND employer_id=p_employer AND run_id=p_run AND id=p_candidate;';
 new:=old||'IF p_operation=''approve'' AND EXISTS(SELECT 1 FROM payroll.amendment_runs amendment WHERE amendment.tenant_id=p_tenant AND amendment.run_id=p_run) THEN PERFORM payroll.assert_correction_observations_current(p_tenant,p_employer,(SELECT proposal.source_changes FROM payroll.amendment_runs amendment JOIN payroll.correction_proposals proposal ON proposal.tenant_id=amendment.tenant_id AND proposal.id=amendment.proposal_id WHERE amendment.tenant_id=p_tenant AND amendment.run_id=p_run));END IF;';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_candidate_current_anchor';END IF;EXECUTE replace(d,old,new);
 d:=pg_get_functiondef('payroll.append_final_output_single(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
 old:='IF FOUND THEN RETURN payroll.append_final_output_before_advances(p_tenant,p_run,p_candidate,p_actor,p_expected,p_attempt);END IF;';
 new:=old||'IF EXISTS(SELECT 1 FROM payroll.amendment_runs amendment WHERE amendment.tenant_id=p_tenant AND amendment.run_id=p_run) THEN PERFORM payroll.assert_correction_observations_current(p_tenant,r.employer_id,(SELECT proposal.source_changes FROM payroll.amendment_runs amendment JOIN payroll.correction_proposals proposal ON proposal.tenant_id=amendment.tenant_id AND proposal.id=amendment.proposal_id WHERE amendment.tenant_id=p_tenant AND amendment.run_id=p_run));END IF;';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_append_current_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

-- Existing workspace and paged choices gain one subtype; no new public RPC.
DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('public.payroll_correction_workspace(uuid,uuid,uuid,uuid,text,uuid,uuid)'::regprocedure);
 old:='p_kind NOT IN(''compensation'',''assignment'',''employment'',''new_employment'',''input_revision'')';new:='p_kind NOT IN(''compensation'',''assignment'',''employment'',''new_employment'',''input_revision'',''source_change'')';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_workspace_kind_anchor';END IF;d:=replace(d,old,new);
 old:='IF p_kind=''input_revision'' THEN';
 new:='IF p_kind=''source_change'' THEN SELECT COALESCE(jsonb_agg(item ORDER BY item->>''id''),''[]''::jsonb) INTO sources FROM(SELECT jsonb_build_object(''id'',observation.id,''name'',CASE observation.source_domain WHEN ''time'' THEN ''حضور'' ELSE ''إجازة'' END||'' · ''||observation.source_date::text||'' · ''||employee.full_name,''domain'',observation.source_domain,''date'',observation.source_date,''fresh'',COALESCE((payroll.bound_source_envelope(observation.tenant_id,observation.source_domain,observation.source_date,(observation.original_binding_identity->>CASE observation.source_domain WHEN ''time'' THEN ''work_instance_id'' ELSE ''request_id'' END)::uuid)->>''fingerprint'')=observation.current_lineage_fingerprint,false),''expected_hash'',observation.current_lineage_fingerprint,''affects_paid_output'',EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.correction_observation_outputs(observation)) affected WHERE (affected->>''ever_paid'')::boolean)) item FROM payroll.bound_source_correction_observations observation JOIN people.employments employment ON employment.tenant_id=observation.tenant_id AND employment.id=observation.employment_id JOIN people.employees employee ON employee.tenant_id=employment.tenant_id AND employee.id=employment.employee_id WHERE observation.tenant_id=p_tenant AND observation.employer_id=p_employer AND EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.correction_observation_outputs(observation)) output WHERE output->>''id''=p_output::text) ORDER BY observation.id LIMIT 30) bounded; ELSIF p_kind=''input_revision'' THEN';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_workspace_sources_anchor';END IF;EXECUTE replace(d,old,new);

 d:=pg_get_functiondef('public.payroll_correction_choices(uuid,uuid,uuid,text,text,text,text,uuid,integer,uuid)'::regprocedure);
 old:='p_kind NOT IN(''compensation'',''assignment'',''employment'',''new_employment'',''input_revision'')';new:='p_kind NOT IN(''compensation'',''assignment'',''employment'',''new_employment'',''input_revision'',''source_change'')';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_choices_kind_anchor';END IF;d:=replace(d,old,new);
 old:='OR length(COALESCE(p_query,''''))>120';new:='OR(p_kind=''source_change'' AND p_choice NOT IN(''sources'',''employees'',''periods'',''components'',''outputs'')) OR length(COALESCE(p_query,''''))>120';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_choices_scope_anchor';END IF;d:=replace(d,old,new);
 old:='UNION ALL SELECT h.id,0,h.kind||'' · ''||COALESCE(v.data->>''name'',v.data->>''reference'',v.effective_from::text)';
 new:='UNION ALL SELECT observation.id,0,CASE observation.source_domain WHEN ''time'' THEN ''حضور'' ELSE ''إجازة'' END||'' · ''||observation.source_date::text||'' · ''||employee.full_name,jsonb_build_object(''id'',observation.id,''name'',CASE observation.source_domain WHEN ''time'' THEN ''حضور'' ELSE ''إجازة'' END||'' · ''||observation.source_date::text||'' · ''||employee.full_name,''domain'',observation.source_domain,''date'',observation.source_date,''fresh'',COALESCE((payroll.bound_source_envelope(observation.tenant_id,observation.source_domain,observation.source_date,(observation.original_binding_identity->>CASE observation.source_domain WHEN ''time'' THEN ''work_instance_id'' ELSE ''request_id'' END)::uuid)->>''fingerprint'')=observation.current_lineage_fingerprint,false),''expected_hash'',observation.current_lineage_fingerprint,''affects_paid_output'',EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.correction_observation_outputs(observation)) affected WHERE (affected->>''ever_paid'')::boolean)) FROM payroll.bound_source_correction_observations observation JOIN people.employments employment ON employment.tenant_id=observation.tenant_id AND employment.id=observation.employment_id JOIN people.employees employee ON employee.tenant_id=employment.tenant_id AND employee.id=employment.employee_id WHERE p_choice=''sources'' AND p_kind=''source_change'' AND observation.tenant_id=p_tenant AND observation.employer_id=p_employer AND EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.correction_observation_outputs(observation)) output WHERE output->>''id''=p_output::text) UNION ALL SELECT h.id,0,h.kind||'' · ''||COALESCE(v.data->>''name'',v.data->>''reference'',v.effective_from::text)';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_choices_source_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

-- Recovery performs only authority/scope checks before receipt lookup. Fresh
-- source validation remains on the dependent mutation path after replay.
DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('public.payroll_correction_reconcile(uuid,uuid,uuid,text,jsonb,uuid)'::regprocedure);
 old:='ELSIF change->>''type''=''new_employment'' THEN';
 new:='ELSIF change->>''type''=''source_change'' THEN SELECT employer_id INTO source_employer FROM payroll.bound_source_correction_observations WHERE tenant_id=p_tenant AND id=(change->>''source_id'')::uuid; ELSIF change->>''type''=''new_employment'' THEN';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_recovery_source_anchor';END IF;EXECUTE replace(d,old,new);
END $patch$;

REVOKE ALL ON FUNCTION payroll.bound_source_envelope(uuid,text,date,uuid),
 payroll.correction_observation_outputs(payroll.bound_source_correction_observations),
 payroll.compile_bound_source_observation(uuid,uuid,jsonb),
 payroll.lock_correction_observation_sources(uuid,uuid,jsonb,boolean),
 payroll.assert_correction_observations_current(uuid,uuid,jsonb),
 payroll.observe_time_work_instance(uuid,uuid,uuid),payroll.observe_leave_source_transition()
 FROM PUBLIC,anon,authenticated,service_role;


-- Links are immutable historical associations. Only a requirement still selected
-- by the current proposal may be treated as resolved or excluded from its review.
CREATE FUNCTION payroll.correction_requirement_is_current(p_tenant uuid,p_case uuid,p_requirement uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT NOT EXISTS(SELECT 1 FROM payroll.bound_source_correction_observations observation
   WHERE observation.tenant_id=p_tenant AND observation.requirement_id=p_requirement)
 OR EXISTS(SELECT 1 FROM payroll.correction_cases correction
   JOIN payroll.correction_proposals proposal ON proposal.tenant_id=correction.tenant_id AND proposal.id=correction.proposal_id AND proposal.case_id=correction.id
   CROSS JOIN LATERAL jsonb_array_elements(proposal.source_changes) change
   JOIN payroll.bound_source_correction_observations observation ON observation.tenant_id=correction.tenant_id
     AND observation.id::text=change->'new_row'->>'observation_id' AND observation.requirement_id=p_requirement
   WHERE correction.tenant_id=p_tenant AND correction.id=p_case
     AND change->>'source_table'='bound_source_correction_observations' AND change->>'operation'='OBSERVE'
     AND change->'new_row'->>'requirement_id'=p_requirement::text
     AND change->'new_row'->>'expected_fingerprint'=observation.current_lineage_fingerprint)
$f$;
REVOKE ALL ON FUNCTION payroll.correction_requirement_is_current(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE d text;old text;new text;fn record;patched integer:=0;BEGIN
 old:='AND c.status IN(''routed'',''completed'')';
 new:=old||' AND payroll.correction_requirement_is_current(l.tenant_id,l.case_id,l.request_id)';
 FOR fn IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='payroll' AND p.proname LIKE 'run_manifest%' LOOP
  d:=pg_get_functiondef(fn.oid);
  IF position('correction_request_links l JOIN payroll.correction_cases' IN d)>0 AND position(old IN d)>0 THEN
   EXECUTE replace(d,old,new);patched:=patched+1;
  END IF;
 END LOOP;
 IF patched<>1 THEN RAISE EXCEPTION 'unexpected_requirement_resolution_anchor';END IF;
 patched:=0;
 old:='AND l.request_id=(x->>''id'')::uuid';
 new:=old||' AND payroll.correction_requirement_is_current(l.tenant_id,l.case_id,l.request_id)';
 FOR fn IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='payroll' AND p.proname LIKE 'amendment_manifest%' LOOP
  d:=pg_get_functiondef(fn.oid);
  IF position('correction_request_links l WHERE' IN d)>0 AND position(old IN d)>0 THEN
   EXECUTE replace(d,old,new);patched:=patched+1;
  END IF;
 END LOOP;
 IF patched<>1 THEN RAISE EXCEPTION 'unexpected_amendment_requirement_anchor';END IF;
END $patch$;

-- Append every replacement while the original affected set is still intact.
-- Publish all successions afterwards in the same locked transaction. Each
-- append keeps its source-currentness check; no blanket bypass or GUC is used.
DO $patch$ DECLARE d text;old text;new text;BEGIN
 d:=pg_get_functiondef('payroll.append_correction_outputs(uuid,uuid,integer,uuid,uuid)'::regprocedure);
 old:='INSERT INTO payroll.output_successions(tenant_id,original_output,replacement_output,actor_id,reason) VALUES(p_tenant,(o->>''id'')::uuid,replacement,p_actor,p.reason);';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_batch_succession_anchor';END IF;
 d:=replace(d,old,'');
 old:='UPDATE payroll.runs SET status=''superseded'',revision=revision+1 WHERE tenant_id=p_tenant AND id=(SELECT run_id FROM payroll.final_contexts WHERE tenant_id=p_tenant AND id=(o->>''id'')::uuid);';
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_batch_run_anchor';END IF;
 d:=replace(d,old,'');
 old:='PERFORM payroll.route_correction_responsibilities(c,p,p_actor);';
 new:='FOR o IN SELECT value FROM jsonb_array_elements(result) LOOP
  INSERT INTO payroll.output_successions(tenant_id,original_output,replacement_output,actor_id,reason)
   VALUES(p_tenant,(o->>''original_output'')::uuid,(o->>''replacement_output'')::uuid,p_actor,p.reason);
  UPDATE payroll.runs SET status=''superseded'',revision=revision+1 WHERE tenant_id=p_tenant
   AND id=(SELECT run_id FROM payroll.final_contexts WHERE tenant_id=p_tenant AND id=(o->>''original_output'')::uuid);
 END LOOP;'||old;
 IF position(old IN d)=0 THEN RAISE EXCEPTION 'unexpected_batch_route_anchor';END IF;
 EXECUTE replace(d,old,new);
END $patch$;
