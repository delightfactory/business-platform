-- Focused delta suite; runner supplies the existing isolated input fixture.
SELECT set_config('test.ytd','{"year":"2030","taxable_earnings":"10000","tax_withheld":"100","social_base":"10000","employee_social":"100","employer_social":"200","reference":"Reviewed prior payroll","reason":"Reviewed opening totals"}',true);
SELECT lives_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb)$$,'legacy YTD remains unknown, not zero');
SELECT lives_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":"125.50"}')$$,'assessed tax may differ from withheld money');
SELECT lives_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":0}')$$,'explicit numeric zero accepted');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":null}')$$,'22023','payroll_invalid','null is not a reviewed amount');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":""}')$$,'22023','payroll_invalid','blank API amount rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":"-1"}')$$,'22023','payroll_invalid','negative prior tax rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":"NaN"}')$$,'22023','payroll_invalid','NaN rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":"Infinity"}')$$,'22023','payroll_invalid','infinity rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":true}')$$,'22023','payroll_invalid','boolean rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":"1.001"}')$$,'22023','payroll_invalid','sub-cent amount rejected');
SELECT throws_ok($$SELECT payroll.validate_input('opening_ytd',current_setting('test.ytd')::jsonb||'{"tax_due":"1000000000000"}')$$,'22023','payroll_invalid','amount ceiling enforced');
SELECT throws_ok($$SELECT payroll.validate_input('policy','{"mode":"calendar_days","reason":"Reviewed policy","tax_due":"1"}')$$,'22023','payroll_invalid','new field cannot leak into other input kinds');
SELECT ok(NOT has_function_privilege('authenticated','payroll.validate_input(text,jsonb)','EXECUTE'),'validator remains private');
CREATE FUNCTION pg_temp.save_ytd(attempt uuid) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_save_input('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','opening_ytd','c4425000-0000-4000-8000-000000000001',NULL,NULL,0,'2030-01-25',NULL,current_setting('test.ytd')::jsonb||'{"tax_due":"125.50"}','save',attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.save_ytd(uuid) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4420000-0000-4000-8000-000000000001',true);
SELECT set_config('test.ytd.saved',pg_temp.save_ytd('c4429000-0000-4000-8000-000000000071')::text,true);
SELECT is(pg_temp.save_ytd('c4429000-0000-4000-8000-000000000071'),current_setting('test.ytd.saved')::jsonb,'same-intent replay preserves original save');
SELECT set_config('test.ytd.period',(public.payroll_save_calendar('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Reviewed synthetic calendar')->>'period_id'),true);
RESET ROLE;
SELECT set_config('test.ytd.manifest',payroll.run_manifest('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.ytd.period')::uuid)::text,true);
SELECT ok(jsonb_path_exists(current_setting('test.ytd.manifest')::jsonb,'$.inputs[*].version.data ? (@.tax_due == "125.50" && @.tax_withheld == "100")'),'run source manifest captures both amounts independently');
SELECT ok(jsonb_path_exists(current_setting('test.ytd.manifest')::jsonb,'$.inputs[*].version ? (@.revision == 1)'),'manifest retains exact input version identity');
SELECT is((SELECT data->>'tax_due' FROM payroll.input_versions WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND head_id=(current_setting('test.ytd.saved')::jsonb->>'id')::uuid),'125.50','assessed amount persisted');
SELECT is((SELECT data->>'tax_withheld' FROM payroll.input_versions WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND head_id=(current_setting('test.ytd.saved')::jsonb->>'id')::uuid),'100','withheld amount remains independently persisted');
SELECT is((SELECT count(*)::integer FROM payroll.input_versions WHERE tenant_id='c4421000-0000-4000-8000-000000000001' AND head_id=(current_setting('test.ytd.saved')::jsonb->>'id')::uuid),1,'replay creates no second version');
SELECT * FROM finish();
