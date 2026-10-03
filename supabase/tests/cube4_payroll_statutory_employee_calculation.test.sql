-- Isolated NONLEGAL mathematical schedules; not current official model comparisons.
SELECT set_config('test.tax.rules','{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":20,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":1000,"bands":[{"upper":100,"rate":0},{"upper":200,"rate":0.1},{"upper":null,"rate":0.2}]},{"through":null,"bands":[{"upper":null,"rate":0.3}]}]}',true);
-- NONLEGAL insurance schedules. No official2026 rate or category qualification.
SELECT set_config('test.insurance.rules','{"schema":"eg-insurance-month-v1","category":"NONLEGAL-test-category","wage_minimum":1,"wage_maximum":200,"rounding":"each_branch_month_half_up_cent","branches":[{"branch":"pension","employee_rate":0.1,"employer_rate":0.2,"tax_deductible":true},{"branch":"reward","employee_rate":0.025,"employer_rate":0.05,"tax_deductible":false}]}',true);
CREATE FUNCTION pg_temp.pack(state_value text DEFAULT 'verified') RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE result uuid;BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules)
 VALUES('EG','egypt_payroll','NONLEGAL-composed','2030-01-01','2031-01-01','["NONLEGAL source"]','{"numeric_comparisons":["NONLEGAL math only"]}',state_value,'c4420000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',current_setting('test.tax.rules')::jsonb,current_setting('test.insurance.rules')::jsonb) RETURNING id INTO result;RETURN result;END $$;
