BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('ed110000-0000-4000-8000-000000000001','auto-approve-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('ed120000-0000-4000-8000-000000000001','Clean auto approval test','ed110000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('ed120000-0000-4000-8000-000000000001','ed130000-0000-4000-8000-000000000001','attendance.auto.operator',1,ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance.correct','attendance.approve','attendance_policy.manage'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('ed120000-0000-4000-8000-000000000001','ed110000-0000-4000-8000-000000000001','active','ed110000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('ed120000-0000-4000-8000-000000000001','ed110000-0000-4000-8000-000000000001','ed130000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('ed120000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','ed110000-0000-4000-8000-000000000001','auto approval test'),
       ('ed120000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','ed110000-0000-4000-8000-000000000001','auto approval test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('ed120000-0000-4000-8000-000000000001','ed140000-0000-4000-8000-000000000001','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('ed120000-0000-4000-8000-000000000001','ed150000-0000-4000-8000-000000000001','ed140000-0000-4000-8000-000000000001','Main site',true,true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
-- Keep punches in the past even just after midnight; this overnight fixture's attribution window still remains open.
SELECT set_config('test.today',(timezone('Africa/Cairo',now())::date-1)::text,true);
SELECT set_config('test.employee_auto',public.create_people_employee('ed120000-0000-4000-8000-000000000001','AUTO-1','موظف اعتماد تلقائي','ed140000-0000-4000-8000-000000000001','ed150000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-10,'monthly',1000,true)::text,true);
SELECT set_config('test.employment_auto',(current_setting('test.employee_auto')::jsonb->>'employment_id'),true);
SELECT set_config('test.policy_auto',(public.save_time_work_policy('ed120000-0000-4000-8000-000000000001',NULL,'AUTO','دوام اعتماد تلقائي','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'00:00','23:59',true,0,NULL,NULL,NULL,0,720,false,30,15,true)->>'id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.policy_auto')::uuid,work_policy_version=1 WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_auto')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open_auto',public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)::text,true);
SELECT set_config('test.instance_auto',(current_setting('test.open_auto')::jsonb->'items'->0->>'id'),true);
SELECT is((public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid)->'instance'->>'auto_approve_clean')::boolean,true,'new Work Instance freezes enabled policy setting');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid,'in',(current_setting('test.today')||' 00:01')::timestamp,'ed160000-0000-4000-8000-000000000001','دخول الوردية')$$,'eligible evidence is accepted while the configured window is open');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid,'out',(current_setting('test.today')||' 00:02')::timestamp,'ed160000-0000-4000-8000-000000000002','خروج الوردية')$$,'clean complete pair becomes ready');
SELECT is((public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid)->'interpretation'->>'exception_code'),NULL,'eligible interpretation has no exception');
SELECT is((SELECT item->>'status' FROM jsonb_array_elements(public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)->'items') item WHERE item->>'employee_code'='AUTO-1'),'ready','opening before the attribution deadline leaves a clean day awaiting close');
SELECT is(jsonb_array_length(public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid)->'facts'),0,'no fact is written before the attribution window closes');
RESET ROLE;
UPDATE time.work_instances SET attribution_end=now()-interval '1 second' WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND id=current_setting('test.instance_auto')::uuid;
SELECT time.interpret_work_instance('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid,'ed110000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT is((SELECT item->>'status' FROM jsonb_array_elements(public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)->'items') item WHERE item->>'employee_code'='AUTO-1'),'approved','bounded reopen after attribution end auto-approves the clean interpretation');
SELECT is(jsonb_array_length(public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid)->'facts'),1,'eligible clean instance creates exactly one immutable fact');
SELECT is((public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid)->'facts'->0->>'actor_user_id'),'ed110000-0000-4000-8000-000000000001','automatic approval fact retains the authorized actor');

