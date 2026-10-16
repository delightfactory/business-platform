BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e4c10000-0000-4000-8000-000000000001','calendar-seed@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e4c20000-0000-4000-8000-000000000001','Calendar test','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('e4c20000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000001','temporal.admin',1,
  ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.manage','attendance.manage','attendance_policy.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('e4c20000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','e4c10000-0000-4000-8000-000000000001','Calendar people fixture');
-- No attendance entitlement: all calendar reads must support historical access.
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('e4c20000-0000-4000-8000-000000000001','e4c40000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default)
VALUES
 ('e4c20000-0000-4000-8000-000000000001','e4c50000-0000-4000-8000-000000000001','e4c40000-0000-4000-8000-000000000001','Original',true),
 ('e4c20000-0000-4000-8000-000000000001','e4c50000-0000-4000-8000-000000000002','e4c40000-0000-4000-8000-000000000001','Transfer',false);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version)
VALUES ('e4c20000-0000-4000-8000-000000000001','e4c60000-0000-4000-8000-000000000001','FLEX',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,
  required_minutes,earliest_punch,latest_punch,created_by)
VALUES ('e4c20000-0000-4000-8000-000000000001','e4c60000-0000-4000-8000-000000000001',1,'Flexible','flexible','Africa/Cairo',
  ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59','e4c10000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar_employee1',public.create_people_employee('e4c20000-0000-4000-8000-000000000001','CAL-1','Calendar person1','e4c40000-0000-4000-8000-000000000001','e4c50000-0000-4000-8000-000000000001','2020-01-01','monthly',1000,true)::text,true);
SELECT set_config('test.calendar_employee2',public.create_people_employee('e4c20000-0000-4000-8000-000000000001','CAL-2','Calendar person2','e4c40000-0000-4000-8000-000000000001','e4c50000-0000-4000-8000-000000000001','2020-01-01','monthly',1000,true)::text,true);
RESET ROLE;
INSERT INTO time.work_instances(tenant_id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,status,created_by)
SELECT a.tenant_id,a.id,a.employment_id,e.employee_id,a.site_id,d.day,'e4c60000-0000-4000-8000-000000000001',1,'Pacific/Auckland',d.status,'e4c10000-0000-4000-8000-000000000001'
FROM people.work_assignments a JOIN people.employments e ON e.tenant_id=a.tenant_id AND e.id=a.employment_id CROSS JOIN (VALUES ('2026-09-30'::date,'ready'),('2026-10-01'::date,'open'),('2026-10-14'::date,'approved'),('2026-10-31'::date,'needs_review'),('2026-11-01'::date,'approved')) d(day,status)
WHERE a.tenant_id='e4c20000-0000-4000-8000-000000000001' AND a.employment_id=(current_setting('test.calendar_employee1')::jsonb->>'employment_id')::uuid;
INSERT INTO time.work_instances(tenant_id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,status,created_by)
SELECT a.tenant_id,a.id,a.employment_id,e.employee_id,a.site_id,d.day,'e4c60000-0000-4000-8000-000000000001',1,'Africa/Cairo',d.status,'e4c10000-0000-4000-8000-000000000001'
FROM people.work_assignments a JOIN people.employments e ON e.tenant_id=a.tenant_id AND e.id=a.employment_id CROSS JOIN (VALUES ('2026-10-14'::date,'ready'),('2026-10-31'::date,'needs_review')) d(day,status)
WHERE a.tenant_id='e4c20000-0000-4000-8000-000000000001' AND a.employment_id=(current_setting('test.calendar_employee2')::jsonb->>'employment_id')::uuid;
SELECT set_config('test.calendar_instances_before',(SELECT count(*)::text FROM time.work_instances WHERE tenant_id='e4c20000-0000-4000-8000-000000000001'),true);
SELECT is((SELECT provolatile::text FROM pg_proc WHERE oid='public.attendance_month_calendar(uuid,date)'::regprocedure),'s','month calendar is stable');
SELECT ok(NOT has_function_privilege('anon','public.attendance_month_calendar(uuid,date)','EXECUTE'),'anonymous calendar execution denied');
SELECT ok(NOT has_function_privilege('service_role','public.attendance_month_calendar(uuid,date)','EXECUTE'),'service role has no direct grant');
SET LOCAL ROLE authenticated;
SELECT set_config('test.calendar_result',public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')::text,true);
SELECT is(jsonb_array_length(current_setting('test.calendar_result')::jsonb->'days'),3,'only three saved civil dates in month, outside boundaries excluded');
SELECT is(current_setting('test.calendar_result')::jsonb->'days'->0->>'date','2026-10-01','operational date, not timezone or UTC instant, determines month');
SELECT is((current_setting('test.calendar_result')::jsonb->'days'->1->>'approved')::int,1,'approved records counted once');
SELECT is((current_setting('test.calendar_result')::jsonb->'days'->1->>'ready')::int,1,'ready records from another employee counted');
SELECT is((current_setting('test.calendar_result')::jsonb->'days'->2->>'needs_review')::int,2,'review records grouped across employees');
SELECT ok(NOT (current_setting('test.calendar_result')::jsonb->'days'->0 ? 'employee_id'),'summary exposes no employee projection');
SELECT is(jsonb_array_length(public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-02-01')->'days'),0,'empty month is explicit sparse result');
SELECT throws_ok($q$SELECT public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-02')$q$,'22023','attendance_month_invalid','non-first day rejected');
SELECT throws_ok($q$SELECT public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001',NULL)$q$,'22023','attendance_month_invalid','null month rejected');
SELECT throws_ok($q$SELECT public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','infinity')$q$,'22023','attendance_month_invalid','infinite date rejected');
SELECT throws_ok($q$SELECT public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','1999-12-01')$q$,'22023','attendance_month_invalid','month below bounded range rejected');
SELECT throws_ok($q$SELECT public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2101-01-01')$q$,'22023','attendance_month_invalid','month above bounded range rejected');
SELECT throws_ok($q$SELECT public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000099','2026-10-01')$q$,'42501','attendance_view_forbidden','cross tenant access denied before reading');
RESET ROLE;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES ('e4c10000-0000-4000-8000-000000000002','calendar-2@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000002','calendar.role2',1,ARRAY['attendance.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000002','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000002','e4c30000-0000-4000-8000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000002',true);
SELECT is(jsonb_array_length(public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')->'days'),3,'attendance.view reads same complete calendar');
RESET ROLE;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES ('e4c10000-0000-4000-8000-000000000003','calendar-3@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000003','calendar.role3',1,ARRAY['attendance.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000003','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000003','e4c30000-0000-4000-8000-000000000003');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000003',true);
SELECT is(jsonb_array_length(public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')->'days'),3,'attendance.manage reads same complete calendar');
RESET ROLE;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES ('e4c10000-0000-4000-8000-000000000004','calendar-4@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000004','calendar.role4',1,ARRAY['attendance.correct']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000004','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000004','e4c30000-0000-4000-8000-000000000004');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000004',true);
SELECT is(jsonb_array_length(public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')->'days'),3,'attendance.correct reads same complete calendar');
RESET ROLE;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES ('e4c10000-0000-4000-8000-000000000005','calendar-5@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000005','calendar.role5',1,ARRAY['attendance.approve']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000005','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000005','e4c30000-0000-4000-8000-000000000005');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000005',true);
SELECT is(jsonb_array_length(public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')->'days'),3,'attendance.approve reads same complete calendar');
RESET ROLE;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES ('e4c10000-0000-4000-8000-000000000006','calendar-6@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000006','calendar.role6',1,ARRAY['tenant.administer']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000006','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000006','e4c30000-0000-4000-8000-000000000006');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000006',true);
SELECT is(jsonb_array_length(public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')->'days'),3,'tenant.administer reads same complete calendar');
RESET ROLE;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES ('e4c10000-0000-4000-8000-000000000007','calendar-7@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c30000-0000-4000-8000-000000000007','calendar.role7',1,ARRAY['people.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000007','e4c10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES ('e4c20000-0000-4000-8000-000000000001','e4c10000-0000-4000-8000-000000000007','e4c30000-0000-4000-8000-000000000007');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000007',true);
SELECT throws_ok($q$SELECT public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')$q$,'42501','attendance_view_forbidden','unrelated active member cannot read calendar');
RESET ROLE;
-- Confirm historical access without changing any entitlement intervals.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e4c10000-0000-4000-8000-000000000002',true);
SELECT is((public.time_attendance_access_snapshot('e4c20000-0000-4000-8000-000000000001')->>'entitlement_enabled')::boolean,false,'fixture proves attendance entitlement is off');
SELECT is(jsonb_array_length(public.attendance_month_calendar('e4c20000-0000-4000-8000-000000000001','2026-10-01')->'days'),3,'entitlement-off historical month readable');
RESET ROLE;
SELECT is((SELECT count(*)::text FROM time.work_instances WHERE tenant_id='e4c20000-0000-4000-8000-000000000001'),current_setting('test.calendar_instances_before'),'month reads created no instances');
SELECT * FROM finish();
ROLLBACK;
