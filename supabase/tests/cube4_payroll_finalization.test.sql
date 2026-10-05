BEGIN;
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required';END IF;END $$;
SELECT no_plan();
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4440000-0000-4000-8000-000000000001','cube4-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4440000-0000-4000-8000-000000000002','cube4-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4441000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4440000-0000-4000-8000-000000000001'),
 ('c4441000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4440000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4441000-0000-4000-8000-000000000001','c4442000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve','payroll.lock','payroll.export']),
 ('c4441000-0000-4000-8000-000000000001','c4442000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4441000-0000-4000-8000-000000000001','c4440000-0000-4000-8000-000000000001','c4440000-0000-4000-8000-000000000001'),
 ('c4441000-0000-4000-8000-000000000001','c4440000-0000-4000-8000-000000000002','c4440000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4441000-0000-4000-8000-000000000001','c4440000-0000-4000-8000-000000000001','c4442000-0000-4000-8000-000000000001'),
 ('c4441000-0000-4000-8000-000000000001','c4440000-0000-4000-8000-000000000002','c4442000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4441000-0000-4000-8000-000000000002','c4443000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4441000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4440000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4441000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4440000-0000-4000-8000-000000000001','Cube4 QA only');
CREATE FUNCTION pg_temp.review_fixture(mode text DEFAULT 'calendar_days',basis text DEFAULT 'monthly',join_on date DEFAULT '2030-01-25',transition boolean DEFAULT false) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('engine','cube4-review-v2-exact','period',jsonb_build_object('id','c4448000-0000-4000-8000-000000000001','starts_on','2030-01-25','ends_on','2030-02-24','is_transition',transition),
 'employees',jsonb_build_array(jsonb_build_object('name','Fixture Employee','code','CALCQA','employment',jsonb_build_object('id','c4445000-0000-4000-8000-000000000001','employee_id','c4444000-0000-4000-8000-000000000001','pay_basis',basis,'start_date',join_on,'end_date',NULL))),
 'compensation',jsonb_build_array(jsonb_build_object('id','c4446000-0000-4000-8000-000000000001','employment_id','c4445000-0000-4000-8000-000000000001','valid_from','2030-01-01','valid_until',NULL,'amount',CASE WHEN basis='daily' THEN 100 ELSE 3000 END)),
 'assignments',jsonb_build_array(jsonb_build_object('employment_id','c4445000-0000-4000-8000-000000000001','valid_from','2030-01-01','valid_until',NULL)),
 'inputs',jsonb_build_array(jsonb_build_object('head',jsonb_build_object('id','c4447000-0000-4000-8000-000000000001','kind','policy'),'version',jsonb_build_object('revision',1,'effective_from','2030-01-01','effective_until',NULL,'status','draft','data',jsonb_build_object('mode',mode)))) || CASE WHEN basis='daily' THEN jsonb_build_array(jsonb_build_object('head',jsonb_build_object('id','c4447000-0000-4000-8000-000000000005','kind','manual_units','employment_id','c4445000-0000-4000-8000-000000000001','period_id','c4448000-0000-4000-8000-000000000001'),'version',jsonb_build_object('revision',1,'effective_from','2030-01-25','effective_until','2030-02-25','status','approved','data','{"units":"5"}'::jsonb))) ELSE '[]'::jsonb END,
 'packs','[]'::jsonb,'optional','{"time":false,"leave":false,"finance":"adjustments_only"}'::jsonb,'corrections','[]'::jsonb)
