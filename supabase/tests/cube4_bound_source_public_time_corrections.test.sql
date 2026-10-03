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
VALUES('d2640000-0000-4000-8000-000000000001','final-binding@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('d2641000-0000-4000-8000-000000000001','Final binding QA','d2640000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES('d2641000-0000-4000-8000-000000000001','d2642000-0000-4000-8000-000000000001','final.binding.payroll',1,ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll_config.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('d2641000-0000-4000-8000-000000000001','d2640000-0000-4000-8000-000000000001','d2640000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('d2641000-0000-4000-8000-000000000001','d2640000-0000-4000-8000-000000000001','d2642000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES('d2641000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','Binding Employer','Binding Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) SELECT 'd2641000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d2640000-0000-4000-8000-000000000001','rollback binding QA' FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance'])x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d2641000-0000-4000-8000-000000000001','d2644000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','Binding Site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2641000-0000-4000-8000-000000000001','d2645000-0000-4000-8000-000000000001','D240','Binding Employee','d2640000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2641000-0000-4000-8000-000000000001','d2646000-0000-4000-8000-000000000001','d2645000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','2025-01-05','daily');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2641000-0000-4000-8000-000000000001','d2647000-0000-4000-8000-000000000001','d2646000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d2641000-0000-4000-8000-000000000001','d2648000-0000-4000-8000-000000000001','D240-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d2641000-0000-4000-8000-000000000001','d2648000-0000-4000-8000-000000000001',1,'D240 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d2640000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d2641000-0000-4000-8000-000000000001','d2649000-0000-4000-8000-000000000001','d2646000-0000-4000-8000-000000000001','d2644000-0000-4000-8000-000000000001','d2648000-0000-4000-8000-000000000001',1,'2025-01-05');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2641000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001','d2649000-0000-4000-8000-000000000001','d2646000-0000-4000-8000-000000000001','d2645000-0000-4000-8000-000000000001','d2644000-0000-4000-8000-000000000001','2025-01-05','d2648000-0000-4000-8000-000000000001',1,'UTC','2025-01-05 08:00+00','2025-01-05 16:00+00','2025-01-05 06:00+00','2025-01-05 22:00+00','approved','d2640000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2641000-0000-4000-8000-000000000001','d264b000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d2641000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001'),'d2640000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2641000-0000-4000-8000-000000000001','d264c000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001',1,'d264b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}', 'd2640000-0000-4000-8000-000000000001');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES('d2641000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES('d2641000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','d264d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2640000-0000-4000-8000-000000000001','rollback binding QA');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES('d2641000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','d264e000-0000-4000-8000-000000000001','d264d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','Binding one-day QA',false,'d2640000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','d2640000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2641000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','d264e000-0000-4000-8000-000000000001',NULL,0,'calculate','rollback binding QA',gen_random_uuid())::text,true);
RESET ROLE;


-- Explicit non-legal final context/employee fixture: this exercises only the
-- private durable protocol, never readiness or public finalization.
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason) SELECT tenant_id,'d264f000-0000-4000-8000-000000000001',employer_id,run_id,id,'approve',0,'d2640000-0000-4000-8000-000000000001','nonlegal rollback binding fixture' FROM payroll.candidates WHERE tenant_id='d2641000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by) SELECT tenant_id,'d2650000-0000-4000-8000-000000000001',employer_id,'d264e000-0000-4000-8000-000000000001',run_id,id,'d264f000-0000-4000-8000-000000000001','{"legal_name":"NONLEGAL"}',input_manifest->'period',input_manifest,output,'NONLEGAL_BINDING_FIXTURE','d2640000-0000-4000-8000-000000000001' FROM payroll.candidates WHERE tenant_id='d2641000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net) VALUES('d2641000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','d2650000-0000-4000-8000-000000000001','d2646000-0000-4000-8000-000000000001','{}','{}','{}',0);
SELECT payroll.insert_final_source_bindings('d2641000-0000-4000-8000-000000000001','d2643000-0000-4000-8000-000000000001','d264e000-0000-4000-8000-000000000001','d2650000-0000-4000-8000-000000000001');

