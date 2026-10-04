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
VALUES ('d6630000-0000-4000-8000-000000000001','d663-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d6630000-0000-4000-8000-000000000002','d663-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d6631000-0000-4000-8000-000000000001','NONLEGAL D663 Leave binding QA','d6630000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d6631000-0000-4000-8000-000000000001','d6632000-0000-4000-8000-000000000001','d663.payroll.leave',1,
 ARRAY['employee_finance.manage','employee_finance.approve','people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','payroll.review','payroll.export','payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','leave.manage','leave.view','leave.approve','employee_finance.view','employee_finance.manage','employee_finance.approve']),
       ('d6631000-0000-4000-8000-000000000001','d6632000-0000-4000-8000-000000000002','d663.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d6631000-0000-4000-8000-000000000001','d6630000-0000-4000-8000-000000000001','d6630000-0000-4000-8000-000000000001'),
       ('d6631000-0000-4000-8000-000000000001','d6630000-0000-4000-8000-000000000002','d6630000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d6631000-0000-4000-8000-000000000001','d6630000-0000-4000-8000-000000000001','d6632000-0000-4000-8000-000000000001'),
       ('d6631000-0000-4000-8000-000000000001','d6630000-0000-4000-8000-000000000002','d6632000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','NONLEGAL D663 NONLEGAL Employer','NONLEGAL D663 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd6631000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d6630000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll','hr.employee_finance']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d6631000-0000-4000-8000-000000000001','d6634000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','NONLEGAL D663 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d6631000-0000-4000-8000-000000000001','d6635000-0000-4000-8000-000000000001','NONLEGAL D663','NONLEGAL D663 Leave Employee','d6630000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d6631000-0000-4000-8000-000000000001','d6636000-0000-4000-8000-000000000001','d6635000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','2025-12-25','active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d6631000-0000-4000-8000-000000000001','d6635000-0000-4000-8000-000000000001','d6630000-0000-4000-8000-000000000002','d6630000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d6631000-0000-4000-8000-000000000001','d6637000-0000-4000-8000-000000000001','d6636000-0000-4000-8000-000000000001',30000,'2025-12-25');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
VALUES ('d6631000-0000-4000-8000-000000000001','d6639000-0000-4000-8000-000000000001','d6636000-0000-4000-8000-000000000001','d6634000-0000-4000-8000-000000000001','2025-12-25');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663d000-0000-4000-8000-000000000001',1,'2025-12-25',NULL,31,'ending','UTC','d6630000-0000-4000-8000-000000000001','NONLEGAL D663 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001','d663d000-0000-4000-8000-000000000001','2025-12-25','2026-01-24','2026-01-24','UTC','NONLEGAL D663 one-day NONLEGAL Leave QA',false,'d6630000-0000-4000-8000-000000000001');


INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
VALUES('d663f000-0000-4000-8000-000000000001','EG','egypt_payroll','NONLEGAL single-band arithmetic fixture','2025-01-01','2026-01-01','["NONLEGAL synthetic arithmetic"]','{"numeric_comparisons":["NONLEGAL isolated math only"]}','verified','d6630000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
'{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}','{}',
'{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable","date_partition_rounding":"chronological_prefix_half_up_cent"}');
INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
SELECT 'd663f000-0000-4000-8000-000000000002',jurisdiction,family,'NONLEGAL independent insurance arithmetic','2025-01-01','2026-01-01',source_references,review_evidence,state,verified_by,engine_adapter,jsonb_set(rules,'{tax_treatment_code}','"02"'),
'{"schema":"eg-insurance-month-v1","category":"NONLEGAL pension fixture","wage_minimum":100,"wage_maximum":20000,"rounding":"each_branch_month_half_up_cent","branches":[{"branch":"pension","employee_rate":0.01,"employer_rate":0.02,"tax_deductible":true}]}',earning_rules
FROM payroll.statutory_packs WHERE id='d663f000-0000-4000-8000-000000000001';
INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
SELECT CASE WHEN id='d663f000-0000-4000-8000-000000000001' THEN 'd663f000-0000-4000-8000-000000000003'::uuid ELSE 'd663f000-0000-4000-8000-000000000004'::uuid END,jurisdiction,family,version||' NONLEGAL2026',date '2026-01-01',date '2027-01-01',source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules FROM payroll.statutory_packs WHERE id IN('d663f000-0000-4000-8000-000000000001','d663f000-0000-4000-8000-000000000002');
SELECT is(payroll.issued_tax_qualification('d663f000-0000-4000-8000-000000000002','2025-12-25','2026-01-24')->>'ready','false','real insurance issuer rejects the independent synthetic pack');
SELECT throws_ok($q$SELECT payroll.validate_employee_statutory_context('{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2025-12-25","calculation_until":"2025-12-31","tax_duration_days":7,"insurance_obligation_month":"2025-07-02","insurance_owner_period":"d663e000-0000-4000-8000-000000000001","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}'::jsonb)$q$,'22023','payroll_insurance_ownership_invalid','ownership month must be an exact civil-month key');
SELECT throws_ok($q$SELECT payroll.validate_employee_statutory_context('{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2025-12-25","calculation_until":"2025-12-31","tax_duration_days":7,"insurance_obligation_month":"2025-12-01","insurance_owner_period":"synthetic-not-a-period","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}'::jsonb)$q$,'22023','payroll_insurance_ownership_invalid','ownership requires an opaque valid period identifier');
SELECT is(payroll.issued_tax_qualification('d663f000-0000-4000-8000-000000000001','2025-12-25','2026-01-24')->>'ready','false','real production issuer rejects synthetic pack; no official evidence is fabricated');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d6630000-0000-4000-8000-000000000001',true);
SELECT public.payroll_save_input('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2025-12-25',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted monthly policy"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','opening_ytd','d6636000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-12-25',NULL,'{"year":2025,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2025-01-01","coverage_end":"2025-12-24","tax_duration_days":0,"reference":"NONLEGAL no prior employment facts","reason":"Synthetic reviewed zero opening"}','save',gen_random_uuid());
SELECT set_config('test.context',(public.payroll_save_input('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','statutory_context','d6636000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-12-25','2026-01-01','{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2025-12-25","calculation_until":"2025-12-31","tax_duration_days":7,"insurance_obligation_month":"2025-12-01","insurance_owner_period":"d663e000-0000-4000-8000-000000000001","insurance_month_disposition":"reviewed_due","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}','save',gen_random_uuid()))->>'id',true);
SELECT public.payroll_save_input('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','statutory_context','d6636000-0000-4000-8000-000000000001',NULL,current_setting('test.context')::uuid,1,'2026-01-01',NULL,'{"tax_treatment_code":"01","insurance_status":"insured","insurance_category":"NONLEGAL pension fixture","insured_wage":10000,"insurance_from":"2025-12-25","reference":"NONLEGAL reviewed insured wage source","reason":"Synthetic source facts only","calculation_from":"2026-01-01","calculation_until":"2026-01-24","tax_duration_days":24,"insurance_obligation_month":"2026-01-01","insurance_owner_period":"d663e000-0000-4000-8000-000000000001","insurance_month_disposition":"reviewed_due","insurance_obligation_reference":"NONLEGAL independently supplied month ownership"}','save',gen_random_uuid());
RESET ROLE;

SET LOCAL ROLE authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('test.termination_component',(public.payroll_save_input('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2025-12-25',NULL,'{"key":"attachment_reviewed","name":"NONLEGAL reviewed employer penalty","classification":"deduction","calculation":"fixed","base":"","value":"0","taxable":false,"social":false,"visible":true,"active":true,"proration":"salary_proration","order":"50","behavior":"period_input","reason":"Explicit reviewed manual V1 handoff; no entitlement formula"}','save',gen_random_uuid())->>'id'),true);
SELECT set_config('test.termination_data',jsonb_build_object('component_id',current_setting('test.termination_component'),'amount',8000,'deduction_category','employer_penalty','reference','NONLEGAL external termination calculation document','reason','Reviewed contractual amount outside automated V1 coverage')::text,true);
SELECT set_config('test.termination_adjustment',(public.payroll_save_input('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','adjustment','d6636000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',NULL,0,'2025-12-25','2026-01-25',current_setting('test.termination_data')::jsonb,'save',gen_random_uuid())->>'id'),true);
SELECT public.payroll_save_input('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','adjustment','d6636000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',current_setting('test.termination_adjustment')::uuid,1,'2025-12-25','2026-01-25',current_setting('test.termination_data')::jsonb,'approve',gen_random_uuid());
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.loan', 'd6638000-0000-4000-8000-000000000001',true);
SELECT public.payroll_advance_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001',jsonb_build_object('operation','save','advance',current_setting('test.loan'),'employment','d6636000-0000-4000-8000-000000000001','expected',0,'data',jsonb_build_object('principal','2000.00','count','1','first_period','d663e000-0000-4000-8000-000000000001','effective_on','2025-12-25','reason','NONLEGAL actual loan source')),gen_random_uuid());
SELECT public.payroll_advance_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001',jsonb_build_object('operation','approve','advance',current_setting('test.loan'),'employment','d6636000-0000-4000-8000-000000000001','expected',1,'data',jsonb_build_object('reference','NONLEGAL source approval','reason','Synthetic approval','confirmed','yes','date','2025-12-25')),gen_random_uuid());
SELECT public.payroll_advance_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001',jsonb_build_object('operation','activate','advance',current_setting('test.loan'),'employment','d6636000-0000-4000-8000-000000000001','expected',2,'data',jsonb_build_object('reference','NONLEGAL external disbursement','reason','Synthetic actual source debt','confirmed','yes','date','2025-12-25')),gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL explicit two reviewed contexts',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'false','real issuer still blocks multi-context synthetic inputs');
CREATE OR REPLACE FUNCTION payroll.issued_tax_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$BEGIN
 IF current_database()<>'business_platform_cube4_adam_positive_qa' OR p_pack NOT IN('d663f000-0000-4000-8000-000000000001','d663f000-0000-4000-8000-000000000002','d663f000-0000-4000-8000-000000000003','d663f000-0000-4000-8000-000000000004') OR p_from<'2025-01-01' OR p_until>='2027-01-01' THEN
  RETURN jsonb_build_object('ready',false,'reason','synthetic_fixture_scope_refused');END IF;
 RETURN jsonb_build_object('ready',true,'scope','synthetic_external_evidence_contract','origin','synthetic_nonlegal','pack_id',p_pack,'reference','NONLEGAL test double; NOT an official issuer acceptance');END$$;

