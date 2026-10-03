-- Actual candidate composition plus bounded NONLEGAL arithmetic/lineage cases.
CREATE FUNCTION pg_temp.balance() RETURNS jsonb LANGUAGE sql AS $f$ SELECT pg_temp.employee()->'statutory_sources'->'cumulative_balances'->'years'->0 $f$;
CREATE FUNCTION pg_temp.sources() RETURNS jsonb LANGUAGE sql AS $f$ SELECT pg_temp.employee()->'statutory_sources' $f$;
SELECT is(pg_temp.balance()->'prior_net_income','null'::jsonb,'missing prior source never becomes zero');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd','{"tax_net_income":"-1"}')$$,'22023','payroll_invalid','negative opening net rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd','{"tax_net_income":"1.001"}')$$,'22023','payroll_invalid','subcent opening net rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd','{"tax_net_income":null}')$$,'22023','payroll_invalid','null opening net is not reviewed zero');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd','{"tax_net_income":"101","taxable_earnings":"100"}')$$,'22023','payroll_invalid','opening net cannot exceed prior taxable earnings');
SET LOCAL ROLE authenticated;
SELECT public.payroll_save_input('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','opening_ytd','c4425000-0000-4000-8000-000000000001',NULL,NULL,0,'2030-01-25',NULL,
 '{"year":"2030","taxable_earnings":"1000","tax_net_income":"100","tax_withheld":"3","tax_due":"10","social_base":"1000","employee_social":"100","employer_social":"200","coverage_start":"2030-01-01","coverage_end":"2030-01-10","tax_duration_days":"16","reference":"NONLEGAL reviewed opening source","reason":"Explicit prior net not all social deductions"}','save',gen_random_uuid());
