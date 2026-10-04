-- A reviewed monthly liability is source evidence, not salary proration.
-- The operator must explicitly record due/not-due for partial/cutoff cases;
-- absence retains the previous complete-month-only compatibility contract.
-- Real independent tax/insurance issuer evidence remains mandatory.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.validate_employee_statutory_context(jsonb)'::regprocedure);
 anchor:='p_data-ARRAY[''tax_treatment_code''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_keys';END IF;
 definition:=replace(definition,anchor,'(p_data-''insurance_month_disposition'')-ARRAY[''tax_treatment_code''');
 anchor:=' IF p_data ?| ARRAY[''insurance_obligation_month''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_validation';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF p_data ? 'insurance_month_disposition' AND (
   p_data->>'insurance_status' IS DISTINCT FROM 'insured'
   OR jsonb_typeof(p_data->'insurance_month_disposition') IS DISTINCT FROM 'string'
   OR p_data->>'insurance_month_disposition' NOT IN('reviewed_due','reviewed_not_due')
   OR NOT(p_data ?& ARRAY['insurance_obligation_month','insurance_owner_period','insurance_obligation_reference'])) THEN
  RAISE EXCEPTION 'payroll_insurance_disposition_invalid' USING ERRCODE='22023';END IF;
 IF p_data ?| ARRAY['insurance_obligation_month'$insert$);

 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='insurance_original uuid;';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_declaration';END IF;
 definition:=replace(definition,anchor,anchor||'insurance_month_end date;insurance_disposition text;');
 anchor:='      IF insurance_month IS DISTINCT FROM(p_employee->>''starts_on'')::date';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_scope';END IF;
 definition:=replace(definition,anchor,$insert$
      insurance_month_end:=(insurance_month+interval '1 month'-interval '1 day')::date;
      insurance_disposition:=data->>'insurance_month_disposition';
      IF insurance_disposition IS NOT NULL THEN
       -- This is an explicit documented liability/exclusion, never a checkbox
       -- claiming legal pack qualification. Category/rates still come from the
       -- immutable independently issued pack and actual worker.
       IF data->>'insurance_owner_period' IS DISTINCT FROM p_manifest->'period'->>'id'
        OR(p_manifest->'period'->>'tenant_id')::uuid IS NULL
        OR insurance_month>(p_employee->>'ends_on')::date
        OR insurance_month_end<(p_employee->>'starts_on')::date
        OR(data->>'insurance_from')::date>insurance_month_end
        OR(data ? 'insurance_until' AND(data->>'insurance_until')::date<insurance_month) THEN
        RETURN original_employee||jsonb_build_object('issues',original_employee->'issues'||jsonb_build_array(payroll.issue('insurance_month_scope_required',employment,'payroll_compliance')));END IF;
      ELSIF insurance_month IS DISTINCT FROM(p_employee->>'starts_on')::date$insert$);
 anchor:='      IF EXISTS(SELECT 1 FROM payroll.final_employees final_employee';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_claim';END IF;
 definition:=replace(definition,anchor,'      IF insurance_disposition IS DISTINCT FROM ''reviewed_not_due'' AND EXISTS(SELECT 1 FROM payroll.final_employees final_employee');
 anchor:='AND pack.effective_from<=insurance_month AND pack.effective_until IS NOT NULL'||chr(10)||'       AND pack.effective_until>(p_employee->>''ends_on'')::date;';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_pack_coverage';END IF;
 definition:=replace(definition,anchor,'AND pack.effective_from<=insurance_month AND pack.effective_until IS NOT NULL'||chr(10)||'       AND pack.effective_until>insurance_month_end;');
 anchor:='''obligation_months'',jsonb_build_array(jsonb_build_object(''month'',insurance_month,''insured_wage'',(data->>''insured_wage'')::numeric,''insured_wage_source'',data->''reference'')))';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_obligations';END IF;
 definition:=replace(definition,anchor,'''obligation_months'',CASE WHEN insurance_disposition=''reviewed_not_due'' THEN ''[]''::jsonb ELSE jsonb_build_array(jsonb_build_object(''month'',insurance_month,''insured_wage'',(data->>''insured_wage'')::numeric,''insured_wage_source'',data->''reference'')) END)');
 anchor:='payroll.issued_tax_qualification(insurance_pack,insurance_month,(p_employee->>''ends_on'')::date)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_issuer_scope';END IF;
 definition:=replace(definition,anchor,'payroll.issued_tax_qualification(insurance_pack,insurance_month,insurance_month_end)');
 anchor:='THEN ''reviewed_single_month_owner'' ELSE ''reviewed_not_insured'' END';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_evidence';END IF;
 definition:=replace(definition,anchor,'THEN CASE WHEN insurance_disposition IS NOT NULL THEN ''reviewed_calendar_month_disposition'' ELSE ''reviewed_single_month_owner'' END ELSE ''reviewed_not_insured'' END');
 anchor:='''insurance_pack_id'',insurance_pack';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_snapshot';END IF;
 EXECUTE replace(definition,anchor,anchor||',''insurance_month_disposition'',insurance_disposition,''reviewed_month'',insurance_month');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:='''-nondebt-qualified-v1-employer-loan113-v1-insured-single-month-owner-v1''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partial_insurance_engine';END IF;
 EXECUTE replace(definition,anchor,'''-nondebt-qualified-v1-employer-loan113-v1-insured-single-month-owner-v1-reviewed-partial-insurance-v1''');
END $patch$;
