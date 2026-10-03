-- Isolated NONLEGAL mathematical schedules; not current official model comparisons.
SELECT set_config('test.tax.rules','{"schema":"eg-cumulative-tax-v1","tax_treatment_code":"01","day_basis":360,"personal_exemption":20,"base_rounding":"floor10","column_basis":"annual_raw","tax_rounding":"cumulative_half_up_cent","columns":[{"through":1000,"bands":[{"upper":100,"rate":0},{"upper":200,"rate":0.1},{"upper":null,"rate":0.2}]},{"through":null,"bands":[{"upper":null,"rate":0.3}]}]}',true);
CREATE FUNCTION pg_temp.pack(extra jsonb DEFAULT '{}', state_value text DEFAULT 'verified') RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE result uuid;BEGIN
 INSERT INTO payroll.statutory_packs(jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules)
 VALUES('EG','egypt_payroll','NONLEGAL-test','2030-01-01','2031-01-01','["NONLEGAL synthetic arithmetic"]','{"numeric_comparisons":["NONLEGAL derived fixture, not official proof"]}',state_value,'c4420000-0000-4000-8000-000000000001','eg-cumulative-tax-v1',current_setting('test.tax.rules')::jsonb||extra) RETURNING id INTO result;RETURN result;END $$;
CREATE FUNCTION pg_temp.context(n numeric DEFAULT 100,d numeric DEFAULT 30,p numeric DEFAULT 0) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('cumulative_net_before_personal_exemption',n,'cumulative_duration_days',d,'prior_tax_due',p,'earning_from','2030-01-01','earning_until','2030-01-30','tax_treatment_code','01','source_reference','Reviewed isolated source') $$;
CREATE FUNCTION pg_temp.calc(n numeric,d numeric DEFAULT 30,p numeric DEFAULT 0,extra jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $$ SELECT payroll.calculate_cumulative_tax(pg_temp.pack(extra),pg_temp.context(n,d,p)) $$;
SELECT is((pg_temp.calc(0)->>'current_tax_delta')::numeric,0::numeric,'zero income');
SELECT is((pg_temp.calc(10)->>'current_tax_delta')::numeric,0::numeric,'personal exemption applied once before floor');
SELECT is((pg_temp.calc(20)->>'current_tax_delta')::numeric,1.17::numeric,'low income scales cumulative annual tax');
SELECT is((pg_temp.calc(85)->>'current_tax_delta')::numeric,14.17::numeric,'exact income column boundary');
SELECT is((pg_temp.calc(85.01)->>'current_tax_delta')::numeric,25::numeric,'raw column selection before annual floor');
SELECT is((pg_temp.calc(85.01,30,0,'{"column_basis":"annual_floor10"}')->>'current_tax_delta')::numeric,14.17::numeric,'pack explicitly selects rounded column');
SELECT is((pg_temp.calc(510,180,30)->>'current_tax_delta')::numeric,55::numeric,'midyear cumulative less prior due');
SELECT is((pg_temp.calc(1020,360,0)->>'current_tax_delta')::numeric,170::numeric,'full year cumulative');
SELECT is((pg_temp.calc(0,30,2)->>'current_tax_delta')::numeric,-2::numeric,'refund delta remains signed');
SELECT is((pg_temp.calc(100,15.5,0)->>'current_tax_delta')::numeric,29.71::numeric,'fractional source duration not calendar-derived');
SELECT is((pg_temp.calc(100)->>'annual_base')::numeric,1180::numeric,'annual base removes exemption and floors to ten');
SELECT is((pg_temp.calc(85.01)->>'column')::integer,2,'higher income loses lower rate column');
SELECT is((pg_temp.calc(100)->>'pack_version'),'NONLEGAL-test','result snapshots pack version');
SELECT is((pg_temp.calc(100)->>'source_reference'),'Reviewed isolated source','result preserves cumulative provenance');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_cumulative_tax(uuid,jsonb)','EXECUTE'),'ordinary actors cannot call adapter');
SELECT ok(NOT has_function_privilege('service_role','payroll.calculate_cumulative_tax(uuid,jsonb)','EXECUTE'),'service API cannot bypass pack qualification');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(gen_random_uuid(),pg_temp.context())$$,'22023','payroll_statutory_pack_unqualified','missing pack blocked');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{}','unqualified'),pg_temp.context())$$,'22023','payroll_statutory_pack_unqualified','unqualified pack blocked');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"cumulative_duration_days":0}')$$,'22023','payroll_statutory_context_invalid','zero duration rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"cumulative_duration_days":361}')$$,'22023','payroll_statutory_context_invalid','duration beyond tax year rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"prior_tax_due":-1}')$$,'22023','payroll_statutory_context_invalid','negative prior due rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"prior_tax_due":"100"}')$$,'22023','payroll_statutory_context_invalid','string money rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"cumulative_net_before_personal_exemption":null}')$$,'22023','payroll_statutory_context_invalid','unknown income rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"cumulative_net_before_personal_exemption":1.001}')$$,'22023','payroll_statutory_context_invalid','fraction beyond input precision rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"tax_treatment_code":"02"}')$$,'22023','payroll_statutory_context_invalid','unsupported tax treatment rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"source_reference":" "}')$$,'22023','payroll_statutory_context_invalid','missing reviewed provenance rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"tax_withheld":100}')$$,'22023','payroll_statutory_context_invalid','withheld cannot replace prior due rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"earning_until":"2030-02-30"}')$$,'22023','payroll_statutory_context_invalid','nonexistent date rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"earning_until":"infinity"}')$$,'22023','payroll_statutory_context_invalid','special date rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"earning_until":"2031-01-01"}')$$,'22023','payroll_statutory_period_unsupported','cross year blocked');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"earning_from":"2029-12-31"}')$$,'22023','payroll_statutory_period_unsupported','before pack blocked');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack(),pg_temp.context()||'{"earning_until":"2029-12-31"}')$$,'22023','payroll_statutory_period_unsupported','reversed dates blocked');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{"column_basis":null}'),pg_temp.context())$$,'22023','payroll_statutory_rules_invalid','unknown rounding order rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{"day_basis":365}'),pg_temp.context())$$,'22023','payroll_statutory_rules_invalid','unsupported day basis rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{"personal_exemption":-1}'),pg_temp.context())$$,'22023','payroll_statutory_rules_invalid','negative exemption rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{"columns":[]}'),pg_temp.context())$$,'22023','payroll_statutory_rules_invalid','empty columns rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{"columns":[{"through":100,"bands":[{"upper":null,"rate":0.1}]}]}'),pg_temp.context())$$,'22023','payroll_statutory_rules_invalid','missing unlimited final column rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{"columns":[{"through":100,"bands":[{"upper":null,"rate":0.1}]},{"through":100,"bands":[{"upper":null,"rate":0.1}]},{"through":null,"bands":[{"upper":null,"rate":0.1}]}]}'),pg_temp.context())$$,'22023','payroll_statutory_rules_invalid','duplicate column boundary rejected');
SELECT throws_ok($$SELECT payroll.calculate_cumulative_tax(pg_temp.pack('{"columns":[{"through":1000,"bands":[{"upper":null,"rate":0}]},{"through":null,"bands":[{"upper":null,"rate":2}]}]}'),pg_temp.context(0))$$,'22023','payroll_arithmetic_input_invalid','unreached invalid schedule rejected even for zero income');
