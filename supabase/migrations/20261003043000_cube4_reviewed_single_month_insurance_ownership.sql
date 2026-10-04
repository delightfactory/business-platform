-- A bounded source contract: one complete civil month, one dated context,
-- explicit employer-period ownership and wage/category/document facts.
-- This does not infer joining/leaving/cutoff-month policy from calendar days.
-- Existing real issuer evidence remains mandatory for both independent packs.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.validate_employee_statutory_context(jsonb)'::regprocedure);
 anchor:='''calculation_from'',''calculation_until'',''tax_duration_days'']';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_keys';END IF;
 definition:=replace(definition,anchor,'''calculation_from'',''calculation_until'',''tax_duration_days'',''insurance_obligation_month'',''insurance_owner_period'',''insurance_obligation_reference'']');
 anchor:=' IF p_data->>''insurance_status''=''not_insured'' THEN';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_validation';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF p_data ?| ARRAY['insurance_obligation_month','insurance_owner_period','insurance_obligation_reference'] THEN
  IF p_data->>'insurance_status'<>'insured'
   OR NOT(p_data ?& ARRAY['insurance_obligation_month','insurance_owner_period','insurance_obligation_reference'])
   OR jsonb_typeof(p_data->'insurance_obligation_month') IS DISTINCT FROM 'string'
   OR coalesce(p_data->>'insurance_obligation_month','')!~'^[0-9]{4}-[0-9]{2}-01$'
   OR jsonb_typeof(p_data->'insurance_owner_period') IS DISTINCT FROM 'string'
   OR coalesce(p_data->>'insurance_owner_period','')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
   OR jsonb_typeof(p_data->'insurance_obligation_reference') IS DISTINCT FROM 'string'
   OR length(btrim(coalesce(p_data->>'insurance_obligation_reference',''))) NOT BETWEEN 3 AND 160 THEN
   RAISE EXCEPTION 'payroll_insurance_ownership_invalid' USING ERRCODE='22023';END IF;
  BEGIN
   IF NOT isfinite((p_data->>'insurance_obligation_month')::date) THEN RAISE EXCEPTION 'payroll_insurance_ownership_invalid' USING ERRCODE='22023';END IF;
  EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN
   RAISE EXCEPTION 'payroll_insurance_ownership_invalid' USING ERRCODE='22023';END;
 END IF;
 IF p_data->>'insurance_status'='not_insured' THEN$insert$);

 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='loan_code text;';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_declarations';END IF;
 definition:=replace(definition,anchor,anchor||'insurance_pack uuid;insurance_matches integer;insurance_context jsonb;insurance_qualification jsonb;insurance_month date;insurance_original uuid;');
 anchor:='  ELSIF data->>''insurance_status'' IS DISTINCT FROM ''not_insured'' THEN';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_scope';END IF;
 definition:=replace(definition,anchor,'  ELSIF data->>''insurance_status'' NOT IN(''insured'',''not_insured'') THEN');
 anchor:='     facts:=jsonb_build_object(''prior_net_income''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_producer';END IF;
 definition:=replace(definition,anchor,$insert$
     IF data->>'insurance_status'='insured' THEN
      IF NOT(data ?& ARRAY['insurance_obligation_month','insurance_owner_period','insurance_obligation_reference']) THEN
       RETURN original_employee||jsonb_build_object('issues',original_employee->'issues'||jsonb_build_array(payroll.issue('insurance_obligation_attribution_required',employment,'payroll_compliance')));END IF;
      insurance_month:=(data->>'insurance_obligation_month')::date;
      IF insurance_month IS DISTINCT FROM(p_employee->>'starts_on')::date
       OR(p_employee->>'ends_on')::date IS DISTINCT FROM(insurance_month+interval '1 month'-interval '1 day')::date
       OR p_manifest->'period'->>'starts_on' IS DISTINCT FROM p_employee->>'starts_on'
       OR p_manifest->'period'->>'ends_on' IS DISTINCT FROM p_employee->>'ends_on'
       OR data->>'insurance_owner_period' IS DISTINCT FROM p_manifest->'period'->>'id'
       OR(p_manifest->'period'->>'tenant_id')::uuid IS NULL
       OR(data->>'insurance_from')::date>insurance_month
       OR(data ? 'insurance_until' AND(data->>'insurance_until')::date<(p_employee->>'ends_on')::date) THEN
       RETURN original_employee||jsonb_build_object('issues',original_employee->'issues'||jsonb_build_array(payroll.issue('insurance_month_scope_required',employment,'payroll_compliance')));END IF;
      insurance_original:=(p_manifest->>'insurance_original_output')::uuid;
      IF EXISTS(SELECT 1 FROM payroll.final_employees final_employee
       WHERE final_employee.tenant_id=(p_manifest->'period'->>'tenant_id')::uuid
        AND final_employee.explanation->>'employee_id'=p_employee->>'employee_id'
        AND final_employee.output_id IS DISTINCT FROM insurance_original
        AND NOT EXISTS(SELECT 1 FROM payroll.output_successions succession WHERE succession.tenant_id=final_employee.tenant_id AND succession.original_output=final_employee.output_id)
        AND EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(final_employee.statutory_context->'obligation_months','[]'::jsonb)) owned WHERE owned->>'month'=insurance_month::text)) THEN
       RETURN original_employee||jsonb_build_object('issues',original_employee->'issues'||jsonb_build_array(payroll.issue('insurance_month_already_consumed',employment,'payroll_compliance')));END IF;
      SELECT count(*),min(pack.id::text)::uuid INTO insurance_matches,insurance_pack
      FROM payroll.statutory_packs pack JOIN jsonb_array_elements(p_manifest->'packs') snapshot ON snapshot->>'id'=pack.id::text
      WHERE snapshot=to_jsonb(pack) AND pack.state='verified' AND pack.engine_adapter='eg-cumulative-tax-v1'
       AND pack.insurance_rules->>'schema'='eg-insurance-month-v1'
       AND pack.insurance_rules->>'category'=data->>'insurance_category'
       AND pack.effective_from<=insurance_month AND pack.effective_until IS NOT NULL
       AND pack.effective_until>(p_employee->>'ends_on')::date;
      IF insurance_matches<>1 THEN RETURN original_employee||jsonb_build_object('issues',original_employee->'issues'||jsonb_build_array(payroll.issue('insurance_pack_missing_or_ambiguous',employment,'payroll_compliance')));END IF;
      insurance_context:=jsonb_build_object('category',data->'insurance_category','source_reference',data->'insurance_obligation_reference',
       'obligation_months',jsonb_build_array(jsonb_build_object('month',insurance_month,'insured_wage',(data->>'insured_wage')::numeric,'insured_wage_source',data->'reference')));
     END IF;
     facts:=jsonb_build_object('prior_net_income'$insert$);
 anchor:='''insurance_status'',''not_insured'',''insurance_exclusion_reference'',data->''reference'');';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_facts';END IF;
 definition:=replace(definition,anchor,'''insurance_status'',data->''insurance_status'');IF data->>''insurance_status''=''not_insured'' THEN facts:=facts||jsonb_build_object(''insurance_exclusion_reference'',data->''reference'');END IF;');
 anchor:='payroll.calculate_statutory_employee_with_earnings(p_employee,tax_pack,facts,NULL,NULL)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_worker';END IF;
 definition:=replace(definition,anchor,'payroll.calculate_statutory_employee_with_earnings(p_employee,tax_pack,facts,insurance_pack,insurance_context)');
 anchor:='     IF profile AND jsonb_array_length(loan_sources)>0 THEN';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_qualification';END IF;
 definition:=replace(definition,anchor,$insert$
     IF profile AND data->>'insurance_status'='insured' THEN
      insurance_qualification:=payroll.issued_tax_qualification(insurance_pack,insurance_month,(p_employee->>'ends_on')::date);
      qualification:=qualification||jsonb_build_object('ready',qualification->>'ready'='true' AND insurance_qualification->>'ready'='true');
     END IF;
     IF profile AND jsonb_array_length(loan_sources)>0 THEN$insert$);
 anchor:='''insurance'',''reviewed_not_insured''';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_evidence';END IF;
 definition:=replace(definition,anchor,'''insurance'',CASE WHEN data->>''insurance_status''=''insured'' THEN ''reviewed_single_month_owner'' ELSE ''reviewed_not_insured'' END,''insurance_evidence'',insurance_qualification');
 anchor:='ELSE ''eg-monthly-nondebt-single-context-v1'' END';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_profile';END IF;
 definition:=replace(definition,anchor,'ELSE CASE WHEN data->>''insurance_status''=''insured'' THEN ''eg-monthly-insured-month-owner-single-context-v1'' ELSE ''eg-monthly-nondebt-single-context-v1'' END END');
 anchor:='''category'',''not_insured'',''insured_wage_source'',data->''reference'',''insured_wage'',0,''obligation_months'',''[]''::jsonb';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_snapshot';END IF;
 definition:=replace(definition,anchor,'''category'',CASE WHEN data->>''insurance_status''=''insured'' THEN data->>''insurance_category'' ELSE ''not_insured'' END,''insured_wage_source'',data->''reference'',''insured_wage'',CASE WHEN insurance_pack IS NOT NULL THEN(data->>''insured_wage'')::numeric ELSE 0 END,''obligation_months'',coalesce(insurance_context->''obligation_months'',''[]''::jsonb),''owner_period'',data->''insurance_owner_period'',''ownership_reference'',data->''insurance_obligation_reference'',''insurance_pack_id'',insurance_pack');
 anchor:='''prior_balance'',balance,''pack_id'',tax_pack';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_binding';END IF;
 EXECUTE replace(definition,anchor,anchor||',''insurance_pack_id'',insurance_pack,''ownership_reference'',data->''insurance_obligation_reference''');

 -- The only excluded claim is the authoritative unpaid original already
 -- checked by the existing amendment path. No client can supply this manifest.
 definition:=pg_get_functiondef('payroll.amendment_manifest(uuid,uuid)'::regprocedure);
 anchor:=' RETURN m;';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_amendment';END IF;
 EXECUTE replace(definition,anchor,' RETURN m||jsonb_build_object(''insurance_original_output'',r.amendment_of);');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:='''-nondebt-qualified-v1-employer-loan113-v1''';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_owner_engine';END IF;
 EXECUTE replace(definition,anchor,'''-nondebt-qualified-v1-employer-loan113-v1-insured-single-month-owner-v1''');
END $patch$;
