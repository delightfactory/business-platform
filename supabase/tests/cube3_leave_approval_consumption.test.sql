BEGIN;
SELECT no_plan();
SELECT set_config('test.today',(pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date::text,true);
SELECT set_config('test.cut',((current_setting('test.today')::date)+200)::text,true);

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('db110000-0000-4000-8000-000000000001','leave-approve-self@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('db110000-0000-4000-8000-000000000002','leave-approve-manager@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('db110000-0000-4000-8000-000000000003','leave-approve-reviewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('db110000-0000-4000-8000-000000000004','leave-approve-balance@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('db120000-0000-4000-8000-000000000001','Leave approval tenant','db110000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('db120000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000001','leave.approval.self.v1',1,ARRAY['leave.self.request','leave.self.view'],false),
       ('db120000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000002','leave.approval.hr.v1',1,ARRAY['leave.manage','leave.view','attendance.manage','attendance.approve','attendance.view','attendance_policy.manage'],false),
       ('db120000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000003','leave.approval.decider.v1',1,ARRAY['leave.approve','leave.view'],false),
       ('db120000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000004','leave.approval.balance.v1',1,ARRAY['leave_balance.adjust'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000002'),
       ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000002','db110000-0000-4000-8000-000000000002'),
       ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000003','db110000-0000-4000-8000-000000000002'),
       ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000004','db110000-0000-4000-8000-000000000002');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000001'),
       ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000002','db130000-0000-4000-8000-000000000002'),
       ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000003','db130000-0000-4000-8000-000000000003'),
       ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000004','db130000-0000-4000-8000-000000000004');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('db120000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001','Approval Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('db120000-0000-4000-8000-000000000001','db170000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001','Approval Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001','APPROVE-SELF','Approval Self','db110000-0000-4000-8000-000000000002'),
       ('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000002','APPROVE-ACCOUNTLESS','Accountless HR Employee','db110000-0000-4000-8000-000000000002');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('db120000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001',(current_setting('test.today')::date)-40,'active','monthly'),
       ('db120000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000002','db140000-0000-4000-8000-000000000002','db150000-0000-4000-8000-000000000001',(current_setting('test.today')::date)-40,'active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('db120000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','db110000-0000-4000-8000-000000000002','approval test'),
       ('db120000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','db110000-0000-4000-8000-000000000002','approval test');

SELECT has_table('leave','request_consumptions','daily allocation table exists');
SELECT ok(NOT has_table_privilege('authenticated','leave.request_consumptions','SELECT'),'allocations are not directly readable');
SELECT ok(has_function_privilege('authenticated','public.leave_approve_request(uuid,uuid,integer,integer,text,text)','EXECUTE'),'approval RPC is granted to authenticated callers');
SELECT ok(NOT has_function_privilege('anon','public.leave_approve_request(uuid,uuid,integer,integer,text,text)','EXECUTE'),'anonymous users cannot approve');
SELECT ok(NOT has_function_privilege('service_role','public.leave_approve_request(uuid,uuid,integer,integer,text,text)','EXECUTE'),'service role cannot bypass approval authorization');
SELECT ok(has_function_privilege('authenticated','public.leave_refresh_request_preview(uuid,uuid,integer,text,text)','EXECUTE'),'preview refresh RPC is exposed to authenticated callers');
SELECT is(to_regprocedure('public.leave_my_balances(uuid,integer,integer)') IS NOT NULL,true,'balance RPC signature remains unchanged');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000002',true);
SELECT set_config('test.calendar',public.leave_create_calendar('db120000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001',
  'approval-cal','Approval Calendar',(current_setting('test.today')::date)-40,NULL,ARRAY[5,6]::smallint[],
  '[]'::jsonb,'accepted source','approval calendar test')::text,true);
SELECT set_config('test.period_a',public.leave_create_year_period('db120000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001',
  current_setting('test.calendar')::uuid,(current_setting('test.today')::date)-20,(current_setting('test.cut')::date)-1,
  'Before boundary','explicit approval test period')::text,true);
SELECT set_config('test.period_b',public.leave_create_year_period('db120000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001',
  current_setting('test.calendar')::uuid,current_setting('test.cut')::date,(current_setting('test.today')::date)+500,
  'After boundary','explicit approval test period')::text,true);
SELECT set_config('test.tracked_type',public.leave_create_type('db120000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001',
  'tracked','Tracked leave',(current_setting('test.today')::date)-20,'paid','tracked',true,
  'verified manual policy','tracked approval test','calendar_days')::text,true);
SELECT set_config('test.untracked_type',public.leave_create_type('db120000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001',
  'untracked','Untracked unpaid leave',(current_setting('test.today')::date)-20,'unpaid','untracked',false,
  'verified manual policy','untracked approval test','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.tracked_version',(SELECT id::text FROM leave.type_versions WHERE leave_type_id=current_setting('test.tracked_type')::uuid AND version=1),true);
SELECT set_config('test.untracked_version',(SELECT id::text FROM leave.type_versions WHERE leave_type_id=current_setting('test.untracked_type')::uuid AND version=1),true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000004',true);
SELECT set_config('test.opening_a',public.leave_post_balance('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001',
 'db150000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.period_a')::uuid,
 'opening',1,current_setting('test.tracked_version')::uuid,'approval-open-a','manual verified balance','Test FIFO account A')->>'entry_id',true);
SELECT set_config('test.account_a',public.leave_post_balance('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001',
 'db150000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.period_a')::uuid,
 'opening',1,current_setting('test.tracked_version')::uuid,'approval-open-a','manual verified balance','Test FIFO account A')->>'account_id',true);
SELECT set_config('test.opening_b',public.leave_post_balance('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001',
 'db150000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.period_b')::uuid,
 'opening',2,current_setting('test.tracked_version')::uuid,'approval-open-b','manual verified balance','Test FIFO account B')->>'entry_id',true);
SELECT set_config('test.account_b',public.leave_post_balance('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001',
 'db150000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.period_b')::uuid,
 'opening',2,current_setting('test.tracked_version')::uuid,'approval-open-b','manual verified balance','Test FIFO account B')->>'account_id',true);
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.own_request',(public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date-1,current_setting('test.cut')::date,
 false,NULL,'two days across the account boundary','approval-own-request')->>'id'),true);
SELECT throws_ok(format($q$SELECT public.leave_approve_request('db120000-0000-4000-8000-000000000001','%s',1,1,'not an approver','own-denied')$q$,
 current_setting('test.own_request')),'42501','leave_forbidden','employee without leave.approve cannot approve a request');
RESET ROLE;

-- Effective calendar changes after submission. Approval returns both versions and
-- writes nothing; only explicit refresh advances the immutable preview pointer.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000002',true);
SELECT set_config('test.calendar_v2',public.leave_revise_calendar('db120000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.cut')::date,NULL,ARRAY[4,5]::smallint[],'[]'::jsonb,'accepted revision','post-submit snapshot change')::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT set_config('test.refresh_needed',public.leave_approve_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.own_request')::uuid,1,1,'review after policy change','approval-first-attempt')::text,true);
SELECT is(current_setting('test.refresh_needed')::jsonb->>'state','refresh_required','approval detects a changed effective snapshot without consuming');
SELECT is(current_setting('test.refresh_needed')::jsonb->>'stored_preview_version','1','approval identifies the submitted preview version');
SELECT set_config('test.refreshed',public.leave_refresh_request_preview('db120000-0000-4000-8000-000000000001',
 current_setting('test.own_request')::uuid,1,'refresh the dated calendar snapshot','approval-refresh-001')::text,true);
SELECT is(current_setting('test.refreshed')::jsonb->>'state','refreshed','reviewer explicitly refreshes a submitted request');
SELECT is((current_setting('test.refreshed')::jsonb->'request'->>'preview_version')::integer,2,'refresh advances to immutable preview version two');
SELECT is((current_setting('test.refreshed')::jsonb->'request'->>'version')::integer,2,'refresh advances request version for CAS');
SELECT is((public.leave_refresh_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.own_request')::uuid,
 1,'refresh the dated calendar snapshot','approval-refresh-001')->>'state'),'refreshed','same authorized refresh key replays the identical result');
SELECT set_config('test.approved',public.leave_approve_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.own_request')::uuid,2,2,'approved after refreshed policy review','approval-approve-001')::text,true);
SELECT is(current_setting('test.approved')::jsonb->>'state','approved','separate approver atomically approves refreshed request');
SELECT is((current_setting('test.approved')::jsonb->>'approved_preview_version')::integer,2,'approval pins the exact reviewed preview version');
SELECT is(jsonb_array_length(current_setting('test.approved')::jsonb->'consumptions'),2,'approval exposes two daily account allocations');
SELECT is((public.leave_request_detail('db120000-0000-4000-8000-000000000001',current_setting('test.own_request')::uuid)->>'state'),
 'approved','authenticated employee detail reflects the approved record');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT is((public.leave_my_requests('db120000-0000-4000-8000-000000000001')->'items'->0->>'state'),
 'approved','own history summary reflects the approved state');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT is(jsonb_array_length(public.leave_hr_queue('db120000-0000-4000-8000-000000000001')->'items'),0,
 'approval removes the completed request from the pending queue');
SELECT is((public.leave_approve_request('db120000-0000-4000-8000-000000000001',current_setting('test.own_request')::uuid,
 2,2,'approved after refreshed policy review','approval-approve-001')->>'state'),'approved','approved retry replays same result under current reviewer authority');
RESET ROLE;

SELECT is((SELECT count(*)::integer FROM leave.request_days WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND request_id=current_setting('test.own_request')::uuid AND preview_version=1),2,'submitted date lines remain immutable after refresh');
SELECT is((SELECT count(*)::integer FROM leave.request_days WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND request_id=current_setting('test.own_request')::uuid AND preview_version=2),2,'refreshed date lines are separately persisted');
SELECT is((SELECT count(*)::integer FROM leave.request_events WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND request_id=current_setting('test.own_request')::uuid AND event_key='hr.approved'),1,'approval retry appends only one decision event');
SELECT is((SELECT count(*)::integer FROM leave.request_consumptions WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND request_id=current_setting('test.own_request')::uuid),2,'approval records one FIFO allocation for each period day');
SELECT is((SELECT sum(units)::numeric FROM leave.request_consumptions WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND request_id=current_setting('test.own_request')::uuid),2::numeric,'cross-period request allocates exactly two units');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND entry_kind='leave_consumption' AND source_reference LIKE 'leave.request:'||current_setting('test.own_request')||'%'),-2::numeric,
 'ledger debits are append-only and sum to the approved request quantity');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND account_id=current_setting('test.account_a')::uuid),0::numeric,'FIFO spends the earlier-period account first');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND account_id=current_setting('test.account_b')::uuid),1::numeric,'later-period account funds its eligible day and retains one unit');
