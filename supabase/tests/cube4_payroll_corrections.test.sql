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
RESET ROLE;
-- Privileged test-only candidate result. No legal pack is inserted or claimed qualified.
-- This simulates an eventual trusted adapter contract solely to exercise approval/append atomicity inside ROLLBACK.
SELECT set_config('test.percentage_component',(public.payroll_save_input('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"key":"percentage_control","name":"Synthetic percentage control","classification":"earning","calculation":"percentage","base":"base_pay","value":"10","taxable":false,"social":false,"visible":true,"active":true,"proration":"salary_proration","order":"1","behavior":"recurring","reason":"Canonical enum regression"}','save',gen_random_uuid())->>'id'),true);
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

-- New assertions only. Synthetic fixture above is not a qualified legal adapter.
CREATE FUNCTION pg_temp.propose(p_amount numeric,p_case uuid DEFAULT NULL,p_expected integer DEFAULT 0,p_rows jsonb DEFAULT '[]',p_changes jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE changes jsonb;preview jsonb;BEGIN
 changes:=COALESCE(p_changes,jsonb_build_array(jsonb_build_object('type','compensation','source_id','c4466000-0000-4000-8000-000000000001','expected_hash',payroll.source_hash((SELECT to_jsonb(v) FROM people.compensation_versions v WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id='c4466000-0000-4000-8000-000000000001')),'fields',jsonb_build_object('amount',p_amount))));
 preview:=public.payroll_correction_proposal('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,p_case,p_expected,changes,p_rows,NULL,'Attributable synthetic source correction','Reviewed source reference',NULL,'preview',gen_random_uuid());
 RETURN public.payroll_correction_proposal('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,p_case,p_expected,changes,p_rows,NULL,'Attributable synthetic source correction','Reviewed source reference',preview->>'preview_hash','save',gen_random_uuid());
END $$;
CREATE FUNCTION pg_temp.command(operation text,expected integer) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_correction_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,expected,operation,'Reviewed synthetic correction operation',gen_random_uuid())
$$;
SELECT is(has_function_privilege('authenticated','payroll.source_effect_authorized(text,text,jsonb,jsonb)','EXECUTE'),false,'ordinary callers cannot manufacture correction source proof');
SELECT is(has_function_privilege('authenticated','payroll.append_correction_outputs(uuid,uuid,integer,uuid,uuid)','EXECUTE'),false,'atomic financial replacement is private; G6 is not exposed');
SELECT set_config('test.case',(pg_temp.propose(3300)->>'case_id'),true);
SELECT is((SELECT amount::text FROM people.compensation_versions WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id='c4466000-0000-4000-8000-000000000001'),'3000.00','saving proposal leaves source unchanged');
SELECT is((SELECT count(*)::integer FROM payroll.output_successions WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),0,'original remains authoritative before replacement');
SELECT pg_temp.command('calculate',1);
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'review','unpaid amendment calculates attributable overlay');
SELECT pg_temp.command('approve',2);
SELECT throws_ok($$SELECT public.payroll_correction_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'cancel','No implicit release',gen_random_uuid())$$,'23514','payroll_correction_release_required','approved proposal requires explicit release before cancel');
SELECT set_config('test.amendment',(SELECT run_id::text FROM payroll.amendment_runs WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),true);
SELECT throws_ok($$SELECT public.payroll_candidate_approval('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.amendment')::uuid,(SELECT candidate_id FROM payroll.runs WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.amendment')::uuid),1,'approve','Unqualified remains blocked',gen_random_uuid())$$,'23514','payroll_approval_blocked','proposal approval does not fabricate qualified net');
-- Privileged synthetic adapter output inserted as a new immutable candidate, never rewritten.
DO $$ DECLARE r payroll.runs%ROWTYPE;m jsonb;o jsonb;employees jsonb;candidate uuid;BEGIN
 SELECT * INTO r FROM payroll.runs WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.amendment')::uuid;
 m:=payroll.amendment_manifest(r.tenant_id,r.id);o:=payroll.build_review(m);
 SELECT jsonb_agg(jsonb_set(jsonb_set(jsonb_set(e,'{issues}','[]'),'{net}',to_jsonb(e->>'base')),'{statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')) INTO employees FROM jsonb_array_elements(o->'employees')e;
 o:=jsonb_set(jsonb_set(jsonb_set(jsonb_set(o,'{issues}','[]'),'{employees}',employees),'{financially_qualified}','true'),'{net}',to_jsonb((SELECT sum((e->>'net')::numeric)::text FROM jsonb_array_elements(employees)e)));
 INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,revision,engine_version,input_manifest,output,created_by) VALUES(r.tenant_id,r.employer_id,r.id,r.revision+1,'SYNTHETIC_NONLEGAL_ROLLBACK',m,o,'c4460000-0000-4000-8000-000000000001') RETURNING id INTO candidate;
 UPDATE payroll.runs SET candidate_id=candidate,revision=revision+1 WHERE tenant_id=r.tenant_id AND id=r.id;
 PERFORM public.payroll_candidate_approval(r.tenant_id,r.employer_id,r.period_id,r.id,candidate,r.revision+1,'approve','Synthetic adapter contract only',gen_random_uuid());
END $$;
SELECT set_config('test.batch_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.replacement_result',payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.batch_attempt')::uuid)::text,true);
SELECT is((SELECT amount::text FROM people.compensation_versions WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id='c4466000-0000-4000-8000-000000000001'),'3300.00','atomic replacement applies exact approved compensation');
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND output_id=current_setting('test.output')::uuid AND employment_id='c4465000-0000-4000-8000-000000000001'),'3000.00','original immutable financial output survives source correction');
SELECT is((SELECT count(*)::integer FROM payroll.output_successions WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),1,'one exact same-period replacement link');
SELECT is(payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.batch_attempt')::uuid),current_setting('test.replacement_result')::jsonb,'batch receipt recovers original result without duplicate append');
SELECT is((SELECT count(*)::integer FROM payroll.correction_source_effects WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),1,'source effect applies once across batch replay');
SELECT set_config('test.output',(current_setting('test.replacement_result')::jsonb->'replacements'->0->>'replacement_output'),true);
SELECT public.payroll_record_payment('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,0,'allocations',CURRENT_DATE,'Synthetic actual evidence','External payment fixture','[{"employment_id":"c4465000-0000-4000-8000-000000000001","amount":"100"}]',NULL,true,gen_random_uuid());
SELECT set_config('test.rows',jsonb_build_array(jsonb_build_object('output_id',current_setting('test.output'),'employment_id','c4465000-0000-4000-8000-000000000001','amount','100','basis','external_reviewed','reference','Manual reviewed basis','source','Independent attributable settlement responsibility; not statutory net'))::text,true);
SELECT set_config('test.case',(pg_temp.propose(3400,NULL,0,current_setting('test.rows')::jsonb)->>'case_id'),true);
SELECT pg_temp.command('approve',1);
SELECT pg_temp.command('route_paid',2);
SELECT is((SELECT amount::text FROM people.compensation_versions WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id='c4466000-0000-4000-8000-000000000001'),'3400.00','paid correction executes approved source without replacing paid original');
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND output_id=current_setting('test.output')::uuid AND employment_id='c4465000-0000-4000-8000-000000000001'),'3300.00','paid original obligation is unchanged');
SELECT throws_ok($$SELECT public.payroll_correction_settlement('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4465000-0000-4000-8000-000000000001','employee_extra_payment',101,CURRENT_DATE,'Evidence excess','Reviewed evidence',gen_random_uuid())$$,'23514','payroll_settlement_excess','external evidence cannot exceed approved responsibility');
SELECT public.payroll_correction_settlement('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4465000-0000-4000-8000-000000000001','employee_extra_payment',100,CURRENT_DATE,'Actual independent settlement','Reviewed external evidence',gen_random_uuid());
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'routed','external evidence does not fabricate statutory reconciliation completion');
SELECT is((SELECT sum(amount)::text FROM payroll.correction_settlements WHERE tenant_id='c4461000-0000-4000-8000-000000000001'),'100.00','separate attributable settlement evidence ledger');
SELECT is(payroll.output_has_ever_paid('c4461000-0000-4000-8000-000000000001',current_setting('test.output')::uuid),true,'paid fact remains permanent after correction');