CREATE FUNCTION pg_temp.employee(d numeric DEFAULT 5) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('employment_id','c4423000-0000-4000-8000-000000000001','gross_complete',true,'gross','100','deductions',d::text,'employer_cost','2','issues','[]'::jsonb,'lines',jsonb_build_array(jsonb_build_object('component','base','classification','earning','amount','100'),jsonb_build_object('component','manual','classification','deduction','amount',d::text),jsonb_build_object('component','benefit','classification','employer_cost','amount','2'))) $$;
CREATE FUNCTION pg_temp.facts() RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"prior_net_income":0,"current_taxable_earnings":100,"cumulative_duration_days":30,"prior_tax_due":0,"earning_from":"2030-01-01","earning_until":"2030-01-30","tax_treatment_code":"01","source_reference":"Reviewed tax facts","insurance_status":"insured"}'::jsonb $$;
CREATE FUNCTION pg_temp.insurance() RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"category":"NONLEGAL-test-category","source_reference":"Reviewed current obligations","obligation_months":[{"month":"2030-01-01","insured_wage":100,"insured_wage_source":"v1"}]}'::jsonb $$;
CREATE FUNCTION pg_temp.calc(f jsonb DEFAULT '{}', e jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $$ SELECT payroll.calculate_statutory_employee(pg_temp.employee()||e,pg_temp.pack(),pg_temp.facts()||f,pg_temp.insurance()) $$;
SELECT is((pg_temp.calc()->>'net')::numeric,56::numeric,'actual net composes operational deductions plus insurance and tax');
SELECT is((pg_temp.calc()->>'statutory_deductions')::numeric,39::numeric,'statutory deductions separate from operational5');
SELECT is((pg_temp.calc()->>'deductions')::numeric,5::numeric,'operational deductions not counted twice');
SELECT is((pg_temp.calc()->>'statutory_contributions')::numeric,25::numeric,'employer contributions separate');
SELECT is((pg_temp.calc()->>'employer_cost')::numeric,27::numeric,'employer extra costs plus contributions');
SELECT is((pg_temp.calc()->>'total_employer_cost')::numeric,127::numeric,'total employer expense reconciles gross and own costs');
SELECT is((pg_temp.calc()->'statutory_calculation'->'tax'->>'annual_base')::numeric,1060::numeric,'only deductible pension10 reduces taxable100, not reward2.5 or manual5');
SELECT is((pg_temp.calc('{"prior_net_income":100}')->'statutory_calculation'->'tax'->>'annual_base')::numeric,2260::numeric,'prior net retained without subtracting old contributions again');
SELECT is((pg_temp.calc('{"prior_tax_due":100}')->>'net')::numeric,156::numeric,'prior assessed overpayment preserves employee refund');
SELECT is((pg_temp.calc('{"current_taxable_earnings":50}')->>'net')::numeric,77.33::numeric,'nontaxable earnings remain in gross but outside tax base');
SELECT is((pg_temp.calc()->>'financially_qualified')::boolean,false,'numerical result does not claim official readiness');
SELECT is(jsonb_array_length(pg_temp.calc()->'lines'),8,'original3 plus separate insurance4 plus tax1');
SELECT is(pg_temp.calc()->'statutory_calculation'->'tax'->>'pack_version','NONLEGAL-composed','tax uses exact pack version');
SELECT is(pg_temp.calc()->'statutory_calculation'->'insurance'->>'pack_version','NONLEGAL-composed','insurance uses same exact pack version');
SELECT is(pg_temp.calc('{}','{"issues":[{"code":"existing_blocker","blocking":true}]}')->'issues'->0->>'code','existing_blocker','existing blocker never cleared');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_statutory_employee(jsonb,uuid,jsonb,jsonb)','EXECUTE'),'composition is private');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('unqualified'),pg_temp.facts(),pg_temp.insurance())$$,'22023','payroll_statutory_pack_unqualified','unqualified pack blocked in composition');
SELECT is((payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack(),pg_temp.facts()||'{"insurance_status":"not_insured","insurance_exclusion_reference":"Reviewed exemption evidence"}',NULL)->>'net')::numeric,65.5::numeric,'explicit reviewed exclusion calculates tax without invented insured wage');
SELECT is((payroll.calculate_statutory_employee(pg_temp.employee(90),pg_temp.pack(),pg_temp.facts(),pg_temp.insurance())->>'net'),NULL::text,'negative result not exposed as payable');
SELECT is((payroll.calculate_statutory_employee(pg_temp.employee(90),pg_temp.pack(),pg_temp.facts(),pg_temp.insurance())->>'calculated_net')::numeric,-29::numeric,'negative result explained precisely');
SELECT is(payroll.calculate_statutory_employee(pg_temp.employee(90),pg_temp.pack(),pg_temp.facts(),pg_temp.insurance())->'issues'->0->>'code','negative_statutory_balance','negative balance owns blocker');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.calc(),pg_temp.pack(),pg_temp.facts(),pg_temp.insurance())$$,'22023','payroll_statutory_already_calculated','reapplication cannot double tax or insurance');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"gross_complete":false}')$$,'22023','payroll_statutory_employee_invalid','partial earnings rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"gross":"99"}')$$,'22023','payroll_statutory_employee_invalid','gross does not match lines rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"deductions":"6"}')$$,'22023','payroll_statutory_employee_invalid','deductions do not match lines rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"employer_cost":"3"}')$$,'22023','payroll_statutory_employee_invalid','employer costs do not match lines rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"issues":null}')$$,'22023','payroll_statutory_employee_invalid','unknown blocker status rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"employment_id":"bad"}')$$,'22023','payroll_statutory_employee_invalid','invalid employee identity rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"gross":"NaN"}')$$,'22023','payroll_statutory_employee_invalid','nonfinite gross rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{}','{"lines":[{"component":"base","classification":"earning","amount":"unknown"}]}')$$,'22023','payroll_statutory_employee_invalid','unknown line amount rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{"current_taxable_earnings":101}')$$,'22023','payroll_statutory_employee_invalid','taxable exceeds gross rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{"prior_net_income":null}')$$,'22023','payroll_statutory_employee_invalid','unknown cumulative income rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{"current_taxable_earnings":1.001}')$$,'22023','payroll_statutory_employee_invalid','excess money precision rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{"insurance_status":"unknown"}')$$,'22023','payroll_statutory_employee_invalid','unknown insurance status rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{"insurance_status":"not_insured"}')$$,'22023','payroll_statutory_employee_invalid','exclusion without reviewed reference rejected');
SELECT throws_ok($$SELECT pg_temp.calc('{"current_taxable_earnings":5}')$$,'22023','payroll_statutory_tax_basis_review_required','deductible insurance exceeds current taxable base needs explicit review');
SELECT * FROM finish();
