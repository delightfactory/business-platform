BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('cfa10000-0000-4000-8000-000000000001','leave-request-self@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('cfa10000-0000-4000-8000-000000000002','leave-request-hr@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('cfa10000-0000-4000-8000-000000000003','leave-request-approver@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('cfa10000-0000-4000-8000-000000000004','leave-request-unlinked@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','Leave request tenant','cfa10000-0000-4000-8000-000000000001'),
       ('cfa20000-0000-4000-8000-000000000002','Other tenant','cfa10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa30000-0000-4000-8000-000000000001','leave.request.self.v1',1,ARRAY['leave.self.request','leave.self.view'],'false'),
       ('cfa20000-0000-4000-8000-000000000001','cfa30000-0000-4000-8000-000000000002','leave.request.manager.v1',1,ARRAY['leave.manage','leave.view'],'false'),
       ('cfa20000-0000-4000-8000-000000000001','cfa30000-0000-4000-8000-000000000003','leave.request.approver.v1',1,ARRAY['leave.approve','leave.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000001'),
       ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000002','cfa10000-0000-4000-8000-000000000001'),
       ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000003','cfa10000-0000-4000-8000-000000000001'),
       ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000004','cfa10000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000001','cfa30000-0000-4000-8000-000000000001'),
       ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000002','cfa30000-0000-4000-8000-000000000002'),
       ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000003','cfa30000-0000-4000-8000-000000000003'),
       ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000004','cfa30000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa50000-0000-4000-8000-000000000001','Request Employer',true),
       ('cfa20000-0000-4000-8000-000000000002','cfa50000-0000-4000-8000-000000000002','Other Employer',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa40000-0000-4000-8000-000000000001','REQ-SELF','Request Self','cfa10000-0000-4000-8000-000000000002'),
       ('cfa20000-0000-4000-8000-000000000001','cfa40000-0000-4000-8000-000000000002','REQ-HR','Accountless HR Record','cfa10000-0000-4000-8000-000000000002'),
       ('cfa20000-0000-4000-8000-000000000002','cfa40000-0000-4000-8000-000000000003','OTHER-1','Other Tenant Employee','cfa10000-0000-4000-8000-000000000002');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa60000-0000-4000-8000-000000000001','cfa40000-0000-4000-8000-000000000001','cfa50000-0000-4000-8000-000000000001',(current_setting('test.today')::date)-30,'active','monthly'),
       ('cfa20000-0000-4000-8000-000000000001','cfa60000-0000-4000-8000-000000000002','cfa40000-0000-4000-8000-000000000002','cfa50000-0000-4000-8000-000000000001',(current_setting('test.today')::date)-30,'active','monthly'),
       ('cfa20000-0000-4000-8000-000000000002','cfa60000-0000-4000-8000-000000000003','cfa40000-0000-4000-8000-000000000003','cfa50000-0000-4000-8000-000000000002',(current_setting('test.today')::date)-30,'active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa40000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('cfa20000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 day','cfa10000-0000-4000-8000-000000000002','submission test'),
       ('cfa20000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 day','cfa10000-0000-4000-8000-000000000002','submission test');

SELECT ok(NOT platform_private.has_tenant_permission('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000001','people.view'),
  'own role has no People directory permission');
SELECT ok(NOT platform_private.has_tenant_permission('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000001','people.self.view'),
  'own request path does not require or receive profile permission');
SELECT has_table('leave','requests','request header table exists');
SELECT has_table('leave','request_previews','versioned immutable date-preview parent exists');
SELECT has_table('leave','request_days','immutable date preview lines exist');
SELECT has_table('leave','request_events','append-only operation events exist');
SELECT has_column('leave','requests','half_day_part','request header records immutable submitted part');
SELECT has_column('leave','request_days','half_day_part','preview day stores effective reviewed part');
SELECT has_column('leave','request_days','halfday_mapping_state','preview day stores mapping state');
SELECT has_column('leave','request_days','halfday_mapping_snapshot','preview day stores complete calculator evidence');
SELECT has_column('leave','request_days','halfday_policy_template_id','preview day stores Time policy identity');
SELECT has_column('leave','request_days','halfday_policy_version','preview day stores Time policy version');
SELECT has_column('leave','request_days','halfday_algorithm_version','preview day stores calculator version');
SELECT ok(NOT has_table_privilege('authenticated','leave.requests','SELECT'),'request tables are not directly readable');
SELECT ok(NOT has_table_privilege('authenticated','leave.request_days','SELECT'),'preview lines are not directly readable');
SELECT ok(has_function_privilege('authenticated','public.leave_submit_own_request(uuid,uuid,date,date,boolean,text,text,text)','EXECUTE'),'own submit RPC is exposed to authenticated users');
SELECT ok(NOT has_function_privilege('anon','public.leave_submit_own_request(uuid,uuid,date,date,boolean,text,text,text)','EXECUTE'),'anonymous users cannot submit');
SELECT ok(NOT has_function_privilege('service_role','public.leave_submit_own_request(uuid,uuid,date,date,boolean,text,text,text)','EXECUTE'),'service role cannot bypass the submit boundary');
SELECT ok(to_regprocedure('public.leave_my_balances(uuid,integer,integer)') IS NOT NULL,'existing balance signature remains intact');
SELECT ok(has_function_privilege('authenticated','public.leave_my_halfday_mapping_options(uuid,date)','EXECUTE'),'own mapping options are granted');
SELECT ok(has_function_privilege('authenticated','public.leave_hr_halfday_mapping_options(uuid,uuid,date)','EXECUTE'),'HR mapping options are granted');
SELECT ok(has_function_privilege('authenticated','public.leave_my_refresh_halfday_preview(uuid,uuid,integer,text,text,text)','EXECUTE'),'own part refresh is granted');
SELECT ok(has_function_privilege('authenticated','public.leave_hr_refresh_halfday_preview(uuid,uuid,integer,text,text,text)','EXECUTE'),'HR part refresh is granted');
SELECT ok(NOT has_function_privilege('service_role','public.leave_my_refresh_halfday_preview(uuid,uuid,integer,text,text,text)','EXECUTE'),'service role cannot bypass own identity checks');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT set_config('test.calendar',public.leave_create_calendar('cfa20000-0000-4000-8000-000000000001','cfa50000-0000-4000-8000-000000000001',
  'request-cal','Request calendar',(current_setting('test.today')::date)-10,NULL,ARRAY[5,6]::smallint[],
  '[]'::jsonb,'accepted calendar','request submission test calendar')::text,true);
SELECT public.leave_revise_calendar('cfa20000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
  (current_setting('test.today')::date)+5,NULL,ARRAY[4,5]::smallint[],
  '[]'::jsonb,'calendar revision','version boundary test');
SELECT set_config('test.period_a',public.leave_create_year_period('cfa20000-0000-4000-8000-000000000001','cfa50000-0000-4000-8000-000000000001',
  current_setting('test.calendar')::uuid,(current_setting('test.today')::date)-10,(current_setting('test.today')::date)+4,
  'Period A','explicit boundary')::text,true);
SELECT set_config('test.period_b',public.leave_create_year_period('cfa20000-0000-4000-8000-000000000001','cfa50000-0000-4000-8000-000000000001',
  current_setting('test.calendar')::uuid,(current_setting('test.today')::date)+5,(current_setting('test.today')::date)+1100,
  'Period B','explicit boundary')::text,true);
SELECT set_config('test.type',public.leave_create_type('cfa20000-0000-4000-8000-000000000001','cfa50000-0000-4000-8000-000000000001',
  'request-test','Request Test',(current_setting('test.today')::date)-10,'paid','tracked',true,
  'test policy v1','working-days preview')::text,true);
SELECT public.leave_revise_type('cfa20000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,
  (current_setting('test.today')::date)+5,'paid','tracked','calendar_days',true,
  'test policy v2','calendar-days preview boundary');
SELECT set_config('test.working_type',public.leave_create_type('cfa20000-0000-4000-8000-000000000001','cfa50000-0000-4000-8000-000000000001',
  'request-working','Working Test',(current_setting('test.today')::date)-10,'paid','untracked',true,
  'test policy','working-days validation')::text,true);
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT ok((public.leave_my_request_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+2,(current_setting('test.today')::date)+8)->>'employee_id')='cfa40000-0000-4000-8000-000000000001',
  'own options resolve the current linked employee without profile permission');
SELECT throws_ok($$SELECT public.leave_my_request_options('cfa20000-0000-4000-8000-000000000002',
  current_date,current_date)$$,'42501','leave_self_forbidden','self options cannot cross tenants');
SELECT throws_ok($$SELECT public.leave_my_request_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+2,(current_setting('test.today')::date)+734)$$,
  '22023','leave_request_range_invalid','request option rejects a range beyond 732 calendar dates');
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+2,(current_setting('test.today')::date)+8,
  false,'first','invalid part test','bad-part-key')$$,
  '22023','leave_half_day_part_invalid','part is rejected on a full-day request');
SELECT set_config('test.own_request',(public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+2,(current_setting('test.today')::date)+8,
  false,NULL,'personal leave request','own-submit-001')->>'id'),true);
