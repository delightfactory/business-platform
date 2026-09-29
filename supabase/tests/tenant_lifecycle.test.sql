BEGIN;
SELECT no_plan();

SELECT has_function('public','current_operator_can_manage_tenant_lifecycle',ARRAY[]::name[],'lifecycle capability RPC exists');
SELECT has_function('public','platform_tenant_lifecycle_list',ARRAY[]::name[],'bounded Tenant lifecycle list exists');
SELECT has_function('public','change_tenant_lifecycle',ARRAY['uuid','text','text','text']::name[],'lifecycle command requires expected state and reason');
SELECT has_function('public','current_tenant_spaces',ARRAY[]::name[],'separate tenant space status projection exists');
SELECT has_function('public','tenant_lifecycle_status',ARRAY['uuid']::name[],'minimal member status projection exists');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_lifecycle_audit_events','SELECT'),'Tenant lifecycle audit is not directly readable');
SELECT ok(NOT has_function_privilege('anon','public.change_tenant_lifecycle(uuid,text,text,text)','EXECUTE'),'anon cannot transition Tenant lifecycle');

INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
 ('f9000000-0000-4000-8000-000000000001','authenticated','authenticated','lifecycle-operator@example.test','hash',now(),'{}','{}',now(),now()),
 ('f9000000-0000-4000-8000-000000000002','authenticated','authenticated','operator-manager-only@example.test','hash',now(),'{}','{}',now(),now()),
 ('f9000000-0000-4000-8000-000000000003','authenticated','authenticated','lifecycle-tenant-admin@example.test','hash',now(),'{}','{}',now(),now()),
 ('f9000000-0000-4000-8000-000000000004','authenticated','authenticated','lifecycle-invited-member@example.test','invite-hash',now(),'{}','{}',now(),now());
UPDATE auth.users SET invited_at=now() WHERE id='f9000000-0000-4000-8000-000000000004';

INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle)
VALUES ('f9000000-0000-4000-8000-000000000001',true,false,false,true),
       ('f9000000-0000-4000-8000-000000000002',true,true,false,false);

