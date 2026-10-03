SELECT no_plan();
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) VALUES
 ('f1400000-0000-4000-8000-000000000001','authenticated','authenticated','compliance-manager@example.test','hash',now(),'{}','{}',now(),now()),
 ('f1400000-0000-4000-8000-000000000002','authenticated','authenticated','compliance-target@example.test','hash',now(),'{}','{}',now(),now()),
 ('f1400000-0000-4000-8000-000000000003','authenticated','authenticated','ordinary-operator@example.test','hash',now(),'{}','{"statutory_rules.manage":true}',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants) VALUES
 ('f1400000-0000-4000-8000-000000000001',true,true,false),('f1400000-0000-4000-8000-000000000003',true,false,true);
SELECT ok(NOT has_function_privilege('anon','public.current_operator_can_manage_statutory_rules()','EXECUTE'),'anonymous cannot inspect Compliance capability');
SELECT ok(NOT has_function_privilege('service_role','public.change_platform_operator_authority(text,text,boolean,boolean,boolean,boolean,boolean,text)','EXECUTE'),'infrastructure role has no product authority endpoint');
SELECT ok(NOT has_table_privilege('authenticated','platform_private.platform_operator_grants','UPDATE'),'authority cannot be edited directly');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1400000-0000-4000-8000-000000000003',true);
SELECT ok(NOT public.current_operator_can_manage_statutory_rules(),'ordinary Operator and user metadata do not confer Compliance');
SELECT throws_ok($$SELECT public.change_platform_operator_authority('compliance-target@example.test','grant',false,false,false,false,true,'Explicit Compliance assignment')$$,'42501','platform_operator_manage_forbidden','ordinary Operator cannot grant Compliance');
SELECT set_config('request.jwt.claim.sub','f1400000-0000-4000-8000-000000000001',true);
SELECT ok(NOT public.current_operator_can_manage_statutory_rules(),'Operator manager does not inherit Compliance');
SELECT is(public.change_platform_operator_authority('compliance-target@example.test','grant',false,false,false,false,true,'Explicit Compliance assignment')->>'state','grant','manager can grant Compliance alone without unrelated administrative powers');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(public.platform_operator_grant_list())g WHERE g->>'email'='compliance-target@example.test' AND g->>'can_manage_statutory_rules'='true'),'grant workspace reports explicitly assigned Compliance');
RESET ROLE;
SELECT is((SELECT before_state::text FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1400000-0000-4000-8000-000000000002'),'null','first grant preserves absent prior authority');
SELECT is((SELECT after_state->>'can_manage_statutory_rules' FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1400000-0000-4000-8000-000000000002'),'true','audit captures resulting Compliance authority');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1400000-0000-4000-8000-000000000002',true);
SELECT ok(public.current_operator_can_manage_statutory_rules(),'explicit Compliance grant authorizes current verified account');
SELECT ok(NOT public.current_operator_can_manage_operators() AND NOT public.current_operator_can_onboard_tenants() AND NOT public.current_operator_can_manage_commercial_access() AND NOT public.current_operator_can_manage_tenant_lifecycle(),'Compliance alone does not confer other Operator tasks');
SELECT throws_ok($$SELECT public.platform_operator_grant_list()$$,'42501','platform_operator_manage_forbidden','Compliance cannot inspect or manage other grants');
RESET ROLE;
UPDATE auth.users SET banned_until=now()+interval '1 day' WHERE id='f1400000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT ok(NOT public.current_operator_can_manage_statutory_rules(),'ban immediately invalidates Compliance authority');
RESET ROLE;
UPDATE auth.users SET banned_until=NULL WHERE id='f1400000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1400000-0000-4000-8000-000000000001',true);
SELECT is(public.change_platform_operator_grant('compliance-target@example.test','update',false,true,false,false,'Legacy client adds onboarding')->>'can_manage_statutory_rules','true','legacy update preserves explicitly assigned Compliance');
SELECT is(public.change_platform_operator_authority('compliance-target@example.test','update',false,true,false,false,false,'Remove Compliance task')->>'can_manage_statutory_rules','false','new workspace can remove only Compliance and keep onboarding');
SELECT is(public.change_platform_operator_authority('compliance-target@example.test','update',false,true,false,false,true,'Restore Compliance task')->>'state','update','explicit reassignment updates authority');
SELECT is(public.change_platform_operator_grant('compliance-target@example.test','revoke',false,false,false,false,'Revoke all Operator authority')->>'can_manage_statutory_rules','false','legacy revoke clears Compliance atomically');
SELECT set_config('request.jwt.claim.sub','f1400000-0000-4000-8000-000000000002',true);
SELECT ok(NOT public.current_operator_can_manage_statutory_rules(),'revoked Operator cannot retain Compliance');
SELECT set_config('request.jwt.claim.sub','f1400000-0000-4000-8000-000000000001',true);
SELECT is(public.change_platform_operator_grant('compliance-target@example.test','grant',false,true,false,false,'Reactivate only onboarding')->>'can_manage_statutory_rules','false','legacy reactivation cannot resurrect Compliance');
SELECT throws_ok($$SELECT public.change_platform_operator_authority('compliance-manager@example.test','update',false,false,false,false,true,'Keep only Compliance')$$,'23514','platform_operator_last_manager','Compliance cannot bypass last Operator-manager protection');
SELECT throws_ok($$SELECT public.change_platform_operator_authority('compliance-target@example.test','update',false,false,false,false,false,'Remove every task')$$,'22023','platform_operator_capability_required','empty grant still requires explicit revocation');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_private.platform_operator_audit_events WHERE target_user_id='f1400000-0000-4000-8000-000000000002'),6,'six distinct authority transitions have exactly six audit records');
SELECT * FROM finish();