SELECT is((public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',current_setting('test.own_request')::uuid)->>'employee_code'),
  'REQ-SELF','own detail returns only the current employee request');
SELECT throws_ok(format($q$SELECT public.leave_request_detail('cfa20000-0000-4000-8000-000000000001','%s')$q$,
  'cfa40000-0000-4000-8000-000000000002'),'P0002','leave_request_unavailable','own detail cannot fetch another employee');
SELECT is((public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+2,(current_setting('test.today')::date)+8,
  false,NULL,'personal leave request','own-submit-001')->>'id'),current_setting('test.own_request'),
  'same actor and canonical payload replays the original request');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT set_config('test.halfday_submit',public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+3,(current_setting('test.today')::date)+3,
  true,'first','one half day with no Attendance entitlement','halfday-submit-001')::text,true);
SELECT is(current_setting('test.halfday_submit')::jsonb->>'half_day_part','first','leave-only submission preserves the employee original part without inferring a clock');
SELECT is((current_setting('test.halfday_submit')::jsonb->'days'->0->>'units')::numeric,0.5::numeric,'leave-only half-day remains one-half leave unit');
SELECT is(current_setting('test.halfday_submit')::jsonb->'days'->0->>'halfday_mapping_state','leave_only','Attendance-off submission creates no inferred clock mapping');
SELECT is((SELECT item->>'half_day_part' FROM jsonb_array_elements(public.leave_my_requests('cfa20000-0000-4000-8000-000000000001')->'items') AS q(item)
 WHERE item->>'id'=current_setting('test.halfday_submit')::jsonb->>'id'),'first','bounded own history summary exposes the original selected part');
