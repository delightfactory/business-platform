BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('e9b10000-0000-4000-8000-000000000001','break-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('e9b10000-0000-4000-8000-000000000002','break-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES('e9b11000-0000-4000-8000-000000000001','Observed break test','e9b10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES
 ('e9b11000-0000-4000-8000-000000000001','e9b12000-0000-4000-8000-000000000001','break.operator',1,
  ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance.correct','attendance.approve','attendance_policy.manage'],'false'),
 ('e9b11000-0000-4000-8000-000000000001','e9b12000-0000-4000-8000-000000000002','break.reader',1,ARRAY['attendance.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES
 ('e9b11000-0000-4000-8000-000000000001','e9b10000-0000-4000-8000-000000000001','active','e9b10000-0000-4000-8000-000000000001'),
 ('e9b11000-0000-4000-8000-000000000001','e9b10000-0000-4000-8000-000000000002','active','e9b10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES
 ('e9b11000-0000-4000-8000-000000000001','e9b10000-0000-4000-8000-000000000001','e9b12000-0000-4000-8000-000000000001'),
 ('e9b11000-0000-4000-8000-000000000001','e9b10000-0000-4000-8000-000000000002','e9b12000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES
 ('e9b11000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','e9b10000-0000-4000-8000-000000000001','Time break overlap test'),
 ('e9b11000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','e9b10000-0000-4000-8000-000000000001','Time break overlap test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES('e9b11000-0000-4000-8000-000000000001','e9b13000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES('e9b11000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001','e9b13000-0000-4000-8000-000000000001','Main',true,true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9b10000-0000-4000-8000-000000000001',true);
SELECT set_config('test.day_a',(timezone('Africa/Cairo',now())::date-35)::text,true);
SELECT set_config('test.day_b',(current_setting('test.day_a')::date+7)::text,true);
SELECT set_config('test.day_c',(current_setting('test.day_a')::date+14)::text,true);
SELECT set_config('test.day_d',(current_setting('test.day_a')::date+21)::text,true);
SELECT set_config('test.day_e',(current_setting('test.day_a')::date+28)::text,true);
SELECT set_config('test.fixed_policy',public.save_time_work_policy_with_leave_mapping(
 'e9b11000-0000-4000-8000-000000000001',NULL,'FIXED-BREAK','Known lunch break','fixed','Africa/Cairo',
 ARRAY[extract(dow FROM current_setting('test.day_a')::date)::smallint+1]::smallint[],
 '09:00','17:00',false,60,NULL,NULL,NULL,120,360,false,15,15,false,'13:00','14:00',NULL
 )::text,true);
SELECT set_config('test.fixed_template',current_setting('test.fixed_policy')::jsonb->>'id',true);
SELECT set_config('test.fixed_version',current_setting('test.fixed_policy')::jsonb->>'version',true);
SELECT set_config('test.overnight_policy',public.save_time_work_policy_with_leave_mapping(
 'e9b11000-0000-4000-8000-000000000001',NULL,'OVERNIGHT-BREAK','Overnight break','fixed','Africa/Cairo',
 ARRAY[extract(dow FROM current_setting('test.day_a')::date)::smallint+1]::smallint[],
 '22:00','06:00',true,30,NULL,NULL,NULL,120,360,false,15,15,false,'02:00','02:30',NULL
 )::text,true);
SELECT set_config('test.overnight_template',current_setting('test.overnight_policy')::jsonb->>'id',true);
SELECT set_config('test.overnight_version',current_setting('test.overnight_policy')::jsonb->>'version',true);
SELECT set_config('test.legacy_policy',public.save_time_work_policy(
 'e9b11000-0000-4000-8000-000000000001',NULL,'LEGACY-BREAK','Legacy unknown break','fixed','Africa/Cairo',
 ARRAY[extract(dow FROM current_setting('test.day_a')::date)::smallint+1]::smallint[],
 '09:00','17:00',false,30,NULL,NULL,NULL,120,360,false,15,15,false
 )::text,true);
SELECT set_config('test.legacy_template',current_setting('test.legacy_policy')::jsonb->>'id',true);
SELECT set_config('test.legacy_version',current_setting('test.legacy_policy')::jsonb->>'version',true);
SELECT set_config('test.invalid_policy',public.save_time_work_policy_with_leave_mapping(
 'e9b11000-0000-4000-8000-000000000001',NULL,'DST-BREAK','DST gap break','fixed','America/New_York',
 ARRAY[1]::smallint[],'00:00','04:00',false,60,NULL,NULL,NULL,120,360,false,15,15,false,'02:00','03:00',NULL
 )::text,true);
SELECT set_config('test.invalid_template',current_setting('test.invalid_policy')::jsonb->>'id',true);
SELECT set_config('test.invalid_version',current_setting('test.invalid_policy')::jsonb->>'version',true);
RESET ROLE;

-- Create Employees through the same authorized People flow and use real policy assignments.
SET LOCAL ROLE authenticated;
SELECT set_config('test.emp_after',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-AFTER','After break','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',current_setting('test.day_a')::date-14,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_overlap',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-OVERLAP','Break overlap','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',current_setting('test.day_a')::date-14,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_full',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-FULL','Full shift','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',current_setting('test.day_a')::date-14,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_seconds',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-SECONDS','Second-resolution break','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',current_setting('test.day_a')::date-14,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_night',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-NIGHT','Overnight','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',current_setting('test.day_a')::date-35,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_legacy',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-LEGACY','Legacy break','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',current_setting('test.day_a')::date-14,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_dst',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-DST','DST break','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',date '2026-03-01','monthly',1000,true)::text,true);
RESET ROLE;

UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.fixed_template')::uuid,work_policy_version=current_setting('test.fixed_version')::int,valid_from=current_setting('test.day_a')::date,valid_until=current_setting('test.day_a')::date+1
WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_after')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.fixed_template')::uuid,work_policy_version=current_setting('test.fixed_version')::int,valid_from=current_setting('test.day_b')::date,valid_until=current_setting('test.day_b')::date+1
WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_overlap')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.fixed_template')::uuid,work_policy_version=current_setting('test.fixed_version')::int,valid_from=current_setting('test.day_c')::date,valid_until=current_setting('test.day_c')::date+1
WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_full')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.fixed_template')::uuid,work_policy_version=current_setting('test.fixed_version')::int,valid_from=current_setting('test.day_c')::date,valid_until=current_setting('test.day_c')::date+1
WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_seconds')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.overnight_template')::uuid,work_policy_version=current_setting('test.overnight_version')::int,valid_from=current_setting('test.day_e')::date,valid_until=current_setting('test.day_e')::date+1
WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_night')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.legacy_template')::uuid,work_policy_version=current_setting('test.legacy_version')::int,valid_from=current_setting('test.day_d')::date,valid_until=current_setting('test.day_d')::date+1
WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_legacy')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.invalid_template')::uuid,work_policy_version=current_setting('test.invalid_version')::int,valid_from=date '2026-03-08',valid_until=date '2026-03-09'
WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_dst')::jsonb->>'employment_id')::uuid;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9b10000-0000-4000-8000-000000000001',true);

-- Overlap after the configured break: scheduled 60, observed overlap 0, net 180.
SELECT set_config('test.after_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_a')::date,NULL,50)::text,true);
SELECT set_config('test.after_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.after_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-AFTER'),true);
SELECT set_config('test.after_initial_interpretation',public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.after_instance')::uuid)->'interpretation'->>'id',true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.after_instance')::uuid,'in',(current_setting('test.day_a')||' 14:00')::timestamp,'e9b16000-0000-4000-8000-000000000001','Punch after configured break')$$,'real punch API records post-break start');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.after_instance')::uuid,'out',(current_setting('test.day_a')||' 17:00')::timestamp,'e9b16000-0000-4000-8000-000000000002','Punch after configured break')$$,'real punch API records post-break end');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.after_instance')::uuid)->'interpretation'->>'gross_worked_minutes')::int,180,'gross elapsed duration is retained');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.after_instance')::uuid)->'interpretation'->>'scheduled_break_minutes')::int,60,'scheduled break remains separately visible');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.after_instance')::uuid)->'interpretation'->>'applied_break_minutes')::int,0,'no scheduled break is subtracted when punches start after it');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.after_instance')::uuid)->'interpretation'->>'worked_minutes')::int,180,'post-break attendance keeps all 180 observed minutes');
SELECT is((SELECT item->>'applied_break_minutes' FROM jsonb_array_elements(public.attendance_day_list('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_a')::date,NULL,50)->'items') item WHERE item->>'employee_code'='BRK-AFTER'),'0','bounded attendance list carries applied break separately');
SELECT is((SELECT item->>'applied_break_minutes' FROM jsonb_array_elements(public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_a')::date,NULL,50)->'items') item WHERE item->>'employee_code'='BRK-AFTER'),'0','open-day response carries applied break separately');




-- Break-overlap punches subtract only the 30 minutes actually overlapped.
SELECT set_config('test.overlap_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_b')::date,NULL,50)::text,true);
SELECT set_config('test.overlap_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.overlap_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-OVERLAP'),true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.overlap_instance')::uuid,'in',(current_setting('test.day_b')||' 13:30')::timestamp,'e9b16000-0000-4000-8000-000000000003','Punch through break')$$,'real punch API records partial break overlap start');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.overlap_instance')::uuid,'out',(current_setting('test.day_b')||' 15:00')::timestamp,'e9b16000-0000-4000-8000-000000000004','Punch through break')$$,'real punch API records partial break overlap end');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.overlap_instance')::uuid)->'interpretation'->>'gross_worked_minutes')::int,90,'partial-overlap gross remains 90 minutes');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.overlap_instance')::uuid)->'interpretation'->>'scheduled_break_minutes')::int,60,'partial-overlap retains full scheduled break as separate value');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.overlap_instance')::uuid)->'interpretation'->>'applied_break_minutes')::int,30,'partial-overlap subtracts only 30 minutes');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.overlap_instance')::uuid)->'interpretation'->>'worked_minutes')::int,60,'partial-overlap net duration is 60 minutes');

