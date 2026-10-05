BEGIN;
DO $$ BEGIN IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required'; END IF; END $$;
SELECT no_plan();
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4420000-0000-4000-8000-000000000001','cube4-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4420000-0000-4000-8000-000000000002','cube4-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4421000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4420000-0000-4000-8000-000000000001'),
 ('c4421000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4420000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4421000-0000-4000-8000-000000000001','c4422000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.approve','payroll.correct','employee_finance.view','employee_finance.manage','employee_finance.approve']),
 ('c4421000-0000-4000-8000-000000000001','c4422000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4421000-0000-4000-8000-000000000001','c4420000-0000-4000-8000-000000000001','c4420000-0000-4000-8000-000000000001'),
 ('c4421000-0000-4000-8000-000000000001','c4420000-0000-4000-8000-000000000002','c4420000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4421000-0000-4000-8000-000000000001','c4420000-0000-4000-8000-000000000001','c4422000-0000-4000-8000-000000000001'),
 ('c4421000-0000-4000-8000-000000000001','c4420000-0000-4000-8000-000000000002','c4422000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4421000-0000-4000-8000-000000000002','c4423000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4421000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4420000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4421000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4420000-0000-4000-8000-000000000001','Cube4 QA only');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4421000-0000-4000-8000-000000000001','c4424000-0000-4000-8000-000000000001','INPUTQA','Synthetic Daily Employee','c4420000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4421000-0000-4000-8000-000000000001','c4425000-0000-4000-8000-000000000001','c4424000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-01','daily');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4421000-0000-4000-8000-000000000001','c4426000-0000-4000-8000-000000000001','c4425000-0000-4000-8000-000000000001',100,'2030-01-01');
