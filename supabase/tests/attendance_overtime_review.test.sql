BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e9010000-0000-4000-8000-000000000001','overtime-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9010000-0000-4000-8000-000000000002','overtime-reviewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9010000-0000-4000-8000-000000000003','overtime-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('e9110000-0000-4000-8000-000000000001','Overtime test tenant','e9010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('e9110000-0000-4000-8000-000000000001','e9210000-0000-4000-8000-000000000001','overtime.test.operator',1,ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance.correct','attendance.approve','attendance_policy.manage'],'false'),
 ('e9110000-0000-4000-8000-000000000001','e9210000-0000-4000-8000-000000000002','overtime.test.reviewer',1,ARRAY['attendance.view','attendance.approve'],'false'),
 ('e9110000-0000-4000-8000-000000000001','e9210000-0000-4000-8000-000000000003','overtime.test.reader',1,ARRAY['attendance.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('e9110000-0000-4000-8000-000000000001','e9010000-0000-4000-8000-000000000001','active','e9010000-0000-4000-8000-000000000001'),
 ('e9110000-0000-4000-8000-000000000001','e9010000-0000-4000-8000-000000000002','active','e9010000-0000-4000-8000-000000000001'),
 ('e9110000-0000-4000-8000-000000000001','e9010000-0000-4000-8000-000000000003','active','e9010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('e9110000-0000-4000-8000-000000000001','e9010000-0000-4000-8000-000000000001','e9210000-0000-4000-8000-000000000001'),
 ('e9110000-0000-4000-8000-000000000001','e9010000-0000-4000-8000-000000000002','e9210000-0000-4000-8000-000000000002'),
 ('e9110000-0000-4000-8000-000000000001','e9010000-0000-4000-8000-000000000003','e9210000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('e9110000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','e9010000-0000-4000-8000-000000000001','overtime test'),
 ('e9110000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','e9010000-0000-4000-8000-000000000001','overtime test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES ('e9110000-0000-4000-8000-000000000001','e9310000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES ('e9110000-0000-4000-8000-000000000001','e9410000-0000-4000-8000-000000000001','e9310000-0000-4000-8000-000000000001','Main',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES ('e9110000-0000-4000-8000-000000000001','e9510000-0000-4000-8000-000000000001','OT',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes)
VALUES ('e9110000-0000-4000-8000-000000000001','e9510000-0000-4000-8000-000000000001',1,'وردية ليلية مع إضافي','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'22:00','06:00',true,30,'e9010000-0000-4000-8000-000000000001',true,30,15);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES ('e9110000-0000-4000-8000-000000000001','e9510000-0000-4000-8000-000000000002','OT-OFF',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes)
VALUES ('e9110000-0000-4000-8000-000000000001','e9510000-0000-4000-8000-000000000002',1,'وردية بلا إضافي','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'22:00','06:00',true,30,'e9010000-0000-4000-8000-000000000001',false,30,15);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employee_one',public.create_people_employee('e9110000-0000-4000-8000-000000000001','OT-1','موظف إضافي أول','e9310000-0000-4000-8000-000000000001','e9410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employment_one',(current_setting('test.employee_one')::jsonb->>'employment_id'),true);
SELECT set_config('test.employee_two',public.create_people_employee('e9110000-0000-4000-8000-000000000001','OT-2','موظف إضافي ثان','e9310000-0000-4000-8000-000000000001','e9410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employment_two',(current_setting('test.employee_two')::jsonb->>'employment_id'),true);
SELECT set_config('test.employee_three',public.create_people_employee('e9110000-0000-4000-8000-000000000001','OT-3','موظف دون تأهل','e9310000-0000-4000-8000-000000000001','e9410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employment_three',(current_setting('test.employee_three')::jsonb->>'employment_id'),true);
SELECT set_config('test.employee_four',public.create_people_employee('e9110000-0000-4000-8000-000000000001','OT-4','موظف دون بلوغ الحد','e9310000-0000-4000-8000-000000000001','e9410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employment_four',(current_setting('test.employee_four')::jsonb->>'employment_id'),true);
SELECT set_config('test.operational_date',(timezone('Africa/Cairo',now())::date-7)::text,true);
RESET ROLE;

UPDATE people.work_assignments SET work_policy_template_id='e9510000-0000-4000-8000-000000000001',work_policy_version=1
WHERE tenant_id='e9110000-0000-4000-8000-000000000001' AND employment_id IN(current_setting('test.employment_one')::uuid,current_setting('test.employment_two')::uuid);
UPDATE people.work_assignments SET work_policy_template_id='e9510000-0000-4000-8000-000000000002',work_policy_version=1
WHERE tenant_id='e9110000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_three')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='e9510000-0000-4000-8000-000000000001',work_policy_version=1
WHERE tenant_id='e9110000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_four')::uuid;
SELECT is((public.time_work_policy_catalog('e9110000-0000-4000-8000-000000000001')->'items'->0->>'overtime_minimum_minutes')::int,30,'catalog exposes the versioned overtime threshold');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.saved_policy',public.save_time_work_policy('e9110000-0000-4000-8000-000000000001',NULL,'OT-SAVE','قالب إعداد الإضافي','flexible','Africa/Cairo',ARRAY[1,2,3,4,5]::smallint[],NULL,NULL,false,0,60,'07:00','21:00',120,360,true,45,15)::text,true);
SELECT is((SELECT item->>'overtime_enabled' FROM jsonb_array_elements(public.time_work_policy_catalog('e9110000-0000-4000-8000-000000000001')->'items') item WHERE item->>'code'='OT-SAVE'),'true','policy save RPC persists explicit overtime eligibility');
SELECT is((SELECT (item->>'overtime_minimum_minutes')::int FROM jsonb_array_elements(public.time_work_policy_catalog('e9110000-0000-4000-8000-000000000001')->'items') item WHERE item->>'code'='OT-SAVE'),45,'policy save RPC persists its threshold');
SELECT is((SELECT (item->>'overtime_rounding_minutes')::int FROM jsonb_array_elements(public.time_work_policy_catalog('e9110000-0000-4000-8000-000000000001')->'items') item WHERE item->>'code'='OT-SAVE'),15,'policy save RPC persists its rounding increment');
SELECT set_config('test.open',public.attendance_open_day('e9110000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,NULL,50)::text,true);
SELECT set_config('test.instance_one',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='OT-1'),true);
SELECT set_config('test.instance_two',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='OT-2'),true);
SELECT set_config('test.instance_three',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='OT-3'),true);
SELECT set_config('test.instance_four',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='OT-4'),true);
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'instance'->>'overtime_enabled')::boolean,true,'Work Instance freezes overtime eligibility from its policy version');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'instance'->>'overtime_rounding_minutes')::int,15,'Work Instance freezes overtime rounding');

SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,'in',(current_setting('test.operational_date')||' 22:00')::timestamp,'e9610000-0000-4000-8000-000000000001','دخول وردية')$$,'overnight shift accepts its start event');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,'out',((current_setting('test.operational_date')::date+1)::text||' 06:41')::timestamp,'e9610000-0000-4000-8000-000000000002','خروج بعد نهاية الوردية')$$,'overnight shift accepts exit after scheduled end');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'interpretation'->>'state'),'ready','overnight interpretation is reviewable before approval');
SELECT set_config('test.approved_one',public.approve_attendance_fact('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,NULL,NULL)::text,true);
SELECT set_config('test.candidate_one',(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'id'),true);
SELECT is((public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'raw_minutes')::int,41,'candidate uses actual overnight minutes beyond the frozen scheduled end');
SELECT is((public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'candidate_minutes')::int,30,'41 eligible minutes round down to 30 by the frozen 15-minute increment');
SELECT is(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'category','ordinary','unsupported night/rest/holiday rules do not fabricate a category');
SELECT is(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'decision','pending','eligible overtime requires an explicit reviewer decision');
SELECT throws_ok($$SELECT public.review_attendance_overtime('e9110000-0000-4000-8000-000000000001',(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'id')::uuid,'approved','')$$,'22023','attendance_overtime_review_input_invalid','approval reason is mandatory');
SELECT throws_ok($$SELECT public.review_attendance_overtime('e9110000-0000-4000-8000-000000000099',(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'id')::uuid,'approved','محاولة عابرة')$$,'42501','attendance_overtime_review_forbidden','cross-tenant overtime review is denied');

SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,'in',(current_setting('test.operational_date')||' 22:00')::timestamp,'e9610000-0000-4000-8000-000000000003','دخول وردية ثانية')$$,'second overnight shift accepts its start event');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,'out',((current_setting('test.operational_date')::date+1)::text||' 06:45')::timestamp,'e9610000-0000-4000-8000-000000000004','خروج وردية ثانية')$$,'second overnight shift accepts its exit event');
SELECT public.approve_attendance_fact('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,NULL,NULL);
SELECT set_config('test.candidate_two',(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid)->'items'->0->>'id'),true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9010000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.review_attendance_overtime('e9110000-0000-4000-8000-000000000001',current_setting('test.candidate_one')::uuid,'approved','ليس مراجعًا')$$,'42501','attendance_overtime_review_forbidden','attendance reader cannot review overtime');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9010000-0000-4000-8000-000000000002',true);
SELECT lives_ok($$SELECT public.review_attendance_overtime('e9110000-0000-4000-8000-000000000001',current_setting('test.candidate_one')::uuid,'approved','تمت مراجعة الكمية وموافقتها')$$,'authorized reviewer can approve a candidate with a reason');
SELECT throws_ok($$SELECT public.review_attendance_overtime('e9110000-0000-4000-8000-000000000001',current_setting('test.candidate_one')::uuid,'rejected','تكرار القرار')$$,'23514','attendance_overtime_already_reviewed','a reviewed candidate cannot be decided twice');
SELECT lives_ok($$SELECT public.review_attendance_overtime('e9110000-0000-4000-8000-000000000001',current_setting('test.candidate_two')::uuid,'rejected','لا أوافق على سبب الزيادة المسجل')$$,'reviewer can reject with a reason');
RESET ROLE;
SELECT is((SELECT decision FROM time.attendance_overtime_review_events WHERE tenant_id='e9110000-0000-4000-8000-000000000001' AND candidate_id=current_setting('test.candidate_two')::uuid),'rejected','rejection is stored as an immutable decision');
RESET ROLE;

