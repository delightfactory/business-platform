BEGIN;
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'dedicated Cube4 QA required';END IF;END $$;
SELECT no_plan();
CREATE FUNCTION pg_temp.k(x text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('cube4-time-coverage:'||x)::uuid $$;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES(pg_temp.k('actor'),'time-coverage@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) SELECT pg_temp.k(x),'Coverage '||x,pg_temp.k('actor') FROM unnest(ARRAY['tenant','foreign-tenant'])x;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES(pg_temp.k('tenant'),pg_temp.k('role'),'coverage.payroll',1,ARRAY['payroll.view','payroll.prepare','payroll.review']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES(pg_temp.k('tenant'),pg_temp.k('actor'),pg_temp.k('actor'));
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(pg_temp.k('tenant'),pg_temp.k('actor'),pg_temp.k('role'));
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) SELECT pg_temp.k('tenant'),x,true,now()-interval '1 minute',pg_temp.k('actor'),'Coverage QA' FROM unnest(ARRAY['hr.people','hr.payroll'])x;
DO $$ DECLARE n text;t uuid;e uuid;BEGIN
 FOREACH n IN ARRAY ARRAY['a','b','foreign'] LOOP
  t:=pg_temp.k(CASE WHEN n='foreign' THEN 'foreign-tenant' ELSE 'tenant' END);e:=pg_temp.k('employer-'||n);
  INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES(t,e,'PRIVATE EMPLOYER '||n,'PRIVATE LEGAL '||n);
  INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES(t,pg_temp.k('site-'||n),e,'PRIVATE SITE',false);
  INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES(t,pg_temp.k('employee-'||n),'COVER-'||n,'PRIVATE EMPLOYEE',pg_temp.k('actor'));
  INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,end_date,employment_status,pay_basis) VALUES(t,pg_temp.k('employment-'||n),pg_temp.k('employee-'||n),e,'2025-01-01','2025-01-12','ended','daily');
  INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES(t,pg_temp.k('policy-'||n),'COVERAGE-'||upper(n),3);
  INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by)
   VALUES(t,pg_temp.k('policy-'||n),1,'PRIVATE POLICY V1','fixed','UTC',ARRAY[2,3,4,5,6]::smallint[],'08:00','16:00',pg_temp.k('actor')),
    (t,pg_temp.k('policy-'||n),2,'PRIVATE POLICY V2','fixed','UTC',ARRAY[2,3,4,5,6]::smallint[],'09:00','17:00',pg_temp.k('actor'));
  INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by)
   VALUES(t,pg_temp.k('policy-'||n),3,'PRIVATE FLEX POLICY','flexible','UTC',ARRAY[1,2,3,4,5,6,7]::smallint[],400,'09:00','17:00',pg_temp.k('actor'));
  INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from,valid_until)
   VALUES(t,pg_temp.k('assignment1-'||n),pg_temp.k('employment-'||n),pg_temp.k('site-'||n),pg_temp.k('policy-'||n),1,'2025-01-01','2025-01-09'),
    (t,pg_temp.k('assignment2-'||n),pg_temp.k('employment-'||n),pg_temp.k('site-'||n),pg_temp.k('policy-'||n),2,'2025-01-09',NULL);
  INSERT INTO time.work_policy_overrides(tenant_id,id,employment_id,policy_template_id,policy_version,valid_from,valid_until,reason,created_by)
   VALUES(t,pg_temp.k('override-'||n),pg_temp.k('employment-'||n),pg_temp.k('policy-'||n),3,'2025-01-10','2025-01-11','PRIVATE OVERRIDE REASON',pg_temp.k('actor'));
 END LOOP;
