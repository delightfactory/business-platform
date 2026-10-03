-- All expected figures below are NONLEGAL mock results. The harness wraps this
-- file AND the migration in BEGIN/ROLLBACK; no real qualified pack is seeded.
SELECT no_plan();
CREATE TEMP TABLE issuance_before AS SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY id),'')) digest FROM payroll.statutory_packs p;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) VALUES
 ('f1440000-0000-4000-8000-000000000001','authenticated','authenticated','issue-review@example.test','hash',now(),'{}','{}',now(),now()),
 ('f1440000-0000-4000-8000-000000000002','authenticated','authenticated','issue-manager@example.test','hash',now(),'{}','{}',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_manage_statutory_rules) VALUES
 ('f1440000-0000-4000-8000-000000000001',true,false,true),('f1440000-0000-4000-8000-000000000002',true,true,false);
CREATE TEMP TABLE issuance_fixture AS SELECT
 '{"tax":{"treatment":"01","exemption":"0","column_basis":"annual_raw","columns":[{"through":"","bands":[{"upper":"","rate":"10"}]}]},"insurance":{"category":"NONLEGAL-ISSUANCE","minimum":"100","maximum":"100","branches":[{"branch":"pension","employee":"1","employer":"2","deductible":true}]},"base_taxable":true}'::jsonb rules,
 '{"name":"NONLEGAL mock","scenario":"rounding","origin":"synthetic","source_url":"https://eta.gov.eg/NONLEGAL-mocked-results","reference":"NONLEGAL mocked provenance, not official proof","tax":{"net":"50","duration":"30","prior_due":"10","from":"2030-07-01","until":"2030-07-31"},"insurance":[{"month":"2030-07-01","wage":"100","reference":"NONLEGAL wage"}],"expected":{"tax_due":"5","tax_delta":"-5","employee_insurance":"1","employer_insurance":"2","deductible_insurance":"1"}}'::jsonb item;
-- Valid unequal min/max; fixtures at each boundary have explicitly derived totals.
UPDATE issuance_fixture SET rules=jsonb_set(rules,'{insurance,maximum}','"200"');
CREATE TEMP TABLE issuance_head(value jsonb);CREATE TEMP TABLE issuance_status(value jsonb);CREATE TEMP TABLE issuance_result(value jsonb);
GRANT ALL ON issuance_head,issuance_status,issuance_result TO authenticated;GRANT SELECT ON issuance_fixture TO authenticated;
SELECT ok(NOT has_function_privilege('anon','public.statutory_draft_issue(uuid,integer,uuid,text,boolean,text)','EXECUTE'),'anonymous cannot issue rules');
SELECT ok(NOT has_function_privilege('service_role','public.statutory_draft_issue(uuid,integer,uuid,text,boolean,text)','EXECUTE'),'service role cannot bypass reviewer');
SELECT ok(NOT has_function_privilege('authenticated','payroll.statutory_issuance_readiness(uuid,integer)','EXECUTE'),'private eligibility is not direct API');
SELECT ok(NOT has_table_privilege('authenticated','payroll.statutory_draft_issuances','INSERT'),'issuance cannot be inserted directly');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"f1440000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT throws_ok($$SELECT public.statutory_draft_issuance_status('f1440000-0000-4000-8000-000000000003',1)$$,'42501','statutory_draft_forbidden','operator management does not imply statutory review');
SELECT set_config('request.jwt.claims','{"sub":"f1440000-0000-4000-8000-000000000001","role":"authenticated"}',true);
INSERT INTO issuance_head SELECT public.statutory_draft_save(NULL,0,'f1441000-0000-4000-8000-000000000001','NONLEGAL-ISSUANCE','2030-01-01','2031-01-01','[{"title":"NONLEGAL mocked official source","url":"https://eta.gov.eg/NONLEGAL-mocked-results"},{"title":"NONLEGAL other source","url":"https://example.test/other"}]','NONLEGAL mock setup',(SELECT rules FROM issuance_fixture));
INSERT INTO issuance_status SELECT public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1);
SELECT is((SELECT value->>'ready' FROM issuance_status),'false','no official results blocks issue');
SELECT is(jsonb_array_length((SELECT value->'missing_coverage' FROM issuance_status)),10,'all ten required cases reported for covered year');
SELECT throws_ok($$SELECT public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000002',(SELECT value->>'evidence_stamp' FROM issuance_status),true,'NONLEGAL reviewer attestation')$$,'23514','statutory_issuance_not_ready','attestation cannot replace missing official coverage');
SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),jsonb_set(item,'{name}',to_jsonb('NONLEGAL synthetic '||scenario)))
 FROM issuance_fixture CROSS JOIN unnest(ARRAY['low','medium','high','mid_year','cumulative','insurance_min','insurance_max','component_mix','correction','rounding'])scenario;
