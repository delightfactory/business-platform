BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('bc100000-0000-4000-8000-000000000001','bundle-manager@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now()),
 ('bc100000-0000-4000-8000-000000000002','bundle-worker@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now()),
 ('bc100000-0000-4000-8000-000000000003','bundle-viewer@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now()),
 ('bc100000-0000-4000-8000-000000000004','bundle-other-tenant@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('bc200000-0000-4000-8000-000000000001','Bundle Tenant A','bc100000-0000-4000-8000-000000000001'),
 ('bc200000-0000-4000-8000-000000000002','Bundle Tenant B','bc100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('bc200000-0000-4000-8000-000000000001','bc300000-0000-4000-8000-000000000001','tenant.members.manager.v1',1,ARRAY['tenant.members.manage'],false),
 ('bc200000-0000-4000-8000-000000000001','bc300000-0000-4000-8000-000000000002','tenant.member.v1',1,ARRAY[]::text[],false),
 ('bc200000-0000-4000-8000-000000000001','bc300000-0000-4000-8000-000000000003','people.test.reader.v1',1,ARRAY['people.view'],false),
 ('bc200000-0000-4000-8000-000000000001','bc300000-0000-4000-8000-000000000006','tenant.support.reader.v1',1,ARRAY['reports.read'],false),
 ('bc200000-0000-4000-8000-000000000001','bc300000-0000-4000-8000-000000000004','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('bc200000-0000-4000-8000-000000000002','bc300000-0000-4000-8000-000000000005','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000001','active','bc100000-0000-4000-8000-000000000001'),
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','active','bc100000-0000-4000-8000-000000000001'),
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000003','active','bc100000-0000-4000-8000-000000000001'),
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004','active','bc100000-0000-4000-8000-000000000001'),
 ('bc200000-0000-4000-8000-000000000002','bc100000-0000-4000-8000-000000000004','active','bc100000-0000-4000-8000-000000000004');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000001','bc300000-0000-4000-8000-000000000001'),
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','bc300000-0000-4000-8000-000000000002'),
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','bc300000-0000-4000-8000-000000000006'),
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000003','bc300000-0000-4000-8000-000000000003'),
 ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004','bc300000-0000-4000-8000-000000000004'),
 ('bc200000-0000-4000-8000-000000000002','bc100000-0000-4000-8000-000000000004','bc300000-0000-4000-8000-000000000005');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('bc200000-0000-4000-8000-000000000001','hr.people',true,pg_catalog.now()-interval '1 minute',
 'bc100000-0000-4000-8000-000000000001','People role bundle test');

CREATE TEMP TABLE protected_admin_before AS
SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('assignment',pg_catalog.to_jsonb(assignment),'role',pg_catalog.to_jsonb(role_snapshot))
 ORDER BY assignment.tenant_id,assignment.role_id) AS snapshot
FROM platform_core.membership_roles AS assignment
JOIN platform_core.tenant_roles AS role_snapshot USING (tenant_id,role_id)
WHERE assignment.user_id='bc100000-0000-4000-8000-000000000004' AND role_snapshot.protects_tenant_admin;

SELECT has_function('public','set_tenant_member_people_bundles',ARRAY['uuid','uuid','text[]']::name[],'bounded People role bundle command exists');
SELECT ok(NOT has_function_privilege('anon','public.set_tenant_member_people_bundles(uuid,uuid,text[])','EXECUTE'),'anonymous callers cannot change People role bundles');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.membership_roles','INSERT'),'authenticated callers cannot assign roles directly');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000001',true);
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',
 ARRAY['people.reader.v1','people.compensation_reader.v1'])->>'state','updated','members.manage alone can assign multiple People bundles');
RESET ROLE;
SELECT ok(NOT platform_private.has_tenant_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000001','tenant.administer'),
 'test administrator has member-management authority without protected-admin bypass');
SELECT ok(platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','people.view'),
 'People Reader bundle grants actual People view permission');
SELECT ok(platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','compensation.view'),
 'Compensation Reader bundle grants actual compensation view permission');
SELECT ok(NOT platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','compensation.manage'),
 'reader bundles do not grant compensation management');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000001',true);
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',
 ARRAY['people.operations.v1','people.import_operator.v1'])->>'state','updated','new fixed bundles replace the prior selected People bundle set');
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',
 ARRAY['people.import_operator.v1','people.operations.v1'])->>'state','unchanged','bundle order does not create a redundant audit event');
RESET ROLE;
SELECT ok(platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','people.view'),
 'People Reader bundle grants actual People view permission');
SELECT ok(platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','compensation.view'),
 'Compensation Reader bundle grants actual compensation view permission');
SELECT ok(platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','compensation.manage'),
 'HR Operations and Import Operator bundle grant compensation management');
SELECT ok(platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','employment.manage'),
 'HR Operations bundle grants Employment management');
SELECT ok(platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','workforce_import.execute'),
 'Import Operator bundle grants Workforce Import permission');
SELECT ok(platform_private.has_tenant_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','reports.read'),
 'updating People bundles preserves unrelated Tenant role assignments');

SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND subject_user_id='bc100000-0000-4000-8000-000000000002'
   AND action='people_role_bundles_changed'),2,'only changed bundle selections append audit events');
