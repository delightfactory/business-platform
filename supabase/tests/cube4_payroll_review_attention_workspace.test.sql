BEGIN;
DO $$ BEGIN
  IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN
    RAISE EXCEPTION 'Cube4 dedicated QA identity required';
  END IF;
END $$;
SELECT no_plan();

-- Contract-level negative checks use the real public RPC and roll back. They do
-- not invent a statutory candidate and are not UX acceptance. Candidate-backed
-- attention/pagination/comparison/search/cursor/full-scope/detail cases remain
-- UNVERIFIED in this bounded pass, including zero-difference exclusion,
-- matching_count stability across pages, stale comparison, and locked privacy.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.payroll_run_review_workspace(
  '00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000003',NULL,30,NULL,'',NULL)$$,
  '22023','payroll_invalid','NULL review view is rejected');
SELECT throws_ok($$SELECT public.payroll_run_review_workspace(
  '00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000003',NULL,30,NULL,'','unexpected')$$,
  '22023','payroll_invalid','unknown review view is rejected');
RESET ROLE;

SELECT ok(NOT EXISTS(
  SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) a
  WHERE p.oid='payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean)'::regprocedure
    AND a.grantee=0 AND a.privilege_type='EXECUTE'
),'private core is not executable by PUBLIC');
SELECT ok(has_function_privilege('anon','payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean)','EXECUTE') IS FALSE,'private core is not executable by anon');
SELECT ok(has_function_privilege('authenticated','payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean)','EXECUTE') IS FALSE,'private core is not executable by authenticated');
SELECT ok(has_function_privilege('authenticated','public.payroll_run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,text)','EXECUTE'),'named review RPC is executable only through authenticated wrapper');
SELECT * FROM finish();
ROLLBACK;
