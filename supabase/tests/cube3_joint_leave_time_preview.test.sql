BEGIN;
SELECT no_plan();
SELECT set_config('test.tenant','cfc20000-0000-4000-8000-000000000001',true);
SELECT set_config('test.actor','cfc10000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employee','cfc40000-0000-4000-8000-000000000001',true);
SELECT set_config('test.employment','cfc60000-0000-4000-8000-000000000001',true);
SELECT set_config('test.day',(now() AT TIME ZONE 'UTC')::date::text,true);
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT ('cfc10000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'classified-'||n||'@test.invalid',now() FROM generate_series(1,3)n;
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES(current_setting('test.tenant')::uuid,'Synthetic classified facts',current_setting('test.actor')::uuid);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
 SELECT current_setting('test.tenant')::uuid,('cfc10000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,current_setting('test.actor')::uuid FROM generate_series(1,3)n;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 (current_setting('test.tenant')::uuid,'cfc30000-0000-4000-8000-000000000001','classified.dual',1,ARRAY['attendance.manage','attendance.view','attendance.approve','attendance.correct','leave.manage','leave.approve','leave.view'],false),
 (current_setting('test.tenant')::uuid,'cfc30000-0000-4000-8000-000000000002','classified.approve',1,ARRAY['attendance.approve','attendance.view'],false),
 (current_setting('test.tenant')::uuid,'cfc30000-0000-4000-8000-000000000003','classified.correct',1,ARRAY['attendance.correct','attendance.view'],false);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
 SELECT current_setting('test.tenant')::uuid,('cfc10000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('cfc30000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid FROM generate_series(1,3)n;
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
 SELECT current_setting('test.tenant')::uuid,k,true,now()-interval '1 minute',current_setting('test.actor')::uuid,'Synthetic classified facts' FROM unnest(ARRAY['hr.people','hr.leave','hr.attendance'])k;
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)
 VALUES(current_setting('test.tenant')::uuid,'cfc50000-0000-4000-8000-000000000001','Synthetic employer',true,true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
 VALUES(current_setting('test.tenant')::uuid,'cfc50000-0000-4000-8000-000000000002','cfc50000-0000-4000-8000-000000000001','Synthetic site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
 VALUES(current_setting('test.tenant')::uuid,current_setting('test.employee')::uuid,'CLASSIFIED-ONE','Synthetic Employee',current_setting('test.actor')::uuid);
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
 VALUES(current_setting('test.tenant')::uuid,current_setting('test.employment')::uuid,current_setting('test.employee')::uuid,'cfc50000-0000-4000-8000-000000000001',current_setting('test.day')::date-30,'active','monthly');
INSERT INTO "time".work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES(current_setting('test.tenant')::uuid,'cfc80000-0000-4000-8000-000000000001','CLASSIFIED-FIXED',true,1);
INSERT INTO "time".work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,attribution_before_minutes,attribution_after_minutes,created_by,auto_approve_clean,fixed_break_start,fixed_break_end,overtime_enabled,lateness_grace_minutes,early_leave_grace_minutes)
 VALUES(current_setting('test.tenant')::uuid,'cfc80000-0000-4000-8000-000000000001',1,'Synthetic fixed','fixed','UTC',ARRAY[1,2,3,4,5,6,7]::smallint[],'09:00','17:00',false,60,120,360,current_setting('test.actor')::uuid,false,'13:00','14:00',true,0,0);
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from)
 VALUES(current_setting('test.tenant')::uuid,'cfc70000-0000-4000-8000-000000000001',current_setting('test.employment')::uuid,'cfc50000-0000-4000-8000-000000000002','cfc80000-0000-4000-8000-000000000001',1,current_setting('test.day')::date-30);
CREATE TEMP TABLE cases(label text PRIMARY KEY,day date,instance uuid,request uuid,review jsonb,result jsonb);
INSERT INTO cases(label,day) SELECT label,current_setting('test.day')::date-offset_days FROM (VALUES
 ('plain',10),('paid_half',9),('paid_full',8),('observed_full',7),('mixed',6),('unpaid_half',5),('unpaid_full',4),('invalid',3))v(label,offset_days);
GRANT SELECT,UPDATE ON cases TO authenticated;
CREATE FUNCTION pg_temp.review(p_label text) RETURNS jsonb LANGUAGE sql AS $f$
 SELECT public.attendance_review_classification(current_setting('test.tenant')::uuid,instance) FROM cases WHERE label=p_label
$f$;
CREATE FUNCTION pg_temp.commit(p_label text,p_review jsonb,p_reason text,p_key text) RETURNS jsonb LANGUAGE sql AS $f$
 SELECT public.attendance_commit_classification(current_setting('test.tenant')::uuid,instance,
 (p_review->>'expected_fact_id')::uuid,(p_review->>'expected_fact_version')::integer,
 (p_review->>'expected_interpretation_id')::uuid,(p_review->>'expected_interpretation_version')::integer,
 p_review->>'input_fingerprint',p_review->>'context_hash',p_review->>'plan_hash',p_reason,p_key) FROM cases WHERE label=p_label
$f$;
CREATE FUNCTION pg_temp.approve_leave(p_label text,p_type uuid,p_half boolean,p_part text,p_key text) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE target cases%ROWTYPE; request jsonb; id uuid;
BEGIN
 SELECT * INTO target FROM cases WHERE label=p_label;
 request:=public.leave_record_hr_request(current_setting('test.tenant')::uuid,current_setting('test.employee')::uuid,current_setting('test.employment')::uuid,p_type,target.day,target.day,p_half,p_part,'Synthetic reviewed Leave',p_key);
 id:=(request->>'id')::uuid;
 PERFORM public.leave_approve_request(current_setting('test.tenant')::uuid,id,1,1,'Synthetic approval',p_key||'-approve');
 RETURN id;
END $f$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',current_setting('test.actor'),true);
UPDATE cases SET instance=(public.attendance_open_day(current_setting('test.tenant')::uuid,day,NULL,50)->'items'->0->>'id')::uuid;
SELECT set_config('test.calendar',public.leave_create_calendar(current_setting('test.tenant')::uuid,'cfc50000-0000-4000-8000-000000000001','CLASSIFIED-CAL','Synthetic Calendar',current_setting('test.day')::date-30,NULL,ARRAY[]::smallint[],'[]','Synthetic source','Synthetic reason')::text,true);
SELECT public.leave_create_year_period(current_setting('test.tenant')::uuid,'cfc50000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.day')::date-30,current_setting('test.day')::date+30,'Synthetic Period','Synthetic reason');
SELECT set_config('test.paid',public.leave_create_type(current_setting('test.tenant')::uuid,'cfc50000-0000-4000-8000-000000000001','CLASSIFIED-PAID','Synthetic Paid',current_setting('test.day')::date-30,'paid','untracked',true,'Synthetic source','Synthetic reason','calendar_days')::text,true);
SELECT set_config('test.unpaid',public.leave_create_type(current_setting('test.tenant')::uuid,'cfc50000-0000-4000-8000-000000000001','CLASSIFIED-UNPAID','Synthetic Unpaid',current_setting('test.day')::date-30,'unpaid','untracked',true,'Synthetic source','Synthetic reason','calendar_days')::text,true);
UPDATE cases SET request=pg_temp.approve_leave(label,current_setting('test.paid')::uuid,true,'first','cf-paid-half') WHERE label='paid_half';
UPDATE cases SET request=pg_temp.approve_leave(label,current_setting('test.paid')::uuid,false,NULL,'cf-'||label) WHERE label IN('paid_full','observed_full','invalid');
SELECT pg_temp.approve_leave('mixed',current_setting('test.paid')::uuid,true,'first','cf-mixed-first');
SELECT pg_temp.approve_leave('mixed',current_setting('test.unpaid')::uuid,true,'second','cf-mixed-second');
UPDATE cases SET request=pg_temp.approve_leave(label,current_setting('test.unpaid')::uuid,label='unpaid_half',CASE WHEN label='unpaid_half' THEN 'second' END,'cf-'||label) WHERE label IN('unpaid_half','unpaid_full');
SELECT public.record_manual_attendance_punch_local(current_setting('test.tenant')::uuid,instance,'in',day+'10:00'::time,gen_random_uuid(),'Synthetic actual work') FROM cases WHERE label IN('observed_full','invalid');
SELECT public.record_manual_attendance_punch_local(current_setting('test.tenant')::uuid,instance,'out',day+'19:00'::time,gen_random_uuid(),'Synthetic actual exit') FROM cases WHERE label='observed_full';
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.prospective',public.leave_record_hr_request(current_setting('test.tenant')::uuid,current_setting('test.employee')::uuid,current_setting('test.employment')::uuid,current_setting('test.unpaid')::uuid,(SELECT day FROM cases WHERE label='plain'),(SELECT day FROM cases WHERE label='plain'),true,'first','Synthetic future half','joint-preview-approve')->>'id',true);
SELECT set_config('test.replace',public.leave_record_hr_request(current_setting('test.tenant')::uuid,current_setting('test.employee')::uuid,current_setting('test.employment')::uuid,current_setting('test.paid')::uuid,(SELECT day FROM cases WHERE label='paid_half'),(SELECT day FROM cases WHERE label='paid_half'),false,NULL,'Synthetic future whole','joint-preview-replace')->>'id',true);
SELECT pg_temp.commit('paid_half',pg_temp.review('paid_half'),'Synthetic existing fraction','joint-preview-existing');
RESET ROLE;
CREATE TEMP TABLE before_review AS SELECT (SELECT count(*) FROM "time".interpretations) q,(SELECT count(*) FROM "time".attendance_facts) f,(SELECT count(*) FROM "time".attendance_audit_events) a,(SELECT count(*) FROM leave.ledger_entries) l,(SELECT md5(string_agg(to_jsonb(r)::text,'' ORDER BY id)) FROM leave.requests r) requests_digest;
CREATE TEMP TABLE plans(kind text PRIMARY KEY,payload jsonb);
GRANT ALL ON plans TO authenticated;
SET LOCAL ROLE authenticated;
INSERT INTO plans VALUES('approve',public.leave_time_correction_preview(current_setting('test.tenant')::uuid,'approve',current_setting('test.prospective')::uuid));
INSERT INTO plans SELECT 'replace',public.leave_time_correction_preview(current_setting('test.tenant')::uuid,'replace',request,current_setting('test.replace')::uuid) FROM cases WHERE label='paid_half';
SELECT is(payload->>'state','reviewed',kind||' has a read-only reviewed plan') FROM plans;
SELECT ok(payload->'items'->0->'proposed_classification' @> '{"kind":"absence","absence_units":0.5,"leave_units":0.5}', 'unapproved half is calculated prospectively without becoming effective') FROM plans WHERE kind='approve';
SELECT ok(payload->'items'->0->'current_classification' @> '{"kind":"absence","absence_units":1,"leave_units":0}', 'actual current context remains unapproved') FROM plans WHERE kind='approve';
SELECT ok(payload->'items'->0->'proposed_classification' @> '{"kind":"leave_covered","absence_units":0,"leave_units":1}', 'replacement removes old half and proposes exact full coverage') FROM plans WHERE kind='replace';
SELECT ok(payload->'items'->0->'expected_fact'->>'id' IS NOT NULL,'replacement binds current immutable fact predecessor') FROM plans WHERE kind='replace';
SELECT ok(NOT (payload ? 'cancellation_event') AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payload->'items') item WHERE item ? 'server_input' OR item ? 'prospective_context'), 'public plan omits private server input and cancellation event payload') FROM plans;
SELECT is(public.leave_time_correction_preview(current_setting('test.tenant')::uuid,'approve',current_setting('test.prospective')::uuid)->>'plan_hash',payload->>'plan_hash','stable plan hash excludes evaluation clock') FROM plans WHERE kind='approve';
SELECT throws_ok($$SELECT public.leave_time_correction_preview(current_setting('test.tenant')::uuid,'approve',current_setting('test.prospective')::uuid,current_setting('test.replace')::uuid)$$,'22023',NULL,'approve cannot smuggle replacement identity');
SELECT throws_ok($$SELECT public.leave_time_correction_preview(current_setting('test.tenant')::uuid,'approve','00000000-0000-4000-8000-000000000001')$$,'P0002',NULL,'unknown scoped request is unavailable');
SELECT set_config('request.jwt.claim.sub','cfc10000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.leave_time_correction_preview(current_setting('test.tenant')::uuid,'approve',current_setting('test.prospective')::uuid)$$,'42501',NULL,'Attendance approval alone cannot obtain joint review');
SELECT set_config('request.jwt.claim.sub',current_setting('test.actor'),true);
RESET ROLE;
SELECT ok((SELECT count(*) FROM "time".interpretations)=q AND (SELECT count(*) FROM "time".attendance_facts)=f AND (SELECT count(*) FROM "time".attendance_audit_events)=a AND (SELECT count(*) FROM leave.ledger_entries)=l AND (SELECT md5(string_agg(to_jsonb(r)::text,'' ORDER BY id)) FROM leave.requests r)=requests_digest,'all joint previews leave facts, interpretations, ledger, audit and request rows untouched') FROM before_review;
SET LOCAL ROLE authenticated;
SELECT public.leave_cancel_approved_request(current_setting('test.tenant')::uuid,request,2,'Synthetic accepted cancellation','joint-preview-cancel') FROM cases WHERE label='paid_half';
INSERT INTO plans SELECT 'cancel',public.leave_time_correction_preview(current_setting('test.tenant')::uuid,'cancel_reconcile',request) FROM cases WHERE label='paid_half';
SELECT ok(payload->'items'->0->'proposed_classification' @> '{"kind":"absence","absence_units":1,"leave_units":0}', 'cancel reconciliation proposes full residual absence') FROM plans WHERE kind='cancel';
SELECT ok(payload->>'cancellation_event_id' IS NOT NULL, 'cancel review binds immutable direct cancellation event even without an employee cancellation request') FROM plans WHERE kind='cancel';
SELECT is(jsonb_array_length(payload->'items'),1,'cancel review discovers complete affected work instance') FROM plans WHERE kind='cancel';
RESET ROLE;
SELECT is((payload->>'cancellation_event_id')::bigint,(SELECT max(e.id) FROM leave.cancellation_events e JOIN cases c ON c.request=e.request_id WHERE e.tenant_id=current_setting('test.tenant')::uuid AND c.label='paid_half' AND e.to_state='cancelled'), 'cancel plan identifies the exact persisted source event') FROM plans WHERE kind='cancel';
SELECT ok(NOT has_function_privilege('authenticated','platform_private.leave_time_review_plan(uuid,text,uuid,uuid,timestamptz)','EXECUTE') AND NOT has_function_privilege('authenticated','platform_private.leave_time_prospective_context(uuid,uuid,uuid,uuid)','EXECUTE'),'private plan and context cannot be called directly');
SELECT * FROM finish();
ROLLBACK;