SELECT is((SELECT details->'before' FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND subject_user_id='bc100000-0000-4000-8000-000000000002'
 AND action='people_role_bundles_changed' ORDER BY id DESC LIMIT 1),
 '["people.compensation_reader.v1", "people.reader.v1"]'::jsonb,'audit captures the previous People bundle set');
SELECT is((SELECT actor_user_id::text FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND subject_user_id='bc100000-0000-4000-8000-000000000002'
   AND action='people_role_bundles_changed' ORDER BY id DESC LIMIT 1),
 'bc100000-0000-4000-8000-000000000001','audit records the responsible member manager');
SELECT is((SELECT details->'after' FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND subject_user_id='bc100000-0000-4000-8000-000000000002'
   AND action='people_role_bundles_changed' ORDER BY id DESC LIMIT 1),
 '["people.import_operator.v1", "people.operations.v1"]'::jsonb,'audit captures the resulting bundle set');
SELECT is((SELECT permission_snapshot FROM platform_core.tenant_roles
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND role_key='people.compensation_manager.v1' AND role_version=1),
 ARRAY['people.view','compensation.view','compensation.manage']::text[],'Compensation Manager maps only to the intended People and compensation permissions');
SELECT throws_ok($$UPDATE platform_core.tenant_roles SET permission_snapshot=ARRAY['tenant.administer']::text[]
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND role_key='people.reader.v1' AND role_version=1$$,
 '55000','Tenant role snapshots are immutable; add a new role version instead','fixed V1 bundle snapshot cannot be edited');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',ARRAY['people.reader.v1'])$$,
 '42501','tenant_members_manage_forbidden','people.view alone cannot manage member bundles');
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000001',true);
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004',ARRAY['people.reader.v1'])->>'state',
 'updated','member manager can explicitly grant work bundles to a protected administrator');
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000004',true);
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004',ARRAY['people.operations.v1'])->>'state',
 'updated','protected administrator can explicitly select own operational access');
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004',ARRAY['people.operations.v1'])->>'state',
 'unchanged','repeating the same own-access selection is idempotent');
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004',ARRAY['tenant.owner_admin.v1'])$$,
 '22023','tenant_people_role_bundle_unknown','protected administrative roles are not grantable work bundles');
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004',ARRAY[]::text[])->>'state',
 'updated','administrator can revoke own work access without revoking administration');
RESET ROLE;
SELECT is((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('assignment',pg_catalog.to_jsonb(assignment),'role',pg_catalog.to_jsonb(role_snapshot))
 ORDER BY assignment.tenant_id,assignment.role_id)
 FROM platform_core.membership_roles AS assignment
 JOIN platform_core.tenant_roles AS role_snapshot USING (tenant_id,role_id)
 WHERE assignment.user_id='bc100000-0000-4000-8000-000000000004' AND role_snapshot.protects_tenant_admin),
 (SELECT snapshot FROM protected_admin_before),'protected role and assignment snapshots remain byte-for-byte unchanged in both companies');
SELECT ok(platform_private.has_tenant_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004','tenant.members.manage'),
 'administrator retains member-management authority after own work-access revocation');
SELECT ok(NOT platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000004','people.view'),
 'revoked own work access is no longer effective');
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND subject_user_id='bc100000-0000-4000-8000-000000000004'
 AND action='people_role_bundles_changed'),3,'administrator grant, replacement and revocation are audited without duplicate no-op events');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000002','bc100000-0000-4000-8000-000000000002',ARRAY['people.reader.v1'])$$,
 '42501','tenant_members_manage_forbidden','cross-Tenant operator cannot alter other Tenant assignments');
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',ARRAY['arbitrary.permission.v1'])$$,
 '22023','tenant_people_role_bundle_unknown','unknown or custom permission bundle cannot be assigned');
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',ARRAY['people.reader.v1','people.reader.v1'])$$,
 '22023','tenant_people_role_bundle_input_invalid','duplicate bundle keys are rejected');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='inactive'
WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND user_id='bc100000-0000-4000-8000-000000000002';
SELECT ok(NOT platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','people.view'),
 'inactive Member cannot retain effective access through assigned bundles');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',ARRAY[]::text[])$$,
 '42501','tenant_people_role_bundle_target_unavailable','inactive membership cannot be mutated while revoked');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='active'
WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND user_id='bc100000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000001',true);
SELECT is(public.set_tenant_member_people_bundles('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002',ARRAY[]::text[])->>'state',
 'updated','an active manager can revoke all selected People bundles');
RESET ROLE;
SELECT ok(NOT platform_private.has_people_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','people.view'),
 'revoking the final People bundle removes People access');
SELECT ok(platform_private.has_tenant_permission('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000002','reports.read'),
 'revoking People bundles leaves unrelated Tenant roles intact');
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_membership_audit_events
 WHERE tenant_id='bc200000-0000-4000-8000-000000000001' AND subject_user_id='bc100000-0000-4000-8000-000000000002'
   AND action='people_role_bundles_changed'),3,'grant, replacement and revoke are audited');

SELECT * FROM finish();
ROLLBACK;