SELECT throws_ok($$UPDATE leave.ledger_entries SET reason='rewrite' WHERE tenant_id='db120000-0000-4000-8000-000000000001'$$,
 '55000','leave_ledger_append_only','consumption ledger rows cannot be edited');

-- A permitted .5 request remains a balance quantity without Attendance. A second
-- .5 on the same date is not treated as a complementary clock part.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.half_request',(public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date+1,current_setting('test.cut')::date+1,
 true,NULL,'half day without Attendance','approval-half-001')->>'id'),true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT is((public.leave_approve_request('db120000-0000-4000-8000-000000000001',current_setting('test.half_request')::uuid,
 1,1,'approve half without Attendance','approval-half-approve')->>'state'),'approved','half-day Leave approves with Attendance disabled');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.half_overlap',(public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date+1,current_setting('test.cut')::date+1,
 true,NULL,'second half same date','approval-half-overlap')->>'id'),true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT throws_ok(format($q$SELECT public.leave_approve_request('db120000-0000-4000-8000-000000000001','%s',1,1,'second half','half-overlap-approve')$q$,
 current_setting('test.half_overlap')),'23514','leave_request_overlap','two half-day quantities on one date are not assumed to be distinct parts');
RESET ROLE;
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND account_id=current_setting('test.account_b')::uuid),0.5::numeric,'allowed half-day consumes exactly 0.5 tracked unit');
-- Insufficient balance after an earlier account can partially fund the date must
-- roll back the partial ledger insert and leave the request submitted.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.insufficient',(public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date+3,current_setting('test.cut')::date+3,
 false,NULL,'one day exceeds remaining manual balance','approval-insufficient')->>'id'),true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT throws_ok(format($q$SELECT public.leave_approve_request('db120000-0000-4000-8000-000000000001','%s',1,1,'balance is short','insufficient-approve')$q$,
 current_setting('test.insufficient')),'23514','leave_balance_insufficient','approval fails when existing manual accounts cannot fund the whole request');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM leave.request_consumptions WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND request_id=current_setting('test.insufficient')::uuid),0,'partial FIFO allocations roll back when any date remains short');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND account_id=current_setting('test.account_b')::uuid),0.5::numeric,'failed approval leaves the verified balance unchanged');
