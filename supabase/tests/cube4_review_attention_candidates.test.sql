BEGIN;

DO $$ BEGIN
  IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN
    RAISE EXCEPTION 'Cube4 dedicated QA identity required';
  END IF;
END $$;

SELECT no_plan();

-- Candidate-backed review coverage.  The root runner injects the pending
-- 20261003021000 migration into this transaction; this file deliberately does
-- not apply it.  All persistent fixture rows below are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4a80000-0000-4000-8000-000000000001','c4a8-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4a80000-0000-4000-8000-000000000002','c4a8-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4a80000-0000-4000-8000-000000000003','c4a8-outsider@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4a81000-0000-4000-8000-000000000001','Cube4 attention candidate QA','c4a80000-0000-4000-8000-000000000001'),
 ('c4a81000-0000-4000-8000-000000000002','Cube4 attention other tenant','c4a80000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4a81000-0000-4000-8000-000000000001','c4a82000-0000-4000-8000-000000000001','qa.c4a8.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review']),
 ('c4a81000-0000-4000-8000-000000000001','c4a82000-0000-4000-8000-000000000002','qa.c4a8.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4a81000-0000-4000-8000-000000000001','c4a80000-0000-4000-8000-000000000001','c4a80000-0000-4000-8000-000000000001'),
 ('c4a81000-0000-4000-8000-000000000001','c4a80000-0000-4000-8000-000000000002','c4a80000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4a81000-0000-4000-8000-000000000001','c4a80000-0000-4000-8000-000000000001','c4a82000-0000-4000-8000-000000000001'),
 ('c4a81000-0000-4000-8000-000000000001','c4a80000-0000-4000-8000-000000000002','c4a82000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4a81000-0000-4000-8000-000000000001','c4a83000-0000-4000-8000-000000000001','Attention issues employer','Attention issues employer'),
 ('c4a81000-0000-4000-8000-000000000001','c4a83000-0000-4000-8000-000000000002','Comparison employer','Comparison employer'),
 ('c4a81000-0000-4000-8000-000000000001','c4a83000-0000-4000-8000-000000000003','Denied employer','Denied employer'),
 ('c4a81000-0000-4000-8000-000000000002','c4a83000-0000-4000-8000-000000000004','Other tenant employer','Other tenant employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4a81000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4a80000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4a81000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4a80000-0000-4000-8000-000000000001','Cube4 QA only');

INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES
 ('c4a81000-0000-4000-8000-000000000001','c4a84000-0000-4000-8000-000000000001','c4a83000-0000-4000-8000-000000000001','Issue site',true),
 ('c4a81000-0000-4000-8000-000000000001','c4a84000-0000-4000-8000-000000000002','c4a83000-0000-4000-8000-000000000002','Comparison site',false);

-- Local mapping keeps every operational candidate synthetic and collision-free.
CREATE TEMP TABLE c4a8_people(scope text,n integer,employee_id uuid,employment_id uuid,assignment_id uuid) ON COMMIT DROP;
INSERT INTO c4a8_people
 SELECT 'issue',n,gen_random_uuid(),('c4a85000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,gen_random_uuid() FROM generate_series(1,35)n
 UNION ALL
 SELECT 'comparison',n,gen_random_uuid(),('c4a86000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,gen_random_uuid() FROM generate_series(1,31)n;
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
 SELECT 'c4a81000-0000-4000-8000-000000000001',employee_id,
        CASE WHEN scope='issue' THEN 'I'||lpad(n::text,2,'0') ELSE 'C'||lpad(n::text,2,'0') END,
        CASE WHEN scope='issue' THEN 'Issue Candidate ' ELSE 'Comparison Candidate ' END||n,
        'c4a80000-0000-4000-8000-000000000001' FROM c4a8_people;
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis)
 SELECT 'c4a81000-0000-4000-8000-000000000001',employment_id,employee_id,
        CASE WHEN scope='issue' THEN 'c4a83000-0000-4000-8000-000000000001'::uuid ELSE 'c4a83000-0000-4000-8000-000000000002'::uuid END,
        CASE WHEN scope='comparison' AND n=31 THEN '2030-03-01'::date ELSE '2030-01-01'::date END,'monthly' FROM c4a8_people;
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from)
 SELECT 'c4a81000-0000-4000-8000-000000000001',assignment_id,employment_id,
        CASE WHEN scope='issue' THEN 'c4a84000-0000-4000-8000-000000000001'::uuid ELSE 'c4a84000-0000-4000-8000-000000000002'::uuid END,
        CASE WHEN scope='comparison' AND n=31 THEN '2030-03-01'::date ELSE '2030-01-01'::date END FROM c4a8_people;

