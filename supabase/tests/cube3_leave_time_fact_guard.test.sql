BEGIN;
SELECT no_plan();
SELECT set_config('test.today',(pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date::text,true);
SELECT set_config('test.day',((current_setting('test.today')::date)-1)::text,true);

-- Isolated tenant/users; all business objects are created through their scoped RPCs.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('dc110000-0000-4000-8000-000000000001','time-leave-manager@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('dc120000-0000-4000-8000-000000000001','Time Leave reciprocal test','dc110000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('dc120000-0000-4000-8000-000000000001','dc130000-0000-4000-8000-000000000001','time.leave.manager',1,
 ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage',
 'leave.manage','leave.view','leave.approve','attendance.view','attendance.manage','attendance.correct','attendance.approve','attendance_policy.manage'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('dc120000-0000-4000-8000-000000000001','dc110000-0000-4000-8000-000000000001','dc110000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('dc120000-0000-4000-8000-000000000001','dc110000-0000-4000-8000-000000000001','dc130000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('dc120000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','dc110000-0000-4000-8000-000000000001','reciprocal Time Leave test'),
       ('dc120000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','dc110000-0000-4000-8000-000000000001','reciprocal Time Leave test'),
       ('dc120000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','dc110000-0000-4000-8000-000000000001','reciprocal Time Leave test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('dc120000-0000-4000-8000-000000000001','dc150000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('dc120000-0000-4000-8000-000000000001','dc170000-0000-4000-8000-000000000001','dc150000-0000-4000-8000-000000000001','Main',true,true);

INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version)
VALUES ('dc120000-0000-4000-8000-000000000001','dc180000-0000-4000-8000-000000000001','FLEX-NOAUTO',true,1),
       ('dc120000-0000-4000-8000-000000000001','dc180000-0000-4000-8000-000000000002','FLEX-AUTO',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by,auto_approve_clean)
VALUES ('dc120000-0000-4000-8000-000000000001','dc180000-0000-4000-8000-000000000001',1,'Flexible review','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59','dc110000-0000-4000-8000-000000000001',false),
       ('dc120000-0000-4000-8000-000000000001','dc180000-0000-4000-8000-000000000002',1,'Flexible auto','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59','dc110000-0000-4000-8000-000000000001',true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','dc110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.emp_a',public.create_people_employee('dc120000-0000-4000-8000-000000000001','TL-A','Fact conflict','dc150000-0000-4000-8000-000000000001','dc170000-0000-4000-8000-000000000001',current_setting('test.day')::date-30,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_b',public.create_people_employee('dc120000-0000-4000-8000-000000000001','TL-B','Fact clear','dc150000-0000-4000-8000-000000000001','dc170000-0000-4000-8000-000000000001',current_setting('test.day')::date-30,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_c',public.create_people_employee('dc120000-0000-4000-8000-000000000001','TL-C','Absence conflict','dc150000-0000-4000-8000-000000000001','dc170000-0000-4000-8000-000000000001',current_setting('test.day')::date-30,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_d',public.create_people_employee('dc120000-0000-4000-8000-000000000001','TL-D','Auto conflict','dc150000-0000-4000-8000-000000000001','dc170000-0000-4000-8000-000000000001',current_setting('test.day')::date-30,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_e',public.create_people_employee('dc120000-0000-4000-8000-000000000001','TL-E','Bulk clear','dc150000-0000-4000-8000-000000000001','dc170000-0000-4000-8000-000000000001',current_setting('test.day')::date-30,'monthly',1000,true)::text,true);
SELECT set_config('test.emp_f',public.create_people_employee('dc120000-0000-4000-8000-000000000001','TL-F','Auto clear','dc150000-0000-4000-8000-000000000001','dc170000-0000-4000-8000-000000000001',current_setting('test.day')::date-30,'monthly',1000,true)::text,true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='dc180000-0000-4000-8000-000000000001',work_policy_version=1 WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_a')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='dc180000-0000-4000-8000-000000000001',work_policy_version=1 WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_b')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='dc180000-0000-4000-8000-000000000001',work_policy_version=1 WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_c')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='dc180000-0000-4000-8000-000000000002',work_policy_version=1 WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_d')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='dc180000-0000-4000-8000-000000000001',work_policy_version=1 WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_e')::jsonb->>'employment_id')::uuid;
UPDATE people.work_assignments SET work_policy_template_id='dc180000-0000-4000-8000-000000000002',work_policy_version=1 WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND employment_id=(current_setting('test.emp_f')::jsonb->>'employment_id')::uuid;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','dc110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('dc120000-0000-4000-8000-000000000001','dc150000-0000-4000-8000-000000000001','time-leave-cal','Time Leave test calendar',current_setting('test.day')::date-30,NULL,ARRAY[]::smallint[],'[]'::jsonb,'explicit test source','time reciprocal guard test')::text,true);
SELECT set_config('test.period',public.leave_create_year_period('dc120000-0000-4000-8000-000000000001','dc150000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.day')::date-20,current_setting('test.day')::date+20,'Time Leave test period','time reciprocal guard test')::text,true);
SELECT set_config('test.type',public.leave_create_type('dc120000-0000-4000-8000-000000000001','dc150000-0000-4000-8000-000000000001','unpaid-test','Unpaid tracked-free test',current_setting('test.day')::date-30,'unpaid','untracked',false,'reviewed QA policy','time reciprocal guard test','calendar_days')::text,true);
SELECT set_config('test.open',public.attendance_open_day('dc120000-0000-4000-8000-000000000001',current_setting('test.day')::date,NULL,50)::text,true);
SELECT set_config('test.i_a',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='TL-A'),true);
SELECT set_config('test.i_b',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='TL-B'),true);
SELECT set_config('test.i_c',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='TL-C'),true);
SELECT set_config('test.i_d',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='TL-D'),true);
SELECT set_config('test.i_e',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='TL-E'),true);
SELECT set_config('test.i_f',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open')::jsonb->'items') item WHERE item->>'employee_code'='TL-F'),true);
SELECT is(jsonb_array_length(current_setting('test.open')::jsonb->'items'),6,'actual day-open RPC materializes all six test Work Instances');

-- Actual punches produce ready interpretations for worked rows; C remains an absence candidate.
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_a')::uuid,'in',(current_setting('test.day')||' 10:00')::timestamp,'dc190000-0000-4000-8000-000000000001','QA time leave in A');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_a')::uuid,'out',(current_setting('test.day')||' 12:30')::timestamp,'dc190000-0000-4000-8000-000000000002','QA time leave out A');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_b')::uuid,'in',(current_setting('test.day')||' 10:00')::timestamp,'dc190000-0000-4000-8000-000000000003','QA time leave in B');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_b')::uuid,'out',(current_setting('test.day')||' 12:30')::timestamp,'dc190000-0000-4000-8000-000000000004','QA time leave out B');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_d')::uuid,'in',(current_setting('test.day')||' 10:00')::timestamp,'dc190000-0000-4000-8000-000000000005','QA time leave in D');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_d')::uuid,'out',(current_setting('test.day')||' 12:30')::timestamp,'dc190000-0000-4000-8000-000000000006','QA time leave out D');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_e')::uuid,'in',(current_setting('test.day')||' 10:00')::timestamp,'dc190000-0000-4000-8000-000000000007','QA time leave in E');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_e')::uuid,'out',(current_setting('test.day')||' 12:30')::timestamp,'dc190000-0000-4000-8000-000000000008','QA time leave out E');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_f')::uuid,'in',(current_setting('test.day')||' 10:00')::timestamp,'dc190000-0000-4000-8000-000000000009','QA time leave in F');
SELECT public.record_manual_attendance_punch_local('dc120000-0000-4000-8000-000000000001',current_setting('test.i_f')::uuid,'out',(current_setting('test.day')||' 12:30')::timestamp,'dc190000-0000-4000-8000-000000000010','QA time leave out F');