END $$;
-- Scope A: pending Tuesday; approved Wednesday; off-schedule Sunday remains visible.
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by)
SELECT pg_temp.k('tenant'),pg_temp.k('wi-'||d),pg_temp.k(CASE WHEN d<DATE '2025-01-09' THEN 'assignment1-a' ELSE 'assignment2-a' END),pg_temp.k('employment-a'),pg_temp.k('employee-a'),pg_temp.k('site-a'),d,pg_temp.k('policy-a'),CASE WHEN d<DATE '2025-01-09' THEN 1 ELSE 2 END,'UTC',
 (d+CASE WHEN d<DATE '2025-01-09' THEN TIME '08:00' ELSE TIME '09:00' END) AT TIME ZONE 'UTC',
 (d+CASE WHEN d<DATE '2025-01-09' THEN TIME '16:00' ELSE TIME '17:00' END) AT TIME ZONE 'UTC',
 (d+CASE WHEN d<DATE '2025-01-09' THEN TIME '06:00' ELSE TIME '07:00' END) AT TIME ZONE 'UTC',
 (d+CASE WHEN d<DATE '2025-01-09' THEN TIME '22:00' ELSE TIME '23:00' END) AT TIME ZONE 'UTC',
 CASE WHEN d=DATE '2025-01-08' THEN 'approved' ELSE 'ready' END,pg_temp.k('actor')
