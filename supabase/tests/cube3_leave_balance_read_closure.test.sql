BEGIN;
SELECT no_plan();
SELECT ok(NOT has_function_privilege('authenticated','leave.authorized_balance_read(uuid)','EXECUTE'),
 'authenticated callers cannot invoke the private balance authorization helper');
SELECT ok(NOT has_function_privilege('authenticated','leave.balance_pair_snapshot(uuid,uuid,uuid)','EXECUTE'),
 'authenticated callers cannot bypass public scope checks through the private pair helper');
SELECT ok(has_function_privilege('authenticated',rpc.signature,'EXECUTE'),rpc.label||' is callable through the authenticated boundary')
 FROM (VALUES
 ('public.leave_balance_employee_options(uuid,text,uuid,text,uuid,uuid,integer)','balance Employee selector'),
 ('public.leave_balance_accounts(uuid,uuid,uuid,date,uuid,integer)','balance accounts'),
 ('public.leave_balance_ledger(uuid,uuid,uuid,uuid,timestamp with time zone,uuid,integer)','balance ledger'),
 ('public.leave_balance_posting_periods(uuid,uuid,uuid,date,uuid,integer)','posting periods'),
 ('public.leave_balance_posting_types(uuid,uuid,uuid,uuid,text,text,uuid,integer)','posting types')
 ) rpc(signature,label);
SELECT ok(NOT has_function_privilege(denied.role_name,rpc.signature,'EXECUTE'),rpc.label||' denies '||denied.role_name||' execution')
 FROM (VALUES
 ('public.leave_balance_employee_options(uuid,text,uuid,text,uuid,uuid,integer)','balance Employee selector'),
 ('public.leave_balance_accounts(uuid,uuid,uuid,date,uuid,integer)','balance accounts'),
 ('public.leave_balance_ledger(uuid,uuid,uuid,uuid,timestamp with time zone,uuid,integer)','balance ledger'),
 ('public.leave_balance_posting_periods(uuid,uuid,uuid,date,uuid,integer)','posting periods'),
 ('public.leave_balance_posting_types(uuid,uuid,uuid,uuid,text,text,uuid,integer)','posting types')
 ) rpc(signature,label) CROSS JOIN (VALUES('anon'),('service_role')) denied(role_name);
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