-- Newly eligible Employment is planned before physical insertion; its target must remain executable.
SELECT set_config('test.next_period',(public.payroll_generate_next_period('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',(SELECT revision FROM payroll.calendar_heads WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND employer_id='c4463000-0000-4000-8000-000000000001'),gen_random_uuid(),payroll.preview_dates('2030-02-25',24,25,'ending','Africa/Cairo'))->>'period_id'),true);
SELECT set_config('test.correction_component',(public.payroll_save_input('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2030-02-25',NULL,'{"key":"correction","name":"Synthetic reviewed carry-forward","classification":"earning","calculation":"fixed","base":"","value":"0","taxable":false,"social":false,"visible":true,"active":true,"proration":"salary_proration","order":"1","behavior":"period_input","reason":"Reviewed test setup only"}','save',gen_random_uuid())->>'id'),true);
SELECT set_config('test.new_changes','[{"type":"new_employment","fields":{"employee_code":"MISSED","full_name":"Synthetic previously omitted Employee","start_date":"2030-01-01","pay_basis":"monthly","payroll_eligible":true,"amount":"500","site_id":"c4463500-0000-4000-8000-000000000001"}}]',true);
SELECT set_config('test.new_rows',jsonb_build_array(jsonb_build_object('output_id',current_setting('test.output'),'employment_ref','new:0','amount','20','basis','period_component','component_id',current_setting('test.correction_component'),'target_period',current_setting('test.next_period'),'reference','Approved independent carry-forward','source','Manual reviewed responsibility; not a statutory delta'))::text,true);
SELECT set_config('test.case',(pg_temp.propose(0,NULL,0,current_setting('test.new_rows')::jsonb,current_setting('test.new_changes')::jsonb)->>'case_id'),true);
SELECT is((SELECT count(*)::integer FROM people.employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND employee_code='MISSED'),0,'new Employment proposal needs no preinserted Employee or Employment');
SELECT pg_temp.command('approve',1);
SELECT pg_temp.command('route_paid',2);
SELECT is((SELECT count(*)::integer FROM people.employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND employee_code='MISSED'),1,'approved route inserts omitted Employee atomically');
SELECT is((SELECT count(*)::integer FROM payroll.correction_targets WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),1,'generated Employment identity reaches approved later-period target');
SELECT is((SELECT status FROM payroll.input_versions v JOIN payroll.correction_targets t ON t.tenant_id=v.tenant_id AND t.head_id=v.head_id WHERE t.tenant_id='c4461000-0000-4000-8000-000000000001' AND t.case_id=current_setting('test.case')::uuid),'approved','carry-forward creation is approved input, not applied money or settled responsibility');
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'routed','later-period input leaves accountable responsibility open');
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND output_id=current_setting('test.output')::uuid AND employment_id='c4465000-0000-4000-8000-000000000001'),'3300.00','new eligibility never rewrites original paid obligation');

