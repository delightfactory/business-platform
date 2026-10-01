BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('cf810000-0000-4000-8000-000000000001','leave-config-hr@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('cf820000-0000-4000-8000-000000000001','Leave config tenant','cf810000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('cf820000-0000-4000-8000-000000000001','cf830000-0000-4000-8000-000000000001','test.leave.config.hr.v1',1,ARRAY['leave.manage','leave.view'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('cf820000-0000-4000-8000-000000000001','cf810000-0000-4000-8000-000000000001','cf810000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('cf820000-0000-4000-8000-000000000001','cf810000-0000-4000-8000-000000000001','cf830000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('cf820000-0000-4000-8000-000000000001','cf850000-0000-4000-8000-000000000001','Employer Config',true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('cf820000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','cf810000-0000-4000-8000-000000000001','configuration integrity'),
       ('cf820000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','cf810000-0000-4000-8000-000000000001','configuration integrity');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf810000-0000-4000-8000-000000000001',true);
SELECT set_config('test.today',current_setting('test.today'),true);
SELECT set_config('test.calendar',public.leave_create_calendar(
 'cf820000-0000-4000-8000-000000000001','cf850000-0000-4000-8000-000000000001',
 'finite','Finite calendar',current_setting('test.today')::date-5,
 current_setting('test.today')::date+40,ARRAY[5,6]::smallint[],
 jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date+5)::text,'name','Original holiday')),
 'HR calendar source','Finite original snapshot')::text,true);
SELECT set_config('test.period',public.leave_create_year_period(
 'cf820000-0000-4000-8000-000000000001','cf850000-0000-4000-8000-000000000001',
 current_setting('test.calendar')::uuid,current_setting('test.today')::date-2,
 current_setting('test.today')::date+20,'Period through later dates','Approved explicit period')::text,true);

SELECT throws_ok(format($q$SELECT public.leave_revise_calendar(
 'cf820000-0000-4000-8000-000000000001','%s',
 (current_setting('test.today')::date+10),(current_setting('test.today')::date+15),
 ARRAY[0,1]::smallint[],'[]'::jsonb,'HR prospective change','Must preserve configured year coverage')$q$,current_setting('test.calendar')),
 '22023','leave_calendar_revision_breaks_year_period',
 'a revision that would leave an existing Leave year uncovered is rejected');
SELECT is(public.leave_calendar_day('cf820000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+16)->>'effective_until',
 (current_setting('test.today')::date+40)::text,
 'failed revision rolls back the prior finite boundary without creating a gap');
SELECT is(public.leave_calendar_day('cf820000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+5)->>'holiday','Original holiday',
 'date before any accepted revision keeps its original holiday snapshot');

SELECT set_config('test.calendar_version',public.leave_revise_calendar(
 'cf820000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+40,current_setting('test.today')::date+60,
 ARRAY[1,2]::smallint[],
 jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date+45)::text,'name','Continued holiday')),
 'HR calendar continuation','Continue at finite exclusive boundary')::text,true);
SELECT is(public.leave_calendar_day('cf820000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+45)->>'holiday','Continued holiday',
 'finite calendar can continue at its exclusive end with a new immutable holiday snapshot');
SELECT is(public.leave_calendar_day('cf820000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+5)->>'holiday','Original holiday',
 'continuation preserves holiday evidence before its effective date');

SELECT throws_ok($$SELECT public.leave_create_year_period(
 'cf820000-0000-4000-8000-000000000001','cf850000-0000-4000-8000-000000000001',
 current_setting('test.calendar')::uuid,current_setting('test.today')::date,
 NULL,'Null end must fail','Explicit period end required')$$,
 '22023','leave_year_period_invalid','year period explicitly rejects a NULL end date');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
