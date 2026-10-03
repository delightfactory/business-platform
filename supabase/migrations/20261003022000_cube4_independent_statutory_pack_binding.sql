-- Stage 2 prerequisite: bind tax/earnings and insurance to independent packs.
-- The five-argument worker is private numeric composition; the four-argument
-- signatures remain compatibility wrappers for the historical same-pack API.
CREATE FUNCTION payroll.calculate_statutory_employee(
  p_employee jsonb,p_tax_pack uuid,p_facts jsonb,p_insurance_pack uuid,p_insurance_context jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE
 key text; amount numeric; gross numeric; deductions numeric; costs numeric;
 taxable numeric; prior_net numeric; insurance jsonb; tax_context jsonb; tax jsonb;
 employee_social numeric; employer_social numeric; deductible_social numeric;
 tax_delta numeric; statutory_deductions numeric; net numeric; lines jsonb; issues jsonb;
 branch jsonb; employment uuid;
BEGIN
 IF jsonb_typeof(p_employee) IS DISTINCT FROM 'object'
   OR p_employee->>'gross_complete' IS DISTINCT FROM 'true'
   OR jsonb_typeof(p_employee->'lines') IS DISTINCT FROM 'array'
   OR jsonb_typeof(p_employee->'issues') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
 END IF;
 BEGIN employment:=(p_employee->>'employment_id')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
   RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
 END;
 IF employment IS NULL THEN RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023'; END IF;
 FOREACH key IN ARRAY ARRAY['gross','deductions','employer_cost'] LOOP
   IF COALESCE(p_employee->>key,'') !~ '^[0-9]+(\.[0-9]{1,2})?$' THEN
     RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
   END IF;
   amount:=(p_employee->>key)::numeric;
   IF amount>1000000000000 THEN RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023'; END IF;
 END LOOP;
 -- Reject a second application instead of doubling insurance and tax lines.
 IF p_employee ? 'statutory_calculation' OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->'lines')l
     WHERE l->>'component' LIKE 'statutory:%') THEN
   RAISE EXCEPTION 'payroll_statutory_already_calculated' USING ERRCODE='22023';
 END IF;
 gross:=(p_employee->>'gross')::numeric;deductions:=(p_employee->>'deductions')::numeric;costs:=(p_employee->>'employer_cost')::numeric;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->'lines')l WHERE
   jsonb_typeof(l) IS DISTINCT FROM 'object' OR COALESCE(l->>'classification','') NOT IN ('earning','deduction','employer_cost')
   OR COALESCE(l->>'amount','') !~ '^[0-9]+(\.[0-9]{1,2})?$') THEN
   RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
 END IF;
 IF gross IS DISTINCT FROM (SELECT coalesce(sum((l->>'amount')::numeric),0) FROM jsonb_array_elements(p_employee->'lines')l WHERE l->>'classification'='earning')
   OR deductions IS DISTINCT FROM (SELECT coalesce(sum((l->>'amount')::numeric),0) FROM jsonb_array_elements(p_employee->'lines')l WHERE l->>'classification'='deduction')
   OR costs IS DISTINCT FROM (SELECT coalesce(sum((l->>'amount')::numeric),0) FROM jsonb_array_elements(p_employee->'lines')l WHERE l->>'classification'='employer_cost') THEN
   RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
 END IF;
 IF jsonb_typeof(p_facts) IS DISTINCT FROM 'object'
   OR NOT(p_facts ?& ARRAY['prior_net_income','current_taxable_earnings','cumulative_duration_days','prior_tax_due','earning_from','earning_until','tax_treatment_code','source_reference','insurance_status'])
   OR COALESCE(p_facts->>'insurance_status','') NOT IN ('insured','not_insured')
   OR (SELECT count(*) FROM jsonb_object_keys(p_facts))<>(CASE WHEN p_facts->>'insurance_status'='insured' THEN 9 ELSE 10 END) THEN
   RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
 END IF;
 FOREACH key IN ARRAY ARRAY['prior_net_income','current_taxable_earnings'] LOOP
   IF jsonb_typeof(p_facts->key) IS DISTINCT FROM 'number'
     OR (p_facts->>key)::numeric NOT BETWEEN 0 AND 1000000000000
     OR (p_facts->>key)::numeric<>round((p_facts->>key)::numeric,2) THEN
     RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
   END IF;
 END LOOP;
 taxable:=(p_facts->>'current_taxable_earnings')::numeric;prior_net:=(p_facts->>'prior_net_income')::numeric;
 IF taxable>gross THEN RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023'; END IF;
 IF p_facts->>'insurance_status'='insured' THEN
   insurance:=payroll.calculate_insurance(p_insurance_pack,p_insurance_context);
 ELSE
   -- Explicit reviewed exclusion, never inferred from absent insured wage.
   IF NOT(p_facts ? 'insurance_exclusion_reference')
     OR jsonb_typeof(p_facts->'insurance_exclusion_reference') IS DISTINCT FROM 'string'
     OR length(btrim(p_facts->>'insurance_exclusion_reference')) NOT BETWEEN 1 AND 160
     OR p_insurance_pack IS NOT NULL OR p_insurance_context IS NOT NULL THEN
     RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
   END IF;
   insurance:=jsonb_build_object('employee_total',0,'employer_total',0,'tax_deductible_employee_total',0,
     'lines','[]'::jsonb,'status','not_insured','source_reference',p_facts->>'insurance_exclusion_reference');
 END IF;
 employee_social:=(insurance->>'employee_total')::numeric;employer_social:=(insurance->>'employer_total')::numeric;
 deductible_social:=(insurance->>'tax_deductible_employee_total')::numeric;
 IF deductible_social>taxable THEN
   RAISE EXCEPTION 'payroll_statutory_tax_basis_review_required' USING ERRCODE='22023';
 END IF;
 tax_context:=(p_facts-'prior_net_income'-'current_taxable_earnings'-'insurance_status'-'insurance_exclusion_reference')
   ||jsonb_build_object('cumulative_net_before_personal_exemption',prior_net+taxable-deductible_social);
 tax:=payroll.calculate_cumulative_tax(p_tax_pack,tax_context);
 tax_delta:=(tax->>'current_tax_delta')::numeric;statutory_deductions:=employee_social+tax_delta;
 net:=gross-deductions-statutory_deductions;lines:=p_employee->'lines';issues:=p_employee->'issues';
 FOR branch IN SELECT value FROM jsonb_array_elements(insurance->'lines') LOOP
   lines:=lines||jsonb_build_array(jsonb_build_object('component','statutory:insurance:'||(branch->>'branch')||':'||(branch->>'month'),
     'name','اشتراك الموظف في التأمينات','classification','deduction','statutory',true,'amount',(branch->>'employee_amount'),'details',jsonb_build_array(branch)));
   lines:=lines||jsonb_build_array(jsonb_build_object('component','statutory:employer:'||(branch->>'branch')||':'||(branch->>'month'),
     'name','اشتراك جهة العمل في التأمينات','classification','employer_cost','statutory',true,'amount',(branch->>'employer_amount'),'details',jsonb_build_array(branch)));
 END LOOP;
 lines:=lines||jsonb_build_array(jsonb_build_object('component','statutory:tax','name',CASE WHEN tax_delta<0 THEN 'تسوية ضريبة مستحقة للموظف' ELSE 'ضريبة الأجور المستحقة' END,
   'classification','deduction','statutory',true,'amount',tax_delta::text,'details',jsonb_build_array(tax)));
 IF net<0 THEN issues:=issues||jsonb_build_array(payroll.issue('negative_statutory_balance',employment,'payroll_compliance')); END IF;
 RETURN p_employee||jsonb_build_object('lines',lines,'issues',issues,'statutory_deductions',statutory_deductions::text,
   'statutory_contributions',employer_social::text,'employer_cost',(costs+employer_social)::text,
   'total_employer_cost',(gross+costs+employer_social)::text,'net',CASE WHEN net>=0 THEN net::text END,
   'calculated_net',net::text,'financially_qualified',false,
   'statutory_calculation',jsonb_build_object('adapter','eg-employee-statutory-v1','pack_id',p_tax_pack,'facts',p_facts,'tax',tax,'insurance',insurance));
