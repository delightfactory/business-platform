-- Actual public save/approve/calculate candidate with NONLEGAL private pack.
-- Explicit NONLEGAL facts below exercise composition, not official treatment,
-- legal tax duration, insurance month ownership or public finalization.
SELECT set_config('test.actual.original',pg_temp.employee()::text,true);
CREATE FUNCTION pg_temp.actual_facts() RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('prior_net_income',0,'current_taxable_earnings',
  (pg_temp.employee()->'statutory_sources'->'current_earnings'->>'base_amount')::numeric+
  (pg_temp.employee()->'statutory_sources'->'current_earnings'->>'declared_taxable_components')::numeric,
  'cumulative_duration_days',30,'prior_tax_due',0,'earning_from','2030-01-25',
  'earning_until','2030-02-24','tax_treatment_code','01','source_reference','NONLEGAL explicit composition facts',
  'insurance_status','not_insured','insurance_exclusion_reference','NONLEGAL explicit exclusion') $$;
CREATE FUNCTION pg_temp.actual_calc(e jsonb DEFAULT '{}', f jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $$
 SELECT payroll.calculate_statutory_employee(pg_temp.employee()||e,pg_temp.pack(),pg_temp.actual_facts()||f,NULL) $$;
SELECT is((pg_temp.actual_calc()->>'gross')::numeric,840::numeric,'actual saved gross is preserved in composed result');
SELECT is((pg_temp.actual_calc()->'statutory_calculation'->'facts'->>'current_taxable_earnings')::numeric,540::numeric,'NONLEGAL facts exercise actual500 base plus40 declared component');
SELECT is((pg_temp.actual_calc()->'statutory_calculation'->'tax'->>'cumulative_tax_due')::numeric,161.5::numeric,'actual operational sources reach cumulative tax arithmetic');
SELECT is((pg_temp.actual_calc()->>'net')::numeric,678.5::numeric,'actual gross minus composed NONLEGAL tax reconciles');
SELECT is((pg_temp.actual_calc('{}','{"prior_tax_due":200}')->>'net')::numeric,878.5::numeric,'signed tax refund reaches actual-source result');
SELECT is((pg_temp.actual_calc()->>'employer_cost')::numeric,0::numeric,'explicit exclusion does not invent employer contributions');
SELECT is(pg_temp.actual_calc()->'lines'->0,pg_temp.employee()->'lines'->0,'original exact source line is unchanged');
SELECT is(pg_temp.actual_calc()->'statutory_sources',pg_temp.employee()->'statutory_sources','source identities and unresolved context are retained');
SELECT is(pg_temp.employee(),current_setting('test.actual.original')::jsonb,'private composition never rewrites the saved candidate');
SELECT is(pg_temp.employee()->>'net',NULL::text,'actual public candidate net stays unavailable');
SELECT is((pg_temp.actual_calc()->>'financially_qualified')::boolean,false,'numeric composition never claims legal qualification');
SELECT throws_ok($$SELECT pg_temp.actual_calc('{"gross":"840.001"}')$$,'22023','payroll_statutory_employee_invalid','true fractional cent total rejected');
SELECT throws_ok($$SELECT pg_temp.actual_calc(jsonb_build_object('lines',jsonb_set(jsonb_set(pg_temp.employee()->'lines',ARRAY['0','amount'],to_jsonb(((pg_temp.employee()->'lines'->0->>'amount')::numeric+0.001)::text)),ARRAY['1','amount'],to_jsonb(((pg_temp.employee()->'lines'->1->>'amount')::numeric-0.001)::text))))$$,'22023','payroll_statutory_employee_invalid','fractional cent lines rejected even when gross conservation holds');
SELECT throws_ok($$SELECT pg_temp.actual_calc('{"gross_complete":false}')$$,'22023','payroll_statutory_employee_invalid','incomplete candidate cannot become numeric net');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_statutory_employee(jsonb,uuid,jsonb,jsonb)','EXECUTE'),'actual-source worker remains private');
SELECT * FROM finish();
