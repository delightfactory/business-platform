BEGIN;
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required';END IF;END $$;
SELECT no_plan();
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4460000-0000-4000-8000-000000000001','cube4-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4460000-0000-4000-8000-000000000002','cube4-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4461000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4460000-0000-4000-8000-000000000001'),
 ('c4461000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4460000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4461000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve','payroll.lock','payroll.export','payroll.payment_record','payroll.correct','people.manage','employment.manage','compensation.manage','org_context.manage','employee_finance.manage','employee_finance.approve']),
 ('c4461000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4461000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000003','qa.payroll.viewonly',1,ARRAY['payroll.view']),
 ('c4461000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000004','qa.payroll.recordonly',1,ARRAY['payroll.payment_record']),
 ('c4461000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000005','qa.payroll.recordcorrect',1,ARRAY['payroll.view','payroll.payment_record','payroll.correct']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4461000-0000-4000-8000-000000000001','c4460000-0000-4000-8000-000000000001','c4460000-0000-4000-8000-000000000001'),
 ('c4461000-0000-4000-8000-000000000001','c4460000-0000-4000-8000-000000000002','c4460000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4461000-0000-4000-8000-000000000001','c4460000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000001'),
 ('c4461000-0000-4000-8000-000000000001','c4460000-0000-4000-8000-000000000002','c4462000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4461000-0000-4000-8000-000000000002','c4463000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4461000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4460000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4461000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4460000-0000-4000-8000-000000000001','Cube4 QA only');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4461000-0000-4000-8000-000000000001','c4463500-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4461000-0000-4000-8000-000000000001','c4464000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','c4460000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4461000-0000-4000-8000-000000000001','c4465000-0000-4000-8000-000000000001','c4464000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4461000-0000-4000-8000-000000000001','c4466000-0000-4000-8000-000000000001','c4465000-0000-4000-8000-000000000001',3000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4461000-0000-4000-8000-000000000001','c4466500-0000-4000-8000-000000000001','c4465000-0000-4000-8000-000000000001','c4463500-0000-4000-8000-000000000001','2030-01-01');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4461000-0000-4000-8000-000000000001','c4464000-0000-4000-8000-000000000004','RUNQA2','Synthetic Second Employee','c4460000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4461000-0000-4000-8000-000000000001','c4465000-0000-4000-8000-000000000004','c4464000-0000-4000-8000-000000000004','c4463000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4461000-0000-4000-8000-000000000001','c4466000-0000-4000-8000-000000000004','c4465000-0000-4000-8000-000000000004',1000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4461000-0000-4000-8000-000000000001','c4466500-0000-4000-8000-000000000004','c4465000-0000-4000-8000-000000000004','c4463500-0000-4000-8000-000000000001','2030-01-01');
