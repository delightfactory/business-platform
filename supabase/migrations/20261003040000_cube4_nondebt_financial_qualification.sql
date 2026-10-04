-- Candidate qualification for the first integrated profile: one civil year,
-- one dated monthly context, explicit non-insurance, no debt deduction and no
-- Time/Leave valuation. Other profiles retain owned blockers; Cube4 scope is
-- not reduced. A tax/insurance pack is not relabelled as a general labour pack.
-- Its real immutable issuer evidence qualifies only the applicable tax worker.
CREATE FUNCTION payroll.issued_tax_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE pack payroll.statutory_packs%ROWTYPE;issuance payroll.statutory_draft_issuances%ROWTYPE;
 version payroll.statutory_draft_versions%ROWTYPE;head payroll.statutory_draft_heads%ROWTYPE;
 expected payroll.statutory_packs%ROWTYPE;comparison payroll.statutory_draft_comparisons%ROWTYPE;
 stamp text;comparisons jsonb;scenario text;selected jsonb:='[]'::jsonb;year_number integer;BEGIN
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 SELECT * INTO issuance FROM payroll.statutory_draft_issuances WHERE pack_id=p_pack;
 IF pack.id IS NULL OR issuance.pack_id IS NULL OR pack.state<>'verified' OR pack.engine_adapter<>'eg-cumulative-tax-v1'
  OR pack.review_evidence->>'scope' IS DISTINCT FROM 'tax_insurance'
  OR pack.verified_by IS DISTINCT FROM issuance.actor_id
  OR NOT isfinite(p_from) OR NOT isfinite(p_until) OR p_from>p_until
  OR extract(year FROM p_from)<>extract(year FROM p_until)
  OR pack.effective_from>p_from OR pack.effective_until IS NULL OR pack.effective_until<=p_until THEN
  RETURN jsonb_build_object('ready',false,'reason','issued_tax_evidence_required');END IF;
 SELECT * INTO version FROM payroll.statutory_draft_versions WHERE head_id=issuance.head_id AND revision=issuance.revision;
 SELECT * INTO head FROM payroll.statutory_draft_heads WHERE id=issuance.head_id;
 expected:=payroll.statutory_draft_pack(version,head.version);
 SELECT md5(to_jsonb(version)::text||md5(coalesce(string_agg(md5(to_jsonb(c)::text),'' ORDER BY id),''))) INTO stamp
  FROM payroll.statutory_draft_comparisons c WHERE head_id=issuance.head_id AND revision=issuance.revision;
 SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY id),'[]'::jsonb) INTO comparisons
  FROM payroll.statutory_draft_comparisons c WHERE head_id=issuance.head_id AND revision=issuance.revision AND case_data->>'origin'='official';
 IF stamp IS DISTINCT FROM issuance.evidence_stamp OR stamp IS DISTINCT FROM pack.review_evidence->>'evidence_stamp'
  OR pack.review_evidence->>'draft_head' IS DISTINCT FROM issuance.head_id::text
  OR pack.review_evidence->>'draft_revision' IS DISTINCT FROM issuance.revision::text
  OR pack.review_evidence->'numeric_comparisons' IS DISTINCT FROM comparisons
  OR pack.rules IS DISTINCT FROM expected.rules OR pack.insurance_rules IS DISTINCT FROM expected.insurance_rules
  OR pack.earning_rules IS DISTINCT FROM expected.earning_rules
  OR pack.effective_from IS DISTINCT FROM version.effective_from OR pack.effective_until IS DISTINCT FROM version.effective_until THEN
  RETURN jsonb_build_object('ready',false,'reason','issued_tax_evidence_mismatch');END IF;
 year_number:=extract(year FROM p_from);
 FOREACH scenario IN ARRAY ARRAY['low','medium','high','mid_year','cumulative','insurance_min','insurance_max','component_mix','correction','rounding'] LOOP
  SELECT * INTO comparison FROM payroll.statutory_current_comparisons(issuance.head_id,issuance.revision) c
   WHERE c.case_data->>'scenario'=scenario AND extract(year FROM(c.case_data->'tax'->>'from')::date)=year_number
    AND c.result->>'matched'='true' AND c.case_data->>'source_url' ~ '^https://([a-zA-Z0-9-]+\.)*(eta|nosi)\.gov\.eg(/|$)'
    AND pack.review_evidence->'representative_case_ids' @> to_jsonb(c.id)
   ORDER BY id DESC LIMIT 1;
  IF comparison.id IS NULL OR comparison.result IS DISTINCT FROM payroll.statutory_draft_compare(version,head.version,comparison.case_data) THEN
   RETURN jsonb_build_object('ready',false,'reason','official_tax_coverage_required');END IF;
  selected:=selected||to_jsonb(comparison.id);
 END LOOP;
 RETURN jsonb_build_object('ready',true,'scope','issued_tax_insurance','pack_id',p_pack,'head',issuance.head_id,
  'revision',issuance.revision,'evidence_stamp',stamp,'actor',issuance.actor_id,'year',year_number,'case_ids',selected);