SELECT throws_ok($$UPDATE people.employments SET end_date=current_setting('test.cut')::date
 WHERE tenant_id='db120000-0000-4000-8000-000000000001' AND id='db160000-0000-4000-8000-000000000001'$$,
 '23514','people_employment_end_before_approved_leave','Employment end cannot invalidate a future approved Leave day');

-- Create a real approved Time absence fact, then turn Attendance off. Its historical
-- fact still blocks Leave approval for that Employee and date.
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('db120000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','db110000-0000-4000-8000-000000000002','attendance fact fixture');
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version)
VALUES ('db120000-0000-4000-8000-000000000001','db180000-0000-4000-8000-000000000001','LEAVE-FACT',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,
 shift_start,shift_end,ends_next_day,break_minutes,required_minutes,attribution_before_minutes,attribution_after_minutes,
 created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes,auto_approve_clean)
VALUES ('db120000-0000-4000-8000-000000000001','db180000-0000-4000-8000-000000000001',1,'Leave fact schedule','fixed','Africa/Cairo',
 ARRAY[1,2,3,4,5,6,7]::smallint[],'09:00','17:00',false,0,NULL,120,360,
 'db110000-0000-4000-8000-000000000002',false,30,15,false);
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from)
VALUES ('db120000-0000-4000-8000-000000000001','db190000-0000-4000-8000-000000000001',
 'db160000-0000-4000-8000-000000000001','db170000-0000-4000-8000-000000000001',
 'db180000-0000-4000-8000-000000000001',1,(current_setting('test.today')::date)-40);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000002',true);
