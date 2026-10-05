BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e9000000-0000-4000-8000-000000000001','attend-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9000000-0000-4000-8000-000000000002','attend-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9000000-0000-4000-8000-000000000003','attend-reviewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9000000-0000-4000-8000-000000000004','attendance-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access) VALUES ('e9000000-0000-4000-8000-000000000004',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('e9100000-0000-4000-8000-000000000001','Attendance test tenant','e9000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('e9100000-0000-4000-8000-000000000099','Attendance cross-tenant test tenant','e9000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
('e9100000-0000-4000-8000-000000000001','e9200000-0000-4000-8000-000000000001','attendance.test.operator',1,ARRAY['tenant.members.manage','people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance.correct','attendance.approve','attendance_policy.manage'],'false'),
('e9100000-0000-4000-8000-000000000001','e9200000-0000-4000-8000-000000000002','attendance.test.reader',1,ARRAY['attendance.view'],'false'),
('e9100000-0000-4000-8000-000000000001','e9200000-0000-4000-8000-000000000003','attendance.test.reviewer',1,ARRAY['attendance.view','attendance.correct','attendance.approve'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000001','active','e9000000-0000-4000-8000-000000000001'),
('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000002','active','e9000000-0000-4000-8000-000000000001'),
('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000003','active','e9000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000001','e9200000-0000-4000-8000-000000000001'),
('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000002','e9200000-0000-4000-8000-000000000002'),
('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000003','e9200000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
('e9100000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','e9000000-0000-4000-8000-000000000001','attendance test'),
('e9100000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','e9000000-0000-4000-8000-000000000001','attendance test');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('e9100000-0000-4000-8000-000000000099','hr.attendance',true,now()-interval '1 minute','e9000000-0000-4000-8000-000000000001','cross-tenant attendance test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('e9100000-0000-4000-8000-000000000001','e9300000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES('e9100000-0000-4000-8000-000000000001','e9400000-0000-4000-8000-000000000001','e9300000-0000-4000-8000-000000000001','Main',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES('e9100000-0000-4000-8000-000000000001','e9500000-0000-4000-8000-000000000001','NIGHT',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,created_by)
SELECT 'e9100000-0000-4000-8000-000000000001','e9500000-0000-4000-8000-000000000001',1,'وردية ليلية','fixed','Africa/Cairo',ARRAY[extract(dow FROM timezone('Africa/Cairo',now())::date)::smallint+1]::smallint[],'22:00','06:00',true,30,'e9000000-0000-4000-8000-000000000001';
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES('e9100000-0000-4000-8000-000000000001','e9500000-0000-4000-8000-000000000002','FLEX',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by)
VALUES('e9100000-0000-4000-8000-000000000001','e9500000-0000-4000-8000-000000000002',1,'دوام مرن','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59','e9000000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employee',public.create_people_employee('e9100000-0000-4000-8000-000000000001','ATT-1','موظف اختبار','e9300000-0000-4000-8000-000000000001','e9400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-7,'monthly',1000,true)::text,true);
SELECT set_config('test.employment',(current_setting('test.employee')::jsonb->>'employment_id'),true);
SELECT set_config('test.absence_employee',public.create_people_employee('e9100000-0000-4000-8000-000000000001','ATT-2','موظف غياب','e9300000-0000-4000-8000-000000000001','e9400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-14,'monthly',1000,true)::text,true);
SELECT set_config('test.absence_employment',(current_setting('test.absence_employee')::jsonb->>'employment_id'),true);
SELECT set_config('test.flex_employee',public.create_people_employee('e9100000-0000-4000-8000-000000000001','ATT-3','موظف مرن','e9300000-0000-4000-8000-000000000001','e9400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-1,'monthly',1000,true)::text,true);
SELECT set_config('test.flex_employment',(current_setting('test.flex_employee')::jsonb->>'employment_id'),true);
SELECT set_config('test.short_flex_employee',public.create_people_employee('e9100000-0000-4000-8000-000000000001','ATT-4','موظف مدة قصيرة','e9300000-0000-4000-8000-000000000001','e9400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-1,'monthly',1000,true)::text,true);
SELECT set_config('test.short_flex_employment',(current_setting('test.short_flex_employee')::jsonb->>'employment_id'),true);
SELECT set_config('test.operational_date',(timezone('Africa/Cairo',now())::date-7)::text,true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='e9500000-0000-4000-8000-000000000001',work_policy_version=1
WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='e9500000-0000-4000-8000-000000000001',work_policy_version=1
WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.absence_employment')::uuid;
UPDATE people.work_assignments SET valid_until=current_setting('test.operational_date')::date
WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.absence_employment')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='e9500000-0000-4000-8000-000000000002',work_policy_version=1
WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND employment_id IN(current_setting('test.flex_employment')::uuid,current_setting('test.short_flex_employment')::uuid);
SELECT is((SELECT count(*)::int FROM people.work_assignments WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment')::uuid AND work_policy_template_id='e9500000-0000-4000-8000-000000000001'),1,'test assignment references the policy version');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open_result',public.attendance_open_day('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,NULL,50)::text,true);
SELECT ok(jsonb_array_length(current_setting('test.open_result')::jsonb->'items')=1,'authorized day open materializes a bounded Work Instance');
SELECT set_config('test.instance',(current_setting('test.open_result')::jsonb->'items'->0->>'id'),true);
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'timezone_name'),'Africa/Cairo','instance freezes policy IANA timezone');
SELECT ok(((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'expected_end')::timestamptz > (public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'expected_start')::timestamptz),'overnight end is after start as a UTC instant');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'break_minutes')::int,30,'Work Instance freezes scheduled break duration');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'exception_code'),'absence_candidate','expired day with no events is surfaced as an absence candidate for review');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'owner_permission'),'attendance.approve','absence candidate has a clear approval owner');
SELECT throws_ok($$SELECT public.attendance_open_day('e9100000-0000-4000-8000-000000000099',current_setting('test.operational_date')::date,NULL,50)$$,'42501','attendance_manage_forbidden','cross-tenant day creation is denied');
SELECT is(jsonb_array_length(public.attendance_open_day('e9100000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date+1,NULL,50)->'items'),0,'future Cairo date is not materialized for Cairo policy');
SELECT set_config('test.flex_date',(timezone('Africa/Cairo',now())::date-1)::text,true);
SELECT set_config('test.flex_result',public.attendance_open_day('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_date')::date,NULL,50)::text,true);
SELECT is(jsonb_array_length(current_setting('test.flex_result')::jsonb->'items'),2,'past operational date opens both flexible-workday employees');
SELECT set_config('test.flex_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.flex_result')::jsonb->'items') item WHERE item->>'employee_code'='ATT-3'),true);
SELECT set_config('test.short_flex_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.flex_result')::jsonb->'items') item WHERE item->>'employee_code'='ATT-4'),true);
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'instance'->>'schedule_kind'),'flexible','Work Instance freezes the flexible schedule kind');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'instance'->>'required_minutes')::int,60,'Work Instance freezes required flexible duration');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid,'in',(current_setting('test.flex_date')||' 10:00')::timestamp,'e9600000-0000-4000-8000-000000000010','تسجيل دخول مرن')$$,'flexible workday accepts an in event inside its daily window');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid,'out',(current_setting('test.flex_date')||' 12:30')::timestamp,'e9600000-0000-4000-8000-000000000011','تسجيل خروج مرن')$$,'flexible workday accepts an out event without a fixed start/end');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'interpretation'->>'state'),'ready','flexible duration meeting the required minutes is ready');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'interpretation'->>'worked_minutes')::int,150,'flexible day reports actual elapsed minutes');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'interpretation'->>'late_minutes')::int,NULL,'flexible schedule does not invent a lateness metric');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.short_flex_instance')::uuid,'in',(current_setting('test.flex_date')||' 10:00')::timestamp,'e9600000-0000-4000-8000-000000000012','تسجيل دخول مرن قصير')$$,'short flexible day accepts its first source event');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.short_flex_instance')::uuid,'out',(current_setting('test.flex_date')||' 10:30')::timestamp,'e9600000-0000-4000-8000-000000000013','تسجيل خروج مرن قصير')$$,'short flexible day accepts its second source event');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.short_flex_instance')::uuid)->'interpretation'->>'exception_code'),'short_workday','duration below requirement is clearly reviewable');
SELECT throws_ok($$SELECT public.approve_attendance_fact('e9100000-0000-4000-8000-000000000001',current_setting('test.short_flex_instance')::uuid,NULL,NULL)$$,'22023','attendance_short_workday_reason_required','approving a short flexible workday requires a reason');
SELECT lives_ok($$SELECT public.approve_attendance_fact('e9100000-0000-4000-8000-000000000001',current_setting('test.short_flex_instance')::uuid,NULL,'تم اعتماد المدة المختصرة بعد المراجعة')$$,'authorized reviewer can explicitly approve a short flexible day with a reason');
SELECT throws_ok($$SELECT public.approve_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid,'غياب رغم وجود تسجيلات فعالة')$$,'23514','attendance_absence_not_eligible','active attendance evidence cannot be approved as absence');
SELECT lives_ok($$DO $d$ DECLARE punch jsonb; BEGIN FOR punch IN SELECT value FROM jsonb_array_elements(public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'punches') LOOP PERFORM public.correct_manual_attendance_punch('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid,(punch->>'id')::uuid,'exclude',NULL,NULL,'استبعاد تسجيل غير صحيح بعد المراجعة'); END LOOP; END $d$; $$,'scenario 1 appends exclusions for every raw punch without deleting evidence');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'interpretation'->>'exception_code'),'absence_candidate','scenario 1: all-excluded raw punches are interpreted as an absence candidate');
SELECT set_config('test.initial_absence',public.approve_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid,'غياب بعد استبعاد التسجيلات غير الصحيحة')::text,true);
SELECT is(current_setting('test.initial_absence')::jsonb->>'state','approved_absence','scenario 1: initial absence approval accepts fully excluded raw punches');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_instance')::uuid)->'facts'->0->'fact'->>'outcome'),'absence','scenario 1: the approved fact records absence');
SELECT throws_ok($$SELECT public.attendance_instance_detail('e9100000-0000-4000-8000-000000000099',current_setting('test.instance')::uuid)$$,'42501','attendance_view_forbidden','instance details are tenant-scoped');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',timezone('Africa/Cairo',now())::timestamp,gen_random_uuid(),NULL)$$,'42501','attendance_manage_forbidden','reader cannot enter manual punches');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000003',true);
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.in_time',(current_setting('test.operational_date')||' 22:03')::text,true);
SELECT set_config('test.out_time',((current_setting('test.operational_date')::date+1)::text||' 05:50')::text,true);
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'out',(timezone('Africa/Cairo',now())::timestamp+interval '10 minutes'),gen_random_uuid(),'تسجيل مستقبلي')$$,'22023','attendance_punch_in_future','future manual events are rejected at the authoritative table boundary');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'out',current_setting('test.out_time')::timestamp,gen_random_uuid(),NULL)$$,'22023','attendance_punch_input_invalid','reviewer must explain an added missing event');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'out',current_setting('test.out_time')::timestamp,'e9600000-0000-4000-8000-000000000003','إضافة خروج مفقود بعد مراجعة السجل')$$,'reviewer can append a missing event with a reason');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',current_setting('test.in_time')::timestamp,gen_random_uuid())$$,'42501','permission denied for function record_manual_attendance_punch_local','unreasoned five-argument local RPC is revoked even from managers');
SELECT throws_ok($$SELECT public.record_manual_attendance_punch('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',now(),gen_random_uuid())$$,'42501','permission denied for function record_manual_attendance_punch','underlying unreasoned RPC is not directly callable');
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',current_setting('test.in_time')::timestamp,gen_random_uuid(),NULL)$$,'22023','attendance_punch_input_invalid','manager also needs a reason when appending to a review record');
SELECT set_config('test.request_key','e9600000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',current_setting('test.in_time')::timestamp,current_setting('test.request_key')::uuid,'استكمال تسجيل الدخول بعد المراجعة')$$,'records manual overnight entry');
SELECT is(public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',current_setting('test.in_time')::timestamp,current_setting('test.request_key')::uuid,'استكمال تسجيل الدخول بعد المراجعة')->>'state','unchanged','same request and payload are idempotent');
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'out',current_setting('test.in_time')::timestamp,current_setting('test.request_key')::uuid,'سبب بديل')$$,'23505','attendance_idempotency_conflict','same request key with another payload is rejected');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'state'),'ready','ordinary overnight pair is interpreted deterministically');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'gross_worked_minutes')::int,467,'overnight span counts the actual elapsed minutes across midnight');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'worked_minutes')::int,437,'scheduled break is deducted from elapsed span for net duration');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'late_minutes')::int,0,'arrival three minutes late is within the frozen five-minute grace');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'early_leave_minutes')::int,5,'early departure is measured beyond the frozen five-minute grace');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000003',true);
SELECT is(public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'out',current_setting('test.out_time')::timestamp,'e9600000-0000-4000-8000-000000000003','إضافة خروج مفقود بعد مراجعة السجل')->>'state','unchanged','reviewer can retry the same payload after it resolves the day');
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'out',current_setting('test.out_time')::timestamp,'e9600000-0000-4000-8000-000000000003','سبب مختلف')$$,'23505','attendance_idempotency_conflict','reviewer cannot change a reason under an existing request key');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.first_fact',(public.approve_attendance_fact('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,NULL,NULL)->>'fact_id'),true);
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'status'),'approved','explicit approval creates approved nonfinancial fact');
SELECT set_config('test.out_punch',(public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'punches'->1->>'id'),true);
SELECT lives_ok($$SELECT public.correct_manual_attendance_punch('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.out_punch')::uuid,'replace','out',((current_setting('test.operational_date')::date+1)::text||' 06:45')::timestamp,'تصحيح وقت الخروج')$$,'reasoned correction appends a new interpretation');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'status'),'needs_review','new evidence after approval is pending reapproval');
SELECT set_config('test.second_fact',(public.approve_attendance_fact('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.first_fact')::uuid,'تصحيح بعد المراجعة')->>'fact_id'),true);
SELECT ok(current_setting('test.second_fact')<>'','correction produces a new fact version after reapproval');
SELECT throws_ok($$SELECT public.approve_attendance_fact('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'محاولة بلا تفسير جديد')$$,'23514','attendance_fact_no_new_interpretation','same interpretation cannot be approved twice');
RESET ROLE;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('e9100000-0000-4000-8000-000000000001','e9200000-0000-4000-8000-000000000004','attendance.test.approver_only',1,ARRAY['attendance.view','attendance.approve'],'false');
DELETE FROM platform_core.membership_roles WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND user_id='e9000000-0000-4000-8000-000000000002';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000002','e9200000-0000-4000-8000-000000000004');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.correct_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'معتمد بلا صلاحية التصحيح')$$,'42501','attendance_absence_correct_forbidden','attendance.approve without attendance.correct cannot correct an absence');
RESET ROLE;
DELETE FROM platform_core.membership_roles WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND user_id='e9000000-0000-4000-8000-000000000002';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000002','e9200000-0000-4000-8000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.correct_attendance_absence('e9100000-0000-4000-8000-000000000099',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'محاولة من مستأجر آخر')$$,'42501','attendance_absence_correct_forbidden','correcting an absence in another tenant is denied');
SELECT throws_ok($$SELECT public.correct_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'غياب مع أدلة فعالة')$$,'23514','attendance_absence_not_eligible','active evidence prevents correcting a worked fact to absence');
SELECT lives_ok($$DO $d$ DECLARE punch jsonb; BEGIN FOR punch IN SELECT value FROM jsonb_array_elements(public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'punches') LOOP PERFORM public.correct_manual_attendance_punch('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,(punch->>'id')::uuid,'exclude',NULL,NULL,'استبعاد دليل الدوام المصحح بعد المراجعة'); END LOOP; END $d$; $$,'scenario 2 appends exclusions for every punch after an approved worked fact');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'exception_code'),'absence_candidate','scenario 2: excluding all punches reinterprets the approved-work day as absence candidate');
SELECT throws_ok($$SELECT public.correct_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.first_fact')::uuid,'نسخة قديمة')$$,'40001','attendance_fact_version_stale','absence correction rejects a stale prior fact version');
SELECT set_config('test.corrected_absence',public.correct_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'تصحيح النتيجة المعتمدة إلى غياب بعد استبعاد كل التسجيلات')::text,true);
SELECT is(current_setting('test.corrected_absence')::jsonb->>'state','approved_absence','scenario 2: an approved worked fact can be superseded by an approved absence');
SELECT throws_ok($$SELECT public.correct_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'إعادة طلب التصحيح القديم')$$,'40001','attendance_fact_version_stale','repeated correction cannot supersede a newer fact');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'facts'->0->>'version')::int,3,'scenario 2: absence correction appends fact version three');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'facts'->0->>'corrects_fact_id'),current_setting('test.second_fact'),'scenario 2: new absence fact links to the exact prior approved fact');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'facts'->1->'fact'->>'outcome'),'worked','scenario 2: prior worked fact remains immutable');
SELECT is((SELECT item->>'outcome' FROM jsonb_array_elements(public.attendance_payroll_input_projection('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,current_setting('test.operational_date')::date,NULL,NULL,NULL,100)->'items') item WHERE item->>'employee_code'='ATT-1'),'absence','scenario 2: payroll projection selects the newly approved absence');
SELECT is((SELECT (item->>'attendance_fact_version')::int FROM jsonb_array_elements(public.attendance_payroll_input_projection('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,current_setting('test.operational_date')::date,NULL,NULL,NULL,100)->'items') item WHERE item->>'employee_code'='ATT-1'),3,'scenario 2: payroll projection uses absence fact version three');
SELECT is((SELECT item->>'corrects_fact_id' FROM jsonb_array_elements(public.attendance_payroll_input_projection('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,current_setting('test.operational_date')::date,NULL,NULL,NULL,100)->'items') item WHERE item->>'employee_code'='ATT-1'),current_setting('test.second_fact'),'scenario 2: payroll projection preserves the fact correction link');
SELECT set_config('test.absence_result',public.attendance_open_day('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date-7,NULL,50)::text,true);
SELECT set_config('test.absence_instance',(current_setting('test.absence_result')::jsonb->'items'->0->>'id'),true);
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'interpretation'->>'exception_code'),'absence_candidate','elapsed shift with no events is an absence candidate for review');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.approve_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid,'غياب')$$,'42501','attendance_approve_forbidden','attendance reader cannot approve an absence');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.approve_attendance_absence('e9100000-0000-4000-8000-000000000099',current_setting('test.absence_instance')::uuid,'غياب')$$,'42501','attendance_approve_forbidden','cross-tenant absence approval is denied');
SELECT throws_ok($$SELECT public.approve_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid,'')$$,'22023','attendance_absence_reason_required','absence approval requires a reason');
SELECT is(public.approve_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid,'غياب بعد انقضاء نافذة الحضور')->>'state','approved_absence','authorized reviewer can approve an elapsed no-punch absence with a reason');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'facts'->0->'fact'->>'absence_units')::int,1,'approved absence is a versioned non-financial one-day fact');
SELECT set_config('test.prior_absence_fact',public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'facts'->0->>'id',true);
SELECT throws_ok($$SELECT public.correct_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid,current_setting('test.prior_absence_fact')::uuid,'إعادة اعتماد الغياب بلا تفسير جديد')$$,'23514','attendance_fact_no_new_interpretation','already-approved absence is not duplicated without a new interpretation');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid,'in',((current_setting('test.operational_date')::date-7)::text||' 22:10')::timestamp,'e9600000-0000-4000-8000-000000000004','تسجيل جديد بعد اعتماد الغياب')$$,'new attendance evidence can be recorded after absence approval');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'instance'->>'status'),'needs_review','new evidence after absence approval marks the day for correction review');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'facts'->0->'fact'->>'outcome'),'absence','prior approved absence fact remains immutable while new evidence is pending');
SELECT lives_ok($$SELECT public.correct_manual_attendance_punch('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid,(public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'punches'->0->>'id')::uuid,'exclude',NULL,NULL,'استبعاد التسجيل المضاف بعد اعتماد الغياب')$$,'scenario 3 excludes newly-added source evidence while preserving it');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'interpretation'->>'exception_code'),'absence_candidate','scenario 3: excluded late evidence restores an absence candidate');
SELECT lives_ok($$SELECT public.correct_attendance_absence('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid,current_setting('test.prior_absence_fact')::uuid,'تأكيد الغياب بعد تصحيح التسجيل المضاف')$$,'scenario 3: prior approved absence can be corrected after a new interpretation');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.absence_instance')::uuid)->'facts'->0->>'corrects_fact_id'),current_setting('test.prior_absence_fact'),'scenario 3: corrected absence links to its previous absence fact');
RESET ROLE;
SET LOCAL ROLE postgres;
SELECT ok(time.resolve_local('2026-11-01 01:30','America/New_York') IS NULL,'ambiguous daylight-saving local time is not guessed');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.attendance_facts WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.instance')::uuid),3,'prior approved facts are preserved alongside worked-to-absence correction');
SELECT is((SELECT count(*)::int FROM time.manual_punches WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.instance')::uuid),2,'original punch evidence remains append-only after correction');
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND actor_user_id='e9000000-0000-4000-8000-000000000001'),27,'Work Instance, absence, exception, capture, correction, and approvals audit the actor');
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND actor_user_id='e9000000-0000-4000-8000-000000000003' AND event_key='manual_punch.review_entry'),1,'reviewer action and reason have a distinct audit event');
SELECT is((SELECT details->>'reason' FROM time.attendance_audit_events WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND actor_user_id='e9000000-0000-4000-8000-000000000003' AND event_key='manual_punch.review_entry' LIMIT 1),'إضافة خروج مفقود بعد مراجعة السجل','reviewer reason is captured in the append-only audit detail');
SET LOCAL ROLE authenticated;
SELECT set_config('test.override_today',(now() AT TIME ZONE 'Africa/Cairo')::date::text,true);
SELECT lives_ok($$SELECT public.assign_attendance_work_policy_override('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid,'e9500000-0000-4000-8000-000000000002',current_setting('test.override_today')::date,current_setting('test.override_today')::date,'تغطية دوام مرن لهذا اليوم')$$,'operator can assign a dated policy override for one day');
SELECT throws_ok($$SELECT public.assign_attendance_work_policy_override('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid,'e9500000-0000-4000-8000-000000000002',current_setting('test.override_today')::date,current_setting('test.override_today')::date,'تكرار الفترة')$$,'23P01','attendance_policy_override_overlap','overlapping dated policy ranges are rejected');
SELECT throws_ok($$SELECT public.assign_attendance_work_policy_override('e9100000-0000-4000-8000-000000000099',current_setting('test.employment')::uuid,'e9500000-0000-4000-8000-000000000002',current_setting('test.override_today')::date,current_setting('test.override_today')::date,'محاولة شركة أخرى')$$,'42501','attendance_policy_manage_forbidden','cross-tenant override write is denied');
SELECT throws_ok($$SELECT public.assign_attendance_work_policy_override('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid,'e9500000-0000-4000-8000-000000000002',current_setting('test.override_today')::date-1,current_setting('test.override_today')::date-1,'تاريخ سابق')$$,'22023','attendance_policy_override_historical','historical override cannot rewrite dates');
SELECT set_config('test.override_range_from',(current_setting('test.override_today')::date+5)::text,true);
SELECT set_config('test.override_range_through',(current_setting('test.override_today')::date+7)::text,true);
SELECT lives_ok($$SELECT public.assign_attendance_work_policy_override('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid,'e9500000-0000-4000-8000-000000000002',current_setting('test.override_range_from')::date,current_setting('test.override_range_through')::date,'تغطية مرنة لنطاق أيام')$$,'operator can assign a bounded date range');
SELECT set_config('test.override_range_id',(public.people_work_policy_panel('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid)->'overrides'->0->>'id'),true);
SELECT is((public.people_work_policy_panel('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid)->'overrides'->0->>'valid_through'),current_setting('test.override_range_through'),'panel shows the inclusive end date of a stored range');
SELECT lives_ok($$SELECT public.cancel_attendance_work_policy_override('e9100000-0000-4000-8000-000000000001',current_setting('test.override_range_id')::uuid,'إلغاء تغيير مستقبلي')$$,'operator can cancel an unstarted future override with a reason');
SELECT is((public.people_work_policy_panel('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid)->'overrides'->0->>'cancelled_at') IS NOT NULL,true,'cancelled override remains visible in history');
RESET ROLE;
SELECT is((SELECT details->>'reason' FROM time.attendance_audit_events WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND actor_user_id='e9000000-0000-4000-8000-000000000001' AND event_key='work_policy.override.created' AND details->>'valid_from'=current_setting('test.override_today') LIMIT 1),'تغطية دوام مرن لهذا اليوم','override audit preserves the actor reason');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.assign_attendance_work_policy_override('e9100000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid,'e9500000-0000-4000-8000-000000000002',current_setting('test.override_today')::date,current_setting('test.override_today')::date,'غير مخول')$$,'42501','attendance_policy_manage_forbidden','attendance reader without policy management cannot assign overrides');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.override_day_result',public.attendance_open_day('e9100000-0000-4000-8000-000000000001',current_setting('test.override_today')::date,NULL,50)::text,true);
SELECT set_config('test.override_day_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.override_day_result')::jsonb->'items') item WHERE item->>'employee_code'='ATT-1'),true);
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.override_day_instance')::uuid)->'instance'->>'schedule_kind'),'flexible','Work Instance freezes the dated override policy instead of the People base assignment');
SELECT throws_ok($$SELECT public.assign_attendance_work_policy_override('e9100000-0000-4000-8000-000000000001',current_setting('test.flex_employment')::uuid,'e9500000-0000-4000-8000-000000000001',current_setting('test.override_today')::date,current_setting('test.override_today')::date,'تعديل يوم مفتوح')$$,'23514','attendance_policy_override_materialized_date','an override cannot rewrite an already materialized Work Instance');
RESET ROLE;
SELECT throws_ok($$UPDATE time.manual_punches SET direction='out' WHERE tenant_id='e9100000-0000-4000-8000-000000000001'$$,'55000','attendance_evidence_append_only','manual source evidence cannot be rewritten');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000004',true);
SELECT lives_ok($$SELECT public.change_tenant_capability_entitlement('e9100000-0000-4000-8000-000000000001','hr.attendance',false,NULL,'إيقاف الحضور لاختبار حفظ السجل')$$,'operator can disable the Attendance entitlement for the fixture');
RESET ROLE;
UPDATE platform_core.tenant_capability_entitlements SET valid_until=transaction_timestamp() WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND capability_key='hr.attendance' AND is_granted AND valid_until>transaction_timestamp();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT is((public.time_attendance_access_snapshot('e9100000-0000-4000-8000-000000000001')->>'entitlement_enabled'),'false','Attendance entitlement is visibly disabled');
SELECT is((public.time_attendance_access_snapshot('e9100000-0000-4000-8000-000000000001')->>'can_view'),'true','membership reader permission preserves historical read access');
SELECT is((public.time_attendance_access_snapshot('e9100000-0000-4000-8000-000000000001')->>'can_manage'),'false','disabled entitlement removes write capabilities');
SELECT is(jsonb_array_length(public.attendance_day_list('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,NULL,50)->'items'),1,'existing Work Instance remains visible after entitlement loss');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'permissions'->>'entitlement_enabled'),'false','instance history remains readable while mutation permission is disabled');
SELECT is(jsonb_array_length(public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'facts'),3,'approved historical facts remain readable');
SELECT throws_ok($$SELECT public.attendance_open_day('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,NULL,50)$$,'42501','attendance_manage_forbidden','disabled entitlement cannot open a work day');
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',current_setting('test.in_time')::timestamp,gen_random_uuid(),'تسجيل جديد')$$,'42501','attendance_manage_forbidden','disabled entitlement blocks new manual events');
SELECT throws_ok($$SELECT public.correct_manual_attendance_punch('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.out_punch')::uuid,'replace','out',((current_setting('test.operational_date')::date+1)::text||' 06:50')::timestamp,'تصحيح بعد الإيقاف')$$,'42501','attendance_correct_forbidden','disabled entitlement blocks correction');
SELECT throws_ok($$SELECT public.approve_attendance_fact('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'اعتماد بعد الإيقاف')$$,'42501','attendance_approve_forbidden','disabled entitlement blocks approval');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
