BEGIN;
DO $$ BEGIN
  IF current_database() <> 'business_platform_cube4_adam_positive_qa' THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- Isolated NONLEGAL complete-month insurance source/ownership acceptance.
-- The actual public producer and immutable consumption remain in use.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d4800000-0000-4000-8000-000000000001','d480-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d4800000-0000-4000-8000-000000000002','d480-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d4801000-0000-4000-8000-000000000001','NONLEGAL D480 Leave binding QA','d4800000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d4801000-0000-4000-8000-000000000001','d4802000-0000-4000-8000-000000000001','d480.payroll.leave',1,
 ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','payroll.review','payroll.export','payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','leave.manage','leave.view','leave.approve']),
       ('d4801000-0000-4000-8000-000000000001','d4802000-0000-4000-8000-000000000002','d480.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d4801000-0000-4000-8000-000000000001','d4800000-0000-4000-8000-000000000001','d4800000-0000-4000-8000-000000000001'),
       ('d4801000-0000-4000-8000-000000000001','d4800000-0000-4000-8000-000000000002','d4800000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d4801000-0000-4000-8000-000000000001','d4800000-0000-4000-8000-000000000001','d4802000-0000-4000-8000-000000000001'),
       ('d4801000-0000-4000-8000-000000000001','d4800000-0000-4000-8000-000000000002','d4802000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d4801000-0000-4000-8000-000000000001','d4803000-0000-4000-8000-000000000001','NONLEGAL D480 NONLEGAL Employer','NONLEGAL D480 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd4801000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d4800000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d4801000-0000-4000-8000-000000000001','d4804000-0000-4000-8000-000000000001','d4803000-0000-4000-8000-000000000001','NONLEGAL D480 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d4801000-0000-4000-8000-000000000001','d4805000-0000-4000-8000-000000000001','NONLEGAL D480','NONLEGAL D480 Leave Employee','d4800000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001','d4805000-0000-4000-8000-000000000001','d4803000-0000-4000-8000-000000000001','2026-07-01','active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d4801000-0000-4000-8000-000000000001','d4805000-0000-4000-8000-000000000001','d4800000-0000-4000-8000-000000000002','d4800000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d4801000-0000-4000-8000-000000000001','d4807000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',30000,'2026-07-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
VALUES ('d4801000-0000-4000-8000-000000000001','d4809000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001','d4804000-0000-4000-8000-000000000001','2026-07-01');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d4801000-0000-4000-8000-000000000001','d4803000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d4801000-0000-4000-8000-000000000001','d4803000-0000-4000-8000-000000000001','d480d000-0000-4000-8000-000000000001',1,'2026-07-01',NULL,31,'ending','UTC','d4800000-0000-4000-8000-000000000001','NONLEGAL D480 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d4801000-0000-4000-8000-000000000001','d4803000-0000-4000-8000-000000000001','d480e000-0000-4000-8000-000000000001','d480d000-0000-4000-8000-000000000001','2026-07-01','2026-07-31','2026-07-31','UTC','NONLEGAL D480 one-day NONLEGAL Leave QA',false,'d4800000-0000-4000-8000-000000000001');



UPDATE people.employments SET payroll_eligible=false WHERE id='d4806000-0000-4000-8000-000000000001';
SELECT ok(NOT has_function_privilege('anon','public.set_people_payroll_inclusion(uuid,uuid,text,boolean,uuid)','EXECUTE'),'anonymous cannot change payroll inclusion');
SELECT ok(NOT has_table_privilege('authenticated','people.payroll_inclusion_events','INSERT'),'audit receipts cannot be forged directly');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4800000-0000-4000-8000-000000000001',true);
SELECT set_config('test.inclusion.before',public.people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001')::text,true);
SELECT is(current_setting('test.inclusion.before')::jsonb->>'included','false','existing excluded employment is visible without being treated as missing');
SELECT is(current_setting('test.inclusion.before')::jsonb->>'can_manage','true','authorized company manager can configure inclusion');
SELECT set_config('test.inclusion.result',public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',current_setting('test.inclusion.before')::jsonb->>'stamp',true,'d4810000-0000-4000-8000-000000000001')::text,true);
SELECT is(current_setting('test.inclusion.result')::jsonb->>'included','true','real public command includes existing employee');
SELECT is(public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',current_setting('test.inclusion.before')::jsonb->>'stamp',true,'d4810000-0000-4000-8000-000000000001'),current_setting('test.inclusion.result')::jsonb,'retry recovers immutable receipt');
SELECT throws_ok($$SELECT public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',current_setting('test.inclusion.before')::jsonb->>'stamp',false,'d4810000-0000-4000-8000-000000000001')$$,'PT409','people_payroll_inclusion_attempt_conflict','same command cannot change intent');
SELECT throws_ok($$SELECT public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',current_setting('test.inclusion.before')::jsonb->>'stamp',false,gen_random_uuid())$$,'PT409','people_payroll_inclusion_stale','stale screen cannot overwrite new state');
SELECT throws_ok($$SELECT public.people_payroll_inclusion('d4801000-0000-4000-8000-000000000099','d4806000-0000-4000-8000-000000000001')$$,'42501','people_payroll_inclusion_forbidden','cross-tenant read is denied');
SELECT throws_ok($$SELECT public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000099','d4806000-0000-4000-8000-000000000001',repeat('0',32),true,gen_random_uuid())$$,'42501','people_payroll_inclusion_forbidden','cross-tenant write is denied');
SELECT set_config('test.inclusion.result',public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',current_setting('test.inclusion.result')::jsonb->>'stamp',false,gen_random_uuid())::text,true);
SELECT is(current_setting('test.inclusion.result')::jsonb->>'included','false','manager can remove inclusion before any frozen payroll');
SELECT throws_ok($$SELECT public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',current_setting('test.inclusion.before')::jsonb->>'stamp',true,gen_random_uuid())$$,'PT409','people_payroll_inclusion_stale','return to original boolean does not revive an old command stamp');
SELECT set_config('request.jwt.claim.sub','d4800000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.set_people_payroll_inclusion('d4801000-0000-4000-8000-000000000001','d4806000-0000-4000-8000-000000000001',repeat('0',32),true,gen_random_uuid())$$,'42501','people_payroll_inclusion_forbidden','ordinary employee cannot change employment eligibility');
RESET ROLE;
SELECT is((SELECT count(*) FROM people.payroll_inclusion_events WHERE tenant_id='d4801000-0000-4000-8000-000000000001'),2::bigint,'two deliberate changes create two audit receipts, retries and failed writes create none');
SELECT throws_ok($$UPDATE people.payroll_inclusion_events SET included=true WHERE tenant_id='d4801000-0000-4000-8000-000000000001'$$,'55000','people_audit_append_only','audit receipts are immutable');
SELECT is((SELECT amount FROM people.compensation_versions WHERE employment_id='d4806000-0000-4000-8000-000000000001'),30000::numeric,'inclusion changes preserve wages');
SELECT * FROM finish();ROLLBACK;
