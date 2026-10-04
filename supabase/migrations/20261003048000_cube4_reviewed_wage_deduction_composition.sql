-- Bounded Article113/114 adapter. No configurable rates or general rules
-- engine. A separately reviewed immutable dossier and approved attributable
-- claims are mandatory; tax/insurance issuance alone never qualifies debt.
ALTER TABLE payroll.statutory_packs ADD COLUMN labour_rules jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE FUNCTION payroll.calculate_wage_deduction_plan(p_context jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE key text;claim jsonb;basis numeric;ceiling numeric;left_capacity numeric;amount numeric;allowed numeric;
 gross numeric;tax numeric;insurance numeric;loan numeric;rate numeric;applied numeric:=0;unapplied numeric:=0;
 claims jsonb:='[]';seen text[]:='{}';BEGIN
 IF jsonb_typeof(p_context) IS DISTINCT FROM 'object'
  OR NOT(p_context ?& ARRAY['gross','tax','employee_insurance','employer_loan','claims'])
  OR(p_context-ARRAY['gross','tax','employee_insurance','employer_loan','claims'])<>'{}'::jsonb
  OR jsonb_typeof(p_context->'claims') IS DISTINCT FROM 'array' OR jsonb_array_length(p_context->'claims')>100 THEN
  RAISE EXCEPTION 'payroll_deduction_context_invalid' USING ERRCODE='22023';END IF;
 FOREACH key IN ARRAY ARRAY['gross','tax','employee_insurance','employer_loan'] LOOP
  IF jsonb_typeof(p_context->key) IS DISTINCT FROM 'number' OR coalesce(p_context->>key,'')!~'^-?[0-9]+(\.[0-9]+)?$'
   OR abs((p_context->>key)::numeric)>1000000000000 OR(p_context->>key)::numeric<>round((p_context->>key)::numeric,2)
   OR(key<>'tax' AND(p_context->>key)::numeric<0) THEN
   RAISE EXCEPTION 'payroll_deduction_context_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
 gross:=(p_context->>'gross')::numeric;tax:=(p_context->>'tax')::numeric;
 insurance:=(p_context->>'employee_insurance')::numeric;loan:=(p_context->>'employer_loan')::numeric;
 IF loan>floor(gross*0.10*100)/100 THEN RAISE EXCEPTION 'advance_capacity_disposition_required' USING ERRCODE='22023';END IF;
 -- A refund cannot silently increase the wage assignment/attachment ceiling.
 -- Require a reviewed refund basis instead of inventing that financial policy.
 IF tax<0 THEN RAISE EXCEPTION 'payroll_deduction_refund_basis_required' USING ERRCODE='22023';END IF;
 basis:=gross-tax-insurance-loan;
 IF basis<0 THEN RAISE EXCEPTION 'negative_statutory_balance' USING ERRCODE='22023';END IF;
 FOR claim IN SELECT value FROM jsonb_array_elements(p_context->'claims') LOOP
  IF jsonb_typeof(claim) IS DISTINCT FROM 'object' OR NOT(claim ?& ARRAY['id','category','amount','reference'])
   OR(claim-ARRAY['id','category','amount','reference','consent_reference'])<>'{}'::jsonb
   OR coalesce(claim->>'category','') NOT IN('alimony','employer_damage','employer_overpayment','employer_penalty','assignment','other_debt')
   OR jsonb_typeof(claim->'id') IS DISTINCT FROM 'string' OR length(claim->>'id') NOT BETWEEN 1 AND 100
   OR claim->>'id'=ANY(seen) OR jsonb_typeof(claim->'amount') IS DISTINCT FROM 'number'
   OR(claim->>'amount')::numeric<=0 OR(claim->>'amount')::numeric>1000000000000
   OR(claim->>'amount')::numeric<>round((claim->>'amount')::numeric,2)
   OR jsonb_typeof(claim->'reference') IS DISTINCT FROM 'string' OR length(btrim(claim->>'reference')) NOT BETWEEN 3 AND 160
   OR(claim->>'category'='assignment' AND (jsonb_typeof(claim->'consent_reference') IS DISTINCT FROM 'string'
    OR length(btrim(claim->>'consent_reference')) NOT BETWEEN 3 AND 160)) THEN
   RAISE EXCEPTION 'payroll_deduction_source_invalid' USING ERRCODE='22023';END IF;
  seen:=array_append(seen,claim->>'id');
 END LOOP;
 rate:=CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(p_context->'claims') item WHERE item->>'category'='alimony') THEN 0.50 ELSE 0.25 END;
 ceiling:=floor(basis*rate*100)/100;left_capacity:=ceiling;
 FOR claim IN SELECT value FROM jsonb_array_elements(p_context->'claims')
  ORDER BY CASE WHEN value->>'category'='alimony' THEN 0
   WHEN value->>'category' IN('employer_damage','employer_overpayment','employer_penalty') THEN 1 ELSE 2 END,value->>'id' LOOP
  amount:=(claim->>'amount')::numeric;allowed:=least(amount,left_capacity);left_capacity:=left_capacity-allowed;
  applied:=applied+allowed;unapplied:=unapplied+amount-allowed;
  claims:=claims||jsonb_build_array(claim||jsonb_build_object('capacity_amount',allowed,'unapplied_amount',amount-allowed,
   'priority',CASE WHEN claim->>'category'='alimony' THEN 0 WHEN claim->>'category' IN('employer_damage','employer_overpayment','employer_penalty') THEN 1 ELSE 2 END));
 END LOOP;
 RETURN jsonb_build_object('adapter','eg-wage-deductions113114-v1','wage_basis',basis,'rate',rate,'ceiling',ceiling,
  'capacity_amount',applied,'unapplied_amount',unapplied,'claims',claims,'ready',unapplied=0,
  'allocation_is_consumption',false,'law_source','https://portal.eta.gov.eg/sites/default/files/2026-03/law.no_.14.of_.2025.pdf');
