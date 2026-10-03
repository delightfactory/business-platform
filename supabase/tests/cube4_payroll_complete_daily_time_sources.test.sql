BEGIN;
DO $$ BEGIN
  IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- Dedicated rollback-only contract fixture. The positive path uses the same
-- capture keys as capture_time_coverage/capture_optional_sources; it is not a
-- synthetic zero/partial-pay helper.
CREATE FUNCTION pg_temp.good_manifest() RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT jsonb_build_object(
    'engine','cube4-review-v5-complete-daily-time',
    'period',jsonb_build_object('id','d2308000-0000-4000-8000-000000000001','tenant_id','d2301000-0000-4000-8000-000000000001','employer_id','d2303000-0000-4000-8000-000000000001','starts_on','2030-01-06','ends_on','2030-01-06','is_transition',false),
    'employees',jsonb_build_array(jsonb_build_object('name','QA Employee','code','D230','employment',jsonb_build_object('id','d2305000-0000-4000-8000-000000000001','tenant_id','d2301000-0000-4000-8000-000000000001','employee_id','d2304000-0000-4000-8000-000000000001','employer_entity_id','d2303000-0000-4000-8000-000000000001','payroll_eligible',true,'pay_basis','daily','start_date','2030-01-01'))),
    'compensation',jsonb_build_array(jsonb_build_object('id','d2306000-0000-4000-8000-000000000001','employment_id','d2305000-0000-4000-8000-000000000001','valid_from','2030-01-01','valid_until',NULL,'amount',100)),
    'assignments',jsonb_build_array(jsonb_build_object('id','d2307000-0000-4000-8000-000000000001','employment_id','d2305000-0000-4000-8000-000000000001','valid_from','2030-01-01','valid_until',NULL)),
    'inputs',jsonb_build_array(
      jsonb_build_object('head',jsonb_build_object('id','d2307100-0000-4000-8000-000000000001','kind','policy'),'version',jsonb_build_object('id','d2307200-0000-4000-8000-000000000001','revision',1,'status','approved','effective_from','2030-01-01','data',jsonb_build_object('mode','calendar_days'))),
      jsonb_build_object('head',jsonb_build_object('id','d2307300-0000-4000-8000-000000000001','kind','manual_units','employment_id','d2305000-0000-4000-8000-000000000001','period_id','d2308000-0000-4000-8000-000000000001'),'version',jsonb_build_object('id','d2307400-0000-4000-8000-000000000001','revision',1,'status','approved','effective_from','2030-01-01','effective_until','2030-01-07','data',jsonb_build_object('source','time','units',0)))
    ),
    'packs','[]'::jsonb,'corrections','[]'::jsonb,
    'optional',jsonb_build_object('time',true,'leave',false,'finance','adjustments_only'),
    'optional_sources',jsonb_build_object('contract','cube4-optional-capture-v1',
      'time',jsonb_build_object('enabled',true,'items',jsonb_build_array(jsonb_build_object('date','2030-01-06','employment_id','d2305000-0000-4000-8000-000000000001','employee_id','d2304000-0000-4000-8000-000000000001','work_instance_id','d2309000-0000-4000-8000-000000000001','fact_id','d230a000-0000-4000-8000-000000000001','fact_version',1,'interpretation_id','d230b000-0000-4000-8000-000000000001','interpretation_version',1,'outcome','worked','absence_units',0,'leave_units',0,'worked_minutes',480,'classification_reconciliation_required',false,'leave_bindings','[]'::jsonb)),
        'coverage',jsonb_build_object('contract','cube4-time-coverage-v1','enabled',true,'items',jsonb_build_array(jsonb_build_object('date','2030-01-06','employment_id','d2305000-0000-4000-8000-000000000001','employee_id','d2304000-0000-4000-8000-000000000001','expected',true,'elapsed',true,'state','approved_fact_current','provenance',jsonb_build_object('instances',jsonb_build_array(jsonb_build_object('id','d2309000-0000-4000-8000-000000000001')),'latest_fact',jsonb_build_object('id','d230a000-0000-4000-8000-000000000001','version',1,'interpretation_id','d230b000-0000-4000-8000-000000000001'),'latest_interpretation',jsonb_build_object('id','d230b000-0000-4000-8000-000000000001','version',1)))))),
      'leave',jsonb_build_object('enabled',false,'items','[]'::jsonb))
  )
