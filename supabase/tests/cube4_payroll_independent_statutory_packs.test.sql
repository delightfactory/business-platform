BEGIN;
SELECT no_plan();
-- Dedicated rollback-only NONLEGAL mathematical fixtures.
DO $$ BEGIN IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required'; END IF; END $$;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('c4420000-0000-4000-8000-000000000001','cube4-independent-packs@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());

CREATE FUNCTION pg_temp.pack(p_version text,p_from date,p_until date,p_state text DEFAULT 'verified',p_earning boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE result uuid;
BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
 VALUES('EG','egypt_payroll',p_version,p_from,p_until,'["NONLEGAL source"]','{"numeric_comparisons":["NONLEGAL math only"]}',p_state,'c4420000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
 '{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}'::jsonb,
 jsonb_build_object('schema','eg-insurance-month-v1','category',p_version,'wage_minimum',1,'wage_maximum',200,'rounding','each_branch_month_half_up_cent','branches',jsonb_build_array(jsonb_build_object('branch','pension','employee_rate',CASE WHEN p_version='INS-2029' THEN 0.2 ELSE 0.01 END,'employer_rate',0,'tax_deductible',false))),
 CASE WHEN p_earning THEN '{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}'::jsonb ELSE '{}'::jsonb END) RETURNING id INTO result;
 RETURN result;
END $$;
CREATE FUNCTION pg_temp.employee() RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"employment_id":"c4423000-0000-4000-8000-000000000001","gross_complete":true,"starts_on":"2030-01-01","ends_on":"2030-01-30","gross":"100","deductions":"0","employer_cost":"0","issues":[],"lines":[{"component":"base","classification":"earning","amount":"100","details":[]}]}'::jsonb $$;
CREATE FUNCTION pg_temp.facts(p_status text DEFAULT 'insured') RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('prior_net_income',0,'current_taxable_earnings',100,'cumulative_duration_days',30,'prior_tax_due',0,'earning_from','2030-01-01','earning_until','2030-01-30','tax_treatment_code','01','source_reference','NONLEGAL facts','insurance_status',p_status) || CASE WHEN p_status='not_insured' THEN '{"insurance_exclusion_reference":"NONLEGAL exclusion"}'::jsonb ELSE '{}'::jsonb END $$;
CREATE FUNCTION pg_temp.insurance(p_category text DEFAULT 'INS-2029',p_month text DEFAULT '2029-12-01') RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('category',p_category,'source_reference','NONLEGAL insurance facts','obligation_months',jsonb_build_array(jsonb_build_object('month',p_month,'insured_wage',100,'insured_wage_source','NONLEGAL reviewed month'))) $$;
SELECT set_config('test.same_pack',pg_temp.pack('SAME','2030-01-01','2031-01-01')::text,true);

SELECT is((payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance())->'statutory_calculation'->'tax'->>'pack_version'),'TAX-2030','tax adapter uses explicit tax pack');
SELECT is((payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance())->'statutory_calculation'->'insurance'->>'pack_version'),'INS-2029','insurance adapter uses independent insurance pack');
SELECT is((payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance())->'statutory_calculation'->'insurance'->>'employee_total')::numeric,20::numeric,'insurance rate comes from dated insurance pack');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-BAD','2030-01-01','2031-01-01','unqualified'),pg_temp.facts(),pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance())$$,'22023','payroll_statutory_pack_unqualified','unqualified tax pack is rejected independently');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),pg_temp.pack('INS-BAD','2029-01-01','2030-01-01','unqualified'),pg_temp.insurance('INS-BAD'))$$,'22023','payroll_statutory_pack_unqualified','unqualified insurance pack is rejected independently');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),pg_temp.pack('INS-SHORT','2029-01-01','2029-12-15'),pg_temp.insurance('INS-SHORT'))$$,'22023','payroll_insurance_period_unsupported','insurance pack must cover the whole reviewed month');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),NULL,pg_temp.insurance())$$,'22023','payroll_statutory_pack_unqualified','insured employee cannot omit insurance pack');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts('not_insured'),pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),NULL)$$,'22023','payroll_statutory_employee_invalid','not insured rejects an extra insurance pack');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts('not_insured'),NULL,pg_temp.insurance())$$,'22023','payroll_statutory_employee_invalid','not insured rejects insurance context');
SELECT is(payroll.calculate_statutory_employee(pg_temp.employee(),current_setting('test.same_pack')::uuid,pg_temp.facts(),current_setting('test.same_pack')::uuid,pg_temp.insurance('SAME','2030-01-01')),payroll.calculate_statutory_employee(pg_temp.employee(),current_setting('test.same_pack')::uuid,pg_temp.facts(),pg_temp.insurance('SAME','2030-01-01')),'same-pack five-argument output equals legacy output');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee(payroll.calculate_statutory_employee(pg_temp.employee(),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance()),pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance())$$,'22023','payroll_statutory_already_calculated','duplicate application remains guarded');
SELECT is((payroll.calculate_statutory_employee_with_earnings(pg_temp.employee(),pg_temp.pack('TAX-EARN','2030-01-01','2031-01-01','verified',true),pg_temp.facts()-'current_taxable_earnings',pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance())->'statutory_calculation'->'earning_attribution'->>'pack_version'),'TAX-EARN','source-derived earnings use tax pack');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_statutory_employee(jsonb,uuid,jsonb,uuid,jsonb)','EXECUTE') AND NOT has_function_privilege('authenticated','payroll.calculate_statutory_employee_with_earnings(jsonb,uuid,jsonb,uuid,jsonb)','EXECUTE'),'both five-argument workers remain private');

WITH p AS MATERIALIZED(SELECT pg_temp.pack('TAX-2030','2030-01-01','2031-01-01') AS tax_id,pg_temp.pack('INS-2029','2029-01-01','2030-01-01') AS insurance_id),
 result AS MATERIALIZED(SELECT p.*,payroll.calculate_statutory_employee(pg_temp.employee(),tax_id,pg_temp.facts(),insurance_id,pg_temp.insurance()) AS value FROM p)
SELECT ok((value->>'net')::numeric=70 AND (value->>'financially_qualified')::boolean=false
 AND value->'statutory_calculation'->>'pack_id'=tax_id::text
 AND value->'statutory_calculation'->'insurance'->>'pack_id'=insurance_id::text,
 'different dated packs reconcile gross100 insurance20 tax10 net70 with exact provenance and no legal qualification') FROM result;
SELECT ok(NOT EXISTS(SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) role_name
 CROSS JOIN unnest(ARRAY['payroll.calculate_statutory_employee(jsonb,uuid,jsonb,uuid,jsonb)','payroll.calculate_statutory_employee_with_earnings(jsonb,uuid,jsonb,uuid,jsonb)']) signature
 WHERE has_function_privilege(role_name,signature,'EXECUTE')),'all API roles denied both independent composition workers');
SELECT * FROM finish();
ROLLBACK;