END $f$;
REVOKE ALL ON FUNCTION payroll.calculate_wage_deduction_plan(jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.compare_labour_deduction_case(p_version payroll.statutory_draft_versions,p_case jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE actual jsonb;expected jsonb;key text;BEGIN
 IF octet_length(p_case::text)>16384 OR p_version.numeric_rules->>'labour_deduction_adapter' IS DISTINCT FROM 'eg-wage-deductions113114-v1'
  OR jsonb_typeof(p_case) IS DISTINCT FROM 'object' OR NOT(p_case ?& ARRAY['name','domain','scenario','origin','source_url','reference','year','context','expected'])
  OR(p_case-ARRAY['name','domain','scenario','origin','source_url','reference','year','context','expected'])<>'{}'::jsonb
  OR p_case->>'domain' IS DISTINCT FROM 'labour_deductions'
  OR coalesce(p_case->>'scenario','') NOT IN('ordinary_limit','alimony_limit','priority','loan_basis','zero_capacity','cent_boundary')
  OR coalesce(p_case->>'origin','') NOT IN('synthetic','official') OR jsonb_typeof(p_case->'name') IS DISTINCT FROM 'string'
  OR length(btrim(p_case->>'name')) NOT BETWEEN 3 AND 160 OR length(btrim(coalesce(p_case->>'reference',''))) NOT BETWEEN 3 AND 160
  OR coalesce(p_case->>'year','')!~'^[0-9]{4}$' OR(p_case->>'year')::integer NOT BETWEEN 2000 AND 2200
  OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_version.source_references) source WHERE source->>'url'=p_case->>'source_url')
  OR p_case->>'source_url' IS DISTINCT FROM 'https://portal.eta.gov.eg/sites/default/files/2026-03/law.no_.14.of_.2025.pdf' THEN
  RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 actual:=payroll.calculate_wage_deduction_plan(p_case->'context');expected:=p_case->'expected';
 -- Representative names must describe actual case facts, not six aliases for
 -- one convenient example. Only independently matched official cases qualify.
 IF (CASE p_case->>'scenario'
  WHEN 'ordinary_limit' THEN (actual->>'rate')::numeric<>0.25 OR (actual->>'unapplied_amount')::numeric<=0
  WHEN 'alimony_limit' THEN (actual->>'rate')::numeric<>0.50 OR (actual->>'unapplied_amount')::numeric<=0
  WHEN 'priority' THEN NOT EXISTS(SELECT 1 FROM jsonb_array_elements(actual->'claims') c WHERE c->>'category'='alimony')
   OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(actual->'claims') c WHERE c->>'category' IN('employer_damage','employer_overpayment','employer_penalty'))
   OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(actual->'claims') c WHERE c->>'category' IN('assignment','other_debt'))
  WHEN 'loan_basis' THEN (p_case->'context'->>'employer_loan')::numeric<=0
  WHEN 'zero_capacity' THEN (actual->>'ceiling')::numeric<>0
  WHEN 'cent_boundary' THEN ((actual->>'wage_basis')::numeric*(actual->>'rate')::numeric*100)=floor((actual->>'wage_basis')::numeric*(actual->>'rate')::numeric*100)
  ELSE true END) THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;

 IF jsonb_typeof(expected) IS DISTINCT FROM 'object' OR NOT(expected ?& ARRAY['wage_basis','ceiling','capacity_amount','unapplied_amount'])
  OR(expected-ARRAY['wage_basis','ceiling','capacity_amount','unapplied_amount','claims'])<>'{}'::jsonb
  OR(p_case->>'scenario'='priority' AND jsonb_typeof(expected->'claims') IS DISTINCT FROM 'array') THEN
  RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 FOREACH key IN ARRAY ARRAY['wage_basis','ceiling','capacity_amount','unapplied_amount'] LOOP
  IF coalesce(expected->>key,'')!~'^[0-9]+(\.[0-9]{1,2})?$' THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
 RETURN jsonb_build_object('actual',actual,'expected',expected,'matched',
  (actual->>'wage_basis')::numeric=(expected->>'wage_basis')::numeric AND(actual->>'ceiling')::numeric=(expected->>'ceiling')::numeric
  AND(actual->>'capacity_amount')::numeric=(expected->>'capacity_amount')::numeric AND(actual->>'unapplied_amount')::numeric=(expected->>'unapplied_amount')::numeric
  AND(NOT(expected ? 'claims') OR expected->'claims'=(SELECT jsonb_agg(jsonb_build_object('id',claim->'id','capacity_amount',claim->'capacity_amount','unapplied_amount',claim->'unapplied_amount') ORDER BY ordinality) FROM jsonb_array_elements(actual->'claims') WITH ORDINALITY item(claim,ordinality))),'qualified',false);