-- Second-resolution punches retain the established integer-minute rounding: 89.5 gross -> 90,
-- 29.5 overlap -> 30, and net is derived from those recorded integers (60).
SELECT set_config('test.seconds_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_c')::date,NULL,50)::text,true);
SELECT set_config('test.seconds_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.seconds_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-SECONDS'),true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.seconds_instance')::uuid,'in',(current_setting('test.day_c')||' 13:30:30')::timestamp,'e9b16000-0000-4000-8000-000000000015','Second-resolution break overlap start')$$,'public punch RPC accepts second-resolution local punch');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.seconds_instance')::uuid,'out',(current_setting('test.day_c')||' 15:00:00')::timestamp,'e9b16000-0000-4000-8000-000000000016','Second-resolution break overlap end')$$,'public punch RPC accepts matching second-resolution end');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.seconds_instance')::uuid)->'interpretation'->>'gross_worked_minutes')::int,90,'89.5 elapsed minutes retain established integer rounding to 90');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.seconds_instance')::uuid)->'interpretation'->>'applied_break_minutes')::int,30,'29.5 overlap minutes retain established integer rounding to 30');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.seconds_instance')::uuid)->'interpretation'->>'worked_minutes')::int,60,'net minutes are consistently derived as recorded gross minus recorded applied break');
-- A full shift consumes the full placed break and the approved immutable fact carries it.
SELECT set_config('test.full_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_c')::date,NULL,50)::text,true);
SELECT set_config('test.full_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.full_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-FULL'),true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid,'in',(current_setting('test.day_c')||' 09:00')::timestamp,'e9b16000-0000-4000-8000-000000000005','Full shift start')$$,'full-shift start is recorded through public punch RPC');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid,'out',(current_setting('test.day_c')||' 17:00')::timestamp,'e9b16000-0000-4000-8000-000000000006','Full shift end')$$,'full-shift end is recorded through public punch RPC');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid)->'interpretation'->>'gross_worked_minutes')::int,480,'full shift gross duration is 480 minutes');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid)->'interpretation'->>'applied_break_minutes')::int,60,'full shift subtracts all 60 placed break minutes');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid)->'interpretation'->>'worked_minutes')::int,420,'full shift net duration is 420 minutes');
SELECT is(public.approve_attendance_fact('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid,NULL,NULL)->>'state','approved','valid full shift remains approvable through the actual approval RPC');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid)->'facts'->0->'fact'->>'applied_break_minutes')::int,60,'new immutable attendance fact records applied break separately');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.full_instance')::uuid)->'facts'->0->'fact'->>'scheduled_break_minutes')::int,60,'new immutable attendance fact retains scheduled break provenance');

