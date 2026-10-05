BEGIN;
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required';END IF;END $$;
SELECT no_plan();
-- Reuses established seed shape only; none of the old payment assertions run.
-- Requires reviewed/qualified prerequisite migrations. Entire fixture rolls back.
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4480000-0000-4000-8000-000000000001','cube4-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4480000-0000-4000-8000-000000000002','cube4-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4481000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4480000-0000-4000-8000-000000000001'),
 ('c4481000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4480000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4481000-0000-4000-8000-000000000001','c4482000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve','payroll.lock','payroll.export','payroll.payment_record','payroll.correct']),
 ('c4481000-0000-4000-8000-000000000001','c4482000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4481000-0000-4000-8000-000000000001','c4482000-0000-4000-8000-000000000003','qa.payroll.viewonly',1,ARRAY['payroll.view']),
 ('c4481000-0000-4000-8000-000000000001','c4482000-0000-4000-8000-000000000004','qa.payroll.recordonly',1,ARRAY['payroll.payment_record']),
 ('c4481000-0000-4000-8000-000000000001','c4482000-0000-4000-8000-000000000005','qa.payroll.recordcorrect',1,ARRAY['payroll.view','payroll.payment_record','payroll.correct']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4481000-0000-4000-8000-000000000001','c4480000-0000-4000-8000-000000000001','c4480000-0000-4000-8000-000000000001'),
 ('c4481000-0000-4000-8000-000000000001','c4480000-0000-4000-8000-000000000002','c4480000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4481000-0000-4000-8000-000000000001','c4480000-0000-4000-8000-000000000001','c4482000-0000-4000-8000-000000000001'),
 ('c4481000-0000-4000-8000-000000000001','c4480000-0000-4000-8000-000000000002','c4482000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4481000-0000-4000-8000-000000000002','c4483000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4481000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4480000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4481000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4480000-0000-4000-8000-000000000001','Cube4 QA only');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4481000-0000-4000-8000-000000000001','c4483500-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4481000-0000-4000-8000-000000000001','c4484000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','c4480000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4481000-0000-4000-8000-000000000001','c4485000-0000-4000-8000-000000000001','c4484000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4481000-0000-4000-8000-000000000001','c4486000-0000-4000-8000-000000000001','c4485000-0000-4000-8000-000000000001',3000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4481000-0000-4000-8000-000000000001','c4486500-0000-4000-8000-000000000001','c4485000-0000-4000-8000-000000000001','c4483500-0000-4000-8000-000000000001','2030-01-01');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4481000-0000-4000-8000-000000000001','c4484000-0000-4000-8000-000000000004','RUNQA2','Synthetic Second Employee','c4480000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4481000-0000-4000-8000-000000000001','c4485000-0000-4000-8000-000000000004','c4484000-0000-4000-8000-000000000004','c4483000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4481000-0000-4000-8000-000000000001','c4486000-0000-4000-8000-000000000004','c4485000-0000-4000-8000-000000000004',1000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4481000-0000-4000-8000-000000000001','c4486500-0000-4000-8000-000000000004','c4485000-0000-4000-8000-000000000004','c4483500-0000-4000-8000-000000000001','2030-01-01');