END $f$;
REVOKE ALL ON FUNCTION payroll.compare_labour_deduction_case(payroll.statutory_draft_versions,jsonb) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.statutory_current_comparisons(uuid,integer)'::regprocedure);
 anchor:='left(case_data->''tax''->>''from'',4)';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_comparison_year_identity';END IF;
 EXECUTE replace(definition,anchor,'coalesce(left(case_data->''tax''->>''from'',4),case_data->>''year'')');
 definition:=pg_get_functiondef('payroll.validate_statutory_draft_rules(jsonb)'::regprocedure);
 anchor:='p_rules-''earning_partition_rounding''-ARRAY';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_draft_keys';END IF;
 definition:=replace(definition,anchor,'p_rules-''labour_deduction_adapter''-''earning_partition_rounding''-ARRAY');
 anchor:=' t:=p_rules->''tax'';';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_draft_validation';END IF;
 EXECUTE replace(definition,anchor,' IF p_rules ? ''labour_deduction_adapter'' AND p_rules->>''labour_deduction_adapter'' IS DISTINCT FROM ''eg-wage-deductions113114-v1'' THEN RAISE EXCEPTION ''statutory_numeric_invalid'' USING ERRCODE=''22023'';END IF;'||anchor);
 definition:=pg_get_functiondef('payroll.statutory_draft_pack(payroll.statutory_draft_versions,text)'::regprocedure);
 anchor:=' RETURN pack;';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_pack_return';END IF;
 EXECUTE replace(definition,anchor,' pack.labour_rules:=CASE WHEN r ? ''labour_deduction_adapter'' THEN jsonb_build_object(''adapter'',r->''labour_deduction_adapter'',''source'',''https://portal.eta.gov.eg/sites/default/files/2026-03/law.no_.14.of_.2025.pdf'') ELSE ''{}''::jsonb END;'||anchor);
 definition:=pg_get_functiondef('payroll.statutory_draft_compare(payroll.statutory_draft_versions,text,jsonb)'::regprocedure);
 anchor:=' IF octet_length(p_case::text)';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_compare_branch';END IF;
 EXECUTE replace(definition,anchor,' IF p_case->>''domain''=''labour_deductions'' THEN RETURN payroll.compare_labour_deduction_case(p_version,p_case);END IF;'||anchor);
 definition:=pg_get_functiondef('public.statutory_draft_issue(uuid,integer,uuid,text,boolean,text)'::regprocedure);
 anchor:='engine_adapter,rules,insurance_rules,earning_rules)';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_issuance_columns';END IF;
 definition:=replace(definition,anchor,'engine_adapter,rules,insurance_rules,earning_rules,labour_rules)');
 anchor:='pack.rules,pack.insurance_rules,pack.earning_rules);';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_issuance_values';END IF;
 EXECUTE replace(definition,anchor,'pack.rules,pack.insurance_rules,pack.earning_rules,pack.labour_rules);');
 definition:=pg_get_functiondef('payroll.issued_tax_qualification(uuid,date,date)'::regprocedure);
 anchor:='OR pack.earning_rules IS DISTINCT FROM expected.earning_rules';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_immutable_evidence';END IF;
 EXECUTE replace(definition,anchor,anchor||' OR pack.labour_rules IS DISTINCT FROM expected.labour_rules');
