import fs from 'node:fs';
let sql=fs.readFileSync('supabase/tests/cube4_historical_leave_addition.test.sql','utf8').replaceAll('\r\n','\n');
const marker="SELECT set_config('test.calendar'";
const cut=sql.indexOf(marker);if(cut<0)throw Error('Unexpected setup fixture');
sql=sql.slice(0,cut).replace("ARRAY['hr.people','hr.payroll','hr.leave']","ARRAY['hr.people','hr.payroll']");
sql+=`
-- Actual input/candidate commands; no privately seeded final or readiness flag.
SELECT public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2025-01-05',NULL,'{"mode":"calendar_days","reason":"NONLEGAL accepted operational policy"}','save',gen_random_uuid());
SELECT set_config('test.units',public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','manual_units','d2606000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',NULL,0,'2025-01-05','2025-01-06','{"source":"manual","basis":"approved_payable_total","units":1,"reference":"NONLEGAL daily source","reason":"one reviewed operational unit"}','save',gen_random_uuid())::text,true);
SELECT public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','manual_units','d2606000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.units')::jsonb->>'id')::uuid,1,'2025-01-05','2025-01-06','{"source":"manual","basis":"approved_payable_total","units":1,"reference":"NONLEGAL daily source","reason":"one reviewed operational unit"}','approve',gen_random_uuid());
SELECT public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','opening_ytd','d2606000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-01-05',NULL,'{"year":2025,"taxable_earnings":0,"tax_withheld":0,"tax_due":0,"tax_net_income":0,"social_base":0,"employee_social":0,"employer_social":0,"coverage_start":"2025-01-01","coverage_end":"2025-01-04","tax_duration_days":4,"reference":"NONLEGAL opening facts","reason":"reviewed zero opening source"}','save',gen_random_uuid());
SELECT set_config('test.context_data','{"tax_treatment_code":"01","insurance_status":"not_insured","reference":"NONLEGAL explicit exclusion and duration","reason":"reviewed source fact for numeric composition","calculation_from":"2025-01-05","calculation_until":"2025-01-05","tax_duration_days":1}',true);
SELECT set_config('test.context',public.payroll_save_input('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','statutory_context','d2606000-0000-4000-8000-000000000001',NULL,NULL,0,'2025-01-05',NULL,current_setting('test.context_data')::jsonb,'save',gen_random_uuid())::text,true);
SELECT set_config('test.run',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',NULL,0,'calculate','NONLEGAL no pack negative',gen_random_uuid())::text,true);
RESET ROLE;
SELECT ok((SELECT output->>'net' IS NULL FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'absent pack cannot produce statutory net');
SELECT ok((SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(output->'issues') issue WHERE issue->>'code'='statutory_composition_pack_missing_or_ambiguous') FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'missing pack is an explicit composition blocker');
CREATE FUNCTION pg_temp.pack(p_from date,p_until date) RETURNS uuid LANGUAGE plpgsql AS $$ DECLARE result uuid;BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
 VALUES('EG','egypt_payroll','NONLEGAL composition fixture',p_from,p_until,'["NONLEGAL source"]','{"numeric_comparisons":["NONLEGAL math only"]}','verified','d2600000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',
 '{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":0,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}','{}',
 '{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}') RETURNING id INTO result;RETURN result;END $$;
SELECT pg_temp.pack('2024-01-01','2025-01-01');
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,1,'calculate','NONLEGAL expired pack negative',gen_random_uuid())::text,true);
RESET ROLE;
SELECT ok((SELECT output->>'net' IS NULL FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'expired pack cannot calculate current context');
SELECT set_config('test.tax_pack',pg_temp.pack('2025-01-01','2026-01-01')::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',public.payroll_run_command('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,2,'calculate','NONLEGAL bound general calculation',gen_random_uuid())::text,true);
RESET ROLE;
CREATE TEMP TABLE computed AS SELECT * FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid;
SELECT is((output->>'gross')::numeric,125::numeric,'actual general calculation computes operational daily gross') FROM computed;
SELECT is((output->>'net')::numeric,112.50::numeric,'actual general calculation now composes nonlegal statutory net') FROM computed;
SELECT is((output->>'statutory_deductions')::numeric,12.50::numeric,'root statutory deduction reconciles employee result') FROM computed;
SELECT is(output->'employees'->0->'statutory_calculation'->'facts'->'cumulative_duration_days','5'::jsonb,'explicit current duration adds to reviewed opening duration') FROM computed;
SELECT is(output->'employees'->0->'statutory_calculation'->'facts'->'prior_net_income','0'::jsonb,'reviewed opening net is bound without inferred deductions') FROM computed;
SELECT is(output->'employees'->0->'statutory_calculation'->>'pack_id',current_setting('test.tax_pack'),'exact manifest pack supplies actual worker') FROM computed;
SELECT is(output->'employees'->0->'statutory_source_binding'->>'context_version_id',(SELECT version.id::text FROM payroll.input_versions version WHERE version.head_id=(current_setting('test.context')::jsonb->>'id')::uuid AND version.revision=1),'exact immutable context version is retained') FROM computed;
SELECT is(output->>'financially_qualified','false','synthetic numeric composition cannot qualify money') FROM computed;
SELECT is(payroll.approval_readiness(jsonb_populate_record(NULL::payroll.candidates,to_jsonb(computed)))->>'ready','false','tax arithmetic success is not complete payroll qualification') FROM computed;
SET LOCAL ROLE authenticated;
SELECT throws_ok($q$SELECT public.payroll_candidate_approval('d2601000-0000-4000-8000-000000000001','d2603000-0000-4000-8000-000000000001','d260e000-0000-4000-8000-000000000001',(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'candidate_id')::uuid,3,'approve','NONLEGAL must remain blocked',gen_random_uuid())$q$,'23514','payroll_approval_blocked','public approval refuses nonlegal composition');
RESET ROLE;
-- A compiler-boundary negative uses the actual full general calculator on a
-- deliberately mismatched manifest; it is not a public source-write claim.
CREATE TEMP TABLE mismatched AS SELECT payroll.build_review(jsonb_set(input_manifest,
 ARRAY['inputs',(SELECT (ordinal-1)::text FROM jsonb_array_elements(input_manifest->'inputs') WITH ORDINALITY item(value,ordinal) WHERE value->'head'->>'kind'='statutory_context'),'version','data','calculation_until'],'"2025-01-06"')) result FROM computed;
SELECT ok(result->>'net' IS NULL,'different dated context cannot reuse declared legal duration') FROM mismatched;
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(result->'issues') issue WHERE issue->>'code'='statutory_composition_context_mismatch'),'mismatched compiler context is an explicit blocker') FROM mismatched;
SELECT is((SELECT output FROM payroll.candidates WHERE id=computed.id),computed.output,'negative compiler context leaves the actual candidate immutable') FROM computed;
SELECT is((SELECT count(*) FROM payroll.final_contexts),0::bigint,'negative qualification writes no final output');
SELECT is((SELECT count(*) FROM payroll.approval_events),0::bigint,'negative qualification writes no approval event');
SELECT ok(NOT has_function_privilege('authenticated','payroll.compose_statutory_review(jsonb,jsonb)','EXECUTE'),'numeric composition remains private');
SELECT * FROM finish();
ROLLBACK;
`;
fs.writeFileSync('supabase/tests/cube4_source_bound_statutory_review.test.sql',sql);
