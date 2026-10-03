BEGIN;
SELECT no_plan();
DO $$BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'dedicated Cube4 QA required';END IF;END$$;
-- Rollback-only NONLEGAL fixture. It qualifies bridge behavior, not legal output.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES('d2680000-0000-4000-8000-000000000001','d268-payroll@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES('d2681000-0000-4000-8000-000000000001','D262 observation correction QA','d2680000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES('d2681000-0000-4000-8000-000000000001','d2682000-0000-4000-8000-000000000001','d268.payroll.only',1,ARRAY['payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','compensation.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('d2681000-0000-4000-8000-000000000001','d2680000-0000-4000-8000-000000000001','d2680000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('d2681000-0000-4000-8000-000000000001','d2680000-0000-4000-8000-000000000001','d2682000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','D262 Employer','D262 NONLEGAL Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd2681000-0000-4000-8000-000000000001',key,true,now()-interval '1 minute','d2680000-0000-4000-8000-000000000001','rollback bridge QA' FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance'])key;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d2681000-0000-4000-8000-000000000001','d2684000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','D262 Site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2681000-0000-4000-8000-000000000001','d2685000-0000-4000-8000-000000000001','D262','D262 Employee','d2680000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2681000-0000-4000-8000-000000000001','d2686000-0000-4000-8000-000000000001','d2685000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','2025-01-05','daily');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2681000-0000-4000-8000-000000000001','d2687000-0000-4000-8000-000000000001','d2686000-0000-4000-8000-000000000001',125,'2025-01-05');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d2681000-0000-4000-8000-000000000001','d2688000-0000-4000-8000-000000000001','D262-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d2681000-0000-4000-8000-000000000001','d2688000-0000-4000-8000-000000000001',1,'D262 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d2680000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d2681000-0000-4000-8000-000000000001','d2689000-0000-4000-8000-000000000001','d2686000-0000-4000-8000-000000000001','d2684000-0000-4000-8000-000000000001','d2688000-0000-4000-8000-000000000001',1,'2025-01-05');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2681000-0000-4000-8000-000000000001','d268a000-0000-4000-8000-000000000001','d2689000-0000-4000-8000-000000000001','d2686000-0000-4000-8000-000000000001','d2685000-0000-4000-8000-000000000001','d2684000-0000-4000-8000-000000000001','2025-01-05','d2688000-0000-4000-8000-000000000001',1,'UTC','2025-01-05 08:00+00','2025-01-05 16:00+00','2025-01-05 06:00+00','2025-01-05 22:00+00','approved','d2680000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2681000-0000-4000-8000-000000000001','d268b000-0000-4000-8000-000000000001','d268a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d2681000-0000-4000-8000-000000000001','d268a000-0000-4000-8000-000000000001'),'d2680000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2681000-0000-4000-8000-000000000001','d268c000-0000-4000-8000-000000000001','d268a000-0000-4000-8000-000000000001',1,'d268b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2680000-0000-4000-8000-000000000001');
INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision) VALUES('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d268d000-0000-4000-8000-000000000001',1,'2025-01-05',6,7,'ending','UTC','d2680000-0000-4000-8000-000000000001','rollback bridge QA');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d268e000-0000-4000-8000-000000000001','d268d000-0000-4000-8000-000000000001','2025-01-05','2025-01-05','2025-01-06','UTC','D262 one day',false,'d2680000-0000-4000-8000-000000000001');

SELECT set_config('request.jwt.claim.sub','d2680000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d268e000-0000-4000-8000-000000000001',NULL,0,'calculate','D262 actual source candidate',gen_random_uuid())::text,true);
RESET ROLE;
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason) SELECT tenant_id,'d268f000-0000-4000-8000-000000000001',employer_id,run_id,id,'approve',0,'d2680000-0000-4000-8000-000000000001','NONLEGAL bridge fixture' FROM payroll.candidates WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT tenant_id,'d2690000-0000-4000-8000-000000000001',employer_id,'d268e000-0000-4000-8000-000000000001',run_id,id,'d268f000-0000-4000-8000-000000000001','{"legal_name":"NONLEGAL"}',input_manifest->'period',input_manifest,output,'NONLEGAL_D262','d2680000-0000-4000-8000-000000000001' FROM payroll.candidates  WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;

