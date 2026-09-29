BEGIN;
SELECT plan(38);

SELECT has_function('public','create_tenant_admin_invitation',ARRAY['uuid','text','text','text','text','text','integer','text','integer']::name[],
  'Operator can create a first Admin invitation intent');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_admin_onboarding_intents','INSERT'),
  'authenticated cannot directly insert invitation intents');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_admin_invitation_audit','SELECT'),
  'authenticated cannot directly read invitation audit');

INSERT INTO auth.users (id,email,encrypted_password,email_confirmed_at,invited_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('c3000000-0000-4000-8000-000000000001','invite-operator@example.test','',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('c3000000-0000-4000-8000-000000000002','invite-operator-alt@example.test','',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('c3000000-0000-4000-8000-000000000003','invite-operator-denied@example.test','',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('c3000000-0000-4000-8000-000000000011','first-admin@example.test','existing-password-hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('c3000000-0000-4000-8000-000000000012','unverified-first-admin@example.test','',NULL,NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('c3000000-0000-4000-8000-000000000013','other-person@example.test','wrong-person-password-hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('c3000000-0000-4000-8000-000000000014','issuer-lost-admin@example.test','issuer-lost-password-hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('c3000000-0000-4000-8000-000000000015','no-password-admin@example.test','random-invite-password-hash',now(),now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants)
VALUES
 ('c3000000-0000-4000-8000-000000000001',true,false,true),
 ('c3000000-0000-4000-8000-000000000002',true,false,true),
 ('c3000000-0000-4000-8000-000000000003',true,true,false);
CREATE TEMP TABLE invite_requests(label text,result jsonb);
GRANT SELECT,INSERT ON invite_requests TO authenticated,service_role;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000003',true);
SELECT throws_ok(
 $$SELECT public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000001','Denied Co','Entity','Main','first-admin@example.test','limited',3,'limited',1)$$,
 '42501','platform_operator_onboarding_forbidden','Operator without explicit onboarding capability is denied');

SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000001',true);
INSERT INTO invite_requests
SELECT 'main',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000001','First Co','','Main',' FIRST-ADMIN@example.test ','limited',3,'limited',1);
INSERT INTO invite_requests
SELECT 'main-replay',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000001','First Co','First Co','Main','first-admin@example.test','limited',3,'limited',1);
SELECT is((SELECT result->>'id' FROM invite_requests WHERE label='main-replay'),
          (SELECT result->>'id' FROM invite_requests WHERE label='main'),'same actor and key replay the same invitation');
SELECT throws_ok(
 $$SELECT public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000001','Changed Co','Entity','Main','first-admin@example.test','limited',3,'limited',1)$$,
 'P0001','tenant_admin_invite_idempotency_conflict','same actor cannot reuse an invitation key with changed payload');
INSERT INTO invite_requests
SELECT 'unverified',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000002','Unverified Co','','Main','unverified-first-admin@example.test','limited',3,'limited',1);
INSERT INTO invite_requests
SELECT 'issuer-lost',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000003','Issuer Lost Co','','Main','issuer-lost-admin@example.test','limited',3,'limited',1);
INSERT INTO invite_requests
SELECT 'no-password',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000006','No Password Co','','Main','no-password-admin@example.test','limited',3,'limited',1);
RESET ROLE;

SELECT is((SELECT count(*)::integer FROM platform_core.tenants WHERE display_name='First Co'),0,
  'pending invite creates no Tenant');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships m
  JOIN platform_core.tenants t ON t.id=m.tenant_id
  WHERE t.display_name IN ('First Co','Unverified Co','Issuer Lost Co','No Password Co')),0,
  'pending invite consumes no membership or seat');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_admin_invitation_audit a
  JOIN invite_requests r ON a.invitation_id=(r.result->>'id')::uuid WHERE r.label='main'),1,
  'intent creation writes its audit event');
SELECT is((SELECT target_email FROM platform_core.tenant_admin_onboarding_intents WHERE id=(SELECT (result->>'id')::uuid FROM invite_requests WHERE label='main')),
  'first-admin@example.test','target email is normalized');
SELECT ok((SELECT expires_at>now()+interval '6 days' FROM platform_core.tenant_admin_onboarding_intents
  WHERE id=(SELECT (result->>'id')::uuid FROM invite_requests WHERE label='main')),'invitation intent has the approved seven-day validity');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000013',true);
SELECT throws_ok(
 pg_catalog.format('SELECT public.accept_tenant_admin_invitation(%L::uuid,1)',(SELECT result->>'id' FROM invite_requests WHERE label='main')),
 '42501','tenant_admin_invite_identity_mismatch','Auth user with a different email cannot accept the invite');
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000012',true);
SELECT throws_ok(
 pg_catalog.format('SELECT public.accept_tenant_admin_invitation(%L::uuid,1)',(SELECT result->>'id' FROM invite_requests WHERE label='unverified')),
 '42501','tenant_admin_invite_identity_unverified','unverified Auth user cannot accept an invitation');
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000015',true);
SELECT is(public.validate_tenant_admin_invitation((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='no-password'),1),
  'password_required','invited Auth user needs an app-owned password-ready marker even with a generated hash');
SELECT throws_ok(
 pg_catalog.format('SELECT public.accept_tenant_admin_invitation(%L::uuid,1)',(SELECT result->>'id' FROM invite_requests WHERE label='no-password')),
 '42501','tenant_admin_invite_password_required','verified email alone cannot activate a Tenant without a credential');
SELECT throws_ok(
 $$SELECT public.record_tenant_admin_password_readiness((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='no-password'),1,'c3000000-0000-4000-8000-000000000015')$$,
 '42501','permission denied for function record_tenant_admin_password_readiness',
 'authenticated cannot mint the server-only password-ready marker');
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000011',true);
SELECT throws_ok(
 pg_catalog.format('SELECT public.accept_tenant_admin_invitation(%L::uuid,0)',(SELECT result->>'id' FROM invite_requests WHERE label='main')),
 'P0001','tenant_admin_invite_stale_issuance','old issuance cannot be accepted');
RESET ROLE;

SET LOCAL ROLE service_role;
SELECT ok(public.record_tenant_admin_password_readiness(
  (SELECT (result->>'id')::uuid FROM invite_requests WHERE label='no-password'),1,'c3000000-0000-4000-8000-000000000015'),
  'server-only password update action can record its successful credential update');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000015',true);
SELECT is(public.validate_tenant_admin_invitation((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='no-password'),1),
  'ready','app-owned password-ready marker makes the invited Auth user eligible');
SELECT ok(public.accept_tenant_admin_invitation((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='no-password'),1)->>'tenant_name'='No Password Co',
  'marked invited Auth user can accept without losing the credential set by the server action');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000002',true);
INSERT INTO invite_requests
SELECT 'same-user-next-tenant',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000007',
  'Second Co For Same Admin','','Main','no-password-admin@example.test','limited',3,'limited',1);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000015',true);
SELECT is(public.validate_tenant_admin_invitation((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='same-user-next-tenant'),1),
  'ready','password readiness is tied to the Auth user across Tenant invitations');
SELECT ok(public.accept_tenant_admin_invitation((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='same-user-next-tenant'),1)->>'tenant_name'='Second Co For Same Admin',
  'same user can accept another Tenant invite without setting the password again');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000001',true);
SELECT public.reissue_tenant_admin_invitation((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='main'));
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000011',true);
CREATE TEMP TABLE accepted_result(result jsonb);
GRANT INSERT,SELECT ON accepted_result TO authenticated;
INSERT INTO accepted_result SELECT public.accept_tenant_admin_invitation(
  (SELECT (result->>'id')::uuid FROM invite_requests WHERE label='main'),2);
CREATE TEMP TABLE accepted_replay(result jsonb);
GRANT INSERT,SELECT ON accepted_replay TO authenticated;
INSERT INTO accepted_replay SELECT public.accept_tenant_admin_invitation(
  (SELECT (result->>'id')::uuid FROM invite_requests WHERE label='main'),2);
RESET ROLE;
SELECT is((SELECT result->>'tenant_name' FROM accepted_result),'First Co','matching verified Auth user can accept current issuance');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE user_id='c3000000-0000-4000-8000-000000000011'),1,
  'acceptance creates the first active Admin membership');
