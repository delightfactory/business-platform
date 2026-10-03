BEGIN;
SELECT no_plan();
-- NONLEGAL immutable output fixtures; source-observation acceptance only.
DO $$ BEGIN
  IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'dedicated Cube4 QA required'; END IF;
END $$;

-- Actual one-day Source11-shaped fixture, deliberately non-legal.  It only
-- supplies a current Time fact and a candidate; it never makes approval/G6
-- ready and all work is rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('d2400000-0000-4000-8000-000000000001','final-binding@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('d2401000-0000-4000-8000-000000000001','Final binding QA','d2400000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES('d2401000-0000-4000-8000-000000000001','d2402000-0000-4000-8000-000000000001','final.binding.payroll',1,ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll_config.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('d2401000-0000-4000-8000-000000000001','d2400000-0000-4000-8000-000000000001','d2400000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('d2401000-0000-4000-8000-000000000001','d2400000-0000-4000-8000-000000000001','d2402000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES('d2401000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','Binding Employer','Binding Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) SELECT 'd2401000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d2400000-0000-4000-8000-000000000001','rollback binding QA' FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance'])x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d2401000-0000-4000-8000-000000000001','d2404000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','Binding Site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2401000-0000-4000-8000-000000000001','d2405000-0000-4000-8000-000000000001','D240','Binding Employee','d2400000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2401000-0000-4000-8000-000000000001','d2406000-0000-4000-8000-000000000001','d2405000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','2025-01-05','daily');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2401000-0000-4000-8000-000000000001','d2407000-0000-4000-8000-000000000001','d2406000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d2401000-0000-4000-8000-000000000001','d2408000-0000-4000-8000-000000000001','D240-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d2401000-0000-4000-8000-000000000001','d2408000-0000-4000-8000-000000000001',1,'D240 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d2400000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d2401000-0000-4000-8000-000000000001','d2409000-0000-4000-8000-000000000001','d2406000-0000-4000-8000-000000000001','d2404000-0000-4000-8000-000000000001','d2408000-0000-4000-8000-000000000001',1,'2025-01-05');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2401000-0000-4000-8000-000000000001','d240a000-0000-4000-8000-000000000001','d2409000-0000-4000-8000-000000000001','d2406000-0000-4000-8000-000000000001','d2405000-0000-4000-8000-000000000001','d2404000-0000-4000-8000-000000000001','2025-01-05','d2408000-0000-4000-8000-000000000001',1,'UTC','2025-01-05 08:00+00','2025-01-05 16:00+00','2025-01-05 06:00+00','2025-01-05 22:00+00','approved','d2400000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2401000-0000-4000-8000-000000000001','d240b000-0000-4000-8000-000000000001','d240a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d2401000-0000-4000-8000-000000000001','d240a000-0000-4000-8000-000000000001'),'d2400000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2401000-0000-4000-8000-000000000001','d240c000-0000-4000-8000-000000000001','d240a000-0000-4000-8000-000000000001',1,'d240b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}', 'd2400000-0000-4000-8000-000000000001');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES('d2401000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES('d2401000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','d240d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2400000-0000-4000-8000-000000000001','rollback binding QA');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES('d2401000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','d240e000-0000-4000-8000-000000000001','d240d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','Binding one-day QA',false,'d2400000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','d2400000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2401000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','d240e000-0000-4000-8000-000000000001',NULL,0,'calculate','rollback binding QA',gen_random_uuid())::text,true);
RESET ROLE;