END $patch$;

CREATE FUNCTION payroll.issued_labour_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE qualification jsonb;pack payroll.statutory_packs;version payroll.statutory_draft_versions;
 issuance payroll.statutory_draft_issuances;comparison payroll.statutory_draft_comparisons;scenario text;year_number integer;ids jsonb:='[]';BEGIN
 qualification:=payroll.issued_tax_qualification(p_pack,p_from,p_until);
 IF qualification->>'ready' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('ready',false,'reason','issued_labour_evidence_required');END IF;
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 SELECT * INTO issuance FROM payroll.statutory_draft_issuances WHERE pack_id=p_pack;
 SELECT * INTO version FROM payroll.statutory_draft_versions WHERE head_id=issuance.head_id AND revision=issuance.revision;
 IF pack.labour_rules->>'adapter' IS DISTINCT FROM 'eg-wage-deductions113114-v1' THEN
  RETURN jsonb_build_object('ready',false,'reason','issued_labour_rules_required');END IF;
 FOR year_number IN extract(year FROM p_from)::integer..extract(year FROM p_until)::integer LOOP
  FOREACH scenario IN ARRAY ARRAY['ordinary_limit','alimony_limit','priority','loan_basis','zero_capacity','cent_boundary'] LOOP
   SELECT * INTO comparison FROM payroll.statutory_current_comparisons(issuance.head_id,issuance.revision) c
    WHERE c.case_data->>'domain'='labour_deductions' AND c.case_data->>'scenario'=scenario
     AND c.case_data->>'year'=year_number::text AND c.case_data->>'origin'='official'
     AND c.result->>'matched'='true' AND pack.review_evidence->'representative_case_ids' @> to_jsonb(c.id)
    ORDER BY c.id DESC LIMIT 1;
   IF comparison.id IS NULL OR comparison.result IS DISTINCT FROM payroll.compare_labour_deduction_case(version,comparison.case_data) THEN
    RETURN jsonb_build_object('ready',false,'reason','official_labour_coverage_required');END IF;
   ids:=ids||to_jsonb(comparison.id);
  END LOOP;
 END LOOP;
 RETURN jsonb_build_object('ready',true,'scope','issued_labour_deductions113114','pack_id',p_pack,'evidence_stamp',issuance.evidence_stamp,'case_ids',ids);
