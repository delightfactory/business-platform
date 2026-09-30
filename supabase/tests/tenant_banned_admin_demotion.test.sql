\set ON_ERROR_STOP on
BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,banned_until,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('f2010000-0000-4000-8000-000000000001','gov-actor@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('f2010000-0000-4000-8000-000000000002','gov-replacement@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('f2010000-0000-4000-8000-000000000003','gov-banned-admin@example.test','hash',now(),now()+interval '1 day','{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('f2020000-0000-4000-8000-000000000001','Governance QA repro','f2010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('f2020000-0000-4000-8000-000000000001','f2030000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage']::text[],true),
 ('f2020000-0000-4000-8000-000000000001','f2030000-0000-4000-8000-000000000002','tenant.member.v1',1,ARRAY[]::text[],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000001','active','f2010000-0000-4000-8000-000000000001'),
 ('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000002','active','f2010000-0000-4000-8000-000000000001'),
 ('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000003','active','f2010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000001','f2030000-0000-4000-8000-000000000001'),
 ('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000002','f2030000-0000-4000-8000-000000000001'),
 ('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000003','f2030000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f2010000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.change_tenant_admin_role('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000003','promote')$$,'42501','tenant_admin_role_target_unavailable','banned account cannot gain Admin authority');
SELECT is(public.change_tenant_admin_role('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000003','demote')->>'state','demoted','banned Admin can be demoted while a recoverable replacement exists');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id) WHERE mr.tenant_id='f2020000-0000-4000-8000-000000000001' AND mr.user_id='f2010000-0000-4000-8000-000000000003' AND r.protects_tenant_admin),0,'demotion removes protected authority');
SELECT ok((SELECT banned_until>now() FROM auth.users WHERE id='f2010000-0000-4000-8000-000000000003'),'demotion does not lift the Auth ban');
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT public.set_tenant_member_access('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000003','inactive')$$,'membership can be deactivated after governed demotion');
RESET ROLE;
SELECT is((SELECT access_state FROM platform_core.tenant_memberships WHERE tenant_id='f2020000-0000-4000-8000-000000000001' AND user_id='f2010000-0000-4000-8000-000000000003'),'inactive','deactivation completes the recovery workflow');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE tenant_id='f2020000-0000-4000-8000-000000000001' AND subject_user_id='f2010000-0000-4000-8000-000000000003' AND action='admin_role_demoted'),1,'demotion is audited once');
UPDATE auth.users SET banned_until=now()+interval '1 day' WHERE id='f2010000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.change_tenant_admin_role('f2020000-0000-4000-8000-000000000001','f2010000-0000-4000-8000-000000000001','demote')$$,'23514','tenant_admin_last_recoverable','a banned replacement does not qualify to remove the last recoverable Admin');
SELECT * FROM finish();
ROLLBACK;