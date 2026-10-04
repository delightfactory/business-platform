-- The existing governed earning worker already validates every dated source,
-- taxable share, complement, cent conservation and issued earning-rule pack.
-- Admit that result for reviewed monthly nondebt earnings, including approved
-- manual termination amounts, without inventing an entitlement formula.
-- Source loans retain the earlier base-only wage contract. General deductions
-- and Time/Leave valuation still require their distinct legal composition.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='WHERE line->>''classification''=''deduction'' OR line->>''classification''=''earning'' AND line->>''component''<>''base'');';
 IF(length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'unexpected_reviewed_earnings_profile';END IF;
 definition:=replace(definition,anchor,'WHERE line->>''classification''=''deduction'');');
 anchor:='''profile'',CASE WHEN jsonb_array_length(loan_sources)>0';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_reviewed_earnings_evidence';END IF;
 definition:=replace(definition,anchor,'''earning_composition'',''issued_reviewed_dated_declarations'','||anchor);
 anchor:='ELSE CASE WHEN data->>''insurance_status''=''insured'' THEN ''eg-monthly-insured-month-owner-single-context-v1'' ELSE ''eg-monthly-nondebt-single-context-v1'' END END';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_reviewed_earnings_profile_name';END IF;
 EXECUTE replace(definition,anchor,$insert$ELSE CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->'lines') earning WHERE earning->>'classification'='earning' AND earning->>'component'<>'base')
  THEN 'eg-monthly-reviewed-earnings-single-context-v1'
  WHEN data->>'insurance_status'='insured' THEN 'eg-monthly-insured-month-owner-single-context-v1' ELSE 'eg-monthly-nondebt-single-context-v1' END END$insert$);
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:='''-nondebt-qualified-v1-employer-loan113-v1-insured-single-month-owner-v1-reviewed-partial-insurance-v1''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_reviewed_earnings_engine';END IF;
 EXECUTE replace(definition,anchor,'''-nondebt-qualified-v1-employer-loan113-v1-insured-single-month-owner-v1-reviewed-partial-insurance-v1-reviewed-earnings-v1''');
END $patch$;