END $f$;
REVOKE ALL ON FUNCTION payroll.issued_tax_qualification(uuid,date,date) FROM PUBLIC,anon,authenticated,service_role;

-- Add actual qualification to the existing composition boundary. No candidate
-- flag, runtime option, tenant rule or synthetic comparison can satisfy the
-- real issuer-evidence function above. Tests simulate that external dependency
-- only in their own isolated database, with the boundary explicitly recorded.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='employment uuid:=(p_employee->>''employment_id'')::uuid;BEGIN';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_profile_qualification_declaration';END IF;
 definition:=replace(definition,anchor,'qualification jsonb;profile boolean;'||anchor);
 anchor:='     RETURN calculated||jsonb_build_object(''statutory_context''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_profile_qualification_result';END IF;
 definition:=replace(definition,anchor,$insert$
     profile:=p_employee->>'pay_basis'='monthly' AND (p_employee->>'deductions')::numeric=0
      AND coalesce((p_manifest->'optional'->>'time')::boolean,false)=false
      AND coalesce((p_manifest->'optional'->>'leave')::boolean,false)=false
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_manifest->'advances','[]'::jsonb)) a WHERE a->>'employment_id'=employment::text)
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->'lines') line
       WHERE line->>'classification'='deduction' OR line->>'classification'='earning' AND line->>'component'<>'base');
     qualification:=CASE WHEN profile THEN payroll.issued_tax_qualification(tax_pack,(p_employee->>'starts_on')::date,(p_employee->>'ends_on')::date)
      ELSE jsonb_build_object('ready',false,'reason','financial_profile_composition_required') END;
     calculated:=calculated||jsonb_build_object('financially_qualified',qualification->>'ready'='true',
      'financial_qualification',jsonb_build_object('profile','eg-monthly-nondebt-single-context-v1','tax_evidence',qualification,
       'insurance','reviewed_not_insured','labour_debt_deductions','none','time_leave_valuation','none',
       'context_head',context->'head_id','context_version',context->'version_id','prior_balance',balance));
     RETURN calculated||jsonb_build_object('statutory_context'$insert$);
 -- Preserve the composed proof instead of overwriting its qualified value.
 anchor:='''prior_balance'',balance,''pack_id'',tax_pack),''financially_qualified'',false);';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_profile_qualification_overwrite';END IF;
 EXECUTE replace(definition,anchor,'''prior_balance'',balance,''pack_id'',tax_pack));');

 definition:=pg_get_functiondef('payroll.build_review(jsonb)'::regprocedure);
 anchor:=' RETURN result||jsonb_build_object(''employees'',employees,''issues'',issues,''financially_qualified'',false,';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_profile_root_qualification';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF jsonb_array_length(employees)>0 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee
  WHERE employee->>'financially_qualified' IS DISTINCT FROM 'true') THEN
  SELECT coalesce(jsonb_agg(issue),'[]'::jsonb) INTO issues FROM jsonb_array_elements(issues) issue
   WHERE issue->>'code' NOT IN('statutory_pack_unqualified','statutory_adapter_unqualified');
 END IF;
 RETURN result||jsonb_build_object('employees',employees,'issues',issues,'financially_qualified',
  jsonb_array_length(employees)>0 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee WHERE employee->>'financially_qualified' IS DISTINCT FROM 'true')
  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(issues) issue WHERE coalesce((issue->>'blocking')::boolean,true)),$insert$);
 -- Version the existing manifest implementation, without adding another layer.
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_profile_engine_manifest';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-nondebt-qualified-v1'');'||anchor);
 definition:=pg_get_functiondef('payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean)'::regprocedure);
 anchor:='''access'',access,''period''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_finalization_confirmation_employer';END IF;
 EXECUTE replace(definition,anchor,'''access'',access,''employer'',(SELECT jsonb_build_object(''display_name'',display_name,''legal_name'',legal_name) FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer),''period''');
 definition:=pg_get_functiondef('public.payroll_correction_workspace(uuid,uuid,uuid,uuid,text,uuid,uuid)'::regprocedure);
 anchor:='''can_approve'',platform_private.has_tenant_permission(p_tenant,auth.uid(),''payroll.approve''),';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_correction_finalization_access';END IF;
 EXECUTE replace(definition,anchor,anchor||'''can_lock'',platform_private.has_tenant_permission(p_tenant,auth.uid(),''payroll.lock''),');
 definition:=pg_get_functiondef('payroll.correction_review_state(payroll.candidates)'::regprocedure);
 anchor:='payroll.approval_readiness(p_candidate)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_correction_qualification_review';END IF;
 EXECUTE replace(definition,anchor,'payroll.public_candidate_readiness(p_candidate)');
END $patch$;
