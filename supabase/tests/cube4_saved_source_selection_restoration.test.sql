BEGIN;
DO $$ BEGIN
  IF current_database() <> 'business_platform_cube4_adam_positive_qa' THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- One bounded, rollback-only NONLEGAL source fixture.  Time is deliberately
-- absent; this acceptance exercises only the actual Leave source lineage.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d4400000-0000-4000-8000-000000000001','d440-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d4400000-0000-4000-8000-000000000002','d440-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d4401000-0000-4000-8000-000000000001','NONLEGAL D440 Leave binding QA','d4400000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d4401000-0000-4000-8000-000000000001','d4402000-0000-4000-8000-000000000001','d440.payroll.leave',1,
 ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','payroll.review','payroll.export','payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','employee_finance.manage','employee_finance.approve','leave.manage','leave.view','leave.approve']),
       ('d4401000-0000-4000-8000-000000000001','d4402000-0000-4000-8000-000000000002','d440.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d4401000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001'),
       ('d4401000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002','d4400000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d4401000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','d4402000-0000-4000-8000-000000000001'),
       ('d4401000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002','d4402000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','NONLEGAL D440 NONLEGAL Employer','NONLEGAL D440 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd4401000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d4400000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d4401000-0000-4000-8000-000000000001','d4404000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','NONLEGAL D440 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d4401000-0000-4000-8000-000000000001','d4405000-0000-4000-8000-000000000001','NONLEGAL D440','NONLEGAL D440 Leave Employee','d4400000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d4401000-0000-4000-8000-000000000001','d4406000-0000-4000-8000-000000000001','d4405000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','2026-07-01','active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d4401000-0000-4000-8000-000000000001','d4405000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002','d4400000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d4401000-0000-4000-8000-000000000001','d4407000-0000-4000-8000-000000000001','d4406000-0000-4000-8000-000000000001',30000,'2026-07-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
VALUES ('d4401000-0000-4000-8000-000000000001','d4409000-0000-4000-8000-000000000001','d4406000-0000-4000-8000-000000000001','d4404000-0000-4000-8000-000000000001','2026-07-01');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440d000-0000-4000-8000-000000000001',1,'2026-07-01',NULL,31,'ending','UTC','d4400000-0000-4000-8000-000000000001','NONLEGAL D440 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001','d440d000-0000-4000-8000-000000000001','2026-07-01','2026-07-31','2026-07-31','UTC','NONLEGAL D440 one-day NONLEGAL Leave QA',false,'d4400000-0000-4000-8000-000000000001');


INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
VALUES('d440f000-0000-4000-8000-000000000001','EG','egypt_payroll','NONLEGAL single-band arithmetic fixture','2026-01-01','2027-01-01','["NONLEGAL synthetic arithmetic"]','{"numeric_comparisons":["NONLEGAL isolated math only"]}','verified','d4400000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
'{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}','{}',
'{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000001',true);
SELECT public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2026-07-01',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted monthly policy"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','opening_ytd','d4406000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-07-01',NULL,'{"year":2026,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2026-01-01","coverage_end":"2026-06-30","tax_duration_days":0,"reference":"NONLEGAL no prior employment facts","reason":"Synthetic reviewed zero opening"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','statutory_context','d4406000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-07-01',NULL,'{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL reviewed uninsured exclusion","reason":"Synthetic source facts only","calculation_from":"2026-07-01","calculation_until":"2026-07-31","tax_duration_days":30}','save',gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL actual issuer negative',gen_random_uuid())::text,true);
RESET ROLE;
-- ONLY the external evidence supplier is simulated inside this isolated test
-- transaction. It carries no official origin, expected-result or legal claim.
-- Actual producer, source/profile checks, arithmetic, auth and public commands
-- remain unchanged. ROLLBACK restores the real supplier and all business data.
CREATE OR REPLACE FUNCTION payroll.issued_tax_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$BEGIN
 IF current_database()<>'business_platform_cube4_adam_positive_qa' OR p_pack<>'d440f000-0000-4000-8000-000000000001' OR p_from<'2026-01-01' OR p_until>='2027-01-01' THEN
  RETURN jsonb_build_object('ready',false,'reason','synthetic_fixture_scope_refused');END IF;
 RETURN jsonb_build_object('ready',true,'scope','synthetic_external_evidence_contract','origin','synthetic_nonlegal','pack_id',p_pack,'reference','NONLEGAL test double; NOT an official issuer acceptance');END$$;
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'calculate','NONLEGAL positive implementation journey',gen_random_uuid())::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,'approve','NONLEGAL implementation approval',gen_random_uuid());
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('test.final_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.final',public.payroll_run_finalize('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid)::text,true);
RESET ROLE;
SELECT set_config('test.original_employee', (SELECT to_jsonb(e)::text FROM payroll.final_employees e WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),true);

SET LOCAL ROLE authenticated;
SELECT is(public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'compensation','sources',p_selected=>'d4407000-0000-4000-8000-000000000001')->'selected'->>'id','d4407000-0000-4000-8000-000000000001','saved compensation restores without picker employee');
SELECT is(public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'assignment','sources',p_selected=>'d4409000-0000-4000-8000-000000000001')->'selected'->>'id','d4409000-0000-4000-8000-000000000001','saved assignment restores without picker employee');
SELECT is(public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'employment','sources',p_selected=>'d4406000-0000-4000-8000-000000000001')->'selected'->>'id','d4406000-0000-4000-8000-000000000001','saved employment restores without picker employee');
SELECT is(jsonb_array_length(public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'compensation','sources')->'items'),0,'unselected list is not broadened');
SELECT is(public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'compensation','sources',p_selected=>'d4407000-0000-4000-8000-000000000099')->'selected','null'::jsonb,'unknown selected source remains absent');
RESET ROLE;
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active) VALUES('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000002','NONLEGAL other Employer','NONLEGAL other Employer',false,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d4401000-0000-4000-8000-000000000001','d4405000-0000-4000-8000-000000000099','NONLEGAL other Employee','NONLEGAL other Employee','d4400000-0000-4000-8000-000000000001');INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis) VALUES('d4401000-0000-4000-8000-000000000001','d4406000-0000-4000-8000-000000000099','d4405000-0000-4000-8000-000000000099','d4403000-0000-4000-8000-000000000002','2026-08-01','active','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d4401000-0000-4000-8000-000000000001','d4407000-0000-4000-8000-000000000099','d4406000-0000-4000-8000-000000000099',999,'2026-08-01');
SELECT set_config('test.saved_head',(SELECT id::text FROM payroll.input_heads WHERE tenant_id='d4401000-0000-4000-8000-000000000001' AND kind='statutory_context'),true);
SET LOCAL ROLE authenticated;
SELECT is(public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'compensation','sources',p_selected=>'d4407000-0000-4000-8000-000000000099')->'selected','null'::jsonb,'explicit selected source cannot cross Employer');
SELECT is(public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'input_revision','sources',p_selected=>current_setting('test.saved_head')::uuid)->'selected'->>'id',current_setting('test.saved_head'),'saved employee-scoped input restores without picker employee');
RESET ROLE;INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) SELECT tenant_id,'d4402000-0000-4000-8000-000000000003','d440.payroll.restoration.revoked',1,array_remove(permission_snapshot,'compensation.manage') FROM platform_core.tenant_roles WHERE role_id='d4402000-0000-4000-8000-000000000001';DELETE FROM platform_core.membership_roles WHERE tenant_id='d4401000-0000-4000-8000-000000000001' AND user_id='d4400000-0000-4000-8000-000000000001';INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('d4401000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','d4402000-0000-4000-8000-000000000003');SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_correction_choices('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,'compensation','sources',p_selected=>'d4407000-0000-4000-8000-000000000001')$q$,'42501','payroll_forbidden','selected saved source still requires live management permission');
RESET ROLE;SELECT * FROM finish();ROLLBACK;
