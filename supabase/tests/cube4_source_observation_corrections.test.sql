BEGIN;
SELECT no_plan();
DO $$BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'dedicated Cube4 QA required';END IF;END$$;
-- Rollback-only NONLEGAL fixture. It qualifies bridge behavior, not legal output.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('d2620000-0000-4000-8000-000000000001','d262-payroll@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('d2621000-0000-4000-8000-000000000001','D262 observation correction QA','d2620000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES('d2621000-0000-4000-8000-000000000001','d2622000-0000-4000-8000-000000000001','d262.payroll.only',1,ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','compensation.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('d2621000-0000-4000-8000-000000000001','d2620000-0000-4000-8000-000000000001','d2620000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('d2621000-0000-4000-8000-000000000001','d2620000-0000-4000-8000-000000000001','d2622000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','D262 Employer','D262 NONLEGAL Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd2621000-0000-4000-8000-000000000001',key,true,now()-interval '1 minute','d2620000-0000-4000-8000-000000000001','rollback bridge QA' FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance'])key;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d2621000-0000-4000-8000-000000000001','d2624000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','D262 Site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2621000-0000-4000-8000-000000000001','d2625000-0000-4000-8000-000000000001','D262','D262 Employee','d2620000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2621000-0000-4000-8000-000000000001','d2626000-0000-4000-8000-000000000001','d2625000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','2025-01-05','daily');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2621000-0000-4000-8000-000000000001','d2627000-0000-4000-8000-000000000001','d2626000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d2621000-0000-4000-8000-000000000001','d2628000-0000-4000-8000-000000000001','D262-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d2621000-0000-4000-8000-000000000001','d2628000-0000-4000-8000-000000000001',1,'D262 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d2620000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d2621000-0000-4000-8000-000000000001','d2629000-0000-4000-8000-000000000001','d2626000-0000-4000-8000-000000000001','d2624000-0000-4000-8000-000000000001','d2628000-0000-4000-8000-000000000001',1,'2025-01-05');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2621000-0000-4000-8000-000000000001','d262a000-0000-4000-8000-000000000001','d2629000-0000-4000-8000-000000000001','d2626000-0000-4000-8000-000000000001','d2625000-0000-4000-8000-000000000001','d2624000-0000-4000-8000-000000000001','2025-01-05','d2628000-0000-4000-8000-000000000001',1,'UTC','2025-01-05 08:00+00','2025-01-05 16:00+00','2025-01-05 06:00+00','2025-01-05 22:00+00','approved','d2620000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2621000-0000-4000-8000-000000000001','d262b000-0000-4000-8000-000000000001','d262a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d2621000-0000-4000-8000-000000000001','d262a000-0000-4000-8000-000000000001'),'d2620000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2621000-0000-4000-8000-000000000001','d262c000-0000-4000-8000-000000000001','d262a000-0000-4000-8000-000000000001',1,'d262b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2620000-0000-4000-8000-000000000001');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d262d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2620000-0000-4000-8000-000000000001','rollback bridge QA');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d262e000-0000-4000-8000-000000000001','d262d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','D262 one day',false,'d2620000-0000-4000-8000-000000000001');

SELECT set_config('request.jwt.claim.sub','d2620000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d262e000-0000-4000-8000-000000000001',NULL,0,'calculate','D262 actual source candidate',gen_random_uuid())::text,true);
RESET ROLE;
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason) SELECT tenant_id,'d262f000-0000-4000-8000-000000000001',employer_id,run_id,id,'approve',0,'d2620000-0000-4000-8000-000000000001','NONLEGAL bridge fixture' FROM payroll.candidates WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT tenant_id,'d2630000-0000-4000-8000-000000000001',employer_id,'d262e000-0000-4000-8000-000000000001',run_id,id,'d262f000-0000-4000-8000-000000000001','{"legal_name":"NONLEGAL"}',input_manifest->'period',input_manifest,output,'NONLEGAL_D262','d2620000-0000-4000-8000-000000000001' FROM payroll.candidates  WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;

