BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('ce100000-0000-4000-8000-000000000001','leave-self@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('ce100000-0000-4000-8000-000000000002','leave-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('ce200000-0000-4000-8000-000000000001','Leave self test','ce100000-0000-4000-8000-000000000001'),
 ('ce200000-0000-4000-8000-000000000002','Leave other tenant','ce100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('ce200000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000001','employee.leave.self.v1',1,
 ARRAY['people.self.view','leave.self.view','leave.self.request'],false),
 ('ce200000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000002','test.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage'],true),
 ('ce200000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000003','test.members_manager.v1',1,ARRAY['tenant.members.manage','people.manage'],false),
 ('ce200000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000004','test.leave.self.only.v1',1,ARRAY['leave.self.view'],false),
 ('ce200000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000005','test.people.self.only.v1',1,ARRAY['people.self.view'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000002','ce100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000002','ce300000-0000-4000-8000-000000000002');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000003');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000001','SELF-1','ملف اختبار الخدمة الذاتية','ce100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('ce200000-0000-4000-8000-000000000001','ce500000-0000-4000-8000-000000000001','جهة اختبار الخدمة الذاتية',true);
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('ce200000-0000-4000-8000-000000000001','ce600000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000001',
 'ce500000-0000-4000-8000-000000000001',CURRENT_DATE-1,'active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000002','SELF-ADMIN','مسؤول اختبار الخدمة الذاتية','ce100000-0000-4000-8000-000000000001');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000003','SELF-3','ملف الخدمة الذاتية الجديد','ce100000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('ce200000-0000-4000-8000-000000000001','ce600000-0000-4000-8000-000000000002','ce400000-0000-4000-8000-000000000002',
 'ce500000-0000-4000-8000-000000000001',CURRENT_DATE+7,'active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('ce200000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000002','ce100000-0000-4000-8000-000000000002','ce100000-0000-4000-8000-000000000001');

SELECT has_function('public','tenant_my_employee_snapshot',ARRAY['uuid']::name[],'minimal own-profile RPC exists');
SELECT ok(has_function_privilege('authenticated','public.tenant_my_employee_snapshot(uuid)','EXECUTE'),'authenticated can invoke own-profile RPC');
SELECT ok(NOT has_function_privilege('anon','public.tenant_my_employee_snapshot(uuid)','EXECUTE'),'anonymous cannot invoke own-profile RPC');
SELECT ok(NOT has_table_privilege('authenticated','people.employee_user_links','SELECT'),'employee identity links remain private');
SELECT ok(NOT has_table_privilege('authenticated','people.employees','SELECT'),'employee records remain private');
SELECT ok(NOT has_function_privilege('authenticated','platform_private.has_leave_self_permission(uuid,uuid,text)','EXECUTE'),'private leave self permission helper is not exposed');
SELECT has_function('public','set_tenant_member_leave_self_access',ARRAY['uuid','uuid','boolean']::name[],'protected-admin self-access command exists');
SELECT ok(NOT has_function_privilege('anon','public.set_tenant_member_leave_self_access(uuid,uuid,boolean)','EXECUTE'),'anonymous cannot grant protected-admin self access');
SELECT is((SELECT count(*)::integer FROM platform_private.people_role_bundle_catalog()),14,'catalog retains nine fixed bundles and appends five leave bundles');
SELECT is((SELECT permission_snapshot FROM platform_private.people_role_bundle_catalog() WHERE role_key='people.compensation_manager.v1'),
 ARRAY['people.view','compensation.view','compensation.manage']::text[],'existing compensation bundle snapshot is unchanged');
SELECT is((SELECT permission_snapshot FROM platform_private.people_role_bundle_catalog() WHERE role_key='employee.leave.self.v1'),
 ARRAY['people.self.view','leave.self.view','leave.self.request']::text[],'employee bundle is narrow and does not grant directory or pay access');
SELECT ok(NOT EXISTS (SELECT 1 FROM unnest((SELECT permission_snapshot FROM platform_private.people_role_bundle_catalog() WHERE role_key='employee.leave.self.v1')) AS permission WHERE permission='people.view'),
 'self-service bundle excludes broad employee directory permission');
SELECT ok(NOT EXISTS (SELECT 1 FROM unnest((SELECT permission_snapshot FROM platform_private.people_role_bundle_catalog() WHERE role_key='employee.leave.self.v1')) AS permission WHERE permission='compensation.view'),
 'self-service bundle excludes compensation permission');

INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('ce200000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','ce100000-0000-4000-8000-000000000001','Leave dependency test');
SELECT ok(NOT platform_private.tenant_capability_is_enabled('ce200000-0000-4000-8000-000000000001','hr.leave',now()),
 'Leave is not enabled without effective People entitlement');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('ce200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','ce100000-0000-4000-8000-000000000001','Leave dependency test');
SELECT ok(platform_private.tenant_capability_is_enabled('ce200000-0000-4000-8000-000000000001','hr.leave',now()),
 'effective People plus Leave enables Leave without Attendance');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'employee_code','SELF-1',
 'own profile resolves the linked employee without an employee id argument');
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'new_work_enabled','true',
 'new work is enabled only when both People and Leave are enabled');
