BEGIN;
SELECT plan(34);

SELECT has_function('public', 'onboard_tenant', ARRAY['uuid','text','text','text','text','text','integer','text','integer']::name[], 'atomic onboarding RPC exists');
SELECT ok(NOT has_table_privilege('authenticated', 'platform_core.tenants', 'INSERT'), 'authenticated has no direct Tenant insert');
SELECT ok(NOT has_table_privilege('authenticated', 'platform_core.audit_events', 'SELECT'), 'authenticated cannot read the audit table directly');

INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES
 ('b2000000-0000-4000-8000-000000000001', 'operator-a@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('b2000000-0000-4000-8000-000000000002', 'operator-b@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('b2000000-0000-4000-8000-000000000003', 'operator-c@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('b2000000-0000-4000-8000-000000000011', 'admin-a@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('b2000000-0000-4000-8000-000000000012', 'admin-b@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('b2000000-0000-4000-8000-000000000014', 'banned-admin@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('b2000000-0000-4000-8000-000000000013', 'unverified-admin@example.test', '', NULL, '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now());
UPDATE auth.users SET banned_until = now() + interval '1 day' WHERE id = 'b2000000-0000-4000-8000-000000000014';
INSERT INTO platform_private.platform_operator_grants (user_id, is_active, can_manage_operators, can_onboard_tenants)
VALUES
 ('b2000000-0000-4000-8000-000000000001', true, true, true),
 ('b2000000-0000-4000-8000-000000000002', true, false, true),
 ('b2000000-0000-4000-8000-000000000003', true, false, false);

CREATE TEMP TABLE onboarding_alpha (result jsonb);
CREATE TEMP TABLE onboarding_beta (result jsonb);
GRANT SELECT, INSERT ON onboarding_alpha, onboarding_beta TO authenticated;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000001', true);
SELECT ok(public.current_operator_can_onboard_tenants(), 'explicitly granted Operator capability is visible');
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000003', true);
SELECT ok(NOT public.current_operator_can_onboard_tenants(), 'active Operator without onboarding capability is denied');
SELECT throws_ok(
  $$SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000001', 'Unauthorized', 'Entity', 'Site', 'admin-a@example.test', 'limited', 5, 'limited', 1)$$,
  '42501', 'platform_operator_onboarding_forbidden', 'Operator without capability cannot create Tenant'
);

SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000001', true);
SELECT throws_ok(
  $$SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000002', 'Missing Admin', 'Entity', 'Site', 'missing@example.test', 'limited', 5, 'limited', 1)$$,
  '22023', 'onboarding_admin_not_found_or_disabled', 'admin must be an existing enabled Auth user'
);
SELECT throws_ok(
  $$SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000003', 'Unverified Admin', 'Entity', 'Site', 'unverified-admin@example.test', 'limited', 5, 'limited', 1)$$,
  '22023', 'onboarding_admin_email_unverified', 'admin email must be confirmed'
);
SELECT throws_ok(
  $$SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000004', 'Zero Limit', 'Entity', 'Site', 'admin-a@example.test', 'limited', 0, 'limited', 1)$$,
  '22023', 'onboarding_invalid_limit', 'zero seat limit is rejected'
);

RESET ROLE;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000001', true);
CREATE FUNCTION platform_core.test_fail_audit_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION 'simulated_audit_failure' USING ERRCODE = '55000';
END;
$function$;
CREATE TRIGGER test_fail_audit_insert
BEFORE INSERT ON platform_core.audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.test_fail_audit_insert();
SELECT throws_ok(
  $$SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000005', 'Audit Failure', 'Entity', 'Site', 'admin-a@example.test', 'limited', 5, 'limited', 1)$$,
  '55000', 'simulated_audit_failure', 'audit failure aborts onboarding transaction'
);
DROP TRIGGER test_fail_audit_insert ON platform_core.audit_events;
DROP FUNCTION platform_core.test_fail_audit_insert();
RESET ROLE;
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenants WHERE display_name = 'Audit Failure'), 0, 'audit failure rolled back Tenant creation');
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_onboarding_idempotency WHERE idempotency_key = 'c2000000-0000-4000-8000-000000000005'), 0, 'audit failure rolled back idempotency reservation');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000001', true);
INSERT INTO onboarding_alpha (result)
SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000010', 'Tenant Alpha', 'Alpha Entity', 'Main Site', 'admin-a@example.test', 'limited', 8, 'limited', 3);
SELECT is((SELECT result ->> 'tenant_name' FROM onboarding_alpha), 'Tenant Alpha', 'Tenant A was created');
SELECT is((SELECT result ->> 'seat_usage' FROM onboarding_alpha), '1', 'initial seat usage is included');
SELECT is((SELECT result ->> 'site_usage' FROM onboarding_alpha), '1', 'initial site usage is included');
RESET ROLE;
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.audit_events WHERE tenant_id = ((SELECT result ->> 'tenant_id' FROM onboarding_alpha)::uuid)), 1, 'onboarding success has one durable audit event');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000001', true);
SELECT is(
  (SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000010', 'Tenant Alpha', 'Alpha Entity', 'Main Site', 'admin-a@example.test', 'limited', 8, 'limited', 3) ->> 'tenant_id'),
  (SELECT result ->> 'tenant_id' FROM onboarding_alpha),
  'same actor and key replay the same Tenant'
);
SELECT throws_ok(
  $$SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000010', 'Changed Payload', 'Alpha Entity', 'Main Site', 'admin-a@example.test', 'limited', 8, 'limited', 3)$$,
  'P0001', 'onboarding_idempotency_conflict', 'same actor cannot reuse a key with a different request'
);

SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
INSERT INTO onboarding_beta (result)
SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000010', 'Tenant Beta', 'Beta Entity', 'Beta Site', 'admin-b@example.test', 'unlimited', NULL, 'limited', 2);
SELECT ok(
  (SELECT result ->> 'tenant_id' FROM onboarding_beta) <> (SELECT result ->> 'tenant_id' FROM onboarding_alpha),
  'the same key is scoped to its Operator actor'
);
SELECT is(
  (SELECT public.tenant_onboarding_result('c2000000-0000-4000-8000-000000000010') ->> 'tenant_id'),
  (SELECT result ->> 'tenant_id' FROM onboarding_beta),
  'result lookup returns only the current actor result'
);
RESET ROLE;
UPDATE platform_private.platform_operator_grants SET can_onboard_tenants = false
WHERE user_id = 'b2000000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
SELECT is(
  public.tenant_onboarding_result('c2000000-0000-4000-8000-000000000010'),
  NULL::jsonb,
  'result lookup is denied after onboarding capability is revoked'
);
RESET ROLE;
UPDATE platform_private.platform_operator_grants SET can_onboard_tenants = true
WHERE user_id = 'b2000000-0000-4000-8000-000000000002';
UPDATE auth.users SET banned_until = now() + interval '1 day' WHERE id = 'b2000000-0000-4000-8000-000000000012';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
SELECT is(
  (SELECT public.onboard_tenant('c2000000-0000-4000-8000-000000000010', 'Tenant Beta', 'Beta Entity', 'Beta Site', 'admin-b@example.test', 'unlimited', NULL, 'limited', 2) ->> 'tenant_id'),
  (SELECT result ->> 'tenant_id' FROM onboarding_beta),
  'same request replay succeeds after the original Admin becomes banned'
);

SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000011', true);
SELECT is(
  (SELECT public.tenant_admin_snapshot((SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)) ->> 'tenant_name'),
  'Tenant Alpha',
  'Tenant Admin can read its explicit tenant snapshot'
);
SELECT is(
  (SELECT public.tenant_admin_snapshot((SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)) ->> 'seat_limit'),
  '8', 'Tenant snapshot reads its authoritative effective-dated seat limit'
);
SELECT throws_ok(
  pg_catalog.format('SELECT public.tenant_admin_snapshot(%L::uuid)', (SELECT result ->> 'tenant_id' FROM onboarding_beta)),
  '42501', 'tenant_snapshot_forbidden', 'Tenant A Admin cannot read Tenant B snapshot'
);
RESET ROLE;
INSERT INTO platform_core.tenant_memberships (tenant_id, user_id, created_by_operator_id)
SELECT (result ->> 'tenant_id')::uuid, 'b2000000-0000-4000-8000-000000000014', 'b2000000-0000-4000-8000-000000000001'
FROM onboarding_alpha;
INSERT INTO platform_core.membership_roles (tenant_id, user_id, role_id)
SELECT (assignment.tenant_id), 'b2000000-0000-4000-8000-000000000014', assignment.role_id
FROM platform_core.membership_roles AS assignment
JOIN onboarding_alpha AS alpha ON assignment.tenant_id = (alpha.result ->> 'tenant_id')::uuid
WHERE assignment.user_id = 'b2000000-0000-4000-8000-000000000011';
SELECT throws_ok(
  pg_catalog.format(
    'DELETE FROM platform_core.membership_roles WHERE tenant_id = %L::uuid AND user_id = %L::uuid',
    (SELECT result ->> 'tenant_id' FROM onboarding_alpha),
    'b2000000-0000-4000-8000-000000000011'
  ),
  '23514', 'The final active Tenant administrator cannot be removed', 'banned alternate Admin does not protect final Admin assignment'
);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000014', true);
SELECT throws_ok(
  pg_catalog.format('SELECT public.tenant_admin_snapshot(%L::uuid)', (SELECT result ->> 'tenant_id' FROM onboarding_alpha)),
  '42501', 'tenant_snapshot_forbidden', 'banned Auth user cannot read Tenant Admin snapshot'
);
RESET ROLE;
CREATE TEMP TABLE saved_limit_row AS
SELECT * FROM platform_core.tenant_capability_limits
WHERE tenant_id = (SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)
  AND capability_key = 'tenant.users';
DELETE FROM platform_core.tenant_capability_limits
WHERE tenant_id = (SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)
  AND capability_key = 'tenant.users';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000011', true);
SELECT throws_ok(
  pg_catalog.format('SELECT public.tenant_admin_snapshot(%L::uuid)', (SELECT result ->> 'tenant_id' FROM onboarding_alpha)),
  '55000', 'tenant_snapshot_limits_unavailable', 'Tenant snapshot fails closed when a current limit is missing'
);
RESET ROLE;
INSERT INTO platform_core.tenant_capability_limits
SELECT * FROM saved_limit_row;
INSERT INTO platform_core.tenant_capability_limits (
  tenant_id, capability_key, limit_key, limit_mode, limit_value,
  valid_from, valid_until, actor_user_id, provenance
)
SELECT tenant_id, capability_key, limit_key, limit_mode, limit_value,
  valid_from - interval '1 hour', valid_from, actor_user_id, provenance
FROM platform_core.tenant_capability_limits
WHERE tenant_id = (SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)
  AND capability_key = 'tenant.users';
SELECT is(
  (SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_capability_limits
   WHERE tenant_id = (SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)
     AND capability_key = 'tenant.users'),
  2, 'adjacent effective limit intervals are accepted'
);
SELECT throws_ok(
  pg_catalog.format(
    'INSERT INTO platform_core.tenant_capability_limits (tenant_id, capability_key, limit_key, limit_mode, limit_value, valid_from, valid_until, actor_user_id, provenance) SELECT tenant_id, capability_key, limit_key, limit_mode, limit_value, valid_from - interval ''1 second'', NULL, actor_user_id, provenance FROM platform_core.tenant_capability_limits WHERE tenant_id = %L::uuid AND capability_key = ''tenant.users''',
    (SELECT result ->> 'tenant_id' FROM onboarding_alpha)
  ),
  '23P01', 'Tenant capability limit validity intervals cannot overlap', 'overlapping effective limit interval is rejected'
);
SELECT throws_ok(
  pg_catalog.format(
    'INSERT INTO platform_core.tenant_roles (tenant_id, role_key, role_version, permission_snapshot, protects_tenant_admin) VALUES (%L::uuid, %L, 1, ARRAY[%L]::text[], true)',
    (SELECT result ->> 'tenant_id' FROM onboarding_alpha), 'tenant.admin.invalid', 'tenant.members.manage'
  ),
  '23514', NULL, 'a protected role must include the admin permission'
);
INSERT INTO platform_core.tenant_roles (tenant_id, role_key, role_version, permission_snapshot, protects_tenant_admin)
SELECT (result ->> 'tenant_id')::uuid, 'tenant.owner_admin.v2', 2, ARRAY['tenant.administer']::text[], true
FROM onboarding_alpha;
INSERT INTO platform_core.membership_roles (tenant_id, user_id, role_id)
SELECT assignment.tenant_id, assignment.user_id, role_snapshot.role_id
FROM platform_core.membership_roles AS assignment
JOIN onboarding_alpha AS alpha ON assignment.tenant_id = (alpha.result ->> 'tenant_id')::uuid
JOIN platform_core.tenant_roles AS role_snapshot
  ON role_snapshot.tenant_id = assignment.tenant_id AND role_snapshot.role_key = 'tenant.owner_admin.v2'
WHERE assignment.user_id = 'b2000000-0000-4000-8000-000000000011';
DELETE FROM platform_core.membership_roles
WHERE tenant_id = (SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)
  AND user_id = 'b2000000-0000-4000-8000-000000000011'
  AND role_id = (SELECT role_id FROM platform_core.tenant_roles
    WHERE tenant_id = (SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)
      AND role_key = 'tenant.owner_admin.v1');
SELECT is(
  (SELECT pg_catalog.count(*)::integer FROM platform_core.membership_roles
   WHERE tenant_id = (SELECT (result ->> 'tenant_id')::uuid FROM onboarding_alpha)
     AND user_id = 'b2000000-0000-4000-8000-000000000011'),
  1, 'an Admin can move to a protected role snapshot version without losing access'
);
SELECT throws_ok(
  pg_catalog.format(
    'INSERT INTO platform_core.tenant_sites (tenant_id, legal_entity_id, display_name) VALUES (%L::uuid, %L::uuid, %L)',
    (SELECT result ->> 'tenant_id' FROM onboarding_alpha),
    (SELECT result ->> 'legal_entity_id' FROM onboarding_beta),
    'Cross Tenant Site'
  ),
  '23503', NULL, 'composite foreign key rejects cross-tenant Legal Entity reference'
);
SELECT throws_ok(
  pg_catalog.format(
    'DELETE FROM platform_core.tenant_memberships WHERE tenant_id = %L::uuid AND user_id = %L::uuid',
    (SELECT result ->> 'tenant_id' FROM onboarding_alpha),
    'b2000000-0000-4000-8000-000000000011'
  ),
  '23514', 'The final active Tenant administrator cannot be removed', 'final tenant administrator is protected'
);

RESET ROLE;
ROLLBACK;
