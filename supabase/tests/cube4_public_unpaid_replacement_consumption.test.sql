BEGIN;
DO $$ BEGIN IF current_database() <> 'business_platform_cube4_adam_closure_qa' THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required';END IF;END $$;
SELECT no_plan();
-- NONLEGAL approved prerequisites only. No public legal approval is claimed.
-- The new public consumer must refuse these prescribed candidates.
CREATE FUNCTION pg_temp.seed_approved(t uuid,e uuid,p uuid,r uuid,c uuid,v integer,op text,why text,k uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$DECLARE approval uuid;BEGIN
 IF current_database()<>'business_platform_cube4_adam_closure_qa' OR op<>'approve' THEN RAISE EXCEPTION 'QA prerequisite only';END IF;
 INSERT INTO payroll.approval_events(tenant_id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
 VALUES(t,e,r,c,'approve',v+1,'d2840000-0000-4000-8000-000000000001','NONLEGAL prescribed prerequisite') RETURNING id INTO approval;
 UPDATE payroll.runs SET status='approved',revision=revision+1,approval_id=approval WHERE tenant_id=t AND id=r AND revision=v AND candidate_id=c AND status='review';
 IF NOT FOUND THEN RAISE EXCEPTION 'QA prerequisite stale';END IF;
 RETURN jsonb_build_object('id',r,'candidate_id',c,'revision',v+1,'status','approved');END$$;

-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('d2840000-0000-4000-8000-000000000001','d284-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d2840000-0000-4000-8000-000000000002','d284-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('d2841000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','d2840000-0000-4000-8000-000000000001'),
 ('d2841000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','d2840000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('d2841000-0000-4000-8000-000000000001','d2842000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve','payroll.lock','payroll.export','payroll.payment_record','payroll.correct','people.manage','employment.manage','compensation.manage','org_context.manage','employee_finance.manage','employee_finance.approve','attendance.view','attendance.correct','attendance.approve']),
 ('d2841000-0000-4000-8000-000000000001','d2842000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('d2841000-0000-4000-8000-000000000001','d2842000-0000-4000-8000-000000000003','qa.payroll.viewonly',1,ARRAY['payroll.view']),
 ('d2841000-0000-4000-8000-000000000001','d2842000-0000-4000-8000-000000000004','qa.payroll.recordonly',1,ARRAY['payroll.payment_record']),
 ('d2841000-0000-4000-8000-000000000001','d2842000-0000-4000-8000-000000000005','qa.payroll.recordcorrect',1,ARRAY['payroll.view','payroll.payment_record','payroll.correct']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('d2841000-0000-4000-8000-000000000001','d2840000-0000-4000-8000-000000000001','d2840000-0000-4000-8000-000000000001'),
 ('d2841000-0000-4000-8000-000000000001','d2840000-0000-4000-8000-000000000002','d2840000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('d2841000-0000-4000-8000-000000000001','d2840000-0000-4000-8000-000000000001','d2842000-0000-4000-8000-000000000001'),
 ('d2841000-0000-4000-8000-000000000001','d2840000-0000-4000-8000-000000000002','d2842000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('d2841000-0000-4000-8000-000000000002','d2843000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('d2841000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','d2840000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('d2841000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','d2840000-0000-4000-8000-000000000001','Cube4 QA only');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('d2841000-0000-4000-8000-000000000001','d2843500-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2841000-0000-4000-8000-000000000001','d2844000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','d2840000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2841000-0000-4000-8000-000000000001','d2845000-0000-4000-8000-000000000001','d2844000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2841000-0000-4000-8000-000000000001','d2846000-0000-4000-8000-000000000001','d2845000-0000-4000-8000-000000000001',3000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('d2841000-0000-4000-8000-000000000001','d2846500-0000-4000-8000-000000000001','d2845000-0000-4000-8000-000000000001','d2843500-0000-4000-8000-000000000001','2030-01-01');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d2841000-0000-4000-8000-000000000001','d2844000-0000-4000-8000-000000000004','RUNQA2','Synthetic Second Employee','d2840000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('d2841000-0000-4000-8000-000000000001','d2845000-0000-4000-8000-000000000004','d2844000-0000-4000-8000-000000000004','d2843000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('d2841000-0000-4000-8000-000000000001','d2846000-0000-4000-8000-000000000004','d2845000-0000-4000-8000-000000000004',1000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('d2841000-0000-4000-8000-000000000001','d2846500-0000-4000-8000-000000000004','d2845000-0000-4000-8000-000000000004','d2843500-0000-4000-8000-000000000001','2030-01-01');
CREATE FUNCTION pg_temp.approval(operation text DEFAULT 'approve',expected integer DEFAULT 1,attempt uuid DEFAULT 'd2849100-0000-4000-8000-000000000001',reason text DEFAULT 'Synthetic candidate reviewed') RETURNS jsonb LANGUAGE sql AS $$
 SELECT pg_temp.seed_approved('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,expected,operation,reason,attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.approval(text,integer,uuid,text) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2840000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Synthetic foundation calendar')->>'period_id'),true);
SELECT public.payroll_save_input('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic proration"}','save',gen_random_uuid());
RESET ROLE;
-- Privileged test-only candidate result. No legal pack is inserted or claimed qualified.
-- This simulates an eventual trusted adapter contract solely to exercise approval/append atomicity inside ROLLBACK.
SELECT set_config('test.percentage_component',(public.payroll_save_input('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"key":"percentage_control","name":"Synthetic percentage control","classification":"earning","calculation":"percentage","base":"base_pay","value":"10","taxable":false,"social":false,"visible":true,"active":true,"proration":"salary_proration","order":"1","behavior":"recurring","reason":"Canonical enum regression"}','save',gen_random_uuid())->>'id'),true);
SELECT set_config('test.run','d2849200-0000-4000-8000-000000000001',true);
SELECT set_config('test.candidate','d2849200-0000-4000-8000-000000000002',true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,'draft','d2840000-0000-4000-8000-000000000001');
-- Real Time sources captured by generated original outputs; NONLEGAL money only.
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES('d2841000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','d2840000-0000-4000-8000-000000000001','Rollback generated-source QA');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d2841000-0000-4000-8000-000000000001','d2848000-0000-4000-8000-000000000001','D262-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d2848000-0000-4000-8000-000000000001',1,'D262 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d2840000-0000-4000-8000-000000000001');
UPDATE people.work_assignments SET work_policy_template_id='d2848000-0000-4000-8000-000000000001',work_policy_version=1 WHERE tenant_id='d2841000-0000-4000-8000-000000000001' AND id='d2846500-0000-4000-8000-000000000001';
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000001','d2846500-0000-4000-8000-000000000001','d2845000-0000-4000-8000-000000000001','d2844000-0000-4000-8000-000000000001','d2843500-0000-4000-8000-000000000001','2030-01-26','d2848000-0000-4000-8000-000000000001',1,'UTC','2030-01-26 08:00+00','2030-01-26 16:00+00','2030-01-26 06:00+00','2030-01-26 22:00+00','approved','d2840000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d284b000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d2841000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000001'),'d2840000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2841000-0000-4000-8000-000000000001','d284c000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000001',1,'d284b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2840000-0000-4000-8000-000000000001');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000002','d2846500-0000-4000-8000-000000000001','d2845000-0000-4000-8000-000000000001','d2844000-0000-4000-8000-000000000001','d2843500-0000-4000-8000-000000000001','2030-02-26','d2848000-0000-4000-8000-000000000001',1,'UTC','2030-02-26 08:00+00','2030-02-26 16:00+00','2030-02-26 06:00+00','2030-02-26 22:00+00','approved','d2840000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d284b000-0000-4000-8000-000000000002','d284a000-0000-4000-8000-000000000002',1,'ready',time.work_instance_interpretation_fingerprint('d2841000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000002'),'d2840000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2841000-0000-4000-8000-000000000001','d284c000-0000-4000-8000-000000000002','d284a000-0000-4000-8000-000000000002',1,'d284b000-0000-4000-8000-000000000002','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2840000-0000-4000-8000-000000000001');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000003','d2846500-0000-4000-8000-000000000001','d2845000-0000-4000-8000-000000000001','d2844000-0000-4000-8000-000000000001','d2843500-0000-4000-8000-000000000001','2030-03-26','d2848000-0000-4000-8000-000000000001',1,'UTC','2030-03-26 08:00+00','2030-03-26 16:00+00','2030-03-26 06:00+00','2030-03-26 22:00+00','approved','d2840000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d284b000-0000-4000-8000-000000000003','d284a000-0000-4000-8000-000000000003',1,'ready',time.work_instance_interpretation_fingerprint('d2841000-0000-4000-8000-000000000001','d284a000-0000-4000-8000-000000000003'),'d2840000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d2841000-0000-4000-8000-000000000001','d284c000-0000-4000-8000-000000000003','d284a000-0000-4000-8000-000000000003',1,'d284b000-0000-4000-8000-000000000003','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}','d2840000-0000-4000-8000-000000000001');

SELECT set_config('test.manifest',payroll.run_manifest('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT set_config('test.synthetic_output',payroll.build_review(current_setting('test.manifest')::jsonb)::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"4000"')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,0,net}','"3000"'),'{employees,0,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,1,net}','"1000"'),'{employees,1,issues}','[]'),'{employees,1,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
-- Explicit test adapter supplies prescribed NONLEGAL money. Time coverage is
-- intentionally incomplete; this must never qualify operational/legal readiness.
SELECT set_config('test.synthetic_output',jsonb_set(current_setting('test.synthetic_output')::jsonb,'{gross_complete}','true')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.manifest')::jsonb,current_setting('test.synthetic_output')::jsonb,'d2840000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id=current_setting('test.candidate')::uuid,revision=1 WHERE tenant_id='d2841000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
SET LOCAL ROLE authenticated;
SELECT pg_temp.approval();
RESET ROLE;
-- Rollback-only deterministic UUID allocation for original output fixtures.
-- It changes only the generated identifier, preserving the append checks and
-- state transitions. Chronological original UUID order forces the formerly
-- failing earlier-replacement-before-later-replacement batch path.
DO $$DECLARE d text;old text;BEGIN
 d:=pg_get_functiondef('payroll.append_final_output_before_advances(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
 old:='INSERT INTO payroll.final_contexts(tenant_id,';
 IF (length(d)-length(replace(d,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'unexpected_fixture_output_insert';END IF;
 d:=replace(d,old,'INSERT INTO payroll.final_contexts(id,tenant_id,');
 old:='VALUES(p_tenant,r.employer_id,r.period_id,p_run,p_candidate';
 IF (length(d)-length(replace(d,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'unexpected_fixture_output_values';END IF;
 d:=replace(d,old,'VALUES(COALESCE(NULLIF(current_setting(''test.final_output_uuid'',true),'''')::uuid,gen_random_uuid()),p_tenant,r.employer_id,r.period_id,p_run,p_candidate');
 EXECUTE d;END$$;
SELECT set_config('test.final_output_uuid','d284f000-0000-4000-8000-000000000001',true);
SELECT set_config('test.output',payroll.append_final_output('d2841000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'d2840000-0000-4000-8000-000000000001',2,gen_random_uuid())::text,true);

-- New assertions only. Synthetic fixture above is not a qualified legal adapter.
CREATE FUNCTION pg_temp.propose(p_amount numeric,p_case uuid DEFAULT NULL,p_expected integer DEFAULT 0,p_rows jsonb DEFAULT '[]',p_changes jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE changes jsonb;preview jsonb;BEGIN
 changes:=COALESCE(p_changes,jsonb_build_array(jsonb_build_object('type','compensation','source_id','d2846000-0000-4000-8000-000000000001','expected_hash',payroll.source_hash((SELECT to_jsonb(v) FROM people.compensation_versions v WHERE tenant_id='d2841000-0000-4000-8000-000000000001' AND id='d2846000-0000-4000-8000-000000000001')),'fields',jsonb_build_object('amount',p_amount))));
 preview:=public.payroll_correction_proposal('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,p_case,p_expected,changes,p_rows,NULL,'Attributable synthetic source correction','Reviewed source reference',NULL,'preview',gen_random_uuid());
 RETURN public.payroll_correction_proposal('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,p_case,p_expected,changes,p_rows,NULL,'Attributable synthetic source correction','Reviewed source reference',preview->>'preview_hash','save',gen_random_uuid());
END $$;
CREATE FUNCTION pg_temp.command(operation text,expected integer) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_correction_command('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,expected,operation,'Reviewed synthetic correction operation',gen_random_uuid())
$$;
CREATE FUNCTION pg_temp.synthetic_final(p_period uuid,p_amendment uuid DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE r payroll.runs%ROWTYPE;m jsonb;o jsonb;employees jsonb;candidate uuid;BEGIN
 IF p_amendment IS NULL THEN INSERT INTO payroll.runs(tenant_id,employer_id,period_id,status,created_by) VALUES('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',p_period,'draft','d2840000-0000-4000-8000-000000000001') RETURNING * INTO r;
 ELSE SELECT * INTO r FROM payroll.runs WHERE tenant_id='d2841000-0000-4000-8000-000000000001' AND id=p_amendment;END IF;
 m:=CASE WHEN p_amendment IS NULL THEN payroll.run_manifest(r.tenant_id,r.employer_id,r.period_id) ELSE payroll.amendment_manifest(r.tenant_id,r.id) END;
 o:=CASE WHEN p_amendment IS NULL THEN payroll.build_review(m) ELSE payroll.build_correction_review(m) END;
 SELECT jsonb_agg(jsonb_set(jsonb_set(jsonb_set(e,'{issues}','[]'),'{net}',to_jsonb(e->>'known_gross')),'{statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-02","2030-03"]}')) INTO employees FROM jsonb_array_elements(o->'employees')e;
 o:=jsonb_set(jsonb_set(jsonb_set(jsonb_set(o,'{issues}','[]'),'{employees}',employees),'{financially_qualified}','true'),'{net}',to_jsonb((SELECT sum((e->>'net')::numeric)::text FROM jsonb_array_elements(employees)e)));
 o:=jsonb_set(o,'{gross_complete}','true');
 INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,revision,engine_version,input_manifest,output,created_by) VALUES(r.tenant_id,r.employer_id,r.id,r.revision+1,'SYNTHETIC_NONLEGAL_ROLLBACK',m,o,'d2840000-0000-4000-8000-000000000001') RETURNING id INTO candidate;
 UPDATE payroll.runs SET status='review',candidate_id=candidate,revision=revision+1 WHERE tenant_id=r.tenant_id AND id=r.id;
 PERFORM pg_temp.seed_approved(r.tenant_id,r.employer_id,r.period_id,r.id,candidate,r.revision+1,'approve','Synthetic adapter contract only',gen_random_uuid());
 IF p_amendment IS NULL THEN RETURN payroll.append_final_output(r.tenant_id,r.id,candidate,'d2840000-0000-4000-8000-000000000001',r.revision+2,gen_random_uuid());END IF;
 RETURN r.id;
END $$;

-- Known monthly fixture and real locked transitions; no scope-only cancelled run clones.
SELECT public.payroll_record_payment('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,0,'allocations',CURRENT_DATE,'NONLEGAL initial external evidence','Batch route fixture','[{"employment_id":"d2845000-0000-4000-8000-000000000001","amount":"1"}]',NULL,true,gen_random_uuid());
SELECT set_config('test.second_period',(public.payroll_generate_next_period('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',(SELECT revision FROM payroll.calendar_heads WHERE tenant_id='d2841000-0000-4000-8000-000000000001' AND employer_id='d2843000-0000-4000-8000-000000000001'),gen_random_uuid(),payroll.preview_dates('2030-02-25',24,25,'ending','Africa/Cairo'))->>'period_id'),true);
SELECT set_config('test.final_output_uuid','d284f000-0000-4000-8000-000000000002',true);
SELECT set_config('test.second_output',pg_temp.synthetic_final(current_setting('test.second_period')::uuid)::text,true);
SELECT set_config('test.third_period',(public.payroll_generate_next_period('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',(SELECT revision FROM payroll.calendar_heads WHERE tenant_id='d2841000-0000-4000-8000-000000000001' AND employer_id='d2843000-0000-4000-8000-000000000001'),gen_random_uuid(),payroll.preview_dates('2030-03-25',24,25,'ending','Africa/Cairo'))->>'period_id'),true);
SELECT set_config('test.final_output_uuid','d284f000-0000-4000-8000-000000000003',true);
SELECT set_config('test.third_output',pg_temp.synthetic_final(current_setting('test.third_period')::uuid)::text,true);
SELECT set_config('test.final_output_uuid','',true);
SELECT set_config('test.original_digest',(SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY output_id,employment_id)::text) FROM payroll.final_employees f WHERE tenant_id='d2841000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.rows',jsonb_build_array(jsonb_build_object('output_id',current_setting('test.output'),'employment_id','d2845000-0000-4000-8000-000000000001','amount','10','basis','external_reviewed','reference','Independent explicit responsibility','source','NONLEGAL external reviewed amount, not statutory net'))::text,true);
SELECT set_config('test.case',(pg_temp.propose(3300,NULL,0,current_setting('test.rows')::jsonb)->>'case_id'),true);
SELECT pg_temp.command('calculate',1);
SELECT pg_temp.command('approve',2);
DO $$DECLARE a record;BEGIN FOR a IN SELECT run.period_id,run.id FROM payroll.amendment_runs m JOIN payroll.runs run ON run.tenant_id=m.tenant_id AND run.id=m.run_id WHERE m.tenant_id='d2841000-0000-4000-8000-000000000001' AND m.case_id=current_setting('test.case')::uuid LOOP PERFORM pg_temp.synthetic_final(a.period_id,a.id);END LOOP;END$$;
SELECT set_config('test.batch_attempt',gen_random_uuid()::text,true);

SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_correction_finalize('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,current_setting('test.batch_attempt')::uuid)$q$,'23514','payroll_financial_qualification_required','mixed paid/unpaid public batch refuses prescribed NONLEGAL amendments');
SELECT throws_ok($q$SELECT public.payroll_correction_finalize('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000003',current_setting('test.case')::uuid,3,current_setting('test.batch_attempt')::uuid)$q$,'42501','payroll_forbidden','batch cannot be rebound to another employer');
SELECT throws_ok($q$SELECT public.payroll_correction_finalize('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,current_setting('test.batch_attempt')::uuid)$q$,'PT409','payroll_correction_stale','batch requires exact approved case revision');
SELECT is(public.payroll_correction_finalization_reconcile('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,current_setting('test.batch_attempt')::uuid)->>'outcome','closed_uncommitted','batch recovery closes absent commit without applying sources');
SELECT is(public.payroll_correction_finalization_reconcile('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,current_setting('test.batch_attempt')::uuid)->>'outcome','closed_uncommitted','batch recovery is idempotent');
SELECT throws_ok($q$SELECT public.payroll_correction_finalize('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,current_setting('test.batch_attempt')::uuid)$q$,'PT409','payroll_attempt_closed','delayed batch cannot append after recovery closes attempt');
SELECT throws_ok($q$SELECT public.payroll_correction_finalization_reconcile('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,current_setting('test.batch_attempt')::uuid)$q$,'PT409','payroll_attempt_conflict','batch attempt identity includes expected revision');
SELECT set_config('request.jwt.claim.sub','d2840000-0000-4000-8000-000000000002',true);
SELECT throws_ok($q$SELECT public.payroll_correction_finalization_reconcile('d2841000-0000-4000-8000-000000000001','d2843000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,current_setting('test.batch_attempt')::uuid)$q$,'42501','payroll_forbidden','current reader authority cannot recover manager batch');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.correction_attempt_closures WHERE attempt_key=current_setting('test.batch_attempt')::uuid),1::bigint,'one batch closure after repeated recovery');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE attempt_key=current_setting('test.batch_attempt')::uuid),0::bigint,'unqualified batch has no final commit receipt');
SELECT is((SELECT count(*) FROM payroll.final_contexts WHERE tenant_id='d2841000-0000-4000-8000-000000000001'),3::bigint,'all three NONLEGAL original outputs remain without replacements');
SELECT is((SELECT count(*) FROM payroll.output_successions WHERE tenant_id='d2841000-0000-4000-8000-000000000001'),0::bigint,'refused public batch publishes no succession');
SELECT is((SELECT count(*) FROM payroll.correction_source_effects WHERE tenant_id='d2841000-0000-4000-8000-000000000001'),0::bigint,'refused public batch applies no source effects');
SELECT is((SELECT amount FROM people.compensation_versions WHERE tenant_id='d2841000-0000-4000-8000-000000000001' AND id='d2846000-0000-4000-8000-000000000001'),3000::numeric,'source wage unchanged by refused batch');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(f) ORDER BY output_id,employment_id)::text) FROM payroll.final_employees f WHERE tenant_id='d2841000-0000-4000-8000-000000000001'),current_setting('test.original_digest'),'all original employee explanations and money unchanged');
SELECT is((SELECT status FROM payroll.correction_cases WHERE id=current_setting('test.case')::uuid),'approved','refused batch preserves approved case');
SELECT is((SELECT revision FROM payroll.correction_cases WHERE id=current_setting('test.case')::uuid),3,'refused batch preserves case revision');
SELECT ok(NOT has_function_privilege('authenticated','payroll.append_correction_outputs(uuid,uuid,integer,uuid,uuid)','EXECUTE'),'private atomic batch remains inaccessible to browser');
SELECT * FROM finish();ROLLBACK;
