BEGIN;
DO $$ BEGIN
  IF current_database() NOT IN ('business_platform_cube4_upgrade_qa', 'business_platform_cube4_fresh_qa') THEN
    RAISE EXCEPTION 'dedicated Cube4 QA required';
  END IF;
END $$;
SELECT plan(46);
-- Derived mathematical fixtures only: these are NOT official statutory goldens.
CREATE FUNCTION pg_temp.bands() RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT '[{"upper":100,"rate":0},{"upper":200,"rate":0.125},{"upper":null,"rate":0.225}]'::jsonb
$$;
CREATE FUNCTION pg_temp.tax(n numeric) RETURNS numeric LANGUAGE sql AS $$
  SELECT (payroll.progressive_annual_arithmetic(n, pg_temp.bands())->>'unrounded_annual_tax')::numeric
$$;
SELECT is(pg_temp.tax(0), 0::numeric, 'zero base has zero tax');
SELECT is(pg_temp.tax(99.99), 0::numeric, 'zero-rate band preserved');
SELECT is(pg_temp.tax(100), 0::numeric, 'first exact boundary');
SELECT is(pg_temp.tax(100.01), 0.00125::numeric, 'fractional marginal tax is not rounded');
SELECT is(pg_temp.tax(150), 6.25::numeric, 'middle of second band');
SELECT is(pg_temp.tax(200), 12.5::numeric, 'second exact boundary');
SELECT is(pg_temp.tax(200.01), 12.50225::numeric, 'fraction beyond second boundary');
SELECT is(pg_temp.tax(1000), 192.5::numeric, 'unbounded final band');
SELECT is((payroll.progressive_annual_arithmetic(10.000001, '[{"upper":null,"rate":0.123456}]')->>'unrounded_annual_tax')::numeric,
  1.234560123456::numeric, 'exact decimal multiplication with full precision');
SELECT is((payroll.progressive_annual_arithmetic(150, '[{"upper":100,"rate":0.1},{"upper":null,"rate":0.2}]')->>'unrounded_annual_tax')::numeric,
  20::numeric, 'explicit alternate schedule does not acquire a zero band');
SELECT is((payroll.progressive_annual_arithmetic(7.5, '[{"upper":null,"rate":1}]')->>'unrounded_annual_tax')::numeric,
  7.5::numeric, 'rate one accepted');
SELECT is(payroll.progressive_annual_arithmetic(200.01, pg_temp.bands())->'segments',
  '[{"band":1,"lower":0,"upper":100,"rate":0,"taxable_width":100,"unrounded_tax":0},
    {"band":2,"lower":100,"upper":200,"rate":0.125,"taxable_width":100,"unrounded_tax":12.5},
    {"band":3,"lower":200,"upper":null,"rate":0.225,"taxable_width":0.01,"unrounded_tax":0.00225}]'::jsonb,
  'trace proves all marginal widths, rates and amounts');
SELECT is(jsonb_array_length(payroll.progressive_annual_arithmetic(0, pg_temp.bands())->'segments'), 3,
  'zero base still traces entire validated schedule');
SELECT is((payroll.progressive_annual_arithmetic(150, pg_temp.bands())->>'base')::numeric, 150::numeric,
  'base is preserved without automatic exemption or flooring');
SELECT is(payroll.floor_annual_base_to_ten(0), 0::numeric, 'floor zero');
SELECT is(payroll.floor_annual_base_to_ten(9.9999999999999999999999999), 0::numeric, 'floor below ten never rounds up');
SELECT is(payroll.floor_annual_base_to_ten(10), 10::numeric, 'floor exact ten');
SELECT is(payroll.floor_annual_base_to_ten(19.9999999999999999999999999), 10::numeric, 'floor fractional base');
SELECT is(payroll.floor_annual_base_to_ten(123456789012345678901234567899.99),
  123456789012345678901234567890::numeric, 'floor large exact numeric');