SELECT is((SELECT count(*)::integer FROM platform_core.audit_events WHERE tenant_id=(SELECT (result->>'tenant_id')::uuid FROM accepted_result)),1,
  'Tenant creation and Admin assignment have one required Core audit');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_admin_invitation_audit a
  JOIN invite_requests r ON a.invitation_id=(r.result->>'id')::uuid WHERE r.label='main' AND a.action='accepted'),1,
  'acceptance writes its invitation audit event');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000001',true);
INSERT INTO invite_requests SELECT 'main-terminal-replay',public.create_tenant_admin_invitation(
  'd3000000-0000-4000-8000-000000000001','First Co','First Co','Main','first-admin@example.test','limited',3,'limited',1);
RESET ROLE;
SELECT ok((SELECT result->>'created'='false' AND result->>'lifecycle_state'='accepted' FROM invite_requests WHERE label='main-terminal-replay'),
  'replaying an accepted idempotency key returns the outcome without requesting another email send');
SELECT is((SELECT result->>'tenant_id' FROM accepted_replay),(SELECT result->>'tenant_id' FROM accepted_result),
  'same accepted user can safely replay the current issuance');

UPDATE platform_private.platform_operator_grants SET is_active=false,can_onboard_tenants=false WHERE user_id='c3000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000014',true);
SELECT throws_ok(
 pg_catalog.format('SELECT public.accept_tenant_admin_invitation(%L::uuid,1)',(SELECT result->>'id' FROM invite_requests WHERE label='issuer-lost')),
 '42501','tenant_admin_invite_issuer_authority_lost','acceptance fails after the intent issuer loses current capability');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenants WHERE display_name='Issuer Lost Co'),0,
  'issuer authority loss leaves no partial Tenant');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000002',true);
