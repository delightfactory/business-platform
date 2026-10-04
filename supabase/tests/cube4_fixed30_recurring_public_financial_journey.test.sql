BEGIN;
DO $$ BEGIN
  IF current_database() <> 'business_platform_cube4_adam_positive_qa' THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- Isolated NONLEGAL complete-month insurance source/ownership acceptance.
-- The actual public producer and immutable consumption remain in use.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d6420000-0000-4000-8000-000000000001','d642-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d6420000-0000-4000-8000-000000000002','d642-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d6421000-0000-4000-8000-000000000001','NONLEGAL D642 Leave binding QA','d6420000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d6421000-0000-4000-8000-000000000001','d6422000-0000-4000-8000-000000000001','d642.payroll.leave',1,
 ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','payroll.review','payroll.export','payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','leave.manage','leave.view','leave.approve']),
       ('d6421000-0000-4000-8000-000000000001','d6422000-0000-4000-8000-000000000002','d642.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d6421000-0000-4000-8000-000000000001','d6420000-0000-4000-8000-000000000001','d6420000-0000-4000-8000-000000000001'),
       ('d6421000-0000-4000-8000-000000000001','d6420000-0000-4000-8000-000000000002','d6420000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d6421000-0000-4000-8000-000000000001','d6420000-0000-4000-8000-000000000001','d6422000-0000-4000-8000-000000000001'),
       ('d6421000-0000-4000-8000-000000000001','d6420000-0000-4000-8000-000000000002','d6422000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','NONLEGAL D642 NONLEGAL Employer','NONLEGAL D642 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd6421000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d6420000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d6421000-0000-4000-8000-000000000001','d6424000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','NONLEGAL D642 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d6421000-0000-4000-8000-000000000001','d6425000-0000-4000-8000-000000000001','NONLEGAL D642','NONLEGAL D642 Leave Employee','d6420000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d6421000-0000-4000-8000-000000000001','d6426000-0000-4000-8000-000000000001','d6425000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','2025-12-25','active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d6421000-0000-4000-8000-000000000001','d6425000-0000-4000-8000-000000000001','d6420000-0000-4000-8000-000000000002','d6420000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d6421000-0000-4000-8000-000000000001','d6427000-0000-4000-8000-000000000001','d6426000-0000-4000-8000-000000000001',30000,'2025-12-25');
UPDATE people.compensation_versions SET valid_until='2026-01-01' WHERE id='d6427000-0000-4000-8000-000000000001';
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d6421000-0000-4000-8000-000000000001','d6427000-0000-4000-8000-000000000002','d6426000-0000-4000-8000-000000000001',30000,'2026-01-01');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d6421000-0000-4000-8000-000000000001','d6428000-0000-4000-8000-000000000001','D240-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d6421000-0000-4000-8000-000000000001','d6428000-0000-4000-8000-000000000001',1,'D240 policy','fixed','UTC',ARRAY[1,2,3,4,5,6,7]::smallint[],'08:00','16:00','d6420000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d6421000-0000-4000-8000-000000000001','d6429000-0000-4000-8000-000000000001','d6426000-0000-4000-8000-000000000001','d6424000-0000-4000-8000-000000000001','d6428000-0000-4000-8000-000000000001',1,'2025-12-25');

INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by)
SELECT 'd6421000-0000-4000-8000-000000000001',gen_random_uuid(),'d6429000-0000-4000-8000-000000000001','d6426000-0000-4000-8000-000000000001','d6425000-0000-4000-8000-000000000001','d6424000-0000-4000-8000-000000000001',day::date,'d6428000-0000-4000-8000-000000000001',1,'UTC',day+interval '8 hour',day+interval '16 hour',day+interval '6 hour',day+interval '22 hour','approved','d6420000-0000-4000-8000-000000000001'
FROM generate_series('2025-12-25'::timestamptz,'2026-01-24'::timestamptz,interval '1 day')day;
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by)
SELECT tenant_id,gen_random_uuid(),id,1,'ready',time.work_instance_interpretation_fingerprint(tenant_id,id),'d6420000-0000-4000-8000-000000000001' FROM time.work_instances WHERE tenant_id='d6421000-0000-4000-8000-000000000001';
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
SELECT tenant_id,gen_random_uuid(),work_instance_id,1,id,CASE WHEN work_instance_id=(SELECT id FROM time.work_instances WHERE tenant_id='d6421000-0000-4000-8000-000000000001' AND operational_date='2026-01-02') THEN '{"outcome":"absence","worked_minutes":0,"absence_units":1,"leave_units":0,"leave_sources":[],"late_minutes":0,"early_leave_minutes":0}'::jsonb ELSE '{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[],"late_minutes":0,"early_leave_minutes":0}'::jsonb END, 'd6420000-0000-4000-8000-000000000001' FROM time.interpretations WHERE tenant_id='d6421000-0000-4000-8000-000000000001';
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642d000-0000-4000-8000-000000000001',1,'2025-12-25',NULL,31,'ending','UTC','d6420000-0000-4000-8000-000000000001','NONLEGAL D642 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001','d642d000-0000-4000-8000-000000000001','2025-12-25','2026-01-24','2026-01-24','UTC','NONLEGAL D642 one-day NONLEGAL Leave QA',false,'d6420000-0000-4000-8000-000000000001');


INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
VALUES('d642f000-0000-4000-8000-000000000001','EG','egypt_payroll','NONLEGAL single-band arithmetic fixture','2025-01-01','2026-01-01','["NONLEGAL synthetic arithmetic"]','{"numeric_comparisons":["NONLEGAL isolated math only"]}','verified','d6420000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
'{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}','{}',
'{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable","date_partition_rounding":"chronological_prefix_half_up_cent"}');
INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
SELECT 'd642f000-0000-4000-8000-000000000002',jurisdiction,family,'NONLEGAL independent insurance arithmetic','2025-01-01','2026-01-01',source_references,review_evidence,state,verified_by,engine_adapter,jsonb_set(rules,'{tax_treatment_code}','"02"'),
'{"schema":"eg-insurance-month-v1","category":"NONLEGAL pension fixture","wage_minimum":100,"wage_maximum":20000,"rounding":"each_branch_month_half_up_cent","branches":[{"branch":"pension","employee_rate":0.01,"employer_rate":0.02,"tax_deductible":true}]}',earning_rules
FROM payroll.statutory_packs WHERE id='d642f000-0000-4000-8000-000000000001';
INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
SELECT CASE WHEN id='d642f000-0000-4000-8000-000000000001' THEN 'd642f000-0000-4000-8000-000000000003'::uuid ELSE 'd642f000-0000-4000-8000-000000000004'::uuid END,jurisdiction,family,version||' NONLEGAL2026',date '2026-01-01',date '2027-01-01',source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules FROM payroll.statutory_packs WHERE id IN('d642f000-0000-4000-8000-000000000001','d642f000-0000-4000-8000-000000000002');
SELECT is(payroll.issued_tax_qualification('d642f000-0000-4000-8000-000000000002','2025-12-25','2026-01-24')->>'ready','false','real insurance issuer rejects the independent synthetic pack');
SELECT throws_ok($q$SELECT payroll.validate_employee_statutory_context('{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2025-12-25","calculation_until":"2025-12-31","tax_duration_days":7,"insurance_obligation_month":"2025-07-02","insurance_owner_period":"d642e000-0000-4000-8000-000000000001","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}'::jsonb)$q$,'22023','payroll_insurance_ownership_invalid','ownership month must be an exact civil-month key');
SELECT throws_ok($q$SELECT payroll.validate_employee_statutory_context('{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2025-12-25","calculation_until":"2025-12-31","tax_duration_days":7,"insurance_obligation_month":"2025-12-01","insurance_owner_period":"synthetic-not-a-period","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}'::jsonb)$q$,'22023','payroll_insurance_ownership_invalid','ownership requires an opaque valid period identifier');
SELECT is(payroll.issued_tax_qualification('d642f000-0000-4000-8000-000000000001','2025-12-25','2026-01-24')->>'ready','false','real production issuer rejects synthetic pack; no official evidence is fabricated');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d6420000-0000-4000-8000-000000000001',true);
SELECT public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2025-12-25',NULL,'{"mode":"fixed_30_day","reason":"NONLEGAL accepted monthly policy"}','save',gen_random_uuid());
SELECT set_config('test.fixed_component',public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2025-12-25',NULL,'{"key":"fixed_allowance","name":"NONLEGAL fixed monthly allowance","classification":"earning","calculation":"fixed","base":"","value":"100","taxable":"true","social":"false","visible":"true","active":"true","order":"10","behavior":"recurring","proration":"salary_proration","reason":"Accepted recurring monthly-value contract"}','save',gen_random_uuid())->>'id',true);
SELECT public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','recurring','d6426000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-12-25',NULL,jsonb_build_object('component_id',current_setting('test.fixed_component'),'value','100','reason','NONLEGAL fixed assignment'),'save',gen_random_uuid());
SELECT set_config('test.percent_component',public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2025-12-25',NULL,'{"key":"earned_percent","name":"NONLEGAL earned-base percentage","classification":"earning","calculation":"percentage","base":"base_pay","value":"10","taxable":"true","social":"false","visible":"true","active":"true","order":"20","behavior":"recurring","proration":"salary_proration","reason":"Accepted earned-base percentage contract"}','save',gen_random_uuid())->>'id',true);
SELECT public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','recurring','d6426000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-12-25',NULL,jsonb_build_object('component_id',current_setting('test.percent_component'),'value','10','reason','NONLEGAL percentage assignment'),'save',gen_random_uuid());
SELECT public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','opening_ytd','d6426000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-12-25',NULL,'{"year":2025,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2025-01-01","coverage_end":"2025-12-24","tax_duration_days":0,"reference":"NONLEGAL no prior employment facts","reason":"Synthetic reviewed zero opening"}','save',gen_random_uuid());
SELECT set_config('test.context',(public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','statutory_context','d6426000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-12-25','2026-01-01','{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2025-12-25","calculation_until":"2025-12-31","tax_duration_days":7,"insurance_obligation_month":"2025-12-01","insurance_owner_period":"d642e000-0000-4000-8000-000000000001","insurance_month_disposition":"reviewed_due","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}','save',gen_random_uuid()))->>'id',true);
SELECT public.payroll_save_input('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','statutory_context','d6426000-0000-4000-8000-000000000001',NULL,current_setting('test.context')::uuid,1,'2026-01-01',NULL,'{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2026-01-01","calculation_until":"2026-01-24","tax_duration_days":24,"insurance_obligation_month":"2026-01-01","insurance_owner_period":"d642e000-0000-4000-8000-000000000001","insurance_month_disposition":"reviewed_due","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}','save',gen_random_uuid());
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL explicit two reviewed contexts',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'false','real issuer still blocks multi-context synthetic inputs');
CREATE OR REPLACE FUNCTION payroll.issued_tax_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$BEGIN
 IF current_database()<>'business_platform_cube4_adam_positive_qa' OR p_pack NOT IN('d642f000-0000-4000-8000-000000000001','d642f000-0000-4000-8000-000000000002','d642f000-0000-4000-8000-000000000003','d642f000-0000-4000-8000-000000000004') OR p_from<'2025-01-01' OR p_until>='2027-01-01' THEN
  RETURN jsonb_build_object('ready',false,'reason','synthetic_fixture_scope_refused');END IF;
 RETURN jsonb_build_object('ready',true,'scope','synthetic_external_evidence_contract','origin','synthetic_nonlegal','pack_id',p_pack,'reference','NONLEGAL test double; NOT an official issuer acceptance');END$$;

SET LOCAL ROLE authenticated;
SELECT public.payroll_run_command('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'cancel','NONLEGAL pre-issuer calculation retained',gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL explicit two reviewed contexts',gen_random_uuid())::text,true);
RESET ROLE;
SELECT output->'issues' AS actual_issues FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'true','actual multi-context producer requires separately qualified scoped packs');
SELECT is((SELECT (output->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),32000::numeric,'fixed30 full30000 salary minus one approved unpaid30000/30 day equals29000');
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),28620.06::numeric,'independent monthly one-day fixture net28620.06 reconciles gross29000 tax2879.94 employee insurance200');
SELECT is((SELECT jsonb_array_length(output->'employees'->0->'statutory_segments') FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),2,'both immutable legal context versions have independent explanations');
SELECT is((SELECT jsonb_array_length(output->'employees'->0->'statutory_context'->'obligation_months') FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),2,'December and January liabilities are independent once-owned calendar months');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->0->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),7474.19::numeric,'first salary segment preserves cent prefix');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->1->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),24525.81::numeric,'second salary segment is exact complementary amount');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->1->'statutory_calculation'->'facts'->>'prior_net_income')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),0::numeric,'January resets prior taxable at year start instead of carrying December income');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->1->'statutory_calculation'->'facts'->>'prior_tax_due')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),0::numeric,'January resets prior tax at year start instead of carrying December assessed tax');
CREATE FUNCTION pg_temp.dated_employee() RETURNS jsonb LANGUAGE sql AS $$ SELECT output->'employees'->0 FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid $$;
SELECT is(payroll.current_earning_sources(pg_temp.dated_employee())->'lines'->0->>'attribution','saved_salary_distribution','current earning source explicitly identifies approved dated payable units');
SELECT is(payroll.earning_date_partitions(pg_temp.dated_employee())->'lines'->0->>'operational_date_distribution_known','true','actual wrapped daily source exposes truthful operational dates');
SELECT is(jsonb_array_length(payroll.earning_date_partitions(pg_temp.dated_employee())->'lines'->0->'months'),2,'actual operational source preserves both civil months');
SELECT is(payroll.earning_date_partitions(pg_temp.dated_employee())->'lines'->0->>'legal_earning_attribution_known','false','operational dates alone do not mint an issued legal allocation');
SELECT throws_ok($q$SELECT payroll.reviewed_earning_segment(jsonb_set(jsonb_set(pg_temp.dated_employee(),'{source_summary,selected_source}','"manual"'),'{pay_basis}','"daily"'),'2025-12-25','2025-12-31')$q$,'22023','payroll_earning_allocation_unknown','manual aggregate cannot inherit Time date allocation');
SELECT ok(NOT has_function_privilege('authenticated','payroll.reviewed_earning_segment(jsonb,date,date)','EXECUTE'),'authenticated caller cannot mint a private earning segment');
SELECT set_config('test.base_manifest',(SELECT input_manifest::text FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),true);
SELECT set_config('test.monthly_missing',payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,coverage,items}','[]'))::text,true);
SELECT is(current_setting('test.monthly_missing')::jsonb->>'financially_qualified','false','monthly cannot infer work or absence from missing coverage');
SELECT is(current_setting('test.monthly_missing')::jsonb->'employees'->0->>'net',NULL::text,'monthly missing coverage exposes no payout');
SELECT is(payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,items,0,overtime}','[{"minutes":60,"decision":"approved"}]'))->>'financially_qualified','false','monthly approved overtime without valuation remains closed');
SELECT set_config('test.fixed_manifest',jsonb_set(current_setting('test.base_manifest')::jsonb,ARRAY['inputs',(SELECT (ordinality-1)::text FROM jsonb_array_elements(current_setting('test.base_manifest')::jsonb->'inputs') WITH ORDINALITY i(value,ordinality) WHERE value->'head'->>'kind'='policy'),'version','data','mode'],'"fixed_30_day"')::text,true);
SELECT set_config('test.fixed_unpaid',payroll.build_review(current_setting('test.fixed_manifest')::jsonb)::text,true);
SELECT is(current_setting('test.fixed_unpaid')::jsonb->>'financially_qualified','true','fixed30 approved unpaid portions use the frozen selected policy');
SELECT is((current_setting('test.fixed_unpaid')::jsonb->>'gross')::numeric,32000::numeric,'unchanged30000 salary minus one unpaid salary/30 day is29000, including31-day periods');
SELECT is((current_setting('test.fixed_unpaid')::jsonb->>'net')::numeric,28620.06::numeric,'fixed30 unpaid net reflects the approved source once across two contexts');
SELECT ok(NOT has_function_privilege('authenticated','payroll.monthly_source_parts(jsonb,jsonb,jsonb,jsonb,text)','EXECUTE'),'monthly approved-source valuation is private');
SELECT set_config('test.full_fixed_manifest',jsonb_set(current_setting('test.fixed_manifest')::jsonb,ARRAY['optional_sources','time','items',(SELECT (ordinality-1)::text FROM jsonb_array_elements(current_setting('test.fixed_manifest')::jsonb->'optional_sources'->'time'->'items') WITH ORDINALITY i(value,ordinality) WHERE value->>'date'='2026-01-02')],(SELECT value||'{"outcome":"worked","worked_minutes":480,"absence_units":0}' FROM jsonb_array_elements(current_setting('test.fixed_manifest')::jsonb->'optional_sources'->'time'->'items') i(value) WHERE value->>'date'='2026-01-02'))::text,true);
SELECT set_config('test.full_fixed',payroll.build_review(current_setting('test.full_fixed_manifest')::jsonb)::text,true);
SELECT is(current_setting('test.full_fixed')::jsonb->>'financially_qualified','true','fixed30 full ordinary cycle with dated salary changes remains supported');
SELECT is((current_setting('test.full_fixed')::jsonb->>'gross')::numeric,33100::numeric,'fixed30 full-cycle salary remains30000 with no unpaid portion');
SELECT is((current_setting('test.full_fixed')::jsonb->>'net')::numeric,29610.06::numeric,'fixed30 full-cycle source-qualified net matches independently reviewed context composition');

SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,1,'approve','NONLEGAL grouped calculation review',gen_random_uuid());
SELECT set_config('test.attempt',gen_random_uuid()::text,true);
SELECT set_config('test.final',public.payroll_run_finalize('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.attempt')::uuid)::text,true);
SELECT is(public.payroll_run_finalize('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.attempt')::uuid),current_setting('test.final')::jsonb,'same attempt returns the one committed output');
SELECT is(public.payroll_run_finalization_reconcile('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','d642e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.attempt')::uuid)->'result',current_setting('test.final')::jsonb,'recovery reads the original grouped financial receipt');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_employees),1::bigint,'one immutable employee output contains both reviewed segments');
SELECT is((SELECT jsonb_array_length(payroll.prior_statutory_outputs('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','2026-01-25','2026-02-24',ARRAY['d6425000-0000-4000-8000-000000000001']::uuid[]))),2,'next period projects both cross-year authoritative segments into cumulative history');
SELECT ok((SELECT bool_and(payroll.prior_statutory_output_usable(value)) FROM jsonb_array_elements(payroll.prior_statutory_outputs('d6421000-0000-4000-8000-000000000001','d6423000-0000-4000-8000-000000000001','2026-01-25','2026-02-24',ARRAY['d6425000-0000-4000-8000-000000000001']::uuid[]))),'each frozen segment satisfies historical structural and numeric contract');

