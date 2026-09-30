BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e9100000-0000-4000-8000-000000000101','csv-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9100000-0000-4000-8000-000000000102','csv-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access) VALUES ('e9100000-0000-4000-8000-000000000101',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('e9110000-0000-4000-8000-000000000101','Attendance import test','e9100000-0000-4000-8000-000000000101');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9120000-0000-4000-8000-000000000101','attendance.import.operator',1,ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage'],'false'),
 ('e9110000-0000-4000-8000-000000000101','e9120000-0000-4000-8000-000000000102','attendance.import.reader',1,ARRAY['attendance.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000101','active','e9100000-0000-4000-8000-000000000101'),
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000102','active','e9100000-0000-4000-8000-000000000101');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000101','e9120000-0000-4000-8000-000000000101'),
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000102','e9120000-0000-4000-8000-000000000102');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('e9110000-0000-4000-8000-000000000101','hr.people',true,now()-interval '1 minute','e9100000-0000-4000-8000-000000000101','attendance import test'),
 ('e9110000-0000-4000-8000-000000000101','hr.attendance',true,now()-interval '1 minute','e9100000-0000-4000-8000-000000000101','attendance import test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('e9110000-0000-4000-8000-000000000101','e9130000-0000-4000-8000-000000000101','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000101','e9130000-0000-4000-8000-000000000101','Main',true,true),
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000102','e9130000-0000-4000-8000-000000000101','Ambiguous',false,true),
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000103','e9130000-0000-4000-8000-000000000101','Ambiguous',false,true),
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000104','e9130000-0000-4000-8000-000000000101','Other',false,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9150000-0000-4000-8000-000000000101','FLEX',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by)
VALUES ('e9110000-0000-4000-8000-000000000101','e9150000-0000-4000-8000-000000000101',1,'يوم مرن','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59','e9100000-0000-4000-8000-000000000101');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.employee',public.create_people_employee('e9110000-0000-4000-8000-000000000101','CSV-1','موظف الاستيراد','e9130000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000101',(now() AT TIME ZONE 'Africa/Cairo')::date-3,'monthly',1000,true)::text,true);
SELECT set_config('test.employment',(current_setting('test.employee')::jsonb->>'employment_id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='e9150000-0000-4000-8000-000000000101',work_policy_version=1
 WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND employment_id=current_setting('test.employment')::uuid;
SELECT set_config('test.event_in',(to_char((((((now() AT TIME ZONE 'Africa/Cairo')::date-1)::timestamp+'10:00'::time) AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'UTC'),'YYYY-MM-DD"T"HH24:MI:SS')||'+00:00'),true);
SELECT set_config('test.event_out',(to_char((((((now() AT TIME ZONE 'Africa/Cairo')::date-1)::timestamp+'18:00'::time) AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'UTC'),'YYYY-MM-DD"T"HH24:MI:SS')||'+00:00'),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.preview',public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('source_line_hint',2,'employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','device-001')))::text,true);
SELECT is(current_setting('test.preview')::jsonb->0->>'status','ready','valid mapped event is ready in preview');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.work_instances WHERE tenant_id='e9110000-0000-4000-8000-000000000101'),0,'preview does not materialize a Work Instance');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT is(public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('source_line_hint',3,'employee_code','CSV-1','site_name','Main','happened_at','not-a-timestamp','direction','in','source_event_key','bad-time')))->0->>'status','rejected','malformed timestamp is rejected with a row result');
SELECT is(public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Ambiguous','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','amb-site')))->0->>'status','rejected','ambiguous duplicate site names are rejected rather than choosing one');
SELECT is(public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Other','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','wrong-site')))->0->>'status','rejected','same-Tenant Site must also match the effective Assignment');
SELECT throws_ok($$SELECT public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000199','[]'::jsonb)$$,'42501','attendance_import_forbidden','cross-tenant preview is denied');
SELECT set_config('test.confirm',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('source_line_hint',2,'employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','device-001'),
 jsonb_build_object('source_line_hint',3,'employee_code','NO-SUCH-EMPLOYEE','site_name','Main','happened_at',current_setting('test.event_in'),'direction','out','source_event_key','device-bad'))::jsonb)::text,true);
SELECT is((current_setting('test.confirm')::jsonb->>'accepted_count')::int,1,'mixed batch imports the valid row');
SELECT is((current_setting('test.confirm')::jsonb->>'rejected_count')::int,1,'mixed batch reports the invalid row without rolling back the valid row');
SELECT is(current_setting('test.confirm')::jsonb->'rows'->1->>'status','rejected','row error is visible in partial result');
SELECT is(public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','device-001')))->>'duplicate_count','1','same source event reimport is idempotently classified as duplicate');
SELECT is(public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','out','source_event_key','device-001')))->>'rejected_count','1','same source key with conflicting payload is rejected');
SELECT set_config('test.instance',(current_setting('test.confirm')::jsonb->'rows'->0->>'instance_id'),true);
SELECT set_config('test.partial',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('source_line_hint',4,'employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_out'),'direction','out','source_event_key','device-002'),
 jsonb_build_object('source_line_hint',5,'employee_code','NO-SUCH-EMPLOYEE','site_name','Main','happened_at',current_setting('test.event_out'),'direction','in','source_event_key','device-003'))::jsonb)::text,true);
SELECT is((current_setting('test.partial')::jsonb->>'accepted_count')::int,1,'second valid event is accepted independently');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000101',current_setting('test.instance')::uuid)->'interpretation'->>'state'),'ready','imported events use the existing Work Instance interpreter');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000101',current_setting('test.instance')::uuid)->'punches'->0->>'source_type'),'import','attendance detail preserves imported-versus-manual event source');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000101',current_setting('test.instance')::uuid)->'punches'->0->>'source_event_key'),'device-001','attendance detail displays stable external event provenance');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.manual_punches WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_type='import' AND source_event_key IN('device-001','device-002')),2,'canonical imported evidence retains stable source keys');
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND event_key='attendance.import.event'),2,'each imported event has actor-attributed audit provenance');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000102',true);
SELECT throws_ok($$SELECT public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101','[{"employee_code":"CSV-1"}]'::jsonb)$$,'42501','attendance_import_forbidden','view-only attendance member cannot preview import');
SELECT throws_ok($$SELECT public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101','[{"employee_code":"CSV-1"}]'::jsonb)$$,'42501','attendance_import_forbidden','view-only attendance member cannot confirm import');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