SELECT is(public.leave_my_halfday_mapping_options('cfa20000-0000-4000-8000-000000000001',(current_setting('test.today')::date)+3)->>'state','leave_only','own mapping options disclose Leave-only mode without People permission');
SELECT set_config('test.halfday_refreshed',public.leave_my_refresh_halfday_preview('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.halfday_submit')::jsonb->>'id')::uuid,1,'second','confirm second portion','halfday-refresh-001')::text,true);
SELECT is(current_setting('test.halfday_refreshed')::jsonb->>'state','refreshed','explicit own refresh produces a new immutable preview');
SELECT is(current_setting('test.halfday_refreshed')::jsonb->'request'->>'half_day_part','first','refresh does not mutate the submitted header intent');
SELECT is(current_setting('test.halfday_refreshed')::jsonb->'request'->'days'->0->>'half_day_part','second','refined part is stored on the new preview day');
SELECT is(current_setting('test.halfday_refreshed')::jsonb->'request'->'days'->0->>'halfday_mapping_state','leave_only','refresh still creates no clock when Attendance is disabled');
SELECT is(public.leave_my_refresh_halfday_preview('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.halfday_submit')::jsonb->>'id')::uuid,1,'second','confirm second portion','halfday-refresh-001')::jsonb->>'state','refreshed','same key and same part replays the identical refresh');
SELECT throws_ok($$SELECT public.leave_my_refresh_halfday_preview('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.halfday_submit')::jsonb->>'id')::uuid,1,'first','change reviewed part','halfday-refresh-001')$$,
  '23505','leave_idempotency_conflict','same refresh key cannot replay with a changed reviewed part');
RESET ROLE;
SELECT is((SELECT half_day_part FROM leave.request_days WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
  AND request_id=(current_setting('test.halfday_submit')::jsonb->>'id')::uuid AND preview_version=1),'first','original preview part remains immutable');
SELECT is((SELECT halfday_mapping_state FROM leave.request_days WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
  AND request_id=(current_setting('test.halfday_submit')::jsonb->>'id')::uuid AND preview_version=1),'leave_only','old preview evidence is not rewritten');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('cfa20000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','cfa10000-0000-4000-8000-000000000002','halfday mapping integration test');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa80000-0000-4000-8000-000000000001',
 'cfa50000-0000-4000-8000-000000000001','Halfday test site',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000001','HALFDAY-FIXED',true,1),
       ('cfa20000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000002','HALFDAY-FLEX',true,1),
       ('cfa20000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000003','HALFDAY-LEGACY',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,
 shift_start,shift_end,ends_next_day,break_minutes,required_minutes,earliest_punch,latest_punch,
 attribution_before_minutes,attribution_after_minutes,created_by,overtime_enabled,overtime_minimum_minutes,
 overtime_rounding_minutes,auto_approve_clean,fixed_break_start,fixed_break_end,flexible_halfday_break_minutes)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000001',1,'Fixed halfday mapping','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],
 '09:00','17:00',false,60,NULL,NULL,NULL,120,360,'cfa10000-0000-4000-8000-000000000002',false,15,15,false,'13:00','14:00',NULL),
 ('cfa20000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000002',1,'Flexible halfday mapping','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],
 NULL,NULL,false,0,481,NULL,NULL,120,360,'cfa10000-0000-4000-8000-000000000002',false,15,15,false,NULL,NULL,30),
 ('cfa20000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000003',1,'Legacy fixed break','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],
 '09:00','17:00',false,60,NULL,NULL,NULL,120,360,'cfa10000-0000-4000-8000-000000000002',false,15,15,false,NULL,NULL,NULL);
INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from,valid_until)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa60000-0000-4000-8000-000000000001','cfa80000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000001',1,
 (current_setting('test.today')::date)+3,(current_setting('test.today')::date)+4),
 ('cfa20000-0000-4000-8000-000000000001','cfa60000-0000-4000-8000-000000000002','cfa80000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000002',1,
 (current_setting('test.today')::date)+12,(current_setting('test.today')::date)+13),
 ('cfa20000-0000-4000-8000-000000000001','cfa60000-0000-4000-8000-000000000002','cfa80000-0000-4000-8000-000000000001','cfa70000-0000-4000-8000-000000000003',1,
 (current_setting('test.today')::date)+13,(current_setting('test.today')::date)+14);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000003',true);
SELECT is(public.leave_approve_request('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.halfday_submit')::jsonb->>'id')::uuid,2,2,'check mapping after Attendance enablement','halfday-attendance-on-approval')->>'state',
  'refresh_required','Attendance enablement changes semantic preview and blocks stale approval');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT is(public.leave_my_halfday_mapping_options('cfa20000-0000-4000-8000-000000000001',(current_setting('test.today')::date)+3)->>'state',
 'mapped_options','fixed policy returns explicit first and second choices from its dated assignment');
SELECT set_config('test.halfday_mapped',public.leave_my_refresh_halfday_preview('cfa20000-0000-4000-8000-000000000001',
 (current_setting('test.halfday_submit')::jsonb->>'id')::uuid,2,'second','map fixed second portion','halfday-fixed-map-001')::text,true);
