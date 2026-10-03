BEGIN;
DO $$ BEGIN IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required'; END IF; END $$;
SELECT no_plan();
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4430000-0000-4000-8000-000000000001','cube4-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4430000-0000-4000-8000-000000000002','cube4-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4431000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4430000-0000-4000-8000-000000000001'),
 ('c4431000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4430000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4431000-0000-4000-8000-000000000001','c4432000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review']),
 ('c4431000-0000-4000-8000-000000000001','c4432000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4431000-0000-4000-8000-000000000001','c4430000-0000-4000-8000-000000000001','c4430000-0000-4000-8000-000000000001'),
 ('c4431000-0000-4000-8000-000000000001','c4430000-0000-4000-8000-000000000002','c4430000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4431000-0000-4000-8000-000000000001','c4430000-0000-4000-8000-000000000001','c4432000-0000-4000-8000-000000000001'),
 ('c4431000-0000-4000-8000-000000000001','c4430000-0000-4000-8000-000000000002','c4432000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4431000-0000-4000-8000-000000000002','c4433000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4431000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4430000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4431000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4430000-0000-4000-8000-000000000001','Cube4 QA only');
-- Pure deterministic dated fixtures are not statutory packs or financial locks.
CREATE FUNCTION pg_temp.review_fixture(mode text DEFAULT 'calendar_days',basis text DEFAULT 'monthly',join_on date DEFAULT '2030-01-25',transition boolean DEFAULT false) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('engine','cube4-review-v1','period',jsonb_build_object('id','c4438000-0000-4000-8000-000000000001','starts_on','2030-01-25','ends_on','2030-02-24','is_transition',transition),
 'employees',jsonb_build_array(jsonb_build_object('name','Fixture Employee','code','CALCQA','employment',jsonb_build_object('id','c4435000-0000-4000-8000-000000000001','employee_id','c4434000-0000-4000-8000-000000000001','pay_basis',basis,'start_date',join_on,'end_date',NULL))),
 'compensation',jsonb_build_array(jsonb_build_object('id','c4436000-0000-4000-8000-000000000001','employment_id','c4435000-0000-4000-8000-000000000001','valid_from','2030-01-01','valid_until',NULL,'amount',CASE WHEN basis='daily' THEN 100 ELSE 3000 END)),
 'assignments',jsonb_build_array(jsonb_build_object('employment_id','c4435000-0000-4000-8000-000000000001','valid_from','2030-01-01','valid_until',NULL)),
 'inputs',jsonb_build_array(jsonb_build_object('head',jsonb_build_object('id','c4437000-0000-4000-8000-000000000001','kind','policy'),'version',jsonb_build_object('revision',1,'effective_from','2030-01-01','effective_until',NULL,'status','draft','data',jsonb_build_object('mode',mode)))) || CASE WHEN basis='daily' THEN jsonb_build_array(jsonb_build_object('head',jsonb_build_object('id','c4437000-0000-4000-8000-000000000005','kind','manual_units','employment_id','c4435000-0000-4000-8000-000000000001','period_id','c4438000-0000-4000-8000-000000000001'),'version',jsonb_build_object('revision',1,'effective_from','2030-01-25','effective_until','2030-02-25','status','approved','data','{"units":"5"}'::jsonb))) ELSE '[]'::jsonb END,
 'packs','[]'::jsonb,'optional','{"time":false,"leave":false,"finance":"adjustments_only"}'::jsonb,'corrections','[]'::jsonb)
