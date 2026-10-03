BEGIN;
DO $$ BEGIN
  IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- One bounded, rollback-only NONLEGAL source fixture.  Time is deliberately
-- absent; this acceptance exercises only the actual Leave source lineage.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d2720000-0000-4000-8000-000000000001','d272-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d2720000-0000-4000-8000-000000000002','d272-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d2721000-0000-4000-8000-000000000001','D260 Leave binding QA','d2720000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d2721000-0000-4000-8000-000000000001','d2722000-0000-4000-8000-000000000001','d272.payroll.leave',1,
 ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll_config.manage','leave.manage','leave.view','leave.approve']),
       ('d2721000-0000-4000-8000-000000000001','d2722000-0000-4000-8000-000000000002','d272.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d2721000-0000-4000-8000-000000000001','d2720000-0000-4000-8000-000000000001','d2720000-0000-4000-8000-000000000001'),
       ('d2721000-0000-4000-8000-000000000001','d2720000-0000-4000-8000-000000000002','d2720000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d2721000-0000-4000-8000-000000000001','d2720000-0000-4000-8000-000000000001','d2722000-0000-4000-8000-000000000001'),
       ('d2721000-0000-4000-8000-000000000001','d2720000-0000-4000-8000-000000000002','d2722000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','D260 NONLEGAL Employer','D260 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd2721000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d2720000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll','hr.leave']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d2721000-0000-4000-8000-000000000001','d2724000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','D260 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d2721000-0000-4000-8000-000000000001','d2725000-0000-4000-8000-000000000001','D260','D260 Leave Employee','d2720000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d2721000-0000-4000-8000-000000000001','d2726000-0000-4000-8000-000000000001','d2725000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','2025-01-05','active','daily');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d2721000-0000-4000-8000-000000000001','d2725000-0000-4000-8000-000000000001','d2720000-0000-4000-8000-000000000002','d2720000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d2721000-0000-4000-8000-000000000001','d2727000-0000-4000-8000-000000000001','d2726000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