SELECT is(current_setting('test.halfday_mapped')::jsonb->'request'->'days'->0->>'halfday_mapping_state','mapped',
 'Attendance-on fixed refresh saves resolved mapping evidence');
SELECT is((current_setting('test.halfday_mapped')::jsonb->'request'->'days'->0->'halfday_mapping_snapshot'->'mapping'->>'split_local')::timestamp,
 ((current_setting('test.today')::date)+3)::timestamp+interval '12 hours 30 minutes','fixed Leave preview uses the net-work midpoint around the configured break');
SELECT is(current_setting('test.halfday_mapped')::jsonb->'request'->'days'->0->>'half_day_part','second',
 'effective preview records the reviewed second part');
SELECT is(public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.halfday_submit')::jsonb->>'id')::uuid)->'days'->0->>'halfday_mapping_state',
  'mapped','request detail selects the new current preview after explicit refresh');
RESET ROLE;
SELECT is((SELECT halfday_mapping_state FROM leave.request_days WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
 AND request_id=(current_setting('test.halfday_submit')::jsonb->>'id')::uuid AND preview_version=1),'leave_only',
 'original submission preview remains unchanged after Attendance mapping');
SELECT is((SELECT half_day_part FROM leave.request_days WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
 AND request_id=(current_setting('test.halfday_submit')::jsonb->>'id')::uuid AND preview_version=2),'second',
 'prior leave-only refined part remains immutable after a later mapping refresh');
SELECT is((SELECT halfday_mapping_state FROM leave.request_days WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
 AND request_id=(current_setting('test.halfday_submit')::jsonb->>'id')::uuid AND preview_version=2),'leave_only',
 'prior leave-only mapping evidence is not rewritten by the mapped refresh');
SELECT is((SELECT half_day_part FROM leave.requests WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
 AND id=(current_setting('test.halfday_submit')::jsonb->>'id')::uuid),'first',
 'original submitted part remains immutable after several preview versions');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT set_config('test.halfday_approval_target',public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.working_type')::uuid,(current_setting('test.today')::date)+3,(current_setting('test.today')::date)+3,
 true,'first','mapped half day approval test','halfday-approved-submit-001')::text,true);
SELECT is(current_setting('test.halfday_approval_target')::jsonb->'days'->0->>'halfday_mapping_state','mapped',
 'Attendance-on own submission snapshots fixed mapping before review');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000003',true);
SELECT is(public.leave_approve_request('cfa20000-0000-4000-8000-000000000001',
 (current_setting('test.halfday_approval_target')::jsonb->>'id')::uuid,1,1,'approve reviewed mapped half day','halfday-approved-001')->>'state',
 'approved','approval accepts current mapped half-day evidence when no Time fact conflicts');
RESET ROLE;
UPDATE people.employee_user_links SET employee_id='cfa40000-0000-4000-8000-000000000002'
WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND user_id='cfa10000-0000-4000-8000-000000000001'
  AND unlinked_at IS NULL;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+2,(current_setting('test.today')::date)+8,
  false,NULL,'personal leave request','own-submit-001')$$,
  '23505','leave_idempotency_conflict','relinking to another Employee cannot replay the former Employee request');
RESET ROLE;
UPDATE people.employee_user_links SET employee_id='cfa40000-0000-4000-8000-000000000001'
WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND user_id='cfa10000-0000-4000-8000-000000000001'
  AND unlinked_at IS NULL;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+3,(current_setting('test.today')::date)+8,
  false,NULL,'personal leave request','own-submit-001')$$,
  '23505','leave_idempotency_conflict','same idempotency key with a changed payload conflicts');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM leave.request_events WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
  AND request_id=current_setting('test.own_request')::uuid),1,'request replay writes exactly one event');
SELECT is((SELECT count(DISTINCT year_period_id)::integer FROM leave.request_days
  WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND request_id=current_setting('test.own_request')::uuid),2,
  'one request stores date lines across two configured account periods');
SELECT is((SELECT count(DISTINCT calendar_version_id)::integer FROM leave.request_days
  WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND request_id=current_setting('test.own_request')::uuid),2,
  'per-date preview pins both effective calendar versions');
SELECT is((SELECT count(DISTINCT type_version_id)::integer FROM leave.request_days
  WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND request_id=current_setting('test.own_request')::uuid),2,
  'per-date preview pins both effective type versions');
SELECT is((SELECT count(*)::integer FROM leave.accounts WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
  AND employee_id='cfa40000-0000-4000-8000-000000000001'),0,'pending submission requires no balance account');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'),0,
  'pending submission consumes no balance');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT is((public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',current_setting('test.own_request')::uuid)->>'state'),
  'submitted','submission never fakes approval');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(
  public.leave_my_requests('cfa20000-0000-4000-8000-000000000001')->'items') item
  WHERE item->>'id'=current_setting('test.own_request')),
  'own request list includes the current employee request without assuming UUID order on tied timestamps');
SELECT set_config('test.year_request',(public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+12,(current_setting('test.today')::date)+377,
  false,NULL,'one calendar year request','one-year-range')->>'id'),true);
