BEGIN;
DO $$ BEGIN
  IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'dedicated Cube4 QA required'; END IF;
END $$;
SELECT no_plan();

-- Actual one-day Source11-shaped fixture, deliberately non-legal.  It only
-- supplies a current Time fact and a candidate; it never makes approval/G6
-- ready and all work is rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('d2500000-0000-4000-8000-000000000001','final-binding@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('d2501000-0000-4000-8000-000000000001','Final binding QA','d2500000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES('d2501000-0000-4000-8000-000000000001','d2502000-0000-4000-8000-000000000001','final.binding.payroll',1,ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll_config.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('d2501000-0000-4000-8000-000000000001','d2500000-0000-4000-8000-000000000001','d2500000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('d2501000-0000-4000-8000-000000000001','d2500000-0000-4000-8000-000000000001','d2502000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','Binding Employer','Binding Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) SELECT 'd2501000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d2500000-0000-4000-8000-000000000001','rollback binding QA' FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance'])x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d2501000-0000-4000-8000-000000000001','d2504000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','Binding Site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2501000-0000-4000-8000-000000000001','d2505000-0000-4000-8000-000000000001','D240','Binding Employee','d2500000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2501000-0000-4000-8000-000000000001','d2506000-0000-4000-8000-000000000001','d2505000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','2025-01-05','daily');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2501000-0000-4000-8000-000000000001','d2507000-0000-4000-8000-000000000001','d2506000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d2501000-0000-4000-8000-000000000001','d2508000-0000-4000-8000-000000000001','D240-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d2501000-0000-4000-8000-000000000001','d2508000-0000-4000-8000-000000000001',1,'D240 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d2500000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d2501000-0000-4000-8000-000000000001','d2509000-0000-4000-8000-000000000001','d2506000-0000-4000-8000-000000000001','d2504000-0000-4000-8000-000000000001','d2508000-0000-4000-8000-000000000001',1,'2025-01-05');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2501000-0000-4000-8000-000000000001','d250a000-0000-4000-8000-000000000001','d2509000-0000-4000-8000-000000000001','d2506000-0000-4000-8000-000000000001','d2505000-0000-4000-8000-000000000001','d2504000-0000-4000-8000-000000000001','2025-01-05','d2508000-0000-4000-8000-000000000001',1,'UTC','2025-01-05 08:00+00','2025-01-05 16:00+00','2025-01-05 06:00+00','2025-01-05 22:00+00','approved','d2500000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2501000-0000-4000-8000-000000000001','d250b000-0000-4000-8000-000000000001','d250a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d2501000-0000-4000-8000-000000000001','d250a000-0000-4000-8000-000000000001'),'d2500000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2501000-0000-4000-8000-000000000001','d250c000-0000-4000-8000-000000000001','d250a000-0000-4000-8000-000000000001',1,'d250b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}', 'd2500000-0000-4000-8000-000000000001');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','d250d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2500000-0000-4000-8000-000000000001','rollback binding QA');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','d250e000-0000-4000-8000-000000000001','d250d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','Binding one-day QA',false,'d2500000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','d2500000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','d250e000-0000-4000-8000-000000000001',NULL,0,'calculate','rollback binding QA',gen_random_uuid())::text,true);
RESET ROLE;

-- Supplemental private binding checks. The runner prepends the same qualified
-- one-day source factory with a separate isolated tenant, without prior checks.
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
SELECT throws_ok($$SELECT payroll.validate_final_source_currentness('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','d250e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid)$$,'42501',NULL,'another actor cannot validate a stored payroll source');
SELECT set_config('request.jwt.claim.sub','d2500000-0000-4000-8000-000000000001',true);

-- Explicit NONLEGAL derivative tests output filtering of an otherwise real
-- canonical capture. It is not a public calculation or financial approval.
INSERT INTO payroll.candidates
SELECT (jsonb_populate_record(NULL::payroll.candidates,to_jsonb(c)||jsonb_build_object('id','d2511000-0000-4000-8000-000000000001','revision',c.revision+10000,'output',jsonb_set(c.output,'{employees}','[]'::jsonb)))).*
FROM payroll.candidates c WHERE tenant_id='d2501000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
SELECT is(payroll.validate_final_source_currentness('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','d250e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,'d2511000-0000-4000-8000-000000000001'),'[]'::jsonb,'a real captured employee omitted from output contributes no binding');

UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='d2501000-0000-4000-8000-000000000001' AND capability_key='hr.attendance';
SET LOCAL ROLE authenticated;
SELECT set_config('test.disabled_run',public.payroll_run_command('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','d250e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'revision')::integer,'calculate','rollback actual disabled binding case',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT input_manifest->'optional_sources'->'time'->'coverage' FROM payroll.candidates WHERE tenant_id='d2501000-0000-4000-8000-000000000001' AND id=(current_setting('test.disabled_run')::jsonb->>'candidate_id')::uuid),jsonb_build_object('contract','cube4-time-coverage-v1','enabled',false,'items','[]'::jsonb),'real disabled calculation stores canonical disabled coverage');
SELECT is(payroll.validate_final_source_currentness('d2501000-0000-4000-8000-000000000001','d2503000-0000-4000-8000-000000000001','d250e000-0000-4000-8000-000000000001',(current_setting('test.disabled_run')::jsonb->>'id')::uuid,(current_setting('test.disabled_run')::jsonb->>'candidate_id')::uuid),'[]'::jsonb,'whole-off stored candidate validates without source bindings');
SELECT * FROM finish();
ROLLBACK;
