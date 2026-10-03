import fs from 'node:fs';
const ownDb="current_database() <> 'business_platform_cube4_adam_closure_qa'";
let statutory=fs.readFileSync('supabase/tests/cube4_payroll_independent_statutory_packs.test.sql','utf8');
statutory=statutory.slice(0,statutory.indexOf("SELECT set_config('test.same_pack'"));
statutory=statutory.replace("current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa')",ownDb);
if(statutory.split("'employer_rate',0").length!==2)throw new Error('Unexpected employer contribution fixture anchor');
statutory=statutory.replace("'employer_rate',0",()=>"'employer_rate',0.15");
statutory+=`
-- Actual private numeric adapter → immutable result → payslip projection.
-- Synthetic NONLEGAL schedules; this proves no official legal amounts.
CREATE FUNCTION pg_temp.present(employee jsonb, explanation jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
 SELECT payroll.report_payslip_lines('{}',jsonb_build_object('employees',jsonb_build_array(employee)),
  'c4423000-0000-4000-8000-000000000001',COALESCE(explanation,jsonb_build_object('lines',employee->'lines')))
$$;
CREATE TEMP TABLE calculated AS SELECT payroll.calculate_statutory_employee(pg_temp.employee(),
 pg_temp.pack('TAX-2030','2030-01-01','2031-01-01'),pg_temp.facts(),
 pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance()) employee;
SELECT is(pg_temp.present(employee)->>'complete','true','generated statutory lines have complete versioned presentation') FROM calculated;
SELECT is(jsonb_array_length(pg_temp.present(employee)->'lines'),3,'base plus employee insurance plus tax only') FROM calculated;
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.present(employee)->'lines') line WHERE line->>'classification'='employer_cost'),'employer contributions are excluded from employee deductions') FROM calculated;
SELECT is((employee->>'net')::numeric,70::numeric,'presentation contract leaves synthetic net unchanged') FROM calculated;
SELECT is((employee->>'statutory_contributions')::numeric,15::numeric,'positive employer contribution remains a distinct own cost') FROM calculated;
SELECT is((employee->>'total_employer_cost')::numeric,115::numeric,'gross and positive employer cost reconcile without reducing net') FROM calculated;
SELECT is((SELECT sum((line->>'amount')::numeric) FROM jsonb_array_elements(pg_temp.present(employee)->'lines') line WHERE line->>'classification'='deduction'),30::numeric,'employee deductions exclude positive employer contribution15') FROM calculated;
SELECT is(employee->>'financially_qualified','false','presentation does not qualify legal calculation') FROM calculated;
SELECT is(pg_temp.present(employee #- '{lines,1,presentation}')->>'complete','false','historical statutory output without metadata remains blocked') FROM calculated;
SELECT is(pg_temp.present(jsonb_set(employee,'{lines,3,presentation,schema}','"unknown"'))->>'complete','false','unknown presentation schema is blocked') FROM calculated;
SELECT is(pg_temp.present(jsonb_set(employee,'{lines,3,presentation,pack_id}','"00000000-0000-0000-0000-000000000000"'))->>'complete','false','wrong saved tax pack cannot supply metadata') FROM calculated;
SELECT is(pg_temp.present(employee,jsonb_build_object('lines',jsonb_set(employee->'lines','{3,amount}','"123.45"')))->>'complete','false','explanation cannot substitute a different amount') FROM calculated;
SELECT is(pg_temp.present(jsonb_set(employee,'{employment_id}','"c4423000-0000-4000-8000-000000000002"'))->>'complete','false','a different employee cannot supply statutory metadata') FROM calculated;
CREATE TEMP TABLE zero_tax AS SELECT payroll.calculate_statutory_employee(pg_temp.employee(),
 pg_temp.pack('TAX-ZERO','2030-01-01','2031-01-01'),pg_temp.facts()||'{"current_taxable_earnings":0}',
 pg_temp.pack('INS-2029','2029-01-01','2030-01-01'),pg_temp.insurance()) employee;
SELECT is(pg_temp.present(employee)->>'complete','true','zero tax has complete metadata') FROM zero_tax;
SELECT is((pg_temp.present(employee)->'lines'->2->>'amount')::numeric,0::numeric,'zero tax remains visible and explicit') FROM zero_tax;
SELECT * FROM finish();
ROLLBACK;
`;
fs.writeFileSync('supabase/tests/cube4_statutory_payslip_contract.test.sql',statutory);
let leave=fs.readFileSync('supabase/tests/cube4_payroll_final_source_bindings_leave.test.sql','utf8');
leave=leave.slice(0,leave.indexOf('-- A fresh authenticated calculation'));
leave=leave.replace("current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa')",ownDb);
const payableAnchor=",'{}','{}','{}',0);";
if(leave.split(payableAnchor).length!==2)throw new Error('Unexpected NONLEGAL finalized payable fixture');
leave=leave.replace(payableAnchor,()=>",'{}','{}','{}',100);");
const permissionAnchor="'payroll.correct','payroll_config.manage'";
if(leave.split(permissionAnchor).length!==2)throw new Error('Unexpected source actor permissions fixture');
leave=leave.replace(permissionAnchor,()=>"'payroll.correct','payroll.payment_record','payroll_config.manage'");
// Reuse the existing public producer fixture, without repeating its old assertions.
leave=leave.split('\n').filter(line=>!/^SELECT (is|ok|throws_ok)\(/.test(line)).join('\n');
leave+=`
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),1::bigint,'old public cancellation has one responsibility');
-- The starting final output is an explicit NONLEGAL seed, not a public lock.
-- Financial closure itself uses actual public payment/correction/settlement
-- commands. No privileged completed marker substitutes for that lifecycle.
SELECT set_config('test.cancel_requirement',(SELECT requirement_id::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
INSERT INTO payroll.correction_requirements(tenant_id,employer_id,id,employment_id,period_id,reason,requested_by)
VALUES('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260ff00-0000-4000-8000-000000000001','d2606000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001','Independent sibling responsibility','d2600000-0000-4000-8000-000000000001');
SELECT set_config('test.original_binding_digest',(SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.original_output_digest',(SELECT md5(jsonb_agg(to_jsonb(employee) ORDER BY employment_id)::text) FROM payroll.final_employees employee WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT public.payroll_record_payment('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',0,'allocations',CURRENT_DATE,'NONLEGAL initial payment','Actual public recorded-payment fixture','[{"employment_id":"d2606000-0000-4000-8000-000000000001","amount":"1"}]',NULL,true,gen_random_uuid());
RESET ROLE;
SELECT set_config('test.change',(SELECT jsonb_build_array(jsonb_build_object('type','source_change','source_id',id,'expected_hash',current_lineage_fingerprint,'fields','{}'::jsonb))::text FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),true);
SELECT set_config('test.rows','[{"output_id":"d2610000-0000-4000-8000-000000000001","employment_id":"d2606000-0000-4000-8000-000000000001","basis":"external_reviewed","amount":"10","source":"NONLEGAL reviewed cancellation liability","reference":"NONLEGAL closure evidence"}]',true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.preview',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review actual cancelled Leave source','Closure source evidence',NULL,'preview',gen_random_uuid())::text,true);
SELECT set_config('test.case',public.payroll_correction_proposal('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d2610000-0000-4000-8000-000000000001',NULL,0,current_setting('test.change')::jsonb,current_setting('test.rows')::jsonb,NULL,'Review actual cancelled Leave source','Closure source evidence',current_setting('test.preview')::jsonb->>'preview_hash','save',gen_random_uuid())->>'case_id',true);
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,1,'approve','Approve exact selected cancellation responsibility',gen_random_uuid());
SELECT public.payroll_correction_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,2,'route_paid','Route reviewed external settlement',gen_random_uuid());
SELECT public.payroll_correction_settlement('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001',current_setting('test.case')::uuid,3,'d2606000-0000-4000-8000-000000000001','employee_extra_payment',10,CURRENT_DATE,'NONLEGAL actual closure evidence','Actual public evidence of reviewed settlement',gen_random_uuid());
RESET ROLE;
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'completed','old cancellation liability is financially closed through public commands');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'=current_setting('test.cancel_requirement')),'completed exact cancellation no longer blocks the current manifest');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001')->'corrections') requirement WHERE requirement->>'id'='d260ff00-0000-4000-8000-000000000001'),'unselected sibling remains open after actual financial closure');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000002',true);
SELECT set_config('test.new_request',public.leave_submit_own_request('d2601000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,'2025-01-05','2025-01-05',false,NULL,'Different historical Leave request','closure-new-request')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d2600000-0000-4000-8000-000000000001',true);
SELECT throws_ok($q$SELECT public.leave_approve_request('d2601000-0000-4000-8000-000000000001',current_setting('test.new_request')::uuid,1,1,'New request cannot borrow old binding','closure-new-approve')$q$,
 '23514','payroll_locked_leave_addition_requires_correction','different same-day request cannot borrow the cancelled binding');
RESET ROLE;
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=current_setting('test.new_request')::uuid),'submitted','refused new approval rolls back its state');
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),1::bigint,'refusal preserves old responsibility without creating false resolution');
SELECT is((SELECT source_identity->>'request_id' FROM payroll.final_source_bindings WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND source_domain='leave'),current_setting('test.request'),'original final binding is unchanged');
SELECT is((SELECT status FROM payroll.correction_cases WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND id=current_setting('test.case')::uuid),'completed','new refusal does not reopen or reuse the completed cancellation case');
SELECT ok(NOT EXISTS(SELECT 1 FROM payroll.correction_request_links WHERE tenant_id='d2601000-0000-4000-8000-000000000001' AND request_id='d260ff00-0000-4000-8000-000000000001'),'new refusal does not link away the independent sibling');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(binding) ORDER BY source_key)::text) FROM payroll.final_source_bindings binding WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_binding_digest'),'all original source binding bytes remain unchanged');
SELECT is((SELECT md5(jsonb_agg(to_jsonb(employee) ORDER BY employment_id)::text) FROM payroll.final_employees employee WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),current_setting('test.original_output_digest'),'original final employee output is unchanged');
SELECT * FROM finish();
ROLLBACK;
`;
fs.writeFileSync('supabase/tests/cube4_leave_request_identity.test.sql',leave);