-- Seed dated rates before either calculation.  Issue employee 31 is the only
-- missing compensation; comparison has 30 January employees plus a March 1 hire.
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from,valid_until)
 SELECT 'c4a81000-0000-4000-8000-000000000001',gen_random_uuid(),employment_id,3000,'2030-01-01',
        CASE WHEN scope='comparison' AND n BETWEEN 1 AND 5 THEN '2030-03-01'::date ELSE NULL END
 FROM c4a8_people WHERE scope='issue' AND n<>31 OR scope='comparison';
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from)
 SELECT 'c4a81000-0000-4000-8000-000000000001',gen_random_uuid(),employment_id,4000,'2030-03-01'
 FROM c4a8_people WHERE scope='comparison' AND n BETWEEN 1 AND 5;


SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4a80000-0000-4000-8000-000000000001',true);
CREATE FUNCTION pg_temp.make_calendar(e uuid) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE q jsonb; BEGIN
 q:=public.payroll_calendar_preview('c4a81000-0000-4000-8000-000000000001',e,'2030-01-01',31,31,'ending','Africa/Cairo');
 PERFORM public.payroll_save_calendar('c4a81000-0000-4000-8000-000000000001',e,'2030-01-01',31,31,'ending','Africa/Cairo',0,gen_random_uuid(),q,'QA January calendar');
 PERFORM public.payroll_generate_next_period('c4a81000-0000-4000-8000-000000000001',e,1,gen_random_uuid(),(public.payroll_workspace('c4a81000-0000-4000-8000-000000000001',e)->>'next_preview')::jsonb);
 PERFORM public.payroll_generate_next_period('c4a81000-0000-4000-8000-000000000001',e,2,gen_random_uuid(),(public.payroll_workspace('c4a81000-0000-4000-8000-000000000001',e)->>'next_preview')::jsonb);
END $f$;
SELECT pg_temp.make_calendar('c4a83000-0000-4000-8000-000000000001');
SELECT pg_temp.make_calendar('c4a83000-0000-4000-8000-000000000002');
RESET ROLE;
SELECT set_config('test.issue_period',(SELECT id::text FROM payroll.periods WHERE tenant_id='c4a81000-0000-4000-8000-000000000001' AND employer_id='c4a83000-0000-4000-8000-000000000001' AND starts_on='2030-01-01'),true);
SELECT set_config('test.comp_jan',(SELECT id::text FROM payroll.periods WHERE tenant_id='c4a81000-0000-4000-8000-000000000001' AND employer_id='c4a83000-0000-4000-8000-000000000002' AND starts_on='2030-01-01'),true);
SELECT set_config('test.comp_mar',(SELECT id::text FROM payroll.periods WHERE tenant_id='c4a81000-0000-4000-8000-000000000001' AND employer_id='c4a83000-0000-4000-8000-000000000002' AND starts_on='2030-03-01'),true);

-- Selection fixtures use real scoped People/calendar rows and actual current
-- run_manifest. Only candidate display values are synthetic, append-only and
-- NOT evidence of payroll arithmetic/statutory calculation or financial lock.
GRANT SELECT ON c4a8_people TO authenticated;
CREATE FUNCTION pg_temp.seed_review(e uuid,p uuid,s text,previous boolean DEFAULT false,many boolean DEFAULT false) RETURNS void LANGUAGE plpgsql AS $f$
<<fixture>>
DECLARE run_id uuid:=gen_random_uuid();candidate_id uuid:=gen_random_uuid();manifest jsonb;employees jsonb;issues jsonb;amount numeric;
BEGIN
 manifest:=payroll.run_manifest('c4a81000-0000-4000-8000-000000000001',e,p);
 SELECT jsonb_agg(jsonb_build_object('employment_id',employment_id,'employee_id',employee_id,
 'name',CASE WHEN s='issue' THEN 'Issue ' ELSE 'Comparison ' END||n,'code',CASE WHEN s='issue' THEN 'I' ELSE 'C' END||lpad(n::text,2,'0'),
 'pay_basis','monthly','eligible_days',31,'base',CASE WHEN s='comparison' AND NOT previous AND n<=5 THEN '4000' ELSE '3000' END,
 'gross',CASE WHEN s='comparison' AND NOT previous AND n<=5 THEN '4000' ELSE '3000' END,
 'known_gross',CASE WHEN s='comparison' AND NOT previous AND n<=5 THEN '4000' ELSE '3000' END,
 'deductions','0','employer_cost','0','net',NULL,'lines','[]'::jsonb,'unresolved_parts','[]'::jsonb,'dated_rates','[]'::jsonb,
 'source_days','[]'::jsonb,'source_coverage_days','[]'::jsonb,
 'issues',CASE WHEN s='issue' AND (n=31 OR many) THEN jsonb_build_array(jsonb_build_object('code','compensation_gap','employment_id',employment_id,'blocking',true)) ELSE '[]'::jsonb END) ORDER BY employment_id)
 INTO employees FROM c4a8_people WHERE scope=s AND (NOT previous OR n<31);
 SELECT COALESCE(jsonb_agg(i),'[]') INTO issues FROM jsonb_array_elements(employees)x CROSS JOIN LATERAL jsonb_array_elements(x->'issues')i;
 issues:=issues||jsonb_build_array(jsonb_build_object('code','statutory_not_qualified','blocking',true));
 SELECT sum((x->>'gross')::numeric) INTO amount FROM jsonb_array_elements(employees)x;
 INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,revision,status,created_by) VALUES('c4a81000-0000-4000-8000-000000000001',e,p,run_id,0,'review','c4a80000-0000-4000-8000-000000000001');
 INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by)
 VALUES('c4a81000-0000-4000-8000-000000000001',e,run_id,candidate_id,1,'qa-review-selection-only',manifest,
 jsonb_build_object('employees',employees,'issues',issues,'gross',amount::text,'known_gross',amount::text,'gross_complete',s='comparison','deductions','0','employer_cost','0','net',NULL,'financially_qualified',false,'employee_count',jsonb_array_length(employees)),
 'c4a80000-0000-4000-8000-000000000001');
 UPDATE payroll.runs SET revision=1,candidate_id=fixture.candidate_id WHERE tenant_id='c4a81000-0000-4000-8000-000000000001' AND id=fixture.run_id;
