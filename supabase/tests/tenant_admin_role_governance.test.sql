BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,banned_until,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('d4000000-0000-4000-8000-000000000001','governance-admin-a@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('d4000000-0000-4000-8000-000000000002','governance-admin-b@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('d4000000-0000-4000-8000-000000000003','governance-member@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('d4000000-0000-4000-8000-000000000004','governance-unverified@example.test','hash',NULL,NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('d4000000-0000-4000-8000-000000000005','governance-banned@example.test','hash',now(),now()+interval '1 day','{}','{}','authenticated','authenticated',now(),now()),
 ('d4000000-0000-4000-8000-000000000006','governance-inactive@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('d4000000-0000-4000-8000-000000000007','governance-manage-only@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('d4000000-0000-4000-8000-000000000008','governance-other-tenant@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,invited_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d4000000-0000-4000-8000-000000000009','governance-password-not-ready@example.test','invite-hash',now(),now(),'{}','{}','authenticated','authenticated',now(),now());

INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d5000000-0000-4000-8000-000000000001','Role Governance A','d4000000-0000-4000-8000-000000000001'),
       ('d5000000-0000-4000-8000-000000000002','Role Governance B','d4000000-0000-4000-8000-000000000008');
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
VALUES ('d5000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',10,now()-interval '1 day','d4000000-0000-4000-8000-000000000001','test');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES
 ('d5000000-0000-4000-8000-000000000001','d6000000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('d5000000-0000-4000-8000-000000000002','d6000000-0000-4000-8000-000000000002','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('d5000000-0000-4000-8000-000000000001','d6000000-0000-4000-8000-000000000003','tenant.member.v1',1,ARRAY[]::text[],false),
 ('d5000000-0000-4000-8000-000000000001','d6000000-0000-4000-8000-000000000004','tenant.hr.officer.v1',1,ARRAY['hr.people.read']::text[],false),
 ('d5000000-0000-4000-8000-000000000001','d6000000-0000-4000-8000-000000000005','tenant.member.manager_only.v1',1,ARRAY['tenant.members.manage']::text[],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001','active','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000002','active','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','active','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000004','active','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000005','active','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000006','inactive','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000007','active','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000009','active','d4000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000002','d4000000-0000-4000-8000-000000000008','active','d4000000-0000-4000-8000-000000000008');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001','d6000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000002','d6000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','d6000000-0000-4000-8000-000000000003'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','d6000000-0000-4000-8000-000000000004'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000004','d6000000-0000-4000-8000-000000000003'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000005','d6000000-0000-4000-8000-000000000003'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000006','d6000000-0000-4000-8000-000000000003'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000007','d6000000-0000-4000-8000-000000000005'),
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000009','d6000000-0000-4000-8000-000000000001'),
 ('d5000000-0000-4000-8000-000000000002','d4000000-0000-4000-8000-000000000008','d6000000-0000-4000-8000-000000000002');

SELECT has_function('public','change_tenant_admin_role',ARRAY['uuid','uuid','text']::name[],'narrow Tenant Admin role command exists');
SELECT has_function('public','tenant_admin_role_governance_available',ARRAY['uuid']::name[],'role-action visibility RPC exists');
SELECT ok(NOT has_function_privilege('anon','public.change_tenant_admin_role(uuid,uuid,text)','EXECUTE'),'anonymous callers cannot change Tenant roles');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.membership_roles','INSERT'),'authenticated users cannot assign roles directly');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000003',true);
SELECT ok(NOT public.tenant_admin_role_governance_available('d5000000-0000-4000-8000-000000000001'),'ordinary Member cannot manage Admin roles');
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','promote')$$,
  '42501','tenant_admin_role_forbidden','ordinary Member cannot promote themselves');
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000007',true);
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','promote')$$,
  '42501','tenant_admin_role_forbidden','members.manage without tenant.administer cannot promote');
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000008',true);
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','promote')$$,
  '42501','tenant_admin_role_forbidden','Tenant B Admin cannot change Tenant A roles');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000001',true);
SELECT ok(public.tenant_admin_role_governance_available('d5000000-0000-4000-8000-000000000001'),'active Owner/Admin with both permissions sees role controls');
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000004','promote')$$,
  '42501','tenant_admin_role_target_unavailable','unverified target cannot be promoted');
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000005','promote')$$,
  '42501','tenant_admin_role_target_unavailable','banned target cannot be promoted');
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000009','promote')$$,
  '42501','tenant_admin_role_target_unavailable','invited user without recorded password readiness cannot be promoted');
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000006','promote')$$,
  '42501','tenant_admin_role_target_unavailable','inactive target cannot be promoted');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND access_state='active'),7,
  'seat usage baseline is seven active memberships');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000001',true);