-- Submit and approve real Leave requests through the scoped public RPCs.
SELECT set_config('test.req_a',(public.leave_record_hr_request('dc120000-0000-4000-8000-000000000001',(current_setting('test.emp_a')::jsonb->>'employee_id')::uuid,(current_setting('test.emp_a')::jsonb->>'employment_id')::uuid,current_setting('test.type')::uuid,current_setting('test.day')::date,current_setting('test.day')::date,false,NULL,'Approved Leave blocks Time fact','time-leave-request-A')->>'id'),true);
SELECT set_config('test.req_c',(public.leave_record_hr_request('dc120000-0000-4000-8000-000000000001',(current_setting('test.emp_c')::jsonb->>'employee_id')::uuid,(current_setting('test.emp_c')::jsonb->>'employment_id')::uuid,current_setting('test.type')::uuid,current_setting('test.day')::date,current_setting('test.day')::date,false,NULL,'Approved Leave blocks absence','time-leave-request-C')->>'id'),true);
SELECT set_config('test.req_d',(public.leave_record_hr_request('dc120000-0000-4000-8000-000000000001',(current_setting('test.emp_d')::jsonb->>'employee_id')::uuid,(current_setting('test.emp_d')::jsonb->>'employment_id')::uuid,current_setting('test.type')::uuid,current_setting('test.day')::date,current_setting('test.day')::date,false,NULL,'Approved Leave blocks auto approval','time-leave-request-D')->>'id'),true);
SELECT is((public.leave_approve_request('dc120000-0000-4000-8000-000000000001',current_setting('test.req_a')::uuid,1,1,'approve A','time-leave-approve-A')->>'state'),'approved','A has a real approved Leave preview');
SELECT is((public.leave_approve_request('dc120000-0000-4000-8000-000000000001',current_setting('test.req_c')::uuid,1,1,'approve C','time-leave-approve-C')->>'state'),'approved','C has a real approved Leave preview');
SELECT is((public.leave_approve_request('dc120000-0000-4000-8000-000000000001',current_setting('test.req_d')::uuid,1,1,'approve D','time-leave-approve-D')->>'state'),'approved','D has a real approved Leave preview');