-- Overnight placement follows the next local date and resolves in elapsed time.
SELECT set_config('test.night_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_e')::date,NULL,50)::text,true);
SELECT set_config('test.night_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.night_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-NIGHT'),true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.night_instance')::uuid,'in',(current_setting('test.day_e')||' 22:00')::timestamp,'e9b16000-0000-4000-8000-000000000007','Overnight start')$$,'overnight start punch recorded through public API');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.night_instance')::uuid,'out',((current_setting('test.day_e')::date+1)::text||' 06:00')::timestamp,'e9b16000-0000-4000-8000-000000000008','Overnight end')$$,'overnight end punch recorded through public API');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.night_instance')::uuid)->'interpretation'->>'gross_worked_minutes')::int,480,'overnight gross span resolves to 480 elapsed minutes');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.night_instance')::uuid)->'interpretation'->>'applied_break_minutes')::int,30,'overnight break overlap is 30 minutes');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.night_instance')::uuid)->'interpretation'->>'worked_minutes')::int,450,'overnight net is 450 minutes');

-- Legacy positive break with no placement keeps its existing full-break behavior.
SELECT set_config('test.legacy_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_d')::date,NULL,50)::text,true);
SELECT set_config('test.legacy_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.legacy_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-LEGACY'),true);
SELECT set_config('test.legacy_initial_interpretation',public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.legacy_instance')::uuid)->'interpretation'->>'id',true);
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.legacy_instance')::uuid)->'interpretation'->>'applied_break_minutes'),NULL,'initial no-punch interpretation has no observed applied break');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.legacy_instance')::uuid,'in',(current_setting('test.day_d')||' 14:00')::timestamp,'e9b16000-0000-4000-8000-000000000009','Legacy break start')$$,'legacy policy accepts real after-break start punch');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.legacy_instance')::uuid,'out',(current_setting('test.day_d')||' 17:00')::timestamp,'e9b16000-0000-4000-8000-000000000010','Legacy break end')$$,'legacy policy accepts real after-break end punch');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.legacy_instance')::uuid)->'interpretation'->>'applied_break_minutes')::int,30,'legacy unknown placement still subtracts its full 30-minute aggregate');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.legacy_instance')::uuid)->'interpretation'->>'worked_minutes')::int,150,'legacy unknown placement retains old 180-minus-30 net duration');
SELECT ok((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.legacy_instance')::uuid)->'interpretation'->>'id') IS DISTINCT FROM current_setting('test.legacy_initial_interpretation'),'new punch evidence appends a fresh interpretation');
RESET ROLE;
SELECT is((SELECT applied_break_minutes FROM time.interpretations WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND id=current_setting('test.legacy_initial_interpretation')::uuid),NULL,'pre-punch immutable interpretation remains unchanged with NULL applied-break provenance');
SELECT is((SELECT count(*)::int FROM time.interpretations WHERE tenant_id='e9b11000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.legacy_instance')::uuid),3,'source corrections append interpretations without rewriting older versions');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9b10000-0000-4000-8000-000000000001',true);
-- DST gap in the configured break is not guessed; it remains a review case.
SELECT set_config('test.dst_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',date '2026-03-08',NULL,50)::text,true);
SELECT set_config('test.dst_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.dst_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-DST'),true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.dst_instance')::uuid,'in',timestamp '2026-03-08 01:00','e9b16000-0000-4000-8000-000000000011','DST start punch')$$,'valid local start around the DST gap is accepted');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.dst_instance')::uuid,'out',timestamp '2026-03-08 04:00','e9b16000-0000-4000-8000-000000000012','DST end punch')$$,'valid local end after the DST gap is accepted');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.dst_instance')::uuid)->'interpretation'->>'state'),'needs_review','unresolvable break placement produces review state');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.dst_instance')::uuid)->'interpretation'->>'exception_code'),'break_placement_invalid','DST gap break does not invent an overlap');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.dst_instance')::uuid)->'interpretation'->>'worked_minutes'),NULL,'invalid placement emits no net worked duration');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.dst_instance')::uuid)->'interpretation'->>'applied_break_minutes'),NULL,'invalid placement emits no applied-break quantity');
SELECT ok((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.dst_instance')::uuid)->'permissions'->>'can_approve')::boolean,'review case preserves normal approval authority visibility');


-- Regression: shared fingerprint allows the mapped-break clean path to auto-approve.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9b10000-0000-4000-8000-000000000001',true);
SELECT set_config('test.day_f',(current_setting('test.day_a')::date-7)::text,true);
SELECT set_config('test.auto_policy',public.save_time_work_policy_with_leave_mapping(
 'e9b11000-0000-4000-8000-000000000001',NULL,'BREAK-AUTO','Mapped break auto approval','fixed','Africa/Cairo',
 ARRAY[extract(dow FROM current_setting('test.day_f')::date)::smallint+1]::smallint[],
 '09:00','17:00',false,60,NULL,NULL,NULL,120,360,false,15,15,true,'13:00','14:00',NULL
 )::text,true);
SELECT set_config('test.emp_auto',public.create_people_employee('e9b11000-0000-4000-8000-000000000001','BRK-AUTO','Mapped break auto','e9b13000-0000-4000-8000-000000000001','e9b14000-0000-4000-8000-000000000001',current_setting('test.day_f')::date-14,'monthly',1000,true)::text,true);
RESET ROLE;
UPDATE people.work_assignments
 SET work_policy_template_id=(current_setting('test.auto_policy')::jsonb->>'id')::uuid,
     work_policy_version=(current_setting('test.auto_policy')::jsonb->>'version')::int,
     valid_from=current_setting('test.day_f')::date,
     valid_until=current_setting('test.day_f')::date+1
 WHERE tenant_id='e9b11000-0000-4000-8000-000000000001'
   AND employment_id=(current_setting('test.emp_auto')::jsonb->>'employment_id')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9b10000-0000-4000-8000-000000000001',true);
SELECT set_config('test.auto_result',public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_f')::date,NULL,50)::text,true);
SELECT set_config('test.auto_instance',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.auto_result')::jsonb->'items') item WHERE item->>'employee_code'='BRK-AUTO'),true);
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.auto_instance')::uuid)->'instance'->>'auto_approve_clean')::boolean,true,'new mapped policy freezes the enabled auto-approval setting');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.auto_instance')::uuid,'in',(current_setting('test.day_f')||' 09:00')::timestamp,'e9b16000-0000-4000-8000-000000000013','Mapped-break full shift in')$$,'mapped auto-approval receives a full-shift in punch');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('e9b11000-0000-4000-8000-000000000001',current_setting('test.auto_instance')::uuid,'out',(current_setting('test.day_f')||' 17:00')::timestamp,'e9b16000-0000-4000-8000-000000000014','Mapped-break full shift out')$$,'mapped auto-approval receives a full-shift out punch');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.auto_instance')::uuid)->'interpretation'->>'applied_break_minutes')::int,60,'mapped clean interpretation has the expected applied break');
RESET ROLE;
UPDATE time.work_instances SET attribution_end=now()-interval '1 second'
 WHERE tenant_id='e9b11000-0000-4000-8000-000000000001'
   AND id=current_setting('test.auto_instance')::uuid;
SELECT time.interpret_work_instance('e9b11000-0000-4000-8000-000000000001',current_setting('test.auto_instance')::uuid,'e9b10000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9b10000-0000-4000-8000-000000000001',true);
SELECT is((SELECT item->>'status' FROM jsonb_array_elements(public.attendance_open_day('e9b11000-0000-4000-8000-000000000001',current_setting('test.day_f')::date,NULL,50)->'items') item WHERE item->>'employee_code'='BRK-AUTO'),'approved','shared fingerprint preserves actual clean auto-approval with a mapped break');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.auto_instance')::uuid)->'facts'->0->'fact'->>'applied_break_minutes')::int,60,'auto-approved immutable fact records applied break');
SELECT is((public.attendance_instance_detail('e9b11000-0000-4000-8000-000000000001',current_setting('test.auto_instance')::uuid)->'facts'->0->'fact'->>'worked_minutes')::int,420,'auto-approved immutable fact retains 420 net minutes');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
