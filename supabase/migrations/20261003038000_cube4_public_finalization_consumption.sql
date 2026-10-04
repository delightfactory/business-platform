-- Connect public finalization to the existing atomic append/consumption chain.
-- A browser flag or prescribed synthetic candidate cannot qualify this path:
-- the immutable candidate must equal the actual current calculation producer.
-- That producer currently returns financially_qualified=false. This migration
-- does not reinterpret tax/insurance-only issuance as full legal qualification.
CREATE FUNCTION payroll.public_candidate_readiness(p_candidate payroll.candidates)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE readiness jsonb;calculated jsonb;amendment uuid;canonical boolean;BEGIN
 IF p_candidate.id IS NULL THEN RETURN jsonb_build_object('ready',false,'qualification_reasons',jsonb_build_array('candidate_missing'));END IF;
 readiness:=payroll.approval_readiness(p_candidate);
 SELECT amendment_of INTO amendment FROM payroll.runs WHERE tenant_id=p_candidate.tenant_id AND id=p_candidate.run_id;
 calculated:=CASE WHEN amendment IS NULL THEN payroll.build_review(p_candidate.input_manifest)
  ELSE payroll.build_correction_review(p_candidate.input_manifest) END;
 canonical:=p_candidate.output=calculated AND p_candidate.engine_version IS NOT DISTINCT FROM p_candidate.input_manifest->>'engine';
 RETURN readiness||jsonb_build_object('ready',coalesce((readiness->>'ready')::boolean,false)
  AND canonical AND calculated->>'financially_qualified'='true',
  'qualification_reasons',CASE WHEN NOT canonical THEN jsonb_build_array('candidate_calculation_mismatch')
   WHEN calculated->>'financially_qualified' IS DISTINCT FROM 'true' THEN jsonb_build_array('financial_qualification_producer_required') ELSE '[]'::jsonb END);
END $f$;
REVOKE ALL ON FUNCTION payroll.public_candidate_readiness(payroll.candidates) FROM PUBLIC,anon,authenticated,service_role;

-- Replace the unreachable release-gate stub, not the established append chain.
-- Receipt lookup precedes lifecycle/CAS checks, while current authorization and
-- exact tenant/employer/period/run scope precede receipt lookup.
CREATE OR REPLACE FUNCTION payroll.finalize_run(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_candidate uuid,p_expected integer,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;r payroll.runs%ROWTYPE;c payroll.candidates%ROWTYPE;
 intent jsonb;receipt payroll.command_receipts%ROWTYPE;output uuid;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.lock',true);
 IF p_run IS NULL OR p_candidate IS NULL OR p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.lock_finalization_sources(p_tenant,p_employer,p_period);
 actor:=payroll.authorized(p_tenant,'payroll.lock',true);
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_run FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF r.amendment_of IS NOT NULL THEN RAISE EXCEPTION 'payroll_atomic_correction_required' USING ERRCODE='23514';END IF;
 intent:=jsonb_build_object('operation','private_final_append','run',p_run,'candidate',p_candidate,'expected',p_expected);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF receipt.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  output:=(receipt.result->>'output')::uuid;
 ELSE
  PERFORM payroll.assert_run_attempt_open(p_tenant,actor,p_attempt,intent);
  IF r.revision<>p_expected OR r.status<>'approved' OR r.candidate_id IS DISTINCT FROM p_candidate THEN
   RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409';END IF;
  SELECT * INTO c FROM payroll.candidates WHERE tenant_id=p_tenant AND employer_id=p_employer AND run_id=p_run AND id=p_candidate;
  IF NOT coalesce((payroll.public_candidate_readiness(c)->>'ready')::boolean,false) THEN
   RAISE EXCEPTION 'payroll_financial_qualification_required' USING ERRCODE='23514';END IF;
  -- This existing chain freezes snapshots, applies approved inputs, binds the
  -- sources and posts advance consumption with audit and receipt in one tx.
  output:=payroll.append_final_output(p_tenant,p_run,p_candidate,actor,p_expected,p_attempt);
 END IF;
 PERFORM payroll.authorized(p_tenant,'payroll.lock',true);
 RETURN jsonb_build_object('id',p_run,'candidate_id',p_candidate,'revision',p_expected+1,'status','locked','output',output);
END $f$;

CREATE FUNCTION public.payroll_run_finalize(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_candidate uuid,p_expected integer,p_attempt uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
 SELECT payroll.finalize_run(p_tenant,p_employer,p_period,p_run,p_candidate,p_expected,p_attempt);
$f$;

-- Recovery holds the same source/scope locks as the writer. It never calls the
-- writer. An absent receipt fences the original attempt durably before retry.
CREATE FUNCTION public.payroll_run_finalization_reconcile(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_candidate uuid,p_expected integer,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;r payroll.runs%ROWTYPE;intent jsonb;receipt payroll.command_receipts%ROWTYPE;closed payroll.run_attempt_closures%ROWTYPE;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 IF p_run IS NULL OR p_candidate IS NULL OR p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.lock_finalization_sources(p_tenant,p_employer,p_period);
 actor:=payroll.authorized(p_tenant,'payroll.lock',false);
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_run FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF r.amendment_of IS NOT NULL THEN RAISE EXCEPTION 'payroll_atomic_correction_required' USING ERRCODE='23514';END IF;
 intent:=jsonb_build_object('operation','private_final_append','run',p_run,'candidate',p_candidate,'expected',p_expected);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF receipt.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
  RETURN jsonb_build_object('outcome','committed','result',jsonb_build_object('id',p_run,'candidate_id',p_candidate,
   'revision',p_expected+1,'status','locked','output',receipt.result->'output'));
 END IF;
 SELECT * INTO closed FROM payroll.run_attempt_closures WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF closed.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
 ELSE
  INSERT INTO payroll.run_attempt_closures(tenant_id,actor_id,attempt_key,employer_id,period_id,intent)
   VALUES(p_tenant,actor,p_attempt,p_employer,p_period,intent);
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details)
   VALUES(p_tenant,p_employer,actor,'finalization_attempt_closed',jsonb_build_object('attempt',p_attempt,'period',p_period,'run',p_run));
 END IF;
 PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 RETURN jsonb_build_object('outcome','closed_uncommitted');
END $f$;
REVOKE ALL ON FUNCTION payroll.finalize_run(uuid,uuid,uuid,uuid,uuid,integer,uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_run_finalize(uuid,uuid,uuid,uuid,uuid,integer,uuid),public.payroll_run_finalization_reconcile(uuid,uuid,uuid,uuid,uuid,integer,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_run_finalize(uuid,uuid,uuid,uuid,uuid,integer,uuid),public.payroll_run_finalization_reconcile(uuid,uuid,uuid,uuid,uuid,integer,uuid) TO authenticated;