SELECT is((public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',current_setting('test.year_request')::uuid)->>'total_units')::numeric,
  366::numeric,'an ordinary leap-year-length calendar-days request is accepted');
SELECT set_config('test.two_year_request',(public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+12,(current_setting('test.today')::date)+743,
  false,NULL,'two calendar years request','two-year-range')->>'id'),true);
SELECT is((public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',current_setting('test.two_year_request')::uuid)->>'total_units')::numeric,
  732::numeric,'the 732-date operational maximum spanning two leap-year lengths is accepted');
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+12,(current_setting('test.today')::date)+744,
  false,NULL,'three calendar years request','three-year-range')$$,
  '22023','leave_request_input_invalid','a three-year request exceeds the operational range');
SELECT ok((public.leave_my_requests('cfa20000-0000-4000-8000-000000000001',1,0)->>'has_more')::boolean,
  'own history first page detects additional requests');
SELECT is(jsonb_array_length(public.leave_my_requests('cfa20000-0000-4000-8000-000000000001',1,1)->'items'),1,
  'own history offset page returns the next request');
SELECT ok(NOT (public.leave_my_requests('cfa20000-0000-4000-8000-000000000001',1,99)->>'has_more')::boolean
  AND jsonb_array_length(public.leave_my_requests('cfa20000-0000-4000-8000-000000000001',1,99)->'items')=0,
  'own history reports a terminal page with no phantom has_more');

SELECT set_config('test.workday',((SELECT d::date FROM pg_catalog.generate_series(
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+30,interval '1 day') d
  WHERE extract(dow FROM d)::integer NOT IN (4,5) ORDER BY d LIMIT 1))::text,true);
SELECT set_config('test.restday',((SELECT d::date FROM pg_catalog.generate_series(
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+30,interval '1 day') d
  WHERE extract(dow FROM d)::integer=5 ORDER BY d LIMIT 1))::text,true);
SELECT is((public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,current_setting('test.workday')::date,current_setting('test.workday')::date,
  true,NULL,'half-day request','own-half-001')->>'total_units')::numeric,0.5::numeric,
  'permitted half-day records exactly one half balance unit');
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.working_type')::uuid,current_setting('test.restday')::date,current_setting('test.restday')::date,
  false,NULL,'rest day request','rest-zero')$$,'23514','leave_request_zero_days','working-day request with no eligible dates is rejected');
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.working_type')::uuid,current_setting('test.restday')::date,current_setting('test.restday')::date,
  true,NULL,'rest half day','rest-half')$$,'23514','leave_half_day_ineligible','working-day half-day on rest day is rejected');
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+2,(current_setting('test.today')::date)+8,
  true,NULL,'multi-date half','multi-half')$$,'22023','leave_request_range_invalid','half-day cannot span multiple dates');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+12,(current_setting('test.today')::date)+12,
  false,NULL,'missing link','missing-link')$$,'42501','leave_self_forbidden','same role without current link cannot submit');
SELECT throws_ok($$SELECT public.leave_my_request_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+12,(current_setting('test.today')::date)+12)$$,
  '42501','leave_self_forbidden','active role without a live link cannot read own options');
SELECT throws_ok($$SELECT public.leave_my_requests('cfa20000-0000-4000-8000-000000000001')$$,
  '42501','leave_self_forbidden','active role without a live link cannot read own history');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT is((public.leave_employee_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+11,'REQ-HR')->'items'->0->>'employee_code'),
  'REQ-HR','HR option search exposes minimal Employee and Employment scope');
SELECT is(jsonb_array_length(public.leave_employee_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+11,'REQ-',1,0)->'items'),1,
  'HR employee options page one is bounded to the requested limit');
SELECT is(jsonb_array_length(public.leave_employee_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+11,'REQ-',1,1)->'items'),1,
  'HR employee options offset page returns the next row');
SELECT ok(NOT (public.leave_employee_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+11,'REQ-',1,99)->>'has_more')::boolean
  AND jsonb_array_length(public.leave_employee_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+11,'REQ-',1,99)->'items')=0,
  'HR employee options report a terminal page with no phantom has_more');
SELECT throws_ok($$SELECT public.leave_employee_options('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.today')::date)+10,(current_setting('test.today')::date)+11,'x')$$,
  '22023','leave_employee_options_input_invalid','HR options require a bounded search string');
SELECT set_config('test.hr_request',(public.leave_record_hr_request('cfa20000-0000-4000-8000-000000000001',
  'cfa40000-0000-4000-8000-000000000002','cfa60000-0000-4000-8000-000000000002',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+10,(current_setting('test.today')::date)+11,
  false,NULL,'HR records for accountless employee','hr-submit-001')->>'id'),true);