END $f$;
REVOKE ALL ON FUNCTION payroll.issued_labour_qualification(uuid,date,date) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.statutory_issuance_readiness(uuid,integer)'::regprocedure);
 anchor:=' RETURN jsonb_build_object(''revision'',h.revision';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_labour_issuance_readiness';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF v.numeric_rules ? 'labour_deduction_adapter' THEN
  FOR year_number IN SELECT generate_series(extract(year FROM v.effective_from)::integer,extract(year FROM(v.effective_until-1))::integer) LOOP
   FOREACH scenario IN ARRAY ARRAY['ordinary_limit','alimony_limit','priority','loan_basis','zero_capacity','cent_boundary'] LOOP
    SELECT id INTO case_id FROM payroll.statutory_current_comparisons(p_head,p_expected) c
     WHERE c.case_data->>'domain'='labour_deductions' AND c.case_data->>'scenario'=scenario
      AND c.case_data->>'year'=year_number::text AND c.case_data->>'origin'='official' AND c.result->>'matched'='true'
      AND c.result=payroll.compare_labour_deduction_case(v,c.case_data) ORDER BY id DESC LIMIT 1;
    IF case_id IS NULL THEN blockers:=blockers||jsonb_build_array('official_labour_coverage_required');
    ELSE selected_ids:=selected_ids||to_jsonb(case_id);END IF;
   END LOOP;
  END LOOP;
 END IF;
 RETURN jsonb_build_object('revision',h.revision$insert$);
 definition:=pg_get_functiondef('payroll.validate_input(text,jsonb)'::regprocedure);
 anchor:=' IF keys IS NULL OR';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_deduction_input_keys';END IF;
 definition:=replace(definition,anchor,' IF p_kind=''adjustment'' THEN keys:=keys||ARRAY[''deduction_category'',''consent_reference''];END IF;'||anchor);
 anchor:=' IF p_kind=''policy''';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_deduction_input_validation';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF p_data ?| ARRAY['deduction_category','consent_reference'] AND(
  p_kind<>'adjustment' OR coalesce(p_data->>'deduction_category','') NOT IN('alimony','employer_damage','employer_overpayment','employer_penalty','assignment','other_debt')
  OR jsonb_typeof(p_data->'deduction_category') IS DISTINCT FROM 'string'
  OR jsonb_typeof(p_data->'reference') IS DISTINCT FROM 'string' OR length(btrim(p_data->>'reference')) NOT BETWEEN 3 AND 160
  OR(p_data ? 'consent_reference' AND (jsonb_typeof(p_data->'consent_reference') IS DISTINCT FROM 'string' OR length(btrim(p_data->>'consent_reference')) NOT BETWEEN 3 AND 160))
  OR(p_data->>'deduction_category'='assignment' AND NOT(p_data ? 'consent_reference'))) THEN
  RAISE EXCEPTION 'payroll_deduction_source_invalid' USING ERRCODE='22023';END IF;
 IF p_kind='policy'$insert$);
END $patch$;