-- Independent NONLEGAL cancelled source runs satisfy UNIQUE(tenant,run).
-- These sibling snapshots only test affected-output scope; no public finalization is claimed.
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by)
SELECT tenant_id,employer_id,period_id,clone_run,'cancelled','d2620000-0000-4000-8000-000000000001'
FROM payroll.runs CROSS JOIN unnest(ARRAY['d2640000-0000-4000-8000-000000000002'::uuid,'d2640000-0000-4000-8000-000000000003'::uuid])clone_run
WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'id')::uuid;
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by)
SELECT c.tenant_id,c.employer_id,clone.run_id,clone.candidate_id,1,c.engine_version,c.input_manifest,c.output,c.created_by
FROM payroll.candidates c CROSS JOIN (VALUES('d2640000-0000-4000-8000-000000000002'::uuid,'d2641000-0000-4000-8000-000000000002'::uuid),('d2640000-0000-4000-8000-000000000003'::uuid,'d2641000-0000-4000-8000-000000000003'::uuid))clone(run_id,candidate_id)
WHERE c.tenant_id='d2621000-0000-4000-8000-000000000001' AND c.id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
SELECT c.tenant_id,clone.approval_id,c.employer_id,c.run_id,c.id,'approve',0,c.created_by,'NONLEGAL sibling scope fixture'
FROM payroll.candidates c JOIN (VALUES('d2641000-0000-4000-8000-000000000002'::uuid,'d2642000-0000-4000-8000-000000000002'::uuid),('d2641000-0000-4000-8000-000000000003'::uuid,'d2642000-0000-4000-8000-000000000003'::uuid))clone(candidate_id,approval_id)ON clone.candidate_id=c.id
WHERE c.tenant_id='d2621000-0000-4000-8000-000000000001';
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT c.tenant_id,clone.output_id,c.employer_id,'d262e000-0000-4000-8000-000000000001',c.run_id,c.id,clone.approval_id,'{"legal_name":"NONLEGAL"}',c.input_manifest->'period',c.input_manifest,c.output,'NONLEGAL_D262_SIBLING',c.created_by
FROM payroll.candidates c JOIN (VALUES('d2641000-0000-4000-8000-000000000002'::uuid,'d2642000-0000-4000-8000-000000000002'::uuid,'d2630000-0000-4000-8000-000000000002'::uuid),('d2641000-0000-4000-8000-000000000003'::uuid,'d2642000-0000-4000-8000-000000000003'::uuid,'d2630000-0000-4000-8000-000000000003'::uuid))clone(candidate_id,approval_id,output_id)ON clone.candidate_id=c.id
WHERE c.tenant_id='d2621000-0000-4000-8000-000000000001';
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net)
SELECT 'd2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',id,'d2626000-0000-4000-8000-000000000001','{}','{}','{}',100 FROM unnest(ARRAY['d2630000-0000-4000-8000-000000000001'::uuid,'d2630000-0000-4000-8000-000000000002'::uuid,'d2630000-0000-4000-8000-000000000003'::uuid])id;
SELECT payroll.insert_final_source_bindings('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d262e000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001');
INSERT INTO payroll.final_source_bindings SELECT tenant_id,'d2630000-0000-4000-8000-000000000002',employer_id,period_id,employment_id,source_date,source_domain,source_key,source_identity,source_version,captured_payload,captured_digest,dependency_lineage FROM payroll.final_source_bindings WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND output_id='d2630000-0000-4000-8000-000000000001';
-- Output 3 intentionally has no binding and must never be added gratuitously.
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id) VALUES('d2621000-0000-4000-8000-000000000001','d262c000-0000-4000-8000-000000000002','d262a000-0000-4000-8000-000000000001',2,'d262b000-0000-4000-8000-000000000001','d262c000-0000-4000-8000-000000000001','D262 actual correction','{"outcome":"worked","worked_minutes":360,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2620000-0000-4000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2621000-0000-4000-8000-000000000001'),2::bigint,'one changed event creates one immutable observation per exact live binding');
SELECT set_config('test.observation',(SELECT id::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND output_id='d2630000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.requirement',(SELECT requirement_id::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND id=current_setting('test.observation')::uuid),true);
SELECT set_config('test.change',jsonb_build_array(jsonb_build_object('type','source_change','source_id',current_setting('test.observation'),'expected_hash',(SELECT current_lineage_fingerprint FROM payroll.bound_source_correction_observations WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND id=current_setting('test.observation')::uuid),'fields','{}'::jsonb))::text,true);

SELECT set_config('test.compensation_hash',payroll.source_hash((SELECT to_jsonb(v) FROM people.compensation_versions v WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND id='d2627000-0000-4000-8000-000000000001')),true);
-- A legacy physical correction must not silently own observation requirements.
SET LOCAL ROLE authenticated;
SELECT set_config('test.legacy_preview',public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,jsonb_build_array(jsonb_build_object('type','compensation','source_id','d2627000-0000-4000-8000-000000000001','expected_hash',current_setting('test.compensation_hash'),'fields','{"amount":130}'::jsonb)), '[]',NULL,'Legacy proposal remains separate','Legacy source reference',NULL,'preview',gen_random_uuid())::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.legacy_case',(public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,jsonb_build_array(jsonb_build_object('type','compensation','source_id','d2627000-0000-4000-8000-000000000001','expected_hash',current_setting('test.compensation_hash'),'fields','{"amount":130}'::jsonb)), '[]',NULL,'Legacy proposal remains separate','Legacy source reference',current_setting('test.legacy_preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id'),true);
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.correction_request_links link JOIN payroll.bound_source_correction_observations observation ON observation.tenant_id=link.tenant_id AND observation.requirement_id=link.request_id WHERE link.tenant_id='d2621000-0000-4000-8000-000000000001'),0::bigint,'legacy People proposal excludes every observation-owned requirement');
SET LOCAL ROLE authenticated;
SELECT public.payroll_correction_command('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',current_setting('test.legacy_case')::uuid,1,'cancel','Close legacy isolation case',gen_random_uuid());
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.payroll_record_payment('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',0,'allocations',CURRENT_DATE,'D262 payment evidence','D262 paid route fixture','[{"employment_id":"d2626000-0000-4000-8000-000000000001","amount":"1"}]',NULL,true,gen_random_uuid());
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('test.choice',public.payroll_correction_choices('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001','source_change','sources','',NULL,current_setting('test.observation')::uuid)::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.sibling_choice',public.payroll_correction_choices('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000002','source_change','sources','',NULL,current_setting('test.observation')::uuid)::text,true);
SELECT set_config('test.financial_choices',public.payroll_correction_choices('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000002','source_change','employees')::text,true);
RESET ROLE;
SELECT ok((current_setting('test.sibling_choice')::jsonb->'selected'->>'affects_paid_output')::boolean,'unpaid original discovers paid sibling impact before responsibility entry');
SELECT is(jsonb_array_length(current_setting('test.financial_choices')::jsonb->'items'),1,'source correction can pick scoped settlement employees without general People editing authority');
SELECT is(current_setting('test.choice')::jsonb->'selected'->>'name','حضور · 2025-01-05 · D262 Employee','Payroll-only discovery returns bounded human metadata');
SELECT ok(NOT(current_setting('test.choice')::jsonb->'selected' ?| ARRAY['current_source_lineage','captured_payload','reason','source_key','requirement_id']),'choice never exposes private source payload or plumbing');
SELECT set_config('test.no_time_authority',(NOT platform_private.has_tenant_permission('d2621000-0000-4000-8000-000000000001','d2620000-0000-4000-8000-000000000001','attendance.manage'))::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.workspace',public.payroll_correction_workspace('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,'source_change')::text,true);
RESET ROLE;
SELECT ok(current_setting('test.no_time_authority')::boolean AND jsonb_array_length(current_setting('test.workspace')::jsonb->'sources')=2,'existing workspace discovers scoped observations without granting Payroll general Time authority');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_choices('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001','source_change','department_id')$$,'22023','payroll_invalid','source subtype cannot broaden the existing picker');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_choices('d2621100-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001','source_change','sources')$$,'42501','payroll_forbidden','observation discovery cannot cross Tenant authority');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000003',NULL,0,current_setting('test.change')::jsonb,'[]',NULL,'Unrelated output refused','Scoped source reference',NULL,'preview',gen_random_uuid())$$,'23514','payroll_correction_observation_unaffected','requested output must be in exact binding-derived affected set');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb||current_setting('test.change')::jsonb,'[]',NULL,'Duplicate observation refused','Scoped source reference',NULL,'preview',gen_random_uuid())$$,'22023','payroll_proposal_invalid','duplicate observation selection is rejected');
RESET ROLE;

