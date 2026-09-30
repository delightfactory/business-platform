BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('f1000000-0000-4000-8000-000000000001','temporal-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('f1100000-0000-4000-8000-000000000001','Temporal integrity test','f1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('f1100000-0000-4000-8000-000000000001','f1200000-0000-4000-8000-000000000001','temporal.admin',1,
  ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.manage','attendance.manage','attendance_policy.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('f1100000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('f1100000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','f1200000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES
 ('f1100000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','f1000000-0000-4000-8000-000000000001','temporal test'),
 ('f1100000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','f1000000-0000-4000-8000-000000000001','temporal test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('f1100000-0000-4000-8000-000000000001','f1300000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default)
VALUES
 ('f1100000-0000-4000-8000-000000000001','f1400000-0000-4000-8000-000000000001','f1300000-0000-4000-8000-000000000001','Original',true),
 ('f1100000-0000-4000-8000-000000000001','f1400000-0000-4000-8000-000000000002','f1300000-0000-4000-8000-000000000001','Transfer',false);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version)
VALUES ('f1100000-0000-4000-8000-000000000001','f1500000-0000-4000-8000-000000000001','FLEX',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,
  required_minutes,earliest_punch,latest_punch,created_by)
VALUES ('f1100000-0000-4000-8000-000000000001','f1500000-0000-4000-8000-000000000001',1,'Flexible','flexible','Africa/Cairo',
  ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59','f1000000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.today',timezone('Africa/Cairo',now())::date::text,true);
SELECT set_config('test.old_employee',public.create_people_employee('f1100000-0000-4000-8000-000000000001',
  'TEMP-OLD','Older employment','f1300000-0000-4000-8000-000000000001','f1400000-0000-4000-8000-000000000001',
  current_setting('test.today')::date-7,'monthly',1000,true)::text,true);
SELECT set_config('test.today_employee',public.create_people_employee('f1100000-0000-4000-8000-000000000001',
  'TEMP-TODAY','New employment','f1300000-0000-4000-8000-000000000001','f1400000-0000-4000-8000-000000000001',
  current_setting('test.today')::date,'monthly',1000,true)::text,true);
SELECT set_config('test.override_employee',public.create_people_employee('f1100000-0000-4000-8000-000000000001',
  'TEMP-OVERRIDE','Override employment','f1300000-0000-4000-8000-000000000001','f1400000-0000-4000-8000-000000000001',
  current_setting('test.today')::date,'monthly',1000,true)::text,true);
SELECT set_config('test.old_employment',current_setting('test.old_employee')::jsonb->>'employment_id',true);
SELECT set_config('test.today_employment',current_setting('test.today_employee')::jsonb->>'employment_id',true);
SELECT set_config('test.override_employment',current_setting('test.override_employee')::jsonb->>'employment_id',true);

RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='f1500000-0000-4000-8000-000000000001',work_policy_version=1
WHERE tenant_id='f1100000-0000-4000-8000-000000000001'
  AND employment_id IN (current_setting('test.old_employment')::uuid,current_setting('test.today_employment')::uuid);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.assign_attendance_work_policy_override('f1100000-0000-4000-8000-000000000001',
  current_setting('test.override_employment')::uuid,'f1500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date,current_setting('test.today')::date,'Initial day override')$$,
  'a dated override can provide a policy while the initial Assignment has none');
SELECT is(jsonb_array_length(public.attendance_open_day('f1100000-0000-4000-8000-000000000001',
  current_setting('test.today')::date,NULL,50)->'items'),3,'day open materializes each of the three Employments');

SELECT throws_ok($$SELECT public.correct_initial_people_work_assignment('f1100000-0000-4000-8000-000000000001',
  current_setting('test.today_employment')::uuid,'f1400000-0000-4000-8000-000000000002',NULL,NULL,NULL)$$,
  '23514','people_assignment_materialized_day','initial context cannot be corrected after a Work Instance opens');
SELECT lives_ok($$SELECT public.correct_initial_people_work_assignment('f1100000-0000-4000-8000-000000000001',
  current_setting('test.today_employment')::uuid,'f1400000-0000-4000-8000-000000000001',NULL,NULL,NULL)$$,
  'an unchanged initial context does not rewrite a materialized Work Instance');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('f1100000-0000-4000-8000-000000000001',
  current_setting('test.old_employment')::uuid,current_setting('test.today')::date,
  'f1400000-0000-4000-8000-000000000002',NULL,NULL,NULL)$$,
  '23514','people_assignment_materialized_day','same-day transfer cannot create a second Assignment after day open');
SELECT throws_ok($$SELECT public.assign_people_work_policy('f1100000-0000-4000-8000-000000000001',
  current_setting('test.old_employment')::uuid,'f1500000-0000-4000-8000-000000000001',current_setting('test.today')::date)$$,
  '23514','people_assignment_materialized_day','same-day policy change cannot create a second Assignment after day open');
SELECT throws_ok($$SELECT public.assign_people_work_policy('f1100000-0000-4000-8000-000000000001',
  current_setting('test.override_employment')::uuid,'f1500000-0000-4000-8000-000000000001',current_setting('test.today')::date)$$,
  '23514','people_assignment_materialized_day','initial policy cannot rewrite an Assignment with an override-backed Work Instance');
SELECT throws_ok($$SELECT public.end_people_employment('f1100000-0000-4000-8000-000000000001',
  (current_setting('test.old_employee')::jsonb->>'employee_id')::uuid,current_setting('test.old_employment')::uuid,
  current_setting('test.today')::date-1)$$,
  '23514','people_assignment_materialized_day','termination cannot backdate before a materialized day');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM time.work_instances WHERE tenant_id='f1100000-0000-4000-8000-000000000001'
  AND employment_id=current_setting('test.old_employment')::uuid AND operational_date=current_setting('test.today')::date),
  1,'rejected same-day changes leave one Work Instance per Employment and day');
