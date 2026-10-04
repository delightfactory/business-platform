-- Public boundaries share the canonical producer check with finalization.
-- Existing tax/insurance-only packs remain insufficient for full qualification.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 anchor:='payroll.approval_readiness(c)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_public_approval_readiness';END IF;
 EXECUTE replace(definition,anchor,'payroll.public_candidate_readiness(c)');
 definition:=pg_get_functiondef('payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean)'::regprocedure);
 anchor:='payroll.approval_readiness(candidate)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_public_workspace_readiness';END IF;
 EXECUTE replace(definition,anchor,'payroll.public_candidate_readiness(candidate)');
 definition:=pg_get_functiondef('public.payroll_run_access(uuid)'::regprocedure);
 anchor:='''can_approve'',platform_private.has_tenant_permission(p_tenant,a,''payroll.approve''),';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_public_run_lock_access';END IF;
 EXECUTE replace(definition,anchor,anchor||'''can_lock'',platform_private.has_tenant_permission(p_tenant,a,''payroll.lock''),');
 -- A recovery request cannot create a fence for an unrelated opaque candidate.
 definition:=pg_get_functiondef('public.payroll_run_finalization_reconcile(uuid,uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
 anchor:='IF NOT FOUND THEN RAISE EXCEPTION ''payroll_forbidden'' USING ERRCODE=''42501'';END IF;';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_finalization_recovery_scope';END IF;
 EXECUTE replace(definition,anchor,anchor||$insert$
 IF NOT EXISTS(SELECT 1 FROM payroll.candidates WHERE tenant_id=p_tenant AND employer_id=p_employer AND run_id=p_run AND id=p_candidate) THEN
  RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;$insert$);
END $patch$;

-- One transaction delegates to the proven batch: all replacement outputs before
-- succession links, source effects, routed responsibilities and consumption.
-- It cannot finalize an individual amendment or the paid-only settlement route.
CREATE FUNCTION public.payroll_correction_finalize(p_tenant uuid,p_employer uuid,p_case uuid,p_expected integer,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;c payroll.correction_cases%ROWTYPE;p payroll.correction_proposals%ROWTYPE;
 candidate payroll.candidates%ROWTYPE;intent jsonb;receipt payroll.command_receipts%ROWTYPE;item jsonb;count_unpaid integer:=0;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 IF p_case IS NULL OR p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.correction_lock(p_tenant,p_employer);
 actor:=payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_case FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO p FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND case_id=p_case AND id=c.proposal_id;
 PERFORM payroll.correction_source_authority(p_tenant,actor,p.source_changes);
 intent:=jsonb_build_object('operation','private_correction_append','case',p_case,'expected',p_expected);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF receipt.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  RETURN payroll.append_correction_outputs(p_tenant,p_case,p_expected,actor,p_attempt);
 END IF;
 PERFORM payroll.assert_correction_attempt_open(p_tenant,actor,p_attempt,intent);
 IF c.revision<>p_expected OR c.status<>'approved' THEN RAISE EXCEPTION 'payroll_correction_stale' USING ERRCODE='PT409';END IF;
 p:=payroll.correction_current(c);
 FOR item IN SELECT value FROM jsonb_array_elements(p.source_scope->'affected_outputs') WHERE NOT(value->>'ever_paid')::boolean ORDER BY value->>'id' LOOP
  count_unpaid:=count_unpaid+1;
  SELECT v.* INTO candidate FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id
   JOIN payroll.candidates v ON v.tenant_id=r.tenant_id AND v.run_id=r.id AND v.id=r.candidate_id
   WHERE m.tenant_id=p_tenant AND m.case_id=p_case AND m.proposal_id=p.id AND r.amendment_of=(item->>'id')::uuid AND r.status='approved';
  IF NOT coalesce((payroll.public_candidate_readiness(candidate)->>'ready')::boolean,false) THEN
   RAISE EXCEPTION 'payroll_financial_qualification_required' USING ERRCODE='23514';END IF;
 END LOOP;
 IF count_unpaid=0 THEN RAISE EXCEPTION 'payroll_paid_route_required' USING ERRCODE='23514';END IF;
 RETURN payroll.append_correction_outputs(p_tenant,p_case,p_expected,actor,p_attempt);
END $f$;

CREATE FUNCTION public.payroll_correction_finalization_reconcile(p_tenant uuid,p_employer uuid,p_case uuid,p_expected integer,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;c payroll.correction_cases%ROWTYPE;p payroll.correction_proposals%ROWTYPE;
 intent jsonb;receipt payroll.command_receipts%ROWTYPE;closed payroll.correction_attempt_closures%ROWTYPE;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 IF p_case IS NULL OR p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.correction_lock(p_tenant,p_employer);
 actor:=payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 SELECT * INTO c FROM payroll.correction_cases WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_case FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO p FROM payroll.correction_proposals WHERE tenant_id=p_tenant AND case_id=p_case AND id=c.proposal_id;
 PERFORM payroll.correction_source_authority(p_tenant,actor,p.source_changes);
 intent:=jsonb_build_object('operation','private_correction_append','case',p_case,'expected',p_expected);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF receipt.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
  RETURN jsonb_build_object('outcome','committed','result',receipt.result);
 END IF;
 SELECT * INTO closed FROM payroll.correction_attempt_closures WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF closed.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
 ELSE
  INSERT INTO payroll.correction_attempt_closures(tenant_id,actor_id,attempt_key,employer_id,output_id,intent)
   VALUES(p_tenant,actor,p_attempt,p_employer,c.original_output,intent);
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details)
   VALUES(p_tenant,p_employer,actor,'correction_finalization_attempt_closed',jsonb_build_object('attempt',p_attempt,'case',p_case));
 END IF;
 PERFORM payroll.authorized(p_tenant,'payroll.correct',false);PERFORM payroll.authorized(p_tenant,'payroll.lock',false);
 RETURN jsonb_build_object('outcome','closed_uncommitted');
END $f$;
REVOKE ALL ON FUNCTION public.payroll_correction_finalize(uuid,uuid,uuid,integer,uuid),public.payroll_correction_finalization_reconcile(uuid,uuid,uuid,integer,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_correction_finalize(uuid,uuid,uuid,integer,uuid),public.payroll_correction_finalization_reconcile(uuid,uuid,uuid,integer,uuid) TO authenticated;