SELECT set_config('test.run',pg_temp.recalculate()::text,true);
RESET ROLE;
SELECT is(pg_temp.balance()->>'known','false','uncovered prior earning interval remains unknown');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(pg_temp.employee()->'issues')i WHERE i->>'code'='prior_ytd_coverage_gap'),'actual candidate owns prior coverage gap');
SELECT set_config('test.first.output',pg_temp.prior_output('2030-01-11','2030-01-24')::text,true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.run',pg_temp.recalculate()::text,true);
RESET ROLE;
SELECT is(pg_temp.balance()->>'known','true','actual prior final and reviewed opening resolve cumulative source');
SELECT is(pg_temp.balance()->>'basis','locked_cumulative_result','actual candidate uses authoritative cumulative result');
SELECT is((pg_temp.balance()->>'prior_net_income')::numeric,595::numeric,'prior100 plus current500 minus deductible5; no second subtraction of total social');
SELECT is((pg_temp.balance()->>'prior_tax_due')::numeric,25::numeric,'use cumulative due25, not prior10 plus25 or cash withheld3');
SELECT is((pg_temp.balance()->>'prior_duration_days')::numeric,30::numeric,'use cumulative duration30, not opening16 plus30');
SELECT is(pg_temp.balance()->'source_ids',jsonb_build_array(current_setting('test.first.output')),'balance keeps exact immutable output lineage');
SELECT is(pg_temp.employee()->>'net',NULL::text,'real balance composition does not activate unqualified legal net');
SELECT set_config('test.good.employee',pg_temp.employee()::text,true);
SELECT set_config('test.good.sources',pg_temp.sources()::text,true);
-- Two consecutive cumulative outputs, mathematically distinct synthetic values.
SELECT set_config('test.second.source',(jsonb_set(jsonb_set(jsonb_set(pg_temp.sources()->'prior_outputs'->0,
 '{statutory_calculation,facts}','{"prior_net_income":595,"current_taxable_earnings":400,"prior_tax_due":25,"cumulative_duration_days":60,"insurance_status":"insured","earning_from":"2030-01-25","earning_until":"2030-02-24"}'),
 '{statutory_calculation,tax}','{"prior_tax_due":25,"cumulative_tax_due":70,"current_tax_delta":45,"duration_days":60,"earning_from":"2030-01-25","earning_until":"2030-02-24"}'),
 '{statutory_calculation,insurance}','{"employee_total":20,"employer_total":30,"tax_deductible_employee_total":20}')||'{"starts_on":"2030-01-25","ends_on":"2030-02-24","output_id":"c4429900-0000-4000-8000-000000000001"}')::text,true);
SELECT set_config('test.next.employee',(pg_temp.employee()||'{"starts_on":"2030-02-25","ends_on":"2030-03-24"}')::text,true);
SELECT set_config('test.chain.sources',(pg_temp.sources()||jsonb_build_object('prior_outputs',(pg_temp.sources()->'prior_outputs')||jsonb_build_array(current_setting('test.second.source')::jsonb)))::text,true);
CREATE FUNCTION pg_temp.chain() RETURNS jsonb LANGUAGE sql AS $f$ SELECT payroll.employee_cumulative_balances(current_setting('test.chain.sources')::jsonb,current_setting('test.next.employee')::jsonb) $f$;
SELECT is((pg_temp.chain()->'years'->0->>'prior_net_income')::numeric,975::numeric,'two-result chain carries595 then adds only current400 minus20');
SELECT is((pg_temp.chain()->'years'->0->>'prior_tax_due')::numeric,70::numeric,'two cumulative due results are not added to95');
SELECT is((pg_temp.chain()->'years'->0->>'prior_duration_days')::numeric,60::numeric,'two cumulative durations are not added to90');
SELECT is(jsonb_array_length(pg_temp.chain()->'years'->0->'source_ids'),2,'both exact prior outputs remain attributable');
SELECT is(payroll.employee_cumulative_balances(jsonb_set(jsonb_set(current_setting('test.chain.sources')::jsonb,'{prior_outputs,0,statutory_calculation,facts,earning_until}','"2030-01-20"'),'{prior_outputs,0,statutory_calculation,tax,earning_until}','"2030-01-20"'),current_setting('test.next.employee')::jsonb)->'years'->0->>'known','false','uncovered interval between otherwise matching prior results remains unknown');
SELECT is(payroll.employee_cumulative_balances(pg_temp.sources()||jsonb_build_object('issues',jsonb_build_array(payroll.issue('opening_ytd_ambiguous',(pg_temp.employee()->>'employment_id')::uuid,'payroll_ytd'))),pg_temp.employee())->'years'->0->>'known','false','unresolved opening ambiguity is not waived by latest prior result');
SELECT is(payroll.employee_cumulative_balances(jsonb_set(current_setting('test.chain.sources')::jsonb,'{prior_outputs,1,statutory_calculation,facts,prior_net_income}','596'),current_setting('test.next.employee')::jsonb)->'years'->0->>'known','false','broken prior net lineage blocks cumulative balance');
SELECT is(payroll.employee_cumulative_balances(jsonb_set(current_setting('test.chain.sources')::jsonb,'{prior_outputs,1,statutory_calculation,tax,duration_days}','30'),current_setting('test.next.employee')::jsonb)->'years'->0->'prior_net_income','null'::jsonb,'inconsistent duration never emits a partial authoritative balance');
SELECT is(payroll.employee_cumulative_balances(jsonb_set(pg_temp.sources(),'{openings,0,source,version,data,coverage_end}','"2030-01-11"'),pg_temp.employee())->'years'->0->>'known','false','opening overlapping authoritative prior earning interval blocks double counting');
SELECT is(payroll.employee_cumulative_balances(jsonb_set(pg_temp.sources(),'{openings,0,source,version,data,tax_net_income}','"101"'),pg_temp.employee())->'years'->0->>'known','false','changed opening income conflicting with locked baseline requires review');
SELECT set_config('test.opening.only',(jsonb_set(pg_temp.sources(),'{prior_outputs}','[]')||jsonb_build_object('openings',jsonb_build_array(jsonb_set(pg_temp.sources()->'openings'->0,'{source,version,data,coverage_end}','"2030-01-24"'))))::text,true);
SELECT is((payroll.employee_cumulative_balances(current_setting('test.opening.only')::jsonb,pg_temp.employee())->'years'->0->>'prior_net_income')::numeric,100::numeric,'opening explicit net100 remains100, not taxable1000 minus employee social100');
SELECT is(payroll.employee_cumulative_balances(jsonb_set(current_setting('test.opening.only')::jsonb,'{openings,0,source,version,data}',(current_setting('test.opening.only')::jsonb->'openings'->0->'source'->'version'->'data')-'tax_net_income'),pg_temp.employee())->'years'->0->>'known','false','legacy positive opening without reviewed net remains unknown');
SELECT is(payroll.employee_cumulative_balances(pg_temp.sources()||'{"prior_outputs":[],"openings":[]}',pg_temp.employee()||'{"starts_on":"2030-01-01","ends_on":"2030-01-24"}')->'years'->0->>'basis','year_start','no prior days in new taxyear resets cumulative source at year boundary');
SELECT is(pg_temp.employee(),current_setting('test.good.employee')::jsonb,'pure lineage cases never rewrite actual candidate');
SELECT ok(NOT has_function_privilege('authenticated','payroll.employee_cumulative_balances(jsonb,jsonb)','EXECUTE'),'cumulative resolver remains private');
SELECT * FROM finish();