SELECT is((SELECT count(*)::integer FROM people.work_assignments WHERE tenant_id='f1100000-0000-4000-8000-000000000001'
  AND employment_id=current_setting('test.old_employment')::uuid),1,'failed transfers do not leave a partial Assignment');
SELECT is((SELECT employment_status FROM people.employments WHERE tenant_id='f1100000-0000-4000-8000-000000000001'
  AND id=current_setting('test.old_employment')::uuid),'active','failed backdated termination leaves Employment active');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.future_assignment',(public.schedule_people_work_assignment('f1100000-0000-4000-8000-000000000001',
  current_setting('test.old_employment')::uuid,current_setting('test.today')::date+1,
  'f1400000-0000-4000-8000-000000000002',NULL,NULL,NULL)->>'assignment_id'),true);
SELECT ok(current_setting('test.future_assignment')::uuid IS NOT NULL,'transfer for an unopened future day remains valid');
SELECT lives_ok($$SELECT public.cancel_people_work_assignment('f1100000-0000-4000-8000-000000000001',
  current_setting('test.old_employment')::uuid,current_setting('test.future_assignment')::uuid)$$,
  'future transfer can be cancelled without changing the opened day');
SELECT lives_ok($$SELECT public.assign_people_work_policy('f1100000-0000-4000-8000-000000000001',
  current_setting('test.old_employment')::uuid,'f1500000-0000-4000-8000-000000000001',current_setting('test.today')::date+1)$$,
  'policy change for an unopened future day remains valid');
SELECT is(jsonb_array_length(public.attendance_open_day('f1100000-0000-4000-8000-000000000001',
  current_setting('test.today')::date,NULL,50)->'items'),3,'reopening the same day remains idempotent');
SELECT lives_ok($$SELECT public.end_people_employment('f1100000-0000-4000-8000-000000000001',
  (current_setting('test.old_employee')::jsonb->>'employee_id')::uuid,current_setting('test.old_employment')::uuid,
  current_setting('test.today')::date)$$,
  'termination on the last materialized day remains valid and cancels future work changes');

RESET ROLE;
SELECT has_index('time','work_instances','work_instances_employment_day_key',
  'database has the Employment and day uniqueness index');
SELECT ok(EXISTS (
  SELECT 1 FROM pg_catalog.pg_index ix
  WHERE ix.indexrelid = 'time.work_instances_employment_day_key'::regclass AND ix.indisunique
), 'Employment and day index enforces uniqueness');
-- The Employment-lock race for CSV confirmation is exercised with two live
-- sessions by scripts/attendance-import-concurrency-qa.sql against the disposable QA DB.
SELECT * FROM finish();
ROLLBACK;