SELECT set_config('test.pending_summary',public.attendance_overtime_day_summary('e9110000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,ARRAY[current_setting('test.instance_one')::uuid,current_setting('test.instance_two')::uuid])::text,true);
SELECT is(coalesce((current_setting('test.pending_summary')::jsonb->'pending_by_instance'->>current_setting('test.instance_one'))::int,0),0,'approved overtime is removed from the day review count');
SELECT is(coalesce((current_setting('test.pending_summary')::jsonb->'pending_by_instance'->>current_setting('test.instance_two'))::int,0),0,'rejected overtime is removed from the day review count');
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9110000-0000-4000-8000-000000000001' AND actor_user_id='e9010000-0000-4000-8000-000000000002' AND event_key LIKE 'overtime.candidate.%'),2,'review decisions record reviewer identity in the audit stream');
SELECT is((SELECT details->>'reason' FROM time.attendance_audit_events WHERE tenant_id='e9110000-0000-4000-8000-000000000001' AND actor_user_id='e9010000-0000-4000-8000-000000000002' AND event_key='overtime.candidate.approved'),'تمت مراجعة الكمية وموافقتها','approval reason is retained in audit');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9010000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_three')::uuid,'in',(current_setting('test.operational_date')||' 22:00')::timestamp,'e9610000-0000-4000-8000-000000000005','دخول مع الإضافي معطل')$$,'disabled overtime policy accepts its start event');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_three')::uuid,'out',((current_setting('test.operational_date')::date+1)::text||' 06:41')::timestamp,'e9610000-0000-4000-8000-000000000006','خروج مع الإضافي معطل')$$,'disabled overtime policy accepts its exit event');
SELECT public.approve_attendance_fact('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_three')::uuid,NULL,NULL);
SELECT is(jsonb_array_length(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_three')::uuid)->'items'),0,'disabled overtime policy creates no candidate with extra minutes');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_four')::uuid,'in',(current_setting('test.operational_date')||' 22:00')::timestamp,'e9610000-0000-4000-8000-000000000007','دخول دون بلوغ الحد')$$,'enabled policy accepts a below-threshold shift');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_four')::uuid,'out',((current_setting('test.operational_date')::date+1)::text||' 06:29')::timestamp,'e9610000-0000-4000-8000-000000000008','خروج قبل حد التأهل')$$,'enabled policy accepts its exit below threshold');
SELECT public.approve_attendance_fact('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_four')::uuid,NULL,NULL);
SELECT is(jsonb_array_length(public.attendance_overtime_instance_panel('e9110000-0000-4000-8000-000000000001',current_setting('test.instance_four')::uuid)->'items'),0,'29 raw minutes below the 30-minute threshold create no candidate');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.attendance_overtime_candidates WHERE tenant_id='e9110000-0000-4000-8000-000000000001'),2,'disabled and below-threshold policies produce no extra candidates');

SELECT * FROM finish();
ROLLBACK;
