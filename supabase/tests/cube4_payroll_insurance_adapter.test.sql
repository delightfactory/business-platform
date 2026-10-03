-- NONLEGAL insurance schedules. No official2026 rate or category qualification.
SELECT set_config('test.insurance.rules','{"schema":"eg-insurance-month-v1","category":"NONLEGAL-test-category","wage_minimum":1,"wage_maximum":200,"rounding":"each_branch_month_half_up_cent","branches":[{"branch":"pension","employee_rate":0.1,"employer_rate":0.2,"tax_deductible":true},{"branch":"reward","employee_rate":0.025,"employer_rate":0.05,"tax_deductible":false}]}',true);
CREATE FUNCTION pg_temp.pack(extra jsonb DEFAULT '{}',state_value text DEFAULT 'verified') RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE result uuid;BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,insurance_rules)
 VALUES('EG','egypt_payroll','NONLEGAL-insurance','2030-01-01','2031-01-01','["NONLEGAL arithmetic source"]','{"numeric_comparisons":["NONLEGAL derived fixture"]}',state_value,'c4420000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',current_setting('test.insurance.rules')::jsonb||extra) RETURNING id INTO result;RETURN result;END $$;
CREATE FUNCTION pg_temp.context(w numeric DEFAULT 100) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('category','NONLEGAL-test-category','source_reference','Reviewed monthly obligations','obligation_months',jsonb_build_array(jsonb_build_object('month','2030-01-01','insured_wage',w,'insured_wage_source','Immutable insured wage version1'))) $$;
CREATE FUNCTION pg_temp.calc(w numeric DEFAULT 100,extra jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $$
 SELECT payroll.calculate_insurance(pg_temp.pack(),pg_temp.context(w)||extra) $$;
SELECT is((pg_temp.calc()->>'employee_total')::numeric,12.50::numeric,'employee contributions');
SELECT is((pg_temp.calc()->>'employer_total')::numeric,25::numeric,'employer contributions separate');
SELECT is((pg_temp.calc()->>'tax_deductible_employee_total')::numeric,10::numeric,'only designated employee branch deductible');
SELECT is(jsonb_array_length(pg_temp.calc()->'lines'),2,'separate branch traces retained');
SELECT is((pg_temp.calc(1)->>'employee_total')::numeric,0.13::numeric,'minimum insured wage accepted; branch rounding');
SELECT is((pg_temp.calc(200)->>'employee_total')::numeric,25::numeric,'maximum insured wage accepted');
SELECT is((pg_temp.calc(1.04)->>'employee_total')::numeric,0.13::numeric,'round each branch before total');
SELECT is((pg_temp.calc(100,'{"obligation_months":[{"month":"2030-01-01","insured_wage":100,"insured_wage_source":"v1"},{"month":"2030-02-01","insured_wage":200,"insured_wage_source":"v2"}]}')->>'employee_total')::numeric,37.5::numeric,'two-month employee_total follows dated wage sources');
SELECT is((pg_temp.calc(100,'{"obligation_months":[{"month":"2030-01-01","insured_wage":100,"insured_wage_source":"v1"},{"month":"2030-02-01","insured_wage":200,"insured_wage_source":"v2"}]}')->>'employer_total')::numeric,75::numeric,'two-month employer_total follows dated wage sources');
SELECT is((pg_temp.calc(100,'{"obligation_months":[{"month":"2030-01-01","insured_wage":100,"insured_wage_source":"v1"},{"month":"2030-02-01","insured_wage":200,"insured_wage_source":"v2"}]}')->>'tax_deductible_employee_total')::numeric,30::numeric,'two-month tax_deductible_employee_total follows dated wage sources');
SELECT is((pg_temp.calc(100,'{"obligation_months":[]}')->>'employee_total')::numeric,0::numeric,'explicit reviewed empty obligations differs from unknown');
SELECT is(pg_temp.calc()->>'pack_version','NONLEGAL-insurance','pack version retained');
SELECT is(pg_temp.calc()->'lines'->0->>'insured_wage_source','Immutable insured wage version1','insured wage provenance retained');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_insurance(uuid,jsonb)','EXECUTE'),'ordinary actor cannot invoke insurance adapter');
SELECT ok(NOT has_function_privilege('service_role','payroll.calculate_insurance(uuid,jsonb)','EXECUTE'),'service API cannot invoke insurance adapter');
SELECT throws_ok($$SELECT payroll.calculate_insurance(pg_temp.pack('{}','unqualified'),pg_temp.context())$$,'22023','payroll_statutory_pack_unqualified','unqualified insurance pack blocked');
SELECT throws_ok($$SELECT pg_temp.calc(0)$$,'22023','payroll_insurance_wage_outside_rules','zero insured wage rejected without automatic clamp');
SELECT throws_ok($$SELECT pg_temp.calc(0.99)$$,'22023','payroll_insurance_wage_outside_rules','below minimum insured wage rejected without automatic clamp');
SELECT throws_ok($$SELECT pg_temp.calc(200.01)$$,'22023','payroll_insurance_wage_outside_rules','above maximum insured wage rejected without automatic clamp');
SELECT throws_ok($$SELECT pg_temp.calc(-1)$$,'22023','payroll_insurance_wage_outside_rules','negative insured wage rejected without automatic clamp');
SELECT throws_ok($$SELECT pg_temp.calc(1.001)$$,'22023','payroll_insurance_wage_outside_rules','excess cents insured wage rejected without automatic clamp');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"category":"other"}')$$,'22023','payroll_insurance_context_invalid','unsupported category rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"source_reference":""}')$$,'22023','payroll_insurance_context_invalid','missing source rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months":null}')$$,'22023','payroll_insurance_context_invalid','unknown obligations rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months":[{"month":"2030-01-15","insured_wage":100,"insured_wage_source":"v1"}]}')$$,'22023','payroll_insurance_context_invalid','salary cycle date used as month rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months":[{"month":"2030-13-01","insured_wage":100,"insured_wage_source":"v1"}]}')$$,'22023','payroll_insurance_context_invalid','invalid month rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months":[{"month":"2030-01-01","insured_wage":"100","insured_wage_source":"v1"}]}')$$,'22023','payroll_insurance_context_invalid','string wage rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months":[{"month":"2030-01-01","insured_wage":100,"insured_wage_source":""}]}')$$,'22023','payroll_insurance_context_invalid','missing wage source rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months": [{"month": "2030-01-01", "insured_wage": 100, "insured_wage_source": "v1"}, {"month": "2030-01-01", "insured_wage": 100, "insured_wage_source": "v1"}]}')$$,'22023','payroll_insurance_period_unsupported','duplicate month rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months": [{"month": "2030-02-01", "insured_wage": 100, "insured_wage_source": "v1"}, {"month": "2030-01-01", "insured_wage": 100, "insured_wage_source": "v1"}]}')$$,'22023','payroll_insurance_period_unsupported','unordered months rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months": [{"month": "2030-12-01", "insured_wage": 100, "insured_wage_source": "v1"}, {"month": "2031-01-01", "insured_wage": 100, "insured_wage_source": "v1"}]}')$$,'22023','payroll_insurance_period_unsupported','cross year or pack rejected');
SELECT throws_ok($$SELECT pg_temp.calc(100,'{"obligation_months": [{"month": "2029-12-01", "insured_wage": 100, "insured_wage_source": "v1"}]}')$$,'22023','payroll_insurance_period_unsupported','before pack rejected');
SELECT throws_ok($$SELECT payroll.calculate_insurance(pg_temp.pack('{"wage_minimum":201}'),pg_temp.context())$$,'22023','payroll_insurance_rules_invalid','reversed bounds rejected');
SELECT throws_ok($$SELECT payroll.calculate_insurance(pg_temp.pack('{"rounding":null}'),pg_temp.context())$$,'22023','payroll_insurance_rules_invalid','unknown rounding rejected');
SELECT throws_ok($$SELECT payroll.calculate_insurance(pg_temp.pack('{"branches":[]}'),pg_temp.context())$$,'22023','payroll_insurance_rules_invalid','empty branches rejected');
SELECT throws_ok($$SELECT payroll.calculate_insurance(pg_temp.pack('{"branches":[{"branch":"pension","employee_rate":-0.1,"employer_rate":0.2,"tax_deductible":true}]}'),pg_temp.context())$$,'22023','payroll_insurance_rules_invalid','negative rate rejected');
SELECT throws_ok($$SELECT payroll.calculate_insurance(pg_temp.pack('{"branches":[{"branch":"pension","employee_rate":0.1,"employer_rate":0.2,"tax_deductible":null}]}'),pg_temp.context())$$,'22023','payroll_insurance_rules_invalid','unknown deductible applicability rejected');
SELECT throws_ok($$SELECT payroll.calculate_insurance(pg_temp.pack('{"branches":[{"branch":"pension","employee_rate":0.1,"employer_rate":0.2,"tax_deductible":true},{"branch":"pension","employee_rate":0.1,"employer_rate":0.2,"tax_deductible":true}]}'),pg_temp.context())$$,'22023','payroll_insurance_rules_invalid','duplicate branch rejected');
SELECT * FROM finish();
