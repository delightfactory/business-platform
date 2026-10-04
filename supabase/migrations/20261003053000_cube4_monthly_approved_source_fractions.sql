-- Apply approved reconciled unpaid units once to the saved monthly base.
-- Calendar-days uses the existing dated salary denominator. Fixed30 unpaid
-- interpretation remains explicit pending its bounded contract; no guess.
CREATE FUNCTION payroll.monthly_source_parts(p_manifest jsonb,p_employment jsonb,p_reconciled jsonb,p_parts jsonb,p_mode text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE hid uuid:=(p_employment->>'id')::uuid;coverage jsonb;selected jsonb;part jsonb;day jsonb;
 result jsonb:='[]';issues jsonb:='[]';unpaid numeric;paid numeric;summary jsonb;
BEGIN
 summary:=p_reconciled->'summary'||jsonb_build_object('selected_source','monthly_approved_sources','coverage','approved_leave_sources');
 IF p_reconciled->'issues' IS DISTINCT FROM '[]'::jsonb THEN
  RETURN jsonb_build_object('parts',p_parts,'summary',summary,'issues',p_reconciled->'issues');END IF;
 IF p_manifest->'optional'->>'time'='true' THEN
  SELECT coalesce(jsonb_agg(candidate.value),'[]') INTO selected FROM jsonb_array_elements(p_parts) candidate(value)
   WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(p_manifest->'optional_sources'->'time'->'coverage'->'items') expected
    WHERE expected->>'employment_id'=hid::text AND expected->>'date'=candidate.value->>'date' AND expected->>'expected'='true');
  coverage:=payroll.complete_daily_time_coverage(p_manifest,p_employment,p_reconciled,selected);
  IF coverage->>'complete' IS DISTINCT FROM 'true' THEN
   RETURN jsonb_build_object('parts',p_parts,'summary',summary,'issues',coverage->'issues');END IF;
  summary:=summary||jsonb_build_object('operational_complete',true,'coverage','operational_complete');
 END IF;
 FOR part IN SELECT value FROM jsonb_array_elements(p_parts) LOOP
  SELECT value INTO day FROM jsonb_array_elements(p_reconciled->'days') WHERE value->>'date'=part->>'date';
  unpaid:=coalesce((day->>'absence_units')::numeric,0)+coalesce((day->>'unpaid_leave_units')::numeric,0);
  IF unpaid NOT BETWEEN 0 AND 1 OR unpaid*100<>trunc(unpaid*100) THEN
   issues:=issues||jsonb_build_array(payroll.issue('source_monthly_units_invalid',hid,'payroll_time'));result:=result||jsonb_build_array(part);CONTINUE;
  ELSIF unpaid>0 AND p_mode='fixed_30_day' THEN
   issues:=issues||jsonb_build_array(payroll.issue('monthly_fixed30_unpaid_basis_required',hid,'payroll_config'));result:=result||jsonb_build_array(part);CONTINUE;
  END IF;
  paid:=1-unpaid;
  result:=result||jsonb_build_array(part||jsonb_build_object('approved_paid_fraction',paid,'approved_unpaid_fraction',unpaid,
   '_numerator',((part->>'_numerator')::numeric*paid*100)::text,
   '_denominator',((part->>'_denominator')::numeric*100)::text,'raw',((part->>'raw')::numeric*paid)::text));
 END LOOP;
 RETURN jsonb_build_object('parts',result,'summary',summary||jsonb_build_object('status',CASE WHEN issues='[]'::jsonb THEN 'reconciliation_ready' ELSE 'needs_source_review' END),'issues',issues);
END $f$;
REVOKE ALL ON FUNCTION payroll.monthly_source_parts(jsonb,jsonb,jsonb,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.build_review_before_advances(jsonb)'::regprocedure);
 anchor:='  IF source_context->''issues''<>''[]''::jsonb THEN';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_monthly_source_builder';END IF;
 EXECUTE replace(definition,anchor,$insert$
  IF basis='monthly' AND(p_manifest->'optional'->>'time'='true' OR p_manifest->'optional'->>'leave'='true') THEN
   daily_context:=payroll.monthly_source_parts(employee_manifest,h,source_context,base_parts,mode);
   base_parts:=daily_context->'parts';source_context:=jsonb_set(source_context,'{summary}',daily_context->'summary');
   employee_issues:=employee_issues||(daily_context->'issues');
   IF daily_context->'issues'<>'[]'::jsonb THEN complete:=false;END IF;
  END IF;
  IF source_context->'issues'<>'[]'::jsonb THEN$insert$);
 definition:=pg_get_functiondef('payroll.daily_optional_financial_profile(jsonb,jsonb)'::regprocedure);
 anchor:='p_employee->>''pay_basis'' IS DISTINCT FROM ''daily''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_monthly_financial_pay_basis';END IF;
 definition:=replace(definition,anchor,'coalesce(p_employee->>''pay_basis'','''') NOT IN(''daily'',''monthly'')');
 anchor:=' IF summary->>''selected_source''=''time'' THEN';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_monthly_financial_source';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF p_employee->>'pay_basis'='monthly' THEN
  IF summary->>'selected_source' IS DISTINCT FROM 'monthly_approved_sources' THEN RETURN false;END IF;
  IF p_manifest->'optional'->>'time'='true' THEN
   IF summary->>'operational_complete' IS DISTINCT FROM 'true' OR summary->>'coverage' IS DISTINCT FROM 'operational_complete' THEN RETURN false;END IF;
  ELSIF summary->>'coverage' IS DISTINCT FROM 'approved_leave_sources' THEN RETURN false;END IF;
 ELSIF summary->>'selected_source'='time' THEN$insert$);
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='ELSE ''none'' END';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_monthly_valuation_evidence';END IF;
 EXECUTE replace(definition,anchor,'ELSE CASE WHEN p_employee->''source_summary''->>''selected_source''=''monthly_approved_sources'' THEN ''existing_approved_monthly_payable_fractions'' ELSE ''none'' END END');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_monthly_manifest';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-monthly-approved-source-fractions-v1'');'||anchor);
END $patch$;
