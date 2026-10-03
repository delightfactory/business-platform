-- Compose the existing numeric adapters in the actual candidate calculation.
-- Duration is an explicit dated source fact, never inferred from civil days.
-- Existing issued packs remain tax/insurance-only; public G6 stays closed.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.validate_employee_statutory_context(jsonb)'::regprocedure);
 anchor:='''insurance_until'',''reference'',''reason'']';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_statutory_review_validator_keys';END IF;
 definition:=replace(definition,anchor,'''insurance_until'',''reference'',''reason'',''calculation_from'',''calculation_until'',''tax_duration_days'']');
 anchor:=' IF p_data->>''insurance_status''=''not_insured'' THEN';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_statutory_review_validator_branch';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF p_data ?| ARRAY['calculation_from','calculation_until','tax_duration_days'] THEN
  IF NOT(p_data ?& ARRAY['calculation_from','calculation_until','tax_duration_days'])
   OR coalesce(p_data->>'calculation_from','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   OR coalesce(p_data->>'calculation_until','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   OR coalesce(p_data->>'tax_duration_days','')!~'^[0-9]+(\.[0-9]{1,2})?$' THEN
    RAISE EXCEPTION 'payroll_statutory_duration_invalid' USING ERRCODE='22023';END IF;
  BEGIN
   IF NOT isfinite((p_data->>'calculation_from')::date) OR NOT isfinite((p_data->>'calculation_until')::date)
    OR (p_data->>'calculation_from')::date>(p_data->>'calculation_until')::date
    OR extract(year FROM(p_data->>'calculation_from')::date)<>extract(year FROM(p_data->>'calculation_until')::date)
    OR (p_data->>'tax_duration_days')::numeric NOT BETWEEN 0.01 AND 360 THEN
     RAISE EXCEPTION 'payroll_statutory_duration_invalid' USING ERRCODE='22023';END IF;
  EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN
   RAISE EXCEPTION 'payroll_statutory_duration_invalid' USING ERRCODE='22023';END;
 END IF;
 IF p_data->>'insurance_status'='not_insured' THEN$insert$);
END $patch$;