VALUES ('d2721000-0000-4000-8000-000000000001','d2729000-0000-4000-8000-000000000001','d2726000-0000-4000-8000-000000000001','d2724000-0000-4000-8000-000000000001','2025-01-05');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','d272d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2720000-0000-4000-8000-000000000001','D260 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','d272e000-0000-4000-8000-000000000001','d272d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','D260 one-day NONLEGAL Leave QA',false,'d2720000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2720000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','d272','D260 calendar','2025-01-05',NULL,'{}'::smallint[],'[]'::jsonb,'NONLEGAL fixture','D260 source factory')::text,true);
SELECT set_config('test.year_period',public.leave_create_year_period('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,'2025-01-05','2025-01-05','D260 period','D260 source factory')::text,true);
SELECT set_config('test.leave_type',public.leave_create_type('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','d272-paid-other','D260 paid other NONLEGAL','2025-01-05','paid','untracked',false,'NONLEGAL fixture','No statutory entitlement asserted','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d2721000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.leave_type')::uuid AND version=1),true);

-- First authenticated public payroll calculation: Leave ON, Time OFF.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2720000-0000-4000-8000-000000000001',true);
SELECT set_config('test.run1',public.payroll_run_command('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','d272e000-0000-4000-8000-000000000001',NULL,0,'calculate','D260 actual Leave candidate',gen_random_uuid())::text,true);
RESET ROLE;

-- Explicit NONLEGAL durable final context, matching candidate manifest/result.
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
SELECT tenant_id,'d272f000-0000-4000-8000-000000000001',employer_id,run_id,id,'approve',0,'d2720000-0000-4000-8000-000000000001','D260 NONLEGAL rollback binder fixture'
FROM payroll.candidates WHERE tenant_id='d2721000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT tenant_id,'d2730000-0000-4000-8000-000000000001',employer_id,'d272e000-0000-4000-8000-000000000001',run_id,id,'d272f000-0000-4000-8000-000000000001','{"legal_name":"NONLEGAL"}',input_manifest->'period',input_manifest,output,'NONLEGAL_D260_BINDING','d2720000-0000-4000-8000-000000000001'
FROM payroll.candidates WHERE tenant_id='d2721000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net)
VALUES ('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','d2730000-0000-4000-8000-000000000001','d2726000-0000-4000-8000-000000000001','{}','{}','{}',0);
SELECT payroll.insert_final_source_bindings('d2721000-0000-4000-8000-000000000001','d2723000-0000-4000-8000-000000000001','d272e000-0000-4000-8000-000000000001','d2730000-0000-4000-8000-000000000001');

-- Actual public Leave submission and approval, retaining the canonical response.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2720000-0000-4000-8000-000000000002',true);
SELECT set_config('test.request',public.leave_submit_own_request('d2721000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2025-01-05','2025-01-05',false,NULL,'D260 actual one-day Leave','d272-submit-001')->>'id',true);
RESET ROLE;

CREATE FUNCTION pg_temp.approve_and_flush() RETURNS void LANGUAGE plpgsql AS $$BEGIN
 PERFORM public.leave_approve_request('d2721000-0000-4000-8000-000000000001',current_setting('test.request')::uuid,1,1,'Actual approval on previously unbound closed date','d272-unbound-approve-001');
 SET CONSTRAINTS ALL IMMEDIATE;
END$$;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2720000-0000-4000-8000-000000000001',true);
SELECT throws_ok('SELECT pg_temp.approve_and_flush()','23514','payroll_locked_leave_addition_requires_correction','actual public approval refuses unbound Leave addition inside closed original scope');
RESET ROLE;
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d2721000-0000-4000-8000-000000000001' AND id=current_setting('test.request')::uuid),'submitted','failed deferred approval keeps original submitted request');
SELECT is((SELECT count(*) FROM payroll.final_source_bindings WHERE tenant_id='d2721000-0000-4000-8000-000000000001'),0::bigint,'captured Leave-enabled output has no pre-existing Leave binding');
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2721000-0000-4000-8000-000000000001'),0::bigint,'refusal does not fabricate an untyped responsibility');
SELECT is((SELECT count(*) FROM payroll.payment_events WHERE tenant_id='d2721000-0000-4000-8000-000000000001'),0::bigint,'failed Leave approval introduces no payment');
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='d2721000-0000-4000-8000-000000000001'),'0.00','original NONLEGAL output remains unchanged');
-- One bounded, rollback-only NONLEGAL source fixture.  Time is deliberately
-- absent; this acceptance exercises only the actual Leave source lineage.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d2740000-0000-4000-8000-000000000001','d274-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d2740000-0000-4000-8000-000000000002','d274-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d2741000-0000-4000-8000-000000000001','D260 Leave binding QA','d2740000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d2741000-0000-4000-8000-000000000001','d2742000-0000-4000-8000-000000000001','d274.payroll.leave',1,
 ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll_config.manage','leave.manage','leave.view','leave.approve']),
       ('d2741000-0000-4000-8000-000000000001','d2742000-0000-4000-8000-000000000002','d274.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d2741000-0000-4000-8000-000000000001','d2740000-0000-4000-8000-000000000001','d2740000-0000-4000-8000-000000000001'),
       ('d2741000-0000-4000-8000-000000000001','d2740000-0000-4000-8000-000000000002','d2740000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d2741000-0000-4000-8000-000000000001','d2740000-0000-4000-8000-000000000001','d2742000-0000-4000-8000-000000000001'),
       ('d2741000-0000-4000-8000-000000000001','d2740000-0000-4000-8000-000000000002','d2742000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','D260 NONLEGAL Employer','D260 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd2741000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d2740000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll','hr.leave']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d2741000-0000-4000-8000-000000000001','d2744000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','D260 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d2741000-0000-4000-8000-000000000001','d2745000-0000-4000-8000-000000000001','D260','D260 Leave Employee','d2740000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d2741000-0000-4000-8000-000000000001','d2746000-0000-4000-8000-000000000001','d2745000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','2025-01-05','active','daily');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d2741000-0000-4000-8000-000000000001','d2745000-0000-4000-8000-000000000001','d2740000-0000-4000-8000-000000000002','d2740000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d2741000-0000-4000-8000-000000000001','d2747000-0000-4000-8000-000000000001','d2746000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
