-- Actual authenticated earning sources with NONLEGAL governed pack data.
SELECT set_config('test.earning.rules','{"schema":"eg-earning-treatment-v1","base_taxable":true,"component_treatment":"reviewed_dated_declarations","mixed_rounding":"taxable_half_up_cent_remainder_nontaxable"}',true);
CREATE FUNCTION pg_temp.earning_pack(e jsonb DEFAULT NULL,s text DEFAULT 'verified') RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE id uuid;BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules)
 VALUES('EG','egypt_payroll','NONLEGAL-earning-composition','2030-01-01','2031-01-01','["NONLEGAL mathematical fixture"]','{"numeric_comparisons":["NONLEGAL mathematics only"]}',s,'c4420000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',current_setting('test.tax.rules')::jsonb,current_setting('test.insurance.rules')::jsonb,coalesce(e,current_setting('test.earning.rules')::jsonb)) RETURNING statutory_packs.id INTO id;RETURN id;END $$;
CREATE FUNCTION pg_temp.attribution(e jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$ SELECT payroll.resolve_taxable_earnings(coalesce(e,pg_temp.employee()),pg_temp.earning_pack()) $$;
CREATE FUNCTION pg_temp.source_calc() RETURNS jsonb LANGUAGE sql AS $$
 SELECT payroll.calculate_statutory_employee_with_earnings(pg_temp.employee(),pg_temp.earning_pack(),'{"prior_net_income":0,"cumulative_duration_days":30,"prior_tax_due":0,"earning_from":"2030-01-25","earning_until":"2030-02-24","tax_treatment_code":"01","source_reference":"NONLEGAL explicit duration and insurance facts","insurance_status":"not_insured","insurance_exclusion_reference":"NONLEGAL reviewed fixture"}'::jsonb,NULL) $$;
SELECT is((pg_temp.attribution()->>'taxable_earnings')::numeric,540::numeric,'actual uniform sources derive500 base plus40 under explicit NONLEGAL pack');
SELECT is((pg_temp.attribution()->>'nontaxable_earnings')::numeric,300::numeric,'actual declared nontaxable line retains its whole300');
SELECT is((pg_temp.source_calc()->>'net')::numeric,678.5::numeric,'source-derived taxable amount reaches composed numeric worker');
SELECT set_config('test.original.employee',pg_temp.employee()::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.save('component',current_setting('test.component.data')::jsonb||'{"taxable":"true"}',(current_setting('test.component')::jsonb->>'id')::uuid,1,'save','2030-02-01');
SELECT set_config('test.run',public.payroll_run_command('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,(current_setting('test.run')::jsonb->>'id')::uuid,(current_setting('test.run')::jsonb->>'revision')::integer,'calculate','',gen_random_uuid())::text,true);
RESET ROLE;
SELECT is((pg_temp.attribution()->>'taxable_earnings')::numeric,772.26::numeric,'actual mixed recurring taxable24of31 parts rounds once to232.26 plus540');
SELECT is((pg_temp.attribution()->>'nontaxable_earnings')::numeric,67.74::numeric,'complement preserves all original cents');
SELECT is((pg_temp.attribution()->>'taxable_earnings')::numeric+(pg_temp.attribution()->>'nontaxable_earnings')::numeric,840::numeric,'mixed attribution always conserves actual gross840');
SELECT is((pg_temp.source_calc()->>'net')::numeric,609::numeric,'mixed source-derived amount reaches existing cumulative calculation');
SELECT is(pg_temp.source_calc()->'statutory_calculation'->'earning_attribution'->>'pack_version','NONLEGAL-earning-composition','composed explanation retains exact earning pack version');
SELECT is((pg_temp.source_calc()->>'financially_qualified')::boolean,false,'source composition does not claim official readiness');
SELECT is(pg_temp.employee()->>'net',NULL::text,'saved public candidate remains nonfinancial');
SELECT is((current_setting('test.original.employee')::jsonb->>'gross')::numeric,840::numeric,'old saved candidate remains untouched');
CREATE FUNCTION pg_temp.tie(n text DEFAULT '1.000',d text DEFAULT '200.00') RETURNS jsonb LANGUAGE sql AS $$
 SELECT '{"starts_on":"2030-01-25","ends_on":"2030-02-24","gross_complete":true,"gross":"0.01"}'::jsonb||jsonb_build_object('lines',jsonb_build_array(jsonb_build_object('component','NONLEGAL-tie','classification','earning','amount','0.01','details',jsonb_build_array(jsonb_build_object('_numerator',n,'_denominator',d,'declared_taxable',true),jsonb_build_object('_numerator','1','_denominator','200','declared_taxable',false))))) $$;
SELECT is((pg_temp.attribution(pg_temp.tie())->>'taxable_earnings')::numeric,0.01::numeric,'exact half-cent tie with integer zero padding rounds under explicit pack rule');
SELECT is((pg_temp.attribution(pg_temp.tie())->>'nontaxable_earnings')::numeric,0::numeric,'tie residual never creates a second rounded cent');
SELECT throws_ok($$SELECT pg_temp.attribution(pg_temp.tie('1','0'))$$,'22023','payroll_earning_allocation_unknown','zero denominator is not a legal allocation');
SELECT throws_ok($$SELECT pg_temp.attribution(pg_temp.tie('3','200'))$$,'22023','payroll_earning_source_mismatch','exact source total cannot disagree with saved line');
SELECT throws_ok($$SELECT payroll.resolve_taxable_earnings(pg_temp.employee(),pg_temp.earning_pack('{}'))$$,'22023','payroll_earning_rules_unqualified','no default base taxability or rounding is invented');
SELECT throws_ok($$SELECT payroll.resolve_taxable_earnings(pg_temp.employee(),pg_temp.earning_pack(NULL,'unqualified'))$$,'22023','payroll_statutory_pack_unqualified','unqualified pack cannot authorize treatment');
SELECT throws_ok($$SELECT payroll.calculate_statutory_employee_with_earnings(pg_temp.employee(),pg_temp.earning_pack(),'{"current_taxable_earnings":1}',NULL)$$,'22023','payroll_statutory_employee_invalid','caller cannot override source-derived taxable amount');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_statutory_employee_with_earnings(jsonb,uuid,jsonb,jsonb)','EXECUTE'),'source composition remains private');
SELECT * FROM finish();