$f$;
CREATE FUNCTION pg_temp.reconciled(p_manifest jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT payroll.reconcile_employee_sources(p_manifest,p_manifest->'employees'->0->'employment')
$$;
CREATE FUNCTION pg_temp.parts() RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT '[{"date":"2030-01-06","rate":"100","units":"1","raw":"100"}]'::jsonb
$$;
CREATE FUNCTION pg_temp.coverage(p jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT payroll.complete_daily_time_coverage(p,p->'employees'->0->'employment',pg_temp.reconciled(p),pg_temp.parts())
$$;
CREATE FUNCTION pg_temp.half_manifest(paid boolean) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_set(
    jsonb_set(
      jsonb_set(pg_temp.good_manifest(),'{optional,leave}','true'),
      '{optional_sources,time,items,0}',
      pg_temp.good_manifest()->'optional_sources'->'time'->'items'->0||jsonb_build_object('leave_units',0.5,'absence_units',0,'leave_bindings',jsonb_build_array(jsonb_build_object('request_id','d230f000-0000-4000-8000-000000000001','approved_preview_version',1,'date','2030-01-06','units',0.5,'mapping_state','mapped')))),
    '{optional_sources,leave}',
    jsonb_build_object('enabled',true,'items',jsonb_build_array(jsonb_build_object('request_id','d230f000-0000-4000-8000-000000000001','date','2030-01-06','employee_id','d2304000-0000-4000-8000-000000000001','employment_id','d2305000-0000-4000-8000-000000000001','state','approved','approved_preview_version',1,'effective_units',0.5,'eligible',true,'pay_effect',CASE WHEN paid THEN 'paid' ELSE 'unpaid' END,'is_half_day',true,'mapping_state','mapped'))));
$$;
CREATE FUNCTION pg_temp.rate_manifest() RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $f$
DECLARE m jsonb; s jsonb; c jsonb;
BEGIN
  m:=jsonb_set(pg_temp.good_manifest(),'{period,ends_on}','"2030-01-07"');
  m:=jsonb_set(m,'{compensation,0,valid_until}','"2030-01-07"');
  m:=jsonb_set(m,'{compensation}',m->'compensation'||jsonb_build_array(jsonb_build_object('id','d2306000-0000-4000-8000-000000000002','employment_id','d2305000-0000-4000-8000-000000000001','valid_from','2030-01-07','valid_until',NULL,'amount',200)));
  s:=m->'optional_sources'->'time'->'items'->0;
  s:=jsonb_set(s,'{date}','"2030-01-07"')||jsonb_build_object('work_instance_id','d2309000-0000-4000-8000-000000000002','fact_id','d230a000-0000-4000-8000-000000000002','interpretation_id','d230b000-0000-4000-8000-000000000002');
  m:=jsonb_set(m,'{optional_sources,time,items}',m->'optional_sources'->'time'->'items'||jsonb_build_array(s));
  c:=m->'optional_sources'->'time'->'coverage'->'items'->0;
  c:=jsonb_set(c,'{date}','"2030-01-07"');
  c:=jsonb_set(c,'{provenance,instances}',jsonb_build_array(jsonb_build_object('id','d2309000-0000-4000-8000-000000000002')));
  c:=jsonb_set(c,'{provenance,latest_fact}',jsonb_build_object('id','d230a000-0000-4000-8000-000000000002','version',1,'interpretation_id','d230b000-0000-4000-8000-000000000002'));
  c:=jsonb_set(c,'{provenance,latest_interpretation}',jsonb_build_object('id','d230b000-0000-4000-8000-000000000002','version',1));
  m:=jsonb_set(m,'{optional_sources,time,coverage,items}',m->'optional_sources'->'time'->'coverage'->'items'||jsonb_build_array(c));
  RETURN m;
END $f$;

SELECT is(pg_temp.coverage(pg_temp.good_manifest())->>'complete','true','complete approved current fact and dated rate part qualify operational daily gross');
WITH original AS MATERIALIZED(SELECT pg_temp.good_manifest() AS m), other AS(
 SELECT m,(m->'optional_sources'->'time'->'coverage'->'items'->0)||jsonb_build_object('employment_id','d2305000-0000-4000-8000-000000000002','employee_id','d2304000-0000-4000-8000-000000000002') AS c,
 (m->'optional_sources'->'time'->'items'->0)||jsonb_build_object('employment_id','d2305000-0000-4000-8000-000000000002','employee_id','d2304000-0000-4000-8000-000000000002') AS f FROM original), expanded AS(
 SELECT jsonb_set(jsonb_set(m,'{optional_sources,time,coverage,items}',m->'optional_sources'->'time'->'coverage'->'items'||jsonb_build_array(c)),
 '{optional_sources,time,items}',m->'optional_sources'->'time'->'items'||jsonb_build_array(f)) AS m FROM other)
SELECT is(pg_temp.coverage(m)->>'complete','true','another Employee coverage and facts are filtered without weakening own binding') FROM expanded;
SELECT is((payroll.build_review(pg_temp.good_manifest())->'employees'->0->>'gross')::numeric,100::numeric,'actual current builder emits exact one-day gross only after complete source binding');
SELECT is(payroll.build_review(pg_temp.good_manifest())->'employees'->0->'source_summary'->>'operational_complete','true','operational metadata is true without changing financial qualification');
SELECT is(payroll.build_review(pg_temp.good_manifest())->'employees'->0->'source_summary'->>'payroll_ready','false','complete daily gross does not claim financial source consumption');
SELECT is(payroll.build_review(pg_temp.good_manifest())->'employees'->0->>'net',NULL::text,'complete daily gross never exposes payable net');
SELECT ok(payroll.build_review(pg_temp.good_manifest())->'issues' @> '[{"code":"time_integration_pending"}]','Time financial integration hold remains');

SELECT is(pg_temp.coverage(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,coverage,items}', '[]'::jsonb))->>'complete','false','missing expected day blocks the whole employee');
SELECT is(pg_temp.coverage(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,coverage,items,0,state}','"not_yet_elapsed"'))->>'complete','false','future coverage cannot qualify gross');
SELECT is(pg_temp.coverage(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,coverage,items,0,state}','"approved_fact_not_current"'))->>'complete','false','stale fact state cannot qualify gross');
SELECT is(pg_temp.coverage(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,coverage,items,0,provenance,latest_fact,id}','"d230a000-0000-4000-8000-000000000099"'))->>'complete','false','latest fact identity mismatch blocks whole coverage');
SELECT is(pg_temp.coverage(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,items}',jsonb_build_array(pg_temp.good_manifest()->'optional_sources'->'time'->'items'->0,pg_temp.good_manifest()->'optional_sources'->'time'->'items'->0)))->>'complete','false','duplicate captured fact day blocks whole coverage');
SELECT is(pg_temp.coverage(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,items,0,fact_version}','2'))->>'complete','false','captured fact version mismatch blocks whole coverage');
SELECT is((SELECT payroll.complete_daily_time_coverage(pg_temp.good_manifest(),pg_temp.good_manifest()->'employees'->0->'employment',pg_temp.reconciled(pg_temp.good_manifest()),'[]'::jsonb))->>'complete','false','missing rate part never receives a zero default');
SELECT is((SELECT payroll.complete_daily_time_coverage(pg_temp.good_manifest(),pg_temp.good_manifest()->'employees'->0->'employment',pg_temp.reconciled(pg_temp.good_manifest()),'[{"date":"2030-01-06","rate":"100"},{"date":"2030-01-06","rate":"100"}]'::jsonb))->>'complete','false','duplicate rate mapping blocks whole coverage');

SELECT is(pg_temp.coverage(jsonb_set(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,coverage,items,0,expected}','false'),'{optional_sources,time,coverage,items,0,state}','"scheduled_nonworkday"'))->>'complete','false','materialized fact cannot be reclassified as a nonworking day');
SELECT is(pg_temp.coverage(jsonb_set(jsonb_set(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,coverage,items,0,expected}','false'),'{optional_sources,time,coverage,items,0,state}','"scheduled_nonworkday"'),'{optional_sources,time,coverage,items,0,provenance,instances}','[]'::jsonb))->>'complete','false','nonworking state cannot silently replace an expected reconciled source day');
WITH nonwork AS MATERIALIZED(SELECT jsonb_set(jsonb_set(jsonb_set(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,items}','[]'::jsonb),'{optional_sources,time,coverage,items,0,expected}','false'),'{optional_sources,time,coverage,items,0,state}','"scheduled_nonworkday"'),'{optional_sources,time,coverage,items,0,provenance,instances}','[]'::jsonb) AS m)
SELECT is(payroll.complete_daily_time_coverage(m,m->'employees'->0->'employment',pg_temp.reconciled(m),'[]'::jsonb)->>'complete','true','a genuine scheduled nonworking day needs no fact and receives no guessed pay') FROM nonwork;
SELECT is(pg_temp.coverage(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,coverage,items,0,provenance,latest_interpretation,version}','2'))->>'complete','false','latest interpretation version binding is strict');
SELECT ok(payroll.stale_reasons(pg_temp.good_manifest(),jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,items,0,fact_version}','2')) ? 'optional_sources_changed','source identity change stales the existing candidate');
SELECT ok(NOT (payroll.build_review(pg_temp.good_manifest())::text ~ 'd230a000-0000-4000-8000-000000000001|d2309000-0000-4000-8000-000000000001'),'builder public-safe explanation does not expose raw source provenance identifiers');
SELECT is((payroll.build_review(pg_temp.half_manifest(true))->'employees'->0->>'gross')::numeric,100::numeric,'half worked plus paid Leave is exactly one paid daily unit');
SELECT is((payroll.build_review(pg_temp.half_manifest(false))->'employees'->0->>'gross')::numeric,50::numeric,'half worked plus unpaid Leave pays only the worked half');
SELECT is((payroll.build_review(jsonb_set(pg_temp.good_manifest(),'{optional_sources,time,items,0}',pg_temp.good_manifest()->'optional_sources'->'time'->'items'->0||'{"outcome":"absence","absence_units":1,"leave_units":0,"worked_minutes":30}'::jsonb))->'employees'->0->>'gross')::numeric,0::numeric,'explicit classified absence contributes zero without guessed work');
SELECT is((payroll.build_review(pg_temp.rate_manifest())->'employees'->0->>'gross')::numeric,300::numeric,'dated compensation rate change preserves exact daily source parts');

-- Actual Source11-shaped capture and public calculate path (one Employee,
-- one inclusive eligible day). This is intentionally separate from the
-- bottled JSON negative cases above and remains inside this transaction.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('d2310000-0000-4000-8000-000000000001','complete-daily@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('d2311000-0000-4000-8000-000000000001','Complete daily QA','d2310000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES('d2311000-0000-4000-8000-000000000001','d2312000-0000-4000-8000-000000000001','complete.daily.payroll',1,ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll_config.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('d2311000-0000-4000-8000-000000000001','d2310000-0000-4000-8000-000000000001','d2310000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('d2311000-0000-4000-8000-000000000001','d2310000-0000-4000-8000-000000000001','d2312000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','Complete Daily Employer','Complete Daily Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd2311000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d2310000-0000-4000-8000-000000000001','rollback actual Source11 QA' FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance'])x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d2311000-0000-4000-8000-000000000001','d2314000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','Complete Daily Site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2311000-0000-4000-8000-000000000001','d2315000-0000-4000-8000-000000000001','D231','Actual Source11 Employee','d2310000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2311000-0000-4000-8000-000000000001','d2316000-0000-4000-8000-000000000001','d2315000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','2025-01-05','daily');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2311000-0000-4000-8000-000000000001','d2317000-0000-4000-8000-000000000001','d2316000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d2311000-0000-4000-8000-000000000001','d2318000-0000-4000-8000-000000000001','D231-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by)
VALUES('d2311000-0000-4000-8000-000000000001','d2318000-0000-4000-8000-000000000001',1,'D231 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d2310000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from)
VALUES('d2311000-0000-4000-8000-000000000001','d2319000-0000-4000-8000-000000000001','d2316000-0000-4000-8000-000000000001','d2314000-0000-4000-8000-000000000001','d2318000-0000-4000-8000-000000000001',1,'2025-01-05');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by)
VALUES('d2311000-0000-4000-8000-000000000001','d231a000-0000-4000-8000-000000000001','d2319000-0000-4000-8000-000000000001','d2316000-0000-4000-8000-000000000001','d2315000-0000-4000-8000-000000000001','d2314000-0000-4000-8000-000000000001','2025-01-05','d2318000-0000-4000-8000-000000000001',1,'UTC','2025-01-05 08:00+00','2025-01-05 16:00+00','2025-01-05 06:00+00','2025-01-05 22:00+00','approved','d2310000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by)
VALUES('d2311000-0000-4000-8000-000000000001','d231b000-0000-4000-8000-000000000001','d231a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d2311000-0000-4000-8000-000000000001','d231a000-0000-4000-8000-000000000001'),'d2310000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
VALUES('d2311000-0000-4000-8000-000000000001','d231c000-0000-4000-8000-000000000001','d231a000-0000-4000-8000-000000000001',1,'d231b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}', 'd2310000-0000-4000-8000-000000000001');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','d231d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2310000-0000-4000-8000-000000000001','rollback actual Source11 QA');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','d231e000-0000-4000-8000-000000000001','d231d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','Actual Source11 one-day QA',false,'d2310000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','d2310000-0000-4000-8000-000000000001',true);
SELECT set_config('test.actual_capture',payroll.capture_optional_sources('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','d231e000-0000-4000-8000-000000000001')::text,true);
SELECT is((current_setting('test.actual_capture')::jsonb->'time'->'coverage'->'items'->0->>'state'),'approved_fact_current','actual Source11 capture sees the approved current fact');
SET LOCAL ROLE authenticated;
SELECT set_config('test.actual_policy',public.payroll_save_input('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2025-01-05',NULL,'{"mode":"calendar_days","reason":"rollback actual Source11 QA"}'::jsonb,'save',gen_random_uuid())::text,true);
SELECT set_config('test.actual_time',public.payroll_save_input('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','manual_units','d2316000-0000-4000-8000-000000000001','d231e000-0000-4000-8000-000000000001',NULL,0,'2025-01-05','2025-01-06','{"source":"time","units":0,"reason":"rollback actual Source11 QA"}'::jsonb,'save',gen_random_uuid())::text,true);
SELECT set_config('test.actual_time_approved',public.payroll_save_input('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','manual_units','d2316000-0000-4000-8000-000000000001','d231e000-0000-4000-8000-000000000001',(current_setting('test.actual_time')::jsonb->>'id')::uuid,1,'2025-01-05','2025-01-06','{"source":"time","units":0,"reason":"rollback actual Source11 QA"}'::jsonb,'approve',gen_random_uuid())::text,true);
SELECT set_config('test.actual_run',public.payroll_run_command('d2311000-0000-4000-8000-000000000001','d2313000-0000-4000-8000-000000000001','d231e000-0000-4000-8000-000000000001',NULL,0,'calculate','rollback actual Source11 QA',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT (output->'employees'->0->>'gross')::numeric FROM payroll.candidates WHERE tenant_id='d2311000-0000-4000-8000-000000000001' AND id=(current_setting('test.actual_run')::jsonb->>'candidate_id')::uuid),125::numeric,'actual public calculate emits one approved daily gross');
SELECT is((SELECT output->'employees'->0->'source_summary'->>'operational_complete' FROM payroll.candidates WHERE tenant_id='d2311000-0000-4000-8000-000000000001' AND id=(current_setting('test.actual_run')::jsonb->>'candidate_id')::uuid),'true','actual candidate marks only source operational completeness');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