SELECT ok(NOT has_table_privilege('authenticated','payroll.input_versions','SELECT'),'input records private');
SELECT ok(NOT has_function_privilege('authenticated','payroll.register_people_context(uuid,uuid,uuid,uuid,uuid,jsonb)','EXECUTE'),'private financial context registration inaccessible');
SELECT ok(NOT has_function_privilege('anon','public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)','EXECUTE'),'anonymous denied');
CREATE FUNCTION pg_temp.input_command(kind text,data jsonb,employment uuid DEFAULT NULL,period uuid DEFAULT NULL,head uuid DEFAULT NULL,expected integer DEFAULT 0,effective date DEFAULT '2030-01-25',until_date date DEFAULT NULL,operation text DEFAULT 'save',attempt uuid DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$ SELECT public.payroll_save_input('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',kind,employment,period,head,expected,effective,until_date,data,operation,COALESCE(attempt,gen_random_uuid())) $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Reviewed synthetic calendar')->>'period_id'),true);
SELECT set_config('test.component','{"key":"allowance","name":"بدل ثابت","classification":"earning","calculation":"fixed","base":"","value":"50","taxable":"false","social":"false","visible":"true","active":"true","order":"10","behavior":"recurring","reason":"Synthetic reviewed allowance"}',true);
SELECT set_config('test.saved',(pg_temp.input_command('component',current_setting('test.component')::jsonb,attempt=>'c4429000-0000-4000-8000-000000000001'))::text,true);
SELECT is(pg_temp.input_command('component',current_setting('test.component')::jsonb,attempt=>'c4429000-0000-4000-8000-000000000001'),current_setting('test.saved')::jsonb,'canonical same-intent replay');
SELECT throws_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"value":"51"}',attempt=>'c4429000-0000-4000-8000-000000000001')$$,'PT409','payroll_attempt_conflict','changed intent refused');
SELECT throws_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"expression":"salary*2"}')$$,'22023','payroll_invalid','arbitrary expression rejected');
SELECT throws_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"calculation":"percentage","base":"gross","key":"bad"}')$$,'22023','payroll_invalid','unsupported percentage base rejected');
SELECT set_config('test.component_id',current_setting('test.saved')::jsonb->>'id',true);
SELECT lives_ok($$SELECT pg_temp.input_command('policy','{"mode":"calendar_days","reason":"Reviewed policy"}')$$,'default actual-day policy recorded');
SELECT throws_ok($$SELECT public.payroll_save_input('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000003','policy',NULL,NULL,NULL,0,'2030-01-25',NULL,'{"mode":"fixed_30_day","reason":"Duplicate policy"}','save',gen_random_uuid())$$,'23505',NULL,'policy unique once per Tenant across Employers');
SELECT lives_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.component_id'),'value','50','reason','Reviewed recurring'),'c4425000-0000-4000-8000-000000000001')$$,'effective recurring assignment');
SELECT lives_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"value":"60"}',head=>current_setting('test.component_id')::uuid,expected=>1,effective=>'2030-03-01')$$,'future component version saved');
SELECT throws_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.component_id'),'value','50','reason','Duplicate recurring'),'c4425000-0000-4000-8000-000000000001')$$,'23505','payroll_duplicate_input','future component does not erase old applicable version; duplicate assignment still identified');
SELECT throws_ok($$SELECT pg_temp.input_command('manual_units','{"units":"32","reference":"Reviewed work","reason":"Synthetic units"}','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,until_date=>'2030-02-25')$$,'22023','payroll_units_capacity','units cannot exceed actual eligible period days');
SELECT set_config('test.units',(pg_temp.input_command('manual_units','{"units":"20.5","reference":"Reviewed work","reason":"Synthetic units"}','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,until_date=>'2030-02-25'))::text,true);
SELECT is(current_setting('test.units')::jsonb->>'status','draft','manual units require approval');
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT pg_temp.input_command('manual_units','{"units":"20.5","reference":"Reviewed work","reason":"Synthetic units"}','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.units')::jsonb->>'id')::uuid,1,until_date=>'2030-02-25',operation=>'approve')$$,'42501','payroll_forbidden','reader cannot approve');
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000001',true);
SELECT is(pg_temp.input_command('manual_units','{"units":"20.5","reference":"Reviewed work","reason":"Synthetic units"}','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.units')::jsonb->>'id')::uuid,1,until_date=>'2030-02-25',operation=>'approve')->>'status','approved','approved manual daily units without Attendance dependency');
SELECT throws_ok($$SELECT pg_temp.input_command('opening_ytd','{"year":"2030","reference":"opening ref","reason":"Opening test","taxable_earnings":"0"}','c4425000-0000-4000-8000-000000000001')$$,'22023','payroll_invalid','unknown required YTD fields are not zero');
SELECT lives_ok($$SELECT pg_temp.input_command('opening_ytd','{"year":"2030","reference":"reviewed opening ref","reason":"Opening test","taxable_earnings":"0","tax_withheld":"0","social_base":"0","employee_social":"0","employer_social":"0"}','c4425000-0000-4000-8000-000000000001')$$,'complete attributable YTD accepted');

SELECT set_config('test.bonus',(pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"key":"bonus","name":"مكافأة","behavior":"period_input"}'))::text,true);
SELECT set_config('test.adjustment_data',jsonb_build_object('component_id',current_setting('test.bonus')::jsonb->>'id','amount','100','reference','Reviewed reward','reason','Synthetic bonus')::text,true);
SELECT set_config('test.adjustment',(pg_temp.input_command('adjustment',current_setting('test.adjustment_data')::jsonb,'c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,until_date=>'2030-02-25'))::text,true);
SELECT is(pg_temp.input_command('adjustment',current_setting('test.adjustment_data')::jsonb,'c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.adjustment')::jsonb->>'id')::uuid,1,until_date=>'2030-02-25',operation=>'approve')->>'status','approved','finance approval creates approved version only');
SELECT throws_ok($$SELECT pg_temp.input_command('adjustment',current_setting('test.adjustment_data')::jsonb,'c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.adjustment')::jsonb->>'id')::uuid,2,until_date=>'2030-02-25',operation=>'save')$$,'PT409','payroll_stale','approved adjustment cannot be silently edited');
SELECT is(pg_temp.input_command('adjustment',current_setting('test.adjustment_data')::jsonb,'c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.adjustment')::jsonb->>'id')::uuid,2,until_date=>'2030-02-25',operation=>'cancel')->>'status','cancelled','approved adjustment can be cancelled before application');
SELECT throws_ok($$SELECT pg_temp.input_command('adjustment',current_setting('test.adjustment_data')::jsonb,'c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.adjustment')::jsonb->>'id')::uuid,3,until_date=>'2030-02-25',operation=>'approve')$$,'PT409','payroll_stale','cancelled adjustment terminal');