FROM unnest(ARRAY[DATE '2025-01-07',DATE '2025-01-08',DATE '2025-01-12'])d;
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by)
 VALUES(pg_temp.k('tenant'),pg_temp.k('interp-2025-01-08'),pg_temp.k('wi-2025-01-08'),1,'ready',time.work_instance_interpretation_fingerprint(pg_temp.k('tenant'),pg_temp.k('wi-2025-01-08')),pg_temp.k('actor'));
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
 VALUES(pg_temp.k('tenant'),pg_temp.k('fact-2025-01-08'),pg_temp.k('wi-2025-01-08'),1,pg_temp.k('interp-2025-01-08'),'{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[],"observations":{"private":"DO NOT PROJECT"}}',pg_temp.k('actor'));
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES(pg_temp.k('tenant'),pg_temp.k('salary'),pg_temp.k('employment-a'),100,'2025-01-01');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'),1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('calendar'),1,'2025-01-01',12,13,'ending','UTC',pg_temp.k('actor'),'Coverage calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period'),pg_temp.k('calendar'),'2025-01-05','2025-01-12','2025-01-13','UTC','Coverage fixture',false,pg_temp.k('actor'));
CREATE FUNCTION pg_temp.coverage(f date DEFAULT '2025-01-05',u date DEFAULT '2025-01-12',employer text DEFAULT 'employer-a',tenant text DEFAULT 'tenant') RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT payroll.capture_time_coverage_window(pg_temp.k(tenant),pg_temp.k(employer),f,u) $$;
CREATE FUNCTION pg_temp.manifest() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT payroll.run_manifest(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period')) $$;
CREATE FUNCTION pg_temp.counts() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT jsonb_build_array((SELECT count(*) FROM time.work_instances),(SELECT count(*) FROM time.attendance_facts),(SELECT count(*) FROM time.attendance_audit_events),(SELECT count(*) FROM payroll.candidates),(SELECT count(*) FROM payroll.final_contexts),(SELECT count(*) FROM payroll.payment_events),(SELECT count(*) FROM payroll.audit_events),(SELECT count(*) FROM leave.requests),(SELECT count(*) FROM leave.ledger_entries)) $$;
CREATE FUNCTION pg_temp.day(c jsonb,d date) RETURNS jsonb LANGUAGE sql AS $$ SELECT x FROM jsonb_array_elements(c->'items')x WHERE x->>'employment_id'=pg_temp.k('employment-a')::text AND x->>'date'=d::text $$;
GRANT EXECUTE ON FUNCTION pg_temp.k(text),pg_temp.coverage(date,date,text,text),pg_temp.manifest(),pg_temp.counts() TO authenticated;
SELECT set_config('request.jwt.claim.sub',pg_temp.k('actor')::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.counts',pg_temp.counts()::text,true);
SELECT is(pg_temp.coverage(),'{"enabled":false,"items":[]}'::jsonb,'disabled Time returns empty before schedule scans even with existing private source records');
SELECT throws_ok($$SELECT payroll.capture_time_coverage_window(pg_temp.k('tenant'),pg_temp.k('employer-a'),'2025-01-05','2025-01-12')$$,'42501',NULL,'private coverage cannot be directly invoked by ordinary caller');
SELECT throws_ok($$SELECT pg_temp.coverage(employer=>'employer-foreign',tenant=>'foreign-tenant')$$,'42501','payroll_forbidden','current Payroll authority cannot cross Tenant');
SELECT throws_ok($$SELECT pg_temp.coverage(employer=>'employer-foreign')$$,'P0002','payroll_employer_unavailable','Employer identity is scoped to Tenant');
RESET ROLE;
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES(pg_temp.k('tenant'),'hr.attendance',true,now()-interval '1 minute',pg_temp.k('actor'),'Coverage enabled');
SET LOCAL ROLE authenticated;
SELECT set_config('test.coverage',pg_temp.coverage()::text,true);
SELECT set_config('test.manifest',pg_temp.manifest()::text,true);
RESET ROLE;
SELECT is(jsonb_array_length(current_setting('test.coverage')::jsonb->'items'),8,'eight eligible dates captured exhaustively for Employer A, excluding B and foreign Tenant');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-05')->>'state','scheduled_nonworkday','Sunday resolves nonworking from pinned weekdays, not absence of facts');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-06')->>'state','expected_instance_missing','expected Monday missing Work Instance is visible');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-07')->>'state','instance_open_or_pending','pending existing instance is not projected as approved or zero');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-08')->>'state','approved_fact_current','current approved fact and classification satisfy observational day');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-09')->'provenance'->'policy'->>'version','2','exclusive Assignment boundary chooses v2 and never current head v3');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-10')->'provenance'->'policy'->>'version','3','dated active override pins its own exact flexible version');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-11')->'provenance'->'policy'->>'version','2','exclusive override end restores dated Assignment policy');
SELECT is(pg_temp.day(current_setting('test.coverage')::jsonb,'2025-01-12')->>'state','off_schedule_materialized','materialized nonworking day is retained for owned review');
SELECT is(jsonb_array_length(pg_temp.coverage('2025-01-12','2025-01-13')->'items'),1,'Employment end inclusive; following day outside Employment is excluded');
SELECT is(pg_temp.coverage(),current_setting('test.coverage')::jsonb,'unchanged sources and elapsed states produce exact stable capture');
SELECT is(pg_temp.manifest(),current_setting('test.manifest')::jsonb,'whole manifest repeat remains canonical without raw refreshed now');
SELECT ok(current_setting('test.manifest')::jsonb->'optional_sources'->'time'?'coverage','actual manifest captures coverage via existing optional source boundary');
SELECT ok(NOT(current_setting('test.coverage')::jsonb)::text ~ 'PRIVATE|DO NOT PROJECT|reason|observations|leave_sources|full_name','private snapshot is purpose-limited provenance without raw sensitive source fields');
SELECT is(payroll.time_coverage_explanation(current_setting('test.coverage')::jsonb,pg_temp.k('employment-a'))->'summary'->>'missing_days','3','summary counts Monday, Thursday and overridden Friday missing obligations');
SELECT ok(NOT(payroll.time_coverage_explanation(current_setting('test.coverage')::jsonb,pg_temp.k('employment-a')))::text ~ 'provenance|assignment_id|policy_template|employee_id|request_id','public explanation contains counts and safe dates without IDs');
SELECT is(pg_temp.counts(),current_setting('test.counts')::jsonb,'observational capture performs no source/financial/audit/Leave writes');
SELECT throws_ok($$SELECT pg_temp.coverage('2025-01-01','2025-02-01')$$,'22023','payroll_optional_window_invalid','32 inclusive dates require multiple bounded windows');
SELECT throws_ok($$SELECT pg_temp.coverage('-infinity','2025-01-01')$$,'22023','payroll_optional_window_invalid','nonfinite date refused before grid generation');
SELECT throws_ok($$SELECT pg_temp.coverage('0001-01-01 BC','0001-01-02 BC')$$,'22023','payroll_optional_window_invalid','outside ISO dates refused');
SELECT is(payroll.time_expected_bounds('2025-03-09','{"schedule_kind":"fixed","timezone_name":"America/New_York","work_days":[1],"shift_start":"02:30","shift_end":"04:00","ends_next_day":false,"attribution_before_minutes":0,"attribution_after_minutes":0}')->>'state','schedule_window_ambiguous','canonical nonexistent DST start is held');
SELECT is(payroll.time_expected_bounds('2025-11-02','{"schedule_kind":"fixed","timezone_name":"America/New_York","work_days":[1],"shift_start":"01:30","shift_end":"04:00","ends_next_day":false,"attribution_before_minutes":0,"attribution_after_minutes":0}')->>'state','schedule_window_ambiguous','canonical ambiguous DST start is held');
-- A distinct future Employment has no Assignment first, then an exact flexible schedule. No future zero/absence is fabricated.
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES(pg_temp.k('tenant'),pg_temp.k('future-employee'),'COVER-FUTURE','PRIVATE FUTURE EMPLOYEE',pg_temp.k('actor'));
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,end_date,employment_status,pay_basis) VALUES(pg_temp.k('tenant'),pg_temp.k('future-employment'),pg_temp.k('future-employee'),pg_temp.k('employer-a'),'2099-01-01','2099-02-05','ended','daily');
SELECT is(pg_temp.coverage('2099-01-01','2099-01-01')->'items'->0->>'state','schedule_context_missing_or_ambiguous','missing Assignment is unknown schedule, not a nonworking date');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES(pg_temp.k('tenant'),pg_temp.k('future-assignment'),pg_temp.k('future-employment'),pg_temp.k('site-a'),pg_temp.k('policy-a'),3,'2099-01-01');
SELECT is(pg_temp.coverage('2099-01-01','2099-01-01')->'items'->0->>'state','not_yet_elapsed','future flexible attribution window is not a missing approved fact');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period32'),pg_temp.k('calendar'),'2099-01-01','2099-02-01','2099-02-02','UTC','Coverage tiling only',true,pg_temp.k('actor'));
SELECT set_config('test.tiled',payroll.capture_time_coverage(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period32'))::text,true);
SELECT is(jsonb_array_length(current_setting('test.tiled')::jsonb->'items'),32,'period integration preserves exact nonempty rows across 31-day and second windows');
SELECT is(ARRAY(SELECT x->>'date' FROM jsonb_array_elements(current_setting('test.tiled')::jsonb->'items')x),ARRAY(SELECT d::date::text FROM generate_series(DATE '2099-01-01',DATE '2099-02-01',interval '1 day')d),'tiled inclusive dates are ordered with no window gap or duplicate');
-- Changed source identities invalidate the whole optional snapshot even when the public approved-fact list stays unchanged.
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by)
 VALUES(pg_temp.k('tenant'),pg_temp.k('wi-2025-01-06'),pg_temp.k('assignment1-a'),pg_temp.k('employment-a'),pg_temp.k('employee-a'),pg_temp.k('site-a'),'2025-01-06',pg_temp.k('policy-a'),1,'UTC','2025-01-06 08:00+00','2025-01-06 16:00+00','2025-01-06 06:00+00','2025-01-06 22:00+00','open',pg_temp.k('actor'));
SELECT is(pg_temp.day(pg_temp.coverage(),'2025-01-06')->>'state','instance_open_or_pending','materializing an expected missing day changes its observational state');
SELECT ok(payroll.stale_reasons(current_setting('test.manifest')::jsonb,pg_temp.manifest())?'optional_sources_changed','new pending instance invalidates canonical snapshot without approved monetary input');
SELECT set_config('test.before_cancel',pg_temp.manifest()::text,true);
UPDATE time.work_policy_overrides SET cancelled_at=now(),cancelled_by=pg_temp.k('actor'),cancel_reason='Reviewed fixture cancellation' WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('override-a');
SELECT is(pg_temp.day(pg_temp.coverage(),'2025-01-10')->'provenance'->'policy'->>'version','2','cancelled override returns exact dated Assignment policy without current-head fallback');
SELECT ok(payroll.stale_reasons(current_setting('test.before_cancel')::jsonb,pg_temp.manifest())?'optional_sources_changed','override cancellation changes canonical provenance and stales review');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES(pg_temp.k('tenant'),pg_temp.k('new-unapproved-interpretation'),pg_temp.k('wi-2025-01-08'),2,'needs_review',time.work_instance_interpretation_fingerprint(pg_temp.k('tenant'),pg_temp.k('wi-2025-01-08')),pg_temp.k('actor'));
SELECT is(pg_temp.day(pg_temp.coverage(),'2025-01-08')->>'state','approved_fact_not_current','a newer unapproved interpretation cannot replace the approved source or prove current coverage');
SELECT set_config('test.math_manifest',(pg_temp.manifest()||jsonb_build_object('inputs',jsonb_build_array(jsonb_build_object('head',jsonb_build_object('kind','policy','id',pg_temp.k('math-policy')),'version',jsonb_build_object('revision',1,'effective_from','2025-01-01','status','draft','data','{"mode":"calendar_days"}'::jsonb)))))::text,true);
SELECT is((payroll.build_review(current_setting('test.math_manifest')::jsonb)->>'known_gross')::numeric,(payroll.build_review(current_setting('test.math_manifest')::jsonb#-'{optional_sources,time,coverage}')->>'known_gross')::numeric,'observational coverage metadata does not change known monetary arithmetic');
SELECT is(payroll.build_review(current_setting('test.math_manifest')::jsonb)->>'financially_qualified','false','observational coverage never qualifies statutory net or finalization');
SELECT ok(payroll.build_review(current_setting('test.math_manifest')::jsonb)->'issues' @> '[{"code":"time_integration_pending"}]','existing Time financial integration gate remains');
CREATE FUNCTION pg_temp.capacity_probe() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
 SELECT pg_temp.k('tenant'),pg_temp.k('capacity-e-'||n),'CAPACITY-'||n,'PRIVATE CAPACITY',pg_temp.k('actor') FROM generate_series(1,650)n;
 INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis)
 SELECT pg_temp.k('tenant'),pg_temp.k('capacity-h-'||n),pg_temp.k('capacity-e-'||n),pg_temp.k('employer-a'),'2025-01-01','daily' FROM generate_series(1,650)n;
 RETURN payroll.capture_time_coverage_window(pg_temp.k('tenant'),pg_temp.k('employer-a'),'2025-01-01','2025-01-31');
END $$;
SELECT throws_ok($$SELECT pg_temp.capacity_probe()$$,'54000','payroll_capacity_review_required','eligible date-grid overflow refuses before materializing days');
SELECT is((SELECT count(*)::integer FROM people.employees WHERE tenant_id=pg_temp.k('tenant') AND employee_code LIKE 'CAPACITY-%'),0,'overflow fixture subtransaction rolls back all source inserts');
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id=pg_temp.k('tenant') AND user_id=pg_temp.k('actor');
SELECT throws_ok($$SELECT pg_temp.coverage()$$,'42501','payroll_forbidden','previous capture does not bypass inactive current membership');
UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id=pg_temp.k('tenant') AND user_id=pg_temp.k('actor');
SELECT ok(NOT has_function_privilege('service_role','payroll.capture_time_coverage(uuid,uuid,uuid)','EXECUTE') AND NOT has_function_privilege('anon','payroll.time_expected_bounds(date,jsonb)','EXECUTE'),'new helpers retain narrow private ACLs');
-- Reader-only synthetic NONLEGAL candidate. Candidate rows are isolated AFTER the observational no-write assertion.
-- No calculated-final qualification, public lock, final context or source consumption is fabricated.
SELECT set_config('test.public_output',payroll.build_review(current_setting('test.math_manifest')::jsonb)::text,true);
SELECT set_config('test.safe_coverage_days','[
 {"date":"2025-01-05","expected":false,"elapsed":null,"state":"scheduled_nonworkday"},
 {"date":"2025-01-06","expected":true,"elapsed":true,"state":"instance_open_or_pending"},
 {"date":"2025-01-07","expected":true,"elapsed":true,"state":"instance_open_or_pending"},
 {"date":"2025-01-08","expected":true,"elapsed":true,"state":"approved_fact_not_current"},
 {"date":"2025-01-09","expected":true,"elapsed":true,"state":"expected_instance_missing"},
 {"date":"2025-01-10","expected":true,"elapsed":true,"state":"expected_instance_missing"},
 {"date":"2025-01-11","expected":false,"elapsed":null,"state":"scheduled_nonworkday"},
 {"date":"2025-01-12","expected":false,"elapsed":null,"state":"off_schedule_materialized"}
]',true);
SELECT is(current_setting('test.public_output')::jsonb->'employees'->0->'source_summary'->'time_coverage',
 '{"enabled":true,"status":"needs_source_review","day_count":8,"expected_days":5,"approved_days":0,"missing_days":2,"pending_days":3,"future_days":0,"other_review_days":1,"payroll_ready":false}'::jsonb,
 'actual builder exposes bounded coverage counts/status without implying Payroll readiness');
SELECT is(current_setting('test.public_output')::jsonb->'employees'->0->'source_coverage_days',current_setting('test.safe_coverage_days')::jsonb,
 'actual builder preserves exact safe date/state coverage explanation');
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,revision,status,created_by)
 VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period'),pg_temp.k('reader-run'),1,'review',pg_temp.k('actor'));
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by)
 VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('reader-run'),pg_temp.k('reader-candidate'),1,'cube4-review-v4-daily-sources',
 current_setting('test.math_manifest')::jsonb,current_setting('test.public_output')::jsonb,pg_temp.k('actor'));
