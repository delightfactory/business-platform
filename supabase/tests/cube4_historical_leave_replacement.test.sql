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
VALUES ('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001','d2606000-0000-4000-8000-000000000001','{}','{}','{}',100);
SELECT payroll.insert_final_source_bindings('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001');

-- Direct supported cancellation changes the current domain source, not the old
-- binding.  The old candidate must become stale and cannot be rewritten.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.cancelled',public.leave_cancel_approved_request('d2601000-0000-4000-8000-000000000001',current_setting('test.request')::uuid,2,'D260 direct actual cancellation','d260-direct-cancel-001')::text,true);
RESET ROLE;


SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),1::bigint,'old public cancellation has one responsibility');
-- The starting final output is an explicit NONLEGAL seed, not a public lock.
-- Financial closure itself uses actual public payment/correction/settlement
-- commands. No privileged completed marker substitutes for that lifecycle.
SELECT set_config('test.cancel_requirement',(SELECT requirement_id::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
INSERT INTO payroll.correction_requirements(tenant_id,employer_id,id,employment_id,period_id,reason,requested_by)
VALUES('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260ff00-0000-4000-8000-000000000001','d2606000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001','Independent sibling responsibility','d2600000-0000-4000-8000-000000000001');
SELECT set_config('test.original_binding_digest',(SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.original_output_digest',(SELECT md5(jsonb_agg(to_jsonb(employee) ORDER BY employment_id)::text) FROM payroll.final_employees employee WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT public.payroll_record_payment('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',0,'allocations',CURRENT_DATE,'NONLEGAL initial payment','Actual public recorded-payment fixture','[{"employment_id":"d2606000-0000-4000-8000-000000000001","amount":"1"}]',NULL,true,gen_random_uuid());
RESET ROLE;
SELECT set_config('test.change',(SELECT jsonb_build_array(jsonb_build_object('type','source_change','source_id',id,'expected_hash',current_lineage_fingerprint,'fields','{}'::jsonb))::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.rows','[{"output_id":"d2610000-0000-4000-8000-000000000001","employment_id":"d2606000-0000-4000-8000-000000000001","basis":"external_reviewed","amount":"10","source":"NONLEGAL reviewed cancellation liability","reference":"NONLEGAL closure evidence"}]',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review actual cancelled Leave source','Closure source evidence',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.case',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review actual cancelled Leave source','Closure source evidence',current_setting('test.preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id',true);
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,'approve','Approve exact selected cancellation responsibility',gen_random_uuid());
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,'route_paid','Route reviewed external settlement',gen_random_uuid());
SELECT public.payroll_correction_settlement('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'d2606000-0000-4000-8000-000000000001','employee_extra_payment',10,CURRENT_DATE,'NONLEGAL actual closure evidence','Actual public evidence of reviewed settlement',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'completed','old cancellation liability is financially closed through public commands');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'=current_setting('test.cancel_requirement')),'completed exact cancellation no longer blocks the current manifest');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'='d260ff00-0000-4000-8000-000000000001'),'unselected sibling remains open after actual financial closure');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000002',true);
SET CONSTRAINTS ALL DEFERRED;
SELECT set_config('test.new_request',public.leave_submit_own_request('d2601000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2025-01-05','2025-01-05',false,NULL,'Different historical Leave request','closure-new-request')->>'id',true);
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT throws_ok($q$SELECT public.leave_approve_request('d2601000-0000-4000-8000-000000000001',current_setting('test.new_request')::uuid,1,1,'New request cannot borrow old binding','closure-new-approve')$q$,
 '23514','payroll_locked_leave_addition_requires_correction','different same-day request cannot borrow the cancelled binding');
RESET ROLE;
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=current_setting('test.new_request')::uuid),'submitted','refused new approval rolls back its state');
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),1::bigint,'refusal preserves old responsibility without creating false resolution');
SELECT is((SELECT source_identity->>'request_id' FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND source_domain='leave'),current_setting('test.request'),'original final binding is unchanged');
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'completed','new refusal does not reopen or reuse the completed cancellation case');
SELECT ok(NOT EXISTS(SELECT 1 FROM payroll.correction_request_links WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND request_id='d260ff00-0000-4000-8000-000000000001'),'new refusal does not link away the independent sibling');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_binding_digest'),'all original source binding bytes remain unchanged');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(employee) ORDER BY employment_id)::text) FROM payroll.final_employees employee WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_output_digest'),'original final employee output is unchanged');

