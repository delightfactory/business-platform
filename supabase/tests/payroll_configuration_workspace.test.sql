BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
('c8251000-0000-4000-8000-000000000001','readiness-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000002','readiness-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000003','readiness-outsider@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000004','readiness-channel@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000005','readiness-combined@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('c8250000-0000-4000-8000-000000000001','Readiness synthetic','c8251000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000001','readiness.admin',1,ARRAY['payroll_config.manage','payroll.view','tenant.administer','tenant.sites.manage','people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','attendance.view','attendance.manage'],false),
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000002','readiness.reader',1,ARRAY['payroll.view'],false),
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000003','readiness.channel',1,ARRAY['employee_finance.view'],false),
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000004','readiness.combined',1,ARRAY['payroll.prepare'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000001','active','c8251000-0000-4000-8000-000000000001'),
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000002','active','c8251000-0000-4000-8000-000000000001'),
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000004','active','c8251000-0000-4000-8000-000000000001'),
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000005','active','c8251000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000001'),
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000002','c8252000-0000-4000-8000-000000000002'),
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000004','c8252000-0000-4000-8000-000000000003'),
('c8250000-0000-4000-8000-000000000001','c8251000-0000-4000-8000-000000000005','c8252000-0000-4000-8000-000000000004');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
('c8250000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 day','c8251000-0000-4000-8000-000000000001','Synthetic'),
('c8250000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 day','c8251000-0000-4000-8000-000000000001','Synthetic');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES('c8250000-0000-4000-8000-000000000001','c8254000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001','Site',true,true);


INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES('c8250000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 day','c8251000-0000-4000-8000-000000000001','Synthetic');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002','Second employer',false);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('c8250000-0000-4000-8000-000000000002','Other company','c8251000-0000-4000-8000-000000000001');
SELECT ok(NOT has_function_privilege('anon','public.payroll_configuration_workspace(uuid,uuid,uuid,integer,uuid,text)','EXECUTE'),'anon has no config grant');
SELECT ok(NOT has_function_privilege('service_role','public.payroll_configuration_workspace(uuid,uuid,uuid,integer,uuid,text)','EXECUTE'),'service role has no config grant');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000001',true);
SELECT set_config('test.config_empty',public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')::text,true);
SELECT is(current_setting('test.config_empty')::jsonb->>'has_more','false','configuration loads without any payroll period');
SELECT ok(NOT(current_setting('test.config_empty')::jsonb ? 'employees'),'no employee projection');
SELECT ok(NOT(current_setting('test.config_empty')::jsonb ? 'period'),'no period scope');
DO $$ BEGIN FOR n IN 1..3 LOOP PERFORM public.payroll_save_input('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2026-01-01',NULL,jsonb_build_object('key','qa_setup_'||n,'name','QA Setup '||n,'classification','earning','calculation','fixed','base','','value','100','active',true,'taxable',false,'social',false,'visible',true,'order','10','behavior','period_input','proration','paid_full_period','reason','Synthetic configuration'),'save',gen_random_uuid()); END LOOP; END $$;
SELECT set_config('test.config_page',public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001',NULL,1)::text,true);
SELECT is(jsonb_array_length(current_setting('test.config_page')::jsonb->'components'),1,'component page bounded');
SELECT is(current_setting('test.config_page')::jsonb->>'has_more','true','has_more uses actual extra row');
SELECT set_config('test.all_components',public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')::text,true);
SELECT set_config('test.deep_head',current_setting('test.all_components')::jsonb->'components'->2->>'id',true);
SELECT is(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001',NULL,1,current_setting('test.deep_head')::uuid)->'selected'->>'id',current_setting('test.deep_head'),'direct head opens independently of first page');
SELECT throws_ok(format('SELECT public.payroll_configuration_workspace(%L,%L,NULL,30,%L)','c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002',current_setting('test.deep_head')),'P0002','payroll_configuration_missing','component head cannot cross employer');
SELECT is(jsonb_array_length(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001',NULL,30,NULL,'QA Setup 2')->'components'),1,'component search by name');
SELECT is(jsonb_array_length(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001',NULL,30,NULL,'%')->'components'),0,'search wildcards literal');
SELECT set_config('test.policy', (public.payroll_save_input('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2026-01-01',NULL,'{"mode":"fixed_30_day","reason":"Synthetic policy"}','save',gen_random_uuid())->>'id'),true);
SELECT is(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002')->'policy'->>'id',current_setting('test.policy'),'company policy visible from another employer');
SELECT is(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002',NULL,1,current_setting('test.policy')::uuid)->'selected'->>'id',current_setting('test.policy'),'policy deep link scoped to company');
SELECT throws_ok($$SELECT public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000002','c8253000-0000-4000-8000-000000000001')$$,'42501','payroll_forbidden','cross tenant denied');
SELECT throws_ok($$SELECT public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001',NULL,51)$$,'22023','payroll_invalid','oversized page denied');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000002',true);
SELECT is(jsonb_array_length(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')->'components'),3,'payroll reader sees config without manage');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')$$,'42501','payroll_forbidden','finance-only cannot read full configuration');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000005',true);
SELECT is(jsonb_array_length(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')->'components'),3,'payroll preparer retains prior read access');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')$$,'42501','payroll_forbidden','outsider denied');

-- Synthetic frozen history proves the new date guidance uses the same scope as
-- the current write guard. No money is calculated or finalized by this fixture.
RESET ROLE;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES('c8250000-0000-4000-8000-000000000001','c8254000-0000-4000-8000-000000000002','c8253000-0000-4000-8000-000000000002','Second site',false,true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employment_a',public.create_people_employee('c8250000-0000-4000-8000-000000000001','CFG-E1','Config synthetic A','c8253000-0000-4000-8000-000000000001','c8254000-0000-4000-8000-000000000001','2025-01-01','monthly',1000,true)->>'employment_id',true);
SELECT set_config('test.employment_b',public.create_people_employee('c8250000-0000-4000-8000-000000000001','CFG-E2','Config synthetic B','c8253000-0000-4000-8000-000000000002','c8254000-0000-4000-8000-000000000002','2025-01-01','monthly',1000,true)->>'employment_id',true);
RESET ROLE;
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES
('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001',1),('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,payment_day,payment_month,timezone,created_by,reason) VALUES
('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001','c8255000-0000-4000-8000-000000000001',1,'2025-01-01',1,'following','UTC','c8251000-0000-4000-8000-000000000001','Synthetic'),
('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002','c8255000-0000-4000-8000-000000000002',1,'2025-01-01',1,'following','UTC','c8251000-0000-4000-8000-000000000001','Synthetic');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES
('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001','c8256000-0000-4000-8000-000000000001','c8255000-0000-4000-8000-000000000001','2026-01-01','2026-01-31','2026-02-01','UTC','Synthetic January',false,'c8251000-0000-4000-8000-000000000001'),
('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002','c8256000-0000-4000-8000-000000000002','c8255000-0000-4000-8000-000000000002','2026-02-01','2026-02-28','2026-03-01','UTC','Synthetic February',false,'c8251000-0000-4000-8000-000000000001');
INSERT INTO payroll.people_frozen_contexts(tenant_id,employer_id,employment_id,period_id,run_id,source_snapshot) VALUES
('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001',current_setting('test.employment_a')::uuid,'c8256000-0000-4000-8000-000000000001',gen_random_uuid(),'{}'),
('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000002',current_setting('test.employment_b')::uuid,'c8256000-0000-4000-8000-000000000002',gen_random_uuid(),'{}');
SET LOCAL ROLE authenticated;
SELECT is(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')->>'component_open_ended_min','2026-02-01','component open-ended guidance scoped to employer history');
SELECT is(public.payroll_configuration_workspace('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001')->>'policy_open_ended_min','2026-03-01','company policy guidance includes other employers frozen history');
SELECT lives_ok($SQL$SELECT public.payroll_save_input('c8250000-0000-4000-8000-000000000001','c8253000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2025-12-01','2026-01-01',(current_setting('test.all_components')::jsonb->'components'->0->'data')||'{"key":"qa_gap","name":"Finite historical range"}'::jsonb,'save',gen_random_uuid())$SQL$,'finite range before frozen history remains a supported capability');

SELECT * FROM finish();
ROLLBACK;
