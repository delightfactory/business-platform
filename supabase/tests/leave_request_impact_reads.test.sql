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
RESET ROLE;
SELECT set_config('test.before',pg_catalog.jsonb_build_array((SELECT count(*) FROM leave.requests),(SELECT count(*) FROM leave.request_events),(SELECT count(*) FROM leave.ledger_entries))::text,true);
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,aud,role,created_at,updated_at)
VALUES('db110000-0000-4000-8000-000000000005','impact-manage-only@example.test','hash',now(),'authenticated','authenticated',now(),now()),
('db110000-0000-4000-8000-000000000006','impact-request-only@example.test','hash',now(),'authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES('db120000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000005','impact.request.only.v1',1,ARRAY['leave.self.request'],false),
('db120000-0000-4000-8000-000000000001','db130000-0000-4000-8000-000000000006','impact.manage.only.v1',1,ARRAY['leave.manage'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
SELECT 'db120000-0000-4000-8000-000000000001',u,'db110000-0000-4000-8000-000000000002' FROM unnest(ARRAY['db110000-0000-4000-8000-000000000005'::uuid,'db110000-0000-4000-8000-000000000006'::uuid])u;
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000004','db130000-0000-4000-8000-000000000005'),
('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000005','db130000-0000-4000-8000-000000000006'),
('db120000-0000-4000-8000-000000000001','db110000-0000-4000-8000-000000000006','db130000-0000-4000-8000-000000000005');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id) VALUES
('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000002','db110000-0000-4000-8000-000000000006','db110000-0000-4000-8000-000000000002');
SELECT ok(NOT has_function_privilege('anon','public.leave_my_request_preview(uuid,uuid,date,date,boolean,text)','EXECUTE'),'anonymous cannot preview');
SELECT ok(NOT has_function_privilege('service_role','public.leave_hr_request_preview(uuid,uuid,uuid,uuid,date,date,boolean,text)','EXECUTE'),'service role cannot bypass HR authorization');
SELECT ok(NOT has_function_privilege('authenticated','leave.request_impact_read(uuid,uuid,uuid,uuid,uuid,date,date,boolean,text,boolean)','EXECUTE'),'private shaping/allocation helper is inaccessible');
SET LOCAL ROLE authenticated;
SELECT set_config('test.impact',public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date-1,current_setting('test.cut')::date,false,NULL)::text,true);
SELECT is(current_setting('test.impact')::jsonb->>'state','ready','two-day cross-period preview is ready');
SELECT is(current_setting('test.impact')::jsonb->>'total_units','2.00','units are exact decimal strings');
SELECT is(current_setting('test.impact')::jsonb#>>'{balance,available_days}','3.00','all eligible account credits are visible');
SELECT is(current_setting('test.impact')::jsonb#>>'{balance,after_approval_days}','1.00','FIFO simulation leaves one day after approval');
SELECT is(current_setting('test.impact')::jsonb#>>'{balance,shortfall_days}','0.00','cross-period credits cover eligible dates');
SELECT ok(NOT(current_setting('test.impact')::jsonb->'days'->0 ?| ARRAY['year_period_id','type_version_id','halfday_mapping_snapshot','employee_id']),'presentation strips internal IDs and mapping evidence');
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.untracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)#>>'{balance,state}','not_tracked','untracked type never implies a missing zero balance');
SELECT set_config('test.short',public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date-2,current_setting('test.cut')::date,false,NULL)::text,true);
SELECT is(current_setting('test.short')::jsonb#>>'{balance,shortfall_days}','1.00','future account credit cannot fund an earlier day even when total credit equals request');
SELECT ok(current_setting('test.short')::jsonb#>'{balance,after_approval_days}'='null'::jsonb,'insufficient request does not promise an approved remaining balance');
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,true,NULL)->>'total_units','0.50','half-day uses authoritative exact units');
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.untracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,true,NULL)->>'reason','half_day_not_allowed','known half-day restriction is unavailable rather than zero');
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001','db199999-0000-4000-8000-000000000001',current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)->>'reason','type','foreign/missing type returns no data');
SELECT throws_ok($$SELECT public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,'first')$$,'22023','leave_half_day_part_invalid','half-day part cannot accompany a full day');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)$$,'42501','leave_self_forbidden','approver without self request cannot preview an employee request');
SELECT throws_ok($$SELECT public.leave_hr_request_preview('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)$$,'42501','leave_forbidden','HR preview requires manage, not approval alone');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000002',true);
SELECT is(public.leave_hr_request_preview('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date-1,current_setting('test.cut')::date,false,NULL),current_setting('test.impact')::jsonb,'authorized HR and own preview have identical calculation and presentation');
SELECT throws_ok($$SELECT public.leave_hr_request_preview('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000002','db160000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)$$,'23514','leave_employment_range_unavailable','employment must belong to the requested employee');
SELECT throws_ok($$SELECT public.leave_hr_request_preview('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.today')::date-100,current_setting('test.today')::date-99,false,NULL)$$,'23514','leave_employment_range_unavailable','out-of-employment range is denied');
SELECT set_config('test.working_type',public.leave_create_type('db120000-0000-4000-8000-000000000001','db150000-0000-4000-8000-000000000001','impact-working','Working days',(current_setting('test.today')::date)-20,'paid','tracked',true,'verified policy','working-day boundary test','working_days')::text,true);
SELECT set_config('test.friday',(current_setting('test.today')::date+((5-extract(dow FROM current_setting('test.today')::date)::integer+7)%7))::text,true);
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.today')::date-25,current_setting('test.today')::date-25,false,NULL)->>'reason','year_period','missing year period is unavailable');
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.working_type')::uuid,current_setting('test.friday')::date,current_setting('test.friday')::date,false,NULL)->>'reason','zero_days','non-working full day is unavailable, not a zero-unit success');
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.working_type')::uuid,current_setting('test.friday')::date,current_setting('test.friday')::date,true,NULL)->>'reason','half_day_ineligible','non-working half day is unavailable');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)$$,'42501','leave_self_forbidden','unlinked member is denied by the existing self-authority guard');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000005',true);
SELECT is(public.leave_hr_request_preview('db120000-0000-4000-8000-000000000001','db140000-0000-4000-8000-000000000001','db160000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)->'balance','{"state":"hidden"}'::jsonb,'manage-only actor receives no balance amounts or accounts');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000006',true);
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date,current_setting('test.cut')::date,false,NULL)->'balance','{"state":"hidden"}'::jsonb,'request-only employee receives no hidden balance or inferred zero');
RESET ROLE;
SELECT is(pg_catalog.jsonb_build_array((SELECT count(*) FROM leave.requests),(SELECT count(*) FROM leave.request_events),(SELECT count(*) FROM leave.ledger_entries))::text,current_setting('test.before'),'all preview and rejected authorization reads leave requests/events/ledger unchanged');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.short_request',public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date-2,current_setting('test.cut')::date,false,NULL,'insufficient date-aware impact parity','impact-short')->>'id',true);
SELECT is(public.leave_my_request_preview('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date-1,current_setting('test.cut')::date,false,NULL)#>>'{balance,available_days}','3.00','pending request does not reserve balance');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.leave_approve_request('db120000-0000-4000-8000-000000000001',current_setting('test.short_request')::uuid,1,1,'test preview shortage against real approval','impact-short-approve')$$,'23514','leave_balance_insufficient','actual approval rejects the date-aware preview shortage');
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.covered_request',public.leave_submit_own_request('db120000-0000-4000-8000-000000000001',current_setting('test.tracked_type')::uuid,current_setting('test.cut')::date-1,current_setting('test.cut')::date,false,NULL,'covered cross-period parity','impact-covered')->>'id',true);
SELECT set_config('request.jwt.claim.sub','db110000-0000-4000-8000-000000000003',true);
SELECT is(public.leave_approve_request('db120000-0000-4000-8000-000000000001',current_setting('test.covered_request')::uuid,1,1,'test preview coverage against real approval','impact-covered-approve')->>'state','approved','actual approval accepts the covered cross-period preview');
RESET ROLE;
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='db120000-0000-4000-8000-000000000001' AND account_id IN(current_setting('test.account_a')::uuid,current_setting('test.account_b')::uuid)),1::numeric,'actual resulting balance equals predicted after-approval value');
SELECT * FROM finish();
ROLLBACK;