SELECT set_config('test.rows','[{"output_id":"d2630000-0000-4000-8000-000000000001","employment_id":"d2626000-0000-4000-8000-000000000001","amount":"10","basis":"external_reviewed","reference":"Reviewed responsibility","source":"Independent reviewed responsibility; no guessed statutory delta"}]',true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,'[]',NULL,'Paid responsibility is explicit','Bound source responsibility',NULL,'preview',gen_random_uuid())$$,'23514','payroll_correction_responsibility_required','paid affected output cannot proceed without explicit responsibility');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review changed attendance source','Bound source responsibility',NULL,'preview','d2629100-0000-4000-8000-000000000001')::text,true);
RESET ROLE;
SELECT is(current_setting('test.preview')::jsonb->>'affected_count','2','preview returns the exact two live outputs sharing the binding identity');
SELECT is(current_setting('test.preview')::jsonb->>'route','paid_correction','existing route detects the paid member without guessing an amount');
SELECT ok(NOT(current_setting('test.preview')::jsonb ?| ARRAY['source_changes','typed_changes','current_source_lineage','captured_payload']),'public proposal metadata does not disclose compiled private source evidence');
SELECT set_config('test.save_attempt','d2629100-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.saved',public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review changed attendance source','Bound source responsibility',current_setting('test.preview')::jsonb->>'preview_hash','save',current_setting('test.save_attempt')::uuid)::text,true);
RESET ROLE;
SELECT set_config('test.case',current_setting('test.saved')::jsonb->>'case_id',true);
SELECT is((SELECT count(*) FROM payroll.correction_request_links WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),1::bigint,'only the exact selected observation requirement is linked');
SELECT is((SELECT count(*) FROM payroll.correction_requirements requirement WHERE requirement.tenant_id='d2621000-0000-4000-8000-000000000001' AND NOT EXISTS(SELECT 1 FROM payroll.correction_request_links link WHERE link.tenant_id=requirement.tenant_id AND link.request_id=requirement.id)),1::bigint,'unselected same-employee and period observation requirement remains open');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Wrong CAS is refused','Bound source responsibility',NULL,'preview',gen_random_uuid())$$,'PT409','payroll_correction_stale','proposal CAS remains enforced');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.payroll_correction_command('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,'calculate','Calculate fresh unpaid amendment',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.amendment_runs WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),1::bigint,'fresh actual source creates only the unpaid amendment run');
SELECT is((SELECT candidate.input_manifest->'optional_sources'->'time'->'items'->0->>'fact_id' FROM payroll.amendment_runs amendment JOIN payroll.runs run ON run.tenant_id=amendment.tenant_id AND run.id=amendment.run_id JOIN payroll.candidates candidate ON candidate.tenant_id=run.tenant_id AND candidate.id=run.candidate_id WHERE amendment.tenant_id='d2621000-0000-4000-8000-000000000001' AND amendment.case_id=current_setting('test.case')::uuid),'d262c000-0000-4000-8000-000000000002','unpaid amendment starts from current authoritative Time source');
SELECT is((SELECT jsonb_array_length(payroll.amendment_manifest(amendment.tenant_id,amendment.run_id)->'corrections') FROM payroll.amendment_runs amendment WHERE amendment.tenant_id='d2621000-0000-4000-8000-000000000001' AND amendment.case_id=current_setting('test.case')::uuid),1,'fresh manifest retains the unselected observation requirement as blocking');
SELECT set_config('test.amendment_run',(SELECT run_id FROM payroll.amendment_runs WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid)::text,true);
SELECT set_config('test.amendment_candidate',(SELECT run.candidate_id FROM payroll.amendment_runs amendment JOIN payroll.runs run ON run.tenant_id=amendment.tenant_id AND run.id=amendment.run_id WHERE amendment.tenant_id='d2621000-0000-4000-8000-000000000001' AND amendment.case_id=current_setting('test.case')::uuid)::text,true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_candidate_approval('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d262e000-0000-4000-8000-000000000001',current_setting('test.amendment_run')::uuid,current_setting('test.amendment_candidate')::uuid,1,'approve','Financial readiness remains closed',gen_random_uuid())$$,'23514','payroll_correction_proposal_approval_required','candidate approval requires the correction proposal to be approved first');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.payroll_correction_command('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,'approve','Approve governed source responsibility',gen_random_uuid());
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_candidate_approval('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d262e000-0000-4000-8000-000000000001',current_setting('test.amendment_run')::uuid,current_setting('test.amendment_candidate')::uuid,1,'approve','Financial readiness remains closed',gen_random_uuid())$$,'23514','payroll_approval_blocked','approved correction still cannot bypass financial readiness');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_command('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'route_paid','Cannot hide unpaid output',gen_random_uuid())$$,'23514','payroll_mixed_dispositions_require_atomic_finalization','existing paid route still requires explicit unpaid replacement lifecycle');
RESET ROLE;

SELECT set_config('test.fact_count',(SELECT count(*)::text FROM time.attendance_facts WHERE tenant_id='d2621000-0000-4000-8000-000000000001'),true);
SELECT payroll.correction_lock('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001');
SELECT payroll.apply_correction_sources((SELECT correction FROM payroll.correction_cases correction WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'d2620000-0000-4000-8000-000000000001');
SELECT is((SELECT count(*) FROM payroll.correction_source_effects WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),1::bigint,'OBSERVE contributes the normal exact proof count');
SELECT is((SELECT operation FROM payroll.correction_source_effects WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),'OBSERVE','proof distinguishes reference resolution from mutation');
SELECT is((SELECT count(*)::text FROM time.attendance_facts WHERE tenant_id='d2621000-0000-4000-8000-000000000001'),current_setting('test.fact_count'),'OBSERVE physically changes no Time row');
SELECT is((SELECT count(*) FROM payroll.payment_events WHERE tenant_id='d2621000-0000-4000-8000-000000000001'),1::bigint,'OBSERVE creates no payment or automatic settlement');
SELECT is((SELECT count(*) FROM payroll.output_successions WHERE tenant_id='d2621000-0000-4000-8000-000000000001'),0::bigint,'original outputs remain immutable without qualified financial append');

SET CONSTRAINTS ALL DEFERRED;
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id) VALUES('d2621000-0000-4000-8000-000000000001','d262c000-0000-4000-8000-000000000003','d262a000-0000-4000-8000-000000000001',3,'d262b000-0000-4000-8000-000000000001','d262c000-0000-4000-8000-000000000002','D262 later correction','{"outcome":"worked","worked_minutes":300,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2620000-0000-4000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SET LOCAL ROLE authenticated;
SELECT is(public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review changed attendance source','Bound source responsibility',current_setting('test.preview')::jsonb->>'preview_hash','save',current_setting('test.save_attempt')::uuid),current_setting('test.saved')::jsonb,'committed save receipt replays even after source changes again');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000002',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Stale observation refused','Bound source responsibility',NULL,'preview',gen_random_uuid())$$,'PT409','payroll_source_stale','stale observation cannot be previewed after a newer source event');
RESET ROLE;
SELECT throws_ok($$SELECT payroll.amendment_manifest('d2621000-0000-4000-8000-000000000001',current_setting('test.amendment_run')::uuid)$$,'PT409','payroll_source_stale','amendment manifest rejects stale observation even after same-transaction application proof');
SELECT throws_ok($$SELECT payroll.correction_current(c) FROM payroll.correction_cases c WHERE c.tenant_id='d2621000-0000-4000-8000-000000000001' AND c.id=current_setting('test.case')::uuid$$,'PT409','payroll_source_stale','approved correction rechecks observation currentness before application');
SELECT is((SELECT count(*) FROM payroll.correction_requirements requirement WHERE requirement.tenant_id='d2621000-0000-4000-8000-000000000001' AND NOT EXISTS(SELECT 1 FROM payroll.correction_request_links link JOIN payroll.correction_cases correction ON correction.tenant_id=link.tenant_id AND correction.id=link.case_id WHERE link.tenant_id=requirement.tenant_id AND link.request_id=requirement.id AND correction.status IN('routed','completed'))),4::bigint,'new source event retains independent open responsibilities');
SELECT ok(NOT has_function_privilege('authenticated','payroll.bound_source_envelope(uuid,text,date,uuid)','EXECUTE') AND NOT has_function_privilege('authenticated','payroll.compile_bound_source_observation(uuid,uuid,jsonb)','EXECUTE'),'private source reader and compiler have no API grants');
SELECT * FROM finish();
ROLLBACK;
