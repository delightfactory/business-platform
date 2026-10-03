-- Shared NONLEGAL setup extracted without inherited assertions. Dedicated rollback only.
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required';END IF;END $$;
-- Privileged NONLEGAL fixture links its FK through the real lifecycle trigger, never disabling it.
CREATE FUNCTION pg_temp.link_fixture_correction(p_case uuid,p_proposal uuid,p_status text) RETURNS void LANGUAGE plpgsql SET search_path='' AS $fixture$
BEGIN
 IF p_status NOT IN('approved','routed') THEN RAISE EXCEPTION 'invalid_fixture_status';END IF;
 UPDATE payroll.correction_cases SET proposal_id=p_proposal,revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;
 UPDATE payroll.correction_cases SET status='review',revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;
 UPDATE payroll.correction_cases SET status='approved',revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;
 IF p_status='routed' THEN UPDATE payroll.correction_cases SET status='routed',revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;END IF;
END $fixture$;

-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4470000-0000-4000-8000-000000000001','cube4-advance-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4470000-0000-4000-8000-000000000002','cube4-advance-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4471000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4470000-0000-4000-8000-000000000001'),
 ('c4471000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4470000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve','payroll.lock','payroll.export','payroll.payment_record','payroll.correct','employee_finance.view','employee_finance.manage','employee_finance.approve']),
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['employee_finance.view']);
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000003','qa.payroll.viewonly',1,ARRAY['payroll.view']),
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000004','qa.payroll.recordonly',1,ARRAY['payroll.payment_record']),
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000005','qa.payroll.recordcorrect',1,ARRAY['payroll.view','payroll.payment_record','payroll.correct','employee_finance.view','employee_finance.manage','employee_finance.approve']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000001'),
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000002','c4470000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000001'),
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000002','c4472000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4471000-0000-4000-8000-000000000002','c4473000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4471000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4470000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4471000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4470000-0000-4000-8000-000000000001','Cube4 QA only');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4471000-0000-4000-8000-000000000001','c4473500-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4471000-0000-4000-8000-000000000001','c4474000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','c4470000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4471000-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000001','c4474000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','2020-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476000-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000001',3000,'2020-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476500-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000001','c4473500-0000-4000-8000-000000000001','2020-01-01');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4471000-0000-4000-8000-000000000001','c4474000-0000-4000-8000-000000000004','RUNQA2','Synthetic Second Employee','c4470000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4471000-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000004','c4474000-0000-4000-8000-000000000004','c4473000-0000-4000-8000-000000000001','2020-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476000-0000-4000-8000-000000000004','c4475000-0000-4000-8000-000000000004',1000,'2020-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476500-0000-4000-8000-000000000004','c4475000-0000-4000-8000-000000000004','c4473500-0000-4000-8000-000000000001','2020-01-01');

INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES('c4471000-0000-4000-8000-000000000001','hr.employee_finance',true,now()-interval '1 minute','c4470000-0000-4000-8000-000000000001','Slice7 synthetic Finance only');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4470000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','2020-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','2020-01-25',24,25,'ending','Africa/Cairo'),'Synthetic Finance schedule')->>'period_id'),true);
SELECT public.payroll_generate_next_period('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',1,gen_random_uuid(),(public.payroll_workspace('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001')->'next_preview'));
SELECT public.payroll_generate_next_period('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',2,gen_random_uuid(),(public.payroll_workspace('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001')->'next_preview'));
SELECT public.payroll_generate_next_period('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',3,gen_random_uuid(),(public.payroll_workspace('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001')->'next_preview'));
SELECT public.payroll_save_input('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2020-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic policy"}','save',gen_random_uuid());
RESET ROLE;
SELECT set_config('test.future_period',(SELECT id::text FROM payroll.periods WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND starts_on='2020-04-25'),true);
CREATE FUNCTION pg_temp.intent(op text,expected integer,data jsonb DEFAULT '{}',aid uuid DEFAULT 'c4478000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('operation',op,'advance',aid,'employment','c4475000-0000-4000-8000-000000000001','expected',expected,'data',CASE WHEN op='save' THEN jsonb_build_object('principal','100.00','count','3','first_period',current_setting('test.period'),'effective_on','2020-01-25','reason','Synthetic principal schedule')||data ELSE jsonb_build_object('reference','Synthetic external evidence','reason','Reviewed synthetic operation','confirmed','yes','date',CURRENT_DATE::text)||data END)
$$;
CREATE FUNCTION pg_temp.command(op text,expected integer,data jsonb DEFAULT '{}',attempt uuid DEFAULT NULL,aid uuid DEFAULT 'c4478000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_advance_command('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',pg_temp.intent(op,expected,data,aid),COALESCE(attempt,gen_random_uuid()))
$$;
CREATE FUNCTION pg_temp.resolve(op text,expected integer,data jsonb DEFAULT '{}',attempt uuid DEFAULT NULL,aid uuid DEFAULT 'c4478000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_resolve_advance_attempt('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',pg_temp.intent(op,expected,data,aid),attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.intent(text,integer,jsonb,uuid),pg_temp.command(text,integer,jsonb,uuid,uuid),pg_temp.resolve(text,integer,jsonb,uuid,uuid) TO authenticated;
SET LOCAL ROLE authenticated;
