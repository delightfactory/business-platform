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
SELECT set_config('test.no_time_authority',(NOT platform_private.has_tenant_permission('d2621000-0000-4000-8000-000000000001','d2620000-0000-4000-8000-000000000001','attendance.manage'))::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.workspace',public.payroll_correction_workspace('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,'source_change')::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;

SELECT set_config('test.rows','[{"output_id":"d2630000-0000-4000-8000-000000000001","employment_id":"d2626000-0000-4000-8000-000000000001","amount":"10","basis":"external_reviewed","reference":"Reviewed responsibility","source":"Independent reviewed responsibility; no guessed statutory delta"}]',true);
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review changed attendance source','Bound source responsibility',NULL,'preview','d2629100-0000-4000-8000-000000000001')::text,true);
RESET ROLE;
SELECT set_config('test.save_attempt','d2629100-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.saved',public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review changed attendance source','Bound source responsibility',current_setting('test.preview')::jsonb->>'preview_hash','save',current_setting('test.save_attempt')::uuid)::text,true);
RESET ROLE;
SELECT set_config('test.case',current_setting('test.saved')::jsonb->>'case_id',true);

SELECT set_config('test.other_change',jsonb_build_array(jsonb_build_object('type','source_change','source_id',observation.id,'expected_hash',observation.current_lineage_fingerprint,'fields','{}'::jsonb))::text,true)
FROM payroll.bound_source_correction_observations observation WHERE observation.tenant_id='d2621000-0000-4000-8000-000000000001' AND observation.output_id='d2630000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('test.edit_preview',public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,current_setting('test.other_change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Replace selected observation','Exact revised selection',NULL,'preview',gen_random_uuid())::text,true);
SELECT public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,current_setting('test.other_change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Replace selected observation','Exact revised selection',current_setting('test.edit_preview')::jsonb->>'preview_hash','save',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.correction_request_links WHERE tenant_id='d2621000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),2::bigint,'editing retains immutable historical links without treating all as current');
SELECT ok(NOT payroll.correction_requirement_is_current('d2621000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,current_setting('test.requirement')::uuid),'removed observation requirement is not resolved by revised proposal');
SET LOCAL ROLE authenticated;
SELECT public.payroll_correction_command('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,'calculate','Calculate revised selection',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT jsonb_array_length(payroll.amendment_manifest(amendment.tenant_id,amendment.run_id)->'corrections') FROM payroll.amendment_runs amendment JOIN payroll.runs run ON run.tenant_id=amendment.tenant_id AND run.id=amendment.run_id WHERE amendment.tenant_id='d2621000-0000-4000-8000-000000000001' AND amendment.case_id=current_setting('test.case')::uuid AND run.status='review'),1,'edited amendment keeps deselected historical requirement blocking');
SELECT set_config('test.combined',((current_setting('test.change')::jsonb)||(current_setting('test.other_change')::jsonb))::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.combined_preview',public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,current_setting('test.combined')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review both recorded changes','Both exact requirements',NULL,'preview',gen_random_uuid())::text,true);
SELECT public.payroll_correction_proposal('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001','d2630000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,current_setting('test.combined')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review both recorded changes','Both exact requirements',current_setting('test.combined_preview')::jsonb->>'preview_hash','save',gen_random_uuid());
RESET ROLE;
SELECT is(current_setting('test.combined_preview')::jsonb->>'affected_count','2','combined selected observations deduplicate their two affected outputs');
SELECT is((SELECT jsonb_array_length(proposal.source_changes) FROM payroll.correction_proposals proposal JOIN payroll.correction_cases correction ON correction.tenant_id=proposal.tenant_id AND correction.proposal_id=proposal.id WHERE correction.tenant_id='d2621000-0000-4000-8000-000000000001' AND correction.id=current_setting('test.case')::uuid),2,'one governed proposal can select both exact recorded changes');
SELECT is((SELECT count(*) FROM payroll.correction_requirements requirement WHERE requirement.tenant_id='d2621000-0000-4000-8000-000000000001' AND payroll.correction_requirement_is_current(requirement.tenant_id,current_setting('test.case')::uuid,requirement.id)),2::bigint,'only both currently selected requirements become eligible for resolution');
SET LOCAL ROLE authenticated;
SELECT public.payroll_correction_command('d2621000-0000-4000-8000-000000000001','d2623000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,4,'calculate','Calculate combined recorded changes',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT jsonb_array_length(payroll.amendment_manifest(amendment.tenant_id,amendment.run_id)->'corrections') FROM payroll.amendment_runs amendment JOIN payroll.runs run ON run.tenant_id=amendment.tenant_id AND run.id=amendment.run_id WHERE amendment.tenant_id='d2621000-0000-4000-8000-000000000001' AND amendment.case_id=current_setting('test.case')::uuid AND run.status='review'),0,'joint amendment review removes only its two selected requirements');
SELECT ok(NOT has_function_privilege('authenticated','payroll.correction_requirement_is_current(uuid,uuid,uuid)','EXECUTE'),'current-selection resolution helper remains private');
SELECT * FROM finish();
ROLLBACK;
