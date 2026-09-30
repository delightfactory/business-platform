BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('fa010000-0000-4000-8000-000000000001','queue-scale-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('fa110000-0000-4000-8000-000000000001','Queue scale tenant','fa010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('fa110000-0000-4000-8000-000000000001','fa210000-0000-4000-8000-000000000001','queue.scale.operator',1,
  ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage',
    'attendance.view','attendance.manage','attendance.correct','attendance.approve'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('fa110000-0000-4000-8000-000000000001','fa010000-0000-4000-8000-000000000001','active','fa010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('fa110000-0000-4000-8000-000000000001','fa010000-0000-4000-8000-000000000001','fa210000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('fa110000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','fa010000-0000-4000-8000-000000000001','queue scale test'),
       ('fa110000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','fa010000-0000-4000-8000-000000000001','queue scale test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('fa110000-0000-4000-8000-000000000001','fa310000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('fa110000-0000-4000-8000-000000000001','fa410000-0000-4000-8000-000000000001','fa310000-0000-4000-8000-000000000001','Main',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version)
VALUES ('fa110000-0000-4000-8000-000000000001','fa510000-0000-4000-8000-000000000001','Q-SCALE',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,
  shift_start,shift_end,ends_next_day,break_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes)
VALUES ('fa110000-0000-4000-8000-000000000001','fa510000-0000-4000-8000-000000000001',1,
  'Queue scale shift','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],
  '22:00','06:00',true,30,'fa010000-0000-4000-8000-000000000001',true,30,15);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
SELECT public.create_people_employee('fa110000-0000-4000-8000-000000000001','RQS-1','Queue employee one',
  'fa310000-0000-4000-8000-000000000001','fa410000-0000-4000-8000-000000000001',
  timezone('Africa/Cairo',now())::date-14,'monthly',1000,true);
SELECT public.create_people_employee('fa110000-0000-4000-8000-000000000001','RQS-2','Queue employee two',
  'fa310000-0000-4000-8000-000000000001','fa410000-0000-4000-8000-000000000001',
  timezone('Africa/Cairo',now())::date-14,'monthly',1000,true);
SELECT public.create_people_employee('fa110000-0000-4000-8000-000000000001','RQS-3','Queue employee three',
  'fa310000-0000-4000-8000-000000000001','fa410000-0000-4000-8000-000000000001',
  timezone('Africa/Cairo',now())::date-14,'monthly',1000,true);
SELECT public.create_people_employee('fa110000-0000-4000-8000-000000000001','RQS-4','Queue employee four',
  'fa310000-0000-4000-8000-000000000001','fa410000-0000-4000-8000-000000000001',
  timezone('Africa/Cairo',now())::date-14,'monthly',1000,true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='fa510000-0000-4000-8000-000000000001',work_policy_version=1
WHERE tenant_id='fa110000-0000-4000-8000-000000000001';
SELECT set_config('test.date',(timezone('Africa/Cairo',now())::date-7)::text,true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open',public.attendance_open_day('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,NULL,50)::text,true);
SELECT set_config('test.one',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item
  WHERE item->>'employee_code'='RQS-1'),true);
SELECT set_config('test.two',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item
  WHERE item->>'employee_code'='RQS-2'),true);
SELECT set_config('test.three',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item
  WHERE item->>'employee_code'='RQS-3'),true);

SELECT public.record_manual_attendance_punch_local('fa110000-0000-4000-8000-000000000001',current_setting('test.one')::uuid,
  'in',(current_setting('test.date')||' 22:00')::timestamp,'fa610000-0000-4000-8000-000000000001','Queue test entry');
SELECT public.record_manual_attendance_punch_local('fa110000-0000-4000-8000-000000000001',current_setting('test.one')::uuid,
  'out',((current_setting('test.date')::date+1)::text||' 06:45')::timestamp,'fa610000-0000-4000-8000-000000000002','Queue test exit');
SELECT public.approve_attendance_fact('fa110000-0000-4000-8000-000000000001',current_setting('test.one')::uuid,NULL,NULL);
SELECT set_config('test.candidate_one',(public.attendance_overtime_instance_panel('fa110000-0000-4000-8000-000000000001',
  current_setting('test.one')::uuid)->'items'->0->>'id'),true);

SELECT public.record_manual_attendance_punch_local('fa110000-0000-4000-8000-000000000001',current_setting('test.two')::uuid,
  'in',(current_setting('test.date')||' 22:00')::timestamp,'fa610000-0000-4000-8000-000000000003','Queue test entry');
SELECT public.record_manual_attendance_punch_local('fa110000-0000-4000-8000-000000000001',current_setting('test.two')::uuid,
  'out',((current_setting('test.date')::date+1)::text||' 06:45')::timestamp,'fa610000-0000-4000-8000-000000000004','Queue test exit');
SELECT public.approve_attendance_fact('fa110000-0000-4000-8000-000000000001',current_setting('test.two')::uuid,NULL,NULL);
SELECT set_config('test.candidate_two',(public.attendance_overtime_instance_panel('fa110000-0000-4000-8000-000000000001',
  current_setting('test.two')::uuid)->'items'->0->>'id'),true);
SELECT public.review_attendance_overtime('fa110000-0000-4000-8000-000000000001',
  current_setting('test.candidate_two')::uuid,'rejected','Queue test rejection');

SELECT public.record_manual_attendance_punch_local('fa110000-0000-4000-8000-000000000001',current_setting('test.three')::uuid,
  'in',(current_setting('test.date')||' 22:00')::timestamp,'fa610000-0000-4000-8000-000000000005','Queue test entry');
SELECT public.record_manual_attendance_punch_local('fa110000-0000-4000-8000-000000000001',current_setting('test.three')::uuid,
  'out',((current_setting('test.date')::date+1)::text||' 06:00')::timestamp,'fa610000-0000-4000-8000-000000000006','Queue test exit');

SELECT set_config('test.first',public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'all',NULL,1)::text,true);
SELECT is(current_setting('test.first')::jsonb->'items'->0->>'employee_code','RQS-1','first page includes approved pending overtime');
SELECT is((current_setting('test.first')::jsonb->'items'->0->>'overtime_pending_count')::integer,1,'page carries exact pending candidate count');
SELECT is((current_setting('test.first')::jsonb->'counts'->>'overtime_pending')::integer,1,'rejected candidate is excluded from day count');
SELECT is((current_setting('test.first')::jsonb->'counts'->>'clean_ready')::integer,1,'clean ready count remains exact');
SELECT is((current_setting('test.first')::jsonb->'counts'->>'needs_review')::integer,1,'no-punch review count remains exact');
SELECT is((current_setting('test.first')::jsonb->'counts'->>'exception_count')::integer,1,'exception count remains exact');
SELECT is((current_setting('test.first')::jsonb->>'next_cursor'),'RQS-1','cursor uses the visible employee code');
SELECT is((current_setting('test.first')::jsonb->>'has_more')::boolean,true,'first page reports another page');
SELECT set_config('test.second',public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'all',current_setting('test.first')::jsonb->>'next_cursor',1)::text,true);
SELECT is(current_setting('test.second')::jsonb->'items'->0->>'employee_code','RQS-3','cursor skips rejected approved row');
SELECT is((current_setting('test.second')::jsonb->'counts'->>'overtime_pending')::integer,1,'counts do not change with cursor');
SELECT is((current_setting('test.second')::jsonb->'items'->0->>'can_bulk_approve')::boolean,true,'clean ready page row remains bulk approvable');
SELECT set_config('test.third',public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'all',current_setting('test.second')::jsonb->>'next_cursor',1)::text,true);
SELECT is(current_setting('test.third')::jsonb->'items'->0->>'employee_code','RQS-4','third page retains exception');
SELECT is((current_setting('test.third')::jsonb->>'has_more')::boolean,false,'last page reports no successor');
SELECT ok((current_setting('test.third')::jsonb->>'next_cursor') IS NULL,'last page has a null cursor');
SELECT is(jsonb_array_length(public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'overtime',NULL,50)->'items'),1,'overtime filter excludes rejected candidate');
SELECT is(public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'ready',NULL,50)->'items'->0->>'employee_code','RQS-3','ready filter selects clean row');
SELECT is(public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'exceptions',NULL,50)->'items'->0->>'employee_code','RQS-4','exception filter selects no-punch row');