$$;
CREATE FUNCTION pg_temp.with_component(manifest jsonb,value numeric DEFAULT 300,method text DEFAULT 'fixed',proration text DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
 SELECT manifest||jsonb_build_object('inputs',manifest->'inputs'||jsonb_build_array(
 jsonb_build_object('head',jsonb_build_object('id','c4437000-0000-4000-8000-000000000002','kind','component'),'version',jsonb_build_object('id','c4437100-0000-4000-8000-000000000002','revision',1,'effective_from','2030-01-01','effective_until',NULL,'status','draft','data',jsonb_strip_nulls(jsonb_build_object('active','true','name','Fixture component','classification','earning','calculation',method,'base',CASE WHEN method='percentage' THEN 'base_pay' ELSE '' END,'behavior','recurring','proration',proration)))),
 jsonb_build_object('head',jsonb_build_object('id','c4437000-0000-4000-8000-000000000003','kind','recurring','employment_id','c4435000-0000-4000-8000-000000000001'),'version',jsonb_build_object('revision',1,'effective_from','2030-01-01','effective_until',NULL,'status','draft','data',jsonb_build_object('component_id','c4437000-0000-4000-8000-000000000002','value',value)))))
$$;
SELECT is((payroll.build_review(pg_temp.review_fixture())->'employees'->0->>'base')::numeric,3000::numeric,'full ordinary 25-24 cycle pays full monthly salary across 31 days');
SELECT is((payroll.build_review(pg_temp.review_fixture('fixed_30_day'))->'employees'->0->>'base')::numeric,3000::numeric,'fixed30 full ordinary cycle never pays 31/30 salary');
SELECT is((payroll.build_review(pg_temp.review_fixture(join_on=>'2030-02-15'))->'employees'->0->>'base')::numeric,967.74::numeric,'actual-days ordinary join portion uses ten of 31 period days');
SELECT is((payroll.build_review(pg_temp.review_fixture('fixed_30_day',join_on=>'2030-02-15'))->'employees'->0->>'base')::numeric,1000::numeric,'fixed30 ordinary partial salary uses eligible days divided by30');
SELECT is((payroll.build_review(pg_temp.review_fixture('fixed_30_day',join_on=>'2030-01-26'))->'employees'->0->>'base')::numeric,3000::numeric,'partial fixed30 reaches full-salary cap at30 days');
SELECT is((payroll.build_review(pg_temp.review_fixture(transition=>true))->'employees'->0->>'base')::numeric,3248.85::numeric,'transition uses each calendar-month denominator and rounds sum once');
SELECT is((payroll.build_review(pg_temp.review_fixture('fixed_30_day',transition=>true))->'employees'->0->>'base')::numeric,3100::numeric,'transition fixed30 retains explicit per-date treatment');
SELECT set_config('test.changed_rates','[{"id":"c4436000-0000-4000-8000-000000000001","employment_id":"c4435000-0000-4000-8000-000000000001","valid_from":"2030-01-01","valid_until":"2030-02-10","amount":3000},{"id":"c4436000-0000-4000-8000-000000000002","employment_id":"c4435000-0000-4000-8000-000000000001","valid_from":"2030-02-10","valid_until":null,"amount":6000}]',true);
SELECT is((payroll.build_review(pg_temp.review_fixture('fixed_30_day')||jsonb_build_object('compensation',current_setting('test.changed_rates')::jsonb))->'employees'->0->>'base')::numeric,4451.61::numeric,'full fixed30 salary change weights sixteen and fifteen actual effective days');
SELECT is((payroll.build_review(pg_temp.review_fixture('fixed_30_day',join_on=>'2030-01-30')||jsonb_build_object('compensation',current_setting('test.changed_rates')::jsonb))->'employees'->0->>'base')::numeric,4100::numeric,'partial salary changes use eligible-date weighted salary and fixed30 cap');
SELECT is((payroll.build_review(pg_temp.review_fixture(basis=>'daily'))->'employees'->0->>'base')::numeric,500::numeric,'approved aggregate daily units with unchanged rate');
SELECT is((payroll.build_review(pg_temp.with_component(pg_temp.review_fixture(join_on=>'2030-02-15')))->'employees'->0->>'gross')::numeric,1064.51::numeric,'legacy fixed recurring defaults to accepted salary proration');
SELECT is((payroll.build_review(pg_temp.with_component(pg_temp.review_fixture(join_on=>'2030-02-15'),proration=>'paid_full_period'))->'employees'->0->>'gross')::numeric,1267.74::numeric,'bounded paid-full-period override is not join-prorated');
SELECT is((payroll.build_review(pg_temp.with_component(pg_temp.review_fixture(basis=>'daily',join_on=>'2030-02-15')))->'employees'->0->>'gross')::numeric,596.77::numeric,'fixed recurring is a monthly value even for daily-base Employee');
SELECT is((payroll.build_review(pg_temp.with_component(pg_temp.review_fixture(join_on=>'2030-02-15'),10,'percentage'))->'employees'->0->>'gross')::numeric,1064.51::numeric,'percentage uses unrounded earned base and component once rounding');
SELECT is((payroll.build_review(pg_temp.with_component(pg_temp.review_fixture(),0.01))->'employees'->0->>'gross')::numeric,3000.01::numeric,'tiny fixed component sums dated fractions then rounds once');
SELECT is(payroll.build_review(pg_temp.review_fixture())->>'net',NULL::text,'legal unqualification never fabricates net zero');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(pg_temp.review_fixture())->'issues')i WHERE i->>'code'='statutory_pack_unqualified'),'owned statutory blocker always visible without verified pack');
SELECT set_config('test.daily_changed',jsonb_set(current_setting('test.changed_rates')::jsonb,'{0,amount}','100'::jsonb)::text,true);
SELECT set_config('test.daily_changed',jsonb_set(current_setting('test.daily_changed')::jsonb,'{1,amount}','200'::jsonb)::text,true);
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(pg_temp.review_fixture(basis=>'daily')||jsonb_build_object('compensation',current_setting('test.daily_changed')::jsonb))->'issues')i WHERE i->>'code'='daily_units_allocation_needed'),'daily rate change blocks unknown aggregate-unit allocation');
SELECT is(payroll.build_review(pg_temp.review_fixture(basis=>'daily')||jsonb_build_object('compensation',current_setting('test.daily_changed')::jsonb))->'employees'->0->>'base',NULL::text,'daily allocation blocker exposes no guessed salary');
SELECT is(payroll.build_review(pg_temp.review_fixture()||'{"assignments":[]}'::jsonb)->'employees'->0->>'gross',NULL::text,'assignment coverage gap makes aggregate incomplete');
SELECT is((payroll.build_review(pg_temp.review_fixture()||'{"assignments":[]}'::jsonb)->'employees'->0->>'known_gross')::numeric,3000::numeric,'actual defined dated compensation remains visible with a work-context blocker');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(pg_temp.review_fixture()||'{"optional":{"time":true,"leave":false}}'::jsonb)->'issues')i WHERE i->>'code'='time_integration_pending'),'enabled optional source is not silently ignored');
-- A cancelled head's higher revision must not override a newly approved replacement head.
SELECT set_config('test.replacement_units',pg_temp.review_fixture(basis=>'daily')::text,true);
SELECT set_config('test.replacement_units',jsonb_set(current_setting('test.replacement_units')::jsonb,'{inputs}',current_setting('test.replacement_units')::jsonb->'inputs'||
 jsonb_set(jsonb_set(current_setting('test.replacement_units')::jsonb->'inputs'->1,'{version,revision}','3'::jsonb),'{version,status}','"cancelled"'::jsonb)||
 jsonb_set(jsonb_set(current_setting('test.replacement_units')::jsonb->'inputs'->1,'{head,id}','"c4437000-0000-4000-8000-000000000006"'::jsonb),'{version,revision}','2'::jsonb))::text,true);