-- Dedicated second Employer: partial ordinary employment gives an observable policy effect.
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4461000-0000-4000-8000-000000000001','c4463500-0000-4000-8000-000000000003','c4463000-0000-4000-8000-000000000003','Cross Employer site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4461000-0000-4000-8000-000000000001','c4464000-0000-4000-8000-000000000003','CROSSB','Synthetic Employer B Employee','c4460000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4461000-0000-4000-8000-000000000001','c4465000-0000-4000-8000-000000000003','c4464000-0000-4000-8000-000000000003','c4463000-0000-4000-8000-000000000003','2030-02-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4461000-0000-4000-8000-000000000001','c4466000-0000-4000-8000-000000000003','c4465000-0000-4000-8000-000000000003',1500,'2030-02-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4461000-0000-4000-8000-000000000001','c4466500-0000-4000-8000-000000000003','c4465000-0000-4000-8000-000000000003','c4463500-0000-4000-8000-000000000003','2030-02-01');
CREATE FUNCTION pg_temp.approval(operation text DEFAULT 'approve',expected integer DEFAULT 1,attempt uuid DEFAULT 'c4469100-0000-4000-8000-000000000001',reason text DEFAULT 'Synthetic candidate reviewed') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_candidate_approval('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,expected,operation,reason,attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.approval(text,integer,uuid,text) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4460000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Synthetic foundation calendar')->>'period_id'),true);
SELECT public.payroll_save_input('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic proration"}','save',gen_random_uuid());
RESET ROLE;
-- Privileged test-only candidate result. No legal pack is inserted or claimed qualified.
-- This simulates an eventual trusted adapter contract solely to exercise approval/append atomicity inside ROLLBACK.
SELECT set_config('test.run','c4469200-0000-4000-8000-000000000001',true);
SELECT set_config('test.candidate','c4469200-0000-4000-8000-000000000002',true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,'draft','c4460000-0000-4000-8000-000000000001');
SELECT set_config('test.manifest',payroll.run_manifest('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT set_config('test.synthetic_output',payroll.build_review(current_setting('test.manifest')::jsonb)::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"4000"')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,0,net}','"3000"'),'{employees,0,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,1,net}','"1000"'),'{employees,1,issues}','[]'),'{employees,1,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.manifest')::jsonb,current_setting('test.synthetic_output')::jsonb,'c4460000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id=current_setting('test.candidate')::uuid,revision=1 WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
SET LOCAL ROLE authenticated;
SELECT pg_temp.approval();
RESET ROLE;
SELECT set_config('test.output',payroll.append_final_output('c4461000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4460000-0000-4000-8000-000000000001',2,gen_random_uuid())::text,true);

-- Standalone cross-Employer delta; synthetic privileged net is never legal qualification.
SET LOCAL ROLE authenticated;
SELECT set_config('test.period_b',(public.payroll_save_calendar('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003','2030-01-25',24,25,'ending','Africa/Cairo'),'Cross Employer synthetic calendar')->>'period_id'),true);
RESET ROLE;
DO $$ DECLARE m jsonb;o jsonb;employees jsonb;r uuid:=gen_random_uuid();v uuid:=gen_random_uuid();BEGIN
 INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003',current_setting('test.period_b')::uuid,r,'draft','c4460000-0000-4000-8000-000000000001');
 m:=payroll.run_manifest('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003',current_setting('test.period_b')::uuid);o:=payroll.build_review(m);
 SELECT jsonb_agg(jsonb_set(jsonb_set(jsonb_set(e,'{issues}','[]'),'{net}',to_jsonb(e->>'known_gross')),'{statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')) INTO employees FROM jsonb_array_elements(o->'employees')e;
 o:=jsonb_set(jsonb_set(jsonb_set(jsonb_set(o,'{issues}','[]'),'{employees}',employees),'{financially_qualified}','true'),'{net}',to_jsonb((SELECT sum((e->>'net')::numeric)::text FROM jsonb_array_elements(employees)e)));
 INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003',r,v,1,'SYNTHETIC_NONLEGAL_ROLLBACK',m,o,'c4460000-0000-4000-8000-000000000001');
 UPDATE payroll.runs SET status='review',candidate_id=v,revision=1 WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=r;
 PERFORM public.payroll_candidate_approval('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003',current_setting('test.period_b')::uuid,r,v,1,'approve','Privileged nonlegal contract fixture',gen_random_uuid());
 PERFORM set_config('test.output_b',payroll.append_final_output('c4461000-0000-4000-8000-000000000001',r,v,'c4460000-0000-4000-8000-000000000001',2,gen_random_uuid())::text,true);