END $f$;
SELECT pg_temp.seed_review('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'issue');
SELECT pg_temp.seed_review('c4a83000-0000-4000-8000-000000000002',current_setting('test.comp_jan')::uuid,'comparison',true);
SELECT pg_temp.seed_review('c4a83000-0000-4000-8000-000000000002',current_setting('test.comp_mar')::uuid,'comparison');
SELECT set_config('test.issue_mar',(SELECT id::text FROM payroll.periods WHERE tenant_id='c4a81000-0000-4000-8000-000000000001' AND employer_id='c4a83000-0000-4000-8000-000000000001' AND starts_on='2030-03-01'),true);
SELECT pg_temp.seed_review('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_mar')::uuid,'issue',false,true);
CREATE FUNCTION pg_temp.ws(e uuid,p uuid,v text DEFAULT 'attention',after_id uuid DEFAULT NULL,limit_rows integer DEFAULT 30,employee uuid DEFAULT NULL,q text DEFAULT '') RETURNS jsonb LANGUAGE sql AS $f$
 SELECT public.payroll_run_review_workspace('c4a81000-0000-4000-8000-000000000001',e,p,after_id,limit_rows,employee,q,v)
$f$;

-- The local qualification runner captures the actual pre-migration function.
-- Standard post-migration suites have no historical temporary function: report
-- an explicit skip for these two comparisons, never compare against a clone of
-- the new wrapper and pretend that proves backward compatibility.
CREATE FUNCTION pg_temp.compare_legacy(e uuid,p uuid,title text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE message text;BEGIN
 IF to_regprocedure('pg_temp.original_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text)') IS NULL THEN
  SELECT skip('Historical pre-migration baseline not injected',1) INTO message;
 ELSE
  EXECUTE 'SELECT is(public.payroll_run_workspace($1,$2,$3),pg_temp.original_run_workspace($1,$2,$3),$4)'
  INTO message USING 'c4a81000-0000-4000-8000-000000000001'::uuid,e,p,title;
 END IF;
 RETURN message;
END $f$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('test.all',pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'all')::text,true);
SELECT set_config('test.attention',pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid)::text,true);
SELECT pg_temp.compare_legacy('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'legacy response equals actual captured baseline');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.all')::jsonb->'employees')x WHERE x->>'code'='I31'),'first thirty all rows are healthy and exclude late issue employee');
SELECT is(current_setting('test.attention')::jsonb->'employees'->0->>'code','I31','attention finds issue after first thirty healthy rows');
SELECT is((current_setting('test.attention')::jsonb->'review_filter'->>'attention_count')::int,1,'only employee issue belongs to attention when comparison unavailable');
SELECT is(jsonb_array_length(pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'all',(current_setting('test.all')::jsonb->'review_filter'->>'next_after')::uuid)->'employees'),5,'all view cursor returns remaining five rows');
SELECT is(current_setting('test.attention')::jsonb->'summary',current_setting('test.all')::jsonb->'summary','full employer totals unchanged by attention');
SELECT is(current_setting('test.attention')::jsonb->'approval',current_setting('test.all')::jsonb->'approval','full employer approval readiness unchanged by attention');
SELECT ok(current_setting('test.attention')::jsonb->'global_issues'=current_setting('test.all')::jsonb->'global_issues' AND current_setting('test.attention')::jsonb->'issue_count'=current_setting('test.all')::jsonb->'issue_count' AND NOT(current_setting('test.attention')::jsonb->'approval'->>'ready')::boolean,'global legal blockers/count and closed financial gate preserved');
SELECT is(pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'attention',NULL,30,'c4a85000-0000-4000-8000-000000000002','I31')->'detail'->>'code','I02','authorized healthy detail remains accessible despite attention/search');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.all')::jsonb->'employees')x WHERE x ?| ARRAY['lines','unresolved_parts','dated_rates','source_days','source_coverage_days']),'list keeps private source and formula fields redacted');
SELECT is(pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'attention',NULL,30,NULL,'I02')->'review_filter'->>'matching_count','0','healthy employee search has no attention result');
SELECT is(pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'all',NULL,30,NULL,'I02')->'employees'->0->>'code','I02','same healthy search works in all view');
SELECT set_config('test.many',pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_mar')::uuid)::text,true);
SELECT ok(jsonb_array_length(current_setting('test.many')::jsonb->'employees')=30 AND (current_setting('test.many')::jsonb->'review_filter'->>'has_more')::boolean,'thirty-five attention employees expose real next page');
SELECT set_config('test.last',pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_mar')::uuid,'attention',(current_setting('test.many')::jsonb->'review_filter'->>'next_after')::uuid)::text,true);
SELECT ok(jsonb_array_length(current_setting('test.last')::jsonb->'employees')=5 AND current_setting('test.last')::jsonb->'review_filter'->>'matching_count'='35' AND NOT(current_setting('test.last')::jsonb->'review_filter'->>'has_more')::boolean,'last attention page keeps full matching count and ends pagination');
SELECT is(pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_mar')::uuid,'attention',NULL,1,NULL,'I3')->'review_filter'->>'matching_count','6','search count applies before cursor and limit');
SELECT is(pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid)->'variance','null'::jsonb,'unavailable comparison is explicit rather than assumed zero');
SELECT set_config('test.comp',pg_temp.ws('c4a83000-0000-4000-8000-000000000002',current_setting('test.comp_mar')::uuid)::text,true);
SELECT is((current_setting('test.comp')::jsonb->'review_filter'->>'attention_count')::int,6,'eligible comparable review shows five changed employees and one new hire');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_setting('test.comp')::jsonb->'employees')x WHERE x->>'gross_difference'='0'),'unchanged zero-difference employees excluded from attention');
SELECT ok((SELECT count(*) FROM jsonb_array_elements(current_setting('test.comp')::jsonb->'employees')x WHERE (x->>'new_employee')::boolean)=1 AND current_setting('test.comp')::jsonb->'variance'->>'changed_employee_count'='6','new hire annotation and comparison count use entire candidate');
SELECT public.payroll_save_input('c4a81000-0000-4000-8000-000000000001','c4a83000-0000-4000-8000-000000000002','policy',NULL,NULL,NULL,0,'2030-03-01',NULL,'{"mode":"calendar_days","reason":"QA current-source change"}','save',gen_random_uuid());
SELECT set_config('test.stale',pg_temp.ws('c4a83000-0000-4000-8000-000000000002',current_setting('test.comp_mar')::uuid)::text,true);
SELECT ok(jsonb_array_length(current_setting('test.stale')::jsonb->'stale_reasons')>0 AND jsonb_array_length(current_setting('test.stale')::jsonb->'employees')=0,'current staleness suppresses comparison attention');
SELECT pg_temp.compare_legacy('c4a83000-0000-4000-8000-000000000002',current_setting('test.comp_mar')::uuid,'legacy stale comparison behavior remains equal to original');
SELECT set_config('request.jwt.claim.sub','c4a80000-0000-4000-8000-000000000002',true);
SELECT lives_ok($$SELECT pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid)$$,'review-only member can read queue without prepare permission');
SELECT throws_ok($$SELECT pg_temp.ws('c4a83000-0000-4000-8000-000000000003',current_setting('test.issue_period')::uuid)$$,'42501','payroll_forbidden','other employer cannot reuse this period');
SELECT throws_ok($$SELECT pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid,'attention',NULL,30,'c4a86000-0000-4000-8000-000000000001')$$,'42501','payroll_forbidden','detail cannot cross employer even when actor can review both');
SELECT set_config('request.jwt.claim.sub','c4a80000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT pg_temp.ws('c4a83000-0000-4000-8000-000000000001',current_setting('test.issue_period')::uuid)$$,'42501','payroll_forbidden','actor without membership denied');
SELECT throws_ok($$SELECT public.payroll_run_review_workspace('c4a81000-0000-4000-8000-000000000002','c4a83000-0000-4000-8000-000000000004',current_setting('test.issue_period')::uuid)$$,'42501','payroll_forbidden','cross-tenant access denied');
RESET ROLE;
-- Locked output behavior is NOT fabricated here; actual retained locked-run
-- read and browser acceptance remain separately required. No financial events.
SELECT * FROM finish();
ROLLBACK;