SELECT is((payroll.build_review(current_setting('test.replacement_units')::jsonb)->'employees'->0->>'base')::numeric,500::numeric,'cancel prior revision3 then approved replacement revision2 calculates daily pay');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(current_setting('test.replacement_units')::jsonb)->'issues')i WHERE i->>'code' IN('approved_units_missing','manual_units_ambiguous')),'cancelled head does not resurrect earlier approval or cause replacement ambiguity');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(pg_temp.review_fixture(basis=>'daily')||jsonb_build_object('inputs',pg_temp.review_fixture(basis=>'daily')->'inputs'||jsonb_set(pg_temp.review_fixture(basis=>'daily')->'inputs'->1,'{head,id}','"c4437000-0000-4000-8000-000000000006"'::jsonb)))->'issues')i WHERE i->>'code'='manual_units_ambiguous'),'two live approved heads are blocked without arbitrary revision selection');
-- Human detail is grouped without leaking exact raw arithmetic to the browser.
SELECT is(jsonb_array_length(payroll.review_employee_detail(payroll.build_review(pg_temp.review_fixture())->'employees'->0)->'lines'->0->'segments'),1,'unchanged monthly salary has one contiguous human segment');
SELECT is(payroll.review_employee_detail(payroll.build_review(pg_temp.review_fixture())->'employees'->0)->'lines'->0->'segments'->0->>'days','31','human explanation retains actual inclusive day count');
SELECT ok(NOT(payroll.review_employee_detail(payroll.build_review(pg_temp.review_fixture())->'employees'->0)->'lines'->0 ? 'details'),'exact daily raw details stay private');
SELECT is(jsonb_array_length(payroll.review_employee_detail(payroll.build_review(pg_temp.review_fixture()||jsonb_build_object('compensation',current_setting('test.changed_rates')::jsonb))->'employees'->0)->'lines'->0->'segments'),2,'effective salary change has two dated human segments');
SELECT set_config('test.mixed_component',pg_temp.with_component(pg_temp.review_fixture())::text,true);
SELECT set_config('test.mixed_component',jsonb_set(current_setting('test.mixed_component')::jsonb,'{inputs}',current_setting('test.mixed_component')::jsonb->'inputs'||jsonb_set(jsonb_set(current_setting('test.mixed_component')::jsonb->'inputs'->1,'{version,effective_from}','"2030-02-10"'::jsonb),'{version,data,classification}','"deduction"'::jsonb))::text,true);
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(current_setting('test.mixed_component')::jsonb)->'issues')i WHERE i->>'code'='component_behavior_changed'),'mixed in-period component classification is an owned blocker');
SELECT is((payroll.build_review(current_setting('test.mixed_component')::jsonb)->'employees'->0->>'known_gross')::numeric,3000::numeric,'ambiguous component is excluded without discarding defined base');
-- Authoritative run lifecycle with scoped actors, replay/CAS, stale source and cancellation.
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4431000-0000-4000-8000-000000000001','c4433500-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4431000-0000-4000-8000-000000000001','c4434000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','c4430000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4431000-0000-4000-8000-000000000001','c4435000-0000-4000-8000-000000000001','c4434000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4431000-0000-4000-8000-000000000001','c4436000-0000-4000-8000-000000000001','c4435000-0000-4000-8000-000000000001',3000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4431000-0000-4000-8000-000000000001','c4436500-0000-4000-8000-000000000001','c4435000-0000-4000-8000-000000000001','c4433500-0000-4000-8000-000000000001','2030-01-01');
SELECT ok(NOT has_table_privilege('authenticated','payroll.candidates','SELECT'),'candidate direct table read revoked');
SELECT ok(NOT has_function_privilege('authenticated','payroll.build_review(jsonb)','EXECUTE'),'private calculation engine cannot bypass supported command');
CREATE FUNCTION pg_temp.run_command(run uuid DEFAULT NULL,expected integer DEFAULT 0,operation text DEFAULT 'calculate',reason text DEFAULT '',attempt uuid DEFAULT 'c4439000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$ SELECT public.payroll_run_command('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,run,expected,operation,reason,attempt) $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4430000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Reviewed candidate calendar')->>'period_id'),true);
SELECT lives_ok($$SELECT public.payroll_save_input('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"mode":"calendar_days","reason":"Reviewed proration"}','save',gen_random_uuid())$$,'candidate policy configured');
SELECT set_config('test.run',pg_temp.run_command()::text,true);
SELECT is(pg_temp.run_command(),current_setting('test.run')::jsonb,'same-intent candidate receipt replay returns one outcome');
SELECT throws_ok($$SELECT pg_temp.run_command(reason=>'Changed intent')$$,'PT409','payroll_attempt_conflict','same-attempt changed intent rejected');
SELECT throws_ok($$SELECT pg_temp.run_command(attempt=>gen_random_uuid())$$,'PT409','payroll_run_stale','second active run prevented');
SELECT is(public.payroll_run_workspace('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->'stale_reasons','[]'::jsonb,'new candidate is current');
SELECT set_config('test.next_quote',(public.payroll_workspace('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001')->'next_preview')::text,true);
SELECT lives_ok($$SELECT public.payroll_generate_next_period('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001',1,gen_random_uuid(),current_setting('test.next_quote')::jsonb)$$,'next unchanged-calendar period may generate while current run is open');
SELECT throws_ok($$SELECT public.payroll_save_calendar('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','2030-03-25',25,25,'ending','Africa/Cairo',2,gen_random_uuid(),public.payroll_calendar_preview('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001','2030-03-25',25,25,'ending','Africa/Cairo'),'Changed calendar')$$,'55000','payroll_open_run','calendar change requires current open run closure');
SELECT set_config('request.jwt.claim.sub','c4430000-0000-4000-8000-000000000002',true);
SELECT lives_ok($$SELECT public.payroll_run_employers('c4431000-0000-4000-8000-000000000001')$$,'review-only actor has narrow UI discovery without prepare/view permissions');
SELECT lives_ok($$SELECT public.payroll_run_workspace('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)$$,'review-only actor can see candidate summary');
SELECT throws_ok($$SELECT pg_temp.run_command(attempt=>gen_random_uuid())$$,'42501','payroll_forbidden','review-only actor cannot calculate');
RESET ROLE;
UPDATE people.compensation_versions SET amount=3100 WHERE tenant_id='c4431000-0000-4000-8000-000000000001' AND id='c4436000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4430000-0000-4000-8000-000000000001',true);
SELECT ok(public.payroll_run_workspace('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->'stale_reasons' ? 'compensation_changed','source change yields specific recalculation reason');
SELECT set_config('test.recalculated',pg_temp.run_command((current_setting('test.run')::jsonb->>'id')::uuid,1,attempt=>gen_random_uuid())::text,true);
SELECT is(public.payroll_run_workspace('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->'stale_reasons','[]'::jsonb,'recalculation resolves source staleness');
SELECT throws_ok($$SELECT pg_temp.run_command((current_setting('test.run')::jsonb->>'id')::uuid,1,attempt=>gen_random_uuid())$$,'PT409','payroll_run_stale','lost stale revision cannot overwrite newer candidate');
SELECT set_config('test.cancelled',pg_temp.run_command((current_setting('test.run')::jsonb->>'id')::uuid,2,'cancel','Reviewed synthetic cancellation',gen_random_uuid())::text,true);
SELECT is(current_setting('test.cancelled')::jsonb->>'status','cancelled','cancellation is explicit terminal state');
SELECT set_config('test.new_run',pg_temp.run_command(attempt=>gen_random_uuid())::text,true);
SELECT isnt(current_setting('test.new_run')::jsonb->>'id',current_setting('test.cancelled')::jsonb->>'id','cancel followed by calculation creates a new run identity');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM payroll.runs WHERE tenant_id='c4431000-0000-4000-8000-000000000001' AND status='review'),1,'one active run chain after cancelled history');
SELECT is((SELECT count(*)::int FROM payroll.candidates WHERE tenant_id='c4431000-0000-4000-8000-000000000001'),3,'three immutable candidates retain recalculation/cancellation history');
SELECT is((SELECT count(*)::int FROM payroll.people_frozen_contexts WHERE tenant_id='c4431000-0000-4000-8000-000000000001'),0,'calculation never registers final financial consumption');
SELECT is((SELECT count(*)::int FROM payroll.input_frozen_versions WHERE tenant_id='c4431000-0000-4000-8000-000000000001'),0,'calculation never freezes input money');
SELECT throws_ok($$UPDATE payroll.candidates SET engine_version='tampered' WHERE tenant_id='c4431000-0000-4000-8000-000000000001'$$,'55000','payroll_immutable','candidate context and lines immutable');
CREATE FUNCTION pg_temp.reject_run_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action LIKE 'run_%' THEN RAISE EXCEPTION 'qa_run_audit_failure' USING ERRCODE='P0001';END IF;RETURN NEW; END $$;
CREATE TRIGGER qa_run_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_run_audit();
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.run_command((current_setting('test.new_run')::jsonb->>'id')::uuid,1,attempt=>gen_random_uuid())$$,'P0001','qa_run_audit_failure','candidate mandatory audit failure rolls back');
RESET ROLE;
DROP TRIGGER qa_run_audit_failure ON payroll.audit_events;
SELECT is((SELECT count(*)::int FROM payroll.candidates WHERE tenant_id='c4431000-0000-4000-8000-000000000001'),3,'audit failure adds no candidate');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='c4431000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.run_command()$$,'55000','payroll_disabled','current entitlement rechecked before candidate receipt replay');
SELECT lives_ok($$SELECT public.payroll_run_workspace('c4431000-0000-4000-8000-000000000001','c4433000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)$$,'bounded candidate history remains readable after entitlement loss');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
