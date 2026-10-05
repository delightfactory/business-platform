BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e9100000-0000-4000-8000-000000000101','csv-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e9100000-0000-4000-8000-000000000102','csv-reader@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access) VALUES ('e9100000-0000-4000-8000-000000000101',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES ('e9110000-0000-4000-8000-000000000101','Attendance import test','e9100000-0000-4000-8000-000000000101');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9120000-0000-4000-8000-000000000101','attendance.import.operator',1,ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance_policy.manage'],'false'),
 ('e9110000-0000-4000-8000-000000000101','e9120000-0000-4000-8000-000000000102','attendance.import.reader',1,ARRAY['attendance.view'],'false');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000101','active','e9100000-0000-4000-8000-000000000101'),
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000102','active','e9100000-0000-4000-8000-000000000101');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000101','e9120000-0000-4000-8000-000000000101'),
 ('e9110000-0000-4000-8000-000000000101','e9100000-0000-4000-8000-000000000102','e9120000-0000-4000-8000-000000000102');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('e9110000-0000-4000-8000-000000000101','hr.people',true,now()-interval '1 minute','e9100000-0000-4000-8000-000000000101','attendance import test'),
 ('e9110000-0000-4000-8000-000000000101','hr.attendance',true,now()-interval '1 minute','e9100000-0000-4000-8000-000000000101','attendance import test');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('e9110000-0000-4000-8000-000000000101','e9130000-0000-4000-8000-000000000101','Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000101','e9130000-0000-4000-8000-000000000101','Main',true,true),
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000102','e9130000-0000-4000-8000-000000000101','Ambiguous',false,true),
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000103','e9130000-0000-4000-8000-000000000101','Ambiguous',false,true),
 ('e9110000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000104','e9130000-0000-4000-8000-000000000101','Other',false,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES
 ('e9110000-0000-4000-8000-000000000101','e9150000-0000-4000-8000-000000000101','FLEX',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by)
VALUES ('e9110000-0000-4000-8000-000000000101','e9150000-0000-4000-8000-000000000101',1,'يوم مرن','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59','e9100000-0000-4000-8000-000000000101');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.employee',public.create_people_employee('e9110000-0000-4000-8000-000000000101','CSV-1','موظف الاستيراد','e9130000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000101',(now() AT TIME ZONE 'Africa/Cairo')::date-3,'monthly',1000,true)::text,true);
SELECT set_config('test.employment',(current_setting('test.employee')::jsonb->>'employment_id'),true);
SELECT set_config('test.unassigned_employee',public.create_people_employee('e9110000-0000-4000-8000-000000000101','CSV-2','موظف بلا سياسة','e9130000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000101',(now() AT TIME ZONE 'Africa/Cairo')::date-3,'monthly',1000,true)::text,true);
SELECT set_config('test.unassigned_employment',(current_setting('test.unassigned_employee')::jsonb->>'employment_id'),true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='e9150000-0000-4000-8000-000000000101',work_policy_version=1
 WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND employment_id=current_setting('test.employment')::uuid;
SELECT set_config('test.event_in',(to_char((((((now() AT TIME ZONE 'Africa/Cairo')::date-1)::timestamp+'10:00'::time) AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'UTC'),'YYYY-MM-DD"T"HH24:MI:SS')||'+00:00'),true);
SELECT set_config('test.event_out',(to_char((((((now() AT TIME ZONE 'Africa/Cairo')::date-1)::timestamp+'18:00'::time) AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'UTC'),'YYYY-MM-DD"T"HH24:MI:SS')||'+00:00'),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.preview',public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('source_line_hint',2,'employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','device-001')))::text,true);
SELECT is(current_setting('test.preview')::jsonb->0->>'status','ready','valid mapped event is ready in preview');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.work_instances WHERE tenant_id='e9110000-0000-4000-8000-000000000101'),0,'preview does not materialize a Work Instance');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT is(public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('source_line_hint',3,'employee_code','CSV-1','site_name','Main','happened_at','not-a-timestamp','direction','in','source_event_key','bad-time')))->0->>'status','rejected','malformed timestamp is rejected with a row result');
SELECT is(public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Ambiguous','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','amb-site')))->0->>'status','rejected','ambiguous duplicate site names are rejected rather than choosing one');
SELECT is(public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Other','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','wrong-site')))->0->>'status','unassigned','known same-Tenant employee and Site without a matching Assignment are retained for review');
SELECT throws_ok($$SELECT public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000199','[]'::jsonb)$$,'42501','attendance_import_forbidden','cross-tenant preview is denied');
SELECT set_config('test.confirm',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('source_line_hint',2,'employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','device-001'),
 jsonb_build_object('source_line_hint',3,'employee_code','NO-SUCH-EMPLOYEE','site_name','Main','happened_at',current_setting('test.event_in'),'direction','out','source_event_key','device-bad'))::jsonb)::text,true);
SELECT is((current_setting('test.confirm')::jsonb->>'accepted_count')::int,1,'mixed batch imports the valid row');
SELECT is((current_setting('test.confirm')::jsonb->>'rejected_count')::int,1,'mixed batch reports the invalid row without rolling back the valid row');
SELECT is(current_setting('test.confirm')::jsonb->'rows'->1->>'status','rejected','row error is visible in partial result');
SELECT is(public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','in','source_event_key','device-001')))->>'duplicate_count','1','same source event reimport is idempotently classified as duplicate');
SELECT is(public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_in'),'direction','out','source_event_key','device-001')))->>'rejected_count','1','same source key with conflicting payload is rejected');
SELECT set_config('test.instance',(current_setting('test.confirm')::jsonb->'rows'->0->>'instance_id'),true);
SELECT set_config('test.partial',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('source_line_hint',4,'employee_code','CSV-1','site_name','Main','happened_at',current_setting('test.event_out'),'direction','out','source_event_key','device-002'),
 jsonb_build_object('source_line_hint',5,'employee_code','NO-SUCH-EMPLOYEE','site_name','Main','happened_at',current_setting('test.event_out'),'direction','in','source_event_key','device-003'))::jsonb)::text,true);
SELECT is((current_setting('test.partial')::jsonb->>'accepted_count')::int,1,'second valid event is accepted independently');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000101',current_setting('test.instance')::uuid)->'interpretation'->>'state'),'ready','imported events use the existing Work Instance interpreter');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000101',current_setting('test.instance')::uuid)->'punches'->0->>'source_type'),'import','attendance detail preserves imported-versus-manual event source');
SELECT is((public.attendance_instance_detail('e9110000-0000-4000-8000-000000000101',current_setting('test.instance')::uuid)->'punches'->0->>'source_event_key'),'device-001','attendance detail displays stable external event provenance');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.manual_punches WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_type='import' AND source_event_key IN('device-001','device-002')),2,'canonical imported evidence retains stable source keys');
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND event_key='attendance.import.event'),2,'each imported event has actor-attributed audit provenance');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000102',true);
SELECT throws_ok($$SELECT public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101','[{"employee_code":"CSV-1"}]'::jsonb)$$,'42501','attendance_import_forbidden','view-only attendance member cannot preview import');
SELECT throws_ok($$SELECT public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101','[{"employee_code":"CSV-1"}]'::jsonb)$$,'42501','attendance_import_forbidden','view-only attendance member cannot confirm import');
RESET ROLE;
SELECT set_config('test.instances_before_unassigned',(SELECT count(*)::text FROM time.work_instances WHERE tenant_id='e9110000-0000-4000-8000-000000000101'),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.unassigned',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('employee_code','CSV-2','site_name','Main','happened_at',current_setting('test.event_in'),'direction','out','source_event_key','device-unassigned')))::text,true);
SELECT is((current_setting('test.unassigned')::jsonb->>'unassigned_count')::int,1,'known employee and site event without a matching policy is retained as unassigned');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.unassigned_attendance_evidence WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_event_key='device-unassigned'),1,'unassigned source event is durably stored');
SELECT is((SELECT source_event_key FROM time.unassigned_attendance_evidence WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_event_key='device-unassigned'),'device-unassigned','source key remains attached to the retained evidence');
SELECT is((SELECT direction FROM time.unassigned_attendance_evidence WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_event_key='device-unassigned'),'out','direction remains attached to the retained evidence');
SELECT is((SELECT count(*)::int FROM time.unassigned_attendance_evidence WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_event_key='device-bad'),0,'unknown employee row is rejected without creating orphan evidence');
SELECT is((SELECT count(*)::int FROM time.work_instances WHERE tenant_id='e9110000-0000-4000-8000-000000000101'),current_setting('test.instances_before_unassigned')::int,'unassigned event does not create or guess a Work Instance');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT is(public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-2','site_name','Main','happened_at',current_setting('test.event_in'),'direction','out','source_event_key','device-unassigned')))->>'duplicate_count','1','reimporting identical unassigned evidence is idempotent');
SELECT is(public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-2','site_name','Main','happened_at',current_setting('test.event_out'),'direction','out','source_event_key','device-unassigned')))->>'rejected_count','1','conflicting payload cannot reuse an unassigned source key');
SELECT is(jsonb_array_length(public.attendance_unassigned_evidence_queue('e9110000-0000-4000-8000-000000000101',NULL,50)->'items'),1,'authorized member can see the owned unassigned evidence queue');
SELECT throws_ok($$SELECT public.attach_unassigned_attendance_evidence('e9110000-0000-4000-8000-000000000199',gen_random_uuid(),'محاولة ربط خارج الشركة')$$,'42501','attendance_unassigned_forbidden','cross-tenant attachment is denied');
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id='e9150000-0000-4000-8000-000000000101',work_policy_version=1
 WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND employment_id=current_setting('test.unassigned_employment')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.evidence_id',(public.attendance_unassigned_evidence_queue('e9110000-0000-4000-8000-000000000101',NULL,50)->'items'->0->>'id'),true);
SELECT is(public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-2','site_name','Main','happened_at',current_setting('test.event_in'),'direction','out','source_event_key','device-unassigned')))->>'duplicate_count','1','fixed policy does not let an ordinary reimport bypass explicit attachment review');
RESET ROLE;
UPDATE platform_core.tenant_sites SET display_name='Main renamed'
 WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND id='e9140000-0000-4000-8000-000000000101';
UPDATE people.employees SET employee_code='CSV-2-RENAMED'
 WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND id=(current_setting('test.unassigned_employee')::jsonb->>'employee_id')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.attach',public.attach_unassigned_attendance_evidence('e9110000-0000-4000-8000-000000000101',current_setting('test.evidence_id')::uuid,'تمت مراجعة التكليف والسياسة')::text,true);
SELECT is(current_setting('test.attach')::jsonb->>'status','attached','reviewer can explicitly attach evidence after effective policy is fixed');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.manual_punches WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_event_key='device-unassigned' AND source_type='import'),1,'resolution creates one canonical imported punch with original source key');
SELECT is((SELECT count(*)::int FROM time.unassigned_attendance_resolutions WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND unassigned_evidence_id=current_setting('test.evidence_id')::uuid),1,'explicit attachment retains append-only resolution history');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT is(public.attach_unassigned_attendance_evidence('e9110000-0000-4000-8000-000000000101',current_setting('test.evidence_id')::uuid,'تمت مراجعة التكليف والسياسة')->>'status','already_attached','repeating attachment returns the original resolution');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.attendance_audit_events WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND event_key='attendance.import.unassigned.attached' AND actor_user_id='e9100000-0000-4000-8000-000000000101'),1,'attachment audit records the acting reviewer');
-- A supported, fixed-shift policy can be assigned with overlapping attribution windows.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
SELECT set_config('test.overnight_policy',public.save_time_work_policy('e9110000-0000-4000-8000-000000000101',NULL,'NIGHT','وردية ليلية متداخلة','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'22:00','06:00',true,0,NULL,NULL,NULL,720,360,false,30,15)::text,true);
SELECT set_config('test.overnight_employee',public.create_people_employee('e9110000-0000-4000-8000-000000000101','CSV-NIGHT','موظف الوردية الليلية','e9130000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000101',(now() AT TIME ZONE 'Africa/Cairo')::date-5,'monthly',1000,true)::text,true);
SELECT set_config('test.overnight_employment',(current_setting('test.overnight_employee')::jsonb->>'employment_id'),true);
SELECT set_config('test.night_unassigned_employee',public.create_people_employee('e9110000-0000-4000-8000-000000000101','CSV-NIGHT-UNASSIGNED','موظف بلا تكليف ليلي','e9130000-0000-4000-8000-000000000101','e9140000-0000-4000-8000-000000000101',(now() AT TIME ZONE 'Africa/Cairo')::date-5,'monthly',1000,true)::text,true);
SELECT set_config('test.night_unassigned_employment',(current_setting('test.night_unassigned_employee')::jsonb->>'employment_id'),true);
SELECT is(public.assign_people_work_policy('e9110000-0000-4000-8000-000000000101',current_setting('test.overnight_employment')::uuid,(current_setting('test.overnight_policy')::jsonb->>'id')::uuid,(now() AT TIME ZONE 'Africa/Cairo')::date)->>'state','assigned','supported assignment RPC accepts fixed overnight 720/360 configuration');
RESET ROLE;
-- Move the policy onto the already-existing past interval to model a valid historic binding.
UPDATE people.work_assignments SET work_policy_template_id=(current_setting('test.overnight_policy')::jsonb->>'id')::uuid,work_policy_version=1
 WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND employment_id=current_setting('test.overnight_employment')::uuid AND valid_from<(now() AT TIME ZONE 'Africa/Cairo')::date;
SET LOCAL ROLE authenticated;
SELECT set_config('test.night_checkout',(to_char((((((now() AT TIME ZONE 'Africa/Cairo')::date-1)::timestamp+'11:00'::time) AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'UTC'),'YYYY-MM-DD"T"HH24:MI:SS')||'+00:00'),true);
SELECT set_config('test.night_checkin',(to_char((((((now() AT TIME ZONE 'Africa/Cairo')::date-2)::timestamp+'22:00'::time) AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'UTC'),'YYYY-MM-DD"T"HH24:MI:SS')||'+00:00'),true);
SELECT set_config('test.night_preview',public.preview_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('employee_code','CSV-NIGHT','site_name','Main renamed','happened_at',current_setting('test.night_checkin'),'direction','in','source_event_key','night-checkin'),
 jsonb_build_object('employee_code','CSV-NIGHT','site_name','Main renamed','happened_at',current_setting('test.night_checkout'),'direction','out','source_event_key','night-checkout')))::text,true);
SELECT is(current_setting('test.night_preview')::jsonb->0->>'status','ready','nightly check-in stays uniquely attributable');
SELECT is(current_setting('test.night_preview')::jsonb->0->>'work_date',((now() AT TIME ZONE 'Africa/Cairo')::date-2)::text,'nightly check-in retains prior operational date');
SELECT is(current_setting('test.night_preview')::jsonb->1->>'status','ambiguous','11:00 checkout in overlapping windows requires review');
SELECT is(current_setting('test.night_preview')::jsonb->1->'candidate_work_dates',to_jsonb(ARRAY[(now() AT TIME ZONE 'Africa/Cairo')::date-2,(now() AT TIME ZONE 'Africa/Cairo')::date-1]),'checkout exposes both matching operational dates');
SELECT set_config('test.night_unselected',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-NIGHT','site_name','Main renamed','happened_at',current_setting('test.night_checkout'),'direction','out','source_event_key','night-unselected')))::text,true);
SELECT is((current_setting('test.night_unselected')::jsonb->>'ambiguous_count')::int,1,'unselected overlap is reported for review');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.manual_punches WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_event_key='night-unselected'),0,'unselected overlap creates no punch');
SELECT is((SELECT count(*)::int FROM time.work_instances wi JOIN people.work_assignments a ON a.tenant_id=wi.tenant_id AND a.id=wi.assignment_id WHERE wi.tenant_id='e9110000-0000-4000-8000-000000000101' AND a.employment_id=current_setting('test.overnight_employment')::uuid),0,'unselected overlap creates no arbitrary instance');
SET LOCAL ROLE authenticated;
SELECT set_config('test.night_wrong_date',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('employee_code','CSV-NIGHT','site_name','Main renamed','happened_at',current_setting('test.night_checkin'),'direction','in','source_event_key','night-wrong-date','work_date',(now() AT TIME ZONE 'Africa/Cairo')::date-1)))::text,true);
SELECT is((current_setting('test.night_wrong_date')::jsonb->>'rejected_count')::int,1,'explicit date outside the single candidate is rejected');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM time.manual_punches WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND source_event_key='night-wrong-date'),0,'invalid explicit date cannot attach a punch');
SET LOCAL ROLE authenticated;
SELECT set_config('test.night_confirm',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(
 jsonb_build_object('employee_code','CSV-NIGHT','site_name','Main renamed','happened_at',current_setting('test.night_checkin'),'direction','in','source_event_key','night-confirmed','work_date',(now() AT TIME ZONE 'Africa/Cairo')::date-2),
 jsonb_build_object('employee_code','CSV-NIGHT','site_name','Main renamed','happened_at',current_setting('test.night_checkout'),'direction','out','source_event_key','night-confirmed-checkout','work_date',(now() AT TIME ZONE 'Africa/Cairo')::date-2)))::text,true);