CREATE FUNCTION pg_temp.approval(operation text DEFAULT 'approve',expected integer DEFAULT 1,attempt uuid DEFAULT 'c4489100-0000-4000-8000-000000000001',reason text DEFAULT 'Synthetic candidate reviewed') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_candidate_approval('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,expected,operation,reason,attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.approval(text,integer,uuid,text) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4480000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Synthetic foundation calendar')->>'period_id'),true);
SELECT public.payroll_save_input('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic proration"}','save',gen_random_uuid());
RESET ROLE;
-- Privileged test-only candidate result. No legal pack is inserted or claimed qualified.
-- This simulates an eventual trusted adapter contract solely to exercise approval/append atomicity inside ROLLBACK.
SELECT set_config('test.run','c4489200-0000-4000-8000-000000000001',true);
SELECT set_config('test.candidate','c4489200-0000-4000-8000-000000000002',true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,'draft','c4480000-0000-4000-8000-000000000001');
SELECT set_config('test.manifest',payroll.run_manifest('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT set_config('test.synthetic_output',payroll.build_review(current_setting('test.manifest')::jsonb)::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"4000"')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,0,net}','"3000"'),'{employees,0,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,1,net}','"1000"'),'{employees,1,issues}','[]'),'{employees,1,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.manifest')::jsonb,current_setting('test.synthetic_output')::jsonb,'c4480000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id=current_setting('test.candidate')::uuid,revision=1 WHERE tenant_id='c4481000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
SET LOCAL ROLE authenticated;
SELECT pg_temp.approval();
RESET ROLE;
SELECT set_config('test.output',payroll.append_final_output('c4481000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4480000-0000-4000-8000-000000000001',2,gen_random_uuid())::text,true);

CREATE FUNCTION pg_temp.report(kind text DEFAULT 'payments',employer uuid DEFAULT 'c4483000-0000-4000-8000-000000000001',employee uuid DEFAULT NULL,cursor uuid DEFAULT NULL,revision text DEFAULT NULL,site uuid DEFAULT NULL,exporting boolean DEFAULT false) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_report_workspace('c4481000-0000-4000-8000-000000000001',employer,current_setting('test.output')::uuid,kind,NULL,employee,'',cursor,1,revision,exporting,site,NULL)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.report(text,uuid,uuid,uuid,text,uuid,boolean) TO authenticated;
SELECT ok(NOT has_function_privilege('authenticated','payroll.report_rows(uuid,uuid,uuid,text,uuid,uuid,text,uuid,uuid)','EXECUTE'),'private row projection is not directly executable');
SELECT ok(NOT has_function_privilege('service_role','payroll.report_payslip_lines(jsonb,jsonb,uuid,jsonb)','EXECUTE'),'saved presentation does not expose a service-role bypass');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4480000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT pg_temp.report()$$,'42501','payroll_forbidden','review-only role cannot retrieve finalized financial reports');
SELECT set_config('request.jwt.claim.sub','c4480000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.report(employer=>'c4483000-0000-4000-8000-000000000003')$$,'42501','payroll_forbidden','same Tenant other Employer cannot retrieve this output');
SELECT throws_ok($$SELECT public.payroll_report_workspace('c4481000-0000-4000-8000-000000000002','c4483000-0000-4000-8000-000000000002',current_setting('test.output')::uuid,'payments')$$,'42501','payroll_forbidden','foreign Tenant denied before financial disclosure');
SELECT throws_ok($$SELECT pg_temp.report(employee=>'c4485000-0000-4000-8000-000000000009')$$,'42501','payroll_forbidden','unknown Employee cannot select another financial context');
SELECT throws_ok($$SELECT public.payroll_report_workspace('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'payments',p_limit=>51)$$,'22023','payroll_report_invalid','page bound cannot be expanded by the caller');
SELECT set_config('test.report',pg_temp.report()::text,true);
SELECT is((current_setting('test.report')::jsonb->>'total_count')::integer,2,'matched total is independent of one-row page');
SELECT is(jsonb_array_length(current_setting('test.report')::jsonb->'rows'),1,'bounded display returns one row');
SELECT is((current_setting('test.report')::jsonb->'summary'->>'net')::numeric,4000::numeric,'summary includes both finalized Employees');
SELECT is((current_setting('test.report')::jsonb->'summary'->>'remaining')::numeric,4000::numeric,'payment summary reconciles whole output');
SELECT is(current_setting('test.report')::jsonb->>'next','c4485000-0000-4000-8000-000000000001','cursor is last row only when more rows exist');
SELECT set_config('test.report_next',pg_temp.report(cursor=>(current_setting('test.report')::jsonb->>'next')::uuid,revision=>current_setting('test.report')::jsonb->>'source_revision')::text,true);
SELECT is(current_setting('test.report_next')::jsonb->'rows'->0->>'id','c4485000-0000-4000-8000-000000000004','next page reaches the distinct remaining Employee');
SELECT is(current_setting('test.report_next')::jsonb->'summary',current_setting('test.report')::jsonb->'summary','summary stays exact across pages');
SELECT is(current_setting('test.report_next')::jsonb->>'next',NULL::text,'last page has no continuation');
SELECT throws_ok($$SELECT pg_temp.report(revision=>'obsolete-source')$$,'PT409','payroll_report_source_changed','obsolete revision refuses a fresh page or export');
SELECT is((pg_temp.report(employee=>'c4485000-0000-4000-8000-000000000004')->'summary'->>'net')::numeric,1000::numeric,'selected Employee totals cannot include the hidden first Employee');
SELECT is((pg_temp.report(site=>'c4483500-0000-4000-8000-000000000001')->>'total_count')::integer,2,'saved site filter and totals select the same cohort');
SELECT throws_ok($$SELECT pg_temp.report(site=>'c4483500-0000-4000-8000-000000000009')$$,'42501','payroll_forbidden','foreign site reference refused instead of falling back to all Employees');
SELECT is(public.payroll_report_dimensions('c4481000-0000-4000-8000-000000000001','c4483000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'payments','site')->'items'->0->>'id','c4483500-0000-4000-8000-000000000001','dimension choices come from saved output references');
SELECT ok(pg_temp.report('statutory')->'issues' @> '["statutory_pack_unqualified"]','synthetic context does not qualify a legal pack');
SELECT throws_ok($$SELECT pg_temp.report('statutory',exporting=>true)$$,'23514','payroll_report_incomplete','unqualified statutory report cannot be exported as complete');
RESET ROLE;
DELETE FROM platform_core.membership_roles WHERE tenant_id='c4481000-0000-4000-8000-000000000001' AND user_id='c4480000-0000-4000-8000-000000000001';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('c4481000-0000-4000-8000-000000000001','c4480000-0000-4000-8000-000000000001','c4482000-0000-4000-8000-000000000003');
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT pg_temp.report()$$,'current view-only authority can retrieve scoped historical report');
SELECT throws_ok($$SELECT pg_temp.report(exporting=>true)$$,'42501','payroll_forbidden','view-only authority cannot become export authority');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
