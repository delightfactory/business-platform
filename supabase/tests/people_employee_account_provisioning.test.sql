BEGIN;
SELECT no_plan();

SELECT ok(
  pg_catalog.strpos(pg_catalog.pg_get_functiondef('public.activate_people_employee_account(uuid)'::regprocedure),'pg_advisory_xact_lock')
    < pg_catalog.strpos(pg_catalog.pg_get_functiondef('public.activate_people_employee_account(uuid)'::regprocedure),'people.manage'),
  'activation takes the tenant advisory lock before checking issuer permissions'
);

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('a1100000-0000-4000-8000-000000000001','account-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('a1100000-0000-4000-8000-000000000002','people-only@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('a1100000-0000-4000-8000-000000000004','unrelated@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('a2200000-0000-4000-8000-000000000001','Account Tenant','a1100000-0000-4000-8000-000000000001'),
 ('a2200000-0000-4000-8000-000000000002','Other Tenant','a1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('a2200000-0000-4000-8000-000000000001','a3300000-0000-4000-8000-000000000001','account.admin',1,ARRAY['tenant.administer','people.manage','tenant.members.manage']),
 ('a2200000-0000-4000-8000-000000000001','a3300000-0000-4000-8000-000000000002','account.people',1,ARRAY['people.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001'),
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000002','a1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001','a3300000-0000-4000-8000-000000000001'),
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000002','a3300000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('a2200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','a1100000-0000-4000-8000-000000000001','Direct employee account test');
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
VALUES ('a2200000-0000-4000-8000-000000000001','tenant.users','max_users','limited',2,now()-interval '1 minute','a1100000-0000-4000-8000-000000000001','focused test');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id,workforce_status) VALUES
 ('a2200000-0000-4000-8000-000000000001','a4400000-0000-4000-8000-000000000001','ACCOUNT-EMP-1','موظف الحساب','a1100000-0000-4000-8000-000000000001','active'),
 ('a2200000-0000-4000-8000-000000000001','a4400000-0000-4000-8000-000000000002','ACCOUNT-EMP-2','موظف بحساب موجود','a1100000-0000-4000-8000-000000000001','active'),
 ('a2200000-0000-4000-8000-000000000001','a4400000-0000-4000-8000-000000000003','ACCOUNT-EMP-3','موظف منتهٍ','a1100000-0000-4000-8000-000000000001','ended'),
 ('a2200000-0000-4000-8000-000000000001','a4400000-0000-4000-8000-000000000004','ACCOUNT-EMP-4','موظف صلاحية مسحوبة','a1100000-0000-4000-8000-000000000001','active');

SELECT ok(NOT has_table_privilege('authenticated','people.employee_account_provision_intents','SELECT'),
  'provisioning intents are not directly readable');
SELECT ok(NOT has_table_privilege('authenticated','people.employee_account_provision_audit_events','SELECT'),
  'account provisioning audit is private');
SELECT ok(NOT has_function_privilege('anon','public.activate_people_employee_account(uuid)','EXECUTE'),
  'anonymous callers cannot activate accounts');
SELECT ok(NOT has_function_privilege('authenticated','public.record_people_employee_account_password_readiness(uuid,uuid)','EXECUTE'),
  'recipients cannot directly record trusted employee password readiness');
SELECT ok(NOT has_table_privilege('authenticated','people.employee_account_password_readiness','INSERT'),
  'recipients cannot write intent-bound employee readiness rows');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001','new-user@example.test','a5500000-0000-4000-8000-000000000001')$$,
  '42501','people_employee_account_manage_forbidden','people.manage alone cannot provision without tenant.members.manage');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.today',pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date::text,true);
SELECT throws_ok($$SELECT public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000003','ended-user@example.test','a5500000-0000-4000-8000-000000000002')$$,
  '42501','people_employee_account_employee_unavailable','ended Employee cannot start direct account provisioning');
SELECT throws_ok($$SELECT public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000002',
  'a4400000-0000-4000-8000-000000000001','foreign-user@example.test','a5500000-0000-4000-8000-000000000003')$$,
  '42501','people_employee_account_manage_forbidden','provisioning is denied outside the authorized Tenant');
SELECT set_config('test.intent_id',(public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001','new-user@example.test','a5500000-0000-4000-8000-000000000004')->>'intent_id'),true);
SELECT is((public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001','new-user@example.test','a5500000-0000-4000-8000-000000000004')->>'intent_id'),
  current_setting('test.intent_id'),'same request key and signature returns the durable operation');
SELECT throws_ok($$SELECT public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001','different@example.test','a5500000-0000-4000-8000-000000000004')$$,
  'P0001','people_employee_account_request_key_conflict','same request key cannot change its target email');
SELECT is((public.people_employee_account_provision_snapshot('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001')->>'state'),'pending','the manager sees a recoverable pending intent');
SELECT throws_ok($$SELECT public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001','unrelated@example.test','a5500000-0000-4000-8000-000000000005')$$,
  '23505','people_employee_account_operation_in_progress','only one open direct account operation is allowed per Employee');
SELECT set_config('test.conflict_intent_id',(public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000002','unrelated@example.test','a5500000-0000-4000-8000-000000000006')->>'intent_id'),true);
SELECT is((public.people_employee_account_provision_snapshot('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000002')->>'state'),'manual_review','existing same-email Auth identity becomes durable manual review');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.marker',((public.prepare_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001',current_setting('test.intent_id')::uuid)->>'auth_marker')),true);
RESET ROLE;
SELECT throws_ok($$INSERT INTO auth.users(id,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
  VALUES('a1100000-0000-4000-8000-000000000003','new-user@example.test','',
    pg_catalog.jsonb_build_object('people_employee_provision_intent_id',current_setting('test.intent_id'),
      'people_employee_provision_marker','a6600000-0000-4000-8000-000000000001'),'{}','authenticated','authenticated',now(),now())$$,
  '23514','people_account_provision_marker_unmatched','a forged marker cannot bind an unrelated Auth insert');
INSERT INTO auth.users(id,email,encrypted_password,invited_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('a1100000-0000-4000-8000-000000000003','new-user@example.test',NULL,now(),'{}','{}','authenticated','authenticated',now(),now());
UPDATE auth.users SET raw_app_meta_data=pg_catalog.jsonb_build_object(
    'people_employee_provision_intent_id',current_setting('test.intent_id'),
    'people_employee_provision_marker',current_setting('test.marker'))
  WHERE id='a1100000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT is((public.prepare_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001',current_setting('test.intent_id')::uuid)->>'state'),
  'user_created','recovery captures the exact marked Auth row when metadata arrives after insert');
RESET ROLE;
SELECT is((SELECT state FROM people.employee_account_provision_intents WHERE id=current_setting('test.intent_id')::uuid),
  'user_created','the Auth insert trigger durably captures the exact marked user');
SELECT is((SELECT auth_user_id::text FROM people.employee_account_provision_intents WHERE id=current_setting('test.intent_id')::uuid),
  'a1100000-0000-4000-8000-000000000003','intent stores the exact Auth ID rather than matching by email');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND user_id='a1100000-0000-4000-8000-000000000003'),0,'Auth creation alone does not create Tenant Membership');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.people_employee_account_activation_snapshot(current_setting('test.intent_id')::uuid)$$,
  '42501','people_employee_account_activation_identity_unverified','unverified email cannot inspect activation details');