END $f$;

CREATE OR REPLACE FUNCTION payroll.calculate_statutory_employee(p_employee jsonb,p_pack uuid,p_facts jsonb,p_insurance jsonb)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT payroll.calculate_statutory_employee($1,$2,$3,
   CASE WHEN $3->>'insurance_status'='insured' THEN $2 ELSE NULL END,
   $4)
$f$;

CREATE FUNCTION payroll.calculate_statutory_employee_with_earnings(
 p_employee jsonb,p_tax_pack uuid,p_facts jsonb,p_insurance_pack uuid,p_insurance_context jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE earnings jsonb;result jsonb;
BEGIN
 IF jsonb_typeof(p_facts) IS DISTINCT FROM 'object' OR p_facts ? 'current_taxable_earnings' THEN
   RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';
 END IF;
 earnings:=payroll.resolve_taxable_earnings(p_employee,p_tax_pack);
 result:=payroll.calculate_statutory_employee(p_employee,p_tax_pack,
   p_facts||jsonb_build_object('current_taxable_earnings',earnings->'taxable_earnings'),
   p_insurance_pack,p_insurance_context);
 RETURN jsonb_set(result,'{statutory_calculation,earning_attribution}',earnings);
END $f$;

CREATE OR REPLACE FUNCTION payroll.calculate_statutory_employee_with_earnings(p_employee jsonb,p_pack uuid,p_facts jsonb,p_insurance jsonb)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT payroll.calculate_statutory_employee_with_earnings($1,$2,$3,
   CASE WHEN $3->>'insurance_status'='insured' THEN $2 ELSE NULL END,
   $4)
$f$;

REVOKE ALL ON FUNCTION payroll.calculate_statutory_employee(jsonb,uuid,jsonb,uuid,jsonb),
 payroll.calculate_statutory_employee_with_earnings(jsonb,uuid,jsonb,uuid,jsonb),
 payroll.calculate_statutory_employee(jsonb,uuid,jsonb,jsonb),
 payroll.calculate_statutory_employee_with_earnings(jsonb,uuid,jsonb,jsonb)
 FROM PUBLIC,anon,authenticated,service_role;