RESET ROLE;
INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id)
VALUES ('fa110000-0000-4000-8000-000000000001',current_setting('test.candidate_one')::uuid,
  'approved','Historical approval awaiting classification','fa010000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
SELECT is((public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'overtime',NULL,50)->'counts'->>'overtime_pending')::integer,1,
  'historical approved candidate without classification remains pending');
SELECT public.classify_attendance_overtime('fa110000-0000-4000-8000-000000000001',current_setting('test.candidate_one')::uuid,
  (public.attendance_overtime_instance_panel('fa110000-0000-4000-8000-000000000001',
    current_setting('test.one')::uuid)->'items'->0->>'candidate_minutes')::integer,0,0,0,'Queue scale classification');
SELECT is((public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'all',NULL,1)->'counts'->>'overtime_pending')::integer,0,
  'classified candidate leaves the day count');
SELECT is(jsonb_array_length(public.attendance_review_queue('fa110000-0000-4000-8000-000000000001',
  current_setting('test.date')::date,'overtime',NULL,50)->'items'),0,'classified candidate leaves overtime filter');
SELECT throws_ok($$SELECT public.attendance_review_queue('fa110000-0000-4000-8000-000000000099',
  current_setting('test.date')::date,'all',NULL,50)$$,'42501','attendance_review_queue_forbidden',
  'cross-tenant queue access remains denied');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