INSERT INTO platform_core.tenants(id,display_name,lifecycle_state,created_by_operator_id)
VALUES ('fa000000-0000-4000-8000-000000000001','Lifecycle A','active','f9000000-0000-4000-8000-000000000001'),
       ('fa000000-0000-4000-8000-000000000002','Lifecycle B','active','f9000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
VALUES ('fa000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',5,now()-interval '1 day','f9000000-0000-4000-8000-000000000001','lifecycle-test'),
       ('fa000000-0000-4000-8000-000000000001','tenant.sites','max_sites','limited',2,now()-interval '1 day','f9000000-0000-4000-8000-000000000001','lifecycle-test'),
       ('fa000000-0000-4000-8000-000000000002','tenant.users','max_users','limited',5,now()-interval '1 day','f9000000-0000-4000-8000-000000000001','lifecycle-test'),
       ('fa000000-0000-4000-8000-000000000002','tenant.sites','max_sites','limited',2,now()-interval '1 day','f9000000-0000-4000-8000-000000000001','lifecycle-test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('fa000000-0000-4000-8000-000000000001','fb000000-0000-4000-8000-000000000001','Lifecycle A Legal',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default)
VALUES ('fa000000-0000-4000-8000-000000000001','fc000000-0000-4000-8000-000000000001','fb000000-0000-4000-8000-000000000001','Lifecycle A Site',true);
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('fa000000-0000-4000-8000-000000000001','fd000000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,
    ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
       ('fa000000-0000-4000-8000-000000000002','fd000000-0000-4000-8000-000000000002','tenant.owner_admin.v1',1,
    ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('fa000000-0000-4000-8000-000000000001','f9000000-0000-4000-8000-000000000003','active','f9000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('fa000000-0000-4000-8000-000000000001','f9000000-0000-4000-8000-000000000003','fd000000-0000-4000-8000-000000000001');

CREATE TEMP TABLE lifecycle_fixture(invitation_id uuid);
GRANT SELECT,INSERT ON lifecycle_fixture TO authenticated,service_role;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f9000000-0000-4000-8000-000000000002',true);
SELECT ok(NOT public.current_operator_can_manage_tenant_lifecycle(),'manage-operators does not imply lifecycle capability');
SELECT throws_ok($$SELECT public.platform_tenant_lifecycle_list()$$,'42501','tenant_lifecycle_forbidden','manager-only Operator cannot list Tenant lifecycle');
SELECT throws_ok($$SELECT public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','active','suspended','not authorized')$$,
  '42501','tenant_lifecycle_forbidden','manager-only Operator cannot change Tenant lifecycle');

SELECT set_config('request.jwt.claim.sub','f9000000-0000-4000-8000-000000000003',true);
SELECT is(public.current_tenant_memberships()->0->>'tenant_name','Lifecycle A','legacy active-only membership projection remains available');
SELECT is(public.current_tenant_spaces()->0->>'lifecycle_state','active','space projection reports an active Tenant');
SELECT is(public.tenant_membership_snapshot('fa000000-0000-4000-8000-000000000001')->>'tenant_name','Lifecycle A','active member can read the membership snapshot');
SELECT is(public.tenant_admin_snapshot('fa000000-0000-4000-8000-000000000001')->>'tenant_name','Lifecycle A','active Admin can read the business snapshot');
SELECT throws_ok($$SELECT public.tenant_membership_snapshot('fa000000-0000-4000-8000-000000000002')$$,
  '42501','tenant_membership_forbidden','Tenant A member cannot inspect Tenant B');
INSERT INTO lifecycle_fixture
SELECT (public.create_tenant_member_invitation('fa000000-0000-4000-8000-000000000001','lifecycle-invited-member@example.test','fe000000-0000-4000-8000-000000000001')->>'id')::uuid;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f9000000-0000-4000-8000-000000000001',true);
SELECT ok(public.current_operator_can_manage_tenant_lifecycle(),'lifecycle grant is independently recognized');
SELECT is(pg_catalog.jsonb_array_length(public.platform_tenant_lifecycle_list()),2,'authorized Operator sees only the bounded Tenant list');
SELECT is((SELECT pg_catalog.count(*)::integer FROM pg_catalog.jsonb_object_keys(public.platform_tenant_lifecycle_list()->0)),3,'Tenant list items expose only id, name, and lifecycle state');
SELECT is(public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','active','suspended','Temporary security hold')->>'to_state',
  'suspended','active Tenant can be suspended');
SELECT throws_ok($$SELECT public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','active','archived','Stale state')$$,
  '40001','tenant_lifecycle_state_changed','stale UI state cannot overwrite a newer lifecycle state');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f9000000-0000-4000-8000-000000000003',true);
SELECT is(public.tenant_lifecycle_status('fa000000-0000-4000-8000-000000000001')->>'lifecycle_state','suspended','active Member sees only the suspended status projection');
SELECT is(public.tenant_lifecycle_status('fa000000-0000-4000-8000-000000000001')->>'tenant_name','Lifecycle A','suspension surface includes the company name for support');
SELECT is(public.current_tenant_spaces()->0->>'lifecycle_state','suspended','suspended Tenant remains selectable with status only');
SELECT is(pg_catalog.jsonb_array_length(public.current_tenant_memberships()),0,'legacy active-only projection excludes suspended Tenant');
SELECT throws_ok($$SELECT public.tenant_membership_snapshot('fa000000-0000-4000-8000-000000000001')$$,
  '42501','tenant_membership_forbidden','suspended Tenant denies normal membership snapshot');
SELECT throws_ok($$SELECT public.tenant_admin_snapshot('fa000000-0000-4000-8000-000000000001')$$,
  'P0002','tenant_snapshot_not_available','suspended Tenant denies business snapshot');
SELECT throws_ok($$SELECT public.create_tenant_member_invitation('fa000000-0000-4000-8000-000000000001','other@example.test','fe000000-0000-4000-8000-000000000002')$$,
  '42501','tenant_members_manage_forbidden','suspended Tenant denies invitation creation');
SELECT throws_ok(pg_catalog.format('SELECT public.reissue_tenant_member_invitation(%L::uuid)',(SELECT invitation_id FROM lifecycle_fixture)),
  '42501','tenant_members_manage_forbidden','suspended Tenant denies invitation reissue');
SELECT throws_ok(pg_catalog.format('SELECT public.revoke_tenant_member_invitation(%L::uuid)',(SELECT invitation_id FROM lifecycle_fixture)),
  '42501','tenant_members_manage_forbidden','suspended Tenant denies invitation revocation');
RESET ROLE;

SET LOCAL ROLE service_role;
SELECT throws_ok(pg_catalog.format('SELECT public.record_tenant_member_invitation_delivery(%L::uuid,1,%L::uuid,true,NULL)',
  (SELECT invitation_id FROM lifecycle_fixture),'f9000000-0000-4000-8000-000000000003'),
  '42501','tenant_member_invite_unavailable','suspended Tenant denies invitation delivery state mutation');
SELECT throws_ok(pg_catalog.format('SELECT public.record_tenant_member_password_readiness(%L::uuid,1,%L::uuid)',
  (SELECT invitation_id FROM lifecycle_fixture),'f9000000-0000-4000-8000-000000000004'),
  '42501','tenant_member_invite_unavailable','suspended Tenant denies invitation credential readiness mutation');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f9000000-0000-4000-8000-000000000001',true);
SELECT is(public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','suspended','active','Support restored access')->>'to_state',
  'active','suspended Tenant can be reactivated');
SELECT is(public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','active','archived','Tenant closure approved')->>'to_state',
  'archived','active Tenant can be archived');
SELECT throws_ok($$SELECT public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','archived','active','Direct restoration')$$,
  '23514','tenant_lifecycle_transition_invalid','archived Tenant cannot move directly to active');
SELECT is(public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','archived','suspended','Restore for review')->>'to_state',
  'suspended','archived Tenant can be restored only to suspended');
SELECT is(public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','suspended','active','Review completed')->>'to_state',
  'active','restored Tenant requires a separate reactivation');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f9000000-0000-4000-8000-000000000003',true);
SELECT is(public.tenant_lifecycle_status('fa000000-0000-4000-8000-000000000001')->>'lifecycle_state','active','member status returns after reactivation');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_lifecycle_audit_events WHERE tenant_id='fa000000-0000-4000-8000-000000000001'),5,
  'all five allowed lifecycle transitions have mandatory audit events');
SELECT is((SELECT reason FROM platform_core.tenant_lifecycle_audit_events WHERE tenant_id='fa000000-0000-4000-8000-000000000001' ORDER BY id LIMIT 1),
  'Temporary security hold','audit retains the mandatory transition reason');

CREATE FUNCTION public.fail_test_tenant_lifecycle_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'tenant_lifecycle_audit_failure' USING ERRCODE='P0001'; END;
$function$;
CREATE TRIGGER fail_test_tenant_lifecycle_audit BEFORE INSERT ON platform_core.tenant_lifecycle_audit_events
FOR EACH ROW EXECUTE FUNCTION public.fail_test_tenant_lifecycle_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f9000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.change_tenant_lifecycle('fa000000-0000-4000-8000-000000000001','active','suspended','Audit rollback test')$$,
  'P0001','tenant_lifecycle_audit_failure','audit failure aborts the lifecycle state change');
RESET ROLE;
DROP TRIGGER fail_test_tenant_lifecycle_audit ON platform_core.tenant_lifecycle_audit_events;
DROP FUNCTION public.fail_test_tenant_lifecycle_audit();
SELECT is((SELECT lifecycle_state FROM platform_core.tenants WHERE id='fa000000-0000-4000-8000-000000000001'),'active',
  'audit failure leaves the Tenant active');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_lifecycle_audit_events WHERE tenant_id='fa000000-0000-4000-8000-000000000001'),5,
  'audit failure does not leave a transition record');

SELECT * FROM finish();
ROLLBACK;