-- Any late evidence creates a review version; the prior approved fact is never silently replaced or auto-approved again.
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid,'in',(current_setting('test.today')||' 00:03')::timestamp,'ed160000-0000-4000-8000-000000000003','تسجيل وصل بعد الاعتماد')$$,'late evidence routes the approved day back to review');
SELECT is((public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)->'items'->0->>'status'),'needs_review','late evidence remains reviewable instead of being auto-approved');
SELECT is(jsonb_array_length(public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_auto')::uuid)->'facts'),1,'auto approval never adds a fact over prior approved history');

-- The 19-argument compatibility RPC keeps the opt-in disabled.
SELECT set_config('test.employee_off',public.create_people_employee('ed120000-0000-4000-8000-000000000001','AUTO-OFF','موظف دون اعتماد تلقائي','ed140000-0000-4000-8000-000000000001','ed150000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-10,'monthly',1000,true)::text,true);
SELECT set_config('test.employment_off',(current_setting('test.employee_off')::jsonb->>'employment_id'),true);
SELECT set_config('test.policy_off',(public.save_time_work_policy('ed120000-0000-4000-8000-000000000001',NULL,'OFF','دوام عادي','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'00:00','23:59',true,0,NULL,NULL,NULL,0,720,false,30,15)->>'id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.policy_off')::uuid,work_policy_version=1 WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_off')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open_off',public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)::text,true);
SELECT set_config('test.instance_off',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open_off')::jsonb->'items') item WHERE item->>'employee_code'='AUTO-OFF'),true);
SELECT is((public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_off')::uuid)->'instance'->>'auto_approve_clean')::boolean,false,'compatibility RPC and default keep auto approval disabled');
RESET ROLE;
UPDATE time.work_instances SET attribution_end=now()-interval '1 second' WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND id=current_setting('test.instance_off')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_off')::uuid,'in',(current_setting('test.today')||' 00:01')::timestamp,'ed160000-0000-4000-8000-000000000004','دخول الوردية')$$,'disabled-policy event accepted');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_off')::uuid,'out',(current_setting('test.today')||' 00:02')::timestamp,'ed160000-0000-4000-8000-000000000005','خروج الوردية')$$,'disabled-policy pair becomes ready');
SELECT is((SELECT item->>'status' FROM jsonb_array_elements(public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)->'items') item WHERE item->>'employee_code'='AUTO-OFF'),'ready','disabled flag never auto-approves a clean instance');
SELECT is(jsonb_array_length(public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_off')::uuid)->'facts'),0,'disabled flag creates no fact');

-- A Work Instance opened on a prior policy version keeps that version's disabled setting after a new policy version opts in.
SELECT set_config('test.employee_old',public.create_people_employee('ed120000-0000-4000-8000-000000000001','AUTO-OLD','موظف إصدار سابق','ed140000-0000-4000-8000-000000000001','ed150000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-10,'monthly',1000,true)::text,true);
SELECT set_config('test.employment_old',(current_setting('test.employee_old')::jsonb->>'employment_id'),true);
SELECT set_config('test.policy_old',(public.save_time_work_policy('ed120000-0000-4000-8000-000000000001',NULL,'OLD','قالب إصدار سابق','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'00:00','23:59',true,0,NULL,NULL,NULL,0,720,false,30,15,false)->>'id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.policy_old')::uuid,work_policy_version=1 WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_old')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open_old',public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)::text,true);
SELECT set_config('test.instance_old',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open_old')::jsonb->'items') item WHERE item->>'employee_code'='AUTO-OLD'),true);
SELECT public.save_time_work_policy('ed120000-0000-4000-8000-000000000001',current_setting('test.policy_old')::uuid,'OLD','قالب إصدار جديد','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'00:00','23:59',true,0,NULL,NULL,NULL,0,720,false,30,15,true);
SELECT is((public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_old')::uuid)->'instance'->>'auto_approve_clean')::boolean,false,'new policy opt-in does not rewrite a Work Instance snapshot');
RESET ROLE;
UPDATE time.work_instances SET attribution_end=now()-interval '1 second' WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND id=current_setting('test.instance_old')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_old')::uuid,'in',(current_setting('test.today')||' 00:01')::timestamp,'ed160000-0000-4000-8000-000000000006','دخول الوردية')$$,'old-version evidence accepted');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_old')::uuid,'out',(current_setting('test.today')||' 00:02')::timestamp,'ed160000-0000-4000-8000-000000000007','خروج الوردية')$$,'old-version pair becomes ready');
SELECT is((SELECT item->>'status' FROM jsonb_array_elements(public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)->'items') item WHERE item->>'employee_code'='AUTO-OLD'),'ready','old policy snapshot remains manual review after a later opt-in');

-- Missing attendance and a short flexible day remain exceptions even when the frozen policy opts in.
SELECT set_config('test.employee_miss',public.create_people_employee('ed120000-0000-4000-8000-000000000001','AUTO-MISS','موظف بلا تسجيل','ed140000-0000-4000-8000-000000000001','ed150000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-10,'monthly',1000,true)::text,true);
SELECT set_config('test.employment_miss',(current_setting('test.employee_miss')::jsonb->>'employment_id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.policy_auto')::uuid,work_policy_version=1 WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_miss')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open_miss',public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)::text,true);
SELECT set_config('test.instance_miss',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open_miss')::jsonb->'items') item WHERE item->>'employee_code'='AUTO-MISS'),true);
RESET ROLE;
UPDATE time.work_instances SET attribution_end=now()-interval '1 second' WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND id=current_setting('test.instance_miss')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT is((SELECT item->>'status' FROM jsonb_array_elements(public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)->'items') item WHERE item->>'employee_code'='AUTO-MISS'),'needs_review','a full absence remains in review');
SELECT is((public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_miss')::uuid)->'interpretation'->>'exception_code'),'absence_candidate','absence exception blocks auto approval');
SELECT is(jsonb_array_length(public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_miss')::uuid)->'facts'),0,'absence creates no automatic fact');

SELECT set_config('test.employee_short',public.create_people_employee('ed120000-0000-4000-8000-000000000001','AUTO-SHORT','موظف مدة قصيرة','ed140000-0000-4000-8000-000000000001','ed150000-0000-4000-8000-000000000001',timezone('Africa/Cairo',now())::date-10,'monthly',1000,true)::text,true);
SELECT set_config('test.employment_short',(current_setting('test.employee_short')::jsonb->>'employment_id'),true);
SELECT set_config('test.policy_short',(public.save_time_work_policy('ed120000-0000-4000-8000-000000000001',NULL,'SHORT','ساعات مرنة تلقائية','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],NULL,NULL,false,0,480,'00:00','23:59',0,720,false,30,15,true)->>'id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id=current_setting('test.policy_short')::uuid,work_policy_version=1 WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND employment_id=current_setting('test.employment_short')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT set_config('test.open_short',public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)::text,true);
SELECT set_config('test.instance_short',(SELECT item->>'id' FROM jsonb_array_elements(current_setting('test.open_short')::jsonb->'items') item WHERE item->>'employee_code'='AUTO-SHORT'),true);
RESET ROLE;
UPDATE time.work_instances SET attribution_end=now()-interval '1 second' WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND id=current_setting('test.instance_short')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ed110000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_short')::uuid,'in',(current_setting('test.today')||' 00:01')::timestamp,'ed160000-0000-4000-8000-000000000008','دخول مرن')$$,'flexible evidence is accepted');
SELECT lives_ok($$SELECT public.record_manual_attendance_punch_local('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_short')::uuid,'out',(current_setting('test.today')||' 01:01')::timestamp,'ed160000-0000-4000-8000-000000000009','خروج مرن')$$,'short flexible duration is interpreted');
SELECT is((public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_short')::uuid)->'interpretation'->>'exception_code'),'short_workday','short duration remains an explicit exception');
SELECT is((SELECT item->>'status' FROM jsonb_array_elements(public.attendance_open_day('ed120000-0000-4000-8000-000000000001',current_setting('test.today')::date,NULL,50)->'items') item WHERE item->>'employee_code'='AUTO-SHORT'),'ready','short exception is ready for manual review, not auto approval');
SELECT is(jsonb_array_length(public.attendance_instance_detail('ed120000-0000-4000-8000-000000000001',current_setting('test.instance_short')::uuid)->'facts'),0,'short exception creates no automatic fact');

SELECT throws_ok($$SELECT public.attendance_open_day('ed990000-0000-4000-8000-000000000099',current_setting('test.today')::date,NULL,50)$$,'42501','attendance_manage_forbidden','cross-tenant caller cannot trigger approval or expose another tenant');
RESET ROLE;
SELECT is((SELECT details->>'mode' FROM time.attendance_audit_events WHERE tenant_id='ed120000-0000-4000-8000-000000000001' AND event_key='attendance.fact.auto_approved' LIMIT 1),'auto_approve_clean','append-only approval audit records the explicit policy mode');
SELECT * FROM finish();
ROLLBACK;