RESET ROLE;
UPDATE auth.users SET email_confirmed_at=now() WHERE id='a1100000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000003',true);
SELECT lives_ok($$SELECT public.people_employee_account_activation_snapshot(current_setting('test.intent_id')::uuid)$$,
  'recipient with confirmed target email sees only their activation context');
SELECT throws_ok($$SELECT public.activate_people_employee_account(current_setting('test.intent_id')::uuid)$$,
  '42501','people_employee_account_password_required','verified recipient still needs to set their own password');
RESET ROLE;
UPDATE auth.users SET encrypted_password='recipient-chosen-hash' WHERE id='a1100000-0000-4000-8000-000000000003';
INSERT INTO platform_private.platform_auth_password_readiness(user_id,source_workflow,source_invitation_id,source_issuance)
VALUES('a1100000-0000-4000-8000-000000000003','tenant_member_invitation','a7700000-0000-4000-8000-000000000001',1);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.activate_people_employee_account(current_setting('test.intent_id')::uuid)$$,
  '42501','people_employee_account_password_required',
  'a nonempty Auth password and another workflow readiness row cannot activate without this intent readiness marker');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT throws_ok($$SELECT public.record_people_employee_account_password_readiness(current_setting('test.intent_id')::uuid,
  'a1100000-0000-4000-8000-000000000004')$$,
  '42501','people_employee_account_readiness_identity_mismatch','readiness cannot be bound to another Auth user');