END $$;
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND output_id=current_setting('test.output_b')::uuid),'1161.29','Employer B original actual-day ordinary proration is exact');
CREATE FUNCTION pg_temp.cross_proposal() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE changes jsonb;preview jsonb;BEGIN
 SELECT jsonb_build_array(jsonb_build_object('type','input_revision','source_id',h.id,'expected_hash',payroll.source_hash(to_jsonb(v)),'fields',jsonb_build_object('effective_from','2030-01-01','effective_until',NULL,'cancelled',false,'data',jsonb_build_object('mode','fixed_30_day','reason','Reviewed Tenant-wide fixed30 policy correction')))) INTO changes FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id='c4461000-0000-4000-8000-000000000001' AND h.kind='policy';
 preview:=public.payroll_correction_proposal('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,NULL,0,changes,'[]',NULL,'Reviewed cross Employer policy correction','Tenant policy evidence',NULL,'preview',gen_random_uuid());
 RETURN public.payroll_correction_proposal('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,NULL,0,changes,'[]',NULL,'Reviewed cross Employer policy correction','Tenant policy evidence',preview->>'preview_hash','save',gen_random_uuid());
END $$;
SELECT set_config('test.case',(pg_temp.cross_proposal()->>'case_id'),true);
SELECT is((SELECT jsonb_array_length(p.source_scope->'affected_outputs') FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id WHERE c.tenant_id='c4461000-0000-4000-8000-000000000001' AND c.id=current_setting('test.case')::uuid),2,'Tenant policy discovers both original outputs across Employers');
SELECT is((SELECT count(DISTINCT x->>'employer_id')::integer FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id CROSS JOIN LATERAL jsonb_array_elements(p.source_scope->'affected_outputs')x WHERE c.tenant_id='c4461000-0000-4000-8000-000000000001' AND c.id=current_setting('test.case')::uuid),2,'Affected scope preserves each legal Employer identity');
SELECT public.payroll_correction_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,'calculate','Review both Employers',gen_random_uuid());
SELECT is((SELECT count(*)::integer FROM payroll.amendment_runs WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),2,'Each original has its own scoped amendment candidate');
SELECT is((SELECT (v.output->'employees'->0->>'known_gross')::numeric FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id JOIN payroll.candidates v ON v.tenant_id=r.tenant_id AND v.id=r.candidate_id WHERE m.tenant_id='c4461000-0000-4000-8000-000000000001' AND m.case_id=current_setting('test.case')::uuid AND r.employer_id='c4463000-0000-4000-8000-000000000003'),1200::numeric,'Employer B overlay uses changed partial fixed30 policy');
SELECT public.payroll_correction_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,'approve','Approved attributable policy proposal',gen_random_uuid());
SELECT is((SELECT v.data->>'mode' FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id='c4461000-0000-4000-8000-000000000001' AND h.kind='policy'),'calendar_days','Proposal approval leaves the actual Tenant source unchanged');
SELECT throws_ok($$SELECT payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',gen_random_uuid())$$,'23514','payroll_approval_blocked','Cross Employer batch cannot skip financial readiness');
-- Insert immutable privileged adapter fixtures only after proving the public readiness refusal.
DO $$ DECLARE r payroll.runs%ROWTYPE;m jsonb;o jsonb;employees jsonb;v uuid;BEGIN
 FOR r IN SELECT r0.* FROM payroll.amendment_runs a JOIN payroll.runs r0 ON r0.tenant_id=a.tenant_id AND r0.id=a.run_id WHERE a.tenant_id='c4461000-0000-4000-8000-000000000001' AND a.case_id=current_setting('test.case')::uuid ORDER BY r0.id LOOP
  m:=payroll.amendment_manifest(r.tenant_id,r.id);o:=payroll.build_review(m);
  SELECT jsonb_agg(jsonb_set(jsonb_set(jsonb_set(e,'{issues}','[]'),'{net}',to_jsonb(e->>'known_gross')),'{statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')) INTO employees FROM jsonb_array_elements(o->'employees')e;
  o:=jsonb_set(jsonb_set(jsonb_set(jsonb_set(o,'{issues}','[]'),'{employees}',employees),'{financially_qualified}','true'),'{net}',to_jsonb((SELECT sum((e->>'net')::numeric)::text FROM jsonb_array_elements(employees)e)));
  INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,revision,engine_version,input_manifest,output,created_by) VALUES(r.tenant_id,r.employer_id,r.id,r.revision+1,'SYNTHETIC_NONLEGAL_ROLLBACK',m,o,'c4460000-0000-4000-8000-000000000001') RETURNING id INTO v;
  UPDATE payroll.runs SET candidate_id=v,revision=revision+1 WHERE tenant_id=r.tenant_id AND id=r.id;
  PERFORM public.payroll_candidate_approval(r.tenant_id,r.employer_id,r.period_id,r.id,v,r.revision+1,'approve','Privileged contract fixture only',gen_random_uuid());
 END LOOP;
