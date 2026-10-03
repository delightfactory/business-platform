-- Private NONLEGAL historical output fixtures; public finalization stays gated.
-- Setup prefix supplies one actual authenticated current-period calculation.
CREATE FUNCTION pg_temp.prior_output(a date,b date,qualified boolean DEFAULT true,run_state text DEFAULT 'locked') RETURNS uuid
LANGUAGE plpgsql AS $f$
DECLARE period_id uuid;run_id uuid:=gen_random_uuid();candidate_id uuid:=gen_random_uuid();approval_id uuid:=gen_random_uuid();output_id uuid:=gen_random_uuid();calc jsonb;result jsonb;
BEGIN
 SELECT id INTO period_id FROM payroll.periods WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND employer_id='c4423000-0000-4000-8000-000000000001' AND starts_on=a;
 IF period_id IS NULL THEN
  INSERT INTO payroll.periods(tenant_id,employer_id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
  SELECT tenant_id,employer_id,calendar_version_id,a,b,b,'Africa/Cairo','NONLEGAL prior-source fixture',false,created_by FROM payroll.periods WHERE id=current_setting('test.period')::uuid RETURNING id INTO period_id;
 END IF;
 calc:=jsonb_build_object('adapter','eg-employee-statutory-v1','pack_id','c4439900-0000-4000-8000-000000000001',
  'facts',jsonb_build_object('prior_net_income',100,'current_taxable_earnings',500,'cumulative_duration_days',30,'prior_tax_due',10,'insurance_status','insured','earning_from',a,'earning_until',b),
  'tax',jsonb_build_object('duration_days',30,'prior_tax_due',10,'cumulative_tax_due',25,'current_tax_delta',15,'earning_from',a,'earning_until',b),
  'insurance',jsonb_build_object('employee_total',10,'employer_total',20,'tax_deductible_employee_total',5));
 result:=jsonb_build_object('financially_qualified',qualified,'employees',jsonb_build_array(jsonb_build_object(
  'employment_id','c4425000-0000-4000-8000-000000000001','statutory_calculation',CASE WHEN qualified THEN calc END)));
 IF NOT qualified THEN result:=jsonb_set(result,'{employees}',(result->'employees')||(result->'employees'));END IF;
 INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,revision,status,created_by) VALUES('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',period_id,run_id,2,run_state,'c4420000-0000-4000-8000-000000000001');
 INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',run_id,candidate_id,1,'NONLEGAL-source-test','{}',result,'c4420000-0000-4000-8000-000000000001');
 INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason) VALUES('c4421000-0000-4000-8000-000000000001',approval_id,'c4423000-0000-4000-8000-000000000001',run_id,candidate_id,'approve',1,'c4420000-0000-4000-8000-000000000001','NONLEGAL private source fixture');
 INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
 VALUES('c4421000-0000-4000-8000-000000000001',output_id,'c4423000-0000-4000-8000-000000000001',period_id,run_id,candidate_id,approval_id,'{}',jsonb_build_object('starts_on',a,'ends_on',b),'{}',result,'NONLEGAL-source-test','c4420000-0000-4000-8000-000000000001');
 INSERT INTO payroll.final_employees VALUES('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',output_id,'c4425000-0000-4000-8000-000000000001','{}','{}','{"calendar_year":2030}',100);
 RETURN output_id;
