BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('a1100000-0000-4000-8000-000000000001','org-catalog-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('a1100000-0000-4000-8000-000000000002','org-catalog-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('a2200000-0000-4000-8000-000000000001','Org Catalog One','a1100000-0000-4000-8000-000000000001'),
 ('a2200000-0000-4000-8000-000000000002','Org Catalog Two','a1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('a2200000-0000-4000-8000-000000000001','a3300000-0000-4000-8000-000000000001','org-catalog.admin',1,ARRAY['tenant.administer']),
 ('a2200000-0000-4000-8000-000000000001','a3300000-0000-4000-8000-000000000002','org-catalog.viewer',1,ARRAY['people.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001'),
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000002','a1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001','a3300000-0000-4000-8000-000000000001'),
 ('a2200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000002','a3300000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES
 ('a2200000-0000-4000-8000-000000000001','a4400000-0000-4000-8000-000000000001','Catalog Employer',true),
 ('a2200000-0000-4000-8000-000000000002','a4400000-0000-4000-8000-000000000002','Other Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES
 ('a2200000-0000-4000-8000-000000000001','a5500000-0000-4000-8000-000000000001','a4400000-0000-4000-8000-000000000001','Catalog Site',true),
 ('a2200000-0000-4000-8000-000000000002','a5500000-0000-4000-8000-000000000002','a4400000-0000-4000-8000-000000000002','Other Site',true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('a2200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute',
 'a1100000-0000-4000-8000-000000000001','Organization catalog test');
INSERT INTO people.departments(tenant_id,code,name,created_by_user_id)
SELECT 'a2200000-0000-4000-8000-000000000001','PAGE-'||pg_catalog.lpad(n::text,2,'0'),
 'PAGEONLY '||pg_catalog.lpad(n::text,2,'0'),'a1100000-0000-4000-8000-000000000001'
FROM pg_catalog.generate_series(1,26) n;
INSERT INTO people.departments(tenant_id,code,name,created_by_user_id)
SELECT 'a2200000-0000-4000-8000-000000000001','OPTION-'||pg_catalog.lpad(n::text,4,'0'),
 'OPTION '||pg_catalog.lpad(n::text,4,'0'),'a1100000-0000-4000-8000-000000000001'
FROM pg_catalog.generate_series(1,972) n;
INSERT INTO people.departments(tenant_id,code,name,created_by_user_id)
VALUES ('a2200000-0000-4000-8000-000000000002','FOREIGN','Other Tenant Department','a1100000-0000-4000-8000-000000000001');
SELECT set_config('test.foreign_department_id',(
  SELECT id::text FROM people.departments WHERE tenant_id='a2200000-0000-4000-8000-000000000002' AND code='FOREIGN'),true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.root_department_id',(public.save_people_department(
  'a2200000-0000-4000-8000-000000000001',NULL,'ROOT','الإدارة الرئيسية',NULL,true)->>'id'),true);
SELECT set_config('test.child_department_id',(public.save_people_department(
  'a2200000-0000-4000-8000-000000000001',NULL,'CHILD','المبيعات',current_setting('test.root_department_id')::uuid,true)->>'id'),true);
SELECT set_config('test.job_id',(public.save_people_job(
  'a2200000-0000-4000-8000-000000000001',NULL,'SALES-1','مندوب مبيعات',current_setting('test.child_department_id')::uuid,true)->>'id'),true);
SELECT is(public.people_org_catalog('a2200000-0000-4000-8000-000000000001','departments','PAGEONLY',1)->'items'->0->>'code',
  'PAGE-01','department search matches a record');
SELECT is(pg_catalog.jsonb_array_length(public.people_org_catalog('a2200000-0000-4000-8000-000000000001','departments','PAGEONLY',1)->'items'),
  25,'first catalog page contains at most 25 rows');
SELECT is(public.people_org_catalog('a2200000-0000-4000-8000-000000000001','departments','PAGEONLY',1)->>'has_more','true',
  'first catalog page signals more results');
SELECT is(public.people_org_catalog('a2200000-0000-4000-8000-000000000001','departments','PAGEONLY',2)->'items'->0->>'code',
  'PAGE-26','second catalog page contains its first local result');
SELECT throws_ok($$SELECT public.people_org_catalog('a2200000-0000-4000-8000-000000000001','departments',NULL,1001)$$,
  '22023','people_org_query_invalid','catalog page cap is enforced');
SELECT throws_ok($$SELECT public.people_org_catalog('a2200000-0000-4000-8000-000000000001',NULL,NULL,1)$$,
  '22023','people_org_query_invalid','null catalog type is rejected');
SELECT is(public.people_org_catalog_options('a2200000-0000-4000-8000-000000000001','departments')->>'truncated','false',
  'exactly 1000 catalog options are not marked truncated');
SELECT lives_ok($$SELECT public.save_people_department('a2200000-0000-4000-8000-000000000001',NULL,
  'OPTION-1001','تجاوز الخيارات',NULL,true)$$,'the catalog can exceed its bounded options page');
SELECT is(public.people_org_catalog_options('a2200000-0000-4000-8000-000000000001','departments')->>'truncated','true',
  'the options response reports a 1001st result accurately');
SELECT throws_ok($$SELECT public.save_people_department('a2200000-0000-4000-8000-000000000001',NULL,'BAD','غير مسموح',
  current_setting('test.foreign_department_id')::uuid,true)$$,
  '23503','people_org_parent_unavailable','cross-Tenant department parent is rejected');
SELECT throws_ok($$SELECT public.save_people_job('a2200000-0000-4000-8000-000000000001',NULL,'BAD-JOB','وظيفة غير مسموحة',
  current_setting('test.foreign_department_id')::uuid,true)$$,
  '23503','people_org_department_unavailable','cross-Tenant job department is rejected');
SELECT throws_ok($$SELECT public.save_people_department('a2200000-0000-4000-8000-000000000001',
  current_setting('test.root_department_id')::uuid,'ROOT','الإدارة الرئيسية',
  current_setting('test.child_department_id')::uuid,true)$$,
  '23514','people_org_department_cycle','department hierarchy cycle is rejected');

SELECT set_config('test.employee_id',(public.create_people_employee('a2200000-0000-4000-8000-000000000001',
  'ORG-EMP-1','موظف اختبار','a4400000-0000-4000-8000-000000000001','a5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date,'monthly',10000,true,
  current_setting('test.child_department_id')::uuid,current_setting('test.job_id')::uuid)->>'employee_id'),true);
SELECT set_config('test.assignment_id',public.people_employee_snapshot('a2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'assignment'->>'id',true);
SELECT ok(current_setting('test.assignment_id') IS NOT NULL,'active same-Tenant department and job are assignable');
SELECT throws_ok($$SELECT public.save_people_job('a2200000-0000-4000-8000-000000000001',
  current_setting('test.job_id')::uuid,'SALES-1','مندوب مبيعات',current_setting('test.root_department_id')::uuid,true)$$,
  '23514','people_org_job_department_in_use','referenced Job cannot be moved to another Department');
SELECT lives_ok($$SELECT public.save_people_job('a2200000-0000-4000-8000-000000000001',
  current_setting('test.job_id')::uuid,'SALES-RENAMED','مندوب مبيعات',current_setting('test.child_department_id')::uuid,true)$$,
  'referenced Job can be renamed while retaining its Department');
SELECT lives_ok($$SELECT public.save_people_job('a2200000-0000-4000-8000-000000000001',
  current_setting('test.job_id')::uuid,'SALES-RENAMED','مندوب مبيعات',current_setting('test.child_department_id')::uuid,false)$$,
  'job can be deactivated');
SELECT is((public.people_org_catalog_record('a2200000-0000-4000-8000-000000000001','jobs',
  current_setting('test.job_id')::uuid)->>'is_active'),'false','disabled job status is visible');
SELECT throws_ok($$SELECT public.create_people_employee('a2200000-0000-4000-8000-000000000001',
  'ORG-EMP-2','موظف آخر','a4400000-0000-4000-8000-000000000001','a5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date,'monthly',10000,true,
  current_setting('test.child_department_id')::uuid,current_setting('test.job_id')::uuid)$$,
  '23503','people_job_unavailable','disabled job is rejected for a new employee assignment');
RESET ROLE;
WITH updated AS (
  UPDATE people.work_assignments SET valid_until=valid_from+1
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
    AND id=current_setting('test.assignment_id')::uuid
  RETURNING id
) SELECT is((SELECT count(*)::integer FROM updated),1,
  'validity-only update changes the existing assignment while its Job is disabled');
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT public.save_people_department('a2200000-0000-4000-8000-000000000001',
  current_setting('test.root_department_id')::uuid,'ROOT','الإدارة الرئيسية',NULL,false)$$,
  'parent department can be deactivated');
SELECT is((public.people_org_catalog_record('a2200000-0000-4000-8000-000000000001','departments',
  current_setting('test.root_department_id')::uuid)->>'is_active'),'false','disabled parent status is visible');
SELECT is(public.people_org_catalog('a2200000-0000-4000-8000-000000000001','departments','CHILD',1)->'items'->0->>'effectively_active',
  'false','active child under disabled parent is unavailable for new assignments');
SELECT ok(NOT EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements(public.people_onboarding_options(
  'a2200000-0000-4000-8000-000000000001')->'departments') item
  WHERE item->>'id'=current_setting('test.child_department_id')),
  'active child under a disabled parent is omitted from employee choices');
SELECT is((public.people_employee_snapshot('a2200000-0000-4000-8000-000000000001',
  current_setting('test.employee_id')::uuid)->'assignment'->>'id'),
  current_setting('test.assignment_id'),'deactivation preserves the historical work assignment');
SELECT throws_ok($$SELECT public.create_people_employee('a2200000-0000-4000-8000-000000000001',
  'ORG-EMP-3','موظف ثالث','a4400000-0000-4000-8000-000000000001','a5500000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date,'monthly',10000,true,
  current_setting('test.child_department_id')::uuid,NULL)$$,
  '23503','people_assignment_department_unavailable','child under disabled parent is rejected for a new assignment');
RESET ROLE;
WITH updated AS (
  UPDATE people.work_assignments SET valid_until=valid_from+2
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
    AND id=current_setting('test.assignment_id')::uuid
  RETURNING id
) SELECT is((SELECT count(*)::integer FROM updated),1,
  'unchanged catalog context remains editable after the referenced Department is archived');
SELECT throws_ok($$UPDATE people.work_assignments
  SET department_id=current_setting('test.root_department_id')::uuid
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
    AND id=current_setting('test.assignment_id')::uuid$$,
  '23503','people_assignment_department_unavailable',
  'changing the catalog context to an archived Department is rejected');
SELECT is((SELECT count(*)::integer FROM people.work_assignments
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
    AND id=current_setting('test.assignment_id')::uuid
    AND department_id=current_setting('test.child_department_id')::uuid
    AND valid_until=valid_from+2),1,
  'rejected catalog-context update leaves the assignment unchanged');
SELECT is((SELECT prosecdef FROM pg_catalog.pg_proc
  WHERE oid='people.prevent_job_department_change_with_assignments()'::regprocedure),false,
  'Job history guard uses invoker rights');
SELECT is((SELECT details->>'department_id' FROM people.audit_events
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
    AND employee_id=current_setting('test.employee_id')::uuid AND event_key='employee.onboarded'),
  current_setting('test.child_department_id'),'employee onboarding audit records the initial Department');
SELECT is((SELECT details->>'job_id' FROM people.audit_events
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001'
    AND employee_id=current_setting('test.employee_id')::uuid AND event_key='employee.onboarded'),
  current_setting('test.job_id'),'employee onboarding audit records the initial Job');
SELECT ok(NOT has_table_privilege('authenticated','people.organization_audit_events','SELECT'),
  'organization audit is unavailable to direct table reads');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.organization_audit_events
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001' AND actor_user_id='a1100000-0000-4000-8000-000000000001'
    AND subject_type='department' AND subject_id=current_setting('test.root_department_id')::uuid
    AND event_key='department.deactivated'),1,'department deactivation is audited with tenant and actor');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.organization_audit_events
  WHERE tenant_id='a2200000-0000-4000-8000-000000000001' AND actor_user_id='a1100000-0000-4000-8000-000000000001'
    AND subject_type='job' AND subject_id=current_setting('test.job_id')::uuid
    AND event_key='job.deactivated'),1,'job deactivation is audited with tenant and actor');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1100000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.people_org_catalog('a2200000-0000-4000-8000-000000000002','departments',NULL,1)$$,
  '42501','people_org_view_forbidden','viewer cannot read another Tenant catalog');
SELECT throws_ok($$SELECT public.save_people_job('a2200000-0000-4000-8000-000000000001',NULL,'NO','ممنوع',NULL,true)$$,
  '42501','people_org_manage_forbidden','read-only People viewer cannot change catalog records');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
