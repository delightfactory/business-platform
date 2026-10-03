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
VALUES ('d2600000-0000-4000-8000-000000000001','d260-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d2600000-0000-4000-8000-000000000002','d260-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d2601000-0000-4000-8000-000000000001','D260 Leave binding QA','d2600000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d2601000-0000-4000-8000-000000000001','d2602000-0000-4000-8000-000000000001','d260.payroll.leave',1,
 ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll_config.manage','leave.manage','leave.view','leave.approve']),
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
FROM unnest(ARRAY['hr.people','hr.payroll','hr.leave']) x;
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
SELECT set_config('test.calendar',public.leave_create_calendar('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260','D260 calendar','2025-01-05',NULL,'{}'::smallint[],'[]'::jsonb,'NONLEGAL fixture','D260 source factory')::text,true);
SELECT set_config('test.year_period',public.leave_create_year_period('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,'2025-01-05','2025-01-05','D260 period','D260 source factory')::text,true);
SELECT set_config('test.leave_type',public.leave_create_type('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260-paid-other','D260 paid other NONLEGAL','2025-01-05','paid','untracked',false,'NONLEGAL fixture','No statutory entitlement asserted','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.leave_type')::uuid AND version=1),true);

-- Actual public Leave submission and approval, retaining the canonical response.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000002',true);
SELECT set_config('test.request',public.leave_submit_own_request('d2601000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2025-01-05','2025-01-05',false,NULL,'D260 actual one-day Leave','d260-submit-001')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.approved',public.leave_approve_request('d2601000-0000-4000-8000-000000000001',current_setting('test.request')::uuid,1,1,'D260 actual Leave approval','d260-approve-001')::text,true);
RESET ROLE;
SELECT is(current_setting('test.approved')::jsonb->>'state','approved','public Leave approval is actual and approved');
SELECT is((current_setting('test.approved')::jsonb->>'approved_preview_version')::integer,1,'approval pins preview version one');
SELECT is((SELECT count(*)::integer FROM leave.request_days WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND request_id=current_setting('test.request')::uuid AND preview_version=1 AND leave_date='2025-01-05' AND units=1),1,'approved Leave has one canonical full-day date line');

-- First authenticated public payroll calculation: Leave ON, Time OFF.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.run1',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',NULL,0,'calculate','D260 actual Leave candidate',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT input_manifest->'optional'->>'time' FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid),'false','first candidate has Time capability OFF');
SELECT is((SELECT input_manifest->'optional_sources'->'leave'->'items'->0->>'request_id' FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid),current_setting('test.request'),'public candidate captures the approved Leave request identity');
SELECT is((SELECT input_manifest->'optional_sources'->'leave'->'items'->0->>'date' FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid),'2025-01-05','candidate captures the approved Leave date');
SELECT is((SELECT (input_manifest->'optional_sources'->'leave'->'items'->0->>'effective_units')::numeric FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid),1::numeric,'candidate captures one approved Leave unit');

-- Explicit NONLEGAL durable final context, matching candidate manifest/result.
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
SELECT tenant_id,'d260f000-0000-4000-8000-000000000001',employer_id,run_id,id,'approve',0,'d2600000-0000-4000-8000-000000000001','D260 NONLEGAL rollback binder fixture'
FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT tenant_id,'d2610000-0000-4000-8000-000000000001',employer_id,'d260e000-0000-4000-8000-000000000001',run_id,id,'d260f000-0000-4000-8000-000000000001','{"legal_name":"NONLEGAL"}',input_manifest->'period',input_manifest,output,'NONLEGAL_D260_BINDING','d2600000-0000-4000-8000-000000000001'
FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run1')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net)
VALUES ('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001','d2606000-0000-4000-8000-000000000001','{}','{}','{}',0);
SELECT payroll.insert_final_source_bindings('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001');
SELECT is((SELECT count(*)::integer FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND output_id='d2610000-0000-4000-8000-000000000001' AND source_domain='leave'),1,'durable binder stores one Leave dependency for the final Employee');
SELECT is((SELECT captured_payload->>'request_id' FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND output_id='d2610000-0000-4000-8000-000000000001' AND source_domain='leave'),current_setting('test.request'),'stored Leave binding preserves exact request identity');
SELECT is((SELECT (captured_payload->>'effective_units')::numeric FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND output_id='d2610000-0000-4000-8000-000000000001' AND source_domain='leave'),1::numeric,'stored Leave binding preserves exact approved payload');
SELECT is((SELECT dependency_lineage->'ledger_links' FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND output_id='d2610000-0000-4000-8000-000000000001' AND source_domain='leave'),'[]'::jsonb,'NONLEGAL untracked paid-other fixture has no balance ledger links');
SELECT is(jsonb_array_length(payroll.validate_final_source_currentness('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run1')::jsonb->>'id')::uuid,(current_setting('test.run1')::jsonb->>'candidate_id')::uuid)),1,'stored approved Leave candidate validates its exact current dependency');

-- Direct supported cancellation changes the current domain source, not the old
-- binding.  The old candidate must become stale and cannot be rewritten.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.cancelled',public.leave_cancel_approved_request('d2601000-0000-4000-8000-000000000001',current_setting('test.request')::uuid,2,'D260 direct actual cancellation','d260-direct-cancel-001')::text,true);
RESET ROLE;
SELECT is(current_setting('test.cancelled')::jsonb->>'state','cancelled','public direct Leave cancellation is actual and supported');
SELECT throws_ok($$SELECT payroll.validate_final_source_currentness('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run1')::jsonb->>'id')::uuid,(current_setting('test.run1')::jsonb->>'candidate_id')::uuid)$$,'PT409',NULL,'old approved Leave candidate is stale after cancellation');
SELECT is((SELECT captured_payload->>'state' FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND output_id='d2610000-0000-4000-8000-000000000001' AND source_domain='leave'),'approved','old durable approved binding is immutable after cancellation');

-- A fresh authenticated calculation captures the cancelled request as a new
-- dependency, with effective units zero and the actual cancellation event.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.run2',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run1')::jsonb->>'id')::uuid,(current_setting('test.run1')::jsonb->>'revision')::integer,'calculate','D260 cancelled Leave candidate',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT input_manifest->'optional_sources'->'leave'->'items'->0->>'state' FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run2')::jsonb->>'candidate_id')::uuid),'cancelled','new candidate captures cancelled Leave state');
SELECT is((SELECT (input_manifest->'optional_sources'->'leave'->'items'->0->>'effective_units')::numeric FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run2')::jsonb->>'candidate_id')::uuid),0::numeric,'cancelled Leave candidate captures effective units zero');
SELECT ok((SELECT input_manifest->'optional_sources'->'leave'->'items'->0->'cancellation'->>'event_id' IS NOT NULL FROM payroll.candidates WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=(current_setting('test.run2')::jsonb->>'candidate_id')::uuid),'new candidate carries the actual cancellation event lineage');
SELECT is(jsonb_array_length(payroll.validate_final_source_currentness('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run2')::jsonb->>'id')::uuid,(current_setting('test.run2')::jsonb->>'candidate_id')::uuid)),1,'current cancelled Leave dependency validates without rewriting history');

SELECT * FROM finish();
ROLLBACK;
