SELECT no_plan();
\ir cube4_financial_civil_dates_fixture.sql
-- Real advance save, approval and activation; no qualified payroll output fabricated.
SELECT pg_temp.command('save',0);
SELECT pg_temp.command('approve',1);
SELECT pg_temp.command('activate',2);
RESET ROLE;
CREATE FUNCTION pg_temp.financial_digest() RETURNS text LANGUAGE sql AS $$
 SELECT md5(jsonb_build_object(
 'settlements',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM payroll.correction_settlements x),
 'advance_events',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM payroll.advance_events x),
 'advance_heads',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM payroll.advance_heads x),
 'receipts',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY tenant_id,actor_id,attempt_key),'[]') FROM payroll.command_receipts x))::text)
$$;
SELECT set_config('test.date_digest',pg_temp.financial_digest(),true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(format('SELECT pg_temp.command(%L,3,jsonb_build_object(''date'',%L,''amount'',''1''))',op,day),'22023','finance_invalid','advance '||op||' rejects '||day)
FROM unnest(ARRAY['settle','compensate'])op CROSS JOIN unnest(ARRAY['-infinity','infinity','0001-01-01 BC','10000-01-01','0001-12-31 BC'])day;
SELECT throws_ok(format('SELECT public.payroll_correction_settlement(''c4471000-0000-4000-8000-000000000001'',''c4473000-0000-4000-8000-000000000001'',''c4478000-0000-4000-8000-000000000099'',0,''c4475000-0000-4000-8000-000000000001'',%L,1,%L::date,''civil date QA'',''Reviewed civil date QA'',gen_random_uuid())',direction,day),'22023','payroll_invalid','correction '||direction||' rejects '||day)
FROM unnest(ARRAY['employee_extra_payment','employee_recovery'])direction CROSS JOIN unnest(ARRAY['-infinity','infinity','0001-01-01 BC','10000-01-01','0001-12-31 BC'])day;
RESET ROLE;
SELECT is(pg_temp.financial_digest(),current_setting('test.date_digest'),'invalid dates leave settlements, advance events/heads and command receipts unchanged');
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('settle',3,'{"date":"0001-01-01","amount":"1"}')->>'outstanding','99.00','earliest valid ISO civil date passes real advance settlement without clamping');
RESET ROLE;
SELECT is((SELECT occurred_on::text FROM payroll.advance_events WHERE kind='settlement' AND advance_id='c4478000-0000-4000-8000-000000000001'),'0001-01-01','saved historical date is exact');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE kind='settlement' AND advance_id='c4478000-0000-4000-8000-000000000001'),1::bigint,'one accepted historical settlement creates exactly one event');
SELECT * FROM finish();
