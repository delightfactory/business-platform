BEGIN;
SELECT no_plan();
-- Dedicated rollback-only NONLEGAL mathematical fixtures.
DO $$ BEGIN IF current_database() <> 'business_platform_cube4_adam_closure_qa' THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required'; END IF; END $$;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('c4420000-0000-4000-8000-000000000001','cube4-independent-packs@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());

CREATE FUNCTION pg_temp.pack(p_version text,p_from date,p_until date,p_state text DEFAULT 'verified',p_earning boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE result uuid;
BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
 VALUES('EG','egypt_payroll',p_version,p_from,p_until,'["NONLEGAL source"]','{"numeric_comparisons":["NONLEGAL math only"]}',p_state,'c4420000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
 '{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}'::jsonb,
 jsonb_build_object('schema','eg-insurance-month-v1','category',p_version,'wage_minimum',1,'wage_maximum',200,'rounding','each_branch_month_half_up_cent','branches',jsonb_build_array(jsonb_build_object('branch','pension','employee_rate',CASE WHEN p_version='INS-2029' THEN 0.2 ELSE 0.01 END,'employer_rate',0.15,'tax_deductible',false))),
 CASE WHEN p_earning THEN '{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}'::jsonb ELSE '{}'::jsonb END) RETURNING id INTO result;
 RETURN result;
END $$;
CREATE FUNCTION pg_temp.employee() RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"employment_id":"c4423000-0000-4000-8000-000000000001","gross_complete":true,"starts_on":"2030-01-01","ends_on":"2030-01-30","gross":"100","deductions":"0","employer_cost":"0","issues":[],"lines":[{"component":"base","classification":"earning","amount":"100","details":[]}]}'::jsonb $$;
CREATE FUNCTION pg_temp.facts(p_status text DEFAULT 'insured') RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('prior_net_income',0,'current_taxable_earnings',100,'cumulative_duration_days',30,'prior_tax_due',0,'earning_from','2030-01-01','earning_until','2030-01-30','tax_treatment_code','01','source_reference','NONLEGAL facts','insurance_status',p_status) || CASE WHEN p_status='not_insured' THEN '{"insurance_exclusion_reference":"NONLEGAL exclusion"}'::jsonb ELSE '{}'::jsonb END $$;
CREATE FUNCTION pg_temp.insurance(p_category text DEFAULT 'INS-2029',p_month text DEFAULT '2029-12-01') RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('category',p_category,'source_reference','NONLEGAL insurance facts','obligation_months',jsonb_build_array(jsonb_build_object('month',p_month,'insured_wage',100,'insured_wage_source','NONLEGAL reviewed month'))) $$;

-- Actual private numeric adapter → immutable result → payslip projection.
-- Synthetic NONLEGAL schedules; this proves no official legal amounts.
CREATE FUNCTION pg_temp.present(employee jsonb, explanation jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
 SELECT payroll.report_payslip_lines('{}',jsonb_build_object('employees',jsonb_build_array(employee)),
  'c4423000-0000-4000-8000-000000000001',COALESCE(explanation,jsonb_build_object('lines',employee->'lines')))
$$;
CREATE TEMP TABLE calculated AS SELECT payroll.calculate_statutory_employee(pg_temp.employee(),
 pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),
 pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance()) employee;
SELECT is(pg_temp.present(employee)->>'complete','true','generated statutory lines have complete versioned presentation') FROM calculated;
SELECT is(jsonb_array_length(pg_temp.present(employee)->'lines'),3,'base plus employee insurance plus tax only') FROM calculated;
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.present(employee)->'lines') line WHERE line->>'classification'='employer_cost'),'employer contributions are excluded from employee deductions') FROM calculated;
SELECT is((employee->>'net')::numeric,70::numeric,'presentation contract leaves synthetic net unchanged') FROM calculated;
SELECT is((employee->>'statutory_contributions')::numeric,15::numeric,'positive employer contribution remains a distinct own cost') FROM calculated;
SELECT is((employee->>'total_employer_cost')::numeric,115::numeric,'gross and positive employer cost reconcile without reducing net') FROM calculated;
SELECT is((SELECT sum((line->>'amount')::numeric) FROM jsonb_array_elements(pg_temp.present(employee)->'lines') line WHERE line->>'classification'='deduction'),30::numeric,'employee deductions exclude positive employer contribution15') FROM calculated;
SELECT is(employee->>'financially_qualified','false','presentation does not qualify legal calculation') FROM calculated;
SELECT is(pg_temp.present(employee #- '{lines,1,presentation}')->>'complete','false','historical statutory output without metadata remains blocked') FROM calculated;
SELECT is(pg_temp.present(jsonb_set(employee,'{lines,3,presentation,schema}','"unknown"'))->>'complete','false','unknown presentation schema is blocked') FROM calculated;
SELECT is(pg_temp.present(jsonb_set(employee,'{lines,3,presentation,pack_id}','"00000000-0000-0000-0000-000000000000"'))->>'complete','false','wrong saved tax pack cannot supply metadata') FROM calculated;
SELECT is(pg_temp.present(employee,jsonb_build_object('lines',jsonb_set(employee->'lines','{3,amount}','"123.45"')))->>'complete','false','explanation cannot substitute a different amount') FROM calculated;
SELECT is(pg_temp.present(jsonb_set(employee,'{employment_id}','"c4423000-0000-4000-8000-000000000002"'))->>'complete','false','a different employee cannot supply statutory metadata') FROM calculated;
CREATE TEMP TABLE zero_tax AS SELECT payroll.calculate_statutory_employee(pg_temp.employee(),
 pg_temp.pack('TAX-ZERO','2030-01-01','2031-01-01'),pg_temp.facts()||'{"current_taxable_earnings":0}',
 pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance()) employee;
SELECT is(pg_temp.present(employee)->>'complete','true','zero tax has complete metadata') FROM zero_tax;
SELECT is((pg_temp.present(employee)->'lines'->2->>'amount')::numeric,0::numeric,'zero tax remains visible and explicit') FROM zero_tax;
SELECT * FROM finish();
ROLLBACK;
