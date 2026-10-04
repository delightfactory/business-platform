BEGIN;
DO $$ BEGIN
  IF current_database() <> 'business_platform_cube4_adam_closure_qa' THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- One bounded, rollback-only NONLEGAL source fixture.  Time is deliberately
-- absent; this acceptance exercises only the actual Leave source lineage.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d2600000-0000-4000-8000-000000000001','d260-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d2600000-0000-4000-8000-000000000002','d260-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d2601000-0000-4000-8000-000000000001','D260 Leave binding QA','d2600000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d2601000-0000-4000-8000-000000000001','d2602000-0000-4000-8000-000000000001','d260.payroll.leave',1,
 ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','leave.manage','leave.view','leave.approve']),
       ('d2601000-0000-4000-8000-000000000001','d2602000-0000-4000-8000-000000000002','d260.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d2601000-0000-4000-8000-000000000001','d2600000-0000-4000-8000-000000000001','d2600000-0000-4000-8000-000000000001'),
       ('d2601000-0000-4000-8000-000000000001','d2600000-0000-4000-8000-000000000002','d2600000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d2601000-0000-4000-8000-000000000001','d2600000-0000-4000-8000-000000000001','d2602000-0000-4000-8000-000000000001'),
       ('d2601000-0000-4000-8000-000000000001','d2600000-0000-4000-8000-000000000002','d2602000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','D260 NONLEGAL Employer','D260 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd2601000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d2600000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d2601000-0000-4000-8000-000000000001','d2604000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','D260 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d2601000-0000-4000-8000-000000000001','d2605000-0000-4000-8000-000000000001','D260','D260 Leave Employee','d2600000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d2601000-0000-4000-8000-000000000001','d2606000-0000-4000-8000-000000000001','d2605000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','2025-01-05','active','daily');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d2601000-0000-4000-8000-000000000001','d2605000-0000-4000-8000-000000000001','d2600000-0000-4000-8000-000000000002','d2600000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d2601000-0000-4000-8000-000000000001','d2607000-0000-4000-8000-000000000001','d2606000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
VALUES ('d2601000-0000-4000-8000-000000000001','d2609000-0000-4000-8000-000000000001','d2606000-0000-4000-8000-000000000001','d2604000-0000-4000-8000-000000000001','2025-01-05');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2600000-0000-4000-8000-000000000001','D260 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001','d260d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','D260 one-day NONLEGAL Leave QA',false,'d2600000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);

