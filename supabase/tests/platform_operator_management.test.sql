BEGIN;
SELECT no_plan();

SELECT has_function('public','current_operator_can_manage_operators',ARRAY[]::name[],'current manager capability RPC exists');
SELECT has_function('public','current_operator_can_manage_commercial_access',ARRAY[]::name[],'independent commercial capability RPC exists');
SELECT has_function('public','platform_operator_grant_list',ARRAY[]::name[],'bounded Operator grant list exists');
SELECT has_function('public','change_platform_operator_grant',ARRAY['text','text','boolean','boolean','boolean','boolean','text']::name[],'transactional grant command exists');
SELECT ok(NOT has_function_privilege('anon','public.platform_operator_grant_list()','EXECUTE'),'anon cannot list Operator grants');
SELECT has_function('public','change_platform_operator_grant',ARRAY['text','text','boolean','boolean','boolean','boolean','text']::name[],'single management RPC accepts three independent capabilities');
SELECT ok(pg_catalog.to_regprocedure('public.change_platform_operator_grant(text,text,boolean,boolean,boolean,text)') IS NULL,'legacy grant RPC overload is removed');
SELECT ok(pg_catalog.to_regprocedure('public.change_platform_operator_grant(text,text,boolean,boolean,boolean,boolean,text)') IS NOT NULL,'one replacement signature includes commercial capability');
SELECT ok(NOT has_function_privilege('service_role','public.change_platform_operator_grant(text,text,boolean,boolean,boolean,boolean,text)','EXECUTE'),'service_role has no product grant-management endpoint');
SELECT ok(NOT has_table_privilege('authenticated','platform_private.platform_operator_grants','SELECT'),'authenticated cannot read grant table directly');

INSERT INTO auth.users(id,aud,role,email,encrypted_password,invited_at,email_confirmed_at,banned_until,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
 ('f1000000-0000-4000-8000-000000000001','authenticated','authenticated','manager-a@example.test','hash',NULL,now(),NULL,'{}','{}',now(),now()),
 ('f1000000-0000-4000-8000-000000000002','authenticated','authenticated','onboard-only@example.test','hash',NULL,now(),NULL,'{}','{}',now(),now()),
 ('f1000000-0000-4000-8000-000000000003','authenticated','authenticated','target-user@example.test','hash',NULL,now(),NULL,'{}','{}',now(),now()),
 ('f1000000-0000-4000-8000-000000000004','authenticated','authenticated','unverified@example.test','hash',NULL,NULL,NULL,'{}','{}',now(),now()),
 ('f1000000-0000-4000-8000-000000000005','authenticated','authenticated','banned@example.test','hash',NULL,now(),now()+interval '1 day','{}','{}',now(),now()),
 ('f1000000-0000-4000-8000-000000000006','authenticated','authenticated','invited-unready@example.test','invite-hash',now(),now(),NULL,'{}','{}',now(),now()),
 ('f1000000-0000-4000-8000-000000000007','authenticated','authenticated','manager-only@example.test','hash',NULL,now(),NULL,'{}','{}',now(),now()),
 ('f1000000-0000-4000-8000-000000000008','authenticated','authenticated','commercial-only@example.test','hash',NULL,now(),NULL,'{}','{}',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access)
VALUES
 ('f1000000-0000-4000-8000-000000000001',true,true,true,false,false),
 ('f1000000-0000-4000-8000-000000000002',true,false,true,false,false),
 ('f1000000-0000-4000-8000-000000000007',true,true,false,false,false),
 ('f1000000-0000-4000-8000-000000000008',true,false,false,false,true);
SELECT throws_ok($$SELECT platform_private.bootstrap_operator_manager('f1000000-0000-4000-8000-000000000006')$$,
  '22023','The target must be an existing, enabled Auth user with a verified email','maintenance bootstrap rejects invited user without password readiness');
SELECT throws_ok($$SELECT platform_private.recover_operator_manager('f1000000-0000-4000-8000-000000000006','recovery readiness check',true)$$,
  '22023','The target must be an existing, enabled Auth user with a verified email','maintenance recovery rejects invited user without password readiness');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT ok(public.current_operator_can_manage_operators(),'manager capability is read from current active grant');
SELECT ok(NOT public.current_operator_can_manage_tenant_lifecycle(),'lifecycle authority is not inherited from other Operator capabilities');
SELECT is(pg_catalog.jsonb_array_length(public.platform_operator_grant_list()),4,'manager sees only bounded grant rows');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('unverified@example.test','grant',false,true,false,false,'valid reason')$$,
  '22023','platform_operator_target_unavailable','unverified account is rejected');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('banned@example.test','grant',false,true,false,false,'valid reason')$$,
  '22023','platform_operator_target_unavailable','banned account is rejected');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('invited-unready@example.test','grant',false,true,false,false,'valid reason')$$,
  '22023','platform_operator_target_unavailable','invited account without password readiness is rejected');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('missing@example.test','grant',false,true,false,false,'valid reason')$$,
  '22023','platform_operator_target_unavailable','missing Auth account cannot receive a grant');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('target-user@example.test','grant',false,false,false,false,'valid reason')$$,
  '22023','platform_operator_capability_required','grant with no task is rejected');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('target-user@example.test','grant',false,true,false,false,'   ')$$,
  '22023','platform_operator_reason_required','grant requires an explicit reason');

SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000002',true);
SELECT ok(NOT public.current_operator_can_manage_operators(),'onboarding-only Operator cannot manage grant authority');
SELECT throws_ok($$SELECT public.platform_operator_grant_list()$$,'42501','platform_operator_manage_forbidden','onboarding-only Operator cannot list grants');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('target-user@example.test','grant',false,true,false,false,'valid reason')$$,
  '42501','platform_operator_manage_forbidden','onboarding-only Operator cannot grant authority');
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000007',true);
SELECT ok(public.current_operator_can_manage_operators(),'manager-only Operator sees management capability');
SELECT ok(NOT public.current_operator_can_onboard_tenants(),'manager-only Operator does not inherit onboarding');
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000008',true);
SELECT ok(public.current_operator_can_manage_commercial_access(),'commercial-only grant enables commercial controls');
SELECT ok(NOT public.current_operator_can_manage_operators(),'commercial task does not imply Operator management');
SELECT ok(NOT public.current_operator_can_onboard_tenants(),'commercial task does not imply onboarding');
SELECT ok(NOT public.current_operator_can_manage_tenant_lifecycle(),'commercial task does not imply lifecycle management');

SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT is(public.change_platform_operator_grant('target-user@example.test','grant',false,true,false,false,'Set up tenant onboarding coverage')->>'state','grant',
  'manager can grant only the onboarding task');