SELECT is((public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',current_setting('test.hr_request')::uuid)->>'request_source'),
  'hr','HR record and submission happen as one audited action');
SELECT set_config('test.hr_halfday',public.leave_record_hr_request('cfa20000-0000-4000-8000-000000000001',
  'cfa40000-0000-4000-8000-000000000002','cfa60000-0000-4000-8000-000000000002',current_setting('test.type')::uuid,
  (current_setting('test.today')::date)+12,(current_setting('test.today')::date)+12,true,NULL,
  'HR records an accountless employee half day','hr-halfday-submit-001')::text,true);
SELECT ok(current_setting('test.hr_halfday')::jsonb->>'half_day_part' IS NULL,'flexible schedule has no original AM/PM part');
SELECT is(current_setting('test.hr_halfday')::jsonb->'days'->0->>'halfday_mapping_state','mapped','HR half-day submission attaches flexible policy evidence');
SELECT is(public.leave_hr_halfday_mapping_options('cfa20000-0000-4000-8000-000000000001','cfa60000-0000-4000-8000-000000000002',(current_setting('test.today')::date)+12)->>'state',
  'mapped_options','HR options expose flexible mode without AM/PM choices');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000003',true);
SELECT set_config('test.hr_halfday_refined',public.leave_hr_refresh_halfday_preview('cfa20000-0000-4000-8000-000000000001',
  (current_setting('test.hr_halfday')::jsonb->>'id')::uuid,1,NULL,'review flexible mapping','hr-halfday-refresh-001')::text,true);
SELECT is(current_setting('test.hr_halfday_refined')::jsonb->>'state','refreshed','HR approver explicitly refines the reviewed per-preview part');
SELECT ok(current_setting('test.hr_halfday_refined')::jsonb->'request'->>'half_day_part' IS NULL,'flexible HR request has no selected clock part');
SELECT is(current_setting('test.hr_halfday_refined')::jsonb->'request'->'days'->0->>'halfday_mapping_state','mapped','flexible HR refresh remains mapped with explicit net threshold');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT set_config('test.hr_legacy_halfday',public.leave_record_hr_request('cfa20000-0000-4000-8000-000000000001',
 'cfa40000-0000-4000-8000-000000000002','cfa60000-0000-4000-8000-000000000002',current_setting('test.type')::uuid,
 (current_setting('test.today')::date)+13,(current_setting('test.today')::date)+13,true,'first',
 'legacy aggregate break needs review','hr-halfday-legacy-001')::text,true);
SELECT is(current_setting('test.hr_legacy_halfday')::jsonb->'days'->0->>'halfday_mapping_state','review_required',
 'legacy positive aggregate break does not receive an inferred fixed clock');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000003',true);
SELECT set_config('test.hr_legacy_refined',public.leave_hr_refresh_halfday_preview('cfa20000-0000-4000-8000-000000000001',
 (current_setting('test.hr_legacy_halfday')::jsonb->>'id')::uuid,1,'first','review legacy fixed policy','hr-halfday-legacy-refresh-001')::text,true);
SELECT is(current_setting('test.hr_legacy_refined')::jsonb->'request'->'days'->0->>'halfday_mapping_state','review_required',
 'explicit refresh retains review-required for legacy fixed break provenance');
SELECT throws_ok($$SELECT public.leave_approve_request('cfa20000-0000-4000-8000-000000000001',
 (current_setting('test.hr_legacy_halfday')::jsonb->>'id')::uuid,2,2,'cannot approve unmapped legacy break','hr-halfday-legacy-approve')$$,
 '23514','leave_half_day_mapping_required','approval refuses an unmapped Attendance-on half day');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT ok((public.leave_hr_queue('cfa20000-0000-4000-8000-000000000001',1,0)->>'has_more')::boolean,
  'HR queue first page detects additional submitted requests');
SELECT is(jsonb_array_length(public.leave_hr_queue('cfa20000-0000-4000-8000-000000000001',1,1)->'items'),1,
  'HR queue offset page returns the next request');
SELECT ok((public.leave_hr_queue('cfa20000-0000-4000-8000-000000000001',1,0)->'items'->0->>'id') IS DISTINCT FROM
  (public.leave_hr_queue('cfa20000-0000-4000-8000-000000000001',1,1)->'items'->0->>'id'),
  'HR queue offset page advances to a different request');
SELECT ok(NOT (public.leave_hr_queue('cfa20000-0000-4000-8000-000000000001',1,99)->>'has_more')::boolean
  AND jsonb_array_length(public.leave_hr_queue('cfa20000-0000-4000-8000-000000000001',1,99)->'items')=0,
  'HR queue reports a terminal page with no phantom has_more');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM leave.request_events WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
  AND request_id=current_setting('test.hr_request')::uuid AND event_key='hr.recorded_submitted'),1,
  'HR record submission creates one event rather than a mandatory draft step');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT ok(EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(
  public.leave_hr_queue('cfa20000-0000-4000-8000-000000000001')->'items') item
  WHERE item->>'id'=current_setting('test.own_request')),
  'authorized HR sees the employee request among submitted queue items');
SELECT throws_ok(format($q$SELECT public.leave_reject_request('cfa20000-0000-4000-8000-000000000001','%s',1,'unauthorized reject','hr-reject-denied')$q$,
  current_setting('test.hr_request')),'42501','leave_forbidden','record permission does not imply approval');
RESET ROLE;

DELETE FROM platform_core.membership_roles WHERE tenant_id='cfa20000-0000-4000-8000-000000000001'
  AND user_id='cfa10000-0000-4000-8000-000000000003' AND role_id='cfa30000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.leave_record_hr_request('cfa20000-0000-4000-8000-000000000001',
  'cfa40000-0000-4000-8000-000000000002','cfa60000-0000-4000-8000-000000000002',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+12,(current_setting('test.today')::date)+12,
  false,NULL,'no approver configured','no-approver')$$,'23514','leave_approval_queue_unavailable','ownerless queue is rejected');