-- Actual input/candidate commands; no privately seeded final or readiness flag.
SELECT public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2025-01-05',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted operational policy"}','save',gen_random_uuid());
SELECT set_config('test.units',public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','manual_units','d2606000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',NULL,0,'2025-01-05','2025-01-06','{"source":"manual","basis":"approved_payable_total","units":1,"reference":"NONLEGAL daily source","reason":"one reviewed operational unit"}','save',gen_random_uuid())::text,true);
SELECT public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','manual_units','d2606000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.units')::jsonb->>'id')::uuid,1,'2025-01-05','2025-01-06','{"source":"manual","basis":"approved_payable_total","units":1,"reference":"NONLEGAL daily source","reason":"one reviewed operational unit"}','approve',gen_random_uuid());
SELECT public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','opening_ytd','d2606000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-01-05',NULL,'{"year":2025,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2025-01-01","coverage_end":"2025-01-04","tax_duration_days":4,"reference":"NONLEGAL opening facts","reason":"reviewed zero opening source"}','save',gen_random_uuid());
SELECT set_config('test.context_data','{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL explicit exclusion and duration","reason":"reviewed source fact for numeric composition","calculation_from":"2025-01-05","calculation_until":"2025-01-05","tax_duration_days":1}',true);
SELECT set_config('test.context',public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','statutory_context','d2606000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-01-05',NULL,current_setting('test.context_data')::jsonb,'save',gen_random_uuid())::text,true);
SELECT set_config('test.run',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL no pack negative',gen_random_uuid())::text,true);
RESET ROLE;
CREATE FUNCTION pg_temp.pack(p_from date,p_until date) RETURNS uuid LANGUAGE plpgsql AS $$ DECLARE result uuid;BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
 VALUES('EG','egypt_payroll','NONLEGAL composition fixture',p_from,p_until,'["NONLEGAL source"]','{"numeric_comparisons":["NONLEGAL math only"]}','verified','d2600000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
 '{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}','{}',
 '{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}') RETURNING id INTO result;RETURN result;END $$;
SELECT pg_temp.pack('2024-01-01','2025-01-01');
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'calculate','NONLEGAL expired pack negative',gen_random_uuid())::text,true);
RESET ROLE;
SELECT set_config('test.tax_pack',pg_temp.pack('2025-01-01','2026-01-01')::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,2,'calculate','NONLEGAL bound general calculation',gen_random_uuid())::text,true);
RESET ROLE;
CREATE TEMP TABLE computed AS SELECT * FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;

SELECT is(payroll.public_candidate_readiness(jsonb_populate_record(NULL::payroll.candidates,to_jsonb(computed)))->>'ready','false','actual numeric producer does not qualify synthetic financial output') FROM computed;
SELECT is(payroll.public_candidate_readiness(jsonb_populate_record(NULL::payroll.candidates,to_jsonb(computed)))->'qualification_reasons','["financial_qualification_producer_required"]'::jsonb,'missing genuine financial producer is explicit') FROM computed;
SELECT is(payroll.public_candidate_readiness(jsonb_populate_record(NULL::payroll.candidates,to_jsonb(computed)||jsonb_build_object('output',output||'{"financially_qualified":true}'::jsonb)))->'qualification_reasons','["candidate_calculation_mismatch"]'::jsonb,'prescribed readiness flag cannot qualify a candidate') FROM computed;
-- Approved state is an explicit NONLEGAL prerequisite, not public approval.
INSERT INTO payroll.approval_events(tenant_id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
 SELECT tenant_id,employer_id,run_id,id,'approve',4,'d2600000-0000-4000-8000-000000000001','NONLEGAL approval state solely to test refusal' FROM computed;
UPDATE payroll.runs SET status='approved',revision=4,approval_id=(SELECT id FROM payroll.approval_events WHERE run_id=payroll.runs.id) WHERE id=(SELECT run_id FROM computed);
SELECT set_config('test.final_attempt',gen_random_uuid()::text,true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,4,(current_setting('test.final_attempt'))::uuid)$q$,'23514','payroll_financial_qualification_required','public finalization refuses approved but unqualified numeric candidate');
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000002','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,4,(current_setting('test.final_attempt'))::uuid)$q$,'42501','payroll_forbidden','wrong employer cannot finalize or inspect receipt');
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,NULL,(current_setting('test.final_attempt'))::uuid)$q$,'22023','payroll_invalid','missing expected revision is rejected');
SELECT is(public.payroll_run_finalization_reconcile('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,4,(current_setting('test.final_attempt'))::uuid)->>'outcome','closed_uncommitted','recovery durably fences the failed original attempt without finalizing');
SELECT is(public.payroll_run_finalization_reconcile('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,4,(current_setting('test.final_attempt'))::uuid)->>'outcome','closed_uncommitted','repeated recovery returns original closed outcome');
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,4,(current_setting('test.final_attempt'))::uuid)$q$,'PT409','payroll_attempt_closed','delayed writer cannot commit after recovery closes its attempt');
SELECT throws_ok($q$SELECT public.payroll_run_finalization_reconcile('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,(current_setting('test.final_attempt'))::uuid)$q$,'PT409','payroll_attempt_conflict','same attempt cannot be rebound to another revision');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.run_attempt_closures WHERE attempt_key=current_setting('test.final_attempt')::uuid),1::bigint,'one closure survives repeated recovery');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE attempt_key=current_setting('test.final_attempt')::uuid),0::bigint,'refused/fenced finalization has no commit receipt');
SELECT is((SELECT count(*) FROM payroll.final_contexts),0::bigint,'public refused/fenced finalization creates no financial output');
SELECT is((SELECT status FROM payroll.runs WHERE id=(SELECT run_id FROM computed)),'approved','failed finalization preserves approved state');
SELECT is((SELECT revision FROM payroll.runs WHERE id=(SELECT run_id FROM computed)),4,'failed finalization preserves revision');
SELECT is((SELECT output FROM payroll.candidates WHERE id=(SELECT id FROM computed)),(SELECT output FROM computed),'actual immutable candidate unchanged');
SELECT ok(NOT has_function_privilege('authenticated','payroll.finalize_run(uuid,uuid,uuid,uuid,uuid,integer,uuid)','EXECUTE'),'browser cannot invoke private finalization');
SELECT ok(has_function_privilege('authenticated','public.payroll_run_finalize(uuid,uuid,uuid,uuid,uuid,integer,uuid)','EXECUTE'),'public exact-context finalization boundary is callable');
SELECT * FROM finish();ROLLBACK;
