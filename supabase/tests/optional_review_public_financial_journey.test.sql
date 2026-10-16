BEGIN;
DO $$ BEGIN
  IF current_database() <> 'business_platform_cube4_adam_positive_qa' THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT no_plan();

-- One bounded, rollback-only NONLEGAL source fixture.  Time is deliberately
-- absent; this acceptance exercises only the actual Leave source lineage.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('d5920000-0000-4000-8000-000000000001','d592-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d5920000-0000-4000-8000-000000000002','d592-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d5921000-0000-4000-8000-000000000001','NONLEGAL D440 Leave binding QA','d5920000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d5921000-0000-4000-8000-000000000001','d5922000-0000-4000-8000-000000000001','d592.payroll.leave',1,
 ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','attendance.view','attendance.approve','attendance.manage','attendance.correct','payroll.review','payroll.export','payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','leave.manage','leave.view','leave.approve']),
       ('d5921000-0000-4000-8000-000000000001','d5922000-0000-4000-8000-000000000002','d592.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d5921000-0000-4000-8000-000000000001','d5920000-0000-4000-8000-000000000001','d5920000-0000-4000-8000-000000000001'),
       ('d5921000-0000-4000-8000-000000000001','d5920000-0000-4000-8000-000000000002','d5920000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d5921000-0000-4000-8000-000000000001','d5920000-0000-4000-8000-000000000001','d5922000-0000-4000-8000-000000000001'),
       ('d5921000-0000-4000-8000-000000000001','d5920000-0000-4000-8000-000000000002','d5922000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','NONLEGAL D440 NONLEGAL Employer','NONLEGAL D440 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd5921000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d5920000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll','hr.leave']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d5921000-0000-4000-8000-000000000001','d5924000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','NONLEGAL D440 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d5921000-0000-4000-8000-000000000001','d5925000-0000-4000-8000-000000000001','NONLEGAL D440','NONLEGAL D440 Leave Employee','d5920000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d5921000-0000-4000-8000-000000000001','d5926000-0000-4000-8000-000000000001','d5925000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','2026-01-04','active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d5921000-0000-4000-8000-000000000001','d5925000-0000-4000-8000-000000000001','d5920000-0000-4000-8000-000000000002','d5920000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d5921000-0000-4000-8000-000000000001','d5927000-0000-4000-8000-000000000001','d5926000-0000-4000-8000-000000000001',125,'2026-01-04');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d5921000-0000-4000-8000-000000000001','d5928000-0000-4000-8000-000000000001','D240-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d5921000-0000-4000-8000-000000000001','d5928000-0000-4000-8000-000000000001',1,'D240 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d5920000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d5921000-0000-4000-8000-000000000001','d5929000-0000-4000-8000-000000000001','d5926000-0000-4000-8000-000000000001','d5924000-0000-4000-8000-000000000001','d5928000-0000-4000-8000-000000000001',1,'2026-01-04');
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592','D260 calendar','2026-01-04',NULL,'{}'::smallint[],'[]'::jsonb,'NONLEGAL fixture','D260 source factory')::text,true);
SELECT set_config('test.year_period',public.leave_create_year_period('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,'2026-01-04','2026-01-05','D260 period','D260 source factory')::text,true);
SELECT set_config('test.leave_type',public.leave_create_type('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592-paid-other','D260 paid other NONLEGAL','2026-01-04','unpaid','untracked',true,'NONLEGAL fixture','No statutory entitlement asserted','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d5921000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.leave_type')::uuid AND version=1),true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000002',true);
SELECT set_config('test.request',public.leave_submit_own_request('d5921000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2026-01-04','2026-01-04',true,'first','D260 actual one-day Leave','d592-submit-001')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000001',true);
SELECT set_config('test.approved',public.leave_approve_request('d5921000-0000-4000-8000-000000000001',current_setting('test.request')::uuid,1,1,'D260 actual Leave approval','d592-approve-001')::text,true);
RESET ROLE;

INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592d000-0000-4000-8000-000000000001',1,'2026-01-04',NULL,31,'ending','UTC','d5920000-0000-4000-8000-000000000001','NONLEGAL D440 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001','d592d000-0000-4000-8000-000000000001','2026-01-04','2026-01-04','2026-01-04','UTC','NONLEGAL D440 one-day NONLEGAL Leave QA',false,'d5920000-0000-4000-8000-000000000001');


-- Actual public configuration publication, without official evidence or mocked qualification.
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_manage_statutory_rules)
VALUES('d5920000-0000-4000-8000-000000000001',true,false,true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000001',true);
SELECT set_config('test.config_rules','{"tax":{"treatment":"01","exemption":"0","column_basis":"annual_raw","columns":[{"through":"","bands":[{"upper":"","rate":"10"}]}]},"insurance":{"category":"NONLEGAL-OPTIONAL","minimum":"100","maximum":"200","branches":[{"branch":"pension","employee":"1","employer":"2","deductible":true}]},"base_taxable":true,"labour_deduction_adapter":"eg-wage-deductions113114-v1"}',true);
SELECT set_config('test.config_head',public.statutory_draft_save(NULL,0,gen_random_uuid(),'NONLEGAL-OPTIONAL-PUBLIC-2026','2026-01-01','2027-01-01','[]',NULL,current_setting('test.config_rules')::jsonb)->>'head',true);
SELECT set_config('test.config_stamp',public.statutory_draft_issuance_status(current_setting('test.config_head')::uuid,1)->>'evidence_stamp',true);
SELECT is(public.statutory_draft_issuance_status(current_setting('test.config_head')::uuid,1)->>'ready','true','valid numeric configuration can activate with zero references and zero comparisons');
SELECT set_config('test.config_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.config_receipt',public.statutory_draft_issue(current_setting('test.config_head')::uuid,1,current_setting('test.config_attempt')::uuid,current_setting('test.config_stamp'),false,NULL)::text,true);
SELECT set_config('test.config_pack',current_setting('test.config_receipt')::jsonb->>'pack',true);
SELECT is(public.statutory_draft_issue(current_setting('test.config_head')::uuid,1,current_setting('test.config_attempt')::uuid,current_setting('test.config_stamp'),false,NULL),current_setting('test.config_receipt')::jsonb,'publication receipt replay is idempotent without accounting attestation');
SELECT throws_ok($$SELECT public.statutory_draft_issue(current_setting('test.config_head')::uuid,1,current_setting('test.config_attempt')::uuid,current_setting('test.config_stamp'),false,'Changed intent')$$,'PT409','statutory_draft_attempt_conflict','publication attempt cannot change intent');
SELECT throws_ok($$SELECT public.statutory_draft_save(NULL,0,gen_random_uuid(),'NONLEGAL-INVALID-NUMBERS','2026-01-01','2027-01-01','[]','Invalid numeric QA',jsonb_set(current_setting('test.config_rules')::jsonb,'{tax,columns,0,bands,0,rate}','"101"'))$$,'22023',NULL,'optional accounting review does not admit invalid arithmetic rules');
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.statutory_draft_issue(current_setting('test.config_head')::uuid,1,gen_random_uuid(),current_setting('test.config_stamp'),false,NULL)$$,'42501','statutory_draft_forbidden','ordinary employee cannot publish calculation rules');
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000001',true);
SELECT is(public.statutory_draft_compare(current_setting('test.config_head')::uuid,1,gen_random_uuid(),'{"name":"Optional mismatch after activation","scenario":"rounding","origin":"synthetic","source_url":"","reference":"Independent company check","tax":{"net":"50","duration":"30","prior_due":"0","from":"2026-01-01","until":"2026-01-31"},"insurance":[],"expected":{"tax_due":"0","tax_delta":"0","employee_insurance":"0","employer_insurance":"0","deductible_insurance":"0"}}')->>'matched','false','company may record an optional mismatched comparison after publication');
SELECT is(public.statutory_draft_issuance_status(current_setting('test.config_head')::uuid,1)->>'evidence_stamp',current_setting('test.config_stamp'),'optional comparisons do not alter configuration fingerprint');
RESET ROLE;
SELECT is(payroll.issued_tax_qualification(current_setting('test.config_pack')::uuid,'2026-01-04','2026-01-04')->>'ready','true','real immutable published configuration qualifies without official results');
SELECT is(payroll.issued_labour_qualification(current_setting('test.config_pack')::uuid,'2026-01-04','2026-01-04')->>'ready','true','configured deduction limits need no mandatory official scenarios');
SELECT is(payroll.issued_tax_qualification(current_setting('test.config_pack')::uuid,NULL,'2026-01-04')->>'ready','false','missing calculation dates remain invalid');
SELECT is(payroll.issued_tax_qualification(current_setting('test.config_pack')::uuid,'2027-01-01','2027-01-31')->>'ready','false','publication does not ignore actual date applicability');
SET LOCAL ROLE authenticated;
SELECT set_config('test.open_head',public.statutory_draft_save(NULL,0,gen_random_uuid(),'NONLEGAL-OPEN-CONFIG','2026-01-01',NULL,'[]','NONLEGAL open interval',jsonb_set(jsonb_set(current_setting('test.config_rules')::jsonb,'{tax,treatment}','"03"'),'{insurance,category}','"NONLEGAL open category"'))->>'head',true);
SELECT set_config('test.open_pack',public.statutory_draft_issue(current_setting('test.open_head')::uuid,1,gen_random_uuid(),public.statutory_draft_issuance_status(current_setting('test.open_head')::uuid,1)->>'evidence_stamp',false,NULL)->>'pack',true);
RESET ROLE;
SELECT is(payroll.issued_tax_qualification(current_setting('test.open_pack')::uuid,'2028-01-01','2028-01-31')->>'ready','true','open-ended configuration has no mandatory annual review deadline');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000001',true);
SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2026-01-04',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted monthly policy"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','opening_ytd','d5926000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-01-04',NULL,'{"year":2026,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2026-01-01","coverage_end":"2026-01-03","tax_duration_days":0,"reference":"NONLEGAL no prior employment facts","reason":"Synthetic reviewed zero opening"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','statutory_context','d5926000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-01-04',NULL,'{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL reviewed uninsured exclusion","reason":"Synthetic source facts only","calculation_from":"2026-01-04","calculation_until":"2026-01-04","tax_duration_days":1}','save',gen_random_uuid());
-- Completing a same-date unconsumed draft appends history, without a new date.
RESET ROLE;
SELECT set_config('test.draft_opening',(SELECT jsonb_build_object('head',h.id,'revision',h.revision,'version',v.id,'data',v.data)::text FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id='d5921000-0000-4000-8000-000000000001' AND h.kind='opening_ytd'),true);
SELECT set_config('test.draft_attempt',gen_random_uuid()::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.draft_result',public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','opening_ytd','d5926000-0000-4000-8000-000000000001',NULL,(current_setting('test.draft_opening')::jsonb->>'head')::uuid,1,'2026-01-04',NULL,current_setting('test.draft_opening')::jsonb->'data'||jsonb_build_object('reason','NONLEGAL completed same-date draft'),'save',current_setting('test.draft_attempt')::uuid)::text,true);
SELECT is(current_setting('test.draft_result')::jsonb->>'revision','2','same-date draft completion appends a new revision');
SELECT is(public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','opening_ytd','d5926000-0000-4000-8000-000000000001',NULL,(current_setting('test.draft_opening')::jsonb->>'head')::uuid,1,'2026-01-04',NULL,current_setting('test.draft_opening')::jsonb->'data'||jsonb_build_object('reason','NONLEGAL completed same-date draft'),'save',current_setting('test.draft_attempt')::uuid),current_setting('test.draft_result')::jsonb,'same-date draft lost response replays original receipt');
SELECT throws_ok($$SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','opening_ytd','d5926000-0000-4000-8000-000000000001',NULL,(current_setting('test.draft_opening')::jsonb->>'head')::uuid,1,'2026-01-04',NULL,current_setting('test.draft_opening')::jsonb->'data','save',gen_random_uuid())$$,'PT409','payroll_stale','stale revision cannot overwrite same-date draft');
RESET ROLE;
SELECT is((SELECT data FROM payroll.input_versions WHERE id=(current_setting('test.draft_opening')::jsonb->>'version')::uuid),current_setting('test.draft_opening')::jsonb->'data','original draft version remains immutable');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','opening_ytd','d5926000-0000-4000-8000-000000000001',NULL,(current_setting('test.draft_opening')::jsonb->>'head')::uuid,2,'2026-01-03',NULL,jsonb_set(current_setting('test.draft_opening')::jsonb->'data','{coverage_end}','"2026-01-02"'),'save',gen_random_uuid())$$,'22023','payroll_employment_unavailable','draft completion cannot backdate before employment');
SELECT set_config('test.fixed_component',public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2026-01-04',NULL,'{"key":"fixed_allowance","name":"NONLEGAL fixed monthly allowance","classification":"earning","calculation":"fixed","base":"","value":"100","taxable":"true","social":"false","visible":"true","active":"true","order":"10","behavior":"recurring","proration":"salary_proration","reason":"Accepted recurring monthly-value contract"}','save',gen_random_uuid())->>'id',true);
SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','recurring','d5926000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-01-04',NULL,jsonb_build_object('component_id',current_setting('test.fixed_component'),'value','100','reason','NONLEGAL fixed assignment'),'save',gen_random_uuid());
SELECT set_config('test.percent_component',public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','component',NULL,NULL,NULL,0,'2026-01-04',NULL,'{"key":"earned_percent","name":"NONLEGAL earned-base percentage","classification":"earning","calculation":"percentage","base":"base_pay","value":"10","taxable":"true","social":"false","visible":"true","active":"true","order":"20","behavior":"recurring","proration":"salary_proration","reason":"Accepted earned-base percentage contract"}','save',gen_random_uuid())->>'id',true);
SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','recurring','d5926000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-01-04',NULL,jsonb_build_object('component_id',current_setting('test.percent_component'),'value','10','reason','NONLEGAL percentage assignment'),'save',gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL actual published configuration',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'true','actual calculation is available with published settings and no official comparisons');
-- No issuer function is replaced: the real public publication above is used end to end.
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'calculate','NONLEGAL positive implementation journey',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT (output->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),168.75::numeric,'approved half-day unpaid Leave reduces monthly base once with Time disabled');
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),151.87::numeric,'actual tax composition reconciles synthetic net');
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'true','actual profile producer uses real published configuration without external proof gates');
SELECT is((SELECT output->'employees'->0->'financial_qualification'->'tax_evidence'->>'origin' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'published_configuration','candidate records actual configuration publication provenance');
SELECT is((SELECT (output->'employees'->0->>'base')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),62.5::numeric,'approved half Leave reduces only dated base fraction once');
SELECT is((SELECT (line->>'amount')::numeric FROM payroll.candidates c CROSS JOIN LATERAL jsonb_array_elements(c.output->'employees'->0->'lines') line WHERE c.id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid AND line->>'component'=current_setting('test.fixed_component')),100::numeric,'fixed recurring monthly value retains its approved ordinary-cycle contract');
SELECT is((SELECT (line->>'amount')::numeric FROM payroll.candidates c CROSS JOIN LATERAL jsonb_array_elements(c.output->'employees'->0->'lines') line WHERE c.id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid AND line->>'component'=current_setting('test.percent_component')),6.25::numeric,'recurring10percent uses earned62.5 base rather than contracted125');
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,2,'approve','NONLEGAL implementation approval',gen_random_uuid());
RESET ROLE;
-- Mandatory audit failure must roll the real public append back completely.
CREATE FUNCTION pg_temp.reject_final_audit() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.action='run_finalized' THEN RAISE EXCEPTION 'NONLEGAL mandatory audit failure' USING ERRCODE='55000';END IF;RETURN NEW;END$$;
CREATE TRIGGER nonlegal_final_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_final_audit();
SELECT set_config('test.audit_attempt',gen_random_uuid()::text,true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_run_finalize('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.audit_attempt')::uuid)$q$,'55000','NONLEGAL mandatory audit failure','public finalization rolls back when mandatory audit fails');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_contexts),0::bigint,'audit failure leaves no final output');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions),0::bigint,'audit failure leaves no consumed input');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE attempt_key=current_setting('test.audit_attempt')::uuid),0::bigint,'audit failure leaves no successful receipt');
SELECT is((SELECT status FROM payroll.runs WHERE id=(current_setting('test.run')::jsonb->>'id')::uuid),'approved','audit failure preserves approved lifecycle');
DROP TRIGGER nonlegal_final_audit_failure ON payroll.audit_events;
SET LOCAL ROLE authenticated;
SELECT set_config('test.final_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.final',public.payroll_run_finalize('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid)::text,true);
SELECT is(public.payroll_run_finalize('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid),current_setting('test.final')::jsonb,'exact public finalization replay returns original result');
SELECT is(public.payroll_run_finalization_reconcile('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,current_setting('test.final_attempt')::uuid)->'result',current_setting('test.final')::jsonb,'public recovery returns committed receipt without calculating or consuming again');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.final_contexts),1::bigint,'one final output after replay and recovery');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions WHERE run_id=(current_setting('test.run')::jsonb->>'id')::uuid),8::bigint,'all source versions including draft history frozen once');
SELECT is((SELECT count(*) FROM payroll.final_source_bindings WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid AND source_domain='time'),0::bigint,'actual financial finalization does not invent Time lineage');
SELECT set_config('test.original_employee', (SELECT to_jsonb(e)::text FROM payroll.final_employees e WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),true);
SELECT set_config('test.source_changes',jsonb_build_array(jsonb_build_object('type','compensation','source_id','d5927000-0000-4000-8000-000000000001','expected_hash',payroll.source_hash((SELECT to_jsonb(c) FROM people.compensation_versions c WHERE id='d5927000-0000-4000-8000-000000000001')),'fields',jsonb_build_object('amount',150)))::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,NULL,0,current_setting('test.source_changes')::jsonb,'[]',NULL,'NONLEGAL reviewed unpaid correction','NONLEGAL implementation reference',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.proposal',public.payroll_correction_proposal('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,NULL,0,current_setting('test.source_changes')::jsonb,'[]',NULL,'NONLEGAL reviewed unpaid correction','NONLEGAL implementation reference',current_setting('test.preview')::jsonb->>'preview_hash','save',gen_random_uuid())::text,true);
SELECT public.payroll_correction_command('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,1,'calculate','NONLEGAL amendment calculation',gen_random_uuid());
SELECT set_config('test.amendment_review',public.payroll_correction_workspace('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.final')::jsonb->>'output')::uuid,(current_setting('test.proposal')::jsonb->>'case_id')::uuid,'compensation',NULL,NULL)::text,true);
SELECT is((current_setting('test.amendment_review')::jsonb->'amendments'->0->'summary'->>'gross')::numeric,182.5::numeric,'actual authorized correction review displays replacement gross before approval');
SELECT is((current_setting('test.amendment_review')::jsonb->'amendments'->0->'summary'->>'net')::numeric,164.25::numeric,'actual authorized correction review displays replacement net before approval');
SELECT is((current_setting('test.amendment_review')::jsonb->'amendments'->0->'review_employees'->0->>'net')::numeric,164.25::numeric,'bounded employee explanation agrees with review summary');
SELECT throws_ok($q$SELECT public.payroll_correction_workspace('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,'compensation',NULL,NULL)$q$,'42501','payroll_forbidden','review projection cannot cross an invalid final-output scope');
SELECT public.payroll_correction_command('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,2,'approve','NONLEGAL proposal approval',gen_random_uuid());
RESET ROLE;
SELECT set_config('test.amendment',(SELECT jsonb_build_object('id',r.id,'candidate',r.candidate_id,'revision',r.revision)::text FROM payroll.amendment_runs m JOIN payroll.runs r ON r.tenant_id=m.tenant_id AND r.id=m.run_id WHERE m.case_id=(current_setting('test.proposal')::jsonb->>'case_id')::uuid),true);
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.amendment')::jsonb->>'candidate')::uuid),164.25::numeric,'actual correction calculation uses new salary and tax');
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','d592e000-0000-4000-8000-000000000001',(current_setting('test.amendment')::jsonb->>'id')::uuid,(current_setting('test.amendment')::jsonb->>'candidate')::uuid,(current_setting('test.amendment')::jsonb->>'revision')::integer,'approve','NONLEGAL amendment approval',gen_random_uuid());
SELECT set_config('test.batch_attempt',gen_random_uuid()::text,true);
SELECT set_config('test.batch',public.payroll_correction_finalize('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,3,current_setting('test.batch_attempt')::uuid)::text,true);
SELECT is(public.payroll_correction_finalize('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,3,current_setting('test.batch_attempt')::uuid),current_setting('test.batch')::jsonb,'unpaid public batch replay returns original receipt');
SELECT is(public.payroll_correction_finalization_reconcile('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',(current_setting('test.proposal')::jsonb->>'case_id')::uuid,3,current_setting('test.batch_attempt')::uuid)->'result',current_setting('test.batch')::jsonb,'unpaid recovery returns committed original batch');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.output_successions),1::bigint,'one succession after batch replay and recovery');
SELECT is((SELECT count(*) FROM payroll.final_contexts),2::bigint,'one original and one authoritative replacement');
SELECT is((SELECT count(*) FROM payroll.correction_source_effects),1::bigint,'source effect applies once');
SELECT is((SELECT to_jsonb(e) FROM payroll.final_employees e WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),current_setting('test.original_employee')::jsonb,'original frozen explanation and money unchanged');
SELECT is((SELECT amount FROM people.compensation_versions WHERE id='d5927000-0000-4000-8000-000000000001'),150::numeric,'governed source correction applied with replacement');
SELECT is((SELECT count(*) FROM payroll.input_frozen_versions),16::bigint,'each output owns one immutable input set including preserved draft history');
SELECT is((SELECT count(*) FROM payroll.final_source_bindings WHERE source_domain='time'),0::bigint,'replacement owns its current absent Time binding without deleting original');
SELECT is((SELECT count(*) FROM payroll.final_source_bindings WHERE source_domain='leave'),2::bigint,'original and unpaid replacement retain exact Leave request lineage once each');
-- Complete the public journey by recording synthetic external-payment evidence
-- against the actual canonical replacement. No manual final-output insertion or
-- financially_qualified override: only the explicit NONLEGAL issuer boundary
-- above is the real public API. These APIs do not execute any bank transfer.
SELECT set_config('test.payment_output',(SELECT id::text FROM payroll.final_contexts
 WHERE tenant_id='d5921000-0000-4000-8000-000000000001'
 AND id<>(current_setting('test.final')::jsonb->>'output')::uuid),true);
SELECT set_config('test.payment_attempt',gen_random_uuid()::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000001',true);
SELECT is(public.payroll_payment_request_prepare(
 'd5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',
 current_setting('test.payment_output')::uuid,current_setting('test.payment_attempt')::uuid,
 jsonb_build_object('expected',0,'operation','remaining','date',CURRENT_DATE,
 'reference','NONLEGAL external payment fixture','reason','Synthetic recording; no bank transfer',
 'allocations','[]'::jsonb,'original',NULL,'confirmed','yes'))->>'state','pending',
 'public payment preparation retains a recoverable intent on the calculated replacement');
SELECT is(public.payroll_payment_request_get(
 'd5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',
 current_setting('test.payment_output')::uuid)->>'attempt',current_setting('test.payment_attempt'),
 'pending payment can be recovered before submission');
SELECT set_config('test.payment_result',public.payroll_payment_request_submit(
 'd5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',
 current_setting('test.payment_output')::uuid,current_setting('test.payment_attempt')::uuid)::text,true);
SELECT is((current_setting('test.payment_result')::jsonb->>'remaining')::numeric,0::numeric,
 'recorded synthetic external payment covers the actual replacement net');
SELECT is(public.payroll_payment_request_submit(
 'd5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',
 current_setting('test.payment_output')::uuid,current_setting('test.payment_attempt')::uuid),
 current_setting('test.payment_result')::jsonb,'lost-response retry returns the original payment receipt');
SELECT is(public.payroll_payment_facts(
 'd5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001',
 current_setting('test.payment_output')::uuid)->>'status','paid',
 'public payment facts show the final replacement paid');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.payment_events
 WHERE tenant_id='d5921000-0000-4000-8000-000000000001'),1::bigint,
 'payment replay records exactly one external-payment event');
SELECT is((SELECT to_jsonb(e) FROM payroll.final_employees e
 WHERE output_id=(current_setting('test.final')::jsonb->>'output')::uuid),
 current_setting('test.original_employee')::jsonb,'payment on replacement preserves the original frozen result');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d5920000-0000-4000-8000-000000000001',true);
SELECT is(public.people_payroll_inclusion('d5921000-0000-4000-8000-000000000001','d5926000-0000-4000-8000-000000000001')->>'locked','true','closed payroll exposes inclusion as read-only');
SELECT throws_ok($$SELECT public.set_people_payroll_inclusion('d5921000-0000-4000-8000-000000000001','d5926000-0000-4000-8000-000000000001',public.people_payroll_inclusion('d5921000-0000-4000-8000-000000000001','d5926000-0000-4000-8000-000000000001')->>'stamp',false,gen_random_uuid())$$,'23514','payroll_people_correction_required','real finalized financial journey cannot be removed from history by inclusion toggle');
RESET ROLE;
SELECT set_config('test.frozen_opening',(SELECT jsonb_build_object('head',h.id,'revision',h.revision,'data',v.data)::text FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id='d5921000-0000-4000-8000-000000000001' AND h.kind='opening_ytd'),true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_save_input('d5921000-0000-4000-8000-000000000001','d5923000-0000-4000-8000-000000000001','opening_ytd','d5926000-0000-4000-8000-000000000001',NULL,(current_setting('test.frozen_opening')::jsonb->>'head')::uuid,(current_setting('test.frozen_opening')::jsonb->>'revision')::integer,'2026-01-04',NULL,current_setting('test.frozen_opening')::jsonb->'data','save',gen_random_uuid())$$,'23514','payroll_correction_required','same-date edit cannot alter frozen opening');
RESET ROLE;
SELECT * FROM finish();ROLLBACK;
