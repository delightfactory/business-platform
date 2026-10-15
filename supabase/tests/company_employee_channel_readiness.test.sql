BEGIN;
SELECT no_plan();
SELECT ok(NOT has_function_privilege('anon','public.people_employee_channel_readiness(uuid,uuid)','EXECUTE'),'anonymous cannot inspect employee setup');
SELECT ok(NOT has_function_privilege('service_role','public.people_employee_channel_readiness(uuid,uuid)','EXECUTE'),'service role has no direct execution grant');
SELECT is((SELECT provolatile::text FROM pg_proc WHERE oid='public.people_employee_channel_readiness(uuid,uuid)'::regprocedure),'s','readiness is a stable read');
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
('c8251000-0000-4000-8000-000000000001','readiness-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000002','readiness-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000003','readiness-outsider@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000004','readiness-channel@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
('c8251000-0000-4000-8000-000000000005','readiness-combined@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('c8250000-0000-4000-8000-000000000001','Readiness synthetic','c8251000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000001','readiness.admin',1,ARRAY['tenant.administer','tenant.sites.manage','people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','attendance.view','attendance.manage'],false),
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000002','readiness.reader',1,ARRAY['people.view'],false),
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000003','readiness.channel',1,ARRAY['attendance.view'],false),
('c8250000-0000-4000-8000-000000000001','c8252000-0000-4000-8000-000000000004','readiness.combined',1,ARRAY['attendance.view','people.view'],false);
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
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000001',true);
SELECT set_config('test.readiness_employee',public.create_people_employee('c8250000-0000-4000-8000-000000000001','READINESS-1','Synthetic employee','c8253000-0000-4000-8000-000000000001','c8254000-0000-4000-8000-000000000001',(now() AT TIME ZONE 'Africa/Cairo')::date-30,'monthly',1000,false)->>'employee_id',true);
SELECT is(public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)->>'state','missing','no mobile source is missing rather than ready');
SELECT set_config('test.readiness_future',public.create_people_employee('c8250000-0000-4000-8000-000000000001','READINESS-FUTURE','Scheduled employee','c8253000-0000-4000-8000-000000000001','c8254000-0000-4000-8000-000000000001',(now() AT TIME ZONE 'Africa/Cairo')::date+3,'monthly',1000,false)->>'employee_id',true);
SELECT is(public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_future')::uuid)->>'state','work-unavailable','scheduled work is not current capture setup');
SELECT set_config('test.readiness_source',public.attendance_channel_save_source('c8250000-0000-4000-8000-000000000001',NULL,'Mobile','mobile','c8254000-0000-4000-8000-000000000001',true,'{"geofence":false,"retention_seconds":300}','Synthetic setup')::text,true);
SELECT is(public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)->>'state','ready','same-site enabled valid configuration is ready');
SELECT ok(NOT(public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid) ?| ARRAY['config','latitude','longitude','employee_id']),'readiness does not expose hidden configuration or extra identity');
SELECT lives_ok($$SELECT public.attendance_channel_save_source('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_source')::uuid,'Mobile','mobile','c8254000-0000-4000-8000-000000000001',false,'{"geofence":false,"retention_seconds":300}','Synthetic disable')$$,'normal source update creates a disabled latest version');
SELECT is(public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)->>'state','disabled','latest disabled version is not ready');
SELECT throws_ok($$SELECT public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001','c8259000-0000-4000-8000-000000000001')$$,'P0002','people_employee_unavailable','missing or foreign employee cannot supply a site');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)$$,'42501','channel_forbidden','People reader without channel authority cannot inspect setup');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)$$,'42501','people_view_forbidden','channel viewer still requires People visibility');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000005',true);
SELECT is(public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)->>'state','disabled','combined read-only roles can inspect setup without management grants');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)$$,'42501','channel_forbidden','outsider is denied');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.manage_tenant_site('c8250000-0000-4000-8000-000000000001','deactivate','c8254000-0000-4000-8000-000000000001',NULL,NULL,'Synthetic inactive-site qualification')$$,'normal scoped site action disables the branch');
SELECT is(public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid)->>'state','site-inactive','inactive branch cannot be presented as ready');
RESET ROLE;
SELECT set_config('test.readiness_events',(SELECT count(*)::text FROM time.channel_events),true);
SELECT set_config('test.readiness_punches',(SELECT count(*)::text FROM time.manual_punches),true);
SET LOCAL ROLE authenticated;
SELECT public.people_employee_channel_readiness('c8250000-0000-4000-8000-000000000001',current_setting('test.readiness_employee')::uuid);
RESET ROLE;
SELECT is((SELECT count(*)::text FROM time.channel_events),current_setting('test.readiness_events'),'read creates no channel event');
SELECT is((SELECT count(*)::text FROM time.manual_punches),current_setting('test.readiness_punches'),'read creates no attendance punch');
SELECT * FROM finish();
ROLLBACK;
