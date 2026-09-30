BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('f1000000-0000-4000-8000-000000000001','directory-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('f1000000-0000-4000-8000-000000000002','directory-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('f2000000-0000-4000-8000-000000000001','Directory Test One','f1000000-0000-4000-8000-000000000001'),
 ('f2000000-0000-4000-8000-000000000002','Directory Test Two','f1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','directory.admin',1,ARRAY['tenant.administer']),
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000002','directory.viewer',1,ARRAY['people.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001'),
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000002','f1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001'),
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000002','f3000000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('f2000000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute',
 'f1000000-0000-4000-8000-000000000001','People directory test');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
SELECT 'f2000000-0000-4000-8000-000000000001',
 ('f4000000-0000-4000-8000-' || pg_catalog.lpad(n::text,12,'0'))::uuid,
 'EMP-' || pg_catalog.lpad(n::text,2,'0'),
 CASE WHEN n=1 THEN 'Sample Worker' ELSE 'Worker ' || pg_catalog.lpad(n::text,2,'0') END,
 'f1000000-0000-4000-8000-000000000001'
FROM pg_catalog.generate_series(1,26) AS n;
UPDATE people.employees SET employee_code='EMP%24',full_name='Percent Query Worker'
WHERE tenant_id='f2000000-0000-4000-8000-000000000001' AND employee_code='EMP-24';
UPDATE people.employees SET employee_code='EMP_25',full_name='Underscore Query Worker'
WHERE tenant_id='f2000000-0000-4000-8000-000000000001' AND employee_code='EMP-25';
UPDATE people.employees SET employee_code=E'EMP\\26',full_name='Backslash Query Worker'
WHERE tenant_id='f2000000-0000-4000-8000-000000000001' AND employee_code='EMP-26';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000002',true);
SELECT is((public.people_directory_page('f2000000-0000-4000-8000-000000000001','Sample',1)->>'items')::jsonb->0->>'code',
 'EMP-01','search matches employee name');
SELECT is((public.people_directory_page('f2000000-0000-4000-8000-000000000001','sample',1)->'items'->0->>'code'),
 'EMP-01','search remains case insensitive');
SELECT is((public.people_directory_page('f2000000-0000-4000-8000-000000000001','EMP-01',1)->>'items')::jsonb->0->>'code',
 'EMP-01','search matches employee code');
SELECT is(pg_catalog.jsonb_array_length(public.people_directory_page('f2000000-0000-4000-8000-000000000001','%',1)->'items'),
 1,'percent is treated as a literal search character');
SELECT is((public.people_directory_page('f2000000-0000-4000-8000-000000000001','%',1)->'items'->0->>'code'),
 'EMP%24','literal percent search returns the matching employee');
SELECT is(pg_catalog.jsonb_array_length(public.people_directory_page('f2000000-0000-4000-8000-000000000001','_',1)->'items'),
 1,'underscore is treated as a literal search character');
SELECT is((public.people_directory_page('f2000000-0000-4000-8000-000000000001',E'\\',1)->'items'->0->>'code'),
 E'EMP\\26','backslash is treated as a literal search character');
SELECT is(pg_catalog.jsonb_array_length(public.people_directory_page('f2000000-0000-4000-8000-000000000001',NULL,1)->'items'),
 25,'page is capped at 25 employees');
SELECT is(public.people_directory_page('f2000000-0000-4000-8000-000000000001',NULL,1)->>'has_more','true',
 'first page reports more results');
SELECT is(pg_catalog.jsonb_array_length(public.people_directory_page('f2000000-0000-4000-8000-000000000001',NULL,2)->'items'),
 1,'second page returns remaining employee');
SELECT is((SELECT pg_catalog.count(DISTINCT item->>'id') FROM (
 SELECT pg_catalog.jsonb_array_elements(public.people_directory_page('f2000000-0000-4000-8000-000000000001',NULL,1)->'items') item
 UNION ALL
 SELECT pg_catalog.jsonb_array_elements(public.people_directory_page('f2000000-0000-4000-8000-000000000001',NULL,2)->'items') item
) pages),26::bigint,'adjacent pages preserve every employee exactly once');
SELECT ok(NOT ((public.people_directory_page('f2000000-0000-4000-8000-000000000001',NULL,1)->'items'->0) ? 'compensation'),
 'directory response contains no compensation field');
SELECT throws_ok($$SELECT public.people_directory_page('f2000000-0000-4000-8000-000000000001',NULL,1001)$$,
 '22023','people_directory_query_invalid','page number is capped');
SELECT throws_ok($$SELECT public.people_directory_page('f2000000-0000-4000-8000-000000000002',NULL,1)$$,
 '42501','people_view_forbidden','viewer cannot read another Tenant');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