SELECT throws_ok($$SELECT pg_temp.tax(NULL)$$, '22023', 'payroll_arithmetic_input_invalid', 'null base rejected');
SELECT throws_ok($$SELECT pg_temp.tax(-1)$$, '22023', 'payroll_arithmetic_input_invalid', 'negative base rejected');
SELECT throws_ok($$SELECT pg_temp.tax('NaN'::numeric)$$, '22023', 'payroll_arithmetic_input_invalid', 'NaN base rejected');
SELECT throws_ok($$SELECT pg_temp.tax('Infinity'::numeric)$$, '22023', 'payroll_arithmetic_input_invalid', 'infinite base rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,NULL)$$, '22023', 'payroll_arithmetic_input_invalid', 'null bands rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'{}')$$, '22023', 'payroll_arithmetic_input_invalid', 'nonarray bands rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[]')$$, '22023', 'payroll_arithmetic_input_invalid', 'empty bands rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[1]')$$, '22023', 'payroll_arithmetic_input_invalid', 'nonobject band rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"rate":0.1}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'missing upper rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":null,"rate":"0.1"}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'string rate rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":"100","rate":0.1},{"upper":null,"rate":0.2}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'string threshold rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":null,"rate":-0.1}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'negative rate rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":null,"rate":1.001}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'rate above one rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":10,"rate":0.1},{"upper":10,"rate":0.2},{"upper":null,"rate":0.3}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'duplicate threshold rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":20,"rate":0.1},{"upper":10,"rate":0.2},{"upper":null,"rate":0.3}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'descending threshold rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":-10,"rate":0.1},{"upper":null,"rate":0.2}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'negative threshold rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":null,"rate":0.1},{"upper":null,"rate":0.2}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'unbounded nonfinal band rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(0,'[{"upper":10,"rate":0.1}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'zero base does not bypass missing unbounded final band');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":null,"rate":0.1,"expression":"x"}]')$$, '22023', 'payroll_arithmetic_input_invalid', 'extra or executable fields rejected');
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,(SELECT jsonb_agg(jsonb_build_object('upper',n,'rate',0)) FROM generate_series(1,33)n))$$,
  '22023', 'payroll_arithmetic_input_invalid', 'overlarge band count rejected before evaluation');
SELECT throws_ok($$SELECT payroll.floor_annual_base_to_ten(NULL)$$, '22023', 'payroll_arithmetic_input_invalid', 'floor null rejected');
SELECT throws_ok($$SELECT payroll.floor_annual_base_to_ten(-0.01)$$, '22023', 'payroll_arithmetic_input_invalid', 'floor negative rejected');
SELECT throws_ok($$SELECT payroll.floor_annual_base_to_ten('-Infinity'::numeric)$$, '22023', 'payroll_arithmetic_input_invalid', 'floor negative infinity rejected');
SELECT ok(NOT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='payroll' AND p.proname IN ('progressive_annual_arithmetic','floor_annual_base_to_ten')
    AND (p.prosecdef OR p.provolatile <> 'i' OR NOT ('search_path=""'=ANY(p.proconfig)))
), 'both primitives immutable invoker with empty search path');
SELECT ok(NOT EXISTS (
  SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role'])r
  WHERE has_function_privilege(r,'payroll.progressive_annual_arithmetic(numeric,jsonb)','EXECUTE')
    OR has_function_privilege(r,'payroll.floor_annual_base_to_ten(numeric)','EXECUTE')
), 'ordinary and service roles cannot execute either primitive, including PUBLIC inheritance');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT payroll.progressive_annual_arithmetic(1,'[{"upper":null,"rate":0.1}]')$$,
  '42501', NULL, 'authenticated caller cannot invoke arithmetic directly');
SELECT throws_ok($$SELECT payroll.floor_annual_base_to_ten(10)$$,
  '42501', NULL, 'authenticated caller cannot invoke flooring directly');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
