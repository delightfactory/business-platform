BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('c8100000-0000-4000-8000-000000000001','authority-manager@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now()),
 ('c8100000-0000-4000-8000-000000000002','authority-worker@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now()),
 ('c8100000-0000-4000-8000-000000000003','authority-viewer@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now()),
 ('c8100000-0000-4000-8000-000000000004','authority-other-tenant@example.test','hash',pg_catalog.now(),'{}','{}','authenticated','authenticated',pg_catalog.now(),pg_catalog.now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c8200000-0000-4000-8000-000000000001','Bundle Tenant A','c8100000-0000-4000-8000-000000000001'),
 ('c8200000-0000-4000-8000-000000000002','Bundle Tenant B','c8100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('c8200000-0000-4000-8000-000000000001','c8300000-0000-4000-8000-000000000001','tenant.members.manager.v1',1,ARRAY['tenant.members.manage'],false),
 ('c8200000-0000-4000-8000-000000000001','c8300000-0000-4000-8000-000000000002','tenant.member.v1',1,ARRAY[]::text[],false),
 ('c8200000-0000-4000-8000-000000000001','c8300000-0000-4000-8000-000000000003','people.test.reader.v1',1,ARRAY['people.view'],false),
 ('c8200000-0000-4000-8000-000000000001','c8300000-0000-4000-8000-000000000006','tenant.support.reader.v1',1,ARRAY['reports.read'],false),
 ('c8200000-0000-4000-8000-000000000001','c8300000-0000-4000-8000-000000000004','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('c8200000-0000-4000-8000-000000000002','c8300000-0000-4000-8000-000000000005','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000001','active','c8100000-0000-4000-8000-000000000001'),
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','active','c8100000-0000-4000-8000-000000000001'),
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000003','active','c8100000-0000-4000-8000-000000000001'),
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000004','active','c8100000-0000-4000-8000-000000000001'),
 ('c8200000-0000-4000-8000-000000000002','c8100000-0000-4000-8000-000000000004','active','c8100000-0000-4000-8000-000000000004');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000001','c8300000-0000-4000-8000-000000000001'),
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','c8300000-0000-4000-8000-000000000002'),
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','c8300000-0000-4000-8000-000000000006'),
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000003','c8300000-0000-4000-8000-000000000003'),
 ('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000004','c8300000-0000-4000-8000-000000000004'),
 ('c8200000-0000-4000-8000-000000000002','c8100000-0000-4000-8000-000000000004','c8300000-0000-4000-8000-000000000005');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('c8200000-0000-4000-8000-000000000001','hr.people',true,pg_catalog.now()-interval '1 minute',
 'c8100000-0000-4000-8000-000000000001','People role bundle test');

-- Fresh synthetic fixture only. Never creates official evidence or a final output.
SELECT is((SELECT count(*)::integer FROM platform_private.people_role_bundle_catalog()),27,'catalog exposes27 explicit work bundles');
SELECT is((SELECT permission_snapshot FROM platform_private.people_role_bundle_catalog() WHERE role_key='payroll.finalizer.v1'),ARRAY['payroll.view','payroll.lock'],'finalizer grants view and lock only');
SELECT is((SELECT permission_snapshot FROM platform_private.people_role_bundle_catalog() WHERE role_key='payroll.exporter.v1'),ARRAY['payroll.view','payroll.export'],'exporter grants view and export only');
SELECT ok(has_function_privilege('authenticated','public.set_tenant_member_people_bundles(uuid,uuid,text[],text[])','EXECUTE'),'authenticated caller can request guarded change');
SELECT ok(NOT has_function_privilege('anon','public.set_tenant_member_people_bundles(uuid,uuid,text[],text[])','EXECUTE'),'anonymous cannot call guarded writer');
SELECT ok(NOT has_function_privilege('service_role','public.set_tenant_member_people_bundles(uuid,uuid,text[],text[])','EXECUTE'),'service role has no direct guarded writer bypass');
SELECT ok(NOT has_function_privilege('authenticated','platform_private.people_role_bundle_catalog()','EXECUTE'),'private catalog remains private');
SELECT set_config('test.authority_keys',(SELECT array_agg(role_key ORDER BY role_key)::text FROM platform_private.people_role_bundle_catalog()),true);
CREATE TEMP TABLE authority_admin_before AS
 SELECT jsonb_agg(jsonb_build_object('assignment',to_jsonb(mr),'role',to_jsonb(r)) ORDER BY mr.tenant_id,mr.role_id) AS snapshot
 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
 WHERE r.protects_tenant_admin;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c8100000-0000-4000-8000-000000000001',true);
SELECT is(public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY['payroll.finalizer.v1','payroll.exporter.v1'],ARRAY[]::text[])->>'state','updated','manager explicitly grants financial bundles');
RESET ROLE;
SELECT ok(platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','payroll.lock') AND platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','payroll.export'),'new grants are real effective permissions');
SELECT ok(NOT platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','payroll.approve') AND NOT platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','payroll.prepare'),'financial grants do not imply prepare or approval');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE tenant_id='c8200000-0000-4000-8000-000000000001' AND subject_user_id='c8100000-0000-4000-8000-000000000002' AND action='people_role_bundles_changed'),1,'one accepted change produces one audit');
SELECT is((SELECT details FROM platform_core.tenant_membership_audit_events WHERE tenant_id='c8200000-0000-4000-8000-000000000001' AND subject_user_id='c8100000-0000-4000-8000-000000000002' AND action='people_role_bundles_changed'),' {"before":[],"after":["payroll.exporter.v1","payroll.finalizer.v1"]}'::jsonb,'audit retains exact before and after selections');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY[]::text[],ARRAY[]::text[])$$,'40001','tenant_people_role_bundle_stale','old snapshot cannot erase a newer financial grant');
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY[]::text[],NULL::text[])$$,'40001','tenant_people_role_bundle_stale','missing expected snapshot cannot write');
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY[]::text[],ARRAY['payroll.exporter.v1','payroll.exporter.v1'])$$,'22023','tenant_people_role_bundle_input_invalid','duplicate expected values are rejected');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE tenant_id='c8200000-0000-4000-8000-000000000001' AND subject_user_id='c8100000-0000-4000-8000-000000000002' AND action='people_role_bundles_changed'),1,'stale and invalid attempts produce no audit changes');
SELECT ok(platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','payroll.lock'),'stale denial leaves current grant intact');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c8100000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY[]::text[],ARRAY['payroll.exporter.v1','payroll.finalizer.v1'])$$,'42501','tenant_members_manage_forbidden','financial permissions do not grant member management');
SELECT set_config('request.jwt.claim.sub','c8100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000002','c8100000-0000-4000-8000-000000000004',ARRAY['payroll.finalizer.v1'],ARRAY[]::text[])$$,'42501','tenant_members_manage_forbidden','manager cannot grant into another tenant');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='c8200000-0000-4000-8000-000000000001' AND user_id='c8100000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000003',ARRAY['payroll.finalizer.v1'],ARRAY[]::text[])$$,'42501','tenant_people_role_bundle_target_unavailable','inactive member cannot receive financial grants');
SELECT is(public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',current_setting('test.authority_keys')::text[],ARRAY['payroll.exporter.v1','payroll.finalizer.v1'])->>'state','updated','all27 catalog selections fit the maintained bound');
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',current_setting('test.authority_keys')::text[]||ARRAY['extra.unknown'],current_setting('test.authority_keys')::text[])$$,'22023','tenant_people_role_bundle_input_invalid','a selection beyond catalog cardinality is rejected');
SELECT throws_ok($$SELECT public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY['unknown.role'],current_setting('test.authority_keys')::text[])$$,'22023','tenant_people_role_bundle_unknown','unknown role is rejected even within cardinality');
SELECT is(public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY[]::text[],current_setting('test.authority_keys')::text[])->>'state','updated','explicit revoke replaces only work bundles');
RESET ROLE;
SELECT ok(NOT platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','payroll.lock') AND NOT platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','payroll.export'),'revoke removes effective financial authority');
SELECT ok(platform_private.has_tenant_permission('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002','reports.read'),'unrelated custom role survives work replacement');
SET LOCAL ROLE authenticated;
SELECT is(public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000004',ARRAY['payroll.finalizer.v1'],ARRAY[]::text[])->>'state','updated','protected administrator can explicitly opt in');
RESET ROLE;
SELECT is((SELECT jsonb_agg(jsonb_build_object('assignment',to_jsonb(mr),'role',to_jsonb(r)) ORDER BY mr.tenant_id,mr.role_id) FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id) WHERE r.protects_tenant_admin),(SELECT snapshot FROM authority_admin_before),'protected administrator role snapshots and assignments unchanged');
SET LOCAL ROLE authenticated;
SELECT is(public.set_tenant_member_people_bundles('c8200000-0000-4000-8000-000000000001','c8100000-0000-4000-8000-000000000002',ARRAY['payroll.finalizer.v1','payroll.exporter.v1'])->>'state','updated','compatible three-argument API remains functional');
RESET ROLE;
-- Minimal unapproved run: a finalizer is authorized but cannot bypass workflow.
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES('c8200000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c8100000-0000-4000-8000-000000000001','Synthetic authority guard test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name)
VALUES('c8200000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001','Synthetic employer','Synthetic employer');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id) VALUES('c8200000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001');
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,payment_day,payment_month,timezone,created_by,reason)
VALUES('c8200000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001','c8500000-0000-4000-8000-000000000001',1,'2030-01-01',31,'ending','Africa/Cairo','c8100000-0000-4000-8000-000000000001','Synthetic unapproved fixture');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES('c8200000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001','c8600000-0000-4000-8000-000000000001','c8500000-0000-4000-8000-000000000001','2030-01-01','2030-01-31','2030-01-31','Africa/Cairo','Synthetic January',false,'c8100000-0000-4000-8000-000000000001');
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by)
VALUES('c8200000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001','c8600000-0000-4000-8000-000000000001','c8700000-0000-4000-8000-000000000001','draft','c8100000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c8100000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.payroll_run_finalize('c8200000-0000-4000-8000-000000000001','c8400000-0000-4000-8000-000000000001','c8600000-0000-4000-8000-000000000001','c8700000-0000-4000-8000-000000000001','c8800000-0000-4000-8000-000000000001',0,'c8900000-0000-4000-8000-000000000001')$$,'PT409','payroll_run_stale','financial grant cannot finalize an unapproved run');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM payroll.final_contexts WHERE tenant_id='c8200000-0000-4000-8000-000000000001'),0,'no final financial output fabricated');
SELECT * FROM finish();
ROLLBACK;