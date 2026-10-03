BEGIN;
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'dedicated Cube4 QA required';END IF;END $$;
SELECT no_plan();
-- Synthetic direct seed shapes only. No fixture source guard is disabled; everything rolls back.
CREATE FUNCTION pg_temp.k(label text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('cube4-optional-capture:'||label)::uuid $$;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES(pg_temp.k('actor'),'optional-capture@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
SELECT pg_temp.k(x),'Capture '||x,pg_temp.k('actor') FROM unnest(ARRAY['tenant','other-tenant'])x;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES(pg_temp.k('tenant'),pg_temp.k('role'),'capture.payroll.only',1,ARRAY['payroll.prepare','payroll.review','payroll.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES(pg_temp.k('tenant'),pg_temp.k('actor'),pg_temp.k('actor'));
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(pg_temp.k('tenant'),pg_temp.k('actor'),pg_temp.k('role'));
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT pg_temp.k('tenant'),x,true,now()-interval '1 minute',pg_temp.k('actor'),'Synthetic capture fixture' FROM unnest(ARRAY['hr.people','hr.payroll'])x;
DO $$ DECLARE name text;t uuid;e uuid;BEGIN
 FOREACH name IN ARRAY ARRAY['a','b','foreign'] LOOP
 t:=pg_temp.k(CASE WHEN name='foreign' THEN 'other-tenant' ELSE 'tenant' END);e:=pg_temp.k('employer-'||name);
 INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES(t,e,'PRIVATE EMPLOYER '||name,'PRIVATE LEGAL '||name);
 -- Legal Entity trigger may create default site. This separate scoped site is explicitly non-default.
 INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES(t,pg_temp.k('site-'||name),e,'PRIVATE SITE',false);
 INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES(t,pg_temp.k('employee-'||name),'CAP-'||name,'PRIVATE EMPLOYEE',pg_temp.k('actor'));
 INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES(t,pg_temp.k('employment-'||name),pg_temp.k('employee-'||name),e,'2030-01-01','monthly');
 INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES(t,pg_temp.k('assignment-'||name),pg_temp.k('employment-'||name),pg_temp.k('site-'||name),'2030-01-01');
 INSERT INTO time.work_policy_templates(tenant_id,id,code) VALUES(t,pg_temp.k('policy-'||name),'CAPTURE-'||upper(name));
 INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,work_days,shift_start,shift_end,created_by)
 VALUES(t,pg_temp.k('policy-'||name),1,'PRIVATE POLICY','fixed',ARRAY[1,2,3,4,5,6,7]::smallint[],'08:00','16:00',pg_temp.k('actor'));
 INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,status,created_by)
 SELECT t,pg_temp.k('wi-'||name||d::date),pg_temp.k('assignment-'||name),pg_temp.k('employment-'||name),pg_temp.k('employee-'||name),pg_temp.k('site-'||name),d::date,pg_temp.k('policy-'||name),1,'Africa/Cairo','approved',pg_temp.k('actor')
 FROM generate_series('2030-01-01'::date,'2030-06-05'::date,interval '1 day')d;
 INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by)
 SELECT t,pg_temp.k('interp-'||name||i.operational_date),i.id,1,'ready',time.work_instance_interpretation_fingerprint(t,i.id),pg_temp.k('actor') FROM time.work_instances i WHERE i.tenant_id=t AND i.employee_id=pg_temp.k('employee-'||name);
 INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
 SELECT t,pg_temp.k('fact-'||name||i.operational_date),i.id,1,pg_temp.k('interp-'||name||i.operational_date),jsonb_build_object('outcome','worked','worked_minutes',480,'absence_units',0,'leave_units',0,'correction_reason','PRIVATE FACT REASON','leave_sources',jsonb_build_array(jsonb_build_object('request_id',pg_temp.k('request-'||name),'approved_preview_version',1,'leave_date',i.operational_date,'units',0,'leave_type_name','PRIVATE CLINICAL TYPE','reason','PRIVATE LEAVE REASON')),'observations',jsonb_build_object('secret','PRIVATE OBSERVATION')),pg_temp.k('actor')
 FROM time.work_instances i WHERE i.tenant_id=t AND i.employee_id=pg_temp.k('employee-'||name);
 INSERT INTO leave.calendars(tenant_id,id,employer_entity_id,code,name) VALUES(t,pg_temp.k('lc-'||name),e,'capture','PRIVATE CALENDAR');
 INSERT INTO leave.calendar_versions(tenant_id,id,calendar_id,version,effective_from,source,reason,created_by) VALUES(t,pg_temp.k('lcv-'||name),pg_temp.k('lc-'||name),1,'2030-01-01','PRIVATE SOURCE','PRIVATE CALENDAR REASON',pg_temp.k('actor'));
 INSERT INTO leave.year_periods(tenant_id,id,employer_entity_id,calendar_id,starts_on,ends_on,label,created_by) VALUES(t,pg_temp.k('ly-'||name),e,pg_temp.k('lc-'||name),'2030-01-01','2030-12-31','PRIVATE YEAR',pg_temp.k('actor'));
 INSERT INTO leave.types(tenant_id,id,employer_entity_id,code,name) VALUES(t,pg_temp.k('lt-'||name),e,'capture','PRIVATE CLINICAL TYPE');
 INSERT INTO leave.type_versions(tenant_id,id,leave_type_id,version,effective_from,pay_effect,balance_mode,day_count_basis,source,reason,created_by) VALUES(t,pg_temp.k('ltv-'||name),pg_temp.k('lt-'||name),1,'2030-01-01','paid','untracked','calendar_days','PRIVATE SOURCE','PRIVATE TYPE REASON',pg_temp.k('actor'));
 -- Start submitted to satisfy immediate approved-preview FK, then use the valid approval transition.
 INSERT INTO leave.requests(tenant_id,id,employee_id,employment_id,employer_entity_id,leave_type_id,start_date,end_date,request_source,created_by,submitted_by,reason)
 VALUES(t,pg_temp.k('request-'||name),pg_temp.k('employee-'||name),pg_temp.k('employment-'||name),e,pg_temp.k('lt-'||name),'2030-01-01','2030-06-05','hr',pg_temp.k('actor'),pg_temp.k('actor'),'PRIVATE REQUEST REASON');
 INSERT INTO leave.request_previews(tenant_id,request_id,preview_version,total_units,created_by) VALUES(t,pg_temp.k('request-'||name),1,156,pg_temp.k('actor'));
 INSERT INTO leave.request_days(tenant_id,request_id,preview_version,leave_date,employer_entity_id,year_period_id,calendar_version_id,leave_type_id,type_version_id,day_count_basis,pay_effect,balance_mode,is_weekly_rest,holiday_name,eligible,units)
 SELECT t,pg_temp.k('request-'||name),1,d::date,e,pg_temp.k('ly-'||name),pg_temp.k('lcv-'||name),pg_temp.k('lt-'||name),pg_temp.k('ltv-'||name),'calendar_days','paid','untracked',false,'PRIVATE HOLIDAY',true,1 FROM generate_series('2030-01-01'::date,'2030-06-05'::date,interval '1 day')d;
 UPDATE leave.requests SET state='approved',version=2,approved_by=pg_temp.k('actor'),approved_at=now(),approved_preview_version=1 WHERE tenant_id=t AND id=pg_temp.k('request-'||name);
 END LOOP;
END $$;
INSERT INTO payroll.calendar_heads(tenant_id,employer_id) VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'));
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('calendar'),1,'2030-01-01',31,1,'following','Africa/Cairo',pg_temp.k('actor'),'Synthetic source windows');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
SELECT pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k(name),pg_temp.k('calendar'),starts,ends,ends+1,'Africa/Cairo',name,true,pg_temp.k('actor') FROM(VALUES('p31','2030-01-01'::date,'2030-01-31'::date),('p32','2030-02-01'::date,'2030-03-04'::date),('p93','2030-03-05'::date,'2030-06-05'::date),('oversize','2031-01-01'::date,'2032-01-02'::date))v(name,starts,ends);
-- Test-only definer bridges model existing private-manifest invocation, with real auth.uid/current authority.
-- Production helpers are never granted to any caller role.
CREATE FUNCTION pg_temp.manifest(period text DEFAULT 'p31',tenant text DEFAULT 'tenant',employer text DEFAULT 'employer-a') RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT payroll.run_manifest(pg_temp.k(tenant),pg_temp.k(employer),pg_temp.k(period)) $$;
CREATE FUNCTION pg_temp.snapshot() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT jsonb_build_array((SELECT count(*) FROM time.attendance_facts),(SELECT count(*) FROM time.attendance_audit_events),(SELECT count(*) FROM leave.requests),(SELECT count(*) FROM leave.ledger_entries),(SELECT count(*) FROM leave.request_events),(SELECT count(*) FROM payroll.candidates),(SELECT count(*) FROM payroll.final_contexts),(SELECT count(*) FROM payroll.payment_events),(SELECT count(*) FROM payroll.audit_events)) $$;
GRANT EXECUTE ON FUNCTION pg_temp.k(text),pg_temp.manifest(text,text,text),pg_temp.snapshot() TO authenticated;
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_proc p WHERE p.pronamespace='payroll'::regnamespace AND p.proname IN('optional_capture_authorized','capture_quantity','capture_time_window','capture_leave_window','capture_optional_sources') AND p.prosecdef),'all new capture helpers are invoker');
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_proc p CROSS JOIN unnest(ARRAY['anon','authenticated','service_role'])r WHERE p.pronamespace='payroll'::regnamespace AND p.proname IN('optional_capture_authorized','capture_quantity','capture_time_window','capture_leave_window','capture_optional_sources') AND has_function_privilege(r,p.oid,'EXECUTE')),'private execute revoked for every external role');
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl)a WHERE p.pronamespace='payroll'::regnamespace AND p.proname IN('optional_capture_authorized','capture_quantity','capture_time_window','capture_leave_window','capture_optional_sources') AND a.grantee=0),'no PUBLIC execute');
SELECT set_config('request.jwt.claim.sub',pg_temp.k('actor')::text,true);
SELECT ok(NOT platform_private.has_tenant_permission(pg_temp.k('tenant'),pg_temp.k('actor'),'leave.view') AND NOT platform_private.has_tenant_permission(pg_temp.k('tenant'),pg_temp.k('actor'),'attendance.view'),'fixture actor is Payroll-only without source permission');
SET LOCAL ROLE authenticated;
SELECT set_config('test.counts',pg_temp.snapshot()::text,true);
SELECT set_config('test.disabled',pg_temp.manifest()::text,true);
SELECT is(current_setting('test.disabled')::jsonb->'optional_sources'->'time','{"enabled":false,"items":[]}'::jsonb,'disabled Attendance is explicit empty');
SELECT is(current_setting('test.disabled')::jsonb->'optional_sources'->'leave','{"enabled":false,"items":[]}'::jsonb,'disabled Leave is independent of existing source rows');
SELECT throws_ok($$SELECT public.leave_payroll_facts(pg_temp.k('tenant'),pg_temp.k('employer-a'),'2030-01-01','2030-01-31')$$,'42501',NULL,'Payroll actor retains denial at unrelated Leave public API');
SELECT throws_ok($$SELECT payroll.capture_optional_sources(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('p31'))$$,'42501',NULL,'ordinary caller cannot invoke private capture');
SELECT throws_ok($$SELECT pg_temp.manifest('p31','other-tenant','employer-foreign')$$,'42501','payroll_forbidden','out-of-Tenant authority denied');
SELECT throws_ok($$SELECT pg_temp.manifest('p31','tenant','employer-foreign')$$,'P0002','payroll_employer_unavailable','foreign Employer does not join through tenant');
SELECT throws_ok($$SELECT pg_temp.manifest('oversize')$$,'54000','payroll_capacity_review_required','oversize period refuses whole snapshot');
SELECT is(pg_temp.snapshot(),current_setting('test.counts')::jsonb,'disabled reads and denials have no source/financial/audit writes');
RESET ROLE;
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT pg_temp.k('tenant'),x,true,now()-interval '1 minute',pg_temp.k('actor'),'Synthetic capture enabled' FROM unnest(ARRAY['hr.attendance','hr.leave'])x;
SET LOCAL ROLE authenticated;
SELECT set_config('test.before',pg_temp.manifest()::text,true);
SELECT is(jsonb_array_length(current_setting('test.before')::jsonb->'optional_sources'->'time'->'items'),31,'31 days exhaustively captured for scoped Employment');
SELECT is(jsonb_array_length(current_setting('test.before')::jsonb->'optional_sources'->'leave'->'items'),31,'approved Leave preview has every scoped day');
SELECT is(jsonb_array_length(pg_temp.manifest('p32')->'optional_sources'->'windows'),2,'32-day period uses two windows');
SELECT is(jsonb_array_length(pg_temp.manifest('p32')->'optional_sources'->'time'->'items'),32,'second window first day is not lost');
SELECT is(jsonb_array_length(pg_temp.manifest('p93')->'optional_sources'->'windows'),3,'93-day transition uses three complete windows');
SELECT is(jsonb_array_length(pg_temp.manifest('p93')->'optional_sources'->'leave'->'items'),93,'long transition exhausts all Leave rows without public pagination');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.manifest('p93')->'optional_sources'->'time'->'items')i WHERE i->>'employment_id'<>pg_temp.k('employment-a')::text),'same-Tenant other Employer and foreign source are excluded');
SELECT ok(NOT(current_setting('test.before')::jsonb->'optional_sources')::text LIKE '%PRIVATE%','privacy canaries from reasons/names/types/holiday/observations are absent');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.before')::jsonb->'optional_sources'->'time'->'items')i WHERE i?'leave_sources' OR i?'observations' OR i?'correction_reason'),'raw Attendance source JSON is not serialized');
SELECT ok(NOT EXISTS(SELECT 1 FROM generate_series('2030-03-05'::date,'2030-06-05'::date,interval '1 day')d WHERE(SELECT count(*) FROM jsonb_array_elements(pg_temp.manifest('p93')->'optional_sources'->'time'->'items')i WHERE(i->>'date')::date=d::date)<>1),'every inclusive long-period date is captured exactly once without window gaps');
SELECT is(pg_temp.manifest(),current_setting('test.before')::jsonb,'canonical order is deterministic');
SELECT is(pg_temp.snapshot(),current_setting('test.counts')::jsonb,'enabled manifest reads do not write any source/financial/audit evidence');
RESET ROLE;
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(pg_temp.manifest())->'issues')i WHERE i->>'code'='time_integration_pending') AND EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(pg_temp.manifest())->'issues')i WHERE i->>'code'='leave_integration_pending'),'source capture does not remove financial integration blockers');
SELECT ok((current_setting('test.before')::jsonb->'optional_sources'->'time'->'items'->0->>'classification_reconciliation_required')::boolean,'current canonical Time context detects subsequently approved Leave');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id=pg_temp.k('tenant') AND capability_key='hr.leave';
SELECT set_config('test.timeonly',pg_temp.manifest()::text,true);
SELECT is(jsonb_array_length(current_setting('test.timeonly')::jsonb->'optional_sources'->'time'->'items'),31,'Attendance works without enabled Leave or Leave permissions');
SELECT is(current_setting('test.timeonly')::jsonb->'optional_sources'->'leave','{"enabled":false,"items":[]}'::jsonb,'disabled Leave has no independent capture beside canonical Time reconciliation');
SELECT ok(NOT(current_setting('test.timeonly')::jsonb->'optional_sources')::text LIKE '%PRIVATE%','transitive Time context exposes no clinical or narrative facts');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=true WHERE tenant_id=pg_temp.k('tenant') AND capability_key='hr.leave';
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id=pg_temp.k('tenant') AND capability_key='hr.attendance';
SELECT is(pg_temp.manifest()->'optional_sources'->'time','{"enabled":false,"items":[]}'::jsonb,'Leave can capture independently while Attendance is disabled');
SELECT is(jsonb_array_length(pg_temp.manifest()->'optional_sources'->'leave'->'items'),31,'Leave-only capture is exhaustive');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=true WHERE tenant_id=pg_temp.k('tenant') AND capability_key='hr.attendance';
-- Immutable new fact version replaces the first version without mutating history.
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES(pg_temp.k('tenant'),pg_temp.k('new-interp'),pg_temp.k('wi-a2030-01-01'),2,'ready',time.work_instance_interpretation_fingerprint(pg_temp.k('tenant'),pg_temp.k('wi-a2030-01-01')),pg_temp.k('actor'));
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id) VALUES(pg_temp.k('tenant'),pg_temp.k('new-fact'),pg_temp.k('wi-a2030-01-01'),2,pg_temp.k('new-interp'),pg_temp.k('fact-a2030-01-01'),'PRIVATE CORRECTION',jsonb_build_object('outcome','worked','worked_minutes',475),pg_temp.k('actor'));
SELECT set_config('test.newversion',pg_temp.manifest()::text,true);
SELECT is(current_setting('test.newversion')::jsonb->'optional_sources'->'time'->'items'->0->>'fact_id',pg_temp.k('new-fact')::text,'latest immutable fact version selected');
SELECT ok(payroll.stale_reasons(current_setting('test.before')::jsonb,current_setting('test.newversion')::jsonb)?'optional_sources_changed','fact version change invalidates candidate source capture');
-- A cancellation uses the supported state transition, retaining approved preview provenance.
UPDATE leave.requests SET state='cancelled',version=3,cancelled_at=now() WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('request-a');
SELECT set_config('test.cancelled',pg_temp.manifest()::text,true);
SELECT is((current_setting('test.cancelled')::jsonb->'optional_sources'->'leave'->'items'->0->>'effective_units')::numeric,0::numeric,'cancelled approved source stays visible with zero effective units');
SELECT is(current_setting('test.cancelled')::jsonb->'optional_sources'->'leave'->'items'->0->>'approved_preview_version','1','cancellation preserves immutable approved preview identity');
SELECT ok(payroll.stale_reasons(current_setting('test.newversion')::jsonb,current_setting('test.cancelled')::jsonb)?'optional_sources_changed','cancellation invalidates canonical source capture');
-- Source enters/leaves the current approved projection without mutation of append-only facts.
UPDATE time.work_instances SET status='needs_review' WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('wi-a2030-01-02');
SELECT set_config('test.removed',pg_temp.manifest()::text,true);
SELECT ok(payroll.stale_reasons(current_setting('test.cancelled')::jsonb,current_setting('test.removed')::jsonb)?'optional_sources_changed','source leaving approved projection is detected');
UPDATE time.work_instances SET status='approved' WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('wi-a2030-01-02');
SELECT ok(payroll.stale_reasons(current_setting('test.removed')::jsonb,pg_temp.manifest())?'optional_sources_changed','source re-entering projection is detected');
SELECT throws_ok($$DELETE FROM time.attendance_facts WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('new-fact')$$,'55000',NULL,'immutable captured source deletion remains refused');
SELECT is(pg_temp.manifest(),current_setting('test.cancelled')::jsonb,'refused source deletion preserves the canonical snapshot');
-- Newly eligible source identity: extra Employment created before its own Time rows, with no overlap bypass.
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES(pg_temp.k('tenant'),pg_temp.k('new-employee'),'CAP-NEW','PRIVATE INSERTED NAME',pg_temp.k('actor'));
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES(pg_temp.k('tenant'),pg_temp.k('new-employment'),pg_temp.k('new-employee'),pg_temp.k('employer-a'),'2030-01-01','monthly');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES(pg_temp.k('tenant'),pg_temp.k('new-assignment'),pg_temp.k('new-employment'),pg_temp.k('site-a'),'2030-01-01');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,status,created_by) VALUES(pg_temp.k('tenant'),pg_temp.k('inserted-wi'),pg_temp.k('new-assignment'),pg_temp.k('new-employment'),pg_temp.k('new-employee'),pg_temp.k('site-a'),'2030-01-15',pg_temp.k('policy-a'),1,'Africa/Cairo','approved',pg_temp.k('actor'));
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES(pg_temp.k('tenant'),pg_temp.k('inserted-interp'),pg_temp.k('inserted-wi'),1,'ready',time.work_instance_interpretation_fingerprint(pg_temp.k('tenant'),pg_temp.k('inserted-wi')),pg_temp.k('actor'));
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES(pg_temp.k('tenant'),pg_temp.k('inserted-fact'),pg_temp.k('inserted-wi'),1,pg_temp.k('inserted-interp'),'{"outcome":"worked","worked_minutes":480}',pg_temp.k('actor'));
SELECT ok(payroll.stale_reasons(current_setting('test.cancelled')::jsonb,pg_temp.manifest())?'optional_sources_changed','new matching source row is detected, not just revised existing identity');
UPDATE people.employments SET payroll_eligible=false WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('employment-a');
SELECT set_config('test.ineligible',pg_temp.manifest()::text,true);
SELECT is(jsonb_array_length(current_setting('test.ineligible')::jsonb->'optional_sources'->'leave'->'items'),0,'ineligible Employment source facts are excluded');
SELECT ok(payroll.stale_reasons(current_setting('test.cancelled')::jsonb,current_setting('test.ineligible')::jsonb)?'optional_sources_changed','eligible scope change invalidates capture');
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id=pg_temp.k('tenant') AND user_id=pg_temp.k('actor');
SELECT throws_ok($$SELECT pg_temp.manifest()$$,'42501','payroll_forbidden','inactive current membership denies source capture');
UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id=pg_temp.k('tenant') AND user_id=pg_temp.k('actor');
DELETE FROM platform_core.membership_roles WHERE tenant_id=pg_temp.k('tenant') AND user_id=pg_temp.k('actor');
SELECT throws_ok($$SELECT pg_temp.manifest()$$,'42501','payroll_forbidden','removed current permission denies source capture');
UPDATE platform_core.tenant_legal_entities SET is_active=false WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('employer-a');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(pg_temp.k('tenant'),pg_temp.k('actor'),pg_temp.k('role'));
SELECT throws_ok($$SELECT pg_temp.manifest()$$,'P0002','payroll_employer_unavailable','inactive scoped Employer denied');
UPDATE platform_core.tenant_legal_entities SET is_active=true WHERE tenant_id=pg_temp.k('tenant') AND id=pg_temp.k('employer-a');
-- Rollback-only known composition model: private base rename plus delegating wrappers.
-- This demonstrates field/diff preservation; it is not Slice7 financial runtime qualification.
ALTER FUNCTION payroll.run_manifest(uuid,uuid,uuid) RENAME TO run_manifest_capture_composition_base;
ALTER FUNCTION payroll.stale_reasons(jsonb,jsonb) RENAME TO stale_reasons_capture_composition_base;
CREATE FUNCTION payroll.run_manifest(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$ SELECT payroll.run_manifest_capture_composition_base(p_tenant,p_employer,p_period)||jsonb_build_object('engine','cube4-review-v3-source-safe-advances-v1','advances','[]'::jsonb) $$;
CREATE FUNCTION payroll.stale_reasons(p_old jsonb,p_current jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$ SELECT payroll.stale_reasons_capture_composition_base(p_old,p_current) $$;
REVOKE ALL ON FUNCTION payroll.run_manifest(uuid,uuid,uuid),payroll.stale_reasons(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
SELECT ok(payroll.run_manifest(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('p31'))?'optional_sources','known delegating manifest composition preserves captured field');
SELECT ok(payroll.stale_reasons(current_setting('test.before')::jsonb,payroll.run_manifest(pg_temp.k('tenant'),pg_temp.k('employer-a'),pg_temp.k('p31')))?'optional_sources_changed','known delegating stale composition preserves capture diff');
UPDATE auth.users SET banned_until=now()+interval '1 day' WHERE id=pg_temp.k('actor');
SELECT throws_ok($$SELECT pg_temp.manifest()$$,'42501','payroll_forbidden','current user access restriction denies previously authorized capture');
SELECT * FROM finish();
ROLLBACK;