CREATE FUNCTION payroll.compose_reviewed_wage_deductions(p_manifest jsonb,p_employee jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE source jsonb;line jsonb;data jsonb;segment jsonb;proof jsonb;qualification jsonb;plan jsonb;
 claims jsonb:='[]';loans jsonb:='[]';loan_items jsonb:='[]';lines jsonb;issues jsonb;calculated jsonb;manifest jsonb;
 employee jsonb;proofs jsonb:='[]';packs jsonb;claim jsonb;code text;employment uuid:=(p_employee->>'employment_id')::uuid;
 amount numeric;total numeric:=0;loan_total numeric:=0;tax numeric;insurance numeric;gross numeric;net numeric;
BEGIN
 IF p_employee->>'gross_complete' IS DISTINCT FROM 'true' THEN RETURN p_employee;END IF;
 FOR line IN SELECT value FROM jsonb_array_elements(p_employee->'lines') WHERE value->>'classification'='deduction' AND value->>'component' NOT LIKE 'advance:%' LOOP
  IF line->>'component' NOT LIKE 'adjustment:%' THEN RAISE EXCEPTION 'payroll_deduction_approval_required' USING ERRCODE='22023';END IF;
  source:=payroll.manifest_input(p_manifest,split_part(line->>'component',':',2)::uuid,(p_employee->>'starts_on')::date);
  data:=source->'version'->'data';amount:=(line->>'amount')::numeric;
  IF source->'head'->>'kind' IS DISTINCT FROM 'adjustment'
   OR source->'head'->>'employment_id' IS DISTINCT FROM employment::text
   OR source->'head'->>'period_id' IS DISTINCT FROM p_manifest->'period'->>'id'
   OR source->'version'->>'status' IS DISTINCT FROM 'approved'
   OR amount IS DISTINCT FROM(data->>'amount')::numeric THEN
   RAISE EXCEPTION 'payroll_deduction_approval_required' USING ERRCODE='22023';END IF;
  claims:=claims||jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('id',source->'head'->>'id','amount',amount,
   'category',data->'deduction_category','reference',data->'reference','consent_reference',data->'consent_reference')));
  total:=total+amount;
 END LOOP;
 SELECT coalesce(jsonb_agg(value ORDER BY value->>'advance',value->>'ordinal'),'[]') INTO loans
  FROM jsonb_array_elements(coalesce(p_manifest->'advances','[]')) WHERE value->>'employment_id'=employment::text;
 IF jsonb_array_length(loans)>0 AND (p_employee->>'pay_basis'<>'monthly'
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->'lines') earning WHERE earning->>'classification'='earning' AND earning->>'component'<>'base')) THEN
  RAISE EXCEPTION 'financial_profile_composition_required' USING ERRCODE='22023';END IF;
 SELECT coalesce(jsonb_agg(value),'[]') INTO lines FROM jsonb_array_elements(p_employee->'lines') WHERE value->>'classification'<>'deduction';
 SELECT coalesce(jsonb_agg(value),'[]') INTO issues FROM jsonb_array_elements(p_employee->'issues') WHERE value->>'code' NOT IN('advance_caps_unqualified','advance_allowance_stale','advance_carry_forward_required');
 employee:=p_employee||jsonb_build_object('lines',lines,'deductions','0','advance_deductions','[]'::jsonb,'issues',issues);
 SELECT coalesce(jsonb_agg(value),'[]') INTO lines FROM jsonb_array_elements(coalesce(p_manifest->'advances','[]')) WHERE value->>'employment_id'<>employment::text;
 manifest:=p_manifest||jsonb_build_object('advances',lines);
 calculated:=payroll.compose_statutory_review(manifest,employee);
 IF calculated->>'financially_qualified' IS DISTINCT FROM 'true' THEN
  RETURN p_employee||jsonb_build_object('issues',(p_employee->'issues')||(calculated->'issues'),'financially_qualified',false,'net',NULL);END IF;
 packs:=CASE WHEN calculated ? 'statutory_segments' THEN calculated->'statutory_segments'
  ELSE jsonb_build_array(jsonb_build_object('starts_on',p_employee->'starts_on','ends_on',p_employee->'ends_on','statutory_calculation',calculated->'statutory_calculation')) END;
 IF jsonb_array_length(claims)>0 THEN
  FOR segment IN SELECT value FROM jsonb_array_elements(packs) LOOP
   proof:=payroll.issued_labour_qualification((segment->'statutory_calculation'->>'pack_id')::uuid,
    (segment->>'starts_on')::date,(segment->>'ends_on')::date);
   proofs:=proofs||jsonb_build_array(proof);
   IF proof->>'ready' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'issued_labour_evidence_required' USING ERRCODE='22023';END IF;
  END LOOP;
 END IF;
 gross:=(calculated->>'gross')::numeric;insurance:=0;tax:=0;
 FOR segment IN SELECT value FROM jsonb_array_elements(packs) LOOP
  insurance:=insurance+(segment->'statutory_calculation'->'insurance'->>'employee_total')::numeric;
  tax:=tax+(segment->'statutory_calculation'->'tax'->>'current_tax_delta')::numeric;
 END LOOP;
 IF jsonb_array_length(loans)>0 THEN
  IF p_manifest->'optional'->'finance'->>'enabled' IS DISTINCT FROM 'true'
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(loans) loan WHERE coalesce(loan->>'outstanding','')!~'^[0-9]+(\.[0-9]{1,2}0*)?$' OR(loan->>'outstanding')::numeric<=0) THEN
   RAISE EXCEPTION 'advance_source_invalid' USING ERRCODE='22023';END IF;
  SELECT sum((value->>'outstanding')::numeric) INTO loan_total FROM jsonb_array_elements(loans);
  IF loan_total>floor(gross*0.10*100)/100 OR loan_total>(calculated->>'calculated_net')::numeric THEN
   RAISE EXCEPTION 'advance_capacity_disposition_required' USING ERRCODE='22023';END IF;
 END IF;
 plan:=payroll.calculate_wage_deduction_plan(jsonb_build_object('gross',gross,'tax',tax,'employee_insurance',insurance,'employer_loan',loan_total,'claims',claims));
 IF plan->>'ready' IS DISTINCT FROM 'true' THEN
  RETURN p_employee||jsonb_build_object('financially_qualified',false,'net',NULL,'deduction_plan',plan,
   'deduction_unapplied',plan->'claims','issues',p_employee->'issues'||jsonb_build_array(payroll.issue('payroll_deduction_capacity_disposition_required',employment,'employee_finance')));END IF;
 lines:=calculated->'lines';
 FOR claim IN SELECT value FROM jsonb_array_elements(p_employee->'lines') WHERE value->>'classification'='deduction' AND value->>'component' NOT LIKE 'advance:%' LOOP
  lines:=lines||jsonb_build_array(claim);
 END LOOP;
 FOR source IN SELECT value FROM jsonb_array_elements(loans) LOOP
  loan_items:=loan_items||jsonb_build_array(source||jsonb_build_object('consumed_amount',source->>'outstanding',
   'cap_evidence',jsonb_build_object('contract','eg-employer-loan-113-v1','wage_basis',gross::text,'aggregate_due',loan_total,
    'ceiling',floor(gross*0.10*100)/100,'law_reference','Law14/2025 Article113','statutory_segments',packs)));
  lines:=lines||jsonb_build_array(jsonb_build_object('component','advance:'||(source->>'installment'),'name','قسط سلفة مستحق','classification','deduction',
   'amount',source->>'outstanding','details',jsonb_build_array(jsonb_build_object('source_revision',source->'revision','wage_basis',gross,'ceiling',floor(gross*0.10*100)/100))));
 END LOOP;
 net:=(calculated->>'calculated_net')::numeric-total-loan_total;
 IF net<0 THEN RAISE EXCEPTION 'negative_statutory_balance' USING ERRCODE='22023';END IF;
 qualification:=calculated->'financial_qualification';
 RETURN calculated||jsonb_build_object('lines',lines,'deductions',(total+loan_total)::text,'net',net::text,'calculated_net',net::text,
  'advance_deductions',loan_items,'deduction_plan',plan,'financial_qualification',qualification||jsonb_build_object('profile','eg-wage-deductions113114-v1',
   'tax_insurance_composition',qualification,'labour_evidence',proofs,'approved_deduction_sources',claims));
