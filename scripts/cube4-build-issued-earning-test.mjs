import fs from 'node:fs';
let sql=fs.readFileSync('supabase/tests/cube4_statutory_numeric_drafts.test.sql','utf8').replaceAll('\r\n','\n');
const anchor='UPDATE platform_private.platform_operator_grants SET can_manage_statutory_rules=false';
if(sql.split(anchor).length!==2)throw Error('Numeric draft authority boundary');
sql=sql.replace(anchor,`
SELECT is((payroll.statutory_draft_pack(version,'NONLEGAL earning projection')).earning_rules->>'schema','eg-earning-treatment-v1','actual draft formatter carries earning adapter contract') FROM payroll.statutory_draft_versions version WHERE head_id=(SELECT(value->>'head')::uuid FROM numeric_saved) AND revision=1;
SELECT is((payroll.statutory_draft_pack(version,'NONLEGAL earning projection')).earning_rules->'base_taxable','true'::jsonb,'explicit taxable base choice is preserved exactly') FROM payroll.statutory_draft_versions version WHERE head_id=(SELECT(value->>'head')::uuid FROM numeric_saved) AND revision=1;
SET LOCAL ROLE authenticated;
SELECT public.statutory_draft_save((SELECT(value->>'head')::uuid FROM numeric_saved),3,'f1421000-0000-4000-8000-000000000005','NONLEGAL-numeric','2026-01-01','2027-01-01','[{"title":"NONLEGAL fixture source","url":"https://example.test/numeric"}]','Explicit NONLEGAL nontaxable base',jsonb_set((SELECT rules FROM numeric_fixture),'{base_taxable}','false'));
SELECT set_config('test.earning_issuance',public.statutory_draft_issuance_status((SELECT(value->>'head')::uuid FROM numeric_saved),4)::text,true);
SELECT is(current_setting('test.earning_issuance')::jsonb->>'ready','false','recorded base choice does not substitute for official qualification');
SELECT is(current_setting('test.earning_issuance')::jsonb->>'financially_qualified','false','numeric earning binding remains tax insurance only');
SELECT throws_ok($q$SELECT public.statutory_draft_issue((SELECT(value->>'head')::uuid FROM numeric_saved),4,'f1421000-0000-4000-8000-000000000006',current_setting('test.earning_issuance')::jsonb->>'evidence_stamp',true,'NONLEGAL missing official coverage must refuse')$q$,'23514','statutory_issuance_not_ready','actual issuance still refuses NONLEGAL source without official coverage');
RESET ROLE;
SELECT is((payroll.statutory_draft_pack(version,'NONLEGAL earning projection')).earning_rules->'base_taxable','false'::jsonb,'nontaxable base is carried without a true default') FROM payroll.statutory_draft_versions version WHERE head_id=(SELECT(value->>'head')::uuid FROM numeric_saved) AND revision=4;
SELECT is((payroll.statutory_draft_pack(version,'NONLEGAL earning projection')).earning_rules->'base_taxable','true'::jsonb,'new rule revision preserves original taxable history') FROM payroll.statutory_draft_versions version WHERE head_id=(SELECT(value->>'head')::uuid FROM numeric_saved) AND revision=1;
`+anchor);
sql="BEGIN;\nDO $$ BEGIN IF current_database()<>'business_platform_cube4_adam_closure_qa' THEN RAISE EXCEPTION 'own QA only';END IF;END $$;\n"+sql+'\nROLLBACK;\n';
fs.writeFileSync('supabase/tests/cube4_issued_earning_binding.test.sql',sql);