SELECT lives_ok($$SELECT public.record_people_employee_account_password_readiness(current_setting('test.intent_id')::uuid,
  'a1100000-0000-4000-8000-000000000003')$$,
  'trusted server records readiness for the verified recipient and current intent');
RESET ROLE;
SELECT is((SELECT source_workflow FROM platform_private.platform_auth_password_readiness WHERE user_id='a1100000-0000-4000-8000-000000000003'),
  'tenant_member_invitation','an existing global readiness record from another invitation workflow is preserved');
SELECT is((SELECT count(*)::integer FROM people.employee_account_password_readiness
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001' AND intent_id=current_setting('test.intent_id')::uuid
    AND employee_id='a4400000-0000-4000-8000-000000000001' AND user_id='a1100000-0000-4000-8000-000000000003'),1,
  'employee readiness is bound to the exact Tenant, Employee, intent, and Auth user');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.activate_people_employee_account(current_setting('test.intent_id')::uuid)$$,
  'P0001','tenant_member_limit_full','full Tenant seat limit blocks activation without partial Membership or link');
SELECT lives_ok($$SELECT public.defer_people_employee_account_activation(current_setting('test.intent_id')::uuid,'tenant_member_limit_full')$$,
  'recipient can retain a recoverable pending state while the Tenant is full');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND user_id='a1100000-0000-4000-8000-000000000003'),0,'seat failure created no membership');
SELECT is((SELECT count(*)::integer FROM people.employee_user_links WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND employee_id='a4400000-0000-4000-8000-000000000001'),0,'seat failure created no Employee link');
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND user_id='a1100000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000003',true);
SELECT is((public.activate_people_employee_account(current_setting('test.intent_id')::uuid)->>'state'),
  'activated','after capacity is available activation completes atomically');
RESET ROLE;
SELECT is((SELECT access_state FROM platform_core.tenant_memberships WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND user_id='a1100000-0000-4000-8000-000000000003'),'active','activation creates active Tenant Membership');
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
  WHERE mr.tenant_id='a2200000-0000-4000-8000-000000000001' AND mr.user_id='a1100000-0000-4000-8000-000000000003'
    AND r.role_key='tenant.member.v1' AND cardinality(r.permission_snapshot)=0),1,'only the empty tenant.member.v1 role is granted');
SELECT is((SELECT count(*)::integer FROM platform_core.membership_roles mr WHERE mr.tenant_id='a2200000-0000-4000-8000-000000000001'
  AND mr.user_id='a1100000-0000-4000-8000-000000000003'),1,'no additional Membership roles are created');
SELECT is((SELECT user_id::text FROM people.employee_user_links WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND employee_id='a4400000-0000-4000-8000-000000000001' AND unlinked_at IS NULL),'a1100000-0000-4000-8000-000000000003',
  'activation atomically links the exact recipient to the Employee');
SELECT ok((SELECT count(*)=1 FROM people.employee_user_link_audit_events WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND employee_id='a4400000-0000-4000-8000-000000000001' AND event_key='employee.user_linked'
  AND actor_user_id='a1100000-0000-4000-8000-000000000003'), 'recipient activation appends the same-Tenant link audit');
SELECT ok((SELECT count(*)=1 FROM platform_core.tenant_membership_audit_events WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND subject_user_id='a1100000-0000-4000-8000-000000000003' AND action='accepted'
  AND details->>'source'='direct_employee_account_activation'), 'membership activation is audited as a distinct direct path');
SELECT is((SELECT state FROM people.employee_account_provision_intents WHERE id=current_setting('test.intent_id')::uuid),
  'activated','activation is durable and idempotent');

-- Simulate an already-active account upgraded from before readiness was recorded.
DELETE FROM people.employee_account_password_readiness WHERE intent_id=current_setting('test.intent_id')::uuid;
DELETE FROM platform_private.platform_auth_password_readiness WHERE user_id='a1100000-0000-4000-8000-000000000003';
UPDATE auth.users SET raw_app_meta_data=raw_app_meta_data-'people_employee_provision_intent_id'-'people_employee_provision_marker'
  WHERE id='a1100000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.prepare_people_employee_account_password_readiness_recovery('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001',current_setting('test.intent_id')::uuid)$$,
  '42501','people_employee_account_manage_forbidden','HR access without tenant.members.manage cannot resend legacy readiness link');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT is(public.people_employee_account_provision_snapshot('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001')->>'password_ready','false','authorized HR sees that the activated legacy account lacks exact readiness');
