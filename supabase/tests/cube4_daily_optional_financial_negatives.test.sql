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
VALUES ('d5500000-0000-4000-8000-000000000001','d550-payroll@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('d5500000-0000-4000-8000-000000000002','d550-employee@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d5501000-0000-4000-8000-000000000001','NONLEGAL D440 Leave binding QA','d5500000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES ('d5501000-0000-4000-8000-000000000001','d5502000-0000-4000-8000-000000000001','d550.payroll.leave',1,
 ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','org_context.manage','payroll.review','payroll.export','payroll.view','payroll.prepare','payroll.approve','payroll.lock','payroll.correct','payroll.payment_record','payroll_config.manage','leave.manage','leave.view','leave.approve']),
       ('d5501000-0000-4000-8000-000000000001','d5502000-0000-4000-8000-000000000002','d550.leave.self',1,
 ARRAY['leave.self.request','leave.self.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('d5501000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001'),
       ('d5501000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000002','d5500000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('d5501000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001','d5502000-0000-4000-8000-000000000001'),
       ('d5501000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000002','d5502000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active)
VALUES ('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','NONLEGAL D440 NONLEGAL Employer','NONLEGAL D440 NONLEGAL Employer',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'd5501000-0000-4000-8000-000000000001',x,true,now()-interval '1 minute','d5500000-0000-4000-8000-000000000001','rollback NONLEGAL Leave binding QA'
FROM unnest(ARRAY['hr.people','hr.payroll','hr.attendance']) x;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('d5501000-0000-4000-8000-000000000001','d5504000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','NONLEGAL D440 Site',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('d5501000-0000-4000-8000-000000000001','d5505000-0000-4000-8000-000000000001','NONLEGAL D440','NONLEGAL D440 Leave Employee','d5500000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('d5501000-0000-4000-8000-000000000001','d5506000-0000-4000-8000-000000000001','d5505000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','2026-01-04','active','daily');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('d5501000-0000-4000-8000-000000000001','d5505000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000002','d5500000-0000-4000-8000-000000000001');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
VALUES ('d5501000-0000-4000-8000-000000000001','d5507000-0000-4000-8000-000000000001','d5506000-0000-4000-8000-000000000001',125,'2026-01-04');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version) VALUES('d5501000-0000-4000-8000-000000000001','d5508000-0000-4000-8000-000000000001','D240-POLICY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by) VALUES('d5501000-0000-4000-8000-000000000001','d5508000-0000-4000-8000-000000000001',1,'D240 policy','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','d5500000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from) VALUES('d5501000-0000-4000-8000-000000000001','d5509000-0000-4000-8000-000000000001','d5506000-0000-4000-8000-000000000001','d5504000-0000-4000-8000-000000000001','d5508000-0000-4000-8000-000000000001',1,'2026-01-04');
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,expected_start,expected_end,attribution_start,attribution_end,status,created_by) VALUES('d5501000-0000-4000-8000-000000000001','d550a000-0000-4000-8000-000000000001','d5509000-0000-4000-8000-000000000001','d5506000-0000-4000-8000-000000000001','d5505000-0000-4000-8000-000000000001','d5504000-0000-4000-8000-000000000001','2026-01-04','d5508000-0000-4000-8000-000000000001',1,'UTC','2026-01-04 08:00+00','2026-01-04 16:00+00','2026-01-04 06:00+00','2026-01-04 22:00+00','approved','d5500000-0000-4000-8000-000000000001');
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by) VALUES('d5501000-0000-4000-8000-000000000001','d550b000-0000-4000-8000-000000000001','d550a000-0000-4000-8000-000000000001',1,'ready',time.work_instance_interpretation_fingerprint('d5501000-0000-4000-8000-000000000001','d550a000-0000-4000-8000-000000000001'),'d5500000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id) VALUES('d5501000-0000-4000-8000-000000000001','d550c000-0000-4000-8000-000000000001','d550a000-0000-4000-8000-000000000001',1,'d550b000-0000-4000-8000-000000000001','{"outcome":"worked","worked_minutes":480,"absence_units":0,"leave_units":0,"leave_sources":[]}', 'd5500000-0000-4000-8000-000000000001');

INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
VALUES ('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001',1);
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
VALUES ('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','d550d000-0000-4000-8000-000000000001',1,'2026-01-04',NULL,31,'ending','UTC','d5500000-0000-4000-8000-000000000001','NONLEGAL D440 rollback calendar');
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
VALUES ('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','d550e000-0000-4000-8000-000000000001','d550d000-0000-4000-8000-000000000001','2026-01-04','2026-01-04','2026-01-04','UTC','NONLEGAL D440 one-day NONLEGAL Leave QA',false,'d5500000-0000-4000-8000-000000000001');


INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
VALUES('d550f000-0000-4000-8000-000000000001','EG','egypt_payroll','NONLEGAL single-band arithmetic fixture','2026-01-01','2027-01-01','["NONLEGAL synthetic arithmetic"]','{"numeric_comparisons":["NONLEGAL isolated math only"]}','verified','d5500000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
'{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}','{}',
'{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}');
SELECT is(payroll.issued_tax_qualification('d550f000-0000-4000-8000-000000000001','2026-01-04','2026-01-04')->>'ready','false','real production issuer rejects synthetic pack; no official evidence is fabricated');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d5500000-0000-4000-8000-000000000001',true);
SELECT public.payroll_save_input('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2026-01-04',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted monthly policy"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','opening_ytd','d5506000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-01-04',NULL,'{"year":2026,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2026-01-01","coverage_end":"2026-01-03","tax_duration_days":0,"reference":"NONLEGAL no prior employment facts","reason":"Synthetic reviewed zero opening"}','save',gen_random_uuid());
SELECT public.payroll_save_input('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','statutory_context','d5506000-0000-4000-8000-000000000001',NULL,NULL,0,'2026-01-04',NULL,'{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL reviewed uninsured exclusion","reason":"Synthetic source facts only","calculation_from":"2026-01-04","calculation_until":"2026-01-04","tax_duration_days":1}','save',gen_random_uuid());
SELECT set_config('test.run',public.payroll_run_command('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','d550e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL actual issuer negative',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'false','actual calculation remains legally closed without real issuer evidence');
-- ONLY the external evidence supplier is simulated inside this isolated test
-- transaction. It carries no official origin, expected-result or legal claim.
-- Actual producer, source/profile checks, arithmetic, auth and public commands
-- remain unchanged. ROLLBACK restores the real supplier and all business data.
CREATE OR REPLACE FUNCTION payroll.issued_tax_qualification(p_pack uuid,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$BEGIN
 IF current_database()<>'business_platform_cube4_adam_positive_qa' OR p_pack<>'d550f000-0000-4000-8000-000000000001' OR p_from<'2026-01-01' OR p_until>='2027-01-01' THEN
  RETURN jsonb_build_object('ready',false,'reason','synthetic_fixture_scope_refused');END IF;
 RETURN jsonb_build_object('ready',true,'scope','synthetic_external_evidence_contract','origin','synthetic_nonlegal','pack_id',p_pack,'reference','NONLEGAL test double; NOT an official issuer acceptance');END$$;
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d5501000-0000-4000-8000-000000000001','d5503000-0000-4000-8000-000000000001','d550e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'calculate','NONLEGAL positive implementation journey',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((SELECT (output->>'gross')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),125::numeric,'actual exhaustive current Time produces125 from its dated daily rate');
SELECT is((SELECT (output->>'net')::numeric FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),112.5::numeric,'actual tax composition reconciles synthetic net');
SELECT is((SELECT output->>'financially_qualified' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'true','actual profile producer qualifies only after simulated external evidence prerequisite');
SELECT is((SELECT output->'employees'->0->'financial_qualification'->'tax_evidence'->>'origin' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'synthetic_nonlegal','candidate retains explicit synthetic evidence boundary');
SELECT set_config('test.base_manifest',(SELECT input_manifest::text FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),true);
SELECT set_config('test.coverage_missing',payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,coverage,items}','[]'))::text,true);
SELECT is(current_setting('test.coverage_missing')::jsonb->>'financially_qualified','false','missing expected grid cannot be financially qualified');
SELECT is(current_setting('test.coverage_missing')::jsonb->'employees'->0->>'net',NULL::text,'missing expected grid exposes no employee net');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.coverage_missing')::jsonb->'issues') issue WHERE issue->>'code'='source_time_coverage_unqualified'),'missing grid has exact owned source issue');
SELECT set_config('test.ot',payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,items,0,overtime}','[{"minutes":60,"decision":"approved"}]'))::text,true);
SELECT is(current_setting('test.ot')::jsonb->>'financially_qualified','false','unvalued approved overtime cannot release daily base-only financial profile');
SELECT is(current_setting('test.ot')::jsonb->'employees'->0->>'net',NULL::text,'unvalued approved overtime exposes no employee net');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.ot')::jsonb->'issues') issue WHERE issue->>'code'='time_integration_pending'),'unvalued overtime retains owned Time integration blocker');
SELECT is(payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,items,0,overtime}','[{"minutes":60,"decision":"pending"}]'))->>'financially_qualified','false','unreviewed overtime cannot release financial profile');
SELECT is(payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,items,0,overtime}','[{"minutes":60,"decision":"rejected"}]'))->>'financially_qualified','true','explicitly rejected overtime does not create payable earning');
SELECT is(payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,items,0,late_minutes}','5'))->>'financially_qualified','false','unvalued positive lateness remains blocked');
SELECT is(payroll.build_review(jsonb_set(current_setting('test.base_manifest')::jsonb,'{optional_sources,time,items,0,early_leave_minutes}','5'))->>'financially_qualified','false','unvalued positive early leave remains blocked');
SELECT is((SELECT count(*) FROM payroll.final_contexts),0::bigint,'negative source cases and review calculations create no final effect');
SELECT ok(NOT has_function_privilege('authenticated','payroll.daily_optional_financial_profile(jsonb,jsonb)','EXECUTE'),'daily optional financial profile remains private');
SELECT * FROM finish();ROLLBACK;
