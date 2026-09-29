BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,invited_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('e4000000-0000-4000-8000-000000000001','member-admin-a@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000002','member-admin-b@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000003','active-member@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000004','new-member@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000005','inactive-member@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000006','wrong-email@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000007','unverified-member@example.test','hash',NULL,NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000008','other-tenant-admin@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000009','new-invited-member@example.test','invite-generated-hash',now(),now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000010','audit-failure@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000011','unconfirmed-reactivation@example.test','hash',NULL,NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('e4000000-0000-4000-8000-000000000012','banned-reactivation@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now());
UPDATE auth.users SET banned_until=now()+interval '1 day' WHERE id='e4000000-0000-4000-8000-000000000012';

INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e5000000-0000-4000-8000-000000000001','Members A','e4000000-0000-4000-8000-000000000001'),
       ('e5000000-0000-4000-8000-000000000002','Members B','e4000000-0000-4000-8000-000000000008');
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
VALUES ('e5000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',3,now()-interval '1 day','e4000000-0000-4000-8000-000000000001','test'),
       ('e5000000-0000-4000-8000-000000000001','tenant.sites','max_sites','limited',1,now()-interval '1 day','e4000000-0000-4000-8000-000000000001','test'),
       ('e5000000-0000-4000-8000-000000000002','tenant.users','max_users','limited',3,now()-interval '1 day','e4000000-0000-4000-8000-000000000008','test'),
       ('e5000000-0000-4000-8000-000000000002','tenant.sites','max_sites','limited',1,now()-interval '1 day','e4000000-0000-4000-8000-000000000008','test');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('e5000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,
  ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('e5000000-0000-4000-8000-000000000002','e6000000-0000-4000-8000-000000000002','tenant.owner_admin.v1',1,
  ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('e5000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000003','tenant.legacy_member.v1',1,ARRAY['legacy.permission'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','active','e4000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000002','active','e4000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000003','active','e4000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000005','inactive','e4000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000011','inactive','e4000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000012','inactive','e4000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000002','e4000000-0000-4000-8000-000000000008','active','e4000000-0000-4000-8000-000000000008');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000002','e6000000-0000-4000-8000-000000000001'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000003','e6000000-0000-4000-8000-000000000003'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000005','e6000000-0000-4000-8000-000000000003'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000011','e6000000-0000-4000-8000-000000000003'),
 ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000012','e6000000-0000-4000-8000-000000000003'),
 ('e5000000-0000-4000-8000-000000000002','e4000000-0000-4000-8000-000000000008','e6000000-0000-4000-8000-000000000002');

SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_member_invitations','SELECT'), 'invites are not directly readable');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_membership_audit_events','INSERT'), 'members cannot write audit directly');
SELECT throws_ok($$SELECT public.tenant_member_access_list('e5000000-0000-4000-8000-000000000002')$$,
  '42501','tenant_members_manage_forbidden','Tenant A Admin cannot list Tenant B memberships');

CREATE TEMP TABLE member_invites(label text,result jsonb);
GRANT SELECT,INSERT ON member_invites TO authenticated,service_role;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000001',true);
INSERT INTO member_invites SELECT 'full',public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000001','new-member@example.test','f5000000-0000-4000-8000-000000000001');
INSERT INTO member_invites SELECT 'inactive',public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000001','inactive-member@example.test','f5000000-0000-4000-8000-000000000002');
INSERT INTO member_invites SELECT 'new-user',public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000001','new-invited-member@example.test','f5000000-0000-4000-8000-000000000003');
INSERT INTO member_invites SELECT 'former-issuer',public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000001','former-issuer-invite@example.test','f5000000-0000-4000-8000-000000000008');
SELECT throws_ok(pg_catalog.format('SELECT public.record_tenant_member_invitation_delivery(%L::uuid,1,%L::uuid,true,NULL)',
  (SELECT result->>'id' FROM member_invites WHERE label='full'),'e4000000-0000-4000-8000-000000000001'),
  '42501','permission denied for function record_tenant_member_invitation_delivery','authenticated actors cannot forge delivery audit state');
SELECT throws_ok($$SELECT public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000002','x@example.test','f5000000-0000-4000-8000-000000000005')$$,
  '42501','tenant_members_manage_forbidden','Tenant A Admin cannot create Tenant B invitations');
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000008',true);
INSERT INTO member_invites SELECT 'cross-company',public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000002','active-member@example.test','f5000000-0000-4000-8000-000000000004');
RESET ROLE;
SELECT is((SELECT result->>'state' FROM member_invites WHERE label='cross-company'),'created','same user may be invited independently by another Tenant');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000004'),0,
  'pending invitation grants no membership and consumes no seat');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE invitation_id=(SELECT (result->>'id')::uuid FROM member_invites WHERE label='full') AND action='invitation_created'),1,
  'creating the invitation writes its audit event');

UPDATE platform_core.tenant_memberships SET access_state='inactive'
WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000001';
SELECT throws_ok($$UPDATE platform_core.tenant_memberships SET access_state='inactive'
  WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000002'$$,
  '23514','The final active Tenant administrator cannot be removed','database trigger blocks removal of the final active protected Admin');
UPDATE platform_core.tenant_memberships SET access_state='active'
WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000001';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000002',true);
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='inactive'
WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000001','member-admin-a@example.test','f5000000-0000-4000-8000-000000000007')$$,
  '42501','tenant_member_admin_requires_governed_change','a protected Admin cannot be reactivated or demoted through Member invitation');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='active'
WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000001';

DELETE FROM platform_core.membership_roles WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000001';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000003');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000002',true);
SELECT throws_ok(pg_catalog.format('SELECT public.reissue_tenant_member_invitation(%L::uuid)',(SELECT result->>'id' FROM member_invites WHERE label='former-issuer')),
  '42501','tenant_member_invite_issuer_authority_lost','another Admin cannot reissue a pending invitation whose original issuer lost authority');
RESET ROLE;
DELETE FROM platform_core.membership_roles WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000001';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000004',true);
SELECT is(public.validate_tenant_member_invitation((SELECT (result->>'id')::uuid FROM member_invites WHERE label='full'),1),'ready',
  'existing verified Auth account can claim matching email');
SELECT throws_ok(pg_catalog.format('SELECT public.accept_tenant_member_invitation(%L::uuid,1)',(SELECT result->>'id' FROM member_invites WHERE label='full')),
  'P0001','tenant_member_limit_full','full seat limit blocks acceptance');
RESET ROLE;
SELECT is((SELECT lifecycle_state FROM platform_core.tenant_member_invitations WHERE id=(SELECT (result->>'id')::uuid FROM member_invites WHERE label='full')),'pending',
  'capacity failure leaves invitation pending');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000001',true);
SELECT ok(public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000003','inactive'),
  'Admin can deactivate an ordinary Member');
SELECT throws_ok($$SELECT public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','inactive')$$,
  '42501','tenant_member_admin_requires_governed_change','member management cannot deactivate a protected Admin');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000011','active')$$,
  '42501','tenant_member_target_unavailable','unconfirmed Auth user cannot consume a seat through direct reactivation');
SELECT throws_ok($$SELECT public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000012','active')$$,
  '42501','tenant_member_target_unavailable','banned Auth user cannot consume a seat through direct reactivation');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000004',true);
CREATE TEMP TABLE accepted_member(result jsonb);
GRANT INSERT,SELECT ON accepted_member TO authenticated;
INSERT INTO accepted_member SELECT public.accept_tenant_member_invitation((SELECT (result->>'id')::uuid FROM member_invites WHERE label='full'),1);
RESET ROLE;
SELECT is((SELECT result->>'state' FROM accepted_member),'accepted','matching verified member accepts after a seat opens');
SELECT is((SELECT access_state FROM platform_core.tenant_memberships WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000004'),'active','acceptance creates active membership');
SELECT is((SELECT r.role_key FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
  WHERE mr.tenant_id='e5000000-0000-4000-8000-000000000001' AND mr.user_id='e4000000-0000-4000-8000-000000000004'),'tenant.member.v1',
  'accepted membership receives only the fixed Member snapshot');
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000004'),1,
  'acceptance writes one role assignment');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000005',true);
SELECT throws_ok(pg_catalog.format('SELECT public.accept_tenant_member_invitation(%L::uuid,1)',(SELECT result->>'id' FROM member_invites WHERE label='inactive')),
  'P0001','tenant_member_limit_full','inactive reactivation is also seat-limited');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000001',true);
SELECT ok(public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000004','inactive'),
  'free a seat before reactivating an inactive member');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000005',true);
SELECT is(public.accept_tenant_member_invitation((SELECT (result->>'id')::uuid FROM member_invites WHERE label='inactive'),1)->>'state','accepted',
  'inactive membership is reactivated through invitation acceptance');
RESET ROLE;
SELECT is((SELECT access_state FROM platform_core.tenant_memberships WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000005'),'active',
  'inactive target membership becomes active');
SELECT is((SELECT r.role_key FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
  WHERE mr.tenant_id='e5000000-0000-4000-8000-000000000001' AND mr.user_id='e4000000-0000-4000-8000-000000000005'),'tenant.member.v1',
  'reactivation replaces historical role assignment with explicit Member role');
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000005'),1,
  'reactivation does not retain the old role snapshot');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000001',true);
SELECT ok(public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000005','inactive'),
  'Admin can deactivate the reactivated Member');
SELECT ok(public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000005','active'),
  'direct reactivation checks capacity and assigns the fixed Member role');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000005'),1,
  'direct reactivation leaves exactly one explicit role assignment');