SELECT set_config('test.attendance_date',((current_setting('test.today')::date)-2)::text,true);
SELECT set_config('test.attendance_open',public.attendance_open_day('db120000-0000-4000-8000-000000000001',
 current_setting('test.attendance_date')::date,NULL,50)::text,true);
SELECT set_config('test.attendance_instance',(current_setting('test.attendance_open')::jsonb->'items'->0->>'id'),true);
SELECT set_config('test.attendance_detail',public.attendance_instance_detail('db120000-0000-4000-8000-000000000001',
 current_setting('test.attendance_instance')::uuid)::text,true);
SELECT is(current_setting('test.attendance_detail')::jsonb->'interpretation'->>'exception_code','absence_candidate',
 'expired Time day resolves to an explicit absence candidate for review');
SELECT set_config('test.attendance_fact',public.approve_attendance_absence('db120000-0000-4000-8000-000000000001',
 current_setting('test.attendance_instance')::uuid,'approved absence for Leave conflict regression')->>'fact_id',true);
RESET ROLE;
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()
 WHERE tenant_id='db120000-0000-4000-8000-000000000001' AND capability_key='hr.attendance';
SELECT is(platform_private.tenant_capability_is_enabled('db120000-0000-4000-8000-000000000001','hr.attendance',now()),false,
 'Attendance is disabled while its immutable historical fact remains');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000002',true);