VALUES ('d2741000-0000-4000-8000-000000000001','d2749000-0000-4000-8000-000000000001','d2746000-0000-4000-8000-000000000001','d2744000-0000-4000-8000-000000000001','2025-01-05');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','d274d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2740000-0000-4000-8000-000000000001','D260 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','d274e000-0000-4000-8000-000000000001','d274d000-0000-4000-8000-000000000001','2025-01-06','2025-01-06','2025-01-07','UTC','D260 one-day NONLEGAL Leave QA',false,'d2740000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2740000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','d274','D260 calendar','2025-01-05',NULL,'{}'::smallint[],'[]'::jsonb,'NONLEGAL fixture','D260 source factory')::text,true);
SELECT set_config('test.year_period',public.leave_create_year_period('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,'2025-01-05','2025-01-05','D260 period','D260 source factory')::text,true);
SELECT set_config('test.leave_type',public.leave_create_type('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','d274-paid-other','D260 paid other NONLEGAL','2025-01-05','paid','untracked',false,'NONLEGAL fixture','No statutory entitlement asserted','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d2741000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.leave_type')::uuid AND version=1),true);

-- First authenticated public payroll calculation: Leave ON, Time OFF.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2740000-0000-4000-8000-000000000001',true);
SELECT set_config('test.run1',public.payroll_run_command('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','d274e000-0000-4000-8000-000000000001',NULL,0,'calculate','D260 actual Leave candidate',gen_random_uuid())::text,true);
RESET ROLE;

-- Explicit NONLEGAL durable final context, matching candidate manifest/result.
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
SELECT tenant_id,'d274f000-0000-4000-8000-000000000001',employer_id,run_id,id,'approve',0,'d2740000-0000-4000-8000-000000000001','D260 NONLEGAL rollback binder fixture'
FROM payroll.candidates WHERE tenant_id='d2741000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT tenant_id,'d2750000-0000-4000-8000-000000000001',employer_id,'d274e000-0000-4000-8000-000000000001',run_id,id,'d274f000-0000-4000-8000-000000000001','{"legal_name":"NONLEGAL"}',input_manifest->'period',input_manifest,output,'NONLEGAL_D260_BINDING','d2740000-0000-4000-8000-000000000001'
FROM payroll.candidates WHERE tenant_id='d2741000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net)
VALUES ('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','d2750000-0000-4000-8000-000000000001','d2746000-0000-4000-8000-000000000001','{}','{}','{}',0);
SELECT payroll.insert_final_source_bindings('d2741000-0000-4000-8000-000000000001','d2743000-0000-4000-8000-000000000001','d274e000-0000-4000-8000-000000000001','d2750000-0000-4000-8000-000000000001');

-- Actual public Leave submission and approval, retaining the canonical response.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2740000-0000-4000-8000-000000000002',true);
SELECT set_config('test.request',public.leave_submit_own_request('d2741000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2025-01-05','2025-01-05',false,NULL,'D260 actual one-day Leave','d274-submit-001')->>'id',true);
RESET ROLE;


SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
CREATE OR REPLACE FUNCTION pg_temp.approve_and_flush() RETURNS void LANGUAGE plpgsql AS $$BEGIN
 PERFORM public.leave_approve_request('d2741000-0000-4000-8000-000000000001',current_setting('test.request')::uuid,1,1,'Actual approval outside closed period','d274-outside-approve-001');
 SET CONSTRAINTS ALL IMMEDIATE;
END$$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2740000-0000-4000-8000-000000000001',true);
SELECT lives_ok('SELECT pg_temp.approve_and_flush()','ordinary public Leave approval outside the closed period is permitted');
RESET ROLE;
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d2741000-0000-4000-8000-000000000001' AND id=current_setting('test.request')::uuid),'approved','outside-period Leave approval completes successfully');
SELECT * FROM finish();
ROLLBACK;
