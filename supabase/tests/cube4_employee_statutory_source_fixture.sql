-- Shared NONLEGAL rollback fixture extracted from existing source qualification setup, no inherited assertions.

DO $$ BEGIN IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required'; END IF; END $$;

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

-- Actual authenticated save -> manifest -> public calculate -> immutable candidate.
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4421000-0000-4000-8000-000000000001','c4423500-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','Statutory source site',false);
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4421000-0000-4000-8000-000000000001','c4426500-0000-4000-8000-000000000001','c4425000-0000-4000-8000-000000000001','c4423500-0000-4000-8000-000000000001','2030-01-01');
CREATE FUNCTION pg_temp.save(k text,d jsonb,h uuid DEFAULT NULL,r integer DEFAULT 0,op text DEFAULT 'save',ef date DEFAULT '2030-01-25') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_save_input('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',k,CASE WHEN k IN('recurring','manual_units','adjustment','opening_ytd','statutory_context') THEN 'c4425000-0000-4000-8000-000000000001'::uuid END,CASE WHEN k IN('manual_units','adjustment') THEN current_setting('test.period')::uuid END,h,r,ef,CASE WHEN k IN('manual_units','adjustment') THEN '2030-02-25'::date END,d,op,gen_random_uuid()) $$;
GRANT EXECUTE ON FUNCTION pg_temp.save(text,jsonb,uuid,integer,text,date) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Source annotation fixture')->>'period_id'),true);
SELECT pg_temp.save('policy','{"mode":"calendar_days","reason":"Reviewed source test"}');
SELECT set_config('test.component.data','{"key":"source_allowance","name":"Allowance","classification":"earning","calculation":"fixed","base":"","value":"300","taxable":"false","social":"true","visible":"false","active":"true","order":"10","behavior":"recurring","reason":"Reviewed source facts"}',true);
SELECT set_config('test.component',pg_temp.save('component',current_setting('test.component.data')::jsonb)::text,true);
SELECT pg_temp.save('recurring',jsonb_build_object('component_id',current_setting('test.component')::jsonb->>'id','value','300','reason','Reviewed assignment'));
SELECT set_config('test.units',pg_temp.save('manual_units','{"units":"5","source":"manual","basis":"approved_payable_total","reference":"Reviewed units","reason":"Reviewed total"}')::text,true);
SELECT pg_temp.save('manual_units','{"units":"5","source":"manual","basis":"approved_payable_total","reference":"Reviewed units","reason":"Reviewed total"}',(current_setting('test.units')::jsonb->>'id')::uuid,1,'approve');
SELECT set_config('test.bonus',pg_temp.save('component',current_setting('test.component.data')::jsonb||'{"key":"source_bonus","name":"Bonus","behavior":"period_input","taxable":"true","social":"false","visible":"true"}')::text,true);
SELECT set_config('test.adjustment.data',jsonb_build_object('component_id',current_setting('test.bonus')::jsonb->>'id','amount','40','reference','Reviewed bonus','reason','Reviewed single bonus')::text,true);
SELECT set_config('test.adjustment',pg_temp.save('adjustment',current_setting('test.adjustment.data')::jsonb)::text,true);
SELECT pg_temp.save('adjustment',current_setting('test.adjustment.data')::jsonb,(current_setting('test.adjustment')::jsonb->>'id')::uuid,1,'approve');
SELECT set_config('test.run',public.payroll_run_command('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,NULL,0,'calculate','',gen_random_uuid())::text,true);
RESET ROLE;
CREATE FUNCTION pg_temp.employee() RETURNS jsonb LANGUAGE sql AS $$ SELECT output->'employees'->0 FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid $$;
CREATE FUNCTION pg_temp.sources() RETURNS jsonb LANGUAGE sql AS $$ SELECT pg_temp.employee()->'statutory_sources' $$;
CREATE FUNCTION pg_temp.recalculate() RETURNS jsonb LANGUAGE sql AS $$ SELECT public.payroll_run_command('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'revision')::integer,'calculate','',gen_random_uuid()) $$;
GRANT EXECUTE ON FUNCTION pg_temp.recalculate() TO authenticated;
