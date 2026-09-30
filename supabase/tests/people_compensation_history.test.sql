BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('c1100000-0000-4000-8000-000000000001','comp-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c1100000-0000-4000-8000-000000000002','comp-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c1100000-0000-4000-8000-000000000003','comp-manager@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c2200000-0000-4000-8000-000000000001','Compensation One','c1100000-0000-4000-8000-000000000001'),
 ('c2200000-0000-4000-8000-000000000002','Compensation Two','c1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c2200000-0000-4000-8000-000000000001','c3300000-0000-4000-8000-000000000001','comp.admin',1,ARRAY['tenant.administer']),
 ('c2200000-0000-4000-8000-000000000001','c3300000-0000-4000-8000-000000000002','comp.viewer',1,ARRAY['compensation.view']),
 ('c2200000-0000-4000-8000-000000000001','c3300000-0000-4000-8000-000000000003','comp.manager',1,ARRAY['compensation.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c2200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001'),
 ('c2200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000002','c1100000-0000-4000-8000-000000000001'),
 ('c2200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000003','c1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c2200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000001','c3300000-0000-4000-8000-000000000001'),
 ('c2200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000002','c3300000-0000-4000-8000-000000000002'),
 ('c2200000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000003','c3300000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES
 ('c2200000-0000-4000-8000-000000000001','c4400000-0000-4000-8000-000000000001','Comp Employer',true),
 ('c2200000-0000-4000-8000-000000000002','c4400000-0000-4000-8000-000000000002','Other Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES
 ('c2200000-0000-4000-8000-000000000001','c5500000-0000-4000-8000-000000000001','c4400000-0000-4000-8000-000000000001','Comp Site',true),
 ('c2200000-0000-4000-8000-000000000002','c5500000-0000-4000-8000-000000000002','c4400000-0000-4000-8000-000000000002','Other Site',true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('c2200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute',
  'c1100000-0000-4000-8000-000000000001','Compensation history test');

SELECT ok(NOT has_table_privilege('authenticated','people.compensation_versions','SELECT'),
  'compensation versions have no direct table read');
SELECT ok(NOT has_table_privilege('authenticated','people.compensation_audit_events','SELECT'),
  'compensation audit has no direct table read');
SELECT ok(NOT has_function_privilege('anon','public.change_people_compensation(uuid,uuid,date,numeric)','EXECUTE'),
  'signed-out users cannot change compensation');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.today',pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date::text,true);
SELECT set_config('test.future_date',(pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date+10)::text,true);
SELECT set_config('test.employee_id',(public.create_people_employee('c2200000-0000-4000-8000-000000000001',
  'COMP-EMP','موظف الأجر','c4400000-0000-4000-8000-000000000001','c5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date-20,'monthly',25000.00,true)->>'employee_id'),true);
SELECT set_config('test.employment_id',public.people_employee_snapshot('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'employment'->>'id',true);
SELECT set_config('test.initial_amount_version_id',public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'id',true);

SELECT is(public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'status','current','initial compensation appears as current history');
SELECT is((public.people_compensation_snapshot('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->>'amount'),'25000.00','snapshot exposes only effective current base pay');
SELECT ok((public.people_compensation_options('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->>'has_current')::boolean,'compensation manager receives management context');
SELECT set_config('test.same_day_employee_id',(public.create_people_employee('c2200000-0000-4000-8000-000000000001',
  'COMP-SAME-DAY','موظف بداية اليوم','c4400000-0000-4000-8000-000000000001','c5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date,'monthly',1200,true)->>'employee_id'),true);
SELECT set_config('test.same_day_employment_id',public.people_employee_snapshot('c2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employee_id')::uuid)->'employment'->>'id',true);
SELECT set_config('test.same_day_version_id',public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employment_id')::uuid)->'items'->0->>'id',true);
SELECT is((public.people_compensation_options('c2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employment_id')::uuid)->>'effective_date_min'),current_setting('test.today'),
  'initial compensation can be corrected during the hire date');
SELECT is((public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employment_id')::uuid,current_setting('test.today')::date,1500)->>'state'),
  'initial_corrected','same-day initial amount typo has an audited correction path');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employment_id')::uuid)->'items'->0->>'id'),current_setting('test.same_day_version_id'),
  'same-day correction preserves initial version id');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employment_id')::uuid)->'items'->0->>'amount'),'1500.00',
  'same-day correction updates the initial amount');
SELECT set_config('test.future_hire_id',(public.create_people_employee('c2200000-0000-4000-8000-000000000001',
  'COMP-FUTURE-HIRE','موظف يبدأ لاحقًا','c4400000-0000-4000-8000-000000000001','c5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date+7,'monthly',1800,true)->>'employee_id'),true);
SELECT set_config('test.future_hire_employment_id',public.people_employee_snapshot('c2200000-0000-4000-8000-000000000001',
  current_setting('test.future_hire_id')::uuid)->'employment'->>'id',true);
SELECT is(public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.future_hire_employment_id')::uuid)->'items'->0->>'status','initial_scheduled',
  'initial pay for a future hire is distinct from a later scheduled change');
SELECT is(public.people_compensation_options('c2200000-0000-4000-8000-000000000001',
  current_setting('test.future_hire_employment_id')::uuid)->'pending','null'::jsonb,
  'initial future-hire pay is not offered as a cancellable change');
SELECT set_config('test.backdated_date',(current_setting('test.today')::date-10)::text,true);
SELECT set_config('test.backdated_version_id',(public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.backdated_date')::date,28000)->>'version_id'),true);
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'amount'),'28000.00',
  'backdated change creates a new effective version');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->1->>'valid_until'),current_setting('test.backdated_date'),
  'backdated change closes the current interval at its exclusive start');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->1->>'id'),current_setting('test.initial_amount_version_id'),
  'backdate preserves the original version identity');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->1->>'amount'),'25000.00',
  'backdating leaves the prior amount unchanged');
SELECT is((public.people_compensation_snapshot('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->>'amount'),'28000.00',
  'backdated amount is effective for the current snapshot');
SELECT throws_ok($$SELECT public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.backdated_date')::date-1,27000)$$,
  '22023','people_compensation_backdate_outside_current_version','backdate outside the currently effective version is rejected');
SELECT throws_ok($$SELECT public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,28000.125)$$,
  '22023','people_compensation_input_invalid','amount with more than two decimal places is rejected');
SELECT set_config('test.today_version_id',(public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,27500.50)->>'version_id'),true);
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'amount'),'27500.50','today change adds exact decimal version');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->1->>'amount'),'28000.00',
  'the backdated version amount remains unchanged after a later change');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->2->>'amount'),'25000.00',
  'the original compensation amount remains unchanged in history');
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->1->>'valid_until'),current_setting('test.today'),
  'prior version ends at the new date using exclusive date-only boundary');
SELECT throws_ok($$SELECT public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,30000)$$,
  '22023','people_compensation_before_current_start','duplicate same-day version is rejected');
SELECT set_config('test.future_version_id',(public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_date')::date,30000)->>'version_id'),true);
SELECT is(public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'status','scheduled','future compensation appears as scheduled');
SELECT is((public.people_compensation_snapshot('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->>'amount'),'27500.50',
  'future change does not replace current compensation before its effective date');
SELECT throws_ok($$SELECT public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_date')::date+3,31000)$$,
  '23514','people_compensation_future_exists','second pending future change is rejected');
SELECT lives_ok($$SELECT public.cancel_people_compensation_change('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_version_id')::uuid)$$,
  'future compensation change can be cancelled');
SELECT is(pg_catalog.jsonb_array_length(public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'),3,'cancel removes only pending version');
SELECT ok((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->'valid_until')='null'::jsonb,
  'cancel restores prior version as open-ended');
SELECT throws_ok($$SELECT public.cancel_people_compensation_change('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today_version_id')::uuid)$$,
  '23514','people_compensation_not_future','effective compensation cannot be cancelled');
RESET ROLE;

SELECT is((SELECT pg_catalog.count(*)::integer FROM people.compensation_audit_events
  WHERE tenant_id='c2200000-0000-4000-8000-000000000001'
    AND employment_id=current_setting('test.employment_id')::uuid
    AND actor_user_id='c1100000-0000-4000-8000-000000000001'),4,
  'backdate, today change, future schedule and cancellation record actor and employment');
SELECT ok((SELECT details ? 'before' AND details ? 'after' FROM people.compensation_audit_events
  WHERE tenant_id='c2200000-0000-4000-8000-000000000001'
    AND subject_version_id=current_setting('test.today_version_id')::uuid
    AND event_key='compensation.changed'),'change audit captures before and after values');
SELECT ok((SELECT details ? 'before' AND details ? 'after' FROM people.compensation_audit_events
  WHERE tenant_id='c2200000-0000-4000-8000-000000000001'
    AND employment_id=current_setting('test.same_day_employment_id')::uuid
    AND subject_version_id=current_setting('test.same_day_version_id')::uuid
    AND event_key='compensation.initial_corrected'),'same-day initial correction audit captures before and after');
SELECT ok((SELECT details ? 'cancelled' AND details ? 'restored' FROM people.compensation_audit_events
  WHERE tenant_id='c2200000-0000-4000-8000-000000000001'
    AND subject_version_id=current_setting('test.future_version_id')::uuid
    AND event_key='compensation.change_cancelled'),'cancellation audit preserves removed and restored context');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c1100000-0000-4000-8000-000000000002',true);
SELECT is((public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'amount'),'27500.50',
  'compensation.view can read amount history');
SELECT throws_ok($$SELECT public.people_compensation_options('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)$$,
  '42501','compensation_manage_forbidden','view permission cannot read management options');
SELECT throws_ok($$SELECT public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_date')::date,31000)$$,
  '42501','compensation_manage_forbidden','view permission cannot change compensation');
SELECT throws_ok($$SELECT public.people_compensation_history('c2200000-0000-4000-8000-000000000002',
  current_setting('test.employment_id')::uuid)$$,
  '42501','compensation_view_forbidden','compensation history is Tenant scoped');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c1100000-0000-4000-8000-000000000003',true);
SELECT is((public.people_compensation_options('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->>'pay_basis'),'monthly',
  'compensation.manage gets pay-basis context without current amount');
SELECT throws_ok($$SELECT public.people_compensation_history('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)$$,
  '42501','compensation_view_forbidden','manage permission does not grant amount history');
SELECT throws_ok($$SELECT public.people_compensation_snapshot('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)$$,
  '42501','compensation_view_forbidden','manage permission does not grant current amount');
SELECT lives_ok($$SELECT public.change_people_compensation('c2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_date')::date,28000)$$,
  'compensation.manage can mutate without compensation.view');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
