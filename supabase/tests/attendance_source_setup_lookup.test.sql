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

SELECT ok(NOT has_function_privilege('anon','public.attendance_channel_mobile_site_lookup(uuid,text,integer,uuid)','EXECUTE'),'anonymous has no lookup grant');
SELECT ok(NOT has_function_privilege('service_role','public.attendance_channel_mobile_site_lookup(uuid,text,integer,uuid)','EXECUTE'),'service role has no lookup grant');
SELECT is((SELECT provolatile::text FROM pg_proc WHERE oid='public.attendance_channel_mobile_site_lookup(uuid,text,integer,uuid)'::regprocedure),'s','lookup is a stable read');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
SELECT 'c8250000-0000-4000-8000-000000000001',gen_random_uuid(),'c8253000-0000-4000-8000-000000000001','Setup site '||lpad(n::text,2,'0'),false,true FROM generate_series(1,24)n;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES
('c8250000-0000-4000-8000-000000000001','c8254000-0000-4000-8000-000000000002','c8253000-0000-4000-8000-000000000001','Literal_%\branch',false,true),
('c8250000-0000-4000-8000-000000000001','c8254000-0000-4000-8000-000000000003','c8253000-0000-4000-8000-000000000001','Inactive branch',false,false);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('c8250000-0000-4000-8000-000000000002','Other company','c8251000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000001',true);
SELECT set_config('test.setup_source',public.attendance_channel_save_source('c8250000-0000-4000-8000-000000000001',NULL,'Stopped source','mobile','c8254000-0000-4000-8000-000000000001',false,'{"geofence":false,"retention_seconds":86400}', 'Test stopped source')::text,true);
SELECT is(jsonb_array_length(public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001')->'items'),20,'site results bounded at20');
SELECT is(public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001')->>'has_more','true','more results signalled honestly');
SELECT set_config('test.lookup',public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001','',1,'c8254000-0000-4000-8000-000000000001')::text,true);
SELECT is(current_setting('test.lookup')::jsonb->'items'->0->'source'->>'id',current_setting('test.setup_source'),'exact site finds source beyond search page');
SELECT is(current_setting('test.lookup')::jsonb->'items'->0->'source'->>'enabled','false','stopped source still reported');
SELECT is(current_setting('test.lookup')::jsonb->>'has_more','false','exact one result not truncated');
SELECT is(jsonb_array_length(public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001','_%\')->'items'),1,'wildcards and escape are literal search characters');
SELECT is(jsonb_array_length(public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001','Inactive')->'items'),0,'inactive site excluded');
SELECT is(jsonb_array_length(public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001','',20,'c8254000-0000-4000-8000-999999999999')->'items'),0,'unknown or foreign site does not leak a row');
SELECT throws_ok($$SELECT public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000002')$$,'42501','channel_forbidden','cross tenant lookup denied');
SELECT throws_ok($$SELECT public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001','',21)$$,'22023','channel_page_invalid','oversized limit rejected');
SELECT throws_ok($$SELECT public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001',repeat('a',101))$$,'22023','channel_page_invalid','oversized search rejected');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001')$$,'42501','channel_forbidden','attendance reader cannot inspect setup');
SELECT set_config('request.jwt.claim.sub','c8251000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.attendance_channel_mobile_site_lookup('c8250000-0000-4000-8000-000000000001')$$,'42501','channel_forbidden','outsider denied');
SELECT * FROM finish();
ROLLBACK;