-- Independent NONLEGAL cancelled source runs satisfy UNIQUE(tenant,run).
-- These sibling snapshots only test affected-output scope; no public finalization is claimed.
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by)
SELECT tenant_id,employer_id,period_id,clone_run,'cancelled','d2680000-0000-4000-8000-000000000001'
FROM payroll.runs CROSS JOIN unnest(ARRAY['d2700000-0000-4000-8000-000000000002'::uuid,'d2700000-0000-4000-8000-000000000003'::uuid])clone_run
WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND id=(current_setting('test.run')::jsonb->>'id')::uuid;
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by)
SELECT c.tenant_id,c.employer_id,clone.run_id,clone.candidate_id,1,c.engine_version,c.input_manifest,c.output,c.created_by
FROM payroll.candidates c CROSS JOIN (VALUES('d2700000-0000-4000-8000-000000000002'::uuid,'d2701000-0000-4000-8000-000000000002'::uuid),('d2700000-0000-4000-8000-000000000003'::uuid,'d2701000-0000-4000-8000-000000000003'::uuid))clone(run_id,candidate_id)
WHERE c.tenant_id='d2681000-0000-4000-8000-000000000001' AND c.id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
SELECT c.tenant_id,clone.approval_id,c.employer_id,c.run_id,c.id,'approve',0,c.created_by,'NONLEGAL sibling scope fixture'
FROM payroll.candidates c JOIN (VALUES('d2701000-0000-4000-8000-000000000002'::uuid,'d2702000-0000-4000-8000-000000000002'::uuid),('d2701000-0000-4000-8000-000000000003'::uuid,'d2702000-0000-4000-8000-000000000003'::uuid))clone(candidate_id,approval_id)ON clone.candidate_id=c.id
WHERE c.tenant_id='d2681000-0000-4000-8000-000000000001';
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT c.tenant_id,clone.output_id,c.employer_id,'d268e000-0000-4000-8000-000000000001',c.run_id,c.id,clone.approval_id,'{"legal_name":"NONLEGAL"}',c.input_manifest->'period',c.input_manifest,c.output,'NONLEGAL_D262_SIBLING',c.created_by
FROM payroll.candidates c JOIN (VALUES('d2701000-0000-4000-8000-000000000002'::uuid,'d2702000-0000-4000-8000-000000000002'::uuid,'d2690000-0000-4000-8000-000000000002'::uuid),('d2701000-0000-4000-8000-000000000003'::uuid,'d2702000-0000-4000-8000-000000000003'::uuid,'d2690000-0000-4000-8000-000000000003'::uuid))clone(candidate_id,approval_id,output_id)ON clone.candidate_id=c.id
WHERE c.tenant_id='d2681000-0000-4000-8000-000000000001';
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net)
SELECT 'd2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001',id,'d2686000-0000-4000-8000-000000000001','{}','{}','{}',100 FROM unnest(ARRAY['d2690000-0000-4000-8000-000000000001'::uuid,'d2690000-0000-4000-8000-000000000002'::uuid,'d2690000-0000-4000-8000-000000000003'::uuid])id;
SELECT payroll.insert_final_source_bindings('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d268e000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001');
INSERT INTO payroll.final_source_bindings SELECT tenant_id,'d2690000-0000-4000-8000-000000000002',employer_id,period_id,employment_id,source_date,source_domain,source_key,source_identity,source_version,captured_payload,captured_digest,dependency_lineage FROM payroll.final_source_bindings WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND output_id='d2690000-0000-4000-8000-000000000001';
-- Output 3 intentionally has no binding and must never be added gratuitously.
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,corrects_fact_id,reason,fact,actor_user_id) VALUES('d2681000-0000-4000-8000-000000000001','d268c000-0000-4000-8000-000000000002','d268a000-0000-4000-8000-000000000001',2,'d268b000-0000-4000-8000-000000000001','d268c000-0000-4000-8000-000000000001','D262 actual correction','{"outcome":"worked","worked_minutes":360,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2680000-0000-4000-8000-000000000001');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT set_config('test.observation',(SELECT id::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND output_id='d2690000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.requirement',(SELECT requirement_id::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND id=current_setting('test.observation')::uuid),true);
SELECT set_config('test.change',jsonb_build_array(jsonb_build_object('type','source_change','source_id',current_setting('test.observation'),'expected_hash',(SELECT current_lineage_fingerprint FROM payroll.bound_source_correction_observations WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND id=current_setting('test.observation')::uuid),'fields','{}'::jsonb))::text,true);

SELECT set_config('test.compensation_hash',payroll.source_hash((SELECT to_jsonb(v) FROM people.compensation_versions v WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND id='d2687000-0000-4000-8000-000000000001')),true);
-- A legacy physical correction must not silently own observation requirements.
SET LOCAL ROLE authenticated;
SELECT set_config('test.legacy_preview',public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',NULL,0,jsonb_build_array(jsonb_build_object('type','compensation','source_id','d2687000-0000-4000-8000-000000000001','expected_hash',current_setting('test.compensation_hash'),'fields','{"amount":130}'::jsonb)), '[]',NULL,'Legacy proposal remains separate','Legacy source reference',NULL,'preview',gen_random_uuid())::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.legacy_case',(public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',NULL,0,jsonb_build_array(jsonb_build_object('type','compensation','source_id','d2687000-0000-4000-8000-000000000001','expected_hash',current_setting('test.compensation_hash'),'fields','{"amount":130}'::jsonb)), '[]',NULL,'Legacy proposal remains separate','Legacy source reference',current_setting('test.legacy_preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id'),true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.payroll_correction_command('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001',current_setting('test.legacy_case')::uuid,1,'cancel','Close legacy isolation case',gen_random_uuid());
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.payroll_record_payment('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',0,'allocations',CURRENT_DATE,'D262 payment evidence','D262 paid route fixture','[{"employment_id":"d2686000-0000-4000-8000-000000000001","amount":"1"}]',NULL,true,gen_random_uuid());
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('test.choice',public.payroll_correction_choices('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001','source_change','sources','',NULL,current_setting('test.observation')::uuid)::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.sibling_choice',public.payroll_correction_choices('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000002','source_change','sources','',NULL,current_setting('test.observation')::uuid)::text,true);
SELECT set_config('test.financial_choices',public.payroll_correction_choices('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000002','source_change','employees')::text,true);
RESET ROLE;
SELECT set_config('test.no_time_authority',(NOT platform_private.has_tenant_permission('d2681000-0000-4000-8000-000000000001','d2680000-0000-4000-8000-000000000001','attendance.manage'))::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.workspace',public.payroll_correction_workspace('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',NULL,'source_change')::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
RESET ROLE;

SELECT set_config('test.rows','[{"output_id":"d2690000-0000-4000-8000-000000000001","employment_id":"d2686000-0000-4000-8000-000000000001","amount":"10","basis":"external_reviewed","reference":"Reviewed responsibility","source":"Independent reviewed responsibility; no guessed statutory delta"}]',true);
SET LOCAL ROLE authenticated;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review changed attendance source','Bound source responsibility',NULL,'preview','d2689100-0000-4000-8000-000000000001')::text,true);
RESET ROLE;
SELECT set_config('test.save_attempt','d2689100-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.saved',public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review changed attendance source','Bound source responsibility',current_setting('test.preview')::jsonb->>'preview_hash','save',current_setting('test.save_attempt')::uuid)::text,true);
RESET ROLE;
SELECT set_config('test.case',current_setting('test.saved')::jsonb->>'case_id',true);

-- Finish the original actor's deferred setup before testing a different actor.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO auth.users(id,email,aud,role,email_confirmed_at,created_at,updated_at) VALUES
('d2680000-0000-4000-8000-000000000002','d268-payroll-only@test.invalid','authenticated','authenticated',now(),now(),now()),
('d2680000-0000-4000-8000-000000000003','d268-time-only@test.invalid','authenticated','authenticated',now(),now(),now());
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) SELECT 'd2681000-0000-4000-8000-000000000001',id,'d2680000-0000-4000-8000-000000000001' FROM auth.users WHERE id IN('d2680000-0000-4000-8000-000000000002','d2680000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
('d2681000-0000-4000-8000-000000000001','d2682000-0000-4000-8000-000000000002','bound.payroll.only',1,ARRAY['payroll.view','payroll.correct']),
('d2681000-0000-4000-8000-000000000001','d2682000-0000-4000-8000-000000000003','bound.time.only',1,ARRAY['attendance.view','attendance.correct','attendance.approve']);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
('d2681000-0000-4000-8000-000000000001','d2680000-0000-4000-8000-000000000002','d2682000-0000-4000-8000-000000000002'),
('d2681000-0000-4000-8000-000000000001','d2680000-0000-4000-8000-000000000003','d2682000-0000-4000-8000-000000000003');
-- Seed only the upstream interpretation prerequisite. The approved fact is
-- appended by correct_attendance_absence under authenticated Time-only authority.
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,exception_code,input_fingerprint,created_by)
VALUES('d2681000-0000-4000-8000-000000000001','d268b000-0000-4000-8000-000000000002','d268a000-0000-4000-8000-000000000001',2,'needs_review','absence_candidate',time.work_instance_interpretation_fingerprint('d2681000-0000-4000-8000-000000000001','d268a000-0000-4000-8000-000000000001'),'d2680000-0000-4000-8000-000000000003');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2680000-0000-4000-8000-000000000003',true);
SELECT public.correct_attendance_absence('d2681000-0000-4000-8000-000000000001','d268a000-0000-4000-8000-000000000001','d268c000-0000-4000-8000-000000000002','Repeated actual public source correction');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT set_config('request.jwt.claim.sub','d2680000-0000-4000-8000-000000000001',true);
SELECT ok(NOT payroll.correction_requirement_is_current('d2681000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,current_setting('test.requirement')::uuid),'stale selected observation cannot resolve its old responsibility');
SELECT set_config('test.latest',jsonb_agg(jsonb_build_object('type','source_change','source_id',id,'expected_hash',current_lineage_fingerprint,'fields','{}'::jsonb) ORDER BY output_id)::text,true) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND current_source_version->>'fact_version'='3';
SELECT is(jsonb_array_length(current_setting('test.latest')::jsonb),2,'latest public mutation observes both exact original bindings');
SET LOCAL ROLE authenticated;
SELECT set_config('test.latest_preview',public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,current_setting('test.latest')::jsonb,current_setting('test.rows')::jsonb,NULL,'Latest source replaces stale selection','Preserved history',NULL,'preview',gen_random_uuid())::text,true);
SELECT public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,current_setting('test.latest')::jsonb,current_setting('test.rows')::jsonb,NULL,'Latest source replaces stale selection','Preserved history',current_setting('test.latest_preview')::jsonb->>'preview_hash','save',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.correction_request_links WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),4::bigint,'new proposal links all four responsibilities without deleting history');
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND payroll.correction_requirement_is_current(tenant_id,current_setting('test.case')::uuid,id)),4::bigint,'fresh exact two binding selections cover both previous and latest responsibilities');
SET LOCAL ROLE authenticated;
SELECT set_config('test.only_a',jsonb_build_array(current_setting('test.latest')::jsonb->0)::text,true);
SELECT set_config('test.only_preview',public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,current_setting('test.only_a')::jsonb,current_setting('test.rows')::jsonb,NULL,'Deselect sibling binding','Keep exact origin only',NULL,'preview',gen_random_uuid())::text,true);
SELECT public.payroll_correction_proposal('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d2690000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,current_setting('test.only_a')::jsonb,current_setting('test.rows')::jsonb,NULL,'Deselect sibling binding','Keep exact origin only',current_setting('test.only_preview')::jsonb->>'preview_hash','save',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.correction_requirements WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND payroll.correction_requirement_is_current(tenant_id,current_setting('test.case')::uuid,id)),2::bigint,'deselected sibling sharing physical source leaves both its responsibilities unresolved');
SELECT is((SELECT count(*) FROM payroll.correction_request_links WHERE tenant_id='d2681000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),4::bigint,'removal preserves all immutable links');
SELECT ok(payroll.correction_requirement_is_current('d2681000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,current_setting('test.requirement')::uuid),'latest exact selected origin now covers stale predecessor');
SELECT ok(NOT has_function_privilege('authenticated','payroll.correction_observation_covers_requirement(uuid,uuid,uuid)','EXECUTE'),'lineage helper remains private');
-- One selected observation still affects an unpaid sibling through the physical
-- source scope. Prove actual refusal rather than inventing another QA payment to
-- turn this mixed fixture into a simpler all-paid case. Generated-period source
-- replacement/closure remains a separate acceptance requirement.
SELECT set_config('test.frozen_digest',(SELECT md5(jsonb_agg(to_jsonb(x) ORDER BY output_id,employment_id)::text) FROM payroll.final_employees x WHERE tenant_id='d2681000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.payment_digest',(SELECT md5(jsonb_agg(to_jsonb(x) ORDER BY id)::text) FROM payroll.payment_events x WHERE tenant_id='d2681000-0000-4000-8000-000000000001'),true);
SET LOCAL ROLE authenticated;
SELECT is(public.payroll_correction_command('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'approve','Review selected current source and independent external responsibility',gen_random_uuid())->>'status','approved','latest selected source proposal can be reviewed after repeated changes');
SELECT throws_ok($$SELECT public.payroll_correction_command('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,4,'route_paid','Do not bypass the unpaid sibling disposition',gen_random_uuid())$$,'23514','payroll_mixed_dispositions_require_atomic_finalization','selected paid observation does not authorize partial closure of a mixed physical source scope');
RESET ROLE;
SELECT is(jsonb_array_length(payroll.run_manifest('d2681000-0000-4000-8000-000000000001','d2683000-0000-4000-8000-000000000001','d268e000-0000-4000-8000-000000000001')->'corrections'),4,'refused partial source route retains all old and new responsibilities until atomic closure');
SELECT ok(current_setting('test.frozen_digest')=(SELECT md5(jsonb_agg(to_jsonb(x) ORDER BY output_id,employment_id)::text) FROM payroll.final_employees x WHERE tenant_id='d2681000-0000-4000-8000-000000000001') AND current_setting('test.payment_digest')=(SELECT md5(jsonb_agg(to_jsonb(x) ORDER BY id)::text) FROM payroll.payment_events x WHERE tenant_id='d2681000-0000-4000-8000-000000000001') AND NOT EXISTS(SELECT 1 FROM payroll.correction_source_effects WHERE tenant_id='d2681000-0000-4000-8000-000000000001'),'refused mixed source route preserves original employee outputs, payments and unapplied source');
SELECT * FROM finish();
ROLLBACK;
