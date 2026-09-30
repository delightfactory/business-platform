BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('d8000000-0000-4000-8000-000000000001','time-policy@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),('d8000000-0000-4000-8000-000000000002','time-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES('d8100000-0000-4000-8000-000000000001','Attendance Enabled','d8000000-0000-4000-8000-000000000001'),
      ('d8100000-0000-4000-8000-000000000002','Attendance Disabled','d8000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES('d8100000-0000-4000-8000-000000000001','d8200000-0000-4000-8000-000000000001','attendance.policy.manager.v1',1,ARRAY['attendance_policy.manage','people.view','people.manage','employment.manage','compensation.manage','org_context.manage'],'false'),('d8100000-0000-4000-8000-000000000001','d8200000-0000-4000-8000-000000000002','people.reader.v1',1,ARRAY['people.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES('d8100000-0000-4000-8000-000000000001','d8000000-0000-4000-8000-000000000001','active','d8000000-0000-4000-8000-000000000001'),
      ('d8100000-0000-4000-8000-000000000002','d8000000-0000-4000-8000-000000000001','active','d8000000-0000-4000-8000-000000000001'),('d8100000-0000-4000-8000-000000000001','d8000000-0000-4000-8000-000000000002','active','d8000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('d8100000-0000-4000-8000-000000000001','d8300000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES('d8100000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001','d8300000-0000-4000-8000-000000000001','Main site',true,true);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES('d8100000-0000-4000-8000-000000000001','d8000000-0000-4000-8000-000000000001','d8200000-0000-4000-8000-000000000001'),('d8100000-0000-4000-8000-000000000001','d8000000-0000-4000-8000-000000000002','d8200000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES('d8100000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','d8000000-0000-4000-8000-000000000001','policy test'),('d8100000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','d8000000-0000-4000-8000-000000000001','People context test');

INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES('d8100000-0000-4000-8000-000000000002','d8600000-0000-4000-8000-000000000001','FOREIGN',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,work_days,shift_start,shift_end,created_by) VALUES('d8100000-0000-4000-8000-000000000002','d8600000-0000-4000-8000-000000000001',1,'Foreign fixed','fixed',ARRAY[1]::smallint[],'09:00','17:00','d8000000-0000-4000-8000-000000000001');
SELECT ok(NOT has_table_privilege('authenticated','time.work_policy_versions','INSERT'),'authenticated cannot write policy versions directly');
SELECT ok(NOT has_table_privilege('authenticated','time.work_policy_audit_events','UPDATE'),'authenticated cannot rewrite policy audit');
SELECT ok(NOT has_function_privilege('anon','public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer)','EXECUTE'),'anonymous caller cannot save policy');
SELECT is(platform_private.tenant_capability_is_enabled('d8100000-0000-4000-8000-000000000001','hr.attendance',now()),true,'Attendance entitlement is evaluated independently');
SELECT is(platform_private.tenant_capability_is_enabled('d8100000-0000-4000-8000-000000000002','hr.attendance',now()),false,'Attendance defaults disabled for another tenant');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d8000000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.save_time_work_policy('d8100000-0000-4000-8000-000000000001',NULL,'DAY','دوام صباحي','fixed','Africa/Cairo',ARRAY[1,2,3,4,5]::smallint[],'09:00','17:00',false,30,NULL,NULL,NULL,120,360)$$,'authorized manager creates named fixed policy');
SELECT is((public.time_work_policy_catalog('d8100000-0000-4000-8000-000000000001')->>'can_manage')::boolean,true,'catalog grants management only with entitlement and permission');
SELECT set_config('test.policy_id',(public.time_work_policy_catalog('d8100000-0000-4000-8000-000000000001')->'items'->0->>'id'),true);
SELECT lives_ok($$SELECT public.save_time_work_policy('d8100000-0000-4000-8000-000000000001',current_setting('test.policy_id')::uuid,'DAY','دوام صباحي مطوّر','fixed','Africa/Cairo',ARRAY[1,2,3,4,5]::smallint[],'08:30','17:00',false,30,NULL,NULL,NULL,120,360)$$,'editing a named policy appends a new version');
SELECT is((public.time_work_policy_catalog('d8100000-0000-4000-8000-000000000001')->'items'->0->>'head_version')::integer,2,'catalog exposes the new immutable head version');
SELECT is((public.time_work_policy_catalog('d8100000-0000-4000-8000-000000000001')->'items'->0->>'shift_start'),'08:30:00','revision persists an edited schedule field');
SELECT lives_ok($$SELECT public.save_time_work_policy('d8100000-0000-4000-8000-000000000001',NULL,'FLEX','ساعات مرنة','flexible','Africa/Cairo',ARRAY[1,2,3,4,5]::smallint[],NULL,NULL,false,0,480,'07:00','11:00',120,360)$$,'bounded flexible-duration policy is supported');
SELECT set_config('test.created_employee',public.create_people_employee('d8100000-0000-4000-8000-000000000001','TIME-EMP','موظف سياسة','d8300000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-5,'monthly',10000,true)::text,true);
SELECT set_config('test.employment_id',(current_setting('test.created_employee')::jsonb->>'employment_id'),true);
SELECT is((public.people_employee_snapshot('d8100000-0000-4000-8000-000000000001',(current_setting('test.created_employee')::jsonb->>'employee_id')::uuid)->'employment'->>'id'),current_setting('test.employment_id'),'People employee onboarding stays usable when Attendance is separately enabled');
SELECT lives_ok($$SELECT public.assign_people_work_policy('d8100000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,current_setting('test.policy_id')::uuid,timezone('Africa/Cairo',now())::date)$$,'People manager assigns the active named policy with an effective date');
SELECT set_config('test.today_employee',public.create_people_employee('d8100000-0000-4000-8000-000000000001','TODAY-TIME-EMP','موظف يبدأ اليوم','d8300000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date,'monthly',10000,true)::text,true);
SELECT set_config('test.today_employment',(current_setting('test.today_employee')::jsonb->>'employment_id'),true);
SELECT set_config('test.initial_assignment_before',(public.people_employee_snapshot('d8100000-0000-4000-8000-000000000001',(current_setting('test.today_employee')::jsonb->>'employee_id')::uuid)->'assignment'->>'id'),true);
SELECT is(public.assign_people_work_policy('d8100000-0000-4000-8000-000000000001',current_setting('test.today_employment')::uuid,current_setting('test.policy_id')::uuid,timezone('Africa/Cairo',now())::date)->>'state','initial_assigned','same-day hire can receive optional policy without a new overlapping interval');
SELECT is((public.people_employee_snapshot('d8100000-0000-4000-8000-000000000001',(current_setting('test.today_employee')::jsonb->>'employee_id')::uuid)->'assignment'->>'id'),current_setting('test.initial_assignment_before'),'same-day assignment keeps its original row identity');
SELECT set_config('test.future_assignment_id',(public.assign_people_work_policy('d8100000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,current_setting('test.policy_id')::uuid,timezone('Africa/Cairo',now())::date+5)->>'assignment_id'),true);
SELECT ok(public.people_work_policy_panel('d8100000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid)->'history' @> jsonb_build_array(jsonb_build_object('policy_id',current_setting('test.policy_id')::uuid)),'employee history shows the assigned policy reference');
SELECT throws_ok($$SELECT public.assign_people_work_policy('d8100000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,'d8600000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date+3)$$,'23503','people_work_policy_inactive_or_foreign','cross-Tenant policy reference is rejected');
SELECT lives_ok($$SELECT public.cancel_people_work_assignment('d8100000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,current_setting('test.future_assignment_id')::uuid)$$,'future policy assignment can be cancelled before taking effect');
SELECT set_config('test.future_employee',public.create_people_employee('d8100000-0000-4000-8000-000000000001','FUTURE-TIME-EMP','موظف يبدأ لاحقًا','d8300000-0000-4000-8000-000000000001','d8400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date+2,'monthly',0,false)::text,true);
SELECT throws_ok($$SELECT public.assign_people_work_policy('d8100000-0000-4000-8000-000000000001',(current_setting('test.future_employee')::jsonb->>'employment_id')::uuid,current_setting('test.policy_id')::uuid,timezone('Africa/Cairo',now())::date)$$,'23514','people_work_policy_before_employment_start','policy cannot be assigned before Employment begins');
SELECT lives_ok($$SELECT public.set_time_work_policy_active('d8100000-0000-4000-8000-000000000001',current_setting('test.policy_id')::uuid,false)$$,'policy can be disabled for future assignments');
SELECT throws_ok($$SELECT public.assign_people_work_policy('d8100000-0000-4000-8000-000000000001',current_setting('test.employment_id')::uuid,current_setting('test.policy_id')::uuid,timezone('Africa/Cairo',now())::date+2)$$,'23503','people_work_policy_inactive_or_foreign','inactive policy cannot be assigned');
SELECT throws_ok($$SELECT public.save_time_work_policy('d8100000-0000-4000-8000-000000000002',NULL,'DENIED','No Attendance','fixed','Africa/Cairo',ARRAY[1]::smallint[],'09:00','17:00',false,0,NULL,NULL,NULL,0,0)$$,'42501','attendance_policy_manage_forbidden','cross-tenant or non-entitled template writes are denied');
SELECT set_config('request.jwt.claim.sub','d8000000-0000-4000-8000-000000000002',true);
SELECT is((public.time_work_policy_catalog('d8100000-0000-4000-8000-000000000001')->>'can_manage')::boolean,false,'People reader can view but cannot manage Attendance templates');
SELECT throws_ok($$SELECT public.save_time_work_policy('d8100000-0000-4000-8000-000000000001',NULL,'NO','No permission','fixed','Africa/Cairo',ARRAY[1]::smallint[],'09:00','17:00',false,0,NULL,NULL,NULL,0,0)$$,'42501','attendance_policy_manage_forbidden','People permission does not grant Time policy management');
SELECT set_config('request.jwt.claim.sub','d8000000-0000-4000-8000-000000000001',true);
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM time.work_policy_audit_events WHERE tenant_id='d8100000-0000-4000-8000-000000000001' AND event_key='policy.initial_assignment'),1,'same-day policy assignment records Time audit');
SELECT is((SELECT count(*)::integer FROM time.work_policy_audit_events WHERE tenant_id='d8100000-0000-4000-8000-000000000001' AND event_key='policy.assignment_cancelled'),1,'cancellation preserves policy context in append-only Time audit');
SELECT is((SELECT count(*)::integer FROM time.work_policy_versions WHERE tenant_id='d8100000-0000-4000-8000-000000000001'),3,'fixed revisions and flexible policy remain versioned separately');
SELECT throws_ok($$UPDATE time.work_policy_versions SET name='rewritten' WHERE tenant_id='d8100000-0000-4000-8000-000000000001'$$,'55000','time_work_policy_version_immutable','policy versions cannot be rewritten');

SELECT is((SELECT count(*)::integer FROM time.work_policy_audit_events WHERE tenant_id='d8100000-0000-4000-8000-000000000001' AND actor_user_id='d8000000-0000-4000-8000-000000000001' AND event_key='policy.created'),2,'template creation records actor and event');
SELECT throws_ok($$UPDATE time.work_policy_audit_events SET details='{}' WHERE tenant_id='d8100000-0000-4000-8000-000000000001'$$,'55000','time_work_policy_audit_append_only','policy audit cannot be changed');

SELECT * FROM finish();
ROLLBACK;