SELECT is(public.payroll_input_workspace('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->>'legal_pack','unqualified','no legal pack qualification invented');
SELECT ok(NOT ((public.payroll_input_workspace('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->'employees'->0)?'amount'),'People projection does not expose salary amount');

-- Review-cycle delta: historical recurring segments, expired component renewal and Finance-only input closure.
RESET ROLE;
SELECT set_config('test.recurring_head',(SELECT h.id::text FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id='c4421000-0000-4000-8000-000000000001' AND h.kind='recurring' AND v.data->>'component_id'=current_setting('test.component_id')),true);
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES('c4420000-0000-4000-8000-000000000003','cube4-finance-only@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES('c4421000-0000-4000-8000-000000000001','c4422000-0000-4000-8000-000000000003','qa.finance.author',1,ARRAY['employee_finance.view','employee_finance.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES('c4421000-0000-4000-8000-000000000001','c4420000-0000-4000-8000-000000000003','c4420000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('c4421000-0000-4000-8000-000000000001','c4420000-0000-4000-8000-000000000003','c4422000-0000-4000-8000-000000000003');
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.component_id'),'value','60','reason','March recurring version'),'c4425000-0000-4000-8000-000000000001',head=>current_setting('test.recurring_head')::uuid,expected=>1,effective=>'2030-03-01')$$,'future recurring revision supersedes prospectively');
SELECT throws_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.component_id'),'value','55','reason','Historical duplicate attempt'),'c4425000-0000-4000-8000-000000000001',effective=>'2030-01-25',until_date=>'2030-02-25')$$,'23505','payroll_duplicate_input','historical recurring segment remains protected after future revision');
SELECT throws_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.component_id'),'value','65','reason','Future duplicate attempt'),'c4425000-0000-4000-8000-000000000001',effective=>'2030-03-01',until_date=>'2030-04-01')$$,'23505','payroll_duplicate_input','future recurring segment cannot duplicate another head');
SELECT set_config('test.renewal',(pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"key":"renewable","name":"بدل محدد المدة"}',until_date=>'2030-02-25'))::text,true);
SELECT lives_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.renewal')::jsonb->>'id','value','5','reason','Finite recurring assignment'),'c4425000-0000-4000-8000-000000000001',until_date=>'2030-02-25')$$,'finite recurring interval recorded');
SELECT lives_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"key":"renewable","name":"بدل محدد المدة"}',head=>(current_setting('test.renewal')::jsonb->>'id')::uuid,expected=>1,effective=>'2030-03-01')$$,'same stable component renews after old expiry');
SELECT lives_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.renewal')::jsonb->>'id','value','6','reason','Renewed recurring assignment'),'c4425000-0000-4000-8000-000000000001',effective=>'2030-03-01',until_date=>'2030-04-01')$$,'finite old recurring interval permits nonoverlapping renewal');
SELECT lives_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"key":"renewable","name":"بدل محدد المدة","active":"false"}',head=>(current_setting('test.renewal')::jsonb->>'id')::uuid,expected=>2,effective=>'2030-04-01')$$,'component deactivation is a prospective version');
SELECT throws_ok($$SELECT pg_temp.input_command('recurring',jsonb_build_object('component_id',current_setting('test.renewal')::jsonb->>'id','value','7','reason','Inactive component attempt'),'c4425000-0000-4000-8000-000000000001',effective=>'2030-04-01')$$,'22023','payroll_component_unavailable','inactive latest applicable version cannot resurrect earlier component');
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000003',true);
SELECT set_config('test.finance_workspace',public.payroll_input_workspace('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.finance_workspace')::jsonb->'component_choices') c WHERE c->>'id'=current_setting('test.bonus')::jsonb->>'id'),'Finance-only author can discover eligible fixed adjustment component');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.finance_workspace')::jsonb->'component_choices') c WHERE c?'value' OR c?'amount' OR c?'taxable' OR c?'social'),'Finance component choices exclude values and treatment details');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.finance_workspace')::jsonb->'records') r WHERE r->>'kind'='component'),'Finance actor still cannot read whole Payroll catalog');
SELECT is(pg_temp.input_command('adjustment',current_setting('test.adjustment_data')::jsonb||'{"amount":"150","reason":"Finance-only reward"}','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,until_date=>'2030-02-25')->>'status','draft','Finance-only author creates attributable draft adjustment');
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000001',true);

RESET ROLE;
-- Private synthetic freeze fixture only; no public financial lock is exercised.
INSERT INTO payroll.people_frozen_contexts(tenant_id,employer_id,employment_id,period_id,run_id,source_snapshot) VALUES('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'c4428000-0000-4000-8000-000000000001','{}');
INSERT INTO payroll.input_frozen_versions(tenant_id,run_id,version_id) SELECT tenant_id,'c4428000-0000-4000-8000-000000000001',id FROM payroll.input_versions WHERE head_id=current_setting('test.component_id')::uuid AND revision=1;
SELECT lives_ok($$UPDATE people.compensation_versions SET valid_until='2030-03-01' WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND id='c4426000-0000-4000-8000-000000000001'$$,'prospective compensation closure after protected dates allowed');
SELECT throws_ok($$UPDATE people.compensation_versions SET amount=101 WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND id='c4426000-0000-4000-8000-000000000001'$$,'23514','payroll_people_correction_required','historical salary mutation refused atomically');
SELECT throws_ok($$UPDATE people.employments SET end_date='2030-02-01',employment_status='ended' WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND id='c4425000-0000-4000-8000-000000000001'$$,'23514','payroll_people_correction_required','historical employment end refused');
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"value":"70"}',head=>current_setting('test.component_id')::uuid,expected=>2,effective=>'2030-04-01')$$,'consumed old component allows prospective configuration');
SELECT throws_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"value":"71"}',head=>current_setting('test.component_id')::uuid,expected=>3,effective=>'2030-02-01')$$,'PT409','payroll_effective_conflict','retroactive component version refused');
SELECT lives_ok($$SELECT public.payroll_request_correction('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'Reviewed People correction',gen_random_uuid())$$,'explicit attributable correction requirement route');
RESET ROLE;
SELECT is((SELECT amount::text FROM people.compensation_versions WHERE id='c4426000-0000-4000-8000-000000000001'),'100.00','protected money source unchanged');
SELECT throws_ok($$UPDATE payroll.input_versions SET status='applied' WHERE tenant_id='c4421000-0000-4000-8000-000000000001'$$,'55000','payroll_immutable','public input history never rewritten to applied');
SELECT is((SELECT count(*)::int FROM payroll.correction_requirements WHERE tenant_id='c4421000-0000-4000-8000-000000000001'),1,'one explicit correction requirement');

CREATE FUNCTION pg_temp.reject_input_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'qa_input_audit_failure' USING ERRCODE='P0001'; END $$;
CREATE TRIGGER qa_input_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_input_audit();
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb||'{"value":"80"}',head=>current_setting('test.component_id')::uuid,expected=>3,effective=>'2030-05-01')$$,'P0001','qa_input_audit_failure','mandatory audit failure rolls back new revision');
RESET ROLE;
DROP TRIGGER qa_input_audit_failure ON payroll.audit_events;
SELECT is((SELECT revision FROM payroll.input_heads WHERE id=current_setting('test.component_id')::uuid),3,'audit failure preserves head revision');
SELECT is((SELECT count(*)::int FROM payroll.input_versions WHERE head_id=current_setting('test.component_id')::uuid),3,'audit failure adds no input version');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.input_command('component',current_setting('test.component')::jsonb,attempt=>'c4429000-0000-4000-8000-000000000001')$$,'55000','payroll_disabled','entitlement checked before saved receipt replay');
SELECT lives_ok($$SELECT public.payroll_input_workspace('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)$$,'bounded historical input read after entitlement loss');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
