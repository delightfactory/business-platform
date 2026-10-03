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
CREATE FUNCTION pg_temp.approval(operation text DEFAULT 'approve',expected integer DEFAULT 1,attempt uuid DEFAULT 'c4469100-0000-4000-8000-000000000001',reason text DEFAULT 'Synthetic candidate reviewed') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_candidate_approval('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,expected,operation,reason,attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.approval(text,integer,uuid,text) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4460000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Synthetic foundation calendar')->>'period_id'),true);
SELECT public.payroll_save_input('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic proration"}','save',gen_random_uuid());
SELECT set_config('test.range_data','{"key":"range_bonus","name":"Synthetic range bonus","classification":"earning","calculation":"fixed","base":"","value":"200","taxable":false,"social":false,"visible":true,"active":true,"proration":"salary_proration","order":"1","behavior":"recurring","reason":"Range regression only"}',true);
SELECT set_config('test.range_component',(public.payroll_save_input('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2030-01-01',NULL,current_setting('test.range_data')::jsonb,'save',gen_random_uuid())->>'id'),true);
SELECT public.payroll_save_input('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','recurring','c4465000-0000-4000-8000-000000000001',NULL,NULL,0,'2030-01-01',NULL,jsonb_build_object('component_id',current_setting('test.range_component'),'value','200','reason','Synthetic recurring range source'),'save',gen_random_uuid());
SELECT public.payroll_save_input('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','component',NULL,NULL,current_setting('test.range_component')::uuid,1,'2030-03-25',NULL,jsonb_set(current_setting('test.range_data')::jsonb,'{active}','false'),'save',gen_random_uuid());
RESET ROLE;
-- Privileged test-only candidate result. No legal pack is inserted or claimed qualified.
-- This simulates an eventual trusted adapter contract solely to exercise approval/append atomicity inside ROLLBACK.
SELECT set_config('test.run','c4469200-0000-4000-8000-000000000001',true);
SELECT set_config('test.candidate','c4469200-0000-4000-8000-000000000002',true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,'draft','c4460000-0000-4000-8000-000000000001');
SELECT set_config('test.manifest',payroll.run_manifest('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT set_config('test.synthetic_output',payroll.build_review(current_setting('test.manifest')::jsonb)::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"4200"')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,0,net}','"3200"'),'{employees,0,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,1,net}','"1000"'),'{employees,1,issues}','[]'),'{employees,1,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.manifest')::jsonb,current_setting('test.synthetic_output')::jsonb,'c4460000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id=current_setting('test.candidate')::uuid,revision=1 WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
SET LOCAL ROLE authenticated;
SELECT pg_temp.approval();
RESET ROLE;
SELECT set_config('test.output',payroll.append_final_output('c4461000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4460000-0000-4000-8000-000000000001',2,gen_random_uuid())::text,true);


-- S6-R1 and S6-R3: real source discovery, privileged NONLEGAL finals, rollback only.
SELECT set_config('test.t','c4461000-0000-4000-8000-000000000001',true),set_config('test.e','c4463000-0000-4000-8000-000000000001',true),set_config('test.a','c4460000-0000-4000-8000-000000000001',true);
CREATE FUNCTION pg_temp.range_final(day date) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE t uuid:=current_setting('test.t')::uuid;e uuid:=current_setting('test.e')::uuid;a uuid:=current_setting('test.a')::uuid;p uuid;r uuid:=gen_random_uuid();v uuid:=gen_random_uuid();m jsonb;o jsonb;employees jsonb;BEGIN
 p:=(public.payroll_generate_next_period(t,e,(SELECT revision FROM payroll.calendar_heads WHERE tenant_id=t AND employer_id=e),gen_random_uuid(),payroll.preview_dates(day,24,25,'ending','Africa/Cairo'))->>'period_id')::uuid;
 INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES(t,e,p,r,'draft',a);
 m:=payroll.run_manifest(t,e,p);o:=payroll.build_review(m);
 SELECT jsonb_agg(jsonb_set(jsonb_set(jsonb_set(x,'{issues}','[]'),'{net}',to_jsonb(x->>'known_gross')),'{statutory_context}',jsonb_build_object('calendar_year',2030,'category','SYNTHETIC_NONLEGAL','insured_wage_source','ROLLBACK_FIXTURE_ONLY','insured_wage','0.00','obligation_months',jsonb_build_array(to_char(day,'YYYY-MM'),to_char((m->'period'->>'ends_on')::date,'YYYY-MM'))))) INTO employees FROM jsonb_array_elements(o->'employees')x;
 o:=jsonb_set(jsonb_set(jsonb_set(jsonb_set(o,'{issues}','[]'),'{employees}',employees),'{financially_qualified}','true'),'{net}',to_jsonb((SELECT sum((x->>'net')::numeric)::text FROM jsonb_array_elements(employees)x)));
 INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES(t,e,r,v,1,'SYNTHETIC_NONLEGAL_ROLLBACK',m,o,a);
 UPDATE payroll.runs SET status='review',candidate_id=v,revision=1 WHERE tenant_id=t AND id=r;
 PERFORM public.payroll_candidate_approval(t,e,p,r,v,1,'approve','Synthetic source-range contract only',gen_random_uuid());
 RETURN payroll.append_final_output(t,r,v,a,2,gen_random_uuid());
END $$;
SELECT set_config('test.range_b',pg_temp.range_final('2030-02-25')::text,true);
SELECT set_config('test.range_c',pg_temp.range_final('2030-03-25')::text,true);
SELECT is((SELECT sum(net)::text FROM payroll.final_employees WHERE tenant_id=current_setting('test.t')::uuid AND output_id=current_setting('test.output')::uuid),'4200.00','Original period contains the open-ended recurring source');
SELECT is((SELECT sum(net)::text FROM payroll.final_employees WHERE tenant_id=current_setting('test.t')::uuid AND output_id=current_setting('test.range_b')::uuid),'4200.00','Later period contains the same recurring source');
SELECT is((SELECT sum(net)::text FROM payroll.final_employees WHERE tenant_id=current_setting('test.t')::uuid AND output_id=current_setting('test.range_c')::uuid),'4000.00','Independent future inactive version already governs the third period');
CREATE FUNCTION pg_temp.range_propose(changes jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE t uuid:=current_setting('test.t')::uuid;e uuid:=current_setting('test.e')::uuid;o uuid:=current_setting('test.output')::uuid;preview jsonb;BEGIN
 preview:=public.payroll_correction_proposal(t,e,o,NULL,0,changes,'[]',NULL,'Reviewed source-range correction','Attributable source range',NULL,'preview',gen_random_uuid());
 RETURN public.payroll_correction_proposal(t,e,o,NULL,0,changes,'[]',NULL,'Reviewed source-range correction','Attributable source range',preview->>'preview_hash','save',gen_random_uuid());
END $$;
SELECT set_config('test.range_changes',(SELECT jsonb_build_array(jsonb_build_object('type','input_revision','source_id',h.id,'expected_hash',payroll.source_hash(to_jsonb(v)),'fields',jsonb_build_object('effective_from','2030-01-01','effective_until','2030-02-01','cancelled',false,'data',current_setting('test.range_data')::jsonb))) FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id=current_setting('test.t')::uuid AND h.id=current_setting('test.range_component')::uuid)::text,true);
SELECT set_config('test.range_case',(pg_temp.range_propose(current_setting('test.range_changes')::jsonb)->>'case_id'),true);
CREATE FUNCTION pg_temp.range_scope() RETURNS jsonb LANGUAGE sql AS $$
 SELECT p.source_scope->'affected_outputs' FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id WHERE c.tenant_id=current_setting('test.t')::uuid AND c.id=current_setting('test.range_case')::uuid
$$;
SELECT is(jsonb_array_length(pg_temp.range_scope()),2,'Expiry discovers both affected periods up to the next effective version');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.range_scope())x WHERE x->>'id'=current_setting('test.range_b')),'Final output beyond the new expiry remains inside correction scope');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.range_scope())x WHERE x->>'id'=current_setting('test.range_c')),'Next dated version bounds influence without an unrelated third correction');
SELECT public.payroll_correction_command(current_setting('test.t')::uuid,current_setting('test.e')::uuid,current_setting('test.range_case')::uuid,1,'calculate','Calculate both affected periods',gen_random_uuid());
SELECT is((SELECT count(*)::integer FROM payroll.amendment_runs WHERE tenant_id=current_setting('test.t')::uuid AND case_id=current_setting('test.range_case')::uuid),2,'Every affected original gets an amendment candidate');
SELECT is((SELECT (v.output->>'known_gross')::numeric FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id JOIN payroll.candidates v ON v.tenant_id=r.tenant_id AND v.id=r.candidate_id WHERE m.tenant_id=current_setting('test.t')::uuid AND m.case_id=current_setting('test.range_case')::uuid AND r.amendment_of=current_setting('test.range_b')::uuid),4000::numeric,'Later amendment suppresses the expired recurring amount');
SELECT is((SELECT effective_until FROM payroll.input_versions WHERE tenant_id=current_setting('test.t')::uuid AND head_id=current_setting('test.range_component')::uuid AND revision=1),NULL::date,'Proposal/calculation retains the original open-ended source');
SELECT is((SELECT sum(net)::text FROM payroll.final_employees WHERE tenant_id=current_setting('test.t')::uuid AND output_id=current_setting('test.range_b')::uuid),'4200.00','Later original money remains authoritative before atomic replacement');
SELECT public.payroll_correction_command(current_setting('test.t')::uuid,current_setting('test.e')::uuid,current_setting('test.range_case')::uuid,2,'cancel','Cancel without applying source',gen_random_uuid());
SELECT public.payroll_record_payment(current_setting('test.t')::uuid,current_setting('test.e')::uuid,current_setting('test.range_b')::uuid,0,'allocations',CURRENT_DATE,'Unrelated later payment','Synthetic paid period outside insertion','[{"employment_id":"c4465000-0000-4000-8000-000000000001","amount":"100"}]',NULL,true,gen_random_uuid());
SELECT set_config('test.short_changes','[{"type":"new_employment","fields":{"employee_code":"SHORT_RANGE","full_name":"Synthetic short omitted Employment","start_date":"2030-01-25","end_date":"2030-01-31","pay_basis":"monthly","payroll_eligible":true,"amount":"500","site_id":"c4463500-0000-4000-8000-000000000001"}}]',true);
SELECT set_config('test.range_case',(pg_temp.range_propose(current_setting('test.short_changes')::jsonb)->>'case_id'),true);
SELECT is(jsonb_array_length(pg_temp.range_scope()),1,'New Employment and its dated children affect only the intersecting period');
SELECT is(pg_temp.range_scope()->0->>'id',current_setting('test.output'),'Insertion keeps the exact overlapping original identity');
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id=current_setting('test.t')::uuid AND id=current_setting('test.range_case')::uuid),'draft','An unrelated paid period requires no impossible responsibility');
SELECT is((SELECT count(*)::integer FROM people.employees WHERE tenant_id=current_setting('test.t')::uuid AND employee_code='SHORT_RANGE'),0,'Proposal never inserts the omitted People source early');
SELECT * FROM finish();
ROLLBACK;