UPDATE payroll.runs SET candidate_id=pg_temp.k('reader-candidate'),revision=revision+1 WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('reader-run');
SET LOCAL ROLE authenticated;
SELECT set_config('test.public_list',public.payroll_run_workspace(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period'),NULL,30,NULL,'')::text,true);
SELECT set_config('test.public_detail',public.payroll_run_workspace(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period'),NULL,30,pg_temp.k('employment-a'),'')::text,true);
SELECT ok(jsonb_array_length(current_setting('test.public_list')::jsonb->'employees')=1
 AND NOT(current_setting('test.public_list')::jsonb->'employees'->0 ? 'source_days')
 AND NOT(current_setting('test.public_list')::jsonb->'employees'->0 ? 'source_coverage_days'),
 'actual authorized public list omits both daily arrays instead of returning whole-company details');
SELECT is(current_setting('test.public_list')::jsonb->'employees'->0->'source_summary'->'time_coverage',
 current_setting('test.public_output')::jsonb->'employees'->0->'source_summary'->'time_coverage',
 'actual public list retains compact builder coverage summary');
SELECT is(current_setting('test.public_detail')::jsonb->'detail'->'source_coverage_days',current_setting('test.safe_coverage_days')::jsonb,
 'actual selected public detail retains safe dates/states under current Payroll authority');
SELECT ok(NOT(current_setting('test.public_list')||current_setting('test.public_detail')) ~ '"(provenance|latest_fact|latest_interpretation|classification_evidence_id|policy_template_id|work_instance_id|assignment_id|input_manifest|overrides|instances)"'
 AND position('DO NOT PROJECT' IN current_setting('test.public_list')||current_setting('test.public_detail'))=0
 AND position('PRIVATE OVERRIDE REASON' IN current_setting('test.public_list')||current_setting('test.public_detail'))=0,
 'all actual public reader payloads exclude raw coverage provenance and sensitive source canaries');
SELECT throws_ok($$SELECT public.payroll_run_workspace(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('period'),NULL,30,pg_temp.k('employment-b'),'')$$,
 '42501','payroll_forbidden','selected detail cannot cross the candidate Employer scope');
RESET ROLE;
SELECT ok(NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=pg_temp.k('tenant'))
 AND NOT EXISTS(SELECT 1 FROM payroll.people_frozen_contexts WHERE tenant_id=pg_temp.k('tenant'))
 AND NOT EXISTS(SELECT 1 FROM payroll.payment_events WHERE tenant_id=pg_temp.k('tenant')),
 'reader-only NONLEGAL candidate fixture creates no finals, People consumption or payment evidence');
SELECT * FROM finish();
ROLLBACK;
