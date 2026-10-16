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

-- No real payroll result or legal qualification is created in this test.
CREATE FUNCTION pg_temp.policy_save(owner uuid,head uuid,revision int,from_on date,until_on date DEFAULT NULL,attempt uuid DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_save_input('c4421000-0000-4000-8000-000000000001',owner,'policy',NULL,NULL,head,revision,from_on,until_on,'{"mode":"fixed_30_day","reason":"NONLEGAL synthetic future policy"}','save',coalesce(attempt,gen_random_uuid())) $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000001',true);
SELECT set_config('test.policy',(public.payroll_save_input('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2000-01-01',NULL,'{"mode":"calendar_days","reason":"NONLEGAL original policy"}','save',gen_random_uuid())->>'id'),true);
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000001',current_setting('test.policy')::uuid,1,(clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date)$$,'22023','payroll_policy_future_date_required','today cannot revise an existing policy');
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000001',current_setting('test.policy')::uuid,1,'2000-01-01')$$,'22023','payroll_policy_future_date_required','date must follow the latest version');
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000001',current_setting('test.policy')::uuid,1,'2030-03-01','2031-01-01')$$,'22023','payroll_policy_future_date_required','new policy version cannot introduce an expiry gap');
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000002',current_setting('test.policy')::uuid,1,'2030-03-01')$$,'42501','payroll_forbidden','foreign employer cannot edit tenant-wide policy');
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000001',current_setting('test.policy')::uuid,1,'2030-03-01')$$,'42501','payroll_forbidden','read-only actor cannot edit policy');
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000001',NULL,0,'2030-03-01')$$,'23505',NULL,'second policy head from same employer rejected by unique partial index');
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000003',NULL,0,'2030-03-01')$$,'23505',NULL,'second policy head from other employer rejected by unique partial index');
SELECT set_config('test.saved',pg_temp.policy_save('c4423000-0000-4000-8000-000000000003',current_setting('test.policy')::uuid,1,'2030-03-01',attempt=>'c4429000-0000-4000-8000-000000000031')::text,true);
SELECT is((current_setting('test.saved')::jsonb->>'revision')::int,2,'other active employer can append the global policy');
SELECT is(pg_temp.policy_save('c4423000-0000-4000-8000-000000000003',current_setting('test.policy')::uuid,1,'2030-03-01',attempt=>'c4429000-0000-4000-8000-000000000031'),current_setting('test.saved')::jsonb,'receipt replay returns original result despite stale expected revision');
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000003',current_setting('test.policy')::uuid,1,'2030-04-01',attempt=>'c4429000-0000-4000-8000-000000000031')$$,'PT409','payroll_attempt_conflict','same attempt cannot change intent');
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000003',current_setting('test.policy')::uuid,1,'2030-04-01')$$,'PT409','payroll_stale','concurrent stale editor cannot overwrite version');
SELECT is(public.payroll_configuration_workspace('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000003')->'policy'->>'revision','2','workspace shows latest global version from another employer');
SELECT is(public.payroll_configuration_workspace('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000003')->'policy_today'->>'revision','1','workspace distinguishes today policy from future latest');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.input_heads WHERE id=current_setting('test.policy')::uuid),1::bigint,'one policy head retained');
SELECT is((SELECT count(*) FROM payroll.input_versions WHERE head_id=current_setting('test.policy')::uuid),2::bigint,'append-only versions retained');
SELECT is((SELECT data->>'mode' FROM payroll.input_versions WHERE head_id=current_setting('test.policy')::uuid AND revision=1),'calendar_days','previous policy data unchanged');
SELECT is((SELECT employer_id::text FROM payroll.input_versions WHERE head_id=current_setting('test.policy')::uuid AND revision=2),'c4423000-0000-4000-8000-000000000001','version retains original head employer for composite ownership');
SELECT is((SELECT employer_id::text FROM payroll.audit_events WHERE details->>'id'=current_setting('test.policy') AND details->>'revision'='2'),'c4423000-0000-4000-8000-000000000003','audit preserves selected execution employer');
-- Minimal empty-employee manifest tests only policy selection, never financial qualification.
CREATE FUNCTION pg_temp.policy_review(from_on date,until_on date,expiry date DEFAULT NULL,cancelled boolean DEFAULT false) RETURNS jsonb LANGUAGE sql AS $$
 SELECT payroll.build_review_before_advances(jsonb_build_object('period',jsonb_build_object('starts_on',from_on,'ends_on',until_on,'is_transition',false),'employees','[]'::jsonb,'packs','[]'::jsonb,'optional','{}'::jsonb,'corrections','[]'::jsonb,'inputs',
 (SELECT jsonb_agg(jsonb_build_object('head',jsonb_build_object('kind','policy'),'version',jsonb_build_object('effective_from',v.effective_from,'effective_until',CASE WHEN v.revision=2 THEN expiry ELSE v.effective_until END,'revision',v.revision,'status',CASE WHEN cancelled AND v.revision=2 THEN 'cancelled' ELSE v.status END,'data',v.data)) ORDER BY v.revision)
 FROM payroll.input_versions v WHERE v.head_id=current_setting('test.policy')::uuid))) $$;
SELECT is(pg_temp.policy_review('2030-02-25','2030-03-24')->>'policy','calendar_days','period spanning change retains its start policy');
SELECT is(pg_temp.policy_review('2030-03-01','2030-03-31')->>'policy','fixed_30_day','period starting at threshold adopts new version');
SELECT is(pg_temp.policy_review('2030-03-25','2030-04-24')->>'policy','fixed_30_day','next staggered cycle adopts new version');
SELECT is(pg_temp.policy_review('2030-01-01','2030-01-31')->>'policy','calendar_days','historical period unchanged');
SELECT ok((pg_temp.policy_review('2030-03-01','2030-03-31','2030-03-15')->'issues') @> '[{"code":"policy_coverage_gap"}]','explicit mid-period expiry still blocks');
SELECT ok((pg_temp.policy_review('2030-03-01','2030-03-31',cancelled=>true)->'issues') @> '[{"code":"policy_coverage_gap"}]','cancelled latest version does not revive older policy');
SELECT is(pg_temp.policy_review('2030-03-01','2030-03-31')->>'financially_qualified','false','policy choice does not grant legal financial qualification');
-- Synthetic frozen PEOPLE context only; no finalized payroll or issued rules fabricated.
SET LOCAL ROLE authenticated;
SELECT set_config('test.period',public.payroll_save_calendar('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-04-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-04-25',24,25,'ending','Africa/Cairo'),'NONLEGAL frozen guard fixture')->>'period_id',true);
RESET ROLE;
INSERT INTO payroll.people_frozen_contexts(tenant_id,employer_id,employment_id,period_id,run_id,source_snapshot) VALUES('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','c4425000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,gen_random_uuid(),'{"fixture":"NONLEGAL frozen input guard"}');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000003',current_setting('test.policy')::uuid,2,'2030-05-01')$$,'23514','payroll_correction_required','other-employer edit cannot bypass tenant-wide frozen guard');
SELECT lives_ok($$SELECT pg_temp.policy_save('c4423000-0000-4000-8000-000000000003',current_setting('test.policy')::uuid,2,'2030-05-25')$$,'future version after frozen period allowed');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
