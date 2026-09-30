BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('e1100000-0000-4000-8000-000000000001','link-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('e1100000-0000-4000-8000-000000000002','link-viewer@example.test','hash',now(),'{}','{"full_name":"قارئ الموارد البشرية"}','authenticated','authenticated',now(),now()),
 ('e1100000-0000-4000-8000-000000000003','member@example.test','hash',now(),'{}','{"full_name":"عضو الفريق"}','authenticated','authenticated',now(),now()),
 ('e1100000-0000-4000-8000-000000000004','unverified@example.test','hash',NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e1100000-0000-4000-8000-000000000005','outside@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('e1100000-0000-4000-8000-000000000006','inactive@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('e2200000-0000-4000-8000-000000000001','Link One','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000002','Link Two','e1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('e2200000-0000-4000-8000-000000000001','e3300000-0000-4000-8000-000000000001','link.admin',1,ARRAY['tenant.administer']),
 ('e2200000-0000-4000-8000-000000000001','e3300000-0000-4000-8000-000000000002','link.viewer',1,ARRAY['people.view']),
 ('e2200000-0000-4000-8000-000000000001','e3300000-0000-4000-8000-000000000003','link.member',1,ARRAY['tenant.read']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000002','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000003','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000004','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000006','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000002','e1100000-0000-4000-8000-000000000005','e1100000-0000-4000-8000-000000000001');
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='e2200000-0000-4000-8000-000000000001' AND user_id='e1100000-0000-4000-8000-000000000006';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000001','e3300000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000002','e3300000-0000-4000-8000-000000000002'),
 ('e2200000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000003','e3300000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('e2200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','e1100000-0000-4000-8000-000000000001','Employee link test');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES
 ('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','LINK-EMP-1','موظف الربط الأول','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000002','LINK-EMP-2','موظف الربط الثاني','e1100000-0000-4000-8000-000000000001'),
 ('e2200000-0000-4000-8000-000000000002','e4400000-0000-4000-8000-000000000003','LINK-EMP-3','موظف شركة أخرى','e1100000-0000-4000-8000-000000000001');
UPDATE people.employees SET workforce_status='ended' WHERE tenant_id='e2200000-0000-4000-8000-000000000001'
  AND id='e4400000-0000-4000-8000-000000000001';

SELECT ok(NOT has_table_privilege('authenticated','people.employee_user_links','SELECT'),'link table is private');
SELECT ok(NOT has_table_privilege('authenticated','people.employee_user_link_audit_events','SELECT'),'link audit is private');
SELECT ok(NOT has_function_privilege('anon','public.link_people_employee_user(uuid,uuid,uuid)','EXECUTE'),'anonymous cannot link accounts');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000002',true);
SELECT is((public.people_employee_user_link_snapshot('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')->>'linked'),'false','people.view can read an unlinked status');
SELECT throws_ok($$SELECT public.people_employee_user_link_options('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','',1)$$,
 '42501','people_manage_forbidden','people.view does not grant link management');
SELECT throws_ok($$SELECT public.link_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000003')$$,
 '42501','people_manage_forbidden','people.view cannot create a link');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000001',true);
SELECT ok((public.people_employee_user_link_options('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','',1)->'items') @> '[{"user_id":"e1100000-0000-4000-8000-000000000003","email":"member@example.test","display_name":"عضو الفريق"}]'::jsonb,
 'eligible choices contain active verified same-Tenant memberships');
SELECT ok(NOT ((public.people_employee_user_link_options('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','',1)->'items') @> '[{"user_id":"e1100000-0000-4000-8000-000000000004"}]'::jsonb)
  AND NOT ((public.people_employee_user_link_options('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','',1)->'items') @> '[{"user_id":"e1100000-0000-4000-8000-000000000006"}]'::jsonb),
 'inactive memberships and unverified identities are excluded');
SELECT throws_ok($$SELECT public.link_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000004')$$,
 '23503','people_link_member_unavailable','unverified Auth identity cannot be linked');
SELECT throws_ok($$SELECT public.link_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000006')$$,
 '23503','people_link_member_unavailable','inactive Tenant Membership cannot be linked');
SELECT throws_ok($$SELECT public.link_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000005')$$,
 '23503','people_link_member_unavailable','same-user identity outside this Tenant cannot be linked');
SELECT ok(NOT ((public.people_employee_user_link_options('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','',1)->'items') @> '[{"user_id":"e1100000-0000-4000-8000-000000000005"}]'::jsonb),
 'members from another Tenant are not exposed');
SELECT is((public.link_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000003')->>'state'),
 'linked','manager links existing member to Employee');
SELECT is((public.people_employee_user_link_snapshot('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')->>'email'),
 'member@example.test','people.manage can see the linked identity');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000002',true);
SELECT ok((public.people_employee_user_link_snapshot('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')->>'linked')='true'
  AND (public.people_employee_user_link_snapshot('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')->>'identity_visible')='false'
  AND NOT ((public.people_employee_user_link_snapshot('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')) ? 'email')
  AND NOT ((public.people_employee_user_link_snapshot('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')) ? 'user_id'),
  'people.view can see linked status but receives no Auth identity');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.link_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000002','e1100000-0000-4000-8000-000000000003')$$,
 '23505','people_user_already_linked','a Tenant User cannot be linked to a second Employee');
SELECT throws_ok($$SELECT public.link_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001','e1100000-0000-4000-8000-000000000002')$$,
 '23505','people_employee_already_linked','an Employee cannot have a second active link');
SELECT throws_ok($$SELECT public.link_people_employee_user('e2200000-0000-4000-8000-000000000002','e4400000-0000-4000-8000-000000000003','e1100000-0000-4000-8000-000000000005')$$,
 '42501','people_manage_forbidden','linking is denied outside the authorized Tenant');
SELECT is((public.unlink_people_employee_user('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')->>'state'),
 'unlinked','manager can unlink without deleting either record');
SELECT is((public.people_employee_user_link_snapshot('e2200000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000001')->>'linked'),
 'false','unlink returns Employee to unlinked state');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles WHERE tenant_id='e2200000-0000-4000-8000-000000000001' AND user_id='e1100000-0000-4000-8000-000000000003'),
 1,'linking leaves membership roles unchanged');
SELECT is((SELECT count(*)::integer FROM people.employee_user_links WHERE tenant_id='e2200000-0000-4000-8000-000000000001' AND employee_id='e4400000-0000-4000-8000-000000000001'),
 1,'unlink retains the link episode as history');
SELECT is((SELECT count(*)::integer FROM people.employee_user_link_audit_events WHERE tenant_id='e2200000-0000-4000-8000-000000000001' AND actor_user_id='e1100000-0000-4000-8000-000000000001'),
  2,'link and unlink append actor audit events');
SELECT throws_ok($$UPDATE people.employee_user_link_audit_events SET details='{}'::jsonb
  WHERE tenant_id='e2200000-0000-4000-8000-000000000001'$$,
  '55000','people_employee_user_link_audit_append_only','link audit events cannot be edited');
SELECT is((SELECT workforce_status FROM people.employees WHERE tenant_id='e2200000-0000-4000-8000-000000000001'
  AND id='e4400000-0000-4000-8000-000000000001'),'ended','ended Employee identity remains available for account linking');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='e2200000-0000-4000-8000-000000000001' AND user_id='e1100000-0000-4000-8000-000000000003' AND access_state='active'),
 1,'unlink does not deactivate Tenant Membership');
SELECT * FROM finish();
ROLLBACK;