-- Explicit public admission must connect to the actual existing correction UI
-- RPC/proposal/financial closure, not merely write an orphan requirement.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.historical_result',public.leave_approve_historical_request('d2601000-0000-4000-8000-000000000001',current_setting('test.new_request')::uuid,1,1,'Explicit historical payroll correction','historical-addition-approved')::text,true);
SELECT is(current_setting('test.historical_result')::jsonb->>'state','approved','explicit historical approval succeeds with Leave authority');
SELECT is(public.leave_approve_historical_request('d2601000-0000-4000-8000-000000000001',current_setting('test.new_request')::uuid,1,1,'Explicit historical payroll correction','historical-addition-approved'),current_setting('test.historical_result')::jsonb,'same explicit approval intent replays its original receipt');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.historical_leave_admissions),1::bigint,'one immutable admission');
SELECT is((SELECT count(*) FROM payroll.historical_leave_observations),1::bigint,'one factual observation, no duplicate on receipt replay');
SELECT set_config('test.addition_requirement',(SELECT requirement_id::text FROM payroll.historical_leave_observations),true);
SELECT set_config('test.addition_change',(SELECT jsonb_build_array(jsonb_build_object('type','source_change','source_id',id,'expected_hash',current_lineage_fingerprint,'fields','{}'::jsonb))::text FROM payroll.historical_leave_observations),true);
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'=current_setting('test.addition_requirement')),'new addition creates a blocking correction obligation');
SET LOCAL ROLE authenticated;
SELECT set_config('test.workspace',public.payroll_correction_workspace('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,'source_change',NULL,NULL)::text,true);
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.workspace')::jsonb->'sources') source WHERE source->>'id'=(current_setting('test.addition_change')::jsonb->0->>'source_id')),'existing correction UI RPC lists the historical addition');
SELECT set_config('test.addition_preview',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.addition_change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review exact historical addition','NONLEGAL addition liability',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.addition_case',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.addition_change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review exact historical addition','NONLEGAL addition liability',current_setting('test.addition_preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id',true);
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.addition_case')::uuid,1,'approve','Approve reviewed historical addition',gen_random_uuid());
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.addition_case')::uuid,2,'route_paid','Route externally reviewed addition',gen_random_uuid());
SELECT public.payroll_correction_settlement('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.addition_case')::uuid,3,'d2606000-0000-4000-8000-000000000001','employee_extra_payment',10,CURRENT_DATE,'NONLEGAL addition closure','Record actual reviewed settlement',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT status FROM payroll.correction_cases WHERE id=current_setting('test.addition_case')::uuid),'completed','paid historical addition closes through actual public financial route');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'=current_setting('test.addition_requirement')),'completed exact addition no longer blocks manifest');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'='d260ff00-0000-4000-8000-000000000001'),'independent sibling remains open after addition closure');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_binding_digest'),'addition creates no fake binding and preserves every original binding');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(employee) ORDER BY employment_id)::text) FROM payroll.final_employees employee WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_output_digest'),'addition preserves original money');