END $$;
-- Force failure on the second append, proving the first append and shared source roll back together.
CREATE FUNCTION pg_temp.cross_second_append_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF current_setting('test.force_second_failure',true)='yes' AND NEW.tenant_id='c4461000-0000-4000-8000-000000000001' AND (SELECT count(*) FROM payroll.final_contexts WHERE tenant_id=NEW.tenant_id)>=3 THEN RAISE EXCEPTION 'synthetic_second_append_failure' USING ERRCODE='23514';END IF;RETURN NEW;
END $$;
CREATE TRIGGER cross_second_append_failure BEFORE INSERT ON payroll.final_contexts FOR EACH ROW EXECUTE FUNCTION pg_temp.cross_second_append_failure();
SELECT set_config('test.force_second_failure','yes',true);
SELECT throws_ok($$SELECT payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',gen_random_uuid())$$,'23514','synthetic_second_append_failure','Failure on second Employer rolls the whole correction batch back');
SELECT is((SELECT count(*)::integer FROM payroll.final_contexts WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),2,'No partial successor remains after forced second-output failure');
SELECT is((SELECT count(*)::integer FROM payroll.output_successions WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),0,'No partial succession survives failed batch');
SELECT is((SELECT count(*)::integer FROM payroll.correction_source_effects WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),0,'Exact source effect proof rolls back with the batch');
SELECT is((SELECT v.data->>'mode' FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id='c4461000-0000-4000-8000-000000000001' AND h.kind='policy'),'calendar_days','Failed batch preserves the actual shared policy');
SELECT set_config('test.force_second_failure','no',true);
SELECT set_config('test.batch_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.batch_result',payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.batch_attempt')::uuid)::text,true);
SELECT is(jsonb_array_length(current_setting('test.batch_result')::jsonb->'replacements'),2,'One transaction replaces both never-paid outputs');
SELECT is((SELECT count(*)::integer FROM payroll.output_successions WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),2,'Each original has exactly one immutable replacement link');
SELECT is((SELECT v.data->>'mode' FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id='c4461000-0000-4000-8000-000000000001' AND h.kind='policy'),'fixed_30_day','Shared source changes only with successful atomic output succession');
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND output_id=current_setting('test.output_b')::uuid),'1161.29','Original Employer B financial history stays immutable');
SELECT is((SELECT e.net::text FROM payroll.output_successions s JOIN payroll.final_employees e ON e.tenant_id=s.tenant_id AND e.output_id=s.replacement_output WHERE s.tenant_id='c4461000-0000-4000-8000-000000000001' AND s.original_output=current_setting('test.output_b')::uuid AND e.employment_id='c4465000-0000-4000-8000-000000000003'),'1200.00','Employer B successor keeps its exact recalculated partial amount and Employment identity');
SELECT is((SELECT count(*)::integer FROM payroll.final_contexts WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),4,'History contains two originals and two successors');
SELECT is(payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.batch_attempt')::uuid),current_setting('test.batch_result')::jsonb,'Same attempt recovers both successors without repeating source effects');
SELECT is((SELECT count(*)::integer FROM payroll.final_contexts WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),4,'Receipt replay creates no additional financial output');
SELECT * FROM finish();
ROLLBACK;

