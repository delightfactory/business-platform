BEGIN;
DO $$ BEGIN
  IF current_database() <> 'business_platform_cube4_adam_positive_qa' THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- Bounded rollback-only NONLEGAL financial source fixture. Time/Leave are
-- absent; only the external issuer prerequisite is simulated below.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d4600000-0000-4000-8000-000000000001','d460-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d4600000-0000-4000-8000-000000000002','d460-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d4601000-0000-4000-8000-000000000001','NONLEGAL D460 Leave binding QA','d4600000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d4601000-0000-4000-8000-000000000001','d4602000-0000-4000-8000-000000000001','d460.payroll.leave',1,
 ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','payroll.review','payroll.export','payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','leave.manage','leave.view','leave.approve','employee_finance.view','employee_finance.manage','employee_finance.approve']),
       ('d4601000-0000-4000-8000-000000000001','d4602000-0000-4000-8000-000000000002','d460.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d4601000-0000-4000-8000-000000000001','d4600000-0000-4000-8000-000000000001','d4600000-0000-4000-8000-000000000001'),
       ('d4601000-0000-4000-8000-000000000001','d4600000-0000-4000-8000-000000000002','d4600000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d4601000-0000-4000-8000-000000000001','d4600000-0000-4000-8000-000000000001','d4602000-0000-4000-8000-000000000001'),
       ('d4601000-0000-4000-8000-000000000001','d4600000-0000-4000-8000-000000000002','d4602000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','NONLEGAL D460 NONLEGAL Employer','NONLEGAL D460 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd4601000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d4600000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll','hr.employee_finance']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d4601000-0000-4000-8000-000000000001','d4604000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','NONLEGAL D460 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d4601000-0000-4000-8000-000000000001','d4605000-0000-4000-8000-000000000001','NONLEGAL D460','NONLEGAL D460 Leave Employee','d4600000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d4601000-0000-4000-8000-000000000001','d4606000-0000-4000-8000-000000000001','d4605000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','2026-07-01','active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d4601000-0000-4000-8000-000000000001','d4605000-0000-4000-8000-000000000001','d4600000-0000-4000-8000-000000000002','d4600000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d4601000-0000-4000-8000-000000000001','d4607000-0000-4000-8000-000000000001','d4606000-0000-4000-8000-000000000001',30000,'2026-07-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
VALUES ('d4601000-0000-4000-8000-000000000001','d4609000-0000-4000-8000-000000000001','d4606000-0000-4000-8000-000000000001','d4604000-0000-4000-8000-000000000001','2026-07-01');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460d000-0000-4000-8000-000000000001',1,'2026-07-01',NULL,31,'ending','UTC','d4600000-0000-4000-8000-000000000001','NONLEGAL D460 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001','d460d000-0000-4000-8000-000000000001','2026-07-01','2026-07-31','2026-07-31','UTC','NONLEGAL D460 one-day NONLEGAL Leave QA',false,'d4600000-0000-4000-8000-000000000001');


INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
VALUES('d460f000-0000-4000-8000-000000000001','EG','egypt_payroll','NONLEGAL single-band arithmetic fixture','2026-01-01','2027-01-01','["NONLEGAL synthetic arithmetic"]','{"numeric_comparisons":["NONLEGAL isolated math only"]}','verified','d4600000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
'{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}','{}',
'{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}');
SELECT is(payroll.issued_tax_qualification('d460f000-0000-4000-8000-000000000001','2026-07-01','2026-07-31')->>'ready','false','real production issuer rejects synthetic pack; no official evidence is fabricated');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4600000-0000-4000-8000-000000000001',true);
SELECT public.payroll_save_input('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2026-07-01',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted monthly policy"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','opening_ytd','d4606000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-07-01',NULL,'{"year":2026,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2026-01-01","coverage_end":"2026-06-30","tax_duration_days":0,"reference":"NONLEGAL no prior employment facts","reason":"Synthetic reviewed zero opening"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','statutory_context','d4606000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-07-01',NULL,'{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL reviewed uninsured exclusion","reason":"Synthetic source facts only","calculation_from":"2026-07-01","calculation_until":"2026-07-31","tax_duration_days":30}','save',gen_random_uuid());

SELECT set_config('test.loan', 'd4608000-0000-4000-8000-000000000001',true);
SELECT public.payroll_advance_command('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',jsonb_build_object('operation','save','advance',current_setting('test.loan'),'employment','d4606000-0000-4000-8000-000000000001','expected',0,'data',jsonb_build_object('principal','3000.00','count','1','first_period','d460e000-0000-4000-8000-000000000001','effective_on','2026-07-01','reason','NONLEGAL actual loan source')),gen_random_uuid());
SELECT public.payroll_advance_command('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',jsonb_build_object('operation','approve','advance',current_setting('test.loan'),'employment','d4606000-0000-4000-8000-000000000001','expected',1,'data',jsonb_build_object('reference','NONLEGAL source approval','reason','Synthetic approval','confirmed','yes','date','2026-07-01')),gen_random_uuid());
SELECT public.payroll_advance_command('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',jsonb_build_object('operation','activate','advance',current_setting('test.loan'),'employment','d4606000-0000-4000-8000-000000000001','expected',2,'data',jsonb_build_object('reference','NONLEGAL external disbursement','reason','Synthetic actual source debt','confirmed','yes','date','2026-07-01')),gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL actual issuer negative',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'false','actual calculation remains legally closed without real issuer evidence');
-- ONLY the external evidence supplier is simulated inside this isolated test
-- transaction. It carries no official origin, expected-result or legal claim.
-- Actual producer, source/profile checks, arithmetic, auth and public commands
-- remain unchanged. ROLLBACK restores the real supplier and all business data.
CREATE OR REPLACE FUNCTION payroll.issued_tax_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$BEGIN
 IF current_database()<>'business_platform_cube4_adam_positive_qa' OR p_pack<>'d460f000-0000-4000-8000-000000000001' OR p_from<'2026-01-01' OR p_until>='2027-01-01' THEN
  RETURN jsonb_build_object('ready',false,'reason','synthetic_fixture_scope_refused');END IF;
 RETURN jsonb_build_object('ready',true,'scope','synthetic_external_evidence_contract','origin','synthetic_nonlegal','pack_id',p_pack,'reference','NONLEGAL test double; NOT an official issuer acceptance');END$$;
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'calculate','NONLEGAL positive implementation journey',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT (output->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),30000::numeric,'actual monthly gross calculated from dated compensation');
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),24000::numeric,'actual tax composition reconciles synthetic net');
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'true','actual profile producer qualifies only after simulated external evidence prerequisite');
SELECT is((SELECT output->'employees'->0->'financial_qualification'->'tax_evidence'->>'origin' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'synthetic_nonlegal','candidate retains explicit synthetic evidence boundary');

SELECT is((SELECT (output->>'deductions')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),3000::numeric,'root deduction total equals actual employer-loan installment');
SELECT is((SELECT (output->'employees'->0->'advance_deductions'->0->'cap_evidence'->>'ceiling')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),3000::numeric,'actual wage ceiling is computed, not an allowance flag');
SELECT is((SELECT count(*) FROM payroll.advance_allowances WHERE tenant_id='d4601000-0000-4000-8000-000000000001'),0::bigint,'no synthetic or user-supplied advance allowance qualifies consumption');
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,'approve','NONLEGAL implementation approval',gen_random_uuid());
RESET ROLE;
-- Mandatory audit failure must roll the real public append back completely.
CREATE FUNCTION pg_temp.reject_final_audit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.action='advance_locked_consumption' THEN RAISE EXCEPTION 'NONLEGAL mandatory audit failure' USING ERRCODE='55000';END IF;RETURN NEW;END$$;
CREATE TRIGGER nonlegal_final_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_final_audit();
SELECT set_config('test.audit_attempt',gen_random_uuid()::text,true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.audit_attempt')::uuid)$q$,'55000','NONLEGAL mandatory audit failure','public finalization rolls back when mandatory audit fails');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_contexts),0::bigint,'audit failure leaves no final output');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions),0::bigint,'audit failure leaves no consumed input');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE attempt_key=current_setting('test.audit_attempt')::uuid),0::bigint,'audit failure leaves no successful receipt');
SELECT is((SELECT status FROM payroll.runs WHERE id=(current_setting('test.run')::jsonb->>'id')::uuid),'approved','audit failure preserves approved lifecycle');
SELECT is(payroll.advance_balance('d4601000-0000-4000-8000-000000000001',current_setting('test.loan')::uuid),3000::numeric,'failed finalization leaves full loan balance');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE kind='payroll_deduction'),0::bigint,'audit failure rolls back loan ledger');
DROP TRIGGER nonlegal_final_audit_failure ON payroll.audit_events;
SET LOCAL ROLE authenticated;
SELECT set_config('test.final_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.final',public.payroll_run_finalize('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid)::text,true);
SELECT is(public.payroll_run_finalize('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid),current_setting('test.final')::jsonb,'exact public finalization replay returns original result');
SELECT is(public.payroll_run_finalization_reconcile('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid)->'result',current_setting('test.final')::jsonb,'public recovery returns committed receipt without calculating or consuming again');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_contexts),1::bigint,'one final output after replay and recovery');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions WHERE run_id=(current_setting('test.run')::jsonb->>'id')::uuid),3::bigint,'policy opening and context consumed once');
SELECT is(payroll.advance_balance('d4601000-0000-4000-8000-000000000001',current_setting('test.loan')::uuid),0::numeric,'actual public finalization consumes exact installment once');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE kind='payroll_deduction'),1::bigint,'finalization replay/recovery add no duplicate debt movement');
SELECT set_config('test.original_employee', (SELECT to_jsonb(e)::text FROM payroll.final_employees e WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),true);
SELECT set_config('test.source_changes',jsonb_build_array(jsonb_build_object('type','compensation','source_id','d4607000-0000-4000-8000-000000000001','expected_hash',payroll.source_hash((SELECT to_jsonb(c) FROM people.compensation_versions c WHERE id='d4607000-0000-4000-8000-000000000001')),'fields',jsonb_build_object('amount',33000)))::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,NULL,0,current_setting('test.source_changes')::jsonb,'[]',NULL,'NONLEGAL reviewed unpaid correction','NONLEGAL implementation reference',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.proposal',public.payroll_correction_proposal('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,NULL,0,current_setting('test.source_changes')::jsonb,'[]',NULL,'NONLEGAL reviewed unpaid correction','NONLEGAL implementation reference',current_setting('test.preview')::jsonb->>'preview_hash','save',gen_random_uuid())::text,true);
SELECT public.payroll_correction_command('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,1,'calculate','NONLEGAL amendment calculation',gen_random_uuid());
SELECT set_config('test.amendment_review',public.payroll_correction_workspace('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,(current_setting('test.proposal')::jsonb->>'case_id')::uuid,'compensation',NULL,NULL)::text,true);
SELECT is((current_setting('test.amendment_review')::jsonb->'amendments'->0->'summary'->>'gross')::numeric,33000::numeric,'actual authorized correction review displays replacement gross before approval');
SELECT is((current_setting('test.amendment_review')::jsonb->'amendments'->0->'summary'->>'net')::numeric,26700::numeric,'actual authorized correction review displays replacement net before approval');
SELECT is((current_setting('test.amendment_review')::jsonb->'amendments'->0->'review_employees'->0->>'net')::numeric,26700::numeric,'bounded employee explanation agrees with review summary');
SELECT throws_ok($q$SELECT public.payroll_correction_workspace('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,'compensation',NULL,NULL)$q$,'42501','payroll_forbidden','review projection cannot cross an invalid final-output scope');
SELECT public.payroll_correction_command('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,2,'approve','NONLEGAL proposal approval',gen_random_uuid());
RESET ROLE;
SELECT set_config('test.amendment',(SELECT jsonb_build_object('id',r.id,'candidate',r.candidate_id,'revision',r.revision)::text FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id WHERE m.case_id=(current_setting('test.proposal')::jsonb->>'case_id')::uuid),true);
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.amendment')::jsonb->>'candidate')::uuid),26700::numeric,'actual correction calculation uses new salary and tax');
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001','d460e000-0000-4000-8000-000000000001',(current_setting('test.amendment')::jsonb->>'id')::uuid,(current_setting('test.amendment')::jsonb->>'candidate')::uuid,(current_setting('test.amendment')::jsonb->>'revision')::integer,'approve','NONLEGAL amendment approval',gen_random_uuid());
SELECT set_config('test.batch_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.batch',public.payroll_correction_finalize('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,3,current_setting('test.batch_attempt')::uuid)::text,true);
SELECT is(public.payroll_correction_finalize('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,3,current_setting('test.batch_attempt')::uuid),current_setting('test.batch')::jsonb,'unpaid public batch replay returns original receipt');
SELECT is(public.payroll_correction_finalization_reconcile('d4601000-0000-4000-8000-000000000001','d4603000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,3,current_setting('test.batch_attempt')::uuid)->'result',current_setting('test.batch')::jsonb,'unpaid recovery returns committed original batch');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.output_successions),1::bigint,'one succession after batch replay and recovery');
SELECT is((SELECT count(*) FROM payroll.final_contexts),2::bigint,'one original and one authoritative replacement');
SELECT is((SELECT count(*) FROM payroll.correction_source_effects),1::bigint,'source effect applies once');
SELECT is((SELECT to_jsonb(e) FROM payroll.final_employees e WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),current_setting('test.original_employee')::jsonb,'original frozen explanation and money unchanged');
SELECT is((SELECT amount FROM people.compensation_versions WHERE id='d4607000-0000-4000-8000-000000000001'),33000::numeric,'governed source correction applied with replacement');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions),6::bigint,'each output owns exactly one frozen set');
SELECT is(payroll.advance_balance('d4601000-0000-4000-8000-000000000001',current_setting('test.loan')::uuid),0::numeric,'unpaid replacement compensates original and consumes replacement exactly once');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE kind='payroll_deduction'),2::bigint,'original and replacement debt deductions retained');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE kind='compensation'),1::bigint,'one immutable original debt compensation');
SELECT is((SELECT sum(delta) FROM payroll.advance_events WHERE advance_id=current_setting('test.loan')::uuid),0::numeric,'full loan ledger reconciles to zero');
SELECT * FROM finish();ROLLBACK;