SET CONSTRAINTS ALL DEFERRED;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000002',true);
SELECT set_config('test.replacement',public.leave_submit_own_request('d2601000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2025-01-05','2025-01-05',false,NULL,'Replacement of admitted historical source','historical-replacement-submit')->>'id',true);
SELECT throws_ok($q$SELECT public.leave_correct_approved_request('d2601000-0000-4000-8000-000000000001',current_setting('test.new_request')::uuid,2,1,current_setting('test.replacement')::uuid,1,1,'Self actor cannot replace historical source','historical-replacement-denied')$q$,'42501','leave_forbidden','replacement retains Leave approval authority');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.replaced',public.leave_correct_approved_request('d2601000-0000-4000-8000-000000000001',current_setting('test.new_request')::uuid,2,1,current_setting('test.replacement')::uuid,1,1,'Explicit correction of admitted historical source','historical-replacement-approved')::text,true);
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is(current_setting('test.replaced')::jsonb->>'state','corrected','existing public replacement command succeeds for admitted historical source');
SELECT is((SELECT replacement_of::text FROM payroll.historical_leave_admissions WHERE request_id=current_setting('test.replacement')::uuid),current_setting('test.new_request'),'replacement carries exact admission predecessor');
SELECT is((SELECT count(*) FROM payroll.historical_leave_admissions),2::bigint,'one admission for each exact request, no synthetic binding');
SELECT is((SELECT count(*) FROM payroll.historical_leave_observations),3::bigint,'replacement records old supersession plus new addition without rewriting prior observation');
SELECT ok(NOT payroll.correction_requirement_is_current('d2601000-0000-4000-8000-000000000001',current_setting('test.addition_case')::uuid,current_setting('test.addition_requirement')::uuid),'old completed addition no longer resolves replaced lineage');
SET LOCAL ROLE authenticated;
SELECT is(public.leave_correct_approved_request('d2601000-0000-4000-8000-000000000001',current_setting('test.new_request')::uuid,2,1,current_setting('test.replacement')::uuid,1,1,'Explicit correction of admitted historical source','historical-replacement-approved'),current_setting('test.replaced')::jsonb,'replacement exact receipt replays after state transition');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.historical_leave_observations),3::bigint,'replacement receipt replay creates no duplicate responsibility');
SELECT set_config('test.replacement_changes',(SELECT jsonb_agg(jsonb_build_object('type','source_change','source_id',observation.id,'expected_hash',current_lineage_fingerprint,'fields','{}'::jsonb) ORDER BY source_key)::text FROM payroll.historical_leave_observations observation WHERE payroll.bound_source_envelope(tenant_id,'leave',source_date,(current_source_identity->>'request_id')::uuid)->>'fingerprint'=current_lineage_fingerprint),true);
SELECT is(jsonb_array_length(current_setting('test.replacement_changes')::jsonb),2,'only current predecessor and replacement observations are selected');
SET LOCAL ROLE authenticated;
SELECT set_config('test.replacement_preview',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.replacement_changes')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review both exact replacement sources','NONLEGAL shared reviewed liability',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.replacement_case',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.replacement_changes')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review both exact replacement sources','NONLEGAL shared reviewed liability',current_setting('test.replacement_preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id',true);
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.replacement_case')::uuid,1,'approve','Approve joined source responsibility',gen_random_uuid());
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.replacement_case')::uuid,2,'route_paid','Route paid joined source correction',gen_random_uuid());
SELECT public.payroll_correction_settlement('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.replacement_case')::uuid,3,'d2606000-0000-4000-8000-000000000001','employee_extra_payment',10,CURRENT_DATE,'NONLEGAL replacement closure','Record one externally reviewed replacement liability',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT status FROM payroll.correction_cases WHERE id=current_setting('test.replacement_case')::uuid),'completed','both replacement sources complete in one actual paid correction route');
SELECT is((SELECT count(*) FROM payroll.correction_request_links WHERE case_id=current_setting('test.replacement_case')::uuid),3::bigint,'latest predecessor covers its own prior obligation and exact replacement obligation');
SELECT is((SELECT amount FROM payroll.correction_settlements WHERE case_id=current_setting('test.replacement_case')::uuid),10::numeric,'shared output liability is not duplicated for two selected sources');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement JOIN payroll.historical_leave_observations observation ON observation.requirement_id::text=requirement->>'id'),'all selected replacement lineage obligations close');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'='d260ff00-0000-4000-8000-000000000001'),'independent sibling remains open after replacement settlement');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_binding_digest'),'replacement preserves every original source binding');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(employee) ORDER BY employment_id)::text) FROM payroll.final_employees employee WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_output_digest'),'replacement preserves original frozen employee money');
SELECT * FROM finish();
ROLLBACK;