RESET ROLE;
SELECT is((SELECT action FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003'),
  'operator_grant_created','new grant is audited with a distinct action');
SELECT is((SELECT before_state::text FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003'),
  'null','new grant audit records the absent before state');
SELECT is((SELECT after_state->>'can_onboard_tenants' FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003'),
  'true','new grant audit records the resulting task');
SELECT is((SELECT reason FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003'),
  'Set up tenant onboarding coverage','grant reason is retained');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT is(public.change_platform_operator_grant('target-user@example.test','update',true,true,true,true,'Add operator coverage')->>'state','update',
  'manager can explicitly update an active grant with lifecycle authority');
SELECT throws_ok($$SELECT public.change_platform_operator_grant('target-user@example.test','update',false,false,false,false,'Remove all tasks')$$,
  '22023','platform_operator_capability_required','clearing tasks in update cannot silently revoke');
RESET ROLE;
SELECT is((SELECT action FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003' ORDER BY id DESC LIMIT 1),
  'operator_grant_updated','task update is audited');
SELECT is((SELECT before_state->>'can_onboard_tenants' FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003' ORDER BY id DESC LIMIT 1),
  'true','update audit captures before state');
SELECT is((SELECT after_state->>'can_manage_operators' FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003' ORDER BY id DESC LIMIT 1),
  'true','update audit captures after state');
SELECT is((SELECT after_state->>'can_manage_tenant_lifecycle' FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003' ORDER BY id DESC LIMIT 1),
  'true','update audit records independent lifecycle authority');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000003',true);
SELECT ok(public.current_operator_can_manage_tenant_lifecycle(),'the explicit lifecycle task is read from the current grant');
SELECT ok(public.current_operator_can_manage_commercial_access(),'the explicit commercial task is read from the current grant');
RESET ROLE;
SELECT is((SELECT after_state->>'can_manage_commercial_access' FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000003' ORDER BY id DESC LIMIT 1),
  'true','commercial capability is included in grant before/after audit');
RESET ROLE;

CREATE FUNCTION platform_private.fail_test_operator_management_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  IF NEW.action='operator_grant_updated' THEN RAISE EXCEPTION 'operator_management_audit_failure' USING ERRCODE='55000'; END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER fail_test_operator_management_audit BEFORE INSERT ON platform_private.platform_operator_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_private.fail_test_operator_management_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.change_platform_operator_grant('target-user@example.test','update',false,true,false,false,'Audit rollback check')$$,
  '55000','operator_management_audit_failure','audit failure aborts the permission update');
RESET ROLE;
DROP TRIGGER fail_test_operator_management_audit ON platform_private.platform_operator_audit_events;
DROP FUNCTION platform_private.fail_test_operator_management_audit();
SELECT is((SELECT can_manage_operators FROM platform_private.platform_operator_grants WHERE user_id='f1000000-0000-4000-8000-000000000003'),
  true,'audit failure leaves the prior capability intact');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT is(public.change_platform_operator_grant('manager-only@example.test','revoke',false,false,false,false,'Remove redundant manager duty')->>'state','revoke',
  'a recoverable manager can revoke another manager while one remains');
SELECT is(public.change_platform_operator_grant('manager-a@example.test','revoke',false,false,false,false,'Rotate operator duties')->>'state','revoke',
  'manager may revoke self while another recoverable manager remains');
SELECT ok(NOT public.current_operator_can_manage_operators(),'self-revoked manager immediately loses current authority');
RESET ROLE;
SELECT is((SELECT is_active FROM platform_private.platform_operator_grants WHERE user_id='f1000000-0000-4000-8000-000000000001'),
  false,'revocation disables the grant');
SELECT is((SELECT after_state->>'is_active' FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1000000-0000-4000-8000-000000000001' ORDER BY id DESC LIMIT 1),
  'false','revocation audit records the inactive after state');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.change_platform_operator_grant('onboard-only@example.test','revoke',false,false,false,false,'Last manager test')$$,
  '42501','platform_operator_manage_forbidden','onboarding-only Operator cannot revoke last manager');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_private.platform_operator_grants WHERE user_id='f1000000-0000-4000-8000-000000000002' AND is_active),1,
  'failed final-manager removal leaves the grant active');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.change_platform_operator_grant('target-user@example.test','revoke',false,false,false,false,'Last manager test')$$,
  '23514','platform_operator_last_manager','last recoverable manager cannot revoke self');
SELECT is(public.change_platform_operator_grant('manager-a@example.test','grant',false,true,false,false,'Restore onboarding task')->>'state','grant',
  'manager can regrant a previously revoked account');
RESET ROLE;
SELECT ok((SELECT is_active AND NOT can_manage_operators AND can_onboard_tenants FROM platform_private.platform_operator_grants WHERE user_id='f1000000-0000-4000-8000-000000000001'),
  'regrant restores only the explicitly selected task');
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_private.platform_operator_audit_events
  WHERE action IN ('operator_grant_created','operator_grant_updated','operator_grant_revoked')),5,
  'only committed grant changes produce managed-grant audit events');

SELECT * FROM finish();
ROLLBACK;