SET LOCAL ROLE authenticated;
SELECT public.payroll_run_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'cancel','NONLEGAL pre-issuer calculation retained',gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL explicit two reviewed contexts',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'false','tax evidence alone cannot qualify an approved general deduction');
SELECT ok((SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(output->'issues') issue WHERE issue->>'code'='issued_labour_evidence_required') FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'owned blocker identifies the independent labour issuer');
SET LOCAL ROLE authenticated;
SELECT public.payroll_run_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'cancel','NONLEGAL labour supplier prerequisite retained',gen_random_uuid());
RESET ROLE;
CREATE OR REPLACE FUNCTION payroll.issued_labour_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$BEGIN
 IF current_database()<>'business_platform_cube4_adam_positive_qa' OR p_pack NOT IN('d663f000-0000-4000-8000-000000000001','d663f000-0000-4000-8000-000000000003') OR p_from<'2025-01-01' OR p_until>='2027-01-01' THEN
  RETURN jsonb_build_object('ready',false,'reason','synthetic_labour_scope_refused');END IF;
 RETURN jsonb_build_object('ready',true,'scope','synthetic_external_labour_contract','origin','synthetic_nonlegal','pack_id',p_pack,'reference','NONLEGAL fixture dependency only; no official legal qualification');END$$;
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL actual approved deduction composition',gen_random_uuid())::text,true);
RESET ROLE;


SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'false','approved8000 overcapacity is not a financially qualified partial consumption');
SELECT is((SELECT (output->'employees'->0->'deduction_plan'->>'unapplied_amount')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),1794.99::numeric,'unapplied approved obligation remains visible with its exact residual');
SELECT is((SELECT count(*) FROM payroll.final_employees),0::bigint,'overcapacity public calculation commits no financial output');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE advance_id=current_setting('test.loan')::uuid AND kind='payroll_deduction'),0::bigint,'blocked claim leaves approved loan unconsumed');
SELECT is(payroll.advance_balance('d6631000-0000-4000-8000-000000000001',current_setting('test.loan')::uuid),2000::numeric,'overcapacity claim cannot lower actual outstanding loan');

