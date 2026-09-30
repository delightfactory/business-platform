BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('ec010000-0000-4000-8000-000000000001','payroll-input-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('ec010000-0000-4000-8000-000000000002','payroll-input-reviewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('ec010000-0000-4000-8000-000000000003','payroll-input-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('ec010000-0000-4000-8000-000000000004','payroll-input-outsider@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('ec110000-0000-4000-8000-000000000001','Payroll input test tenant','ec010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('ec110000-0000-4000-8000-000000000001','ec210000-0000-4000-8000-000000000001','payroll.input.operator',1,ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance.correct','attendance.approve'],'false'),
 ('ec110000-0000-4000-8000-000000000001','ec210000-0000-4000-8000-000000000002','payroll.input.reviewer',1,ARRAY['attendance.view','attendance.approve'],'false'),
 ('ec110000-0000-4000-8000-000000000001','ec210000-0000-4000-8000-000000000003','payroll.input.reader',1,ARRAY['attendance.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('ec110000-0000-4000-8000-000000000001','ec010000-0000-4000-8000-000000000001','active','ec010000-0000-4000-8000-000000000001'),
 ('ec110000-0000-4000-8000-000000000001','ec010000-0000-4000-8000-000000000002','active','ec010000-0000-4000-8000-000000000001'),
 ('ec110000-0000-4000-8000-000000000001','ec010000-0000-4000-8000-000000000003','active','ec010000-0000-4000-8000-000000000001'),
 ('ec110000-0000-4000-8000-000000000001','ec010000-0000-4000-8000-000000000004','active','ec010000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('ec110000-0000-4000-8000-000000000001','ec010000-0000-4000-8000-000000000001','ec210000-0000-4000-8000-000000000001'),
 ('ec110000-0000-4000-8000-000000000001','ec010000-0000-4000-8000-000000000002','ec210000-0000-4000-8000-000000000002'),
 ('ec110000-0000-4000-8000-000000000001','ec010000-0000-4000-8000-000000000003','ec210000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('ec110000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','ec010000-0000-4000-8000-000000000001','Payroll input test'),
 ('ec110000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','ec010000-0000-4000-8000-000000000001','Payroll input test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES ('ec110000-0000-4000-8000-000000000001','ec310000-0000-4000-8000-000000000001','Input employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES ('ec110000-0000-4000-8000-000000000001','ec410000-0000-4000-8000-000000000001','ec310000-0000-4000-8000-000000000001','Input site',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES ('ec110000-0000-4000-8000-000000000001','ec510000-0000-4000-8000-000000000001','INPUT-OT',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes)
VALUES ('ec110000-0000-4000-8000-000000000001','ec510000-0000-4000-8000-000000000001',1,'قالب مدخل الأجور','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'08:00','16:00',false,0,'ec010000-0000-4000-8000-000000000001',true,30,15);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ec010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employee_one',public.create_people_employee('ec110000-0000-4000-8000-000000000001','PI-1','موظف مدخل أول','ec310000-0000-4000-8000-000000000001','ec410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employee_two',public.create_people_employee('ec110000-0000-4000-8000-000000000001','PI-2','موظف مدخل ثان','ec310000-0000-4000-8000-000000000001','ec410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
SELECT set_config('test.employee_three',public.create_people_employee('ec110000-0000-4000-8000-000000000001','PI-3','موظف غياب معتمد','ec310000-0000-4000-8000-000000000001','ec410000-0000-4000-8000-000000000001',(timezone('Africa/Cairo',now())::date-14),'monthly',1000,true)::text,true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='ec510000-0000-4000-8000-000000000001',work_policy_version=1 WHERE tenant_id='ec110000-0000-4000-8000-000000000001';
SELECT set_config('test.date',(timezone('Africa/Cairo',now())::date-7)::text,true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ec010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open',public.attendance_open_day('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,NULL,50)::text,true);
SELECT set_config('test.instance_one',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),true);
SELECT set_config('test.instance_two',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='PI-2'),true);
SELECT set_config('test.instance_three',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='PI-3'),true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,'in',(current_setting('test.date')||' 08:00')::timestamp,'ec610000-0000-4000-8000-000000000001','تسجيل أول للاختبار')$$,'first employee receives a complete attendance pair');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,'out',(current_setting('test.date')||' 16:45')::timestamp,'ec610000-0000-4000-8000-000000000002','تسجيل أول للاختبار')$$,'first employee interpretation is ready');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,'in',(current_setting('test.date')||' 08:00')::timestamp,'ec610000-0000-4000-8000-000000000003','تسجيل ثان للاختبار')$$,'second employee receives a complete attendance pair');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,'out',(current_setting('test.date')||' 16:45')::timestamp,'ec610000-0000-4000-8000-000000000004','تسجيل ثان للاختبار')$$,'second employee interpretation is ready');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ec010000-0000-4000-8000-000000000002',true);
SELECT set_config('test.fact_one',public.approve_attendance_fact('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,NULL,NULL)->>'fact_id',true);
SELECT set_config('test.fact_two',public.approve_attendance_fact('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid,NULL,NULL)->>'fact_id',true);
SELECT set_config('test.candidate_one',(public.attendance_overtime_instance_panel('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items'->0->>'id'),true);
SELECT set_config('test.candidate_two',(public.attendance_overtime_instance_panel('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_two')::uuid)->'items'->0->>'id'),true);
SELECT lives_ok($$SELECT public.review_attendance_overtime('ec110000-0000-4000-8000-000000000001',current_setting('test.candidate_two')::uuid,'rejected','الكمية الثانية غير مستحقة')$$,'rejected overtime has a reasoned immutable decision');
SELECT lives_ok($$SELECT public.approve_attendance_absence('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_three')::uuid,'غياب معتمد للاختبار')$$,'absence is approved as a nonfinancial fact');
SELECT set_config('test.initial_projection',public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,100)::text,true);
SELECT is(current_setting('test.initial_projection')::jsonb->>'boundary_status','projection_only','boundary explicitly says Payroll has not consumed these inputs');
SELECT is((current_setting('test.initial_projection')::jsonb->>'consumed')::boolean,false,'read projection does not claim consumption');
SELECT is(jsonb_array_length(current_setting('test.initial_projection')::jsonb->'items'),3,'projection contains only the three current approved facts');
SELECT is((SELECT item->>'outcome' FROM jsonb_array_elements(current_setting('test.initial_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-3'),'absence','approved absence is exposed as an absence unit');
SELECT is((SELECT (item->>'absence_units')::int FROM jsonb_array_elements(current_setting('test.initial_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-3'),1,'absence quantity remains nonfinancial');
SELECT is(jsonb_array_length((SELECT item->'overtime_quantities' FROM jsonb_array_elements(current_setting('test.initial_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1')),0,'pending overtime is excluded before approval');
SELECT is(jsonb_array_length((SELECT item->'overtime_quantities' FROM jsonb_array_elements(current_setting('test.initial_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-2')),0,'rejected overtime is excluded');
SELECT is((public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,1)->>'has_more')::boolean,true,'projection is bounded and returns a keyset page');
SELECT set_config('test.before_version',(SELECT item->>'input_version' FROM jsonb_array_elements(current_setting('test.initial_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),true);
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ec010000-0000-4000-8000-000000000001',true);
SELECT set_config('test.punch_out',(SELECT item->>'id' FROM jsonb_array_elements(public.attendance_instance_detail('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'punches') item WHERE item->>'direction'='out'),true);
SELECT lives_ok($$SELECT public.correct_manual_attendance_punch_local('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,current_setting('test.punch_out')::uuid,'replace','out',(current_setting('test.date')||' 16:50')::timestamp,'تصحيح وقت الانصراف')$$,'attendance correction preserves original fact and marks it stale');
SELECT is((public.attendance_instance_detail('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'instance'->>'status'),'needs_review','changed evidence makes the old approved input non-current');
SELECT is(jsonb_array_length((public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,100)->'items')),2,'stale fact is omitted until its correction is approved');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ec010000-0000-4000-8000-000000000002',true);
SELECT set_config('test.corrected_fact',public.approve_attendance_fact('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid,current_setting('test.fact_one')::uuid,'تصحيح معتمد بعد مراجعة الحضور')->>'fact_id',true);
SELECT set_config('test.current_candidate',(SELECT item->>'id' FROM jsonb_array_elements(public.attendance_overtime_instance_panel('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items') item WHERE item->>'attendance_fact_id'=current_setting('test.corrected_fact')),true);
SELECT is((SELECT item->>'decision' FROM jsonb_array_elements(public.attendance_overtime_instance_panel('ec110000-0000-4000-8000-000000000001',current_setting('test.instance_one')::uuid)->'items') item WHERE item->>'id'=current_setting('test.candidate_one')),'superseded','old pending overtime decision is retained as superseded after fact correction');
SELECT throws_ok($$SELECT public.review_attendance_overtime('ec110000-0000-4000-8000-000000000001',current_setting('test.candidate_one')::uuid,'approved','محاولة قرار قديم')$$,'23514','attendance_overtime_already_reviewed','superseded candidate cannot receive a stale decision');
SELECT lives_ok($$SELECT public.review_attendance_overtime('ec110000-0000-4000-8000-000000000001',current_setting('test.current_candidate')::uuid,'approved','إضافي معتمد للنسخة الحالية')$$,'current overtime quantity receives a reasoned approval');
SELECT set_config('test.final_projection',public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,100)::text,true);
SELECT is((SELECT (item->>'attendance_fact_version')::int FROM jsonb_array_elements(current_setting('test.final_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),2,'current projection selects corrected attendance fact version');
SELECT is((SELECT item->>'corrects_fact_id' FROM jsonb_array_elements(current_setting('test.final_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),current_setting('test.fact_one'),'correction chain links to prior immutable fact');
SELECT is((SELECT jsonb_array_length(item->'overtime_quantities') FROM jsonb_array_elements(current_setting('test.final_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),1,'projection contains only approved overtime quantity for current fact');
SELECT is((SELECT (item->'overtime_quantities'->0->>'minutes')::int FROM jsonb_array_elements(current_setting('test.final_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),45,'approved overtime publishes quantity without a money amount');
SELECT ok(NOT ((SELECT item FROM jsonb_array_elements(current_setting('test.final_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1') ? 'amount'),'projection row has no monetary field');
SELECT is((SELECT item->>'input_version' FROM jsonb_array_elements(current_setting('test.final_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),(SELECT item->>'input_version' FROM jsonb_array_elements(public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,100)->'items') item WHERE item->>'employee_code'='PI-1'),'repeated projection read preserves input version for unchanged sources');
SELECT isnt((SELECT item->>'input_version' FROM jsonb_array_elements(current_setting('test.final_projection')::jsonb->'items') item WHERE item->>'employee_code'='PI-1'),current_setting('test.before_version'),'correction produces a new input version');
SELECT throws_ok($$SELECT public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000099',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,100)$$,'42501','attendance_payroll_projection_forbidden','cross-tenant projection is denied');
SELECT throws_ok($$SELECT public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,101)$$,'22023','attendance_payroll_projection_input_invalid','oversized projection page is rejected');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ec010000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,100)$$,'42501','attendance_payroll_projection_forbidden','active Tenant member without Attendance permission is denied');
RESET ROLE;

UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()
WHERE tenant_id='ec110000-0000-4000-8000-000000000001' AND capability_key='hr.attendance' AND valid_until IS NULL;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ec010000-0000-4000-8000-000000000003',true);
SELECT is(jsonb_array_length(public.attendance_payroll_input_projection('ec110000-0000-4000-8000-000000000001',current_setting('test.date')::date,current_setting('test.date')::date,NULL,NULL,NULL,100)->'items'),3,'authorized Attendance reader retains historical projection after entitlement revocation');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
