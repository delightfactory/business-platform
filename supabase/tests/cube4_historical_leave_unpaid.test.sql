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
VALUES ('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001','d260d000-0000-4000-8000-000000000001','2025-01-05','2025-01-06','2025-01-07','UTC','D260 one-day NONLEGAL Leave QA',false,'d2600000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260','D260 calendar','2025-01-05',NULL,'{}'::smallint[],'[]'::jsonb,'NONLEGAL fixture','D260 source factory')::text,true);
SELECT set_config('test.year_period',public.leave_create_year_period('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,'2025-01-05','2025-01-06','D260 period','D260 source factory')::text,true);
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

-- First authenticated public payroll calculation: Leave ON, Time OFF.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.run1',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',NULL,0,'calculate','D260 actual Leave candidate',gen_random_uuid())::text,true);
RESET ROLE;

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


-- An independently admitted new day has no original Leave binding at all.
SELECT is((SELECT count(*) FROM payroll.final_source_bindings WHERE source_domain='leave' AND source_date='2025-01-06'),0::bigint,'new day starts without an original Leave binding');
SELECT set_config('test.binding_digest',(SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000002',true);
SELECT set_config('test.addition_request',public.leave_submit_own_request('d2601000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2025-01-06','2025-01-06',false,NULL,'New historical day without binding','historical-unpaid-submit')->>'id',true);
SELECT throws_ok($q$SELECT public.leave_approve_historical_request('d2601000-0000-4000-8000-000000000001',current_setting('test.addition_request')::uuid,1,1,'Self actor cannot admit historical source','historical-unauthorized')$q$,'42501','leave_forbidden','self requester cannot approve historical addition');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.historical_leave_admissions),0::bigint,'unauthorized request leaves no admission');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT throws_ok($q$SELECT public.leave_approve_historical_request('d2601000-0000-4000-8000-000000000002',current_setting('test.addition_request')::uuid,1,1,'Cross tenant attempt rejected','historical-wrong-tenant')$q$,'42501','leave_forbidden','historical admission denies cross tenant context');
SELECT throws_ok($q$SELECT public.leave_approve_historical_request('d2601000-0000-4000-8000-000000000001',current_setting('test.addition_request')::uuid,2,1,'Stale exact request rejected','historical-stale')$q$,'PT409','leave_request_version_conflict','historical admission retains exact request CAS');
RESET ROLE;
SELECT ok(NOT has_function_privilege('anon','public.leave_approve_historical_request(uuid,uuid,integer,integer,text,text)','EXECUTE'),'anonymous cannot call explicit admission');
SELECT ok(NOT has_table_privilege('authenticated','payroll.source_correction_observations','SELECT'),'private unified observations are not exposed as a data API');
SET LOCAL ROLE authenticated;
SELECT public.leave_approve_historical_request('d2601000-0000-4000-8000-000000000001',current_setting('test.addition_request')::uuid,1,1,'Explicit unpaid source addition','historical-unpaid-approve');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.historical_leave_observations),1::bigint,'new unbound day has its own observation and responsibility');
SELECT set_config('test.change',(SELECT jsonb_build_array(jsonb_build_object('type','source_change','source_id',id,'expected_hash',current_lineage_fingerprint,'fields','{}'::jsonb))::text FROM payroll.historical_leave_observations),true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,'[]',NULL,'Review unbound historical day','NONLEGAL source evidence',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.case',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,'[]',NULL,'Review unbound historical day','NONLEGAL source evidence',current_setting('test.preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id',true);
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,'calculate','Calculate actual unpaid replacement with added Leave day',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.amendment_runs),1::bigint,'unpaid addition creates actual existing amendment run');
SELECT set_config('test.amendment',(SELECT run_id::text FROM payroll.amendment_runs),true);
SELECT set_config('test.candidate',(SELECT candidate_id::text FROM payroll.runs WHERE id=current_setting('test.amendment')::uuid),true);
SELECT ok(EXISTS(SELECT 1 FROM payroll.candidates candidate CROSS JOIN LATERAL jsonb_array_elements(candidate.input_manifest->'optional_sources'->'leave'->'items') source WHERE candidate.id=current_setting('test.candidate')::uuid AND source->>'request_id'=current_setting('test.addition_request')),'actual amendment calculation captures the new Leave request');
SET LOCAL ROLE authenticated;
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,'approve','Approve exact source proposal only',gen_random_uuid());
SELECT throws_ok($q$SELECT public.payroll_candidate_approval('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',current_setting('test.amendment')::uuid,current_setting('test.candidate')::uuid,1,'approve','No synthetic financial qualification',gen_random_uuid())$q$,'23514','payroll_approval_blocked','unpaid addition cannot bypass real financial qualification');
SELECT throws_ok($q$SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'route_paid','Cannot turn unpaid amendment into paid settlement',gen_random_uuid())$q$,'23514','payroll_paid_correction_route_required','paid shortcut remains refused for wholly unpaid output');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.output_successions),0::bigint,'unqualified replacement publishes no succession');
SELECT is((SELECT count(*) FROM payroll.final_contexts),1::bigint,'unqualified replacement creates no final output');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding),current_setting('test.binding_digest'),'unbound addition never fabricates original bindings');
SELECT * FROM finish();
ROLLBACK;
