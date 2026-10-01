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
CREATE TEMP TABLE effects_before AS SELECT (SELECT count(*) FROM "time".interpretations) q,(SELECT count(*) FROM "time".attendance_facts) f,(SELECT count(*) FROM "time".attendance_audit_events) a,(SELECT count(*) FROM leave.ledger_entries) l;
SET LOCAL ROLE authenticated;
UPDATE cases SET review=pg_temp.review(label);
SELECT ok(review->'classification' @> expected,label||' reviewed nominal quantities') FROM cases JOIN (VALUES
 ('plain','{"kind":"absence","absence_units":1,"leave_units":0}'::jsonb),
 ('paid_half','{"kind":"absence","absence_units":0.5,"leave_units":0.5}'::jsonb),
 ('unpaid_half','{"kind":"absence","absence_units":0.5,"leave_units":0.5}'::jsonb),
 ('paid_full','{"kind":"leave_covered","absence_units":0,"leave_units":1}'::jsonb),
 ('unpaid_full','{"kind":"leave_covered","absence_units":0,"leave_units":1}'::jsonb),
 ('mixed','{"kind":"leave_covered","absence_units":0,"leave_units":1}'::jsonb),
 ('invalid','{"kind":"review_required","diagnostics":["missing_punch"]}'::jsonb)
 )v(label,expected) USING(label);
RESET ROLE;
SELECT ok((SELECT count(*) FROM "time".interpretations)=q AND (SELECT count(*) FROM "time".attendance_facts)=f AND
 (SELECT count(*) FROM "time".attendance_audit_events)=a AND (SELECT count(*) FROM leave.ledger_entries)=l,'review creates no operational effects') FROM effects_before;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cfc10000-0000-4000-8000-000000000002',true);
UPDATE cases SET result=pg_temp.commit(label,review,'Synthetic initial absence','cf-initial-plain') WHERE label='plain';
SELECT ok(result @> '{"state":"approved_absence","absence_units":1,"version":1}', 'approve-only actor can make initial reviewed absence') FROM cases WHERE label='plain';
SELECT set_config('request.jwt.claim.sub',current_setting('test.actor'),true);
UPDATE cases SET result=pg_temp.commit(label,review,'Synthetic explicit classification','cf-commit-'||label) WHERE label NOT IN('plain','invalid');
SELECT ok(result->>'fact_id' IS NOT NULL,label||' committed immutable fact') FROM cases WHERE label NOT IN('invalid');
SELECT throws_ok($$SELECT pg_temp.commit('invalid',pg_temp.review('invalid'),'Synthetic unsupported evidence','cf-unsupported')$$,'23514',NULL,'invalid full-covered punch evidence cannot create a fact');
SELECT throws_ok($$SELECT pg_temp.commit('paid_full',review,'Synthetic stale token retry','cf-stale') FROM cases WHERE label='paid_full'$$,'PT409',NULL,'old review cannot append another fact');
SELECT ok(pg_temp.review('plain')->>'plan_hash'=pg_temp.review('plain')->>'plan_hash','unchanged classification hash excludes clock milliseconds');
SELECT throws_ok(format('SELECT pg_temp.commit(%L,jsonb_set(pg_temp.review(%L),%L::text[],%L::jsonb),%L,%L)',
 'paid_full','paid_full',ARRAY[field]::text,bad_value::text,'Synthetic altered review','cf-altered-'||field),
 'PT409',NULL,'reject mismatched '||field) FROM (VALUES
 ('expected_fact_id','"00000000-0000-4000-8000-000000000001"'::jsonb),
 ('expected_fact_version','99'::jsonb),
 ('expected_interpretation_id','"00000000-0000-4000-8000-000000000002"'::jsonb),
 ('expected_interpretation_version','99'::jsonb),
 ('input_fingerprint','"00000000000000000000000000000000"'::jsonb),
 ('context_hash','"00000000000000000000000000000000"'::jsonb),
 ('plan_hash',to_jsonb(repeat('0',64))))v(field,bad_value);
SELECT throws_ok($$SELECT pg_temp.commit('paid_full',pg_temp.review('paid_full')-'plan_hash','Synthetic missing review hash','cf-missing-hash')$$,
 '22023',NULL,'missing hash is rejected before any write');
SELECT throws_ok($$SELECT public.attendance_review_classification(current_setting('test.tenant')::uuid,'00000000-0000-4000-8000-000000000003')$$,
 'P0002',NULL,'foreign work instance is unavailable in the tenant');
