BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('eb010000-0000-4000-8000-000000000001','review-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('eb010000-0000-4000-8000-000000000002','review-approver@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('eb010000-0000-4000-8000-000000000003','review-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('eb110000-0000-4000-8000-000000000001','Attendance review test tenant','eb010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('eb110000-0000-4000-8000-000000000001','eb210000-0000-4000-8000-000000000001','review.test.operator',1,ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance.correct','attendance.approve'],'false'),
 ('eb110000-0000-4000-8000-000000000001','eb210000-0000-4000-8000-000000000002','review.test.approver',1,ARRAY['attendance.view','attendance.approve'],'false'),
 ('eb110000-0000-4000-8000-000000000001','eb210000-0000-4000-8000-000000000003','review.test.reader',1,ARRAY['attendance.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('eb110000-0000-4000-8000-000000000001','eb010000-0000-4000-8000-000000000001','active','eb010000-0000-4000-8000-000000000001'),
 ('eb110000-0000-4000-8000-000000000001','eb010000-0000-4000-8000-000000000002','active','eb010000-0000-4000-8000-000000000001'),
 ('eb110000-0000-4000-8000-000000000001','eb010000-0000-4000-8000-000000000003','active','eb010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('eb110000-0000-4000-8000-000000000001','eb010000-0000-4000-8000-000000000001','eb210000-0000-4000-8000-000000000001'),
 ('eb110000-0000-4000-8000-000000000001','eb010000-0000-4000-8000-000000000002','eb210000-0000-4000-8000-000000000002'),
 ('eb110000-0000-4000-8000-000000000001','eb010000-0000-4000-8000-000000000003','eb210000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('eb110000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','eb010000-0000-4000-8000-000000000001','review queue test'),
 ('eb110000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','eb010000-0000-4000-8000-000000000001','review queue test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES ('eb110000-0000-4000-8000-000000000001','eb310000-0000-4000-8000-000000000001','Review employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES ('eb110000-0000-4000-8000-000000000001','eb410000-0000-4000-8000-000000000001','eb310000-0000-4000-8000-000000000001','Review site',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES ('eb110000-0000-4000-8000-000000000001','eb510000-0000-4000-8000-000000000001','REVIEW',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,created_by)
VALUES ('eb110000-0000-4000-8000-000000000001','eb510000-0000-4000-8000-000000000001',1,'قالب المراجعة','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'08:00','16:00',false,0,'eb010000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','eb010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employee_one',public.create_people_employee('eb110000-0000-4000-8000-000000000001','RQ-1','موظف مراجعة أول','eb310000-0000-4000-8000-000000000001','eb410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employee_two',public.create_people_employee('eb110000-0000-4000-8000-000000000001','RQ-2','موظف مراجعة ثان','eb310000-0000-4000-8000-000000000001','eb410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employee_three',public.create_people_employee('eb110000-0000-4000-8000-000000000001','RQ-3','موظف يحتاج مراجعة','eb310000-0000-4000-8000-000000000001','eb410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='eb510000-0000-4000-8000-000000000001',work_policy_version=1 WHERE tenant_id='eb110000-0000-4000-8000-000000000001';
SELECT set_config('test.date',(timezone('Africa/Cairo',now())::date-7)::text,true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','eb010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open',public.attendance_open_day('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,NULL,50)::text,true);
SELECT set_config('test.instance_one',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='RQ-1'),true);
SELECT set_config('test.instance_two',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='RQ-2'),true);
SELECT set_config('test.instance_three',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='RQ-3'),true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('eb110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,'in',(current_setting('test.date')||' 08:00')::timestamp,'eb610000-0000-4000-8000-000000000001','تسجيل مكتمل للاختبار')$$,'first clean workday receives attendance and departure events');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('eb110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,'out',(current_setting('test.date')||' 16:00')::timestamp,'eb610000-0000-4000-8000-000000000002','تسجيل مكتمل للاختبار')$$,'first clean workday becomes ready');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('eb110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,'in',(current_setting('test.date')||' 08:00')::timestamp,'eb610000-0000-4000-8000-000000000003','تسجيل مكتمل للاختبار')$$,'second clean workday receives attendance and departure events');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('eb110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,'out',(current_setting('test.date')||' 16:00')::timestamp,'eb610000-0000-4000-8000-000000000004','تسجيل مكتمل للاختبار')$$,'second clean workday becomes ready');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','eb010000-0000-4000-8000-000000000002',true);
SELECT set_config('test.queue',public.attendance_review_queue('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,'all',NULL,50)::text,true);
SELECT is((current_setting('test.queue')::jsonb->'counts'->>'clean_ready')::int,2,'queue count includes only clean ready instances');
SELECT is((current_setting('test.queue')::jsonb->'counts'->>'needs_review')::int,1,'queue counts the elapsed no-punch exception');
SELECT is((current_setting('test.queue')::jsonb->'counts'->>'exception_count')::int,1,'exception filter count matches the exception queue');
SELECT is(jsonb_array_length(public.attendance_review_queue('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,'ready',NULL,50)->'items'),2,'ready filter returns only clean ready rows');
SELECT is((public.attendance_review_queue('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,'exceptions',NULL,50)->'items'->0->>'can_bulk_approve')::boolean,false,'exception row is never marked bulk-approvable');
SELECT is((public.attendance_review_queue('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,'all',NULL,1)->>'has_more')::boolean,true,'queue pages are bounded and expose a next page');
SELECT set_config('test.bulk',public.approve_attendance_facts_bulk('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,ARRAY[current_setting('test.instance_one')::uuid,current_setting('test.instance_three')::uuid,current_setting('test.instance_two')::uuid])::text,true);
SELECT is((current_setting('test.bulk')::jsonb->>'approved_count')::int,2,'safe rows are approved within the mixed batch');
SELECT is((current_setting('test.bulk')::jsonb->>'skipped_count')::int,1,'exception row is explicitly skipped in a mixed batch');
SELECT is(jsonb_array_length(public.attendance_instance_detail('eb110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'facts'),1,'bulk approval creates an immutable fact for each clean row');
SELECT is((public.attendance_instance_detail('eb110000-0000-4000-8000-000000000001',current_setting('test.instance_three')::uuid)->'instance'->>'status'),'needs_review','mixed batch leaves exception available for individual review');
SELECT set_config('test.stale',public.approve_attendance_facts_bulk('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,ARRAY[current_setting('test.instance_one')::uuid])::text,true);
SELECT is((current_setting('test.stale')::jsonb->>'skipped_count')::int,1,'already approved stale row is not approved a second time');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='eb110000-0000-4000-8000-000000000001' AND event_key='attendance.bulk_approval.item_skipped'),2,'skipped items retain individual audit provenance');
SELECT is((SELECT details->>'skipped_count' FROM time.attendance_audit_events WHERE tenant_id='eb110000-0000-4000-8000-000000000001' AND event_key='attendance.bulk_approval.completed' ORDER BY id DESC LIMIT 1),'1','batch audit records final outcome counts');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.approve_attendance_facts_bulk('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,ARRAY[current_setting('test.instance_one')::uuid,current_setting('test.instance_one')::uuid])$$,'22023','attendance_bulk_approval_input_invalid','duplicate selected ids are rejected');
SELECT throws_ok($$SELECT public.attendance_review_queue('eb110000-0000-4000-8000-000000000099',current_setting('test.date')::date,'all',NULL,50)$$,'42501','attendance_review_queue_forbidden','cross-tenant queue access is denied');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','eb010000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.approve_attendance_facts_bulk('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,ARRAY[current_setting('test.instance_three')::uuid])$$,'42501','attendance_bulk_approval_forbidden','read-only member cannot bulk approve');
SELECT lives_ok($$SELECT public.attendance_review_queue('eb110000-0000-4000-8000-000000000001',current_setting('test.date')::date,'exceptions',NULL,50)$$,'read-only member can inspect the owned exception queue');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