SELECT is((SELECT r.role_key FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
  WHERE mr.tenant_id='e5000000-0000-4000-8000-000000000001' AND mr.user_id='e4000000-0000-4000-8000-000000000005'),'tenant.member.v1',
  'direct reactivation cannot restore an old role');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000006',true);
SELECT throws_ok(pg_catalog.format('SELECT public.accept_tenant_member_invitation(%L::uuid,1)',(SELECT result->>'id' FROM member_invites WHERE label='full')),
  'P0001','tenant_member_invite_unavailable','accepted invitation cannot be claimed by another user');
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000007',true);
SELECT throws_ok(pg_catalog.format('SELECT public.accept_tenant_member_invitation(%L::uuid,1)',(SELECT result->>'id' FROM member_invites WHERE label='cross-company')),
  '42501','tenant_member_identity_unverified','unverified email cannot accept invitation');
RESET ROLE;

CREATE FUNCTION platform_core.test_fail_member_accept_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN IF NEW.action='accepted' THEN RAISE EXCEPTION 'simulated_member_audit_failure' USING ERRCODE='55000'; END IF; RETURN NEW; END;
$function$;
CREATE TRIGGER test_fail_member_accept_audit BEFORE INSERT ON platform_core.tenant_membership_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.test_fail_member_accept_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000001',true);
INSERT INTO member_invites SELECT 'audit-failure',public.create_tenant_member_invitation('e5000000-0000-4000-8000-000000000001','audit-failure@example.test','f5000000-0000-4000-8000-000000000006');
SELECT ok(public.set_tenant_member_access('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000005','inactive'),
  'free a seat for audit rollback case');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000010',true);
SELECT throws_ok(pg_catalog.format('SELECT public.accept_tenant_member_invitation(%L::uuid,1)',(SELECT result->>'id' FROM member_invites WHERE label='audit-failure')),
  '55000','simulated_member_audit_failure','audit failure aborts acceptance transaction');
RESET ROLE;
DROP TRIGGER test_fail_member_accept_audit ON platform_core.tenant_membership_audit_events;
DROP FUNCTION platform_core.test_fail_member_accept_audit();
SELECT is((SELECT lifecycle_state FROM platform_core.tenant_member_invitations WHERE id=(SELECT (result->>'id')::uuid FROM member_invites WHERE label='audit-failure')),'pending',
  'audit failure rolls invitation state back');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000006'),0,
  'audit failure rolls membership creation back');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000009',true);
SELECT throws_ok(pg_catalog.format('SELECT public.record_tenant_member_password_readiness(%L::uuid,1,%L::uuid)',
  (SELECT result->>'id' FROM member_invites WHERE label='new-user'),'e4000000-0000-4000-8000-000000000009'),
  '42501','permission denied for function record_tenant_member_password_readiness','authenticated users cannot mint password readiness');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT ok(public.record_tenant_member_password_readiness((SELECT (result->>'id')::uuid FROM member_invites WHERE label='new-user'),1,
  'e4000000-0000-4000-8000-000000000009'),'server-only password action can mark invited Auth credentials as ready');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000009',true);
SELECT is(public.validate_tenant_member_invitation((SELECT (result->>'id')::uuid FROM member_invites WHERE label='new-user'),1),'ready',
  'new invited Auth user becomes eligible only after credential marker');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000001',true);
SELECT is((public.reissue_tenant_member_invitation((SELECT (result->>'id')::uuid FROM member_invites WHERE label='new-user'))->>'issuance')::integer,2,
  'reissue advances issuance and expires old link');
SELECT ok(public.revoke_tenant_member_invitation((SELECT (result->>'id')::uuid FROM member_invites WHERE label='new-user')),
  'Admin can revoke a pending invitation');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4000000-0000-4000-8000-000000000009',true);
SELECT throws_ok(pg_catalog.format('SELECT public.accept_tenant_member_invitation(%L::uuid,1)',(SELECT result->>'id' FROM member_invites WHERE label='new-user')),
  'P0001','tenant_member_invite_stale_issuance','old issue cannot be accepted after reissue');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='e5000000-0000-4000-8000-000000000001' AND user_id='e4000000-0000-4000-8000-000000000009'),0,
  'pending Auth invite cannot create access without server-only acceptance');

SELECT * FROM finish();
ROLLBACK;