END $f$;
CREATE FUNCTION pg_temp.manifest() RETURNS jsonb LANGUAGE sql AS $f$ SELECT payroll.run_manifest('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid) $f$;
CREATE FUNCTION pg_temp.recalculate() RETURNS jsonb LANGUAGE sql AS $f$ SELECT public.payroll_run_command('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'revision')::integer,'calculate','',gen_random_uuid()) $f$;
GRANT EXECUTE ON FUNCTION pg_temp.recalculate() TO authenticated;
SELECT set_config('test.before.manifest',pg_temp.manifest()::text,true);
SELECT set_config('test.before.employee',pg_temp.employee()::text,true);
SELECT is(pg_temp.manifest()->'prior_statutory_outputs','[]'::jsonb,'actual initial manifest has explicit empty prior-output set');
SELECT set_config('test.original',pg_temp.prior_output('2030-01-11','2030-01-24',true,'superseded')::text,true);
SELECT set_config('test.replacement',pg_temp.prior_output('2030-01-11','2030-01-24')::text,true);
INSERT INTO payroll.output_successions VALUES('c4421000-0000-4000-8000-000000000001',current_setting('test.original')::uuid,current_setting('test.replacement')::uuid,'c4420000-0000-4000-8000-000000000001','NONLEGAL output lineage fixture',now());
SELECT pg_temp.prior_output('2029-12-01','2029-12-24');
SELECT pg_temp.prior_output('2030-02-25','2030-03-24');
SELECT is(jsonb_array_length(pg_temp.manifest()->'prior_statutory_outputs'),1,'exclude earlier-year future and replaced historical outputs');
SELECT is(pg_temp.manifest()->'prior_statutory_outputs'->0->>'output_id',current_setting('test.replacement'),'only active replacement source survives');
SELECT is(pg_temp.manifest()->'prior_statutory_outputs'->0->'statutory_calculation'->'tax'->>'cumulative_tax_due','25','retain cumulative due as source, never sum it with prior due');
SELECT ok(payroll.prior_statutory_output_usable(pg_temp.manifest()->'prior_statutory_outputs'->0),'complete structurally consistent synthetic source is admitted');
SELECT ok(NOT payroll.prior_statutory_output_usable(jsonb_set(pg_temp.manifest()->'prior_statutory_outputs'->0,'{statutory_calculation}','{"adapter":"eg-employee-statutory-v1"}')),'adapter label alone cannot qualify missing prior facts');
SELECT ok(NOT payroll.prior_statutory_output_usable(jsonb_set(pg_temp.manifest()->'prior_statutory_outputs'->0,'{statutory_context,calendar_year}','2029')),'contradictory prior taxyear cannot qualify');
SELECT ok(NOT payroll.prior_statutory_output_usable(jsonb_set(pg_temp.manifest()->'prior_statutory_outputs'->0,'{statutory_calculation,tax,current_tax_delta}','999')),'inconsistent cumulative tax source cannot qualify');
SELECT ok(NOT payroll.prior_statutory_output_usable(jsonb_set(pg_temp.manifest()->'prior_statutory_outputs'->0,'{statutory_calculation,facts,insurance_status}','"not_insured"')),'not-insured prior facts cannot admit positive insurance totals');
SELECT is(payroll.prior_statutory_outputs('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000003','2030-01-25','2030-02-24',ARRAY['c4424000-0000-4000-8000-000000000001'::uuid]),'[]'::jsonb,'other employer cannot capture these sources');
SELECT is(payroll.prior_statutory_outputs('c4421000-0000-4000-8000-000000000002','c4423000-0000-4000-8000-000000000001','2030-01-25','2030-02-24',ARRAY['c4424000-0000-4000-8000-000000000001'::uuid]),'[]'::jsonb,'other tenant cannot capture these sources');
SELECT is(payroll.prior_statutory_outputs('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-25','2030-02-24',ARRAY[gen_random_uuid()]),'[]'::jsonb,'other employee cannot capture these sources');
SELECT ok(payroll.stale_reasons(current_setting('test.before.manifest')::jsonb,pg_temp.manifest()) ? 'prior_statutory_outputs_changed','new authoritative prior output invalidates reviewed YTD context');
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',pg_temp.recalculate()::text,true);
RESET ROLE;
SELECT is(pg_temp.employee()->'statutory_sources'->'prior_outputs'->0->>'output_id',current_setting('test.replacement'),'actual authenticated recalculation freezes employee prior output');
SELECT is(pg_temp.employee()->>'net',NULL::text,'prior-source capture does not invent qualified financial net');
SELECT set_config('test.good.snapshot',pg_temp.employee()::text,true);
SELECT pg_temp.prior_output('2030-01-01','2030-01-10',false);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',pg_temp.recalculate()::text,true);
RESET ROLE;
SELECT is(jsonb_array_length(pg_temp.employee()->'statutory_sources'->'prior_outputs'),2,'unknown prior calculation remains visible rather than silently zero');
SELECT is(pg_temp.employee()->'statutory_sources'->'prior_outputs'->0->>'calculation_count','2','duplicate matching result employees retained as unknown cardinality, not duplicated source rows');
SELECT is(pg_temp.employee()->'statutory_sources'->'prior_outputs'->0->'statutory_calculation','null'::jsonb,'ambiguous prior calculation is not arbitrarily selected');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.employee()->'issues')i WHERE i->>'code'='prior_statutory_context_unqualified'),'actual candidate owns unknown prior statutory source blocker');
SELECT is(current_setting('test.good.snapshot')::jsonb->'statutory_sources'->'prior_outputs'->0->>'output_id',current_setting('test.replacement'),'earlier captured source snapshot remains immutable');
SELECT ok((SELECT engine_version LIKE '%prior-finals-v1' FROM payroll.candidates WHERE id=(current_setting('test.run')::jsonb->>'candidate_id')::uuid),'actual candidate records changed YTD source engine');
SELECT ok(NOT has_function_privilege('authenticated','payroll.prior_statutory_outputs(uuid,uuid,date,date,uuid[])','EXECUTE'),'tenant API role cannot directly inspect private prior outputs');
SELECT * FROM finish();