-- mixed disposition: one already-paid original and one never-paid original in the same source window.
CREATE FUNCTION pg_temp.synthetic_final(p_period uuid,p_amendment uuid DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE r payroll.runs%ROWTYPE;m jsonb;o jsonb;employees jsonb;candidate uuid;BEGIN
 IF p_amendment IS NULL THEN INSERT INTO payroll.runs(tenant_id,employer_id,period_id,status,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',p_period,'draft','c4460000-0000-4000-8000-000000000001') RETURNING * INTO r;
 ELSE SELECT * INTO r FROM payroll.runs WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=p_amendment;END IF;
 m:=CASE WHEN p_amendment IS NULL THEN payroll.run_manifest(r.tenant_id,r.employer_id,r.period_id) ELSE payroll.amendment_manifest(r.tenant_id,r.id) END;
 o:=CASE WHEN p_amendment IS NULL THEN payroll.build_review(m) ELSE payroll.build_correction_review(m) END;
 SELECT jsonb_agg(jsonb_set(jsonb_set(jsonb_set(e,'{issues}','[]'),'{net}',to_jsonb(e->>'gross')),'{statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-02","2030-03"]}')) INTO employees FROM jsonb_array_elements(o->'employees')e;
 o:=jsonb_set(jsonb_set(jsonb_set(jsonb_set(o,'{issues}','[]'),'{employees}',employees),'{financially_qualified}','true'),'{net}',to_jsonb((SELECT sum((e->>'net')::numeric)::text FROM jsonb_array_elements(employees)e)));
 INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,revision,engine_version,input_manifest,output,created_by) VALUES(r.tenant_id,r.employer_id,r.id,r.revision+1,'SYNTHETIC_NONLEGAL_ROLLBACK',m,o,'c4460000-0000-4000-8000-000000000001') RETURNING id INTO candidate;
 UPDATE payroll.runs SET status='review',candidate_id=candidate,revision=revision+1 WHERE tenant_id=r.tenant_id AND id=r.id;
 PERFORM public.payroll_candidate_approval(r.tenant_id,r.employer_id,r.period_id,r.id,candidate,r.revision+1,'approve','Synthetic adapter contract only',gen_random_uuid());
 IF p_amendment IS NULL THEN RETURN payroll.append_final_output(r.tenant_id,r.id,candidate,'c4460000-0000-4000-8000-000000000001',r.revision+2,gen_random_uuid());END IF;
 RETURN r.id;
END $$;
SELECT set_config('test.unpaid_output',pg_temp.synthetic_final(current_setting('test.next_period')::uuid)::text,true);
SELECT is((SELECT status FROM payroll.input_versions v JOIN payroll.correction_targets t ON t.tenant_id=v.tenant_id AND t.head_id=v.head_id WHERE t.tenant_id='c4461000-0000-4000-8000-000000000001' ORDER BY v.revision DESC LIMIT 1),'applied','original locked output consumed the approved carry-forward fixture');
SELECT set_config('test.case',(pg_temp.propose(3600,NULL,0,current_setting('test.rows')::jsonb)->>'case_id'),true);
SELECT is((SELECT jsonb_array_length(source_scope->'affected_outputs') FROM payroll.correction_proposals p JOIN payroll.correction_cases c ON c.tenant_id=p.tenant_id AND c.proposal_id=p.id WHERE c.tenant_id='c4461000-0000-4000-8000-000000000001' AND c.id=current_setting('test.case')::uuid),2,'mixed source change discovers both active outputs');
SELECT pg_temp.command('calculate',1);
SELECT is((SELECT count(*)::integer FROM payroll.amendment_runs WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),1,'only never-paid output gets a replacement candidate');
SELECT is((SELECT sum((line->>'amount')::numeric)::text FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id JOIN payroll.candidates c ON c.tenant_id=r.tenant_id AND c.id=r.candidate_id CROSS JOIN LATERAL jsonb_array_elements(c.output->'employees')e CROSS JOIN LATERAL jsonb_array_elements(e->'lines')line WHERE m.tenant_id='c4461000-0000-4000-8000-000000000001' AND m.case_id=current_setting('test.case')::uuid AND line->>'component' IN(SELECT 'adjustment:'||head_id FROM payroll.correction_targets WHERE tenant_id='c4461000-0000-4000-8000-000000000001')),'20.00','amendment preserves original consumed adjustment exactly once');
SELECT pg_temp.command('approve',2);
SELECT throws_ok($$SELECT pg_temp.command('route_paid',3)$$,'23514','payroll_mixed_dispositions_require_atomic_finalization','public paid-only route cannot hide required unpaid replacement');
SELECT is((SELECT amount::text FROM people.compensation_versions WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id='c4466000-0000-4000-8000-000000000001'),'3400.00','refused mixed public execution leaves source unchanged');
SELECT set_config('test.amendment',(SELECT run_id::text FROM payroll.amendment_runs WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND case_id=current_setting('test.case')::uuid),true);
SELECT pg_temp.synthetic_final(current_setting('test.next_period')::uuid,current_setting('test.amendment')::uuid);
SELECT set_config('test.mixed_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.mixed_result',payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.mixed_attempt')::uuid)::text,true);
SELECT is(jsonb_array_length(current_setting('test.mixed_result')::jsonb->'replacements'),1,'mixed atomic execution replaces only never-paid output');
SELECT is((SELECT count(*)::integer FROM payroll.output_successions WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND original_output=current_setting('test.output')::uuid),0,'mixed execution preserves ever-paid original identity');
SELECT is((SELECT net::text FROM payroll.final_employees WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND output_id=current_setting('test.output')::uuid AND employment_id='c4465000-0000-4000-8000-000000000001'),'3300.00','mixed execution preserves paid original money');
SELECT is((SELECT count(*)::integer FROM payroll.output_successions WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND original_output=current_setting('test.unpaid_output')::uuid),1,'unpaid member has one attributable successor');
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'routed','mixed responsibility remains open after atomic replacement');
SELECT is(payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.mixed_attempt')::uuid),current_setting('test.mixed_result')::jsonb,'mixed replay recovers same receipt without extra source effect or succession');
SELECT throws_ok($$SELECT public.payroll_run_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.next_period')::uuid,NULL,0,'calculate','Ordinary run cannot bypass correction history',gen_random_uuid())$$,'23514','payroll_correction_required','ordinary calculation cannot recreate a financially finalized period');

SELECT throws_ok($$INSERT INTO payroll.runs(tenant_id,employer_id,period_id,amendment_of,created_by) VALUES('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000003',current_setting('test.period')::uuid,current_setting('test.output')::uuid,'c4460000-0000-4000-8000-000000000001')$$,'23514','payroll_amendment_scope_invalid','amendment cannot cross original legal Employer identity');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('c4461000-0000-4000-8000-000000000001','c4460000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000005');
DELETE FROM platform_core.membership_roles WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND user_id='c4460000-0000-4000-8000-000000000001' AND role_id='c4462000-0000-4000-8000-000000000001';
SELECT throws_ok($$SELECT public.payroll_correction_workspace('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,current_setting('test.case')::uuid,'compensation')$$,'42501','payroll_forbidden','correction privilege alone never grants private compensation source projection');
SELECT throws_ok($$SELECT payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.mixed_attempt')::uuid)$$,'42501','payroll_forbidden','receipt replay requires current financial authority');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('c4461000-0000-4000-8000-000000000001','c4460000-0000-4000-8000-000000000001','c4462000-0000-4000-8000-000000000001');
SELECT is(payroll.append_correction_outputs('c4461000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'c4460000-0000-4000-8000-000000000001',current_setting('test.mixed_attempt')::uuid),current_setting('test.mixed_result')::jsonb,'restored current authority recovers original mixed receipt');
-- S6-R4 canonical contract through actual proposal preview/save; no source application.
CREATE FUNCTION pg_temp.input_proposal(p_head uuid,p_patch jsonb) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE h payroll.input_heads%ROWTYPE;v payroll.input_versions%ROWTYPE;result jsonb;BEGIN
 SELECT * INTO h FROM payroll.input_heads WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id=p_head;
 SELECT * INTO v FROM payroll.input_versions WHERE tenant_id=h.tenant_id AND head_id=h.id AND revision=h.revision;
 result:=pg_temp.propose(0,NULL,0,current_setting('test.rows')::jsonb,jsonb_build_array(jsonb_build_object('type','input_revision','source_id',h.id,'expected_hash',payroll.source_hash(to_jsonb(v)),'fields',jsonb_build_object('effective_from',v.effective_from,'effective_until',v.effective_until,'data',v.data||p_patch,'cancelled',false))));RETURN(result->>'case_id')::uuid;
END $$;
SELECT set_config('test.enum_case',pg_temp.input_proposal(current_setting('test.correction_component')::uuid,'{"name":"Fixed control renamed"}')::text,true);
SELECT is((SELECT p.typed_changes->0->'fields'->'data'->>'base' FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id WHERE c.tenant_id='c4461000-0000-4000-8000-000000000001' AND c.id=current_setting('test.enum_case')::uuid),'','fixed correction preserves empty canonical base');
SELECT public.payroll_correction_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.enum_case')::uuid,1,'cancel','Canonical fixture complete',gen_random_uuid());
SELECT set_config('test.enum_case',pg_temp.input_proposal(current_setting('test.percentage_component')::uuid,'{"name":"Percentage control renamed"}')::text,true);
SELECT is((SELECT p.typed_changes->0->'fields'->'data'->>'base' FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id WHERE c.tenant_id='c4461000-0000-4000-8000-000000000001' AND c.id=current_setting('test.enum_case')::uuid),'base_pay','percentage correction preserves canonical base_pay');
SELECT public.payroll_correction_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.enum_case')::uuid,1,'cancel','Canonical fixture complete',gen_random_uuid());
SELECT set_config('test.enum_case',pg_temp.input_proposal((SELECT id FROM payroll.input_heads WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND kind='policy'),'{"mode":"fixed_30_day"}')::text,true);
SELECT is((SELECT p.typed_changes->0->'fields'->'data'->>'mode' FROM payroll.correction_cases c JOIN payroll.correction_proposals p ON p.tenant_id=c.tenant_id AND p.id=c.proposal_id WHERE c.tenant_id='c4461000-0000-4000-8000-000000000001' AND c.id=current_setting('test.enum_case')::uuid),'fixed_30_day','displayed 30-day policy saves canonical enum');
SELECT public.payroll_correction_command('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.enum_case')::uuid,1,'cancel','Canonical fixture complete',gen_random_uuid());
-- S6-R5 future fixture choices do not change protected historical eligibility.
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name) SELECT 'c4461000-0000-4000-8000-000000000001',('c4467100-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'c4463000-0000-4000-8000-000000000001','Later site '||i FROM generate_series(1,31)i;
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) SELECT 'c4461000-0000-4000-8000-000000000001',('c4467200-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'FUTURE'||i,'Later Employee '||i,'c4460000-0000-4000-8000-000000000001' FROM generate_series(1,31)i;
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) SELECT 'c4461000-0000-4000-8000-000000000001',('c4467300-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,('c4467200-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'c4463000-0000-4000-8000-000000000001','2035-01-01','monthly' FROM generate_series(1,31)i;
UPDATE people.compensation_versions SET valid_until='2035-01-01' WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id='c4466000-0000-4000-8000-000000000001';
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from,valid_until) SELECT 'c4461000-0000-4000-8000-000000000001',('c4467400-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'c4465000-0000-4000-8000-000000000001',200,'2035-01-01'::date+i-1,'2035-01-01'::date+i FROM generate_series(1,31)i;
SELECT set_config('test.choice_page',public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'assignment','site_id')::text,true);
SELECT is(jsonb_array_length(current_setting('test.choice_page')::jsonb->'items'),30,'site projection keeps 30-item bound');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'assignment','site_id','',current_setting('test.choice_page')::jsonb->>'next')->'items')x WHERE x->>'id'='c4467100-0000-4000-8000-000000000031'),'site 31 is reachable with independent cursor');
SELECT is(public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'assignment','site_id','',NULL,'c4467100-0000-4000-8000-000000000031')->'selected'->>'name','Later site 31','selected reference outside page one retains actual label');
SELECT is(jsonb_array_length(public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'assignment','employees','Later Employee 31')->'items'),1,'Employee beyond page one is searchable without raw identity entry');
SELECT set_config('test.source_page',public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'compensation','sources','',NULL,NULL,NULL,'c4465000-0000-4000-8000-000000000001')::text,true);
SELECT is(jsonb_array_length(current_setting('test.source_page')::jsonb->'items'),30,'source projection has own 30-item bound');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'compensation','sources','',current_setting('test.source_page')::jsonb->>'next',NULL,NULL,'c4465000-0000-4000-8000-000000000001')->'items')x WHERE x->>'id'='c4467400-0000-4000-8000-000000000031'),'source 31 is reachable independently of Employee cursor');
SELECT is(public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'compensation','sources','',NULL,'c4467400-0000-4000-8000-000000000031',NULL,'c4465000-0000-4000-8000-000000000001')->'selected'->'fields'->>'amount','200.00','selected later source includes canonical fields for preview');
UPDATE people.work_assignments SET valid_until='2035-01-01' WHERE tenant_id='c4461000-0000-4000-8000-000000000001' AND id='c4466500-0000-4000-8000-000000000001';
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4461000-0000-4000-8000-000000000001','c4467500-0000-4000-8000-000000000001','c4465000-0000-4000-8000-000000000001','c4467100-0000-4000-8000-000000000031','2035-01-01');
SELECT set_config('test.assignment_choice',public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'assignment','sources','',NULL,'c4467500-0000-4000-8000-000000000001',NULL,'c4465000-0000-4000-8000-000000000001')::text,true);
SELECT is(public.payroll_correction_choices('c4461000-0000-4000-8000-000000000001','c4463000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'assignment','site_id','',NULL,(current_setting('test.assignment_choice')::jsonb->'selected'->'fields'->>'site_id')::uuid)->'selected'->>'name','Later site 31','existing assignment reference beyond page one preserves its scoped human label');
SELECT * FROM finish();
ROLLBACK;