EXCEPTION WHEN SQLSTATE '22023' THEN
 GET STACKED DIAGNOSTICS code=MESSAGE_TEXT;
 RETURN p_employee||jsonb_build_object('issues',p_employee->'issues'||jsonb_build_array(payroll.issue(code,employment,'employee_finance')),
  'financially_qualified',false,'net',NULL);
END $f$;
REVOKE ALL ON FUNCTION payroll.compose_reviewed_wage_deductions(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:=' IF jsonb_array_length(sources->''contexts'')>1';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_wage_deduction_composition_branch';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->'lines') line WHERE line->>'classification'='deduction' AND line->>'component' NOT LIKE 'advance:%')
  OR(jsonb_array_length(sources->'contexts')>1 AND jsonb_array_length(loan_sources)>0) THEN
  RETURN payroll.compose_reviewed_wage_deductions(p_manifest,p_employee);END IF;
 IF jsonb_array_length(sources->'contexts')>1$insert$);
 definition:=pg_get_functiondef('payroll.build_review(jsonb)'::regprocedure);
 anchor:='AND employee->''financial_qualification''->>''profile''=''eg-monthly-employer-loans-single-context-v1''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_wage_deduction_root_issues';END IF;
 definition:=replace(definition,anchor,'AND employee->''financial_qualification''->>''profile'' IN(''eg-monthly-employer-loans-single-context-v1'',''eg-wage-deductions113114-v1'')');
 anchor:='AND employee->''financial_qualification''->>''profile''=''eg-reviewed-context-year-segments-v1''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_wage_deduction_year_issue';END IF;
 EXECUTE replace(definition,anchor,'AND employee->''financial_qualification''->>''profile'' IN(''eg-reviewed-context-year-segments-v1'',''eg-wage-deductions113114-v1'') AND employee->>''financially_qualified''=''true''');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_wage_deduction_engine';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-wage-deductions113114-v1'');'||anchor);
END $patch$;