SELECT is(public.revoke_tenant_admin_invitation((SELECT (result->>'id')::uuid FROM invite_requests WHERE label='issuer-lost')),true,
  'another capable Operator can revoke an unsupported intent');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000014',true);
SELECT throws_ok(
 pg_catalog.format('SELECT public.accept_tenant_admin_invitation(%L::uuid,1)',(SELECT result->>'id' FROM invite_requests WHERE label='issuer-lost')),
 'P0001','tenant_admin_invite_unavailable','revoked invitation cannot be accepted');
RESET ROLE;

CREATE FUNCTION platform_core.test_fail_invite_accept_audit()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $function$
BEGIN
  IF NEW.action='accepted' THEN RAISE EXCEPTION 'simulated_invitation_audit_failure' USING ERRCODE='55000'; END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER test_fail_invite_accept_audit BEFORE INSERT ON platform_core.tenant_admin_invitation_audit
FOR EACH ROW EXECUTE FUNCTION platform_core.test_fail_invite_accept_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000002',true);
INSERT INTO invite_requests
SELECT 'audit-failure',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000004','Audit Fail Co','','Main','other-person@example.test','limited',3,'limited',1);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000013',true);
SELECT throws_ok(
 pg_catalog.format('SELECT public.accept_tenant_admin_invitation(%L::uuid,1)',(SELECT result->>'id' FROM invite_requests WHERE label='audit-failure')),
 '55000','simulated_invitation_audit_failure','audit failure aborts the acceptance transaction');
RESET ROLE;
DROP TRIGGER test_fail_invite_accept_audit ON platform_core.tenant_admin_invitation_audit;
DROP FUNCTION platform_core.test_fail_invite_accept_audit();
SELECT is((SELECT count(*)::integer FROM platform_core.tenants WHERE display_name='Audit Fail Co'),0,
  'audit failure rolls back Tenant, site, limits, roles and membership');
SELECT is((SELECT lifecycle_state FROM platform_core.tenant_admin_onboarding_intents WHERE id=(SELECT (result->>'id')::uuid FROM invite_requests WHERE label='audit-failure')),
  'pending','audit failure leaves invitation pending');
SELECT is((SELECT count(*)::integer FROM platform_core.audit_events WHERE tenant_id=(SELECT tenant_id FROM platform_core.tenant_admin_onboarding_intents
  WHERE id=(SELECT (result->>'id')::uuid FROM invite_requests WHERE label='audit-failure'))),0,'audit failure leaves no partial Core audit');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000002',true);
INSERT INTO invite_requests
SELECT 'same-email-other-tenant',public.create_tenant_admin_invitation('d3000000-0000-4000-8000-000000000005','Another Co','','Main','first-admin@example.test','limited',3,'limited',1);
SELECT is((SELECT result->>'target_email' FROM invite_requests WHERE label='same-email-other-tenant'),'first-admin@example.test',
  'same person may receive another Tenant invitation');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_admin_onboarding_intents WHERE target_email='first-admin@example.test' AND lifecycle_state='pending'),1,
  'accepted invitation does not leave a duplicate pending intent for the same email');

ROLLBACK;