SELECT set_config('test.past_request',public.leave_record_hr_request('db120000-0000-4000-8000-000000000001',
 'db140000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,
 current_setting('test.attendance_date')::date,current_setting('test.attendance_date')::date,false,NULL,
 'historical absence already approved in Time','attendance-off-past-leave')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT throws_ok(format($q$SELECT public.leave_approve_request('db120000-0000-4000-8000-000000000001','%s',1,1,'review historical fact','past-fact-conflict')$q$,
 current_setting('test.past_request')),'23514','leave_attendance_fact_conflict','historical Attendance fact blocks duplicate Leave even with Attendance entitlement off');
RESET ROLE;

-- When Attendance is enabled and no versioned half-day mapping exists, refuse the
-- clock interpretation explicitly. No Attendance operation or inferred clock is made.
UPDATE platform_core.tenant_capability_entitlements SET valid_until=NULL
 WHERE tenant_id='db120000-0000-4000-8000-000000000001' AND capability_key='hr.attendance';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.half_mapping_request',(public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date+2,current_setting('test.cut')::date+2,
 true,NULL,'half with Attendance enabled','approval-half-mapping')->>'id'),true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT throws_ok(format($q$SELECT public.leave_approve_request('db120000-0000-4000-8000-000000000001','%s',1,1,'no timing map','half-map-required')$q$,
 current_setting('test.half_mapping_request')),'23514','leave_half_day_mapping_required','half-day Attendance integration requires a versioned mapping');
RESET ROLE;

-- HR submission remains distinct from approval and can target an Employee without
-- a User link. Untracked approval creates no account or balance debit.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000002',true);
SELECT set_config('test.hr_recorded',public.leave_record_hr_request('db120000-0000-4000-8000-000000000001',
 'db140000-0000-4000-8000-000000000002','db160000-0000-4000-8000-000000000002',current_setting('test.untracked_type')::uuid,
 current_setting('test.cut')::date+10,current_setting('test.cut')::date+10,false,NULL,
 'HR recorded unpaid leave for an accountless employee','hr-accountless-untracked')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT set_config('test.untracked_approved',public.leave_approve_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.hr_recorded')::uuid,1,1,'approve untracked leave','hr-accountless-approve')::text,true);
SELECT is(current_setting('test.untracked_approved')::jsonb->>'state','approved','HR independently approves accountless Employee request');
SELECT is(jsonb_array_length(current_setting('test.untracked_approved')::jsonb->'consumptions'),0,
 'untracked unpaid Leave approves without a balance ledger entry');
RESET ROLE;

-- A reviewer may not create a new approval after Leave entitlement closure.
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000003');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.self_approved_request',public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',
 current_setting('test.untracked_type')::uuid,current_setting('test.cut')::date+30,current_setting('test.cut')::date+30,
 false,NULL,'personal request by authorized approver','self-approver-record')->>'id',true);
SELECT is((public.leave_approve_request('db120000-0000-4000-8000-000000000001',current_setting('test.self_approved_request')::uuid,
 1,1,'personal approval explicitly recorded','self-approver-approve')->>'state'),'approved',
 'authorized employee may approve their own request in a separate operation');
RESET ROLE;
SELECT ok((SELECT submitted_by='db110000-0000-4000-8000-000000000001'::uuid
 AND approved_by='db110000-0000-4000-8000-000000000001'::uuid AND approved_at IS NOT NULL
 FROM leave.requests WHERE tenant_id='db120000-0000-4000-8000-000000000001'
 AND id=current_setting('test.self_approved_request')::uuid),'personal submission and approval identities and time are preserved');
SELECT is((SELECT count(*)::integer FROM leave.request_events
 WHERE tenant_id='db120000-0000-4000-8000-000000000001' AND request_id=current_setting('test.self_approved_request')::uuid
 AND event_key IN ('employee.submitted','hr.approved')),2,'personal submission and approval retain two separate audit events');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000002',true);
SELECT set_config('test.disabled_pending',public.leave_record_hr_request('db120000-0000-4000-8000-000000000001',
 'db140000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000001',current_setting('test.untracked_type')::uuid,
 current_setting('test.cut')::date+20,current_setting('test.cut')::date+20,false,NULL,
 'pending record before entitlement closure','disabled-pending-record')->>'id',true);
RESET ROLE;
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()
 WHERE tenant_id='db120000-0000-4000-8000-000000000001' AND capability_key='hr.leave';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT throws_ok(format($q$SELECT public.leave_approve_request('db120000-0000-4000-8000-000000000001','%s',1,1,'disabled new approval','leave-disabled')$q$,
 current_setting('test.disabled_pending')),'55000','leave_new_work_disabled','entitlement closure blocks new approval and debit');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
