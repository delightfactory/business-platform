BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('b1100000-0000-4000-8000-000000000001','assignment-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('b1100000-0000-4000-8000-000000000002','assignment-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('b2200000-0000-4000-8000-000000000001','Assignment One','b1100000-0000-4000-8000-000000000001'),
 ('b2200000-0000-4000-8000-000000000002','Assignment Two','b1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('b2200000-0000-4000-8000-000000000001','b3300000-0000-4000-8000-000000000001','assignment.admin',1,ARRAY['tenant.administer']),
 ('b2200000-0000-4000-8000-000000000001','b3300000-0000-4000-8000-000000000002','assignment.viewer',1,ARRAY['people.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('b2200000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000001'),
 ('b2200000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000002','b1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('b2200000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000001','b3300000-0000-4000-8000-000000000001'),
 ('b2200000-0000-4000-8000-000000000001','b1100000-0000-4000-8000-000000000002','b3300000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES
 ('b2200000-0000-4000-8000-000000000001','b4400000-0000-4000-8000-000000000001','Employer One',true),
 ('b2200000-0000-4000-8000-000000000001','b4400000-0000-4000-8000-000000000002','Employer Two',false),
 ('b2200000-0000-4000-8000-000000000002','b4400000-0000-4000-8000-000000000003','Foreign Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES
 ('b2200000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000001','b4400000-0000-4000-8000-000000000001','Employer One Site',true,true),
 ('b2200000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000002','b4400000-0000-4000-8000-000000000002','Employer Two Site',false,true),
 ('b2200000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000003','b4400000-0000-4000-8000-000000000001','Inactive Site',false,false),
 ('b2200000-0000-4000-8000-000000000002','b5500000-0000-4000-8000-000000000004','b4400000-0000-4000-8000-000000000003','Foreign Site',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('b2200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute',
 'b1100000-0000-4000-8000-000000000001','Work assignment transfer test');
INSERT INTO people.departments(tenant_id,code,name,created_by_user_id) VALUES
 ('b2200000-0000-4000-8000-000000000002','FOREIGN-DEPT','Foreign department','b1100000-0000-4000-8000-000000000001');
SELECT set_config('test.foreign_department_id',(
  SELECT id::text FROM people.departments WHERE tenant_id='b2200000-0000-4000-8000-000000000002'),true);
INSERT INTO people.jobs(tenant_id,code,name,department_id,is_active)
VALUES ('b2200000-0000-4000-8000-000000000002','FOREIGN-JOB','Foreign job',current_setting('test.foreign_department_id')::uuid,true);
SELECT set_config('test.foreign_job_id',(
  SELECT id::text FROM people.jobs WHERE tenant_id='b2200000-0000-4000-8000-000000000002'),true);
INSERT INTO people.employees(tenant_id,employee_code,full_name,workforce_status,created_by_user_id) VALUES
 ('b2200000-0000-4000-8000-000000000001','INACTIVE-MANAGER','مدير غير نشط','inactive','b1100000-0000-4000-8000-000000000001'),
 ('b2200000-0000-4000-8000-000000000002','FOREIGN-MANAGER','مدير من شركة أخرى','active','b1100000-0000-4000-8000-000000000001');
SELECT set_config('test.inactive_manager_id',(
  SELECT id::text FROM people.employees WHERE tenant_id='b2200000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.foreign_manager_id',(
  SELECT id::text FROM people.employees WHERE tenant_id='b2200000-0000-4000-8000-000000000002'),true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.root_department_id',(public.save_people_department(
  'b2200000-0000-4000-8000-000000000001',NULL,'ROOT','الإدارة الرئيسية',NULL,true)->>'id'),true);
SELECT set_config('test.child_department_id',(public.save_people_department(
  'b2200000-0000-4000-8000-000000000001',NULL,'CHILD','القسم الحالي',current_setting('test.root_department_id')::uuid,true)->>'id'),true);
SELECT set_config('test.job_id',(public.save_people_job(
  'b2200000-0000-4000-8000-000000000001',NULL,'JOB-1','الوظيفة الحالية',current_setting('test.child_department_id')::uuid,true)->>'id'),true);
SELECT set_config('test.inactive_department_id',(public.save_people_department(
  'b2200000-0000-4000-8000-000000000001',NULL,'INACTIVE-DEPT','قسم متوقف',NULL,true)->>'id'),true);
SELECT lives_ok($$SELECT public.save_people_department('b2200000-0000-4000-8000-000000000001',
  current_setting('test.inactive_department_id')::uuid,'INACTIVE-DEPT','قسم متوقف',NULL,false)$$,
  'inactive department fixture is prepared');
SELECT set_config('test.inactive_job_id',(public.save_people_job(
  'b2200000-0000-4000-8000-000000000001',NULL,'INACTIVE-JOB','وظيفة متوقفة',current_setting('test.child_department_id')::uuid,true)->>'id'),true);
SELECT lives_ok($$SELECT public.save_people_job('b2200000-0000-4000-8000-000000000001',
  current_setting('test.inactive_job_id')::uuid,'INACTIVE-JOB','وظيفة متوقفة',current_setting('test.child_department_id')::uuid,false)$$,
  'inactive Job fixture is prepared');
SELECT set_config('test.manager_id',(public.create_people_employee('b2200000-0000-4000-8000-000000000001',
  'ACTIVE-MANAGER','مدير نشط','b4400000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date-10,'monthly',0,true)->>'employee_id'),true);
SELECT set_config('test.future_manager_id',(public.create_people_employee('b2200000-0000-4000-8000-000000000001',
  'FUTURE-MANAGER','مدير سيبدأ لاحقًا','b4400000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date+10,'monthly',0,true)->>'employee_id'),true);
SELECT set_config('test.employee_id',(public.create_people_employee('b2200000-0000-4000-8000-000000000001',
  'TRANSFER-EMP','موظف النقل','b4400000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date-7,'monthly',10000,true,
  current_setting('test.child_department_id')::uuid,current_setting('test.job_id')::uuid)->>'employee_id'),true);
SELECT set_config('test.employment_id',public.people_employee_snapshot('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'employment'->>'id',true);
SELECT set_config('test.assignment_id',public.people_employee_snapshot('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'assignment'->>'id',true);
SELECT set_config('test.today',pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date::text,true);
SELECT set_config('test.future_date',(pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date+5)::text,true);
SELECT set_config('test.future_manager_eligible_id',(public.create_people_employee('b2200000-0000-4000-8000-000000000001',
  'FUTURE-MANAGER-READY','مدير سيبدأ قبل النقل','b4400000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date+3,'monthly',0,true)->>'employee_id'),true);

SELECT ok(public.people_work_assignment_options('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'managers' @> pg_catalog.jsonb_build_array(
  pg_catalog.jsonb_build_object('id',current_setting('test.manager_id')::uuid,'name','مدير نشط')),
  'active same-Tenant manager appears in assignment choices');
SELECT ok((public.people_work_assignment_options('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'managers' @> pg_catalog.jsonb_build_array(
  pg_catalog.jsonb_build_object('id',current_setting('test.future_manager_id')::uuid,'name','مدير سيبدأ لاحقًا',
    'start_date',current_setting('test.today')::date+10))),
  'future-start active manager appears with employment start date');
SELECT is(public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'status','current','history labels the effective assignment');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date-1,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,NULL)$$,
  '22023','people_assignment_backdate_not_supported','backdated transfer is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000004',NULL,NULL,NULL)$$,
  '23503','people_assignment_site_unavailable','cross-Tenant Site is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000002',NULL,NULL,NULL)$$,
  '23503','people_assignment_site_unavailable','Site for a different Employer is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000003',NULL,NULL,NULL)$$,
  '23503','people_assignment_site_unavailable','inactive Site is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',current_setting('test.foreign_department_id')::uuid,NULL,NULL)$$,
  '23503','people_assignment_department_unavailable','cross-Tenant Department is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',current_setting('test.inactive_department_id')::uuid,NULL,NULL)$$,
  '23503','people_assignment_department_unavailable','inactive Department is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',current_setting('test.child_department_id')::uuid,
  current_setting('test.foreign_job_id')::uuid,NULL)$$,
  '23503','people_assignment_job_unavailable','cross-Tenant Job is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',current_setting('test.child_department_id')::uuid,
  current_setting('test.inactive_job_id')::uuid,NULL)$$,
  '23503','people_assignment_job_unavailable','inactive Job is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',current_setting('test.root_department_id')::uuid,
  current_setting('test.job_id')::uuid,NULL)$$,
  '23514','people_assignment_job_department_mismatch','Job linked to another Department is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,current_setting('test.employee_id')::uuid)$$,
  '23514','people_assignment_self_manager','self manager is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,current_setting('test.inactive_manager_id')::uuid)$$,
  '23503','people_assignment_manager_unavailable','inactive manager is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,current_setting('test.future_manager_id')::uuid)$$,
  '23503','people_assignment_manager_unavailable','future-start manager is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,current_setting('test.foreign_manager_id')::uuid)$$,
  '23503','people_assignment_manager_unavailable','cross-Tenant manager is rejected');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_date')::date,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,current_setting('test.future_manager_id')::uuid)$$,
  '23503','people_assignment_manager_unavailable','manager starting after effective date is rejected');

SELECT set_config('test.today_transfer_id',(public.schedule_people_work_assignment(
  'b2200000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,
  current_setting('test.today')::date,'b5500000-0000-4000-8000-000000000001',
  current_setting('test.root_department_id')::uuid,NULL,current_setting('test.manager_id')::uuid)->>'assignment_id'),true);
SELECT is(public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->1->>'valid_until',current_setting('test.today'),
  'prior interval ends exactly when today-effective transfer starts');
SELECT is((public.people_employee_snapshot('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'assignment'->>'id'),current_setting('test.today_transfer_id'),
  'employee detail snapshot shows the assignment effective today');
SELECT is((public.people_employee_snapshot('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'assignment'->>'manager'), 'مدير نشط',
  'employee detail snapshot includes the primary manager');
SELECT set_config('test.same_day_hire_id',(public.create_people_employee('b2200000-0000-4000-8000-000000000001',
  'SAME-DAY-HIRE','موظف بداية اليوم','b4400000-0000-4000-8000-000000000001','b5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date,'monthly',10000,true)->>'employee_id'),true);
SELECT set_config('test.same_day_employment_id',public.people_employee_snapshot('b2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_hire_id')::uuid)->'employment'->>'id',true);
SELECT set_config('test.same_day_assignment_id',public.people_employee_snapshot('b2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_hire_id')::uuid)->'assignment'->>'id',true);
SELECT is((public.correct_initial_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employment_id')::uuid,'b5500000-0000-4000-8000-000000000001',
  current_setting('test.root_department_id')::uuid,NULL,current_setting('test.manager_id')::uuid)->>'assignment_id'),
  current_setting('test.same_day_assignment_id'),'same-day initial correction preserves assignment id');
SELECT is((public.people_employee_snapshot('b2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_hire_id')::uuid)->'assignment'->>'manager'),'مدير نشط',
  'same-day initial correction updates manager context');
SELECT throws_ok($$SELECT public.correct_initial_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,'b5500000-0000-4000-8000-000000000001',NULL,NULL,NULL)$$,
  '23514','people_assignment_initial_correction_window_closed','initial correction closes after hire day');
SELECT set_config('test.future_assignment_id',(public.schedule_people_work_assignment(
  'b2200000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,
  current_setting('test.future_date')::date,'b5500000-0000-4000-8000-000000000001',
  current_setting('test.child_department_id')::uuid,current_setting('test.job_id')::uuid,
  current_setting('test.future_manager_eligible_id')::uuid)->>'assignment_id'),true);
SELECT is((public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'manager'),'مدير سيبدأ قبل النقل',
  'future-start manager is eligible on the transfer effective date');
SELECT is(public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'status','scheduled','future transfer appears as scheduled history');
SELECT is(public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->1->>'valid_until',current_setting('test.future_date'),
  'current interval closes at the exclusive future effective date');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_date')::date+2,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,NULL)$$,
  '23514','people_assignment_future_exists','second pending future transfer is rejected');
SELECT lives_ok($$SELECT public.cancel_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.future_assignment_id')::uuid)$$,
  'pending future transfer can be cancelled');
SELECT is(pg_catalog.jsonb_array_length(public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'),2,'cancellation removes only the future assignment row');
SELECT ok(public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->'valid_until'='null'::jsonb,
  'cancellation restores prior interval to open-ended');
SELECT throws_ok($$SELECT public.cancel_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today_transfer_id')::uuid)$$,
  '23514','people_assignment_not_future','effective assignment cannot be cancelled as future');
RESET ROLE;

SELECT throws_ok($$INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,department_id,valid_from)
  VALUES('b2200000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,
    'b5500000-0000-4000-8000-000000000001',NULL,current_setting('test.today')::date)$$,
  '23P01','conflicting key value violates exclusion constraint "work_assignment_no_overlap"',
  'exclusion constraint rejects overlapping interval');

SELECT is((SELECT pg_catalog.count(*)::integer FROM people.work_assignment_audit_events
  WHERE tenant_id='b2200000-0000-4000-8000-000000000001'
    AND employment_id=current_setting('test.employment_id')::uuid
    AND actor_user_id='b1100000-0000-4000-8000-000000000001'),3,
  'today transfer, future schedule, and cancellation record the actor');
SELECT ok((SELECT details ? 'before' AND details ? 'after' FROM people.work_assignment_audit_events
  WHERE tenant_id='b2200000-0000-4000-8000-000000000001'
    AND assignment_id=current_setting('test.today_transfer_id')::uuid
    AND event_key='assignment.transferred'),'transfer audit includes before and after context');
SELECT ok((SELECT details ? 'before' AND details ? 'after' FROM people.work_assignment_audit_events
  WHERE tenant_id='b2200000-0000-4000-8000-000000000001'
    AND employment_id=current_setting('test.same_day_employment_id')::uuid
    AND event_key='assignment.initial_corrected'),'initial correction audit captures before and after');
SELECT ok((SELECT details ? 'cancelled' AND details ? 'restored' FROM people.work_assignment_audit_events
  WHERE tenant_id='b2200000-0000-4000-8000-000000000001'
    AND assignment_id=current_setting('test.future_assignment_id')::uuid
    AND event_key='assignment.transfer_cancelled'),'cancellation audit retains cancelled and restored context');
SELECT ok(NOT has_table_privilege('authenticated','people.work_assignment_audit_events','SELECT'),
  'assignment audit is unavailable to direct table reads');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1100000-0000-4000-8000-000000000002',true);
SELECT is(pg_catalog.jsonb_array_length(public.people_work_assignment_history('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'),2,'people.view grants bounded assignment history');
SELECT throws_ok($$SELECT public.schedule_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid,current_setting('test.today')::date+10,
  'b5500000-0000-4000-8000-000000000001',NULL,NULL,NULL)$$,
  '42501','people_org_manage_forbidden','read-only viewer cannot transfer assignment');
SELECT throws_ok($$SELECT public.people_work_assignment_options('b2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)$$,
  '42501','people_org_manage_forbidden','read-only viewer cannot read management options');
SELECT throws_ok($$SELECT public.correct_initial_people_work_assignment('b2200000-0000-4000-8000-000000000001',
  current_setting('test.same_day_employment_id')::uuid,'b5500000-0000-4000-8000-000000000001',NULL,NULL,NULL)$$,
  '42501','people_org_manage_forbidden','read-only viewer cannot correct initial assignment');
SELECT throws_ok($$SELECT public.people_work_assignment_history('b2200000-0000-4000-8000-000000000002',
  'b6600000-0000-4000-8000-000000000001')$$,
  '42501','people_view_forbidden','cross-Tenant assignment history is denied');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
