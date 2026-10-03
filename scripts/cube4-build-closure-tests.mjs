import fs from 'node:fs';
const ownDb="current_database() <> 'business_platform_cube4_adam_closure_qa'";
let statutory=fs.readFileSync('supabase/tests/cube4_payroll_independent_statutory_packs.test.sql','utf8');
statutory=statutory.slice(0,statutory.indexOf("SELECT set_config('test.same_pack'"));
statutory=statutory.replace("current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa')",ownDb);
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
// Reuse the existing public producer fixture, without repeating its old assertions.
leave=leave.split('\n').filter(line=>!/^SELECT (is|ok|throws_ok)\(/.test(line)).join('\n');
leave+=`
SET CONSTRAINTS ALL IMMEDIATE;
SELECT is((SELECT count(*) FROM payroll.bound_source_correction_observations WHERE tenant_id='d2601000-0000-4000-8000-000000000001'),1::bigint,'old public cancellation has one responsibility');
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
SELECT * FROM finish();
ROLLBACK;
`;
fs.writeFileSync('supabase/tests/cube4_leave_request_identity.test.sql',leave);