$$;
CREATE FUNCTION pg_temp.with_component(manifest jsonb,value numeric DEFAULT 300,method text DEFAULT 'fixed',proration text DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
 SELECT manifest||jsonb_build_object('inputs',manifest->'inputs'||jsonb_build_array(
 jsonb_build_object('head',jsonb_build_object('id','c4447000-0000-4000-8000-000000000002','kind','component'),'version',jsonb_build_object('id','c4447100-0000-4000-8000-000000000002','revision',1,'effective_from','2030-01-01','effective_until',NULL,'status','draft','data',jsonb_strip_nulls(jsonb_build_object('active','true','name','Fixture component','classification','earning','calculation',method,'base',CASE WHEN method='percentage' THEN 'base_pay' ELSE '' END,'behavior','recurring','proration',proration)))),
 jsonb_build_object('head',jsonb_build_object('id','c4447000-0000-4000-8000-000000000003','kind','recurring','employment_id','c4445000-0000-4000-8000-000000000001'),'version',jsonb_build_object('revision',1,'effective_from','2030-01-01','effective_until',NULL,'status','draft','data',jsonb_build_object('component_id','c4447000-0000-4000-8000-000000000002','value',value)))))
$$;
-- New exact arithmetic cases only; these are not statutory or golden qualification.
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4441000-0000-4000-8000-000000000001','c4443500-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4441000-0000-4000-8000-000000000001','c4444000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','c4440000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4441000-0000-4000-8000-000000000001','c4445000-0000-4000-8000-000000000001','c4444000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4441000-0000-4000-8000-000000000001','c4446000-0000-4000-8000-000000000001','c4445000-0000-4000-8000-000000000001',3000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4441000-0000-4000-8000-000000000001','c4446500-0000-4000-8000-000000000001','c4445000-0000-4000-8000-000000000001','c4443500-0000-4000-8000-000000000001','2030-01-01');
SELECT is((payroll.build_review(pg_temp.with_component(jsonb_set(jsonb_set(pg_temp.review_fixture(),'{period,ends_on}',to_jsonb(('2030-01-25'::date+days-1)::text)),'{compensation,0,amount}',to_jsonb(amount)),10,'percentage'))->'employees'->0->>'gross')::numeric,amount+round(amount*10/100,2),format('exact half-cent percentage salary %s ordinary %s days',amount,days)) FROM unnest(ARRAY[28,30,31])d(days) CROSS JOIN unnest(ARRAY[0.05,0.15,0.25]::numeric[])a(amount);
SELECT is(payroll.round_fraction('{"n":"-1","d":"200"}'),-0.01::numeric,'negative exact half-cent rounds away from zero');
SELECT is(payroll.round_fraction('{"n":"1","d":"201"}'),0::numeric,'below-half fraction is not nudged by an epsilon');
SELECT is((payroll.build_review(pg_temp.with_component(jsonb_set(jsonb_set(pg_temp.review_fixture(join_on=>'2030-02-21'),'{period,ends_on}','"2030-02-23"'),'{compensation,0,amount}','0.25'),0.25))->'employees'->0->>'gross')::numeric,0.06::numeric,'partial base and fixed recurring each exact .025 round to .03');
SELECT is((payroll.build_review(pg_temp.with_component(jsonb_set(pg_temp.review_fixture(join_on=>'2030-02-15',transition=>true),'{compensation,0,amount}','0.07'),0.07))->'employees'->0->>'gross')::numeric,0.06::numeric,'transition calendar denominator exact half-cent base and component');
SELECT is((payroll.build_review(pg_temp.with_component(jsonb_set(jsonb_set(pg_temp.review_fixture(basis=>'daily'),'{compensation,0,amount}','0.10'),'{inputs,1,version,data,units}','"0.50"'),10,'percentage'))->'employees'->0->>'gross')::numeric,0.06::numeric,'daily approved units and earned-base percentage preserve exact tie');
SELECT ok(payroll.stale_reasons('{"engine":"cube4-review-v1"}','{"engine":"cube4-review-v2-exact"}') ? 'engine_changed','new engine invalidates immutable previous candidates explicitly');
SELECT ok(NOT has_function_privilege('authenticated','payroll.finalize_run(uuid,uuid,uuid,uuid,uuid,integer,uuid)','EXECUTE'),'no ordinary finalization grant');
SELECT ok(NOT has_function_privilege('service_role','payroll.append_final_output(uuid,uuid,uuid,uuid,integer,uuid)','EXECUTE'),'no service-role private append bypass');
SELECT ok(NOT has_table_privilege('authenticated','payroll.final_contexts','SELECT'),'immutable final manifest not directly readable');
CREATE FUNCTION pg_temp.approval(operation text DEFAULT 'approve',expected integer DEFAULT 1,attempt uuid DEFAULT 'c4449100-0000-4000-8000-000000000001',reason text DEFAULT 'Synthetic candidate reviewed') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_candidate_approval('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,expected,operation,reason,attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.approval(text,integer,uuid,text) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4440000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Synthetic foundation calendar')->>'period_id'),true);
SELECT public.payroll_save_input('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic proration"}','save',gen_random_uuid());
SELECT set_config('test.actual',public.payroll_run_command('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,NULL,0,'calculate','',gen_random_uuid())::text,true);
SELECT set_config('test.run',current_setting('test.actual')::jsonb->>'id',true);
SELECT set_config('test.candidate',current_setting('test.actual')::jsonb->>'candidate_id',true);
SELECT throws_ok($$SELECT pg_temp.approval()$$,'23514','payroll_approval_blocked','actual unqualified legal candidate cannot be approved');
SELECT public.payroll_run_command('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,1,'cancel','Replace only with rollback fixture',gen_random_uuid());
RESET ROLE;
-- Privileged test-only candidate result. No legal pack is inserted or claimed qualified.
-- This simulates an eventual trusted adapter contract solely to exercise approval/append atomicity inside ROLLBACK.
SELECT set_config('test.run','c4449200-0000-4000-8000-000000000001',true);
SELECT set_config('test.candidate','c4449200-0000-4000-8000-000000000002',true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,'draft','c4440000-0000-4000-8000-000000000001');
SELECT set_config('test.manifest',payroll.run_manifest('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT set_config('test.synthetic_output',payroll.build_review(current_setting('test.manifest')::jsonb)::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"3000"')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,0,net}','"3000"'),'{employees,0,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.manifest')::jsonb,current_setting('test.synthetic_output')::jsonb,'c4440000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id=current_setting('test.candidate')::uuid,revision=1 WHERE tenant_id='c4441000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4440000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT pg_temp.approval()$$,'42501','payroll_forbidden','review-only actor cannot approve');
SELECT set_config('request.jwt.claim.sub','c4440000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.approval(expected=>0)$$,'PT409','payroll_run_stale','approval exact revision CAS');
RESET ROLE;
UPDATE people.compensation_versions SET amount=3100 WHERE tenant_id='c4441000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.approval()$$,'PT409','payroll_source_stale','source changes invalidate approval readiness');
RESET ROLE;
UPDATE people.compensation_versions SET amount=3000 WHERE tenant_id='c4441000-0000-4000-8000-000000000001';
CREATE FUNCTION pg_temp.reject_approval_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='candidate_approve' THEN RAISE EXCEPTION 'qa_approval_audit_failure' USING ERRCODE='P0001';END IF;RETURN NEW;END $$;
CREATE TRIGGER qa_approval_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_approval_audit();
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.approval()$$,'P0001','qa_approval_audit_failure','mandatory approval audit failure rolls back event/state/receipt');
RESET ROLE;
DROP TRIGGER qa_approval_audit_failure ON payroll.audit_events;
SELECT is((SELECT count(*)::int FROM payroll.approval_events WHERE tenant_id='c4441000-0000-4000-8000-000000000001'),0,'failed approval retained no evidence');
SET LOCAL ROLE authenticated;
SELECT set_config('test.approval',pg_temp.approval()::text,true);
SELECT is(pg_temp.approval(),current_setting('test.approval')::jsonb,'exact approval replay recovers committed evidence');
SELECT throws_ok($$SELECT pg_temp.approval(reason=>'Changed retry intent')$$,'PT409','payroll_attempt_conflict','changed approval retry intent rejected');
SELECT throws_ok($$SELECT public.payroll_run_command('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,2,'calculate','',gen_random_uuid())$$,'PT409','payroll_run_stale','approved run needs explicit release before calculation');
RESET ROLE;
UPDATE people.compensation_versions SET amount=3100 WHERE tenant_id='c4441000-0000-4000-8000-000000000001';
SELECT throws_ok($$SELECT payroll.append_final_output('c4441000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4440000-0000-4000-8000-000000000001',2,gen_random_uuid())$$,'23514','payroll_approval_blocked','stale approved manifest cannot append output');
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.approval('release',2,gen_random_uuid(),'Return after source change')->>'status','review','explicit release retains approval evidence and returns review');
RESET ROLE;
UPDATE people.compensation_versions SET amount=3000 WHERE tenant_id='c4441000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.approval('approve',3,gen_random_uuid(),'Synthetic review after restored source');
RESET ROLE;
SELECT throws_ok($$SELECT payroll.finalize_run('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,4,gen_random_uuid())$$,'55000','payroll_release_gate','private finalization entry cannot bypass G6 even for synthetic ready candidate');
CREATE FUNCTION pg_temp.reject_final_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='run_finalized' THEN RAISE EXCEPTION 'qa_final_audit_failure' USING ERRCODE='P0001';END IF;RETURN NEW;END $$;
CREATE TRIGGER qa_final_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_final_audit();
SELECT throws_ok($$SELECT payroll.append_final_output('c4441000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4440000-0000-4000-8000-000000000001',4,'c4449300-0000-4000-8000-000000000001')$$,'P0001','qa_final_audit_failure','mandatory final audit rolls back output/context/consumption/state/receipt');
DROP TRIGGER qa_final_audit_failure ON payroll.audit_events;
SELECT is((SELECT count(*)::int FROM payroll.final_contexts WHERE tenant_id='c4441000-0000-4000-8000-000000000001'),0,'failed private append leaves no immutable output');
SELECT is((SELECT count(*)::int FROM payroll.people_frozen_contexts WHERE tenant_id='c4441000-0000-4000-8000-000000000001'),0,'failed private append leaves no People consumption');
SELECT is((SELECT count(*)::int FROM payroll.input_frozen_versions WHERE tenant_id='c4441000-0000-4000-8000-000000000001'),0,'failed private append leaves no frozen input versions');
SELECT is((SELECT status FROM payroll.runs WHERE tenant_id='c4441000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid),'approved','failed append restores approved state');
SELECT set_config('test.output',payroll.append_final_output('c4441000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4440000-0000-4000-8000-000000000001',4,'c4449300-0000-4000-8000-000000000001')::text,true);
SELECT is(payroll.append_final_output('c4441000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4440000-0000-4000-8000-000000000001',4,'c4449300-0000-4000-8000-000000000001')::text,current_setting('test.output'),'private append result receipt is exact and idempotent');
SELECT is((SELECT count(*)::int FROM payroll.people_frozen_contexts WHERE tenant_id='c4441000-0000-4000-8000-000000000001'),1,'synthetic ledger registers one immutable People context');
SELECT throws_ok($$UPDATE payroll.final_contexts SET engine_version='mutated' WHERE tenant_id='c4441000-0000-4000-8000-000000000001'$$,'55000','payroll_immutable','final context/result immutable');
SELECT throws_ok($$UPDATE payroll.runs SET status='review',revision=revision+1 WHERE tenant_id='c4441000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid$$,'55000','payroll_immutable','locked run cannot reopen through mutable state');
SELECT throws_ok($$UPDATE people.compensation_versions SET amount=3100 WHERE tenant_id='c4441000-0000-4000-8000-000000000001'$$,'23514','payroll_people_correction_required','finalized dated compensation requires correction ownership');
SELECT lives_ok($$UPDATE people.compensation_versions SET valid_until='2030-03-01' WHERE tenant_id='c4441000-0000-4000-8000-000000000001'$$,'prospective compensation closure after protected dates remains allowed');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4441000-0000-4000-8000-000000000001','c4444000-0000-4000-8000-000000000002','NEWFINAL','Synthetic insertion Employee','c4440000-0000-4000-8000-000000000001');
SELECT lives_ok($$INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4441000-0000-4000-8000-000000000001','c4445000-0000-4000-8000-000000000002','c4444000-0000-4000-8000-000000000002','c4443000-0000-4000-8000-000000000001','2030-03-01','monthly')$$,'new future Employment outside finalized period is allowed');
SELECT throws_ok($$INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,end_date,employment_status,pay_basis) VALUES('c4441000-0000-4000-8000-000000000001','c4445000-0000-4000-8000-000000000003','c4444000-0000-4000-8000-000000000002','c4443000-0000-4000-8000-000000000001','2030-01-25','2030-02-24','ended','monthly')$$,'23514','payroll_people_correction_required','new eligible Employment insertion in finalized period is protected');
SET LOCAL ROLE authenticated;
SELECT set_config('test.final_navigation',public.payroll_run_workspace('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT is(current_setting('test.final_navigation')::jsonb->'summary','null'::jsonb,'authorized finalized workspace also defers financial data to audited accessor');
SELECT set_config('test.final_retrieval',public.payroll_final_output('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.output')::uuid)::text,true);
SELECT is(current_setting('test.final_retrieval')::jsonb->'employees'->0->>'net','3000.00','authorized final data returned only by protected accessor');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM payroll.audit_events WHERE tenant_id='c4441000-0000-4000-8000-000000000001' AND action='final_output_access'),1,'authorized final-data retrieval records mandatory access audit');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_final_output('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000003',current_setting('test.output')::uuid)$$,'42501','payroll_forbidden','cross Employer output retrieval denied');
SELECT set_config('request.jwt.claim.sub','c4440000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.payroll_final_output('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.output')::uuid)$$,'42501','payroll_forbidden','review-only permission does not expose final sensitive output');
SELECT set_config('test.review_navigation',public.payroll_run_workspace('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,p_employee=>'c4445000-0000-4000-8000-000000000001')::text,true);
SELECT ok(current_setting('test.review_navigation')::jsonb->'summary'='null'::jsonb AND current_setting('test.review_navigation')::jsonb->'detail'='null'::jsonb AND current_setting('test.review_navigation')::jsonb->'employees'='[]'::jsonb AND current_setting('test.review_navigation')::jsonb->'variance'='null'::jsonb,'review-only finalized workspace cannot bypass money/detail authority with Employee selector');
SELECT ok(NOT(current_setting('test.review_navigation') ~ '"(net|statutory_context|gross|known_gross|lines|dated_rates)"'),'review-only finalized workspace contains no serialized final financial fields');
SELECT is(current_setting('test.review_navigation')::jsonb->'access'->>'can_view_final','false','final navigation exposes permission-compatible handoff');
RESET ROLE;
DELETE FROM platform_core.membership_roles WHERE tenant_id='c4441000-0000-4000-8000-000000000001' AND user_id='c4440000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4440000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.approval()$$,'42501','payroll_forbidden','permission removal is checked before prior approval receipt replay');
RESET ROLE;
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('c4441000-0000-4000-8000-000000000001','c4440000-0000-4000-8000-000000000001','c4442000-0000-4000-8000-000000000001');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='c4441000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4440000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.approval()$$,'55000','payroll_disabled','current entitlement before committed approval replay');
SELECT lives_ok($$SELECT public.payroll_final_output('c4441000-0000-4000-8000-000000000001','c4443000-0000-4000-8000-000000000001',current_setting('test.output')::uuid)$$,'historical final output remains readable with current permission after entitlement loss');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
