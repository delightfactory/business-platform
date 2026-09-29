BEGIN;
SELECT plan(39);

SELECT ok(
  NOT has_schema_privilege('authenticated', 'platform_private', 'USAGE'),
  'authenticated users cannot access the private Platform schema'
);
SELECT ok(
  NOT has_schema_privilege('service_role', 'platform_private', 'USAGE'),
  'service_role cannot access the private Platform schema'
);
SELECT ok(
  NOT has_function_privilege('authenticated', 'platform_private.bootstrap_operator_manager(uuid)', 'EXECUTE'),
  'bootstrap is not executable by authenticated users'
);
SELECT ok(
  NOT has_function_privilege('service_role', 'platform_private.recover_operator_manager(uuid,text,boolean)', 'EXECUTE'),
  'recovery is not executable by service_role'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'platform_private.platform_operator_grants', 'SELECT'),
  'service_role cannot read operator grants directly'
);

INSERT INTO auth.users (id, aud, role, email, encrypted_password, invited_at, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
VALUES
  ('a15c3b4e-18a9-4aa0-91c9-a00000000001', 'authenticated', 'authenticated', 'bootstrap-one@example.test', 'hash', NULL, pg_catalog.now(), '{}'::jsonb, '{}'::jsonb),
  ('a15c3b4e-18a9-4aa0-91c9-a00000000002', 'authenticated', 'authenticated', 'bootstrap-two@example.test', 'hash', NULL, pg_catalog.now(), '{}'::jsonb, '{}'::jsonb),
  ('a15c3b4e-18a9-4aa0-91c9-a00000000003', 'authenticated', 'authenticated', 'bootstrap-three@example.test', 'hash', NULL, pg_catalog.now(), '{}'::jsonb, '{}'::jsonb),
  ('a15c3b4e-18a9-4aa0-91c9-a00000000004', 'authenticated', 'authenticated', 'bootstrap-four-unconfirmed@example.test', 'hash', NULL, NULL, '{}'::jsonb, '{}'::jsonb),
  ('a15c3b4e-18a9-4aa0-91c9-a00000000006', 'authenticated', 'authenticated', 'bootstrap-six-invited-unready@example.test', 'invite-hash', pg_catalog.now(), pg_catalog.now(), '{}'::jsonb, '{}'::jsonb),
  ('a15c3b4e-18a9-4aa0-91c9-a00000000008', 'authenticated', 'authenticated', 'bootstrap-eight@example.test', 'hash', NULL, pg_catalog.now(), '{}'::jsonb, '{}'::jsonb);

SELECT throws_ok(
  $$SELECT platform_private.bootstrap_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000004'::uuid)$$,
  '22023',
  'The target must be an existing, enabled Auth user with a verified email',
  'bootstrap refuses an Auth user who cannot sign in with verified email'
);
SELECT throws_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000004'::uuid, 'unverified target check', false)$$,
  '22023',
  'The target must be an existing, enabled Auth user with a verified email',
  'recovery refuses an Auth user who cannot sign in with verified email'
);
SELECT throws_ok(
  $$SELECT platform_private.bootstrap_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000006'::uuid)$$,
  '22023',
  'The target must be an existing, enabled Auth user with a verified email',
  'bootstrap refuses an invited account without password readiness'
);
SELECT throws_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000006'::uuid, 'invited target check', false)$$,
  '22023',
  'The target must be an existing, enabled Auth user with a verified email',
  'recovery refuses an invited account without password readiness'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000004'::uuid),
  0::bigint,
  'an unconfirmed Auth user receives no Platform Operator grant'
);

SELECT lives_ok(
  $$SELECT platform_private.bootstrap_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid)$$,
  'one-time bootstrap grants an existing Auth user manager authority'
);
SELECT is(
  (SELECT is_active FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid),
  true,
  'the bootstrapped grant is active'
);
SELECT is(
  (SELECT can_manage_operators FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid),
  true,
  'the first grant includes operator-management authority'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_audit_events WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid),
  1::bigint,
  'bootstrap persists exactly one audit event with its grant'
);
SELECT is(
  (SELECT actor_class FROM platform_private.platform_operator_audit_events WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid),
  'platform_bootstrap',
  'infrastructure execution is recorded as the bootstrap actor class'
);
SELECT throws_ok(
  $$SELECT platform_private.bootstrap_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid)$$,
  '55000',
  'A Platform Operator manager already exists; bootstrap is one-time',
  'bootstrap refuses to run after the first manager exists'
);
SELECT throws_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid, '   ', false)$$,
  '22023',
  'A non-empty recovery reason is required',
  'recovery requires a non-empty reason'
);
SELECT throws_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000005'::uuid, 'restore manager access', false)$$,
  '22023',
  'The target must be an existing, enabled Auth user with a verified email',
  'recovery refuses a missing Auth principal'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000005'::uuid),
  0::bigint,
  'failed recovery does not leave an authority grant'
);
SELECT throws_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid, 'undeclared incident', false)$$,
  '55000',
  'A recoverable manager is active; declare and explain an emergency to recover another',
  'recovery cannot add a manager over an active manager without emergency declaration'
);