SELECT ok(NOT (public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001') ?| ARRAY['salary','compensation','phone','email','legal_id','internal_notes']),
 'own profile excludes compensation and sensitive personal fields');
SELECT is(public.set_tenant_member_leave_self_access('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000002',true)->>'state','updated',
 'member manager grants only the self-service bundle to a protected admin');
RESET ROLE;
SELECT ok(platform_private.has_leave_self_permission('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000002','leave.self.view'),
 'protected admin with explicit self bundle receives own self permission');
SELECT ok(platform_private.has_tenant_permission('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000002','tenant.administer'),
 'adding self access preserves protected-admin permissions');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000002',true);
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'employee_code','SELF-ADMIN',
 'linked protected admin can view only the own employee profile after explicit self grant');
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'employment_start_date',NULL,
 'future employment is not surfaced as current own employment context');
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000002')$$,
 '42501','leave_self_profile_forbidden','active membership in another tenant is required for cross-tenant profile reads');
RESET ROLE;
DELETE FROM platform_core.membership_roles WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND user_id='ce100000-0000-4000-8000-000000000001' AND role_id='ce300000-0000-4000-8000-000000000001';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000004');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')$$,
 '42501','leave_self_profile_forbidden','leave self view without people self view is denied');
RESET ROLE;
DELETE FROM platform_core.membership_roles WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND user_id='ce100000-0000-4000-8000-000000000001' AND role_id='ce300000-0000-4000-8000-000000000004';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000005');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')$$,
 '42501','leave_self_profile_forbidden','people self view without leave self view is denied');
RESET ROLE;
DELETE FROM platform_core.membership_roles WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND user_id='ce100000-0000-4000-8000-000000000001' AND role_id='ce300000-0000-4000-8000-000000000005';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001','ce300000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT is(public.set_tenant_member_leave_self_access('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000002',false)->>'state','updated',
 'member manager can revoke the narrow protected-admin self bundle');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND subject_user_id='ce100000-0000-4000-8000-000000000002' AND action='leave_self_access_changed'),2,
 'protected-admin self-access grant and revoke append audit events');
SELECT ok(NOT platform_private.has_leave_self_permission('ce200000-0000-4000-8000-000000000002','ce100000-0000-4000-8000-000000000002','leave.self.view'),
 'protected-admin self-service permission does not cross tenant boundaries');
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000099')$$,
 '42501','leave_self_profile_forbidden','a different tenant cannot widen the authenticated user scope');
RESET ROLE;

UPDATE people.employments SET employment_status='ended',end_date=CURRENT_DATE-1
WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND id='ce600000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'employment_status','ended',
 'ended employment history remains readable for the current linked employee');
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'new_work_enabled','false',
 'ended employment cannot start new leave work');
RESET ROLE;
UPDATE people.employments SET employment_status='active',end_date=NULL
WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND id='ce600000-0000-4000-8000-000000000001';
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()
WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND capability_key='hr.leave';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'new_work_enabled','false',
 'active employment cannot start new work after Leave entitlement ends');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT is(public.unlink_people_employee_user('ce200000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000001')->>'state','unlinked',
 'authorized People manager can unlink identity for current-user transition test');
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')$$,
 '42501','leave_self_profile_forbidden','unlinked users cannot read employee history');
SELECT is(public.link_people_employee_user('ce200000-0000-4000-8000-000000000001','ce400000-0000-4000-8000-000000000003','ce100000-0000-4000-8000-000000000001')->>'state','linked',
 'authorized relink changes the authenticated user to the new current employee');
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'employee_code','SELF-3',
 'profile after relink resolves only the newly linked employee');
RESET ROLE;

UPDATE auth.users SET email_confirmed_at=NULL WHERE id='ce100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')$$,
 '42501','leave_self_profile_forbidden','unconfirmed Auth account cannot read own profile');
RESET ROLE;
UPDATE auth.users SET email_confirmed_at=now(),banned_until=now()+interval '1 hour' WHERE id='ce100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')$$,
 '42501','leave_self_profile_forbidden','banned Auth account cannot read own profile');
RESET ROLE;
UPDATE auth.users SET banned_until=NULL WHERE id='ce100000-0000-4000-8000-000000000001';
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND user_id='ce100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')$$,
 '42501','leave_self_profile_forbidden','inactive membership cannot read own profile');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND user_id='ce100000-0000-4000-8000-000000000001';
UPDATE platform_core.tenants SET lifecycle_state='suspended' WHERE id='ce200000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')$$,
 '42501','leave_self_profile_forbidden','suspended tenant cannot expose own profile');
RESET ROLE;
UPDATE platform_core.tenants SET lifecycle_state='active' WHERE id='ce200000-0000-4000-8000-000000000001';
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()
WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND capability_key='hr.people';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ce100000-0000-4000-8000-000000000001',true);
SELECT is(public.tenant_my_employee_snapshot('ce200000-0000-4000-8000-000000000001')->>'new_work_enabled','false',
 'historical own profile remains available after People entitlement ends');
SELECT is(public.set_tenant_member_people_bundles('ce200000-0000-4000-8000-000000000001','ce100000-0000-4000-8000-000000000001',ARRAY['leave.reader.v1'])->>'state','updated',
 'normal member bundle writer accepts expanded catalog and keeps existing audit action');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='ce200000-0000-4000-8000-000000000001' AND subject_user_id='ce100000-0000-4000-8000-000000000001' AND action='people_role_bundles_changed'),1,
 'normal bundle changes append the established audit event after Slice 1');
SELECT * FROM finish();
ROLLBACK;