-- HR recorder, approver, manager-only actor, and two Employees. All workflow
-- effects below are exercised through authenticated public RPCs.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('b5100000-0000-4000-8000-000000000001','correction-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('b5100000-0000-4000-8000-000000000002','correction-approver@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('b5100000-0000-4000-8000-000000000003','correction-manager-only@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('b5100000-0000-4000-8000-000000000004','correction-other-employee@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
 VALUES('b5101000-0000-4000-8000-000000000001','Leave correction test','b5100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('b5101000-0000-4000-8000-000000000001','b5102000-0000-4000-8000-000000000001','corr.manage.approve.v1',1,ARRAY['leave.manage','leave.view','leave.approve','leave_balance.adjust'],false),
 ('b5101000-0000-4000-8000-000000000001','b5102000-0000-4000-8000-000000000002','corr.approve.v1',1,ARRAY['leave.view'],false),
 ('b5101000-0000-4000-8000-000000000001','b5102000-0000-4000-8000-000000000003','corr.manage.v1',1,ARRAY['leave.manage','leave.view','leave_balance.adjust'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000001'),
 ('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000002','b5100000-0000-4000-8000-000000000001'),
 ('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000003','b5100000-0000-4000-8000-000000000001'),
 ('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000004','b5100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000001','b5102000-0000-4000-8000-000000000001'),
 ('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000002','b5102000-0000-4000-8000-000000000002'),
 ('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000003','b5102000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)
 VALUES('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001','Correction Employer',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES
 ('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','BAL-A','Correction Employee A','b5100000-0000-4000-8000-000000000001'),
 ('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000002','BAL-B','Correction Employee B','b5100000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis) VALUES
 ('b5101000-0000-4000-8000-000000000001','b5105000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.today')::date-30,'active','monthly'),
 ('b5101000-0000-4000-8000-000000000001','b5105000-0000-4000-8000-000000000002','b5104000-0000-4000-8000-000000000002','b5103000-0000-4000-8000-000000000001',current_setting('test.today')::date-30,'active','monthly');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('b5101000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','b5100000-0000-4000-8000-000000000001','correction test'),
 ('b5101000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','b5100000-0000-4000-8000-000000000001','correction test');

-- Establish one long-lived calendar and nonoverlapping retained/current periods.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001','corr-calendar','Correction Calendar',current_setting('test.today')::date-30,NULL,ARRAY[5,6]::smallint[],'[]'::jsonb,'Test calendar','Explicit correction fixture')::text,true);
SELECT set_config('test.old_period',public.leave_create_year_period('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date-30,current_setting('test.today')::date-1,'Retained period','Historical FIFO provenance')::text,true);
SELECT set_config('test.period',public.leave_create_year_period('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date,current_setting('test.today')::date+90,'Current period','Current correction fixtures')::text,true);
SELECT set_config('test.type_a',public.leave_create_type('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001','corr-a','Tracked type A',current_setting('test.today')::date-30,'paid','tracked',true,'Test policy','Explicit tracked policy','calendar_days')::text,true);
SELECT set_config('test.type_b',public.leave_create_type('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001','corr-b','Tracked type B',current_setting('test.today')::date-30,'paid','tracked',true,'Test policy','Second tracked policy','calendar_days')::text,true);
SELECT set_config('test.type_c',public.leave_create_type('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001','corr-c','Tracked type C',current_setting('test.today')::date-30,'paid','tracked',true,'Test policy','No balance policy','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.date1',(current_setting('test.today')::date + (7-extract(isodow FROM current_setting('test.today')::date)::integer)%7 + 7)::text,true);
SELECT set_config('test.date2',(current_setting('test.date1')::date+1)::text,true);
SELECT set_config('test.date3',(current_setting('test.date1')::date+2)::text,true);
SELECT set_config('test.type_a_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type_a')::uuid AND version=1),true);
SELECT set_config('test.type_b_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type_b')::uuid AND version=1),true);
SELECT set_config('test.type_c_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type_c')::uuid AND version=1),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.old_account',public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.old_period')::uuid,'opening',0.25,current_setting('test.type_a_version')::uuid,'corr-old-opening','Verified retained fractional balance','Correction FIFO opening')->>'account_id',true);
SELECT set_config('test.a_account',public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.period')::uuid,'opening',4.00,current_setting('test.type_a_version')::uuid,'corr-a-opening','Verified test balance','Correction opening A')->>'account_id',true);
SELECT set_config('test.b_account',public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_b')::uuid,current_setting('test.period')::uuid,'opening',2.00,current_setting('test.type_b_version')::uuid,'corr-b-opening','Verified test balance','Correction opening B')->>'account_id',true);
RESET ROLE;

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('b5100000-0000-4000-8000-000000000005','balance-adjust-only@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES('b5101000-0000-4000-8000-000000000001','b5102000-0000-4000-8000-000000000005','balance.adjust.only.v1',1,ARRAY['leave_balance.adjust'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000005','b5100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000005','b5102000-0000-4000-8000-000000000005');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active) VALUES('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000002','Unrelated employer',false,true);
SELECT ok(NOT platform_private.has_tenant_permission('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000005','people.view') AND NOT platform_private.has_tenant_permission('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000005','leave.view') AND NOT platform_private.has_tenant_permission('b5101000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000005','leave.manage'),'adjust-only role gets no broader People or Leave view/manage permission');
SELECT ok(NOT has_function_privilege('anon','public.leave_balance_ledger(uuid,uuid,uuid,uuid,timestamptz,uuid,integer)','EXECUTE'),'anonymous has no ledger RPC access');
SELECT ok(NOT has_function_privilege('service_role','public.leave_balance_accounts(uuid,uuid,uuid,date,uuid,integer)','EXECUTE'),'service role cannot bypass balance read authority');
SELECT ok(NOT has_function_privilege('authenticated','leave.balance_pair_snapshot(uuid,uuid,uuid)','EXECUTE'),'private pair helper is not directly callable');
SELECT ok(NOT has_table_privilege('authenticated','leave.ledger_entries','SELECT'),'ledger remains private');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000005',true);
SELECT set_config('test.search1',public.leave_balance_employee_options('b5101000-0000-4000-8000-000000000001','BAL-',NULL,NULL,NULL,NULL,1)::text,true);
SELECT is(jsonb_array_length(current_setting('test.search1')::jsonb->'items'),1,'bounded Employee search returns one row');
SELECT is(current_setting('test.search1')::jsonb->>'has_more','true','Employee page proves another result');
SELECT set_config('test.search2',public.leave_balance_employee_options('b5101000-0000-4000-8000-000000000001','BAL-',NULL,current_setting('test.search1')::jsonb->>'next_after_code',(current_setting('test.search1')::jsonb->>'next_after_employee')::uuid,(current_setting('test.search1')::jsonb->>'next_after_employer')::uuid,1)::text,true);
SELECT isnt(current_setting('test.search1')::jsonb->'items'->0->>'employee_id',current_setting('test.search2')::jsonb->'items'->0->>'employee_id','Employee cursor advances without duplicate pair');
SELECT is(jsonb_array_length(public.leave_balance_employee_options('b5101000-0000-4000-8000-000000000001','%_',NULL,NULL,NULL,NULL,20)->'items'),0,'search treats wildcard characters literally');
SELECT is(jsonb_array_length(public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000002','b5103000-0000-4000-8000-000000000001')->'items'),0,'Employee without User or Leave account has inspectable empty balance state');
SELECT is(public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000002','b5103000-0000-4000-8000-000000000001')->'employee'->>'can_post','true','accountless active Employee remains eligible for manual posting');
SELECT set_config('test.accounts1',public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',NULL,NULL,1)::text,true);
SELECT is(current_setting('test.accounts1')::jsonb->'items'->0->>'account_id',current_setting('test.old_account'),'expired period balance remains first and visible');
SELECT is((current_setting('test.accounts1')::jsonb->'items'->0->>'balance_days')::numeric,0.25::numeric,'retained period remainder does not expire');
SELECT set_config('test.accounts2',public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',(current_setting('test.accounts1')::jsonb->>'next_after_period_start')::date,(current_setting('test.accounts1')::jsonb->>'next_after_account')::uuid,1)::text,true);
SELECT isnt(current_setting('test.accounts1')::jsonb->'items'->0->>'account_id',current_setting('test.accounts2')::jsonb->'items'->0->>'account_id','account cursor advances across period boundary');
SELECT throws_ok($test$SELECT public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000002')$test$,'P0002','leave_balance_scope_unavailable','same-Tenant mismatched Employer is rejected');
SELECT throws_ok($test$SELECT public.leave_balance_ledger('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000002','b5103000-0000-4000-8000-000000000001',current_setting('test.a_account')::uuid)$test$,'P0002','leave_balance_scope_unavailable','account ID cannot bypass selected Employee scope');
SELECT throws_ok($test$SELECT public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000099','b5103000-0000-4000-8000-000000000001')$test$,'P0002','leave_balance_scope_unavailable','missing/cross-scope Employee gives scoped unavailable');
SELECT throws_ok($test$SELECT public.leave_balance_accounts('b5101000-0000-4000-8000-000000000099','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001')$test$,'42501','leave_forbidden','wrong Tenant fails current authority before lookup');
SELECT throws_ok($test$SELECT public.leave_balance_employee_options('b5101000-0000-4000-8000-000000000001','BAL-',NULL,'BAL-A',NULL,NULL,20)$test$,'22023','leave_balance_search_input_invalid','partial Employee cursor rejected');
SELECT throws_ok($test$SELECT public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',NULL,NULL,101)$test$,'22023','leave_balance_accounts_input_invalid','oversized account limit rejected');
SELECT throws_ok($test$SELECT public.leave_balance_ledger('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.a_account')::uuid,now(),NULL,50)$test$,'22023','leave_balance_ledger_input_invalid','partial ledger cursor rejected');
SELECT set_config('test.types1',public.leave_balance_posting_types('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'opening',NULL,NULL,1)::text,true);
SELECT is(current_setting('test.types1')::jsonb->'items'->0->>'can_post','false','existing one-opening account cannot get another opening');
SELECT is(current_setting('test.types1')::jsonb->'items'->0->>'posting_blocked_reason','opening_already_posted','opening uniqueness is explicit');
SELECT set_config('test.types2',public.leave_balance_posting_types('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'opening',current_setting('test.types1')::jsonb->>'next_after_code',(current_setting('test.types1')::jsonb->>'next_after_type')::uuid,1)::text,true);
SELECT isnt(current_setting('test.types1')::jsonb->'items'->0->>'leave_type_id',current_setting('test.types2')::jsonb->'items'->0->>'leave_type_id','type cursor advances without dropping tie identity');
SELECT set_config('test.periods1',public.leave_balance_posting_periods('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',NULL,NULL,1)::text,true);
SELECT is(public.leave_balance_posting_periods('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',(current_setting('test.periods1')::jsonb->>'next_after_start')::date,(current_setting('test.periods1')::jsonb->>'next_after_period')::uuid,1)->'items'->0->>'period_id',current_setting('test.period'),'period cursor includes current period after retained period');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000001',true);
SELECT public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.period')::uuid,'annual_grant',1,current_setting('test.type_a_version')::uuid,'balance-grant-one','Audited manual grant evidence','Verified manual one day');
SELECT public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.period')::uuid,'adjustment',-0.25,current_setting('test.type_a_version')::uuid,'balance-adjust-one','Correction source evidence','Verified fractional adjustment');
SELECT public.leave_revise_type('b5101000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.today')::date+1,'paid','tracked','calendar_days',true,'Prospective revised source','Explicit prospective revision');
SELECT set_config('test.future_period',public.leave_create_year_period('b5101000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date+91,current_setting('test.today')::date+120,'Future test period','Prospective opening provenance')::text,true);
RESET ROLE;
SELECT set_config('test.type_a_v2',(SELECT id::text FROM leave.type_versions WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type_a')::uuid AND version=2),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000005',true);
SELECT set_config('test.eligible_open',public.leave_balance_posting_types('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.old_period')::uuid,'opening')::text,true);
SELECT is(current_setting('test.eligible_open')::jsonb->'items'->0->>'type_version_id',current_setting('test.type_a_version'),'opening resolves exact period-start provenance');
SELECT set_config('test.eligible_adjust',public.leave_balance_posting_types('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.old_period')::uuid,'adjustment')::text,true);
SELECT is(current_setting('test.eligible_adjust')::jsonb->'items'->0->>'type_version_id',current_setting('test.type_a_version'),'adjustment resolves Cairo-today provenance rather than the prospective version');
SELECT is(public.leave_balance_posting_types('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.future_period')::uuid,'opening')->'items'->0->>'type_version_id',current_setting('test.type_a_v2'),'future period opening resolves the version effective at that period start');
SELECT is(public.leave_balance_posting_types('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'annual_grant')->'items'->0->>'posting_blocked_reason','annual_grant_already_posted','policy revision does not create a new annual grant period');
SELECT throws_ok($test$SELECT public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.period')::uuid,'annual_grant',1,current_setting('test.type_a_v2')::uuid,'duplicate-grant','New revision evidence','Cannot grant twice')$test$,'23505','leave_annual_grant_exists','actual posting still rejects grant duplicate across versions');
SELECT throws_ok($test$SELECT public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.period')::uuid,'adjustment',-99,current_setting('test.type_a_version')::uuid,'underflow','Audited source','Cannot underflow')$test$,'23514','leave_balance_insufficient','actual posting still prevents underflow');
SELECT set_config('test.ledger1',public.leave_balance_ledger('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.a_account')::uuid,NULL,NULL,1)::text,true);
SELECT is((current_setting('test.ledger1')::jsonb->'account'->>'balance_days')::numeric,4.75::numeric,'ledger summary is full server-computed balance independent of page size');
SELECT set_config('test.ledger2',public.leave_balance_ledger('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.a_account')::uuid,(current_setting('test.ledger1')::jsonb->>'next_before_created_at')::timestamptz,(current_setting('test.ledger1')::jsonb->>'next_before_entry')::uuid,1)::text,true);
SELECT isnt(current_setting('test.ledger1')::jsonb->'items'->0->>'entry_id',current_setting('test.ledger2')::jsonb->'items'->0->>'entry_id','ledger cursor advances across identical transaction timestamps');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.source',public.leave_record_hr_request('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5105000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date1')::date,current_setting('test.date1')::date,false,NULL,'Balance history source','balance-record-source')->>'id',true);
SELECT set_config('test.replacement',public.leave_record_hr_request('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5105000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date1')::date,current_setting('test.date1')::date,false,NULL,'Balance history replacement','balance-record-replacement')->>'id',true);
SELECT public.leave_approve_request('b5101000-0000-4000-8000-000000000001',current_setting('test.source')::uuid,1,1,'Approve original evidence','balance-original-approval');
SELECT public.leave_correct_approved_request('b5101000-0000-4000-8000-000000000001',current_setting('test.source')::uuid,2,1,current_setting('test.replacement')::uuid,1,1,'Governed balance source correction','balance-correction');
SELECT public.leave_cancel_approved_request('b5101000-0000-4000-8000-000000000001',current_setting('test.replacement')::uuid,2,'Approved Leave cancellation evidence','balance-cancel');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000005',true);
SELECT set_config('test.history',public.leave_balance_ledger('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.a_account')::uuid)::text,true);
SELECT ok((SELECT bool_or(x->>'entry_kind'='correction_reversal' AND x->>'reversal_of_entry_id' IS NOT NULL AND x->'request_consumption'->>'request_id'=current_setting('test.source') AND jsonb_array_length(x->'correction_links')=1) FROM jsonb_array_elements(current_setting('test.history')::jsonb->'items') x),'correction reversal includes original allocation and linked replacement provenance');
SELECT ok((SELECT bool_or(x->>'entry_kind'='cancellation_reversal' AND x->>'reversal_of_entry_id' IS NOT NULL AND x->'request_consumption'->>'request_id'=current_setting('test.replacement') AND x->'request_consumption'->>'request_state'='cancelled') FROM jsonb_array_elements(current_setting('test.history')::jsonb->'items') x),'cancellation reversal includes exact cancelled source allocation');
SELECT ok((SELECT bool_and(x->>'actor_user_id' IS NOT NULL AND x->>'source_reference' IS NOT NULL AND x->>'reason' IS NOT NULL) FROM jsonb_array_elements(current_setting('test.history')::jsonb->'items') x),'each ledger row remains attributable and source-backed');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000002',true);
SELECT is(public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001')->'employee'->>'can_adjust','false','view-only can inspect without adjusting');
SELECT throws_ok($test$SELECT public.leave_balance_posting_periods('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001')$test$,'42501','leave_forbidden','view-only cannot inspect posting selectors');
RESET ROLE;
UPDATE people.employments SET employment_status='ended',end_date=current_setting('test.today')::date-1 WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND employee_id='b5104000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000005',true);
SELECT is(public.leave_balance_posting_periods('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000002','b5103000-0000-4000-8000-000000000001')->'employee'->>'posting_blocked_reason','active_employment_required','ended Employment alone blocks new posting while retaining configuration reads');
RESET ROLE;
UPDATE platform_core.tenant_legal_entities SET is_default=false,is_active=false WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND id='b5103000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000005',true);
SELECT is(public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000002','b5103000-0000-4000-8000-000000000001')->'employee'->>'can_post','false','ended Employment and inactive Employer retain historical inspection with posting blocked');
SELECT is(jsonb_array_length(public.leave_balance_employee_options('b5101000-0000-4000-8000-000000000001','BAL-')->'items'),2,'historical search retains ended Employee and inactive Employer');
RESET ROLE;
UPDATE platform_core.tenant_legal_entities SET is_default=true,is_active=true WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND id='b5103000-0000-4000-8000-000000000001';
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now() WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND capability_key='hr.leave';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000005',true);
SELECT ok(jsonb_array_length(public.leave_balance_ledger('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.a_account')::uuid)->'items')>0,'disabled entitlement preserves scoped historical ledger');
SELECT is(public.leave_balance_posting_periods('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001')->'employee'->>'posting_blocked_reason','new_work_disabled','posting selector remains readable but denies disabled new work');
SELECT throws_ok($test$SELECT public.leave_post_balance('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.period')::uuid,'adjustment',-0.01,current_setting('test.type_a_version')::uuid,'disabled-adjust','Historical source','Disabled adjustment denied')$test$,'55000','leave_new_work_disabled','disabled service does not allow a new negative adjustment');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='b5101000-0000-4000-8000-000000000001' AND user_id='b5100000-0000-4000-8000-000000000005';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b5100000-0000-4000-8000-000000000005',true);
SELECT throws_ok($test$SELECT public.leave_balance_accounts('b5101000-0000-4000-8000-000000000001','b5104000-0000-4000-8000-000000000001','b5103000-0000-4000-8000-000000000001')$test$,'42501','leave_forbidden','inactive membership loses historical balance access');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