-- Privileged NONLEGAL output/binding fixtures above do not qualify public
-- financial finalization. Only the Time mutation below uses the real public API.
-- Finish the original actor's deferred setup before testing a different actor.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO auth.users(id,email,aud,role,email_confirmed_at,created_at,updated_at) VALUES
('d2640000-0000-4000-8000-000000000002','payroll-only@test.invalid','authenticated','authenticated',now(),now(),now()),
('d2640000-0000-4000-8000-000000000003','time-only@test.invalid','authenticated','authenticated',now(),now(),now());
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) SELECT 'd2641000-0000-4000-8000-000000000001',id,'d2640000-0000-4000-8000-000000000001' FROM auth.users WHERE id IN('d2640000-0000-4000-8000-000000000002','d2640000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
('d2641000-0000-4000-8000-000000000001','d2642000-0000-4000-8000-000000000002','bound.payroll.only',1,ARRAY['payroll.view','payroll.correct']),
('d2641000-0000-4000-8000-000000000001','d2642000-0000-4000-8000-000000000003','bound.time.only',1,ARRAY['attendance.view','attendance.correct','attendance.approve']);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
('d2641000-0000-4000-8000-000000000001','d2640000-0000-4000-8000-000000000002','d2642000-0000-4000-8000-000000000002'),
('d2641000-0000-4000-8000-000000000001','d2640000-0000-4000-8000-000000000003','d2642000-0000-4000-8000-000000000003');
-- Seed only the upstream interpretation prerequisite. The approved fact is
-- appended by correct_attendance_absence under authenticated Time-only authority.
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,exception_code,input_fingerprint,created_by)
VALUES('d2641000-0000-4000-8000-000000000001','d264b000-0000-4000-8000-000000000002','d264a000-0000-4000-8000-000000000001',2,'needs_review','absence_candidate',time.work_instance_interpretation_fingerprint('d2641000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001'),'d2640000-0000-4000-8000-000000000003');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2640000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.correct_attendance_absence('d2641000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001','d264c000-0000-4000-8000-000000000001','Payroll-only must not change Time')$$,'42501','attendance_absence_correct_forbidden','Payroll correction authority cannot mutate a bound Time source');
SELECT set_config('request.jwt.claim.sub','d2640000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.correct_attendance_absence('d2641000-0000-4000-8000-000000000099','d264a000-0000-4000-8000-000000000001','d264c000-0000-4000-8000-000000000001','Wrong Tenant source correction')$$,'42501','attendance_absence_correct_forbidden','Time correction cannot cross Tenant authority');
SELECT set_config('test.public_time_result',public.correct_attendance_absence('d2641000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001','d264c000-0000-4000-8000-000000000001','Actual Time-only correction after NONLEGAL output binding')::text,true);
SELECT is(current_setting('test.public_time_result')::jsonb->>'state','approved_absence','Actual public Time correction succeeds without Payroll authority');
SELECT throws_ok($$SELECT public.correct_attendance_absence('d2641000-0000-4000-8000-000000000001','d264a000-0000-4000-8000-000000000001','d264c000-0000-4000-8000-000000000001','Replay exact old source correction')$$,'40001','attendance_fact_version_stale','Old correction replay cannot append another approved fact');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2641000-0000-4000-8000-000000000001'),1::bigint,'Deferred interpretation and public fact tails coalesce into one current observation');
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2641000-0000-4000-8000-000000000001'),1::bigint,'Public Time correction creates one explicit Payroll responsibility');
SELECT ok(EXISTS(SELECT 1 FROM payroll.bound_source_correction_observations WHERE tenant_id='d2641000-0000-4000-8000-000000000001' AND source_actor='d2640000-0000-4000-8000-000000000003' AND current_source_identity->>'fact_id'=current_setting('test.public_time_result')::jsonb->>'fact_id' AND current_source_version->>'fact_version'='2'),'Observation records the exact public successor and Time actor');
SELECT is((SELECT source_version->>'fact_version' FROM payroll.final_source_bindings WHERE tenant_id='d2641000-0000-4000-8000-000000000001'),'1','Original final source binding remains immutable');
SELECT is((SELECT count(*) FROM time.attendance_facts WHERE tenant_id='d2641000-0000-4000-8000-000000000001'),2::bigint,'Denied and stale attempts produce no additional Time facts');
SELECT is((SELECT count(*) FROM payroll.correction_cases WHERE tenant_id='d2641000-0000-4000-8000-000000000001'),0::bigint,'Source correction does not silently open a financial correction case');
SELECT is((SELECT count(*) FROM payroll.payment_events WHERE tenant_id='d2641000-0000-4000-8000-000000000001'),0::bigint,'Source correction never fabricates a payment');
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='d2641000-0000-4000-8000-000000000001'),'0.00','Original synthetic amount is preserved without guessing adjustment');
SELECT * FROM finish();
ROLLBACK;
