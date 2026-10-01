BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('cf910000-0000-4000-8000-000000000001','leave-finite-hr@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('cf920000-0000-4000-8000-000000000001','Leave finite tenant','cf910000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('cf920000-0000-4000-8000-000000000001','cf930000-0000-4000-8000-000000000001','test.leave.finite.hr.v1',1,ARRAY['leave.manage','leave_balance.adjust'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('cf920000-0000-4000-8000-000000000001','cf910000-0000-4000-8000-000000000001','cf910000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('cf920000-0000-4000-8000-000000000001','cf910000-0000-4000-8000-000000000001','cf930000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001','Employer Finite',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('cf920000-0000-4000-8000-000000000001','cf940000-0000-4000-8000-000000000001','FINITE-1','Finite test employee','cf910000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('cf920000-0000-4000-8000-000000000001','cf960000-0000-4000-8000-000000000001','cf940000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',current_setting('test.today')::date-10,'active','monthly');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('cf920000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','cf910000-0000-4000-8000-000000000001','finite numeric regression'),
       ('cf920000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','cf910000-0000-4000-8000-000000000001','finite numeric regression');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf910000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',
 'numeric','Numeric regression calendar',current_setting('test.today')::date-10,NULL,
 ARRAY[5,6]::smallint[],'[]'::jsonb,'HR calendar','numeric finite test')::text,true);
SELECT set_config('test.period',public.leave_create_year_period(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',
 current_setting('test.calendar')::uuid,current_setting('test.today')::date-5,
 current_setting('test.today')::date+20,'Numeric test period','Explicit period')::text,true);
SELECT set_config('test.type',public.leave_create_type(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',
 'tracked','Tracked leave',current_setting('test.today')::date-5,
 'paid','tracked',false,'Verified source','Numeric test type')::text,true);
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions
 WHERE leave_type_id=current_setting('test.type')::uuid AND version=1),true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.entry',public.leave_post_balance(
 'cf920000-0000-4000-8000-000000000001','cf940000-0000-4000-8000-000000000001',
 'cf950000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,
 current_setting('test.period')::uuid,'opening',1.00,current_setting('test.type_version')::uuid,
 'finite-opening','HR verified opening','Seed balance for special numeric rejection')->>'entry_id',true);
SELECT set_config('test.account',public.leave_post_balance(
 'cf920000-0000-4000-8000-000000000001','cf940000-0000-4000-8000-000000000001',
 'cf950000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,
 current_setting('test.period')::uuid,'opening',1.00,current_setting('test.type_version')::uuid,
 'finite-opening','HR verified opening','Seed balance for special numeric rejection')->>'account_id',true);

SELECT throws_ok($$SELECT public.leave_post_balance(
 'cf920000-0000-4000-8000-000000000001','cf940000-0000-4000-8000-000000000001',
 'cf950000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,
 current_setting('test.period')::uuid,'adjustment','NaN'::numeric,
 current_setting('test.type_version')::uuid,'nan-adjustment','HR correction','NaN must never poison balance')$$,
 '22023','leave_balance_input_invalid','authenticated balance RPC rejects numeric NaN before ledger aggregation');
SELECT throws_ok($$SELECT public.leave_post_balance(
 'cf920000-0000-4000-8000-000000000001','cf940000-0000-4000-8000-000000000001',
 'cf950000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,
 current_setting('test.period')::uuid,'adjustment','Infinity'::numeric,
 current_setting('test.type_version')::uuid,'positive-infinity-adjustment','HR correction','infinity must be rejected')$$,
 '22023','leave_balance_input_invalid','authenticated balance RPC rejects positive numeric Infinity');
SELECT throws_ok($$SELECT public.leave_post_balance(
 'cf920000-0000-4000-8000-000000000001','cf940000-0000-4000-8000-000000000001',
 'cf950000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,
 current_setting('test.period')::uuid,'adjustment','-Infinity'::numeric,
 current_setting('test.type_version')::uuid,'negative-infinity-adjustment','HR correction','negative infinity must be rejected')$$,
 '22023','leave_balance_input_invalid','authenticated balance RPC rejects negative numeric Infinity');
RESET ROLE;

SELECT throws_ok(format($q$INSERT INTO leave.ledger_entries(
 tenant_id,account_id,leave_type_id,entry_kind,delta_days,source_version_id,
 source_reference,idempotency_key,reason,actor_user_id
) VALUES('cf920000-0000-4000-8000-000000000001','%s','%s','adjustment','NaN'::numeric,
 '%s','direct-finite-check','direct-nan','direct insert regression','cf910000-0000-4000-8000-000000000001')$q$,
 current_setting('test.account'),current_setting('test.type'),current_setting('test.type_version')),
 '23514','new row for relation "ledger_entries" violates check constraint "leave_ledger_delta_finite"',
 'ledger CHECK independently rejects NaN even from a privileged direct insert');
SELECT * FROM finish();
ROLLBACK;