RESET ROLE;
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000003','cfa30000-0000-4000-8000-000000000003');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000003',true);
SELECT is((public.leave_reject_request('cfa20000-0000-4000-8000-000000000001',current_setting('test.hr_request')::uuid,
  1,'not approved by HR','reject-001')->>'state'),'rejected','separate approver can reject with CAS');
SELECT is((public.leave_reject_request('cfa20000-0000-4000-8000-000000000001',current_setting('test.hr_request')::uuid,
  1,'not approved by HR','reject-001')->>'state'),'rejected','same rejection operation replays after state change');
SELECT throws_ok($$SELECT public.leave_reject_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.hr_request')::uuid,1,'changed reason','reject-001')$$,
  '23505','leave_idempotency_conflict','changed rejection payload conflicts under same key');
SELECT throws_ok($$SELECT public.leave_reject_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.hr_request')::uuid,1,'stale decision','reject-stale')$$,
  '23514','leave_request_not_rejectable','rejection cannot repeat under a fresh key');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_withdraw_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.own_request')::uuid,2,'wrong version','withdraw-stale')$$,
  '40001','leave_request_version_conflict','withdrawal checks expected version');
SELECT is((public.leave_withdraw_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.own_request')::uuid,1,'employee withdrew','withdraw-001')->>'state'),
  'withdrawn','employee can withdraw a submitted request');
SELECT is((public.leave_withdraw_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.own_request')::uuid,1,'employee withdrew','withdraw-001')->>'state'),
  'withdrawn','withdraw retry replays its original result');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT is((public.leave_set_type_active('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,false,'retire type','deactivate-type-001')->>'is_active')::boolean,
  false,'authorized manager can deactivate a leave type with an audit reason');
SELECT is((SELECT (t.item->>'is_active')::boolean FROM pg_catalog.jsonb_array_elements(
  public.leave_configuration_snapshot('cfa20000-0000-4000-8000-000000000001',
    'cfa50000-0000-4000-8000-000000000001')->'types') t(item)
  WHERE t.item->>'id'=current_setting('test.type')),false,'configuration snapshot exposes inactive type status');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_submit_own_request('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,(current_setting('test.today')::date)+12,(current_setting('test.today')::date)+12,
  false,NULL,'inactive type denied','inactive-type')$$,'23503','leave_type_unavailable',
  'inactive types cannot receive new requests');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000002',true);
SELECT is((public.leave_set_type_active('cfa20000-0000-4000-8000-000000000001',
  current_setting('test.type')::uuid,true,'restore type','activate-type-001')->>'is_active')::boolean,
  true,'authorized manager can reactivate a leave type');
RESET ROLE;

UPDATE platform_core.tenant_capability_entitlements SET valid_until=pg_catalog.now()
WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND capability_key='hr.leave' AND valid_until IS NULL;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT ok(EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements(public.leave_my_requests(
  'cfa20000-0000-4000-8000-000000000001')->'items') item
  WHERE item->>'id'=current_setting('test.own_request') AND item->>'state'='withdrawn'),
  'own historical request list retains the withdrawn request after Leave entitlement ends');
SELECT is((public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',current_setting('test.own_request')::uuid)->>'state'),
  'withdrawn','scoped detail remains available after disable');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.leave_my_requests(
 'cfa20000-0000-4000-8000-000000000001')->'items') item WHERE item ? 'days'),
 'own history carries summaries without hydrating daily policy evidence');
SELECT ok(jsonb_array_length(public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.two_year_request')::uuid)->'days')=732,
 'scoped detail retains the complete 732-date breakdown independently of list summaries');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.leave_my_requests(
 'cfa20000-0000-4000-8000-000000000001')->'items') item WHERE octet_length(item::text)>4096),
 'history item payload stays bounded even for long leave requests');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000003',true);
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.leave_hr_queue(
 'cfa20000-0000-4000-8000-000000000001')->'items') item WHERE item ? 'days'),
 'HR review queue carries summaries without daily evidence hydration');
RESET ROLE;
SELECT ok(has_function_privilege('authenticated','public.leave_my_request_detail(uuid,uuid)','EXECUTE'),
 'own-only detail is available to authenticated callers');
SELECT ok(NOT has_function_privilege('anon','public.leave_my_request_detail(uuid,uuid)','EXECUTE'),
 'anonymous callers cannot read own-only detail');
SELECT ok(NOT has_function_privilege('service_role','public.leave_my_request_detail(uuid,uuid)','EXECUTE'),
 'service role cannot bypass own-only detail authority');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000001','cfa30000-0000-4000-8000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_my_halfday_mapping_options('cfa20000-0000-4000-8000-000000000001',
 (current_setting('test.today')::date)+3)$$,'55000','leave_new_work_disabled',
 'own mapping options remain disabled for a linked actor who also has an HR role');