SELECT pg_temp.commit('plain',pg_temp.review('plain'),'Synthetic explicit successor','cf-successor-plain');
SELECT set_config('request.jwt.claim.sub','cfc10000-0000-4000-8000-000000000002',true);
SELECT is(pg_temp.commit('plain',review,'Synthetic initial absence','cf-initial-plain'),result,'initial receipt replays after successor for approve-only actor') FROM cases WHERE label='plain';
SELECT throws_ok($$SELECT pg_temp.commit('plain',review,'Changed immutable reason','cf-initial-plain') FROM cases WHERE label='plain'$$,'23505',NULL,'same key with altered reason refuses replay');
SELECT throws_ok($$SELECT pg_temp.review('plain')$$,'42501',NULL,'approve-only actor cannot review an existing-fact correction');
SELECT ok(public.attendance_instance_detail(current_setting('test.tenant')::uuid,instance)::text NOT LIKE '%pay_effect%', 'Attendance-only full fact history hides expanded Leave pay effect') FROM cases WHERE label='paid_half';
SELECT ok(public.attendance_payroll_input_projection(current_setting('test.tenant')::uuid,current_setting('test.day')::date-10,current_setting('test.day')::date-3)::text NOT LIKE '%pay_effect%',
 'Attendance-only payroll projection hides Leave pay effect');
SELECT is(jsonb_array_length(public.attendance_payroll_input_projection(current_setting('test.tenant')::uuid,current_setting('test.day')::date-10,current_setting('test.day')::date-3)->'items'),7,
 'projection includes the latest seven worked-day identities including full coverage');
SELECT is((SELECT count(*)::integer FROM jsonb_array_elements(public.attendance_payroll_input_projection(current_setting('test.tenant')::uuid,current_setting('test.day')::date-10,current_setting('test.day')::date-3)->'items') item
 WHERE item->>'outcome'='leave_covered' AND (item->>'absence_units')::numeric=0 AND (item->>'leave_units')::numeric=1),4,
 'projection carries four full-covered days exactly once');
SELECT set_config('request.jwt.claim.sub','cfc10000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT pg_temp.review('plain')$$,'42501',NULL,'correct-only actor also lacks correction approval');
SELECT set_config('request.jwt.claim.sub',current_setting('test.actor'),true);
SELECT public.leave_cancel_approved_request(current_setting('test.tenant')::uuid,request,2,'Synthetic explicit cancellation','cf-cancel-half') FROM cases WHERE label='paid_half';
SELECT ok((public.attendance_instance_detail(current_setting('test.tenant')::uuid,instance)->>'classification_reconciliation_required')::boolean,
 'cancelled source leaves current fact visibly pending reconciliation') FROM cases WHERE label='paid_half';
SELECT ok(pg_temp.review('paid_half')->'classification' @> '{"kind":"absence","absence_units":1,"leave_units":0}', 'cancelled half can be re-reviewed as residual absence1');
SELECT pg_temp.commit('paid_half',pg_temp.review('paid_half'),'Synthetic current-source correction','cf-reconcile-half');
SELECT ok(NOT (public.attendance_instance_detail(current_setting('test.tenant')::uuid,instance)->>'classification_reconciliation_required')::boolean,
 'explicit successor clears source reconciliation') FROM cases WHERE label='paid_half';
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM "time".attendance_facts WHERE tenant_id=current_setting('test.tenant')::uuid),9,'seven initial facts and two explicit successors');
SELECT is((SELECT count(*)::integer FROM "time".classification_evidence WHERE tenant_id=current_setting('test.tenant')::uuid),9,'every classified fact has independently appended reviewed evidence');
SELECT is((SELECT count(*)::integer FROM "time".classification_operations WHERE tenant_id=current_setting('test.tenant')::uuid),9,'receipt cardinality excludes replay and refused calls');
SELECT ok(f.fact @> '{"observations":{"gross_worked_minutes":540,"worked_minutes":480,"late_minutes":60,"early_leave_minutes":0,"applied_break_minutes":60},"classification":{"diagnostics":["observed_work_during_excused"]}}','covered fact retains actual work independently')
 FROM "time".attendance_facts f JOIN cases c ON c.instance=f.work_instance_id WHERE c.label='observed_full';
SELECT is((SELECT count(*)::integer FROM "time".attendance_overtime_candidates WHERE tenant_id=current_setting('test.tenant')::uuid),0,'full coverage with observed overtime creates no overtime candidate');
SELECT is((SELECT count(*) FROM leave.ledger_entries),l,'Time classification leaves Leave ledger unchanged') FROM effects_before;
SELECT ok(NOT has_table_privilege('authenticated','time.classification_evidence','SELECT')
 AND NOT has_table_privilege('authenticated','time.classification_operations','SELECT'), 'private plans and receipts cannot be read directly');
SELECT * FROM finish();
ROLLBACK;