SELECT is((SELECT jsonb_array_length(output->'employees'->0->'statutory_segments') FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),2,'blocked debt retains completed independent statutory segment explanations');
SELECT ok((SELECT output->'employees'->0->>'net' IS NULL AND output->'employees'->0->>'calculated_net' IS NULL FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'capacity explanation exposes no qualified or provisional payout');

SELECT is((SELECT v.status FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.id=current_setting('test.termination_adjustment')::uuid),'approved','overcapacity leaves approved source unconsumed');
SET LOCAL ROLE authenticated;
SELECT throws_ok(format($q$SELECT public.payroll_candidate_approval('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',%L::uuid,%L::uuid,1,'approve','NONLEGAL overcapacity refusal',gen_random_uuid())$q$,current_setting('test.run')::jsonb->>'id',current_setting('test.run')::jsonb->>'candidate_id'),'23514',NULL,'public approval refuses unapplied obligation');
RESET ROLE;
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000002','d663d000-0000-4000-8000-000000000001','2026-01-25','2026-02-24','2026-02-24','UTC','NONLEGAL next cutoff period',false,'d6630000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('test.disposition_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.disposition',public.payroll_deduction_disposition('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,1,'d6636000-0000-4000-8000-000000000001',current_setting('test.termination_adjustment'),3000,'external_settlement',NULL,'2026-01-24','NONLEGAL approved5000 residual','NONLEGAL approved partial3000 and carry5000; no debt cancellation',current_setting('test.disposition_attempt')::uuid)::text,true);
SELECT is(public.payroll_deduction_disposition('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,1,'d6636000-0000-4000-8000-000000000001',current_setting('test.termination_adjustment'),3000,'external_settlement',NULL,'2026-01-24','NONLEGAL approved5000 residual','NONLEGAL approved partial3000 and carry5000; no debt cancellation',current_setting('test.disposition_attempt')::uuid),current_setting('test.disposition')::jsonb,'same disposition receipt creates one attributable remainder');
SELECT public.payroll_run_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'cancel','NONLEGAL replaced stale candidate after approved debt disposition; original debt retained',gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL explicit3000 recovery5000 carry',gen_random_uuid())::text,true);
RESET ROLE;
SELECT output->'issues' AS actual_issues FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'true','actual multi-context producer requires separately qualified scoped packs');
SELECT is((SELECT (output->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),30000::numeric,'segment cents conserve original rounded monthly gross');
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),21820.06::numeric,'Dec7/Jan24 tax and two insurance months reconcile with one approved1000 deduction');
SELECT is((SELECT jsonb_array_length(output->'employees'->0->'statutory_segments') FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),2,'both immutable legal context versions have independent explanations');
SELECT is((SELECT jsonb_array_length(output->'employees'->0->'statutory_context'->'obligation_months') FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),2,'December and January liabilities are independent once-owned calendar months');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->0->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),6774.19::numeric,'first salary segment preserves cent prefix');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->1->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),23225.81::numeric,'second salary segment is exact complementary amount');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->1->'statutory_calculation'->'facts'->>'prior_net_income')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),0::numeric,'January resets prior taxable at year start instead of carrying December income');
SELECT is((SELECT (output->'employees'->0->'statutory_segments'->1->'statutory_calculation'->'facts'->>'prior_tax_due')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),0::numeric,'January resets prior tax at year start instead of carrying December assessed tax');
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,1,'approve','NONLEGAL grouped calculation review',gen_random_uuid());
SELECT set_config('test.attempt',gen_random_uuid()::text,true);
SELECT set_config('test.final',public.payroll_run_finalize('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.attempt')::uuid)::text,true);
SELECT is(public.payroll_run_finalize('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.attempt')::uuid),current_setting('test.final')::jsonb,'same attempt returns the one committed output');
SELECT is(public.payroll_run_finalization_reconcile('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.attempt')::uuid)->'result',current_setting('test.final')::jsonb,'recovery reads the original grouped financial receipt');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_employees),1::bigint,'one immutable employee output contains both reviewed segments');
SELECT is((SELECT jsonb_array_length(payroll.prior_statutory_outputs('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','2026-01-25','2026-02-24',ARRAY['d6635000-0000-4000-8000-000000000001']::uuid[]))),2,'next period projects both cross-year authoritative segments into cumulative history');
SELECT ok((SELECT bool_and(payroll.prior_statutory_output_usable(value)) FROM jsonb_array_elements(payroll.prior_statutory_outputs('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','2026-01-25','2026-02-24',ARRAY['d6635000-0000-4000-8000-000000000001']::uuid[]))),'each frozen segment satisfies historical structural and numeric contract');

SELECT is((SELECT residual_amount FROM payroll.deduction_dispositions),5000::numeric,'external evidence accounts for exact residual5000');
SELECT ok((SELECT target_head IS NULL AND target_period IS NULL FROM payroll.deduction_dispositions),'external residual creates no future deduction source');
SELECT is((SELECT occurred_on::text FROM payroll.deduction_dispositions),'2026-01-24','actual external settlement date is retained');
SELECT is((SELECT count(*) FROM payroll.payment_events),0::bigint,'settling debt outside payroll creates no fabricated salary payment');
SELECT is((SELECT status FROM payroll.input_versions WHERE head_id=current_setting('test.termination_adjustment')::uuid ORDER BY revision DESC LIMIT 1),'applied','original debt consumes with preserved8000 and external residual evidence');
SET LOCAL ROLE authenticated;
SELECT throws_ok(format($q$SELECT public.payroll_deduction_disposition_retract('d6631000-0000-4000-8000-000000000001','d6633000-0000-4000-8000-000000000001','d663e000-0000-4000-8000-000000000001',%L::uuid,'NONLEGAL forbidden rewrite','NONLEGAL post-consumption rewrite',gen_random_uuid())$q$,current_setting('test.disposition')::jsonb->>'id'),'23514','payroll_correction_required','consumed split requires governed correction instead of retraction');
RESET ROLE;
SELECT * FROM finish();ROLLBACK;
