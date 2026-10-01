BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

-- Shared seeded identities, two tenants, two active employees and isolated roles.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('cf100000-0000-4000-8000-000000000001','leave-self@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('cf100000-0000-4000-8000-000000000002','leave-hr@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('cf200000-0000-4000-8000-000000000001','Leave tenant A','cf100000-0000-4000-8000-000000000001'),
       ('cf200000-0000-4000-8000-000000000002','Leave tenant B','cf100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('cf200000-0000-4000-8000-000000000001','cf300000-0000-4000-8000-000000000011','test.leave.hr.v1',1,ARRAY['leave.manage','leave.view','leave_balance.adjust'],false),
       ('cf200000-0000-4000-8000-000000000001','cf300000-0000-4000-8000-000000000012','test.leave.self.v1',1,ARRAY['people.self.view','leave.self.view'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('cf200000-0000-4000-8000-000000000001','cf100000-0000-4000-8000-000000000001','cf100000-0000-4000-8000-000000000001'),
       ('cf200000-0000-4000-8000-000000000001','cf100000-0000-4000-8000-000000000002','cf100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('cf200000-0000-4000-8000-000000000001','cf100000-0000-4000-8000-000000000001','cf300000-0000-4000-8000-000000000012'),
       ('cf200000-0000-4000-8000-000000000001','cf100000-0000-4000-8000-000000000002','cf300000-0000-4000-8000-000000000011');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011','Employer A',true),
       ('cf200000-0000-4000-8000-000000000002','cf500000-0000-4000-8000-000000000012','Employer B',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','A-1','Self employee','cf100000-0000-4000-8000-000000000001'),
       ('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000012','A-2','Unlinked employee','cf100000-0000-4000-8000-000000000002'),
       ('cf200000-0000-4000-8000-000000000002','cf400000-0000-4000-8000-000000000013','B-1','Other tenant employee','cf100000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('cf200000-0000-4000-8000-000000000001','cf600000-0000-4000-8000-000000000011','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',(current_setting('test.today')::date)-20,'active','monthly'),
       ('cf200000-0000-4000-8000-000000000001','cf600000-0000-4000-8000-000000000012','cf400000-0000-4000-8000-000000000012','cf500000-0000-4000-8000-000000000011',(current_setting('test.today')::date)-20,'active','monthly'),
       ('cf200000-0000-4000-8000-000000000002','cf600000-0000-4000-8000-000000000013','cf400000-0000-4000-8000-000000000013','cf500000-0000-4000-8000-000000000012',(current_setting('test.today')::date)-20,'active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf100000-0000-4000-8000-000000000001','cf100000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('cf200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','cf100000-0000-4000-8000-000000000002','slice two acceptance'),
       ('cf200000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','cf100000-0000-4000-8000-000000000002','slice two acceptance');

SELECT ok(NOT platform_private.tenant_capability_is_enabled('cf200000-0000-4000-8000-000000000001','hr.attendance',now()),'Leave fixtures run with no Attendance entitlement');

SELECT has_table('leave','calendar_versions','calendar versions are effective dated snapshots');
SELECT has_table('leave','calendar_holidays','holidays are snapshotted by immutable version');
SELECT has_table('leave','calendar_rest_days','weekly rest days are snapshotted by immutable version');
SELECT has_table('leave','year_periods','account years are explicitly configured');
SELECT has_table('leave','type_versions','Leave policy versions are independent of account identity');
SELECT has_table('leave','ledger_entries','balance changes are append-only ledger rows');
SELECT ok(NOT has_table_privilege('authenticated','leave.ledger_entries','SELECT'),'authenticated users cannot query ledger tables directly');
SELECT ok(NOT has_table_privilege('authenticated','leave.accounts','SELECT'),'authenticated users cannot query account tables directly');
SELECT ok(NOT has_table_privilege('anon','leave.calendar_versions','SELECT'),'anonymous users cannot read private calendar snapshots');
SELECT ok(has_function_privilege('authenticated','public.leave_create_calendar(uuid,uuid,text,text,date,date,smallint[],jsonb,text,text)','EXECUTE'),'authenticated HR command is exposed');
SELECT ok(NOT has_function_privilege('anon','public.leave_create_calendar(uuid,uuid,text,text,date,date,smallint[],jsonb,text,text)','EXECUTE'),'anonymous cannot configure calendars');
SELECT ok(NOT has_function_privilege('service_role','public.leave_post_balance(uuid,uuid,uuid,uuid,uuid,text,numeric,uuid,text,text,text)','EXECUTE'),'balance RPC is unavailable to service role');
SELECT ok(has_function_privilege('authenticated','public.leave_access_snapshot(uuid)','EXECUTE'),'authenticated users can read the scoped Leave access snapshot');
SELECT ok(NOT has_function_privilege('anon','public.leave_access_snapshot(uuid)','EXECUTE'),'anonymous users cannot read Leave access');
SELECT ok(NOT has_function_privilege('authenticated','leave.authorized(uuid,text,boolean)','EXECUTE'),'authorization helper remains private');

SELECT ok(EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='leave.accounts'::regclass AND contype='u' AND pg_get_constraintdef(oid) LIKE '%period_id%'),'account uniqueness includes period while not including policy version');
SELECT ok(EXISTS(SELECT 1 FROM pg_index i WHERE i.indexrelid='leave.leave_ledger_one_annual_grant'::regclass AND pg_get_expr(i.indpred,i.indrelid) LIKE '%annual_grant%'),'one annual grant per account is enforced independently of policy version');
SELECT ok(EXISTS(SELECT 1 FROM pg_index i WHERE i.indexrelid='leave.leave_ledger_one_opening'::regclass AND pg_get_expr(i.indpred,i.indrelid) LIKE '%opening%'),'one opening entry per account is enforced independently of idempotency key');
SELECT ok(EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='leave.ledger_entries'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%delta_days%' AND pg_get_constraintdef(oid) NOT LIKE '%0.5%'),'ledger precision supports hundredth-day prorated grants and adjustments');
SELECT ok(EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='leave.type_versions'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%balance_mode%'),'tracked mode is independently represented on Leave type versions');
SELECT ok(EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='leave.type_versions'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%pay_effect%'),'paid effect is independently represented on Leave type versions');
SELECT ok(EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='leave.calendar_versions'::regclass AND contype='x'),'overlapping calendar effective versions are rejected');
SELECT ok(EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='leave.year_periods'::regclass AND contype='x'),'overlapping explicit employer year periods are rejected');
SELECT ok(to_regprocedure('leave.calendar_day_snapshot(uuid,uuid,date)') IS NOT NULL,'calendar resolution is performed for each requested date');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='leave.ledger_entries'::regclass AND tgname='leave_ledger_append_only' AND NOT tgisinternal),'ledger updates and deletes are blocked by trigger');

-- HR configures an effective calendar, explicit year period and independently dimensioned types.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf100000-0000-4000-8000-000000000002',true);
SELECT set_config('test.calendar',public.leave_create_calendar('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011','annual','Annual calendar',(current_setting('test.today')::date)-100,NULL,ARRAY[5,6]::smallint[],jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date)::text,'name','old version holiday')),'HR legal calendar','initial accepted calendar snapshot')::text,true);
SELECT public.leave_revise_calendar('cf200000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,(current_setting('test.today')::date)+1,NULL,ARRAY[extract(dow FROM (current_setting('test.today')::date)+2)::smallint],jsonb_build_array(jsonb_build_object('date',((current_setting('test.today')::date)+2)::text,'name','new version holiday')),'HR legal calendar v2','prospective schedule change');
SELECT is(public.leave_calendar_day('cf200000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,(current_setting('test.today')::date))->>'holiday','old version holiday','authenticated day resolver selects the holiday snapshot effective before the revision');
SELECT is(public.leave_calendar_day('cf200000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,(current_setting('test.today')::date)+2)->>'holiday','new version holiday','authenticated day resolver selects the newly effective holiday snapshot');
SELECT is((public.leave_calendar_day('cf200000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,(current_setting('test.today')::date)+2)->>'is_weekly_rest')::boolean,true,'weekday rest snapshot also changes on its effective date');
SELECT ok(public.leave_configuration_snapshot('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011') ? 'calendars','HR configuration read returns bounded calendar/type/period data');
SELECT set_config('test.period',public.leave_create_year_period('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011',current_setting('test.calendar')::uuid,(current_setting('test.today')::date)-10,(current_setting('test.today')::date)+10,'FY explicit','Approved explicit boundary')::text,true);
SELECT set_config('test.old_period',public.leave_create_year_period('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011',current_setting('test.calendar')::uuid,(current_setting('test.today')::date)-90,(current_setting('test.today')::date)-60,'Prior explicit leave year','Approved prior boundary')::text,true);
SELECT set_config('test.type',public.leave_create_type('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011','annual','Annual leave',(current_setting('test.today')::date)-90,'paid','tracked',true,'HR verified policy v1','explicit reviewed opening and grant values')::text,true);
SELECT set_config('test.untracked_type',public.leave_create_type('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011','untracked','Untracked unpaid leave',(current_setting('test.today')::date)-10,'unpaid','untracked',false,'HR policy','no balance by definition')::text,true);
SELECT throws_ok($$SELECT public.leave_create_type('cf200000-0000-4000-8000-000000000002','cf500000-0000-4000-8000-000000000012','foreign','Foreign type',(current_setting('test.today')::date),'paid','tracked',false,'source','reason')$$,'42501','leave_forbidden','HR permission in Tenant A cannot configure Tenant B');
SELECT throws_ok(format($$SELECT public.leave_create_year_period('cf200000-0000-4000-8000-000000000001','cf500000-0000-4000-8000-000000000011','%s',(current_setting('test.today')::date),(current_setting('test.today')::date)+2,'overlap','overlap should fail')$$,current_setting('test.calendar')),'23P01','conflicting key value violates exclusion constraint "year_periods_tenant_id_employer_entity_id_daterange_excl"','overlapping employer Leave years are rejected');
RESET ROLE;

SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions WHERE leave_type_id=current_setting('test.type')::uuid AND version=1),true);
SELECT set_config('test.untracked_version',(SELECT id::text FROM leave.type_versions WHERE leave_type_id=current_setting('test.untracked_type')::uuid AND version=1),true);

-- Same authenticated HR identity records two employees, with replay and exact-cent precision.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf100000-0000-4000-8000-000000000002',true);
SELECT set_config('test.old_opening',public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.old_period')::uuid,'opening',2.00,current_setting('test.type_version')::uuid,'old-open','HR verified prior balance','prior period opening remains available')::text,true);
SELECT set_config('test.opening',public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',10.00,current_setting('test.type_version')::uuid,'open-1','HR verified opening v1','Opening balance evidenced by signed record')::text,true);
SELECT throws_ok($$SELECT public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',1.00,current_setting('test.type_version')::uuid,'open-2','HR verified opening duplicate','only one initial opening')$$,'23505','duplicate key value violates unique constraint "leave_ledger_one_opening"','a different key cannot post a second opening to the same account');
SELECT set_config('test.grant',public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'annual_grant',5.00,current_setting('test.type_version')::uuid,'grant-1','HR approved grant 2026','Explicit approved amount; no statutory formula')::text,true);
SELECT is(public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'annual_grant',5.00,current_setting('test.type_version')::uuid,'grant-1','HR approved grant 2026','Explicit approved amount; no statutory formula')->>'state','replay','same idempotency key and payload replays the original grant');
SELECT throws_ok($$SELECT public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'annual_grant',6.00,current_setting('test.type_version')::uuid,'grant-1','HR approved grant 2026','changed amount')$$,'23505','leave_idempotency_conflict','same key with changed amount is rejected');
SELECT set_config('test.adjust',public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'adjustment',0.01,current_setting('test.type_version')::uuid,'adjust-1','HR approved adjustment','Explicit hundredth-day adjustment')::text,true);
SELECT throws_ok($$SELECT public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'adjustment',-20.00,current_setting('test.type_version')::uuid,'adjust-negative','HR correction','must not overdraw')$$,'23514','leave_balance_insufficient','negative adjustment cannot reduce a tracked balance below zero');
SELECT set_config('test.other_balance',public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000012','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',3.00,current_setting('test.type_version')::uuid,'other-open','HR verified opening B','Second employee distinct account')::text,true);
SELECT throws_ok($$SELECT public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000012','cf500000-0000-4000-8000-000000000011',current_setting('test.untracked_type')::uuid,current_setting('test.period')::uuid,'opening',3.00,current_setting('test.untracked_version')::uuid,'untracked-open','HR source','untracked must not have a balance')$$,'23514','leave_untracked_has_no_balance','untracked Leave cannot create a ledger balance');
SELECT throws_ok($$SELECT public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000013','cf500000-0000-4000-8000-000000000012',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',3.00,current_setting('test.type_version')::uuid,'foreign-open','HR source','cross tenant employee')$$,'23503','leave_employee_unavailable','Tenant A HR cannot post against a Tenant B employee');
SELECT is((SELECT sum((x->>'balance_days')::numeric)::text FROM jsonb_array_elements(public.leave_hr_balances('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011',50,0)->'items') x),'17.01','HR balance projection includes prior period plus explicit current opening, grant and hundredth-day adjustment');
SELECT is((public.leave_hr_balances('cf200000-0000-4000-8000-000000000001',NULL,1,0)->>'has_more')::boolean,true,'HR account pagination reports another account without aggregating every ledger row');
SELECT is(public.leave_hr_balances('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011',1,1)->'items'->0->>'balance_days','15.01','second bounded page returns the next current-period balance after the retained prior period');
SELECT is((public.leave_hr_balances('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011',1,2)->>'has_more')::boolean,false,'terminal page reports no further balances');
SELECT set_config('test.version2',public.leave_revise_type('cf200000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,(current_setting('test.today')::date)+20,'paid','tracked','working_days',true,'HR verified policy v2','future policy effective date')::text,true);
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf100000-0000-4000-8000-000000000002',true);
SELECT is(public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'annual_grant',5.00,current_setting('test.type_version')::uuid,'grant-1','HR approved grant 2026','Explicit approved amount; no statutory formula')->>'state','replay','exact grant retry still replays after a future policy version is added');
SELECT throws_ok($$SELECT public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'annual_grant',5.00,current_setting('test.version2')::uuid,'grant-policy-v2','HR approved grant 2026','new policy must not issue a second grant')$$,'23505','leave_annual_grant_exists','a new policy version cannot create a second annual grant for the same account');
RESET ROLE;
SELECT throws_ok($$UPDATE leave.type_versions SET reason='retroactive rewrite' WHERE id=current_setting('test.type_version')::uuid$$,'55000','leave_snapshot_immutable','type policy content is immutable after its future effective boundary is recorded');

-- Self RPC derives the employee from the current link, never a supplied employee ID.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf100000-0000-4000-8000-000000000001',true);
SELECT is(jsonb_array_length(public.leave_my_balances('cf200000-0000-4000-8000-000000000001',50,0)->'items'),2,'own balance returns both retained periods for the linked employee and excludes another employee account');
SELECT is((SELECT sum((x->>'balance_days')::numeric)::text FROM jsonb_array_elements(public.leave_my_balances('cf200000-0000-4000-8000-000000000001',50,0)->'items') x),'17.01','self history remains readable across old and current balance periods');
SELECT ok(public.leave_my_balances('cf200000-0000-4000-8000-000000000001',50,0)->'items' @> jsonb_build_array(jsonb_build_object('period_id',current_setting('test.old_period'),'balance_days',2.00)),'retained old period balance remains visible after a newer policy version is added');
SELECT is((public.leave_access_snapshot('cf200000-0000-4000-8000-000000000001')->>'can_view')::boolean,false,'own self permission does not grant HR view access');
SELECT is((public.leave_access_snapshot('cf200000-0000-4000-8000-000000000001')->>'self_access')::boolean,true,'access snapshot separately reports own Leave access');
SELECT throws_ok($$SELECT public.leave_my_balances('cf200000-0000-4000-8000-000000000002',50,0)$$,'42501','leave_self_forbidden','self permission and link do not cross into another tenant');
RESET ROLE;

-- Disabled entitlements preserve HR history reads while blocking new work; ledger is immutable.
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now() WHERE tenant_id='cf200000-0000-4000-8000-000000000001' AND capability_key IN('hr.people','hr.leave');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf100000-0000-4000-8000-000000000002',true);
SELECT is((SELECT sum((x->>'balance_days')::numeric)::text FROM jsonb_array_elements(public.leave_hr_balances('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011',50,0)->'items') x),'17.01','authorized HR can read historical balances while new-work entitlements are disabled');
SELECT throws_ok($$SELECT public.leave_post_balance('cf200000-0000-4000-8000-000000000001','cf400000-0000-4000-8000-000000000011','cf500000-0000-4000-8000-000000000011',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'adjustment',0.01,current_setting('test.type_version')::uuid,'disabled-1','source','blocked positive growth')$$,'55000','leave_new_work_disabled','disabled People or Leave entitlement blocks balance growth');
RESET ROLE;
SELECT throws_ok($$UPDATE leave.ledger_entries SET reason='tampered' WHERE tenant_id='cf200000-0000-4000-8000-000000000001'$$,'55000','leave_ledger_append_only','ledger history cannot be rewritten');

SELECT * FROM finish();
ROLLBACK;
