SELECT no_plan();
CREATE TEMP TABLE compare_pack_stamp AS SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY id),'')) digest FROM payroll.statutory_packs p;
CREATE TEMP TABLE compare_fixture AS SELECT '{"tax":{"treatment":"01","exemption":"0","column_basis":"annual_raw","columns":[{"through":"","bands":[{"upper":"","rate":"10"}]}]},"insurance":{"category":"NONLEGAL","minimum":"1","maximum":"200","branches":[{"branch":"pension","employee":"1","employer":"2","deductible":true}]},"base_taxable":true}'::jsonb rules,
 '{"name":"NONLEGAL comparison","scenario":"rounding","origin":"synthetic","source_url":"https://example.test/comparison","reference":"NONLEGAL derived result","tax":{"net":"50","duration":"30","prior_due":"10","from":"2030-01-01","until":"2030-01-31"},"insurance":[{"month":"2030-01-01","wage":"100","reference":"NONLEGAL wage"}],"expected":{"tax_due":"5.00","tax_delta":"-5.00","employee_insurance":"1.00","employer_insurance":"2.00","deductible_insurance":"1.00"}}'::jsonb item;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)VALUES
 ('f1430000-0000-4000-8000-000000000001','authenticated','authenticated','compare-compliance@example.test','hash',now(),'{}','{}',now(),now()),
 ('f1430000-0000-4000-8000-000000000002','authenticated','authenticated','compare-operator@example.test','hash',now(),'{}','{}',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_manage_statutory_rules)VALUES
 ('f1430000-0000-4000-8000-000000000001',true,false,true),('f1430000-0000-4000-8000-000000000002',true,true,false);
SELECT ok(NOT has_function_privilege('anon','public.statutory_draft_compare(uuid,integer,uuid,jsonb)','EXECUTE'),'anonymous cannot write comparisons');
SELECT ok(NOT has_function_privilege('service_role','public.statutory_draft_compare(uuid,integer,uuid,jsonb)','EXECUTE'),'service role cannot bypass comparison authority');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_cumulative_tax_data(payroll.statutory_packs,jsonb)','EXECUTE'),'raw tax calculation is private');
SELECT ok(NOT has_function_privilege('authenticated','payroll.calculate_insurance_data(payroll.statutory_packs,jsonb)','EXECUTE'),'raw insurance calculation is private');
SELECT ok(NOT has_table_privilege('authenticated','payroll.statutory_draft_comparisons','INSERT'),'comparison history cannot be appended directly');
CREATE TEMP TABLE comparison_saved(value jsonb);CREATE TEMP TABLE comparison_head(value jsonb);GRANT ALL ON comparison_saved,comparison_head TO authenticated;GRANT SELECT ON compare_fixture TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"f1430000-0000-4000-8000-000000000001","role":"authenticated"}',true);
INSERT INTO comparison_head SELECT public.statutory_draft_save(NULL,0,'f1431000-0000-4000-8000-000000000001','NONLEGAL-compare','2030-01-01','2031-01-01','[{"title":"NONLEGAL source","url":"https://example.test/comparison"}]','Create comparison fixture',(SELECT rules FROM compare_fixture));
INSERT INTO comparison_saved SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000002',(SELECT item FROM compare_fixture));
SELECT is((SELECT value->>'matched' FROM comparison_saved),'true','known synthetic tax and insurance totals match exactly');
SELECT is((SELECT value->>'qualified' FROM comparison_saved),'false','matching does not qualify legal rules');
SELECT is(public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000002',(SELECT item FROM compare_fixture)),(SELECT value FROM comparison_saved),'same comparison attempt replays its original record');
SELECT throws_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000002',(SELECT jsonb_set(item,'{expected,tax_due}','"6"') FROM compare_fixture))$$,'PT409','statutory_draft_attempt_conflict','changed expected result cannot reuse attempt');
SELECT is(public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000003',(SELECT jsonb_set(item,'{expected,tax_due}','"6"') FROM compare_fixture))->>'matched','false','mismatch is recorded rather than softened');
SELECT throws_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000004',(SELECT jsonb_set(item,'{source_url}','"https://example.test/other"') FROM compare_fixture))$$,'22023','statutory_comparison_invalid','results require a source in this exact draft revision');
SELECT throws_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000004',(SELECT jsonb_set(item,'{tax,duration}','"0"') FROM compare_fixture))$$,'22023','payroll_statutory_context_invalid','zero legal duration is refused');
SELECT throws_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000004',(SELECT jsonb_set(item,'{insurance,0,wage}','"201"') FROM compare_fixture))$$,'22023','payroll_insurance_wage_outside_rules','insured wage is not silently clamped');
SELECT throws_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000004',(SELECT jsonb_set(item,'{tax,from}','"2030-02-31"') FROM compare_fixture))$$,'22023','statutory_comparison_invalid','invalid dates are refused');
SELECT is(jsonb_array_length(public.statutory_draft_comparison_history((SELECT(value->>'head')::uuid FROM comparison_head),NULL,1)->'rows'),1,'comparison list is bounded');
SELECT ok(public.statutory_draft_comparison_history((SELECT(value->>'head')::uuid FROM comparison_head),NULL,1)->>'next' IS NOT NULL,'history exposes keyset continuation');
SELECT is(jsonb_array_length(public.statutory_draft_comparison_history((SELECT(value->>'head')::uuid FROM comparison_head),(public.statutory_draft_comparison_history((SELECT(value->>'head')::uuid FROM comparison_head),NULL,1)->>'next')::bigint,1)->'rows'),1,'history continuation excludes previous row');
SELECT public.statutory_draft_save((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000005','NONLEGAL-compare','2030-01-01','2031-01-01','[{"title":"NONLEGAL source","url":"https://example.test/comparison"}]','Edit draft metadata');
SELECT is(public.statutory_draft_comparison_history((SELECT(value->>'head')::uuid FROM comparison_head))->>'current_revision','2','history identifies newer draft revision');
SELECT is(public.statutory_draft_comparison_history((SELECT(value->>'head')::uuid FROM comparison_head))#>>'{rows,0,revision}','1','comparison retains its original revision');
SELECT throws_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM comparison_head),1,'f1431000-0000-4000-8000-000000000006',(SELECT item FROM compare_fixture))$$,'PT409','statutory_draft_stale','new comparison cannot use a stale rules revision');
SELECT set_config('request.jwt.claims','{"sub":"f1430000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT throws_ok($$SELECT public.statutory_draft_comparison_history((SELECT(value->>'head')::uuid FROM comparison_head))$$,'42501','statutory_draft_forbidden','operator manager does not inherit comparison visibility');
RESET ROLE;
SELECT throws_ok($$UPDATE payroll.statutory_draft_comparisons SET result='{}' WHERE head_id=(SELECT(value->>'head')::uuid FROM comparison_head)$$,'55000','payroll_immutable','comparison result is immutable');
SELECT is((SELECT count(*)::integer FROM payroll.statutory_draft_comparisons WHERE head_id=(SELECT(value->>'head')::uuid FROM comparison_head)),2,'refused requests and receipt replay add no comparison rows');
SELECT is((SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY id),'')) FROM payroll.statutory_packs p),(SELECT digest FROM compare_pack_stamp),'draft evaluation never creates or changes live packs');
SELECT * FROM finish();
