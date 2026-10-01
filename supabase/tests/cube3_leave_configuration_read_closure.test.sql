BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e3910000-0000-4000-8000-000000000001','config-manage@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e3910000-0000-4000-8000-000000000002','config-approve@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e3910000-0000-4000-8000-000000000003','config-self@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e3920000-0000-4000-8000-000000000001','Configuration read tenant','e3910000-0000-4000-8000-000000000001'),
       ('e3920000-0000-4000-8000-000000000002','Other configuration tenant','e3910000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('e3920000-0000-4000-8000-000000000001','e3930000-0000-4000-8000-000000000001','config.manage',1,ARRAY['leave.manage'],false),
       ('e3920000-0000-4000-8000-000000000001','e3930000-0000-4000-8000-000000000002','config.approve',1,ARRAY['leave.approve'],false),
       ('e3920000-0000-4000-8000-000000000001','e3930000-0000-4000-8000-000000000003','config.self',1,ARRAY['leave.self.view'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('e3920000-0000-4000-8000-000000000001','e3910000-0000-4000-8000-000000000001','e3910000-0000-4000-8000-000000000001'),
       ('e3920000-0000-4000-8000-000000000001','e3910000-0000-4000-8000-000000000002','e3910000-0000-4000-8000-000000000001'),
       ('e3920000-0000-4000-8000-000000000001','e3910000-0000-4000-8000-000000000003','e3910000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e3920000-0000-4000-8000-000000000001','e3910000-0000-4000-8000-000000000001','e3930000-0000-4000-8000-000000000001'),
       ('e3920000-0000-4000-8000-000000000001','e3910000-0000-4000-8000-000000000002','e3930000-0000-4000-8000-000000000002'),
       ('e3920000-0000-4000-8000-000000000001','e3910000-0000-4000-8000-000000000003','e3930000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)
VALUES ('e3920000-0000-4000-8000-000000000001','e3940000-0000-4000-8000-000000000001','Config default',true,true),
       ('e3920000-0000-4000-8000-000000000001','e3940000-0000-4000-8000-000000000002','Historical Employer',false,false),
       ('e3920000-0000-4000-8000-000000000001','e3940000-0000-4000-8000-000000000003','Literal % Employer',false,true),
       ('e3920000-0000-4000-8000-000000000002','e3940000-0000-4000-8000-000000000004','Other tenant entity',true,true);
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)
SELECT 'e3920000-0000-4000-8000-000000000001',pg_catalog.md5('config-employer-'||g::text)::uuid,
  'Config Entity '||pg_catalog.lpad(g::text,3,'0'),false,true FROM pg_catalog.generate_series(1,101) g;

SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_legal_entities','SELECT'),'tenant entities are not directly readable');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_legal_entities','UPDATE'),'configuration reads do not grant an entity mutation path');
SELECT ok(has_function_privilege('authenticated','public.leave_configuration_employers(uuid,text,text,uuid,integer)','EXECUTE'),'authenticated HR can call the bounded entity selector');
SELECT ok(has_function_privilege('authenticated','public.leave_configuration_employer(uuid,uuid)','EXECUTE'),'authenticated HR can resolve a selected historical entity');
SELECT ok(NOT has_function_privilege('anon','public.leave_configuration_employer(uuid,uuid)','EXECUTE'),'anonymous users cannot resolve entities');
SELECT ok(NOT has_function_privilege('service_role','public.leave_configuration_employers(uuid,text,text,uuid,integer)','EXECUTE'),'service role cannot bypass the HR selector authorization');

-- No HR entitlements are seeded: historical configuration reads depend on active
-- actor authority, not new-work entitlement state.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3910000-0000-4000-8000-000000000001',true);
SELECT ok(jsonb_typeof(public.leave_configuration_snapshot('e3920000-0000-4000-8000-000000000001','e3940000-0000-4000-8000-000000000001'))='object',
 'leave.manage-only member can read configuration without leave.view');
SELECT set_config('test.page1',public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001','Config Entity',NULL,NULL,100)::text,true);
SELECT is(jsonb_array_length(current_setting('test.page1')::jsonb->'items'),100,'first page returns 100 matching legal entities');
SELECT ok((current_setting('test.page1')::jsonb->>'has_more')::boolean,'selector reports entities after the first page');
SELECT set_config('test.page2',public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001','Config Entity',
 current_setting('test.page1')::jsonb->>'next_after_name',(current_setting('test.page1')::jsonb->>'next_after_id')::uuid,100)::text,true);
SELECT is(jsonb_array_length(current_setting('test.page2')::jsonb->'items'),1,'second keyset page returns the 101st entity');
SELECT is((current_setting('test.page2')::jsonb->'items'->0->>'display_name'),'Config Entity 101','keyset resumes in name/id order without omission');
SELECT is((current_setting('test.page2')::jsonb->>'has_more')::boolean,false,'final keyset page has no further cursor');
SELECT set_config('test.literal',public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001','%',NULL,NULL,100)::text,true);
SELECT is(jsonb_array_length(current_setting('test.literal')::jsonb->'items'),1,'percent search character is treated literally rather than as a wildcard');
SELECT is(current_setting('test.literal')::jsonb->'items'->0->>'display_name','Literal % Employer','literal match returns the entity containing percent');
SELECT set_config('test.inactive',public.leave_configuration_employer('e3920000-0000-4000-8000-000000000001','e3940000-0000-4000-8000-000000000002')::text,true);
SELECT is((current_setting('test.inactive')::jsonb->>'is_active')::boolean,false,'exact entity lookup retains inactive historical entities');
SELECT set_config('test.inactive_list',public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001','Historical',NULL,NULL,10)::text,true);
SELECT is((current_setting('test.inactive_list')::jsonb->'items'->0->>'is_active')::boolean,false,'selector includes inactive references with explicit status');
SELECT throws_ok($q$SELECT public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001',repeat('x',121),NULL,NULL,10)$q$,
 '22023','leave_configuration_employers_input_invalid','search text above 120 characters is rejected');
SELECT throws_ok($q$SELECT public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001','',NULL,NULL,101)$q$,
 '22023','leave_configuration_employers_input_invalid','page sizes above 100 are rejected');
SELECT throws_ok($q$SELECT public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001','',NULL,'e3940000-0000-4000-8000-000000000001',10)$q$,
 '22023','leave_configuration_employers_input_invalid','cursor name and id must be supplied together');
SELECT throws_ok($q$SELECT public.leave_configuration_employer('e3920000-0000-4000-8000-000000000002','e3940000-0000-4000-8000-000000000004')$q$,
 '42501','leave_forbidden','tenant tampering is denied for exact employer lookup');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3910000-0000-4000-8000-000000000002',true);
SELECT ok(jsonb_typeof(public.leave_configuration_snapshot('e3920000-0000-4000-8000-000000000001','e3940000-0000-4000-8000-000000000001'))='object',
 'leave.approve-only member can read configuration without leave.view');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3910000-0000-4000-8000-000000000003',true);
SELECT throws_ok($q$SELECT public.leave_configuration_snapshot('e3920000-0000-4000-8000-000000000001','e3940000-0000-4000-8000-000000000001')$q$,
 '42501','leave_forbidden','self-only member cannot read HR configuration');
SELECT throws_ok($q$SELECT public.leave_configuration_employers('e3920000-0000-4000-8000-000000000001','',NULL,NULL,50)$q$,
 '42501','leave_forbidden','self-only member cannot enumerate tenant employers');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