SELECT throws_ok(format($q$SELECT public.approve_attendance_fact('dc120000-0000-4000-8000-000000000001','%s',NULL,NULL)$q$,current_setting('test.i_a')),'23514','leave_conflict_review_required','manual worked-fact approval refuses an approved Leave day');
SELECT lives_ok(format($q$SELECT public.approve_attendance_fact('dc120000-0000-4000-8000-000000000001','%s',NULL,NULL)$q$,current_setting('test.i_b')),'a worked day without approved Leave remains approvable');
SELECT throws_ok(format($q$SELECT public.approve_attendance_absence('dc120000-0000-4000-8000-000000000001','%s','absence after Leave')$q$,current_setting('test.i_c')),'23514','leave_conflict_review_required','absence approval refuses an approved Leave day');

-- Reopening the expired day invokes the real auto-approval path: D is withheld, F proceeds.
SELECT public.attendance_open_day('dc120000-0000-4000-8000-000000000001',current_setting('test.day')::date,NULL,50);
SELECT is((public.attendance_instance_detail('dc120000-0000-4000-8000-000000000001',current_setting('test.i_d')::uuid)->'instance'->>'status'),'ready','auto approval leaves approved-Leave Work Instance pending review');
SELECT is((public.attendance_instance_detail('dc120000-0000-4000-8000-000000000001',current_setting('test.i_f')::uuid)->'instance'->>'status'),'approved','auto approval still processes a clear Work Instance');

-- Bulk retains its existing item-level skip contract while the clear item approves.
SELECT set_config('test.bulk',public.approve_attendance_facts_bulk('dc120000-0000-4000-8000-000000000001',current_setting('test.day')::date,ARRAY[current_setting('test.i_a')::uuid,current_setting('test.i_e')::uuid])::text,true);
SELECT is((current_setting('test.bulk')::jsonb->>'approved_count')::integer,1,'bulk approves its clear item');
SELECT is((current_setting('test.bulk')::jsonb->>'skipped_count')::integer,1,'bulk skips its approved-Leave conflict without aborting the batch');
SELECT is((SELECT item->>'reason_code' FROM jsonb_array_elements(current_setting('test.bulk')::jsonb->'items') AS x(item) WHERE item->>'instance_id'=current_setting('test.i_a')),'leave_conflict_review_required','bulk identifies its Leave conflict by Work Instance ID');

RESET ROLE;
SELECT is((SELECT count(*)::integer FROM time.attendance_facts WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.i_a')::uuid),0,'manual Leave conflict wrote no fact');
SELECT is((SELECT count(*)::integer FROM time.attendance_facts WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.i_b')::uuid),1,'clear manual approval wrote one fact');
SELECT is((SELECT count(*)::integer FROM time.attendance_facts WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.i_c')::uuid),0,'Leave conflict wrote no absence fact');
SELECT is((SELECT count(*)::integer FROM time.attendance_facts WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.i_d')::uuid),0,'auto Leave conflict wrote no fact');
SELECT is((SELECT count(*)::integer FROM time.attendance_facts WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.i_e')::uuid),1,'clear bulk item wrote one fact');
SELECT is((SELECT count(*)::integer FROM time.attendance_facts WHERE tenant_id='dc120000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.i_f')::uuid),1,'clear automatic approval wrote one fact');

-- A naturally reachable correction conflict cannot be seeded after public Leave approval:
-- approval itself rejects an existing same-day Attendance fact. The correction guard still
-- protects historical/imported approved Leave rows; this suite does not forge such rows.
SELECT * FROM finish();
ROLLBACK;

