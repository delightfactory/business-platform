BEGIN;
SELECT plan(7);

SELECT has_function('public', 'current_platform_operator_status', ARRAY[]::name[], 'narrow caller status RPC exists');
SELECT ok(NOT has_function_privilege('anon', 'public.current_platform_operator_status()', 'EXECUTE'), 'anon cannot execute the status RPC');
SELECT ok(has_function_privilege('authenticated', 'public.current_platform_operator_status()', 'EXECUTE'), 'authenticated can execute the status RPC');
SELECT ok(NOT has_function_privilege('service_role', 'public.current_platform_operator_status()', 'EXECUTE'), 'service_role has no web execution grant');

INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES
 ('a1000000-0000-4000-8000-000000000001', 'operator-a@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('a1000000-0000-4000-8000-000000000002', 'operator-b@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now()),
 ('a1000000-0000-4000-8000-000000000003', 'operator-c@example.test', '', now(), '{}'::jsonb, '{}'::jsonb, 'authenticated', 'authenticated', now(), now());
INSERT INTO platform_private.platform_operator_grants (user_id, is_active, can_manage_operators)
VALUES ('a1000000-0000-4000-8000-000000000001', true, true), ('a1000000-0000-4000-8000-000000000002', false, false);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);
SELECT is((SELECT public.current_platform_operator_status()), 'active', 'current active operator is recognized');
SELECT set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000002', true);
SELECT is((SELECT public.current_platform_operator_status()), 'revoked', 'current revoked grant is denied');
SELECT set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000003', true);
SELECT is((SELECT public.current_platform_operator_status()), 'not_operator', 'caller without a grant is not an operator');
RESET ROLE;
ROLLBACK;