SELECT is(public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','promote')->>'state','promoted',
  'authorized Admin can promote an active Member');
RESET ROLE;
SELECT ok(EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND user_id='d4000000-0000-4000-8000-000000000003' AND role_id='d6000000-0000-4000-8000-000000000001'),
  'promotion assigns the existing Owner/Admin template');
SELECT ok(NOT EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND user_id='d4000000-0000-4000-8000-000000000003' AND role_id='d6000000-0000-4000-8000-000000000003'),
  'promotion removes the baseline Member assignment');
SELECT ok(EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND user_id='d4000000-0000-4000-8000-000000000003' AND role_id='d6000000-0000-4000-8000-000000000004'),
  'promotion preserves existing Domain role assignments');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000001',true);
SELECT is((SELECT pg_catalog.count(*)::integer FROM pg_catalog.jsonb_array_elements(
  public.tenant_member_access_list('d5000000-0000-4000-8000-000000000001')->'memberships') AS membership(membership_row)
  WHERE membership_row->>'user_id'='d4000000-0000-4000-8000-000000000003'),1,
  'access list returns exactly one row for a promoted Member with a Domain role');
SELECT is((SELECT membership_row->>'protected_admin' FROM pg_catalog.jsonb_array_elements(
  public.tenant_member_access_list('d5000000-0000-4000-8000-000000000001')->'memberships') AS membership(membership_row)
  WHERE membership_row->>'user_id'='d4000000-0000-4000-8000-000000000003'),'true',
  'access list marks the promoted Domain-role user as protected Admin');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND access_state='active'),7,
  'promotion does not change seat usage');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND subject_user_id='d4000000-0000-4000-8000-000000000003' AND action='admin_role_promoted'),1,
  'promotion writes one append-only audit event');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000001',true);
SELECT is(public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','demote')->>'state','demoted',
  'authorized Admin can demote an Admin while a recoverable replacement exists');
RESET ROLE;
SELECT ok(NOT EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND user_id='d4000000-0000-4000-8000-000000000003' AND role_id='d6000000-0000-4000-8000-000000000001'),
  'demotion removes the protected Owner/Admin assignment');
SELECT ok(EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND user_id='d4000000-0000-4000-8000-000000000003' AND role_id='d6000000-0000-4000-8000-000000000003'),
  'demotion explicitly establishes the baseline Member assignment');
SELECT ok(EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND user_id='d4000000-0000-4000-8000-000000000003' AND role_id='d6000000-0000-4000-8000-000000000004'),
  'demotion preserves existing Domain role assignments');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND access_state='active'),7,
  'demotion does not change seat usage');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND subject_user_id='d4000000-0000-4000-8000-000000000003' AND action='admin_role_demoted'),1,
  'demotion writes one append-only audit event');

CREATE FUNCTION platform_core.test_fail_admin_role_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  IF NEW.action='admin_role_promoted' THEN RAISE EXCEPTION 'simulated_admin_role_audit_failure' USING ERRCODE='55000'; END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER test_fail_admin_role_audit BEFORE INSERT ON platform_core.tenant_membership_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.test_fail_admin_role_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','promote')$$,
  '55000','simulated_admin_role_audit_failure','audit failure aborts the role mutation');
RESET ROLE;
DROP TRIGGER test_fail_admin_role_audit ON platform_core.tenant_membership_audit_events;
DROP FUNCTION platform_core.test_fail_admin_role_audit();
SELECT ok(NOT EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND user_id='d4000000-0000-4000-8000-000000000003' AND role_id='d6000000-0000-4000-8000-000000000001'),
  'audit failure leaves the Member role assignment unchanged');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000001',true);
SELECT is(public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001','demote')->>'state','demoted',
  'current Admin may demote themself when another recoverable Admin exists');
SELECT set_config('request.jwt.claim.sub','d4000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.change_tenant_admin_role('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000002','demote')$$,
  '23514','tenant_admin_last_recoverable','last recoverable Admin cannot demote themself');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
  WHERE mr.tenant_id='d5000000-0000-4000-8000-000000000001' AND mr.user_id='d4000000-0000-4000-8000-000000000002' AND r.protects_tenant_admin),1,
  'failed last-Admin demotion leaves the protected assignment intact');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE tenant_id='d5000000-0000-4000-8000-000000000001' AND action IN ('admin_role_promoted','admin_role_demoted')),3,
  'only committed promotions/demotions have audit events');

SELECT * FROM finish();
ROLLBACK;