CREATE FUNCTION payroll.compose_statutory_review(p_manifest jsonb,p_employee jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE sources jsonb:=p_employee->'statutory_sources';context jsonb;data jsonb;balance jsonb;
 facts jsonb;calculated jsonb;tax_pack uuid;matches integer;code text;duration numeric;
 employment uuid:=(p_employee->>'employment_id')::uuid;BEGIN
 IF p_employee->>'gross_complete' IS DISTINCT FROM 'true' THEN RETURN p_employee;END IF;
 IF jsonb_array_length(sources->'contexts')<>1 OR jsonb_array_length(sources->'cumulative_balances'->'years')<>1
  OR sources->'calendar'->>'known' IS DISTINCT FROM 'true' THEN code:='statutory_composition_scope_required';
 ELSE
  context:=sources->'contexts'->0;data:=context->'source'->'version'->'data';
  balance:=sources->'cumulative_balances'->'years'->0;
  IF balance->>'known' IS DISTINCT FROM 'true' THEN code:='statutory_prior_balance_required';
  ELSIF NOT(data ?& ARRAY['calculation_from','calculation_until','tax_duration_days']) THEN code:='statutory_legal_duration_required';
  ELSIF data->>'calculation_from' IS DISTINCT FROM p_employee->>'starts_on'
   OR data->>'calculation_until' IS DISTINCT FROM p_employee->>'ends_on'
   OR context->>'from' IS DISTINCT FROM p_employee->>'starts_on'
   OR context->>'through' IS DISTINCT FROM p_employee->>'ends_on'
   OR balance->>'year' IS DISTINCT FROM left(p_employee->>'starts_on',4)
   OR balance->>'through' IS DISTINCT FROM ((p_employee->>'starts_on')::date-1)::text THEN code:='statutory_composition_context_mismatch';
  ELSIF data->>'insurance_status' IS DISTINCT FROM 'not_insured' THEN
   -- Insured month ownership needs its own reviewed binding. An insurance_from
   -- date or a calendar fragment cannot substitute for that financial decision.
   code:='insurance_obligation_attribution_required';
  ELSE
   duration:=(balance->>'prior_duration_days')::numeric+(data->>'tax_duration_days')::numeric;
   IF duration NOT BETWEEN 0.01 AND 360 THEN code:='statutory_duration_outside_adapter';
   ELSE
    SELECT count(*),min(pack.id::text)::uuid INTO matches,tax_pack
    FROM payroll.statutory_packs pack JOIN jsonb_array_elements(p_manifest->'packs') snapshot ON snapshot->>'id'=pack.id::text
    WHERE snapshot=to_jsonb(pack) AND pack.state='verified' AND pack.engine_adapter='eg-cumulative-tax-v1'
     AND pack.rules->>'tax_treatment_code'=data->>'tax_treatment_code'
     AND pack.effective_from<=(p_employee->>'starts_on')::date
     AND pack.effective_until IS NOT NULL AND pack.effective_until>(p_employee->>'ends_on')::date;
    IF matches<>1 THEN code:='statutory_composition_pack_missing_or_ambiguous';
    ELSE
     facts:=jsonb_build_object('prior_net_income',(balance->>'prior_net_income')::numeric,
      'prior_tax_due',(balance->>'prior_tax_due')::numeric,'cumulative_duration_days',duration,
      'earning_from',p_employee->'starts_on','earning_until',p_employee->'ends_on',
      'tax_treatment_code',data->'tax_treatment_code','source_reference',data->'reference',
      'insurance_status','not_insured','insurance_exclusion_reference',data->'reference');
     BEGIN
      calculated:=payroll.calculate_statutory_employee_with_earnings(p_employee,tax_pack,facts,NULL,NULL);
     EXCEPTION WHEN SQLSTATE '22023' THEN
      -- Known unsupported/unqualified source contracts are actionable blockers.
      -- Other engine/database failures must still abort the candidate command.
      GET STACKED DIAGNOSTICS code=MESSAGE_TEXT;
      RETURN p_employee||jsonb_build_object('issues',p_employee->'issues'||jsonb_build_array(payroll.issue(code,employment,'payroll_compliance')));
     END;
     RETURN calculated||jsonb_build_object('statutory_context',jsonb_build_object('calendar_year',balance->'year',
      'category','not_insured','insured_wage_source',data->'reference','insured_wage',0,'obligation_months','[]'::jsonb),
      'statutory_source_binding',jsonb_build_object('context_head_id',context->'head_id','context_version_id',context->'version_id',
       'earning_from',p_employee->'starts_on','earning_until',p_employee->'ends_on','current_duration_days',data->'tax_duration_days',
       'prior_balance',balance,'pack_id',tax_pack),'financially_qualified',false);
    END IF;
   END IF;
  END IF;
 END IF;
 RETURN p_employee||jsonb_build_object('issues',p_employee->'issues'||jsonb_build_array(payroll.issue(code,employment,'payroll_compliance')));
END $f$;
REVOKE ALL ON FUNCTION payroll.compose_statutory_review(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

-- Modify the existing integration boundary; do not add another wrapper layer.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.build_review(jsonb)'::regprocedure);
 anchor:=' FOR e IN SELECT value FROM jsonb_array_elements(result->''employees'') LOOP';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'unexpected_statutory_review_integration_loop';END IF;
 definition:=replace(definition,' IMMUTABLE',' STABLE');
 definition:=replace(definition,anchor,anchor||' e:=payroll.compose_statutory_review(p_manifest,e);');
 anchor:=' RETURN result||jsonb_build_object(''employees'',employees,''issues'',issues);';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_statutory_review_integration_result';END IF;
 EXECUTE replace(definition,anchor,$insert$
 SELECT coalesce(jsonb_agg(DISTINCT issue),'[]'::jsonb) INTO issues FROM (
  SELECT issue FROM jsonb_array_elements(issues) issue
  UNION ALL SELECT issue FROM jsonb_array_elements(employees) employee CROSS JOIN LATERAL jsonb_array_elements(employee->'issues') issue
 ) all_issues;
 RETURN result||jsonb_build_object('employees',employees,'issues',issues,'financially_qualified',false,
  'employer_cost',(SELECT sum((employee->>'employer_cost')::numeric)::text FROM jsonb_array_elements(employees) employee),
  'statutory_complete',jsonb_array_length(employees)>0 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee WHERE NOT(employee ? 'statutory_calculation')),
  'statutory_deductions',CASE WHEN NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee WHERE employee->>'statutory_deductions' IS NULL)
   THEN (SELECT sum((employee->>'statutory_deductions')::numeric)::text FROM jsonb_array_elements(employees) employee) END,
  'statutory_contributions',CASE WHEN NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee WHERE employee->>'statutory_contributions' IS NULL)
   THEN (SELECT sum((employee->>'statutory_contributions')::numeric)::text FROM jsonb_array_elements(employees) employee) END,
  'net',CASE WHEN jsonb_array_length(employees)>0 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee WHERE employee->>'net' IS NULL)
    THEN (SELECT sum((employee->>'net')::numeric)::text FROM jsonb_array_elements(employees) employee) END);$insert$);
END $patch$;

-- Operational calculations retain numeric scale. Accept trailing zero scale,
-- still rejecting any fraction beyond a cent, instead of rejecting valid money.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.calculate_statutory_employee(jsonb,uuid,jsonb,uuid,jsonb)'::regprocedure);
 anchor:='^[0-9]+(\.[0-9]{1,2})?$';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>2 THEN
  RAISE EXCEPTION 'unexpected_statutory_review_money_scale';END IF;
 EXECUTE replace(definition,anchor,'^[0-9]+(\.[0-9]{1,2}0*)?$');
END $patch$;