SELECT is((public.prepare_people_employee_account_password_readiness_recovery('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001',current_setting('test.intent_id')::uuid)->>'target_email'),'new-user@example.test',
  'authorized HR can prepare a recovery link only for this activated employee identity');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000003',true);
SELECT is((public.people_employee_account_activation_snapshot(current_setting('test.intent_id')::uuid)->>'password_ready'),'false',
  'recipient snapshot exposes missing readiness only for the exact current Auth identity');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT throws_ok($$SELECT public.record_people_employee_account_password_readiness(current_setting('test.intent_id')::uuid,
  'a1100000-0000-4000-8000-000000000004')$$,
  '42501','people_employee_account_readiness_identity_mismatch','activated readiness recovery remains bound to the exact Auth user');
SELECT lives_ok($$SELECT public.record_people_employee_account_password_readiness(current_setting('test.intent_id')::uuid,
  'a1100000-0000-4000-8000-000000000003')$$,
  'recipient password update can record readiness for a legacy activated intent after provisioning metadata was cleared');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000003',true);
SELECT is((public.people_employee_account_activation_snapshot(current_setting('test.intent_id')::uuid)->>'password_ready'),'true',
  'recipient sees exact intent-bound readiness after the server records it');
SELECT is((public.activate_people_employee_account(current_setting('test.intent_id')::uuid)->>'state'),'activated',
  'activation RPC remains idempotent for the already-active legacy recipient');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND user_id='a1100000-0000-4000-8000-000000000003'),1,'readiness repair creates no duplicate membership');
SELECT is((SELECT count(*)::integer FROM people.employee_user_links WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND employee_id='a4400000-0000-4000-8000-000000000001' AND user_id='a1100000-0000-4000-8000-000000000003' AND unlinked_at IS NULL),1,
  'readiness repair creates no duplicate Employee link');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.record_people_employee_account_readiness_delivery('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000001',current_setting('test.intent_id')::uuid,'sent',NULL)$$,
  'authorized HR can audit readiness-link delivery without changing activated state');
RESET ROLE;
SELECT is((SELECT state FROM people.employee_account_provision_intents WHERE id=current_setting('test.intent_id')::uuid),'activated',
  'readiness-link delivery does not alter the activated intent state');

INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('a2200000-0000-4000-8000-000000000001','a3300000-0000-4000-8000-000000000003','tenant.owner_admin.v1',1,
  ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT is(public.change_tenant_admin_role('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000003','promote')->>'state','promoted',
  'recipient who completed the intent-bound password step is eligible for Admin promotion');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.revoked_intent_id',(public.start_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000004','revoked@example.test','a5500000-0000-4000-8000-000000000007')->>'intent_id'),true);
SELECT set_config('test.revoked_marker',((public.prepare_people_employee_account_provision('a2200000-0000-4000-8000-000000000001',
  'a4400000-0000-4000-8000-000000000004',current_setting('test.revoked_intent_id')::uuid)->>'auth_marker')),true);
RESET ROLE;
INSERT INTO auth.users(id,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('a1100000-0000-4000-8000-000000000005','revoked@example.test','',
  pg_catalog.jsonb_build_object('people_employee_provision_intent_id',current_setting('test.revoked_intent_id'),
    'people_employee_provision_marker',current_setting('test.revoked_marker')),'{}','authenticated','authenticated',now(),now());
UPDATE auth.users SET email_confirmed_at=now(),encrypted_password='recipient-chosen-hash' WHERE id='a1100000-0000-4000-8000-000000000005';
SET LOCAL ROLE service_role;
SELECT lives_ok($$SELECT public.record_people_employee_account_password_readiness(current_setting('test.revoked_intent_id')::uuid,
  'a1100000-0000-4000-8000-000000000005')$$,'issuer revocation is still checked during activation, after readiness capture');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='inactive'
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001' AND user_id='a1100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000005',true);
SELECT throws_ok($$SELECT public.activate_people_employee_account(current_setting('test.revoked_intent_id')::uuid)$$,
  '42501','people_employee_account_issuer_forbidden','recipient activation is denied after issuer Membership is revoked');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND user_id='a1100000-0000-4000-8000-000000000005'),0,'revoked issuer cannot cause an automatic membership grant');
SELECT is((SELECT count(*)::integer FROM people.employee_user_links WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
  AND employee_id='a4400000-0000-4000-8000-000000000004' AND unlinked_at IS NULL),0,'revoked issuer cannot cause an Employee link');
SELECT * FROM finish();
ROLLBACK;
