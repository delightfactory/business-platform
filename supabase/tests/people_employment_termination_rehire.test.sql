BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('d1100000-0000-4000-8000-000000000001','lifecycle-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d1100000-0000-4000-8000-000000000002','lifecycle-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('d2200000-0000-4000-8000-000000000001','Lifecycle One','d1100000-0000-4000-8000-000000000001'),
 ('d2200000-0000-4000-8000-000000000002','Lifecycle Two','d1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('d2200000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000001','lifecycle.admin',1,ARRAY['tenant.administer']),
 ('d2200000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000002','lifecycle.viewer',1,ARRAY['people.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('d2200000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001'),
 ('d2200000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('d2200000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000001'),
 ('d2200000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000002','d3300000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES
 ('d2200000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','Lifecycle Employer',true),
 ('d2200000-0000-4000-8000-000000000002','d4400000-0000-4000-8000-000000000002','Foreign Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES
 ('d2200000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','Lifecycle Site',true),
 ('d2200000-0000-4000-8000-000000000002','d5500000-0000-4000-8000-000000000002','d4400000-0000-4000-8000-000000000002','Foreign Site',true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('d2200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute',
 'd1100000-0000-4000-8000-000000000001','Employment lifecycle test');
INSERT INTO people.departments(tenant_id,code,name,is_active,created_by_user_id) VALUES
 ('d2200000-0000-4000-8000-000000000002','FOREIGN-DEPT','قسم خارجي',true,'d1100000-0000-4000-8000-000000000001');
INSERT INTO people.jobs(tenant_id,code,name,department_id,is_active) SELECT
 tenant_id,'FOREIGN-JOB','وظيفة خارجية',id,true FROM people.departments WHERE tenant_id='d2200000-0000-4000-8000-000000000002';
SELECT set_config('test.foreign_department_id',(SELECT id::text FROM people.departments
  WHERE tenant_id='d2200000-0000-4000-8000-000000000002'),true);
SELECT set_config('test.foreign_job_id',(SELECT id::text FROM people.jobs
  WHERE tenant_id='d2200000-0000-4000-8000-000000000002'),true);

SELECT ok(NOT has_table_privilege('authenticated','people.employment_lifecycle_audit_events','SELECT'),
  'lifecycle audit is not directly readable');
SELECT ok(NOT has_function_privilege('anon','public.end_people_employment(uuid,uuid,uuid,date)','EXECUTE'),
  'anonymous users cannot end Employment');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.today',pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date::text,true);
SELECT set_config('test.future', (pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date+8)::text,true);
SELECT set_config('test.employee_id',(public.create_people_employee('d2200000-0000-4000-8000-000000000001',
  'LIFECYCLE-EMP','موظف دورة العمل','d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date-12,'monthly',15000,true)->>'employee_id'),true);
SELECT set_config('test.employment_id',public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'employment'->>'id',true);
SELECT set_config('test.assignment_id',public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'assignment'->>'id',true);
SELECT set_config('test.comp_version_id',public.people_compensation_history('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employment_id')::uuid)->'items'->0->>'id',true);

SELECT throws_ok($$SELECT public.end_people_employment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,current_setting('test.employment_id')::uuid,current_setting('test.today')::date-13)$$,
  '22023','people_employment_end_before_start','termination before Employment start is rejected');
SELECT throws_ok($$SELECT public.end_people_employment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,current_setting('test.employment_id')::uuid,current_setting('test.today')::date+1)$$,
  '22023','people_employment_future_end_unsupported','future-dated Employment termination is rejected');
SELECT set_config('test.pending_assignment_id',(public.schedule_people_work_assignment(
  'd2200000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,current_setting('test.future')::date,
  'd5500000-0000-4000-8000-000000000001',NULL,NULL,NULL)->>'assignment_id'),true);
SELECT set_config('test.pending_comp_version_id',(public.change_people_compensation(
  'd2200000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,
  current_setting('test.future')::date,17000)->>'version_id'),true);
SELECT is((public.end_people_employment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,current_setting('test.employment_id')::uuid,current_setting('test.today')::date-1)->>'state'),
  'ended','active Employment can be ended on a safe past date');
SELECT is((public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->>'status'),'ended','Employee remains and is marked ended');
SELECT is((public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'employment'->>'status'),'ended','Employment is ended without deleting it');
RESET ROLE;
SELECT is((SELECT end_date::text FROM people.employments WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND id=current_setting('test.employment_id')::uuid),(current_setting('test.today')::date-1)::text,'end date is the inclusive final work date');
SELECT is((SELECT valid_until::text FROM people.work_assignments WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND id=current_setting('test.assignment_id')::uuid),current_setting('test.today'),
  'current assignment closes at the exclusive day after final work date');
SELECT is((SELECT valid_until::text FROM people.compensation_versions WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND id=current_setting('test.comp_version_id')::uuid),current_setting('test.today'),
  'current compensation closes at the exclusive day after final work date');
SELECT is((SELECT count(*)::integer FROM people.work_assignments WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND id=current_setting('test.pending_assignment_id')::uuid),0,'pending future assignment is removed');
SELECT is((SELECT count(*)::integer FROM people.compensation_versions WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND id=current_setting('test.pending_comp_version_id')::uuid),0,'pending future compensation is removed');
SELECT is((SELECT count(*)::integer FROM people.work_assignment_audit_events WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND assignment_id=current_setting('test.pending_assignment_id')::uuid AND event_key='assignment.transfer_cancelled'),1,
  'pending assignment cancellation records context in assignment audit');
SELECT is((SELECT count(*)::integer FROM people.compensation_audit_events WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND subject_version_id=current_setting('test.pending_comp_version_id')::uuid AND event_key='compensation.change_cancelled'),1,
  'pending compensation cancellation records context in compensation audit');
SELECT ok((SELECT details ? 'before' AND details ? 'after' AND details ? 'handoff_required'
  AND details->'handoff_required' @> '["payroll_final_settlement","leave_balance_review","finance_balance_review"]'::jsonb
  FROM people.employment_lifecycle_audit_events WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
    AND employment_id=current_setting('test.employment_id')::uuid AND event_key='employment.ended'
    AND actor_user_id='d1100000-0000-4000-8000-000000000001'),
  'termination audit stores actor, before/after and explicit domain handoffs');
SELECT is((SELECT details->'after'->>'end_date' FROM people.employment_lifecycle_audit_events
  WHERE tenant_id='d2200000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_id')::uuid
    AND event_key='employment.ended'),(current_setting('test.today')::date-1)::text,
  'historical termination audit records the selected end date');
SELECT is((public.people_employment_history('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'items'->0->>'status'),'ended','authorized history reads ended Employment');

SELECT throws_ok($$SELECT public.rehire_people_employee('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,'d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date-1,'monthly',18000,true)$$,
  '22023','people_rehire_start_date_invalid','rehire on prior inclusive end date is rejected');
SELECT throws_ok($$SELECT public.rehire_people_employee('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,'d4400000-0000-4000-8000-000000000002','d5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date+1,'monthly',18000,true)$$,
  '23503','people_employer_unavailable','cross-Tenant Employer is rejected');
SELECT throws_ok($$SELECT public.rehire_people_employee('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,'d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000002',
  current_setting('test.today')::date+1,'monthly',18000,true)$$,
  '23503','people_site_unavailable','cross-Tenant Site is rejected');
SELECT throws_ok($$SELECT public.rehire_people_employee('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,'d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date+1,'monthly',18000,true,current_setting('test.foreign_department_id')::uuid,NULL)$$,
  '23503','people_department_unavailable','cross-Tenant Department is rejected');
SELECT throws_ok($$SELECT public.rehire_people_employee('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,'d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date+1,'monthly',18000,true,NULL,current_setting('test.foreign_job_id')::uuid)$$,
  '23503','people_job_unavailable','cross-Tenant Job is rejected');

SELECT set_config('test.rehire_employment_id',(public.rehire_people_employee('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,'d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date+1,'daily',18000.25,true)->>'employment_id'),true);
SELECT ok(current_setting('test.rehire_employment_id')::uuid<>current_setting('test.employment_id')::uuid,
  'rehire creates a new Employment identity');
SELECT is((public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->>'status'),'scheduled','future rehire remains visibly scheduled');
SELECT is((public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'assignment'->>'site'),'Lifecycle Site',
  'future rehire snapshot includes its planned Site context');
SELECT is((public.people_directory_page('d2200000-0000-4000-8000-000000000001','LIFECYCLE-EMP',1)->'items'->0->>'status'),
  'scheduled','future rehire follows scheduled onboarding status in the directory');
SELECT is((public.people_work_assignment_history('d2200000-0000-4000-8000-000000000001',
  current_setting('test.rehire_employment_id')::uuid)->'items'->0->>'status'),'initial_scheduled',
  'rehire initial assignment is distinguished from a transfer');
SELECT throws_ok($$SELECT public.cancel_people_work_assignment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.rehire_employment_id')::uuid,
  (public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',current_setting('test.employee_id')::uuid)->'assignment'->>'id')::uuid)$$,
  '23514','people_assignment_initial_not_cancellable','rehire initial assignment cannot be cancelled as a transfer');
SELECT is((public.people_compensation_history('d2200000-0000-4000-8000-000000000001',
  current_setting('test.rehire_employment_id')::uuid)->'items'->0->>'status'),'initial_scheduled',
  'rehire initial compensation is labelled as pay at Employment start');
SELECT is((public.people_compensation_options('d2200000-0000-4000-8000-000000000001',
  current_setting('test.rehire_employment_id')::uuid)->'pending'),'null'::jsonb,
  'initial future compensation does not become a pending-change blocker');
SELECT is((public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->>'code'),'LIFECYCLE-EMP','rehire preserves the Employee code and identity');
SELECT is((SELECT count(*)::integer FROM people.employments WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND employee_id=current_setting('test.employee_id')::uuid),2,'old and new Employment records are preserved');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND user_id='d1100000-0000-4000-8000-000000000001'),1,'ending and rehiring do not revoke Tenant membership');
SELECT is((SELECT count(*)::integer FROM people.work_assignments WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND employment_id=current_setting('test.employment_id')::uuid),1,'ended Employment assignment history remains');
SELECT is((SELECT count(*)::integer FROM people.compensation_versions WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND employment_id=current_setting('test.employment_id')::uuid),1,'ended Employment pay history remains');
SELECT is((SELECT count(*)::integer FROM people.compensation_versions WHERE tenant_id='d2200000-0000-4000-8000-000000000001'
  AND employment_id=current_setting('test.rehire_employment_id')::uuid AND amount=18000.25),1,
  'rehire creates initial compensation only on the new Employment');
SELECT is((public.people_employment_history('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'items'->0->>'id'),current_setting('test.rehire_employment_id'),
  'history places the new Employment first while retaining the old one');
SELECT ok((SELECT details ? 'before' AND details ? 'after' FROM people.employment_lifecycle_audit_events
  WHERE tenant_id='d2200000-0000-4000-8000-000000000001' AND employee_id=current_setting('test.employee_id')::uuid
    AND employment_id=current_setting('test.rehire_employment_id')::uuid AND event_key='employment.rehired'
    AND actor_user_id='d1100000-0000-4000-8000-000000000001'),'rehire audit captures actor and before/after context');
SELECT set_config('test.changed_employee_id',(public.create_people_employee('d2200000-0000-4000-8000-000000000001',
  'LIFECYCLE-CHANGED','موظف تغير سياقه','d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date-10,'monthly',10000,true)->>'employee_id'),true);
SELECT set_config('test.changed_employment_id',public.people_employee_snapshot('d2200000-0000-4000-8000-000000000001',
  current_setting('test.changed_employee_id')::uuid)->'employment'->>'id',true);
SELECT lives_ok($$SELECT public.schedule_people_work_assignment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.changed_employment_id')::uuid,current_setting('test.today')::date,
  'd5500000-0000-4000-8000-000000000001',NULL,NULL,NULL)$$,
  'second employee receives a today-effective assignment fixture');
SELECT throws_ok($$SELECT public.end_people_employment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.changed_employee_id')::uuid,current_setting('test.changed_employment_id')::uuid,
  current_setting('test.today')::date-1)$$,
  '23514','people_employment_end_after_effective_change','backdate crossing a later effective assignment is rejected');
SELECT is((public.end_people_employment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.changed_employee_id')::uuid,current_setting('test.changed_employment_id')::uuid,
  current_setting('test.today')::date)->>'state'),'ended','today-effective termination works after a rejected backdate');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.end_people_employment('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,current_setting('test.rehire_employment_id')::uuid,
  (pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date+1))$$,
  '42501','people_employment_manage_forbidden','viewer cannot end Employment');
SELECT throws_ok($$SELECT public.rehire_people_employee('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid,'d4400000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001',
  current_setting('test.today')::date+2,'monthly',18000,true)$$,
  '42501','people_rehire_forbidden','viewer cannot rehire');
SELECT throws_ok($$SELECT public.people_employment_history('d2200000-0000-4000-8000-000000000002',
  current_setting('test.employee_id')::uuid)$$,'42501','people_view_forbidden','history is tenant-scoped');
SELECT ok(public.people_employment_history('d2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)::text NOT LIKE '%17000.00%'
  AND NOT (public.people_employment_history('d2200000-0000-4000-8000-000000000001',
    current_setting('test.employee_id')::uuid)->'events'->1->'details' ? 'cancelled_future_compensation'),
  'people.view lifecycle history redacts cancelled compensation values from the private audit stream');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
