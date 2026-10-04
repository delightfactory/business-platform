-- Close the approved employer-loan slice using the actual wage/tax producer.
-- Article113's10% limit is fixed code, not a user-defined rule/allowance.
-- Over-cap/insufficient balances remain unapplied and require the existing
-- approved deferral/external-settlement route; no silent partial allocation.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='qualification jsonb;profile boolean;';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_profile_declarations';END IF;
 definition:=replace(definition,anchor,'qualification jsonb;profile boolean;original_employee jsonb:=p_employee;loan_sources jsonb;loan_source jsonb;loan_total numeric;loan_limit numeric;loan_net numeric;loan_operational numeric;loan_lines jsonb;loan_items jsonb;loan_code text;');
 anchor:='BEGIN'||chr(10)||' IF p_employee->>''gross_complete''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_profile_begin';END IF;
 definition:=replace(definition,anchor,$insert$BEGIN
 SELECT coalesce(jsonb_agg(source ORDER BY source->>'scheduled_period',source->>'advance',source->>'ordinal'),'[]') INTO loan_sources
  FROM jsonb_array_elements(coalesce(p_manifest->'advances','[]'::jsonb)) source WHERE source->>'employment_id'=employment::text;
 IF p_employee->>'gross_complete'$insert$);
 anchor:='     facts:=jsonb_build_object(''prior_net_income''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_numeric_projection';END IF;
 definition:=replace(definition,anchor,$insert$
 -- Remove the future-allowance projection only after supported source facts
 -- and the exact statutory pack have resolved. Unsupported legacy reviews
 -- retain their operational lines and reviewed allowances.
 SELECT coalesce(sum((line->>'amount')::numeric),0) INTO loan_operational FROM jsonb_array_elements(p_employee->'lines') line
  WHERE line->>'component' LIKE 'advance:%' AND line->>'classification'='deduction';
 IF jsonb_array_length(loan_sources)>0 THEN
  IF p_employee->>'pay_basis'<>'monthly' OR (p_employee->>'deductions')::numeric-loan_operational<>0
   OR coalesce((p_manifest->'optional'->>'time')::boolean,false) OR coalesce((p_manifest->'optional'->>'leave')::boolean,false)
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->'lines') line WHERE line->>'classification'='earning' AND line->>'component'<>'base') THEN
   RETURN original_employee||jsonb_build_object('issues',original_employee->'issues'||jsonb_build_array(payroll.issue('financial_profile_composition_required',employment,'payroll_compliance')));
  END IF;
  SELECT coalesce(jsonb_agg(line),'[]') INTO loan_lines FROM jsonb_array_elements(p_employee->'lines') line WHERE line->>'component' NOT LIKE 'advance:%';
  p_employee:=p_employee||jsonb_build_object('lines',loan_lines,'deductions',((p_employee->>'deductions')::numeric-loan_operational)::text,'advance_deductions','[]'::jsonb);
 END IF;
     facts:=jsonb_build_object('prior_net_income'$insert$);
 anchor:='RETURN p_employee||jsonb_build_object(''issues'',p_employee->''issues''||jsonb_build_array(payroll.issue(code,employment,''payroll_compliance'')));';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_worker_failure_recovery';END IF;
 definition:=replace(definition,anchor,'RETURN original_employee||jsonb_build_object(''issues'',original_employee->''issues''||jsonb_build_array(payroll.issue(code,employment,''payroll_compliance'')));');
 anchor:='      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_manifest->''advances'',''[]''::jsonb)) a WHERE a->>''employment_id''=employment::text)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_profile_scope';END IF;
 definition:=replace(definition,anchor,'');
 anchor:='     calculated:=calculated||jsonb_build_object(''financially_qualified'',qualification->>''ready''=''true'',';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_profile_result';END IF;
 definition:=replace(definition,anchor,$insert$
     IF profile AND jsonb_array_length(loan_sources)>0 THEN
      loan_total:=(SELECT sum((source->>'outstanding')::numeric) FROM jsonb_array_elements(loan_sources) source);
      loan_limit:=floor((calculated->>'gross')::numeric*0.10*100)/100;
      loan_net:=(calculated->>'calculated_net')::numeric-loan_total;loan_items:='[]';loan_code:=NULL;
      IF p_manifest->'optional'->'finance'->>'enabled' IS DISTINCT FROM 'true' THEN loan_code:='advance_finance_disabled';
      ELSIF loan_total<=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(loan_sources) source WHERE coalesce(source->>'outstanding','')!~'^[0-9]+(\.[0-9]{1,2}0*)?$' OR(source->>'outstanding')::numeric<=0) THEN loan_code:='advance_source_invalid';
      ELSIF loan_total>loan_limit OR loan_net<0 THEN loan_code:='advance_capacity_disposition_required';END IF;
      SELECT coalesce(jsonb_agg(issue),'[]') INTO loan_lines FROM jsonb_array_elements(calculated->'issues') issue
       WHERE issue->>'code' NOT IN('advance_caps_unqualified','advance_allowance_stale','advance_carry_forward_required');
      calculated:=calculated||jsonb_build_object('issues',loan_lines);
      IF loan_code IS NULL THEN
       loan_lines:=calculated->'lines';
       FOR loan_source IN SELECT value FROM jsonb_array_elements(loan_sources) LOOP
        loan_items:=loan_items||jsonb_build_array(loan_source||jsonb_build_object('consumed_amount',loan_source->>'outstanding',
         'cap_evidence',jsonb_build_object('contract','eg-employer-loan-113-v1','wage_basis',calculated->'gross','aggregate_due',loan_total,
          'ceiling',loan_limit,'tax_pack',tax_pack,'context_version',context->'version_id','law_reference','Law14/2025 Article113')));
        loan_lines:=loan_lines||jsonb_build_array(jsonb_build_object('component','advance:'||(loan_source->>'installment'),
         'name','قسط سلفة صاحب العمل','classification','deduction','amount',loan_source->>'outstanding',
         'details',jsonb_build_array(jsonb_build_object('reason','القسط المستحق ضمن حد10% من الأجر؛ لا فائدة','approved_amount',loan_source->>'outstanding',
          'source_revision',loan_source->'revision','wage_basis',calculated->'gross','ceiling',loan_limit))));
       END LOOP;
       calculated:=calculated||jsonb_build_object('lines',loan_lines,'deductions',loan_total::text,'net',loan_net::text,
        'calculated_net',loan_net::text,'advance_deductions',loan_items);
      ELSE
       calculated:=calculated||jsonb_build_object('financially_qualified',false,'net',NULL,'advance_deductions','[]'::jsonb,
        'advance_unapplied',loan_sources,'issues',calculated->'issues'||jsonb_build_array(payroll.issue(loan_code,employment,'employee_finance')));
       qualification:=qualification||jsonb_build_object('ready',false,'reason',loan_code);
      END IF;
     END IF;
     calculated:=calculated||jsonb_build_object('financially_qualified',qualification->>'ready'='true',$insert$);
 anchor:='''profile'',''eg-monthly-nondebt-single-context-v1''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_profile_evidence';END IF;
 definition:=replace(definition,anchor,'''profile'',CASE WHEN jsonb_array_length(loan_sources)>0 THEN ''eg-monthly-employer-loans-single-context-v1'' ELSE ''eg-monthly-nondebt-single-context-v1'' END');
 anchor:='''labour_debt_deductions'',''none''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_profile_debt_evidence';END IF;
 EXECUTE replace(definition,anchor,'''labour_debt_deductions'',CASE WHEN jsonb_array_length(loan_sources)>0 THEN ''employer_loans_article113'' ELSE ''none'' END');

 -- Remove only obsolete per-employee allowance blockers that the new exact
 -- derivation has resolved. Do not remove unavailable-employment/sibling issues.
 definition:=pg_get_functiondef('payroll.build_review(jsonb)'::regprocedure);
 anchor:=' IF jsonb_array_length(employees)>0 AND NOT EXISTS';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_root_issues';END IF;
 definition:=replace(definition,anchor,$insert$
 SELECT coalesce(jsonb_agg(issue),'[]') INTO issues FROM jsonb_array_elements(issues) issue
 WHERE NOT(issue->>'code' IN('advance_caps_unqualified','advance_allowance_stale','advance_carry_forward_required')
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee WHERE employee->>'employment_id'=issue->>'employment_id'
   AND employee->'financial_qualification'->>'profile'='eg-monthly-employer-loans-single-context-v1'
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employee->'issues') current_issue WHERE current_issue->>'code'=issue->>'code')));
 IF jsonb_array_length(employees)>0 AND NOT EXISTS$insert$);
 anchor:='''employer_cost'',(SELECT sum((employee->>''employer_cost'')::numeric)::text FROM jsonb_array_elements(employees) employee),';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_root_deduction_total';END IF;
 EXECUTE replace(definition,anchor,'''deductions'',(SELECT sum((employee->>''deductions'')::numeric)::text FROM jsonb_array_elements(employees) employee),'||anchor);

 -- Keep the legacy trusted-allowance branch. A new computed claim must match
 -- its exact manifest source and wage ceiling; the public consumer additionally
 -- recomputes the complete real producer before this private append is reached.
 definition:=pg_get_functiondef('payroll.append_final_output_single(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
 anchor:='s=item-''consumed_amount''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_source_membership';END IF;
 definition:=replace(definition,anchor,'s=item-''consumed_amount''-''cap_evidence''');
 anchor:='OR(item->>''consumed_amount'') IS DISTINCT FROM item->''allowance''->>''amount''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_append_amount';END IF;
 definition:=replace(definition,anchor,$insert$OR (CASE WHEN item->'cap_evidence'->>'contract'='eg-employer-loan-113-v1' THEN
  (item->>'consumed_amount')::numeric<>(item->>'outstanding')::numeric
  OR(item->'cap_evidence'->>'wage_basis')::numeric IS DISTINCT FROM(e->>'gross')::numeric
  OR(item->'cap_evidence'->>'ceiling')::numeric IS DISTINCT FROM floor((e->>'gross')::numeric*0.10*100)/100
  OR(item->'cap_evidence'->>'aggregate_due')::numeric IS DISTINCT FROM(SELECT sum((claim->>'consumed_amount')::numeric) FROM jsonb_array_elements(e->'advance_deductions') claim)
  OR(item->'cap_evidence'->>'aggregate_due')::numeric>(item->'cap_evidence'->>'ceiling')::numeric
  ELSE(item->>'consumed_amount') IS DISTINCT FROM item->'allowance'->>'amount' END)$insert$);
 EXECUTE definition;
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:='''-nondebt-qualified-v1''';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_loan_engine';END IF;
 EXECUTE replace(definition,anchor,'''-nondebt-qualified-v1-employer-loan113-v1''');
END $patch$;
