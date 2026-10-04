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
SELECT is(payroll.issued_tax_qualification('d440f000-0000-4000-8000-000000000001','2026-07-01','2026-07-31')->>'ready','false','real production issuer rejects synthetic pack; no official evidence is fabricated');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000001',true);
SELECT public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2026-07-01',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted monthly policy"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','opening_ytd','d4406000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-07-01',NULL,'{"year":2026,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2026-01-01","coverage_end":"2026-06-30","tax_duration_days":0,"reference":"NONLEGAL no prior employment facts","reason":"Synthetic reviewed zero opening"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','statutory_context','d4406000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-07-01',NULL,'{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL reviewed uninsured exclusion","reason":"Synthetic source facts only","calculation_from":"2026-07-01","calculation_until":"2026-07-31","tax_duration_days":30}','save',gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL actual issuer negative',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'false','actual calculation remains legally closed without real issuer evidence');
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
SELECT is((SELECT (output->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),30000::numeric,'actual monthly gross calculated from dated compensation');
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),27000::numeric,'actual tax composition reconciles synthetic net');
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'true','actual profile producer qualifies only after simulated external evidence prerequisite');
SELECT is((SELECT output->'employees'->0->'financial_qualification'->'tax_evidence'->>'origin' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'synthetic_nonlegal','candidate retains explicit synthetic evidence boundary');
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,'approve','NONLEGAL implementation approval',gen_random_uuid());
RESET ROLE;
-- Mandatory audit failure must roll the real public append back completely.
CREATE FUNCTION pg_temp.reject_final_audit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.action='run_finalized' THEN RAISE EXCEPTION 'NONLEGAL mandatory audit failure' USING ERRCODE='55000';END IF;RETURN NEW;END$$;
CREATE TRIGGER nonlegal_final_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_final_audit();
SELECT set_config('test.audit_attempt',gen_random_uuid()::text,true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.audit_attempt')::uuid)$q$,'55000','NONLEGAL mandatory audit failure','public finalization rolls back when mandatory audit fails');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_contexts),0::bigint,'audit failure leaves no final output');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions),0::bigint,'audit failure leaves no consumed input');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE attempt_key=current_setting('test.audit_attempt')::uuid),0::bigint,'audit failure leaves no successful receipt');
SELECT is((SELECT status FROM payroll.runs WHERE id=(current_setting('test.run')::jsonb->>'id')::uuid),'approved','audit failure preserves approved lifecycle');
DROP TRIGGER nonlegal_final_audit_failure ON payroll.audit_events;
SET LOCAL ROLE authenticated;
SELECT set_config('test.final_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.final',public.payroll_run_finalize('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid)::text,true);
SELECT is(public.payroll_run_finalize('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid),current_setting('test.final')::jsonb,'exact public finalization replay returns original result');
SELECT is(public.payroll_run_finalization_reconcile('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','d440e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid)->'result',current_setting('test.final')::jsonb,'public recovery returns committed receipt without calculating or consuming again');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_contexts),1::bigint,'one final output after replay and recovery');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions WHERE run_id=(current_setting('test.run')::jsonb->>'id')::uuid),3::bigint,'policy opening and context consumed once');
SELECT set_config('test.original_employee', (SELECT to_jsonb(e)::text FROM payroll.final_employees e WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),true);

-- Reuse the actual qualified public producer above. Only the external issuer
-- supplier is NONLEGAL; no output, qualification flag or net is manufactured.
SELECT set_config('test.original_context',(SELECT to_jsonb(f)::text FROM payroll.final_contexts f WHERE id=(current_setting('test.final')::jsonb->>'output')::uuid),true);
SELECT set_config('test.next_preview',payroll.preview_dates('2026-08-01',NULL,31,'ending','UTC')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.payroll_record_payment('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,0,'allocations','2026-07-31','NONLEGAL actual payment1000','Independent external payment evidence','[{"employment_id":"d4406000-0000-4000-8000-000000000001","amount":"1000"}]',NULL,true,gen_random_uuid());
SELECT set_config('test.next_period',(public.payroll_generate_next_period('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',1,gen_random_uuid(),current_setting('test.next_preview')::jsonb)->>'period_id'),true);
SELECT set_config('test.link_component',(public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2026-08-01',NULL,'{"key":"linked_correction","name":"NONLEGAL reviewed linked responsibility","classification":"earning","calculation":"fixed","base":"","value":0,"taxable":false,"social":false,"visible":true,"active":true,"proration":"salary_proration","order":1,"behavior":"period_input","reason":"Independently reviewed responsibility100, not a calculated statutory delta"}','save',gen_random_uuid())->>'id'),true);
RESET ROLE;
SELECT set_config('test.changes',jsonb_build_array(jsonb_build_object('type','compensation','source_id','d4407000-0000-4000-8000-000000000001','expected_hash',payroll.source_hash((SELECT to_jsonb(c) FROM people.compensation_versions c WHERE id='d4407000-0000-4000-8000-000000000001')),'fields',jsonb_build_object('amount',33000)))::text,true);
SELECT set_config('test.rows',jsonb_build_array(jsonb_build_object('output_id',current_setting('test.final')::jsonb->>'output','employment_id','d4406000-0000-4000-8000-000000000001','amount',100,'basis','period_component','component_id',current_setting('test.link_component'),'target_period',current_setting('test.next_period'),'reference','NONLEGAL independently reviewed responsibility100','source','Manual reviewed100; explicitly not the computed salary or tax difference'))::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,NULL,0,current_setting('test.changes')::jsonb,current_setting('test.rows')::jsonb,NULL,'NONLEGAL paid correction with accountable future target','NONLEGAL reviewed source',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.case',(public.payroll_correction_proposal('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,NULL,0,current_setting('test.changes')::jsonb,current_setting('test.rows')::jsonb,NULL,'NONLEGAL paid correction with accountable future target','NONLEGAL reviewed source',current_setting('test.preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id'),true);
SELECT public.payroll_correction_command('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,'approve','NONLEGAL approved independent responsibility',gen_random_uuid());
SELECT public.payroll_correction_command('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,'route_paid','NONLEGAL future linked target',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT status FROM payroll.correction_cases WHERE id=current_setting('test.case')::uuid),'routed','approved future input leaves responsibility open until actual consumption');
SELECT is((SELECT count(*) FROM payroll.output_successions),0::bigint,'paid original never receives an unpaid replacement');
SELECT is((SELECT to_jsonb(f) FROM payroll.final_contexts f WHERE id=(current_setting('test.final')::jsonb->>'output')::uuid),current_setting('test.original_context')::jsonb,'paid frozen context preserved byte for byte');
SELECT set_config('test.target_head',(SELECT head_id::text FROM payroll.correction_targets WHERE case_id=current_setting('test.case')::uuid),true);
SELECT is((SELECT v.status FROM payroll.input_heads h JOIN payroll.input_versions v ON v.head_id=h.id AND v.revision=h.revision WHERE h.id=current_setting('test.target_head')::uuid),'approved','linked target is approved but not yet applied');
SELECT ok(NOT payroll.correction_responsibilities_complete('d4401000-0000-4000-8000-000000000001',(SELECT proposal_id FROM payroll.correction_cases WHERE id=current_setting('test.case')::uuid)),'approval alone cannot prove frozen target consumption');
SELECT ok(NOT has_function_privilege('authenticated','payroll.complete_consumed_correction_targets(uuid,uuid,uuid)','EXECUTE'),'ordinary callers cannot manufacture responsibility completion');
SELECT set_config('test.context_head',(SELECT id::text FROM payroll.input_heads WHERE kind='statutory_context'),true);
SET LOCAL ROLE authenticated;
SELECT public.payroll_save_input('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001','statutory_context','d4406000-0000-4000-8000-000000000001',NULL,current_setting('test.context_head')::uuid,1,'2026-08-01',NULL,'{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL reviewed next period source","reason":"Independent August legal duration facts","calculation_from":"2026-08-01","calculation_until":"2026-08-31","tax_duration_days":30}','save',gen_random_uuid());
SELECT set_config('test.next_run',public.payroll_run_command('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',current_setting('test.next_period')::uuid,NULL,0,'calculate','NONLEGAL real linked future calculation',gen_random_uuid())::text,true);
RESET ROLE;
SELECT output->'issues' AS next_issues FROM payroll.candidates WHERE id=(current_setting('test.next_run')::jsonb->>'candidate_id')::uuid;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.next_run')::jsonb->>'candidate_id')::uuid),'true','actual next-period producer qualifies reviewed linked earning without a flag override');
SELECT is((SELECT (output->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.next_run')::jsonb->>'candidate_id')::uuid),33100::numeric,'gross contains corrected salary33000 and linked responsibility100 once');
SELECT is((SELECT status FROM payroll.correction_cases WHERE id=current_setting('test.case')::uuid),'routed','calculation alone cannot close responsibility');
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',current_setting('test.next_period')::uuid,(current_setting('test.next_run')::jsonb->>'id')::uuid,(current_setting('test.next_run')::jsonb->>'candidate_id')::uuid,1,'approve','NONLEGAL reviewed target consumption',gen_random_uuid());
SELECT set_config('test.next_attempt',gen_random_uuid()::text,true);
RESET ROLE;
CREATE FUNCTION pg_temp.reject_target_audit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.action='correction_target_consumed' THEN RAISE EXCEPTION 'NONLEGAL target audit failed' USING ERRCODE='55000';END IF;RETURN NEW;END$$;
CREATE TRIGGER nonlegal_target_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_target_audit();
SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',current_setting('test.next_period')::uuid,(current_setting('test.next_run')::jsonb->>'id')::uuid,(current_setting('test.next_run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.next_attempt')::uuid)$q$,'55000','NONLEGAL target audit failed','completion audit failure rolls back final output, consumption and receipt together');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_contexts),1::bigint,'failed target completion leaves only the original qualified output');
SELECT is((SELECT status FROM payroll.correction_cases WHERE id=current_setting('test.case')::uuid),'routed','failed completion audit preserves routed responsibility');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE attempt_key=current_setting('test.next_attempt')::uuid),0::bigint,'failed completion has no successful finalization receipt');
DROP TRIGGER nonlegal_target_audit_failure ON payroll.audit_events;
SET LOCAL ROLE authenticated;
SELECT set_config('test.next_final',public.payroll_run_finalize('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',current_setting('test.next_period')::uuid,(current_setting('test.next_run')::jsonb->>'id')::uuid,(current_setting('test.next_run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.next_attempt')::uuid)::text,true);
SELECT is(public.payroll_run_finalize('d4401000-0000-4000-8000-000000000001','d4403000-0000-4000-8000-000000000001',current_setting('test.next_period')::uuid,(current_setting('test.next_run')::jsonb->>'id')::uuid,(current_setting('test.next_run')::jsonb->>'candidate_id')::uuid,2,current_setting('test.next_attempt')::uuid),current_setting('test.next_final')::jsonb,'same fixed attempt preserves the one target consumption receipt');
RESET ROLE;
SELECT is((SELECT status FROM payroll.correction_cases WHERE id=current_setting('test.case')::uuid),'completed','actual qualified future finalization closes the linked responsibility');
SELECT is((SELECT v.status FROM payroll.input_heads h JOIN payroll.input_versions v ON v.head_id=h.id AND v.revision=h.revision WHERE h.id=current_setting('test.target_head')::uuid),'applied','linked target consumed once');
SELECT is((SELECT count(*) FROM payroll.final_contexts),2::bigint,'exactly original paid and future qualified outputs');
SELECT is((SELECT to_jsonb(e) FROM payroll.final_employees e WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),current_setting('test.original_employee')::jsonb,'original paid explanation and amount remain immutable');
SELECT is((SELECT count(*) FROM payroll.payment_events),1::bigint,'target consumption creates no fictitious external salary payment');
SELECT is((SELECT count(*) FROM payroll.correction_events WHERE case_id=current_setting('test.case')::uuid AND operation='target_consumed'),1::bigint,'replay preserves exactly one mandatory completion event');
SELECT * FROM finish();ROLLBACK;
