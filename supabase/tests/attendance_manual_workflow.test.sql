BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e9000000-0000-4000-8000-000000000001','attend-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9000000-0000-4000-8000-000000000002','attend-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9000000-0000-4000-8000-000000000003','attend-reviewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9000000-0000-4000-8000-000000000004','attendance-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access) VALUES ('e9000000-0000-4000-8000-000000000004',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('e9100000-0000-4000-8000-000000000001','Attendance test tenant','e9000000-0000-4000-8000-000000000001');
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
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('e9100000-0000-4000-8000-000000000001','e9300000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES('e9100000-0000-4000-8000-000000000001','e9400000-0000-4000-8000-000000000001','e9300000-0000-4000-8000-000000000001','Main',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES('e9100000-0000-4000-8000-000000000001','e9500000-0000-4000-8000-000000000001','NIGHT',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,created_by)
SELECT 'e9100000-0000-4000-8000-000000000001','e9500000-0000-4000-8000-000000000001',1,'وردية ليلية','fixed','Africa/Cairo',ARRAY[extract(dow FROM timezone('Africa/Cairo',now())::date)::smallint+1]::smallint[],'22:00','06:00',true,'e9000000-0000-4000-8000-000000000001';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employee',public.create_people_employee('e9100000-0000-4000-8000-000000000001','ATT-1','موظف اختبار','e9300000-0000-4000-8000-000000000001','e9400000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-7,'monthly',1000,true)::text,true);
SELECT set_config('test.employment',(current_setting('test.employee')::jsonb->>'employment_id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='e9500000-0000-4000-8000-000000000001',work_policy_version=1
WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment')::uuid;
SELECT is((SELECT count(*)::int FROM people.work_assignments WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment')::uuid AND work_policy_template_id='e9500000-0000-4000-8000-000000000001'),1,'test assignment references the policy version');
SELECT set_config('test.operational_date',(timezone('Africa/Cairo',now())::date-7)::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open_result',public.attendance_open_day('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,NULL,50)::text,true);
SELECT ok(jsonb_array_length(current_setting('test.open_result')::jsonb->'items')=1,'authorized day open materializes a bounded Work Instance');
SELECT set_config('test.instance',(current_setting('test.open_result')::jsonb->'items'->0->>'id'),true);
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'timezone_name'),'Africa/Cairo','instance freezes policy IANA timezone');
SELECT ok(((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'expected_end')::timestamptz > (public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'instance'->>'expected_start')::timestamptz),'overnight end is after start as a UTC instant');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'exception_code'),'missing_punch','expired day with no events is surfaced as a missing-punch review');
SELECT is((public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'interpretation'->>'owner_permission'),'attendance.correct','missing-punch exception has a clear review owner');
SELECT throws_ok($$SELECT public.attendance_open_day('e9100000-0000-4000-8000-000000000099',current_setting('test.operational_date')::date,NULL,50)$$,'42501','attendance_manage_forbidden','cross-tenant day creation is denied');
SELECT is(jsonb_array_length(public.attendance_open_day('e9100000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date+1,NULL,50)->'items'),0,'future Cairo date is not materialized for Cairo policy');
SELECT throws_ok($$SELECT public.attendance_instance_detail('e9100000-0000-4000-8000-000000000099',current_setting('test.instance')::uuid)$$,'42501','attendance_view_forbidden','instance details are tenant-scoped');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',timezone('Africa/Cairo',now())::timestamp,gen_random_uuid(),NULL)$$,'42501','attendance_manage_forbidden','reader cannot enter manual punches');
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000003',true);
SELECT set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.in_time',(current_setting('test.operational_date')||' 23:15')::text,true);
SELECT set_config('test.out_time',((current_setting('test.operational_date')::date+1)::text||' 06:30')::text,true);
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
SET LOCAL ROLE postgres;
SELECT ok(time.resolve_local('2026-11-01 01:30','America/New_York') IS NULL,'ambiguous daylight-saving local time is not guessed');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.attendance_facts WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.instance')::uuid),2,'prior approved fact is preserved alongside corrected version');
SELECT is((SELECT count(*)::int FROM time.manual_punches WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND work_instance_id=current_setting('test.instance')::uuid),2,'original punch evidence remains append-only after correction');
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND actor_user_id='e9000000-0000-4000-8000-000000000001'),6,'Work Instance, exception, capture, correction, and approvals audit the actor');
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND actor_user_id='e9000000-0000-4000-8000-000000000003' AND event_key='manual_punch.review_entry'),1,'reviewer action and reason have a distinct audit event');
SELECT is((SELECT details->>'reason' FROM time.attendance_audit_events WHERE tenant_id='e9100000-0000-4000-8000-000000000001' AND actor_user_id='e9000000-0000-4000-8000-000000000003' AND event_key='manual_punch.review_entry' LIMIT 1),'إضافة خروج مفقود بعد مراجعة السجل','reviewer reason is captured in the append-only audit detail');
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
SELECT is(jsonb_array_length(public.attendance_instance_detail('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid)->'facts'),2,'approved historical facts remain readable');
SELECT throws_ok($$SELECT public.attendance_open_day('e9100000-0000-4000-8000-000000000001',current_setting('test.operational_date')::date,NULL,50)$$,'42501','attendance_manage_forbidden','disabled entitlement cannot open a work day');
SELECT throws_ok($$SELECT public.record_manual_attendance_punch_local('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,'in',current_setting('test.in_time')::timestamp,gen_random_uuid(),'تسجيل جديد')$$,'42501','attendance_manage_forbidden','disabled entitlement blocks new manual events');
SELECT throws_ok($$SELECT public.correct_manual_attendance_punch('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.out_punch')::uuid,'replace','out',((current_setting('test.operational_date')::date+1)::text||' 06:50')::timestamp,'تصحيح بعد الإيقاف')$$,'42501','attendance_correct_forbidden','disabled entitlement blocks correction');
SELECT throws_ok($$SELECT public.approve_attendance_fact('e9100000-0000-4000-8000-000000000001',current_setting('test.instance')::uuid,current_setting('test.second_fact')::uuid,'اعتماد بعد الإيقاف')$$,'42501','attendance_approve_forbidden','disabled entitlement blocks approval');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
