-- Insurance computation from reviewed calendar obligations, not salary proration.
-- No statutory rates, categories or legally qualified packs are seeded here.
ALTER TABLE payroll.statutory_packs ADD COLUMN insurance_rules jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE FUNCTION payroll.calculate_insurance(p_pack uuid,p_context jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE
 pack payroll.statutory_packs; rules jsonb; branch jsonb; obligation jsonb;
 key text; rate numeric; wage numeric; minimum numeric; maximum numeric;
 month date; prior_month date; year integer; seen text[] := ARRAY[]::text[];
 employee_rate numeric:=0; employer_rate numeric:=0;
 employee_amount numeric; employer_amount numeric;
 employee_total numeric:=0; employer_total numeric:=0; deductible_total numeric:=0;
 lines jsonb:='[]';
BEGIN
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 IF NOT FOUND OR pack.state<>'verified' OR pack.engine_adapter IS DISTINCT FROM 'eg-cumulative-tax-v1'
   OR jsonb_typeof(pack.review_evidence->'numeric_comparisons') IS DISTINCT FROM 'array'
   OR jsonb_array_length(pack.review_evidence->'numeric_comparisons')=0 THEN
   RAISE EXCEPTION 'payroll_statutory_pack_unqualified' USING ERRCODE='22023';
 END IF;
 rules:=pack.insurance_rules;
 IF jsonb_typeof(rules) IS DISTINCT FROM 'object'
   OR NOT(rules ?& ARRAY['schema','category','wage_minimum','wage_maximum','rounding','branches'])
   OR (SELECT count(*) FROM jsonb_object_keys(rules))<>6
   OR rules->>'schema' IS DISTINCT FROM 'eg-insurance-month-v1'
   OR jsonb_typeof(rules->'category') IS DISTINCT FROM 'string'
   OR length(btrim(rules->>'category')) NOT BETWEEN 1 AND 160
   OR rules->>'rounding' IS DISTINCT FROM 'each_branch_month_half_up_cent'
   OR jsonb_typeof(rules->'wage_minimum') IS DISTINCT FROM 'number'
   OR jsonb_typeof(rules->'wage_maximum') IS DISTINCT FROM 'number'
   OR jsonb_typeof(rules->'branches') IS DISTINCT FROM 'array'
   OR jsonb_array_length(rules->'branches') NOT BETWEEN 1 AND 6 THEN
   RAISE EXCEPTION 'payroll_insurance_rules_invalid' USING ERRCODE='22023';
 END IF;
 minimum:=(rules->>'wage_minimum')::numeric;maximum:=(rules->>'wage_maximum')::numeric;
 IF minimum<0 OR maximum<=minimum OR maximum>1000000000000
   OR minimum<>round(minimum,2) OR maximum<>round(maximum,2) THEN
   RAISE EXCEPTION 'payroll_insurance_rules_invalid' USING ERRCODE='22023';
 END IF;
 FOR branch IN SELECT value FROM jsonb_array_elements(rules->'branches') LOOP
   IF jsonb_typeof(branch) IS DISTINCT FROM 'object'
     OR NOT(branch ?& ARRAY['branch','employee_rate','employer_rate','tax_deductible'])
     OR (SELECT count(*) FROM jsonb_object_keys(branch))<>4
     OR COALESCE(branch->>'branch','') NOT IN ('pension','reward','injury','sickness','unemployment','universal_health')
     OR branch->>'branch'=ANY(seen)
     OR jsonb_typeof(branch->'tax_deductible') IS DISTINCT FROM 'boolean' THEN
     RAISE EXCEPTION 'payroll_insurance_rules_invalid' USING ERRCODE='22023';
   END IF;
   FOREACH key IN ARRAY ARRAY['employee_rate','employer_rate'] LOOP
     IF jsonb_typeof(branch->key) IS DISTINCT FROM 'number' THEN
       RAISE EXCEPTION 'payroll_insurance_rules_invalid' USING ERRCODE='22023';
     END IF;
     rate:=(branch->>key)::numeric;
     IF rate<0 OR rate>1 THEN RAISE EXCEPTION 'payroll_insurance_rules_invalid' USING ERRCODE='22023'; END IF;
   END LOOP;
   employee_rate:=employee_rate+(branch->>'employee_rate')::numeric;
   employer_rate:=employer_rate+(branch->>'employer_rate')::numeric;
   seen:=array_append(seen,branch->>'branch');
 END LOOP;
 IF employee_rate>1 OR employer_rate>1 THEN
   RAISE EXCEPTION 'payroll_insurance_rules_invalid' USING ERRCODE='22023';
 END IF;
 IF jsonb_typeof(p_context) IS DISTINCT FROM 'object'
   OR NOT(p_context ?& ARRAY['category','obligation_months','source_reference'])
   OR (SELECT count(*) FROM jsonb_object_keys(p_context))<>3
   OR p_context->>'category' IS DISTINCT FROM rules->>'category'
   OR jsonb_typeof(p_context->'source_reference') IS DISTINCT FROM 'string'
   OR length(btrim(p_context->>'source_reference')) NOT BETWEEN 1 AND 160
   OR jsonb_typeof(p_context->'obligation_months') IS DISTINCT FROM 'array'
   OR jsonb_array_length(p_context->'obligation_months')>12 THEN
   RAISE EXCEPTION 'payroll_insurance_context_invalid' USING ERRCODE='22023';
 END IF;
 FOR obligation IN SELECT value FROM jsonb_array_elements(p_context->'obligation_months') LOOP
   IF jsonb_typeof(obligation) IS DISTINCT FROM 'object'
     OR NOT(obligation ?& ARRAY['month','insured_wage','insured_wage_source'])
     OR (SELECT count(*) FROM jsonb_object_keys(obligation))<>3
     OR jsonb_typeof(obligation->'month') IS DISTINCT FROM 'string'
     OR obligation->>'month' !~ '^[0-9]{4}-[0-9]{2}-01$'
     OR jsonb_typeof(obligation->'insured_wage') IS DISTINCT FROM 'number'
     OR jsonb_typeof(obligation->'insured_wage_source') IS DISTINCT FROM 'string'
     OR length(btrim(obligation->>'insured_wage_source')) NOT BETWEEN 1 AND 160 THEN
     RAISE EXCEPTION 'payroll_insurance_context_invalid' USING ERRCODE='22023';
   END IF;
   BEGIN month:=(obligation->>'month')::date;
   EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN
     RAISE EXCEPTION 'payroll_insurance_context_invalid' USING ERRCODE='22023';
   END;
   wage:=(obligation->>'insured_wage')::numeric;
   IF wage<=0 OR wage<minimum OR wage>maximum OR wage<>round(wage,2) THEN
     RAISE EXCEPTION 'payroll_insurance_wage_outside_rules' USING ERRCODE='22023';
   END IF;
   -- Obligation intervals must be ordered, unique and wholly within one pack/year.
   IF NOT isfinite(pack.effective_from) OR (pack.effective_until IS NOT NULL AND NOT isfinite(pack.effective_until))
     OR (prior_month IS NOT NULL AND month<=prior_month)
     OR (year IS NOT NULL AND extract(year FROM month)<>year)
     OR month<pack.effective_from
     OR (pack.effective_until IS NOT NULL AND (month+interval '1 month')::date>pack.effective_until) THEN
     RAISE EXCEPTION 'payroll_insurance_period_unsupported' USING ERRCODE='22023';
   END IF;
   prior_month:=month;year:=extract(year FROM month);
   FOR branch IN SELECT value FROM jsonb_array_elements(rules->'branches') LOOP
     employee_amount:=round(wage*(branch->>'employee_rate')::numeric,2);
     employer_amount:=round(wage*(branch->>'employer_rate')::numeric,2);
     employee_total:=employee_total+employee_amount;employer_total:=employer_total+employer_amount;
     IF (branch->>'tax_deductible')::boolean THEN deductible_total:=deductible_total+employee_amount; END IF;
     lines:=lines||jsonb_build_array(jsonb_build_object('month',month,'branch',branch->>'branch',
       'insured_wage',wage,'insured_wage_source',obligation->>'insured_wage_source',
       'employee_rate',branch->'employee_rate','employer_rate',branch->'employer_rate',
       'employee_amount',employee_amount,'employer_amount',employer_amount,'tax_deductible',branch->'tax_deductible'));
   END LOOP;
 END LOOP;
 RETURN jsonb_build_object('adapter','eg-insurance-month-v1','pack_id',pack.id,'pack_version',pack.version,
   'category',rules->>'category','calendar_year',year,'source_reference',p_context->>'source_reference',
   'obligation_months',p_context->'obligation_months','employee_total',employee_total,
   'employer_total',employer_total,'tax_deductible_employee_total',deductible_total,'lines',lines);
END $f$;
REVOKE ALL ON FUNCTION payroll.calculate_insurance(uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