-- Explicit non-legal final context/employee fixture: this exercises only the
-- private durable protocol, never readiness or public finalization.
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason) SELECT tenant_id,'d240f000-0000-4000-8000-000000000001',employer_id,run_id,id,'approve',0,'d2400000-0000-4000-8000-000000000001','nonlegal rollback binding fixture' FROM payroll.candidates WHERE tenant_id='d2401000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by) SELECT tenant_id,'d2410000-0000-4000-8000-000000000001',employer_id,'d240e000-0000-4000-8000-000000000001',run_id,id,'d240f000-0000-4000-8000-000000000001','{"legal_name":"NONLEGAL"}',input_manifest->'period',input_manifest,output,'NONLEGAL_BINDING_FIXTURE','d2400000-0000-4000-8000-000000000001' FROM payroll.candidates WHERE tenant_id='d2401000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net) VALUES('d2401000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','d2410000-0000-4000-8000-000000000001','d2406000-0000-4000-8000-000000000001','{}','{}','{}',0);
SELECT payroll.insert_final_source_bindings('d2401000-0000-4000-8000-000000000001','d2403000-0000-4000-8000-000000000001','d240e000-0000-4000-8000-000000000001','d2410000-0000-4000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations),0::bigint,'unchanged Time command tail does not create a responsibility');
SELECT payroll.observe_time_work_instance('d2401000-0000-4000-8000-000000000001','d240a000-0000-4000-8000-000000000001','d2400000-0000-4000-8000-000000000001');
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2401000-0000-4000-8000-000000000001'),0::bigint,'unchanged private Time replay stays empty');
SET CONSTRAINTS ALL DEFERRED;
-- Privileged append exercises the real domain contract/trigger; it does not qualify public Time approval.
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id)
VALUES('d2401000-0000-4000-8000-000000000001','d240c000-0000-4000-8000-000000000002','d240a000-0000-4000-8000-000000000001',2,'d240b000-0000-4000-8000-000000000001','d240c000-0000-4000-8000-000000000001','NONLEGAL source correction','{"outcome":"worked","worked_minutes":360,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2400000-0000-4000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2401000-0000-4000-8000-000000000001'),1::bigint,'Time fact successor creates one exact bound observation');
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2401000-0000-4000-8000-000000000001'),1::bigint,'Time successor creates one linked responsibility');
SELECT is((SELECT current_source_version->>'fact_version' FROM payroll.bound_source_correction_observations WHERE tenant_id='d2401000-0000-4000-8000-000000000001'),'2','observation records successor version');
SELECT is((SELECT source_version->>'fact_version' FROM payroll.final_source_bindings WHERE tenant_id='d2401000-0000-4000-8000-000000000001'),'1','original Time binding stays immutable');
SELECT payroll.observe_time_work_instance('d2401000-0000-4000-8000-000000000001','d240a000-0000-4000-8000-000000000001','d2400000-0000-4000-8000-000000000001');
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2401000-0000-4000-8000-000000000001'),1::bigint,'exact source replay creates no extra responsibility');
SELECT payroll.observe_time_work_instance('d2401000-0000-4000-8000-000000000001',gen_random_uuid(),'d2400000-0000-4000-8000-000000000001');
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2401000-0000-4000-8000-000000000001'),1::bigint,'unrelated source identity has no effect');
SET CONSTRAINTS ALL DEFERRED;
DO $$ BEGIN
  IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;

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

-- Direct supported cancellation changes the current domain source, not the old
-- binding.  The old candidate must become stale and cannot be rewritten.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT set_config('test.cancelled',public.leave_cancel_approved_request('d2601000-0000-4000-8000-000000000001',current_setting('test.request')::uuid,2,'D260 direct actual cancellation','d260-direct-cancel-001')::text,true);
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),1::bigint,'actual public Leave cancellation creates bound observation');
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),1::bigint,'actual cancellation creates one responsibility');
SELECT is((SELECT current_source_lineage->>'effective_units' FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),'0','cancellation evidence retains zero current effective units');
SELECT ok((SELECT current_source_lineage->>'cancellation_event_id' IS NOT NULL FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),'cancellation evidence retains actual committed domain event');
SELECT is((SELECT captured_payload->>'state' FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),'approved','Leave binding stays approved and immutable');
SELECT ok(NOT has_table_privilege('authenticated','payroll.bound_source_correction_observations','SELECT,INSERT,UPDATE,DELETE'),'API cannot read or mutate private source evidence');
SELECT ok(NOT has_function_privilege('authenticated','payroll.observe_time_work_instance(uuid,uuid,uuid)','EXECUTE'),'API cannot invoke trusted observer');
SELECT is((SELECT count(*) FROM payroll.payment_events WHERE tenant_id IN('d2401000-0000-4000-8000-000000000001','d2601000-0000-4000-8000-000000000001')),0::bigint,'source observations create no payment');
SELECT is((SELECT count(*) FROM payroll.correction_cases WHERE tenant_id IN('d2401000-0000-4000-8000-000000000001','d2601000-0000-4000-8000-000000000001')),0::bigint,'no correction case or monetary decision is created automatically');
SELECT * FROM finish();
ROLLBACK;
