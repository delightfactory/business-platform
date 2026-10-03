BEGIN;
DO $$ BEGIN IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_candidate_lf_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required'; END IF; END $$;
SELECT no_plan();
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('d3000000-0000-4000-8000-000000000001','d300-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3000000-0000-4000-8000-000000000002','d300-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('d3001000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','d3000000-0000-4000-8000-000000000001'),
 ('d3001000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','d3000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('d3001000-0000-4000-8000-000000000001','d3002000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve']),
 ('d3001000-0000-4000-8000-000000000001','d3002000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('d3001000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001'),
 ('d3001000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000002','d3000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('d3001000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d3002000-0000-4000-8000-000000000001'),
 ('d3001000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000002','d3002000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('d3001000-0000-4000-8000-000000000002','d3003000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('d3001000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','d3000000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('d3001000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','d3000000-0000-4000-8000-000000000001','Cube4 QA only');

-- Scope-only rollback fixture. No legal pack, approval or final money is invented.
CREATE FUNCTION pg_temp.workspace() RETURNS jsonb LANGUAGE sql AS $$SELECT public.payroll_workspace('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001')->'calendar_change_review'$$;
GRANT EXECUTE ON FUNCTION pg_temp.workspace() TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3000000-0000-4000-8000-000000000001',true);
SELECT is(pg_temp.workspace()->>'open_run_period_id',NULL::text,'empty scope has no open-run handoff');
SELECT is(pg_temp.workspace()->>'pending_attendance_date',NULL::text,'optional disabled Time is not a pending input');
SELECT is(pg_temp.workspace()->>'locked_history','false','empty scope is not labelled locked');
SELECT set_config('test.period',(public.payroll_save_calendar('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','2030-01-25',24,1,'following','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','2030-01-25',24,1,'following','Africa/Cairo'),'Reviewed QA calendar')->>'period_id'),true);
RESET ROLE;
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'d3009000-0000-4000-8000-000000000001','draft','d3000000-0000-4000-8000-000000000001');
SELECT set_config('test.period_digest',(SELECT md5(jsonb_agg(to_jsonb(p) ORDER BY id)::text) FROM payroll.periods p WHERE tenant_id='d3001000-0000-4000-8000-000000000001'),true);
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.workspace()->>'open_run_period_id',current_setting('test.period'),'open run exposes its exact period for recovery');
SELECT throws_ok($$SELECT public.payroll_save_calendar('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','2030-02-25',24,2,'following','Africa/Cairo',1,gen_random_uuid(),public.payroll_calendar_preview('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','2030-02-25',24,2,'following','Africa/Cairo'),'Reviewed change')$$,'55000','payroll_open_run','server retains open-run guard despite preflight UI');
SELECT lives_ok($$SELECT public.payroll_run_command('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'d3009000-0000-4000-8000-000000000001',0,'cancel','Explicit QA cancellation',gen_random_uuid())$$,'supported command cancels draft before calendar change');
SELECT is(pg_temp.workspace()->>'open_run_period_id',NULL::text,'cancelled run releases calendar handoff');
SELECT lives_ok($$SELECT public.payroll_save_calendar('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','2030-02-25',24,2,'following','Africa/Cairo',1,gen_random_uuid(),public.payroll_calendar_preview('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','2030-02-25',24,2,'following','Africa/Cairo'),'Reviewed after cancellation')$$,'same scope accepts prospective change after explicit cancellation');
RESET ROLE;
SELECT is((SELECT md5(jsonb_agg(to_jsonb(p) ORDER BY id)::text) FROM payroll.periods p WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND id=current_setting('test.period')::uuid),current_setting('test.period_digest'),'original generated period byte-equivalent after prospective change');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d3001000-0000-4000-8000-000000000001','d3003500-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','Calendar review QA',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d3001000-0000-4000-8000-000000000001','d3004000-0000-4000-8000-000000000001','CALREV','Synthetic review','d3000000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d3001000-0000-4000-8000-000000000001','d3005000-0000-4000-8000-000000000001','d3004000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('d3001000-0000-4000-8000-000000000001','d3006500-0000-4000-8000-000000000001','d3005000-0000-4000-8000-000000000001','d3003500-0000-4000-8000-000000000001','2030-01-01');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d3001000-0000-4000-8000-000000000001','d3008000-0000-4000-8000-000000000001','CALREVIEW',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d3001000-0000-4000-8000-000000000001','d3008000-0000-4000-8000-000000000001',1,'Review fixture','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d3000000-0000-4000-8000-000000000001');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,status,created_by) VALUES('d3001000-0000-4000-8000-000000000001','d300a000-0000-4000-8000-000000000001','d3006500-0000-4000-8000-000000000001','d3005000-0000-4000-8000-000000000001','d3004000-0000-4000-8000-000000000001','d3003500-0000-4000-8000-000000000001','2030-01-26','d3008000-0000-4000-8000-000000000001',1,'UTC','needs_review','d3000000-0000-4000-8000-000000000001');
SELECT is(pg_temp.workspace()->>'pending_attendance_date',NULL::text,'disabled optional Time hides even existing scoped pending instance');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES('d3001000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','d3000000-0000-4000-8000-000000000001','QA observation only');
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.workspace()->>'pending_attendance_date','2030-01-26','enabled scoped pending instance exposes exact review date');
SELECT is(public.payroll_workspace('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000003')->'calendar_change_review'->>'pending_attendance_date',NULL::text,'sibling Employer does not inherit pending Time');
SELECT is(pg_temp.workspace()->>'can_review_attendance','false','calendar manager lacks Attendance drill-through authority');
SELECT throws_ok($$SELECT public.payroll_workspace('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000002')$$,'22023','payroll_invalid','cross-Tenant Employer review refused');
RESET ROLE;
SELECT ok(NOT has_function_privilege('authenticated','payroll.calendar_change_review(uuid,uuid)','EXECUTE'),'private review cannot bypass workspace authority');
SELECT is((SELECT status FROM time.work_instances WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND id='d300a000-0000-4000-8000-000000000001'),'needs_review','observational review does not approve or mutate Time');
SELECT is((SELECT count(*) FROM payroll.final_contexts WHERE tenant_id='d3001000-0000-4000-8000-000000000001'),0::bigint,'review generates no financial output');
-- Historical-approved-state prerequisite only: current candidate remains unqualified.
-- This does not exercise or fake successful legal approval. Release must work when readiness was lost.
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'d3009000-0000-4000-8000-000000000002','draft','d3000000-0000-4000-8000-000000000001');
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) SELECT 'd3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','d3009000-0000-4000-8000-000000000002','d3009100-0000-4000-8000-000000000001',1,'SYNTHETIC_NONLEGAL_HISTORICAL_APPROVAL',m,payroll.build_review(m),'d3000000-0000-4000-8000-000000000001' FROM(SELECT payroll.run_manifest('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)m)s;
UPDATE payroll.runs SET status='review',candidate_id='d3009100-0000-4000-8000-000000000001',revision=1 WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND id='d3009000-0000-4000-8000-000000000002';
INSERT INTO payroll.approval_events(tenant_id,employer_id,run_id,candidate_id,id,operation,run_revision,actor_id,reason) VALUES('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001','d3009000-0000-4000-8000-000000000002','d3009100-0000-4000-8000-000000000001','d3009200-0000-4000-8000-000000000001','approve',2,'d3000000-0000-4000-8000-000000000001','SYNTHETIC_NONLEGAL historical approved-state prerequisite; not statutory qualification');
UPDATE payroll.runs SET status='approved',approval_id='d3009200-0000-4000-8000-000000000001',revision=2 WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND id='d3009000-0000-4000-8000-000000000002';
SELECT set_config('test.approved_candidate_digest',(SELECT md5(to_jsonb(c)::text) FROM payroll.candidates c WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND id='d3009100-0000-4000-8000-000000000001'),true);
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.workspace()->>'open_run_period_id',current_setting('test.period'),'approved history still blocks calendar with exact-period recovery');
SELECT throws_ok($$SELECT public.payroll_run_command('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'d3009000-0000-4000-8000-000000000002',2,'cancel','Must release first',gen_random_uuid())$$,'PT409','payroll_run_stale','approved run cannot be cancelled before release');
SELECT is(public.payroll_candidate_approval('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'d3009000-0000-4000-8000-000000000002','d3009100-0000-4000-8000-000000000001',2,'release','Reviewed calendar return','d3009300-0000-4000-8000-000000000001')->>'status','review','actual public release works despite current unqualified candidate');
SELECT is(public.payroll_candidate_approval('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'d3009000-0000-4000-8000-000000000002','d3009100-0000-4000-8000-000000000001',2,'release','Reviewed calendar return','d3009300-0000-4000-8000-000000000001')->>'revision','3','original release receipt recovers without another revision');
SELECT is(public.payroll_run_command('d3001000-0000-4000-8000-000000000001','d3003000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'d3009000-0000-4000-8000-000000000002',3,'cancel','Explicit post-release calendar cancellation',gen_random_uuid())->>'status','cancelled','released run can be explicitly cancelled through supported command');
SELECT is(pg_temp.workspace()->>'open_run_period_id',NULL::text,'release then cancellation clears calendar block');
RESET ROLE;
SELECT is((SELECT md5(to_jsonb(c)::text) FROM payroll.candidates c WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND id='d3009100-0000-4000-8000-000000000001'),current_setting('test.approved_candidate_digest'),'release/cancel retains exact original candidate');
SELECT is((SELECT count(*) FROM payroll.approval_events WHERE tenant_id='d3001000-0000-4000-8000-000000000001'),2::bigint,'historical approval plus one release retained without receipt duplication');
-- Stored Time-state fixtures exercise read-only warning semantics, not Time producer/legal qualification.
UPDATE time.work_instances SET status='approved' WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND id='d300a000-0000-4000-8000-000000000001';
SELECT is(pg_temp.workspace()->>'pending_attendance_date','2030-01-26','approved instance without fact remains an owned review warning');
CREATE FUNCTION pg_temp.append_warning_fact(p_version integer,p_fingerprint text) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE interpretation uuid:=gen_random_uuid();fact_id uuid:=gen_random_uuid();prior uuid;BEGIN
 SELECT id INTO prior FROM time.attendance_facts WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND work_instance_id='d300a000-0000-4000-8000-000000000001' ORDER BY version DESC LIMIT 1;
 INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d3001000-0000-4000-8000-000000000001',interpretation,'d300a000-0000-4000-8000-000000000001',p_version,'ready',p_fingerprint,'d3000000-0000-4000-8000-000000000001');
 INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id) VALUES('d3001000-0000-4000-8000-000000000001',fact_id,'d300a000-0000-4000-8000-000000000001',p_version,interpretation,prior,'Synthetic warning-source history',jsonb_build_object('outcome','worked','input_fingerprint',p_fingerprint),'d3000000-0000-4000-8000-000000000001');RETURN fact_id;
END $$;
SELECT pg_temp.append_warning_fact(1,'SYNTHETIC_STALE_SOURCE_CONTEXT');
SELECT is(pg_temp.workspace()->>'pending_attendance_date','2030-01-26','approved fact with changed current classification context warns');
SELECT set_config('test.current_warning_fact',pg_temp.append_warning_fact(2,time.work_instance_interpretation_fingerprint('d3001000-0000-4000-8000-000000000001','d300a000-0000-4000-8000-000000000001'))::text,true);
SELECT is(pg_temp.workspace()->>'pending_attendance_date',NULL::text,'current approved fact with no overtime pending does not warn');
INSERT INTO time.attendance_overtime_candidates(tenant_id,id,work_instance_id,attendance_fact_id,policy_template_id,policy_version,raw_minutes,candidate_minutes,category,actor_user_id) VALUES('d3001000-0000-4000-8000-000000000001','d300b000-0000-4000-8000-000000000001','d300a000-0000-4000-8000-000000000001',current_setting('test.current_warning_fact')::uuid,'d3008000-0000-4000-8000-000000000001',1,60,60,'ordinary','d3000000-0000-4000-8000-000000000001');
SELECT is(pg_temp.workspace()->>'pending_attendance_date','2030-01-26','unreviewed overtime on current approved fact warns');
SELECT set_config('test.current_warning_fact',pg_temp.append_warning_fact(3,time.work_instance_interpretation_fingerprint('d3001000-0000-4000-8000-000000000001','d300a000-0000-4000-8000-000000000001'))::text,true);
SELECT is(pg_temp.workspace()->>'pending_attendance_date',NULL::text,'older unreviewed overtime does not resurrect after newer authoritative fact');
INSERT INTO time.attendance_overtime_candidates(tenant_id,id,work_instance_id,attendance_fact_id,policy_template_id,policy_version,raw_minutes,candidate_minutes,category,actor_user_id) VALUES('d3001000-0000-4000-8000-000000000001','d300b000-0000-4000-8000-000000000002','d300a000-0000-4000-8000-000000000001',current_setting('test.current_warning_fact')::uuid,'d3008000-0000-4000-8000-000000000001',1,60,60,'ordinary','d3000000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id) VALUES('d3001000-0000-4000-8000-000000000001','d300b000-0000-4000-8000-000000000002','rejected','Reviewed synthetic rejection','d3000000-0000-4000-8000-000000000001');
SELECT is(pg_temp.workspace()->>'pending_attendance_date',NULL::text,'rejected current overtime is no longer pending');
SELECT set_config('test.current_warning_fact',pg_temp.append_warning_fact(4,time.work_instance_interpretation_fingerprint('d3001000-0000-4000-8000-000000000001','d300a000-0000-4000-8000-000000000001'))::text,true);
INSERT INTO time.attendance_overtime_candidates(tenant_id,id,work_instance_id,attendance_fact_id,policy_template_id,policy_version,raw_minutes,candidate_minutes,category,actor_user_id) VALUES('d3001000-0000-4000-8000-000000000001','d300b000-0000-4000-8000-000000000003','d300a000-0000-4000-8000-000000000001',current_setting('test.current_warning_fact')::uuid,'d3008000-0000-4000-8000-000000000001',1,60,60,'ordinary','d3000000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id) VALUES('d3001000-0000-4000-8000-000000000001','d300b000-0000-4000-8000-000000000003','approved','Reviewed synthetic approval','d3000000-0000-4000-8000-000000000001');
SELECT is(pg_temp.workspace()->>'pending_attendance_date','2030-01-26','approved overtime awaits explicit classification');
INSERT INTO time.attendance_overtime_classification_events(tenant_id,candidate_id,version,review_event_id,ordinary_day_minutes,ordinary_night_minutes,weekly_rest_minutes,official_holiday_minutes,reason,request_fingerprint,actor_user_id) SELECT 'd3001000-0000-4000-8000-000000000001',candidate_id,1,id,60,0,0,0,'Synthetic stored-classification state','SYNTHETIC_NONLEGAL_WARNING_ONLY','d3000000-0000-4000-8000-000000000001' FROM time.attendance_overtime_review_events WHERE tenant_id='d3001000-0000-4000-8000-000000000001' AND candidate_id='d300b000-0000-4000-8000-000000000003';
SELECT is(pg_temp.workspace()->>'pending_attendance_date',NULL::text,'explicitly classified current overtime clears only its pending warning');
SELECT is((SELECT count(*) FROM time.attendance_facts WHERE tenant_id='d3001000-0000-4000-8000-000000000001'),4::bigint,'all source fact versions retained through warning changes');
SELECT * FROM finish();
ROLLBACK;