SELECT is(public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.own_request')::uuid)->>'state','withdrawn','own-only detail retains historical access with Leave disabled');
SELECT throws_ok($$SELECT public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.hr_request')::uuid)$$,'P0002','leave_request_unavailable',
 'own-only detail rejects another employee even when the same actor also has HR visibility');
SELECT is(public.leave_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.hr_request')::uuid)->>'request_source','hr','separate HR detail retains its authorized broader scope');
SELECT throws_ok($$SELECT public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000002',
 current_setting('test.own_request')::uuid)$$,'P0002','leave_request_unavailable','own detail rejects tenant identifier tampering');
RESET ROLE;
UPDATE people.employee_user_links SET unlinked_at=now(),unlinked_by_user_id='cfa10000-0000-4000-8000-000000000002'
 WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND user_id='cfa10000-0000-4000-8000-000000000001' AND unlinked_at IS NULL;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.own_request')::uuid)$$,'P0002','leave_request_unavailable','unlink revokes own detail despite retained HR permission');
RESET ROLE;
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('cfa20000-0000-4000-8000-000000000001','cfa40000-0000-4000-8000-000000000002',
 'cfa10000-0000-4000-8000-000000000001','cfa10000-0000-4000-8000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.own_request')::uuid)$$,'P0002','leave_request_unavailable','relink to another employee does not restore old own identity');
SELECT throws_ok($$SELECT public.leave_my_refresh_halfday_preview('cfa20000-0000-4000-8000-000000000001',
 (current_setting('test.halfday_submit')::jsonb->>'id')::uuid,1,'second','try old linked employee','halfday-relink-denied')$$,
 'P0002','leave_request_unavailable','own refined refresh follows the current link after relinking');
SELECT is(public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.hr_request')::uuid)->>'employee_id','cfa40000-0000-4000-8000-000000000002',
 'relinked account reads only the currently linked employee request');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='inactive'
 WHERE tenant_id='cfa20000-0000-4000-8000-000000000001' AND user_id='cfa10000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfa10000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.leave_my_request_detail('cfa20000-0000-4000-8000-000000000001',
 current_setting('test.hr_request')::uuid)$$,'P0002','leave_request_unavailable','inactive membership removes current own detail access');
RESET ROLE;
SELECT is(time.leave_halfday_mapping(jsonb_build_object(
  'policy_template_id','cfa70000-0000-4000-8000-000000000001','policy_version',1,'schedule_kind','fixed',
  'timezone_name','Africa/Cairo','shift_start','09:00','shift_end','17:00','ends_next_day',false,
  'break_minutes',60,'fixed_break_start','13:00','fixed_break_end','14:00','required_minutes',420),
  (current_setting('test.today')::date)+4,'first')->>'state','mapped','fixed explicit first part maps');
SELECT is((time.leave_halfday_mapping(jsonb_build_object(
  'policy_template_id','cfa70000-0000-4000-8000-000000000001','policy_version',1,'schedule_kind','fixed',
  'timezone_name','Africa/Cairo','shift_start','09:00','shift_end','17:00','ends_next_day',false,
  'break_minutes',60,'fixed_break_start','13:00','fixed_break_end','14:00','required_minutes',420),
  (current_setting('test.today')::date)+4,'first')->>'split_local')::timestamp,
  ((current_setting('test.today')::date)+4)::timestamp+interval '12 hours 30 minutes','fixed net 420-minute shift splits at 12:30 around the break');
SELECT is(jsonb_array_length(time.leave_halfday_mapping(jsonb_build_object(
  'policy_template_id','cfa70000-0000-4000-8000-000000000001','policy_version',1,'schedule_kind','fixed',
  'timezone_name','Africa/Cairo','shift_start','09:00','shift_end','17:00','ends_next_day',false,
  'break_minutes',60,'fixed_break_start','13:00','fixed_break_end','14:00','required_minutes',420),
  (current_setting('test.today')::date)+4,'second')->'excused_intervals'),2,'second part retains the pre-break remainder and post-break work as mapped intervals');
SELECT is(time.leave_halfday_mapping(jsonb_build_object(
  'policy_template_id','cfa70000-0000-4000-8000-000000000002','policy_version',3,'schedule_kind','flexible',
  'timezone_name','Africa/Cairo','required_minutes',481,'flexible_halfday_break_minutes',30),
  (current_setting('test.today')::date)+4,NULL)->>'remaining_net_threshold_minutes','241','flexible threshold is ceil(required/2) with explicit configured halfday break');
SELECT is(time.leave_halfday_mapping(jsonb_build_object(
  'policy_template_id','cfa70000-0000-4000-8000-000000000002','policy_version',3,'schedule_kind','flexible',
  'timezone_name','Africa/Cairo','required_minutes',481,'flexible_halfday_break_minutes',30),
  (current_setting('test.today')::date)+4,'first')->>'state','review_required','flexible policy has no AM/PM part');
SELECT is(time.leave_halfday_mapping(jsonb_build_object(
  'policy_template_id',NULL,'policy_version',NULL,'schedule_kind','flexible','timezone_name','Africa/Cairo',
  'required_minutes',481,'flexible_halfday_break_minutes',30),
  (current_setting('test.today')::date)+4,NULL)->>'reason','policy_identity_missing',
 'JSON-null policy identity cannot produce approval-ready half-day evidence');
SELECT is(time.leave_halfday_mapping(jsonb_build_object(
  'policy_template_id','cfa70000-0000-4000-8000-000000000003','policy_version',1,'schedule_kind','fixed',
  'timezone_name','Africa/Cairo','shift_start','09:00','shift_end','17:00','ends_next_day',false,
  'break_minutes',60,'required_minutes',420),
  (current_setting('test.today')::date)+4,'first')->>'reason','fixed_break_placement_unknown','legacy aggregate break is not mapped to a guessed clock');
SELECT * FROM finish();
ROLLBACK;