SELECT is(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1)->>'ready','false','ten matching synthetic labels never qualify');
SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),
 jsonb_set(jsonb_set(jsonb_set(item,'{name}',to_jsonb('NONLEGAL official mock '||scenario)),'{scenario}',to_jsonb(scenario)),'{origin}','"official"') ||
 CASE WHEN scenario='insurance_max' THEN '{"insurance":[{"month":"2030-07-01","wage":"200","reference":"NONLEGAL max"}],"expected":{"tax_due":"5","tax_delta":"-5","employee_insurance":"2","employer_insurance":"4","deductible_insurance":"2"}}'::jsonb ELSE '{}' END)
 FROM issuance_fixture CROSS JOIN unnest(ARRAY['low','medium','high','mid_year','cumulative','insurance_min','insurance_max','component_mix','correction','rounding'])scenario;
DELETE FROM issuance_status;INSERT INTO issuance_status SELECT public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1);
SELECT is((SELECT value->>'ready' FROM issuance_status),'true','isolated official-provenance mocks satisfy mechanical adapter coverage, not real law');
SELECT is((SELECT value->>'financially_qualified' FROM issuance_status),'false','mechanical readiness never qualifies whole payroll');
SELECT throws_ok($$SELECT public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),(SELECT value->>'evidence_stamp' FROM issuance_status),false,'NONLEGAL reviewer attestation')$$,'22023','statutory_issuance_invalid','explicit provenance/applicability review required');
-- A new mismatch must invalidate previous readiness and block release.
SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),jsonb_set(jsonb_set(jsonb_set(item,'{name}','"NONLEGAL official mock rounding"'),'{origin}','"official"'),'{expected,tax_due}','"6"')) FROM issuance_fixture;
SELECT throws_ok($$SELECT public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),(SELECT value->>'evidence_stamp' FROM issuance_status),true,'NONLEGAL reviewer attestation')$$,'PT409','statutory_issuance_evidence_stale','comparison saved after review invalidates stamp');
SELECT ok(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1)->'blockers' ? 'official_result_unresolved','current official mismatch blocks despite other matches');
SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),jsonb_set(jsonb_set(item,'{name}','"NONLEGAL official mock rounding"'),'{origin}','"official"')) FROM issuance_fixture;
SELECT is(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1)->>'ready','true','corrected same case supersedes mismatch without deleting history');
-- Official label with an unrelated URL cannot qualify or hide unresolved results.
SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),jsonb_set(jsonb_set(jsonb_set(item,'{name}','"NONLEGAL official mock rounding"'),'{origin}','"official"'),'{source_url}','"https://example.test/other"')) FROM issuance_fixture;
SELECT ok(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1)->'blockers' ? 'official_result_unresolved','arbitrary URL and official tag are insufficient');
SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000003',jsonb_set(jsonb_set(item,'{name}','"NONLEGAL official mock rounding"'),'{origin}','"official"')) FROM issuance_fixture;
DELETE FROM issuance_status;INSERT INTO issuance_status SELECT public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1);
INSERT INTO issuance_result SELECT public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000004',(SELECT value->>'evidence_stamp' FROM issuance_status),true,'NONLEGAL mocked reviewer attestation for rollback only');
SELECT is(public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000004',(SELECT value->>'evidence_stamp' FROM issuance_status),true,'NONLEGAL mocked reviewer attestation for rollback only'),(SELECT value FROM issuance_result),'same attempt returns original issued pack');
SELECT throws_ok($$SELECT public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000004',(SELECT value->>'evidence_stamp' FROM issuance_status),true,'Changed review intent')$$,'PT409','statutory_draft_attempt_conflict','changed intent cannot reuse receipt');
SELECT is(public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),(SELECT value->>'evidence_stamp' FROM issuance_status),true,'NONLEGAL duplicate browser review'),(SELECT value FROM issuance_result),'another attempt cannot duplicate same revision issuance');
SELECT throws_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),(SELECT item FROM issuance_fixture))$$,'PT409','statutory_revision_issued','issued evidence revision is frozen');
SELECT lives_ok($$SELECT public.statutory_draft_compare((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000003',(SELECT jsonb_set(jsonb_set(item,'{name}','"NONLEGAL official mock rounding"'),'{origin}','"official"') FROM issuance_fixture))$$,'original comparison receipt still recovers after issuance');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.statutory_draft_issuances),1::bigint,'one immutable issuance');
SELECT is((SELECT review_evidence->>'scope' FROM payroll.statutory_packs WHERE id=(SELECT(value->>'pack')::uuid FROM issuance_result)),'tax_insurance','issued scope is explicit');
SELECT is((SELECT earning_rules FROM payroll.statutory_packs WHERE id=(SELECT(value->>'pack')::uuid FROM issuance_result)),'{}'::jsonb,'no inferred earning or labour qualification');
SELECT is(jsonb_array_length((SELECT review_evidence->'numeric_comparisons' FROM payroll.statutory_packs WHERE id=(SELECT(value->>'pack')::uuid FROM issuance_result))),14,'all original official records preserved including superseded mismatch');
SELECT throws_ok($$UPDATE payroll.statutory_draft_issuances SET reason='rewrite'$$,'55000','payroll_immutable','issuance evidence cannot be rewritten');
SELECT is((SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY id),'')) FROM payroll.statutory_packs p WHERE id<>(SELECT(value->>'pack')::uuid FROM issuance_result)),(SELECT digest FROM issuance_before),'all previous packs unchanged');
SET LOCAL ROLE authenticated;
SELECT public.statutory_draft_save((SELECT(value->>'head')::uuid FROM issuance_head),1,gen_random_uuid(),'NONLEGAL-ISSUANCE','2030-01-01','2032-01-01','[{"title":"NONLEGAL mocked official source","url":"https://eta.gov.eg/NONLEGAL-mocked-results"}]','New review extending across year',(SELECT rules FROM issuance_fixture));
SELECT throws_ok($$SELECT public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),1)$$,'PT409','statutory_draft_stale','old head revision cannot be issued freshly');
SELECT is(jsonb_array_length(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),2)->'missing_coverage'),20,'each covered year requires its own official representative results');
SELECT is(public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000004',(SELECT value->>'evidence_stamp' FROM issuance_status),true,'NONLEGAL mocked reviewer attestation for rollback only'),(SELECT value FROM issuance_result),'original issuance receipt recovers even after draft changes');
SELECT ok(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),2)->'blockers' ? 'qualified_scope_overlap','overlapping category/treatment cannot issue ambiguously');
SELECT public.statutory_draft_save((SELECT(value->>'head')::uuid FROM issuance_head),2,gen_random_uuid(),'NONLEGAL-ISSUANCE','2030-01-01','2031-01-01','[{"title":"NONLEGAL mocked official source","url":"https://eta.gov.eg/NONLEGAL-mocked-results"}]','Different insurance category with conflicting tax',(SELECT jsonb_set(jsonb_set(rules,'{insurance,category}','"NONLEGAL-other"'),'{tax,exemption}','"10"') FROM issuance_fixture));
SELECT ok(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),3)->'blockers' ? 'qualified_scope_overlap','conflicting tax cannot hide behind another insurance category');
SELECT public.statutory_draft_save((SELECT(value->>'head')::uuid FROM issuance_head),3,gen_random_uuid(),'NONLEGAL-ISSUANCE','2030-01-01','2031-01-01','[{"title":"NONLEGAL mocked official source","url":"https://eta.gov.eg/NONLEGAL-mocked-results"}]','Different tax treatment with conflicting insurance',(SELECT jsonb_set(jsonb_set(rules,'{tax,treatment}','"02"'),'{insurance,branches,0,employee}','"3"') FROM issuance_fixture));
SELECT ok(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),4)->'blockers' ? 'qualified_scope_overlap','conflicting insurance cannot hide behind another tax treatment');
SELECT public.statutory_draft_save((SELECT(value->>'head')::uuid FROM issuance_head),4,gen_random_uuid(),'NONLEGAL-ISSUANCE','2030-01-01','2031-01-01','[{"title":"NONLEGAL mocked official source","url":"https://eta.gov.eg/NONLEGAL-mocked-results"}]','Another category sharing identical tax schedule',(SELECT jsonb_set(rules,'{insurance,category}','"NONLEGAL-other"') FROM issuance_fixture));
SELECT ok(NOT(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),5)->'blockers' ? 'qualified_scope_overlap'),'identical tax rules can serve another insurance category without artificial restriction');
SELECT public.statutory_draft_save((SELECT(value->>'head')::uuid FROM issuance_head),5,gen_random_uuid(),'NONLEGAL-ISSUANCE','2030-01-01',NULL,'[{"title":"NONLEGAL mocked official source","url":"https://eta.gov.eg/NONLEGAL-mocked-results"}]','Open-ended review cannot qualify unknown future years',(SELECT rules FROM issuance_fixture));
SELECT ok(public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM issuance_head),6)->'blockers' ? 'review_end_missing','unknown future years cannot be silently qualified');
RESET ROLE;
UPDATE platform_private.platform_operator_grants SET can_manage_statutory_rules=false,is_active=false WHERE user_id='f1440000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM issuance_head),1,'f1441000-0000-4000-8000-000000000004',(SELECT value->>'evidence_stamp' FROM issuance_status),true,'NONLEGAL mocked reviewer attestation for rollback only')$$,'42501','statutory_draft_forbidden','revoked reviewer cannot recover sensitive receipt');
RESET ROLE;
SELECT * FROM finish();