SELECT lives_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid, 'declared emergency manager redundancy exercise', true)$$,
  'recovery succeeds with an explicit emergency and reason'
);
SELECT is(
  (SELECT reason FROM platform_private.platform_operator_audit_events WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid),
  'declared emergency manager redundancy exercise',
  'the recovery reason is retained in audit'
);
SELECT is(
  (SELECT is_emergency FROM platform_private.platform_operator_audit_events WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid),
  true,
  'the emergency declaration is retained in audit'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_grants WHERE is_active AND can_manage_operators),
  2::bigint,
  'emergency recovery adds another active manager'
);

UPDATE auth.users
SET banned_until = pg_catalog.now() + interval '1 day'
WHERE id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid;
SELECT throws_ok(
  $$DELETE FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid$$,
  '23514',
  'The final active Platform Operator manager cannot be removed',
  'a banned manager is not a recoverable replacement for the manager being removed'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid AND is_active AND can_manage_operators),
  1::bigint,
  'the recoverable manager remains active when the only alternative is banned'
);
UPDATE auth.users SET banned_until = NULL
WHERE id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid;

SELECT lives_ok(
  $$DELETE FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000001'::uuid$$,
  'a manager may be removed while another active manager remains'
);
SELECT throws_ok(
  $$UPDATE platform_private.platform_operator_grants SET is_active = false, can_manage_operators = false WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid$$,
  '23514',
  'The final active Platform Operator manager cannot be removed',
  'the final active manager cannot be revoked'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_grants WHERE is_active AND can_manage_operators),
  1::bigint,
  'the last-manager guard leaves the final manager active'
);
SELECT throws_ok(
  $$DELETE FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid$$,
  '23514',
  'The final active Platform Operator manager cannot be removed',
  'the final active manager cannot be deleted'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_grants WHERE is_active AND can_manage_operators),
  1::bigint,
  'the last-manager guard also preserves the row against deletion'
);
UPDATE auth.users SET banned_until = pg_catalog.now() + interval '1 day'
WHERE id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid;
SELECT lives_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000008'::uuid, 'recover after remaining manager became unavailable', false)$$,
  'maintenance recovery proceeds without emergency when the active grant is not recoverable'
);
SELECT is(
  (SELECT is_emergency FROM platform_private.platform_operator_audit_events WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000008'::uuid),
  false,
  'non-emergency recovery is audited without an emergency declaration'
);
SELECT ok(
  (SELECT is_active AND can_manage_operators FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000008'::uuid),
  'recovery creates an active manager grant'
);
SELECT throws_ok(
  $$UPDATE platform_private.platform_operator_audit_events SET reason = 'rewritten' WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid$$,
  '55000',
  'Platform Operator audit events are append-only',
  'persisted audit events cannot be updated'
);
SELECT throws_ok(
  $$DELETE FROM platform_private.platform_operator_audit_events WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000002'::uuid$$,
  '55000',
  'Platform Operator audit events are append-only',
  'persisted audit events cannot be deleted'
);

CREATE FUNCTION platform_private.fail_test_operator_audit_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION 'forced audit persistence failure' USING ERRCODE = 'P0001';
END;
$function$;
CREATE TRIGGER fail_test_operator_audit_insert
BEFORE INSERT ON platform_private.platform_operator_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_private.fail_test_operator_audit_insert();

SELECT throws_ok(
  $$SELECT platform_private.recover_operator_manager('a15c3b4e-18a9-4aa0-91c9-a00000000003'::uuid, 'audit atomicity check', true)$$,
  'P0001',
  'forced audit persistence failure',
  'audit persistence failure aborts the protected grant transaction'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_grants WHERE user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000003'::uuid),
  0::bigint,
  'failed audit insertion rolls back the recovered grant'
);
SELECT is(
  (SELECT count(*) FROM platform_private.platform_operator_audit_events WHERE target_user_id = 'a15c3b4e-18a9-4aa0-91c9-a00000000003'::uuid),
  0::bigint,
  'failed audit insertion leaves no success audit'
);

SELECT * FROM finish();
ROLLBACK;