SELECT is((current_setting('test.night_confirm')::jsonb->>'accepted_count')::int,2,'explicit prior date confirms both paired events');
RESET ROLE;
SELECT is((SELECT count(DISTINCT wi.id)::int FROM time.manual_punches p JOIN time.work_instances wi ON wi.tenant_id=p.tenant_id AND wi.id=p.work_instance_id WHERE p.tenant_id='e9110000-0000-4000-8000-000000000101' AND p.source_event_key IN('night-confirmed','night-confirmed-checkout')),1,'paired nightly events share the selected instance');
SELECT is((SELECT wi.operational_date FROM time.manual_punches p JOIN time.work_instances wi ON wi.tenant_id=p.tenant_id AND wi.id=p.work_instance_id WHERE p.tenant_id='e9110000-0000-4000-8000-000000000101' AND p.source_event_key='night-confirmed-checkout'),((now() AT TIME ZONE 'Africa/Cairo')::date-2),'checkout persists against selected operational date');
SET LOCAL ROLE authenticated;
SELECT set_config('test.night_unassigned',public.confirm_attendance_csv_import('e9110000-0000-4000-8000-000000000101',jsonb_build_array(jsonb_build_object('employee_code','CSV-NIGHT-UNASSIGNED','site_name','Main renamed','happened_at',current_setting('test.night_checkout'),'direction','out','source_event_key','night-unassigned')))::text,true);
SELECT is((current_setting('test.night_unassigned')::jsonb->>'unassigned_count')::int,1,'unassigned evidence fixture is created before policy assignment');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000101',true);
RESET ROLE;
UPDATE people.work_assignments SET work_policy_template_id=(current_setting('test.overnight_policy')::jsonb->>'id')::uuid,work_policy_version=1 WHERE tenant_id='e9110000-0000-4000-8000-000000000101' AND employment_id=current_setting('test.night_unassigned_employment')::uuid AND valid_from<(now() AT TIME ZONE 'Africa/Cairo')::date;
SET LOCAL ROLE authenticated;
SELECT set_config('test.night_evidence',(SELECT item->>'id' FROM jsonb_array_elements(public.attendance_unassigned_evidence_queue('e9110000-0000-4000-8000-000000000101',NULL,50)->'items') AS q(item) WHERE item->>'source_event_key'='night-unassigned'),true);
SELECT is((SELECT item->>'date_resolution_status' FROM jsonb_array_elements(public.attendance_unassigned_evidence_queue('e9110000-0000-4000-8000-000000000101',NULL,50)->'items') AS q(item) WHERE item->>'source_event_key'='night-unassigned'),'ambiguous','existing unassigned queue surfaces overlap after assignment is fixed');
SELECT is((SELECT item->'candidate_work_dates' FROM jsonb_array_elements(public.attendance_unassigned_evidence_queue('e9110000-0000-4000-8000-000000000101',NULL,50)->'items') AS q(item) WHERE item->>'source_event_key'='night-unassigned'),to_jsonb(ARRAY[(now() AT TIME ZONE 'Africa/Cairo')::date-2,(now() AT TIME ZONE 'Africa/Cairo')::date-1]),'unassigned queue exposes both bounded date choices');
SELECT throws_ok($$SELECT public.attach_unassigned_attendance_evidence('e9110000-0000-4000-8000-000000000101',current_setting('test.night_evidence')::uuid,'مراجعة التكليف')$$,'22023','attendance_unassigned_work_date_required','legacy attach refuses to guess between dates');
SELECT is(public.attach_unassigned_attendance_evidence_for_date('e9110000-0000-4000-8000-000000000101',current_setting('test.night_evidence')::uuid,'مراجعة التكليف',(now() AT TIME ZONE 'Africa/Cairo')::date-2)->>'status','attached','date-selected attachment resolves saved evidence');
RESET ROLE;
SELECT is((SELECT wi.operational_date FROM time.unassigned_attendance_resolutions r JOIN time.work_instances wi ON wi.tenant_id=r.tenant_id AND wi.id=r.work_instance_id WHERE r.tenant_id='e9110000-0000-4000-8000-000000000101' AND r.unassigned_evidence_id=current_setting('test.night_evidence')::uuid),((now() AT TIME ZONE 'Africa/Cairo')::date-2),'attachment resolution persists chosen work date');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e9100000-0000-4000-8000-000000000102',true);
SELECT throws_ok($$SELECT public.attach_unassigned_attendance_evidence('e9110000-0000-4000-8000-000000000101',current_setting('test.evidence_id')::uuid,'محاولة بلا صلاحية')$$,'42501','attendance_unassigned_forbidden','view-only member cannot attach unassigned evidence');
SELECT throws_ok($$SELECT public.attendance_unassigned_evidence_queue('e9110000-0000-4000-8000-000000000199',NULL,50)$$,'42501','attendance_unassigned_forbidden','cross-tenant unassigned queue is denied');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