SELECT is((SELECT count(*) FROM payroll.final_source_bindings WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid AND source_domain='time'),31::bigint,'each dated Time lineage is frozen once across both contexts');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions WHERE run_id=(current_setting('test.run')::jsonb->>'id')::uuid),8::bigint,'policy opening contexts and both component/recurring heads consumed once');
SELECT is((SELECT (output->'employees'->0->>'base')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),29000::numeric,'saved public candidate base is29000 before legal deductions');
SELECT is((SELECT (explanation->>'gross')::numeric FROM payroll.final_employees WHERE tenant_id='d6421000-0000-4000-8000-000000000001'),32000::numeric,'atomic output preserves approved fixed30 unpaid base');
SELECT is((SELECT (explanation->'source_summary'->>'absence_units')::numeric FROM payroll.final_employees WHERE tenant_id='d6421000-0000-4000-8000-000000000001'),1::numeric,'immutable output keeps the one approved absence quantity');

SELECT is((SELECT (line->>'amount')::numeric FROM payroll.candidates c CROSS JOIN LATERAL jsonb_array_elements(c.output->'employees'->0->'lines') line WHERE c.id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid AND line->>'component'=current_setting('test.fixed_component')),100::numeric,'fixed allowance retains full monthly100 despite one approved unpaid day');
SELECT is((SELECT (line->>'amount')::numeric FROM payroll.candidates c CROSS JOIN LATERAL jsonb_array_elements(c.output->'employees'->0->'lines') line WHERE c.id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid AND line->>'component'=current_setting('test.percent_component')),2900::numeric,'earned10percent follows fixed30 base29000 including signed dated counterportion');
SELECT * FROM finish();ROLLBACK;
