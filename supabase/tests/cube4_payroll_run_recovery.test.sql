-- Actual public candidate/receipt and read-only reconciliation. No statutory net.
SELECT set_config('test.receipt',(SELECT to_jsonb(r)::text FROM payroll.command_receipts r WHERE result->>'candidate_id'=current_setting('test.run')::jsonb->>'candidate_id'),true);
SELECT set_config('test.pending.attempt',gen_random_uuid()::text,true);
CREATE FUNCTION pg_temp.recover(attempt uuid, reason text DEFAULT '') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_run_reconcile('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,NULL,0,'calculate',reason,attempt) $$;
GRANT EXECUTE ON FUNCTION pg_temp.recover(uuid,text) TO authenticated;
SELECT set_config('test.before.candidates',(SELECT count(*)::text FROM payroll.candidates),true);
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.recover((current_setting('test.receipt')::jsonb->>'attempt_key')::uuid)->>'outcome','committed','lost response resolves the actual original receipt');
SELECT is(pg_temp.recover((current_setting('test.receipt')::jsonb->>'attempt_key')::uuid)->'result',current_setting('test.receipt')::jsonb->'result','exact original saved result returned');
SELECT throws_ok($$SELECT pg_temp.recover((current_setting('test.receipt')::jsonb->>'attempt_key')::uuid,'Changed reason')$$,'PT409','payroll_attempt_conflict','receipt cannot be recovered under another intent');
SELECT is(pg_temp.recover(current_setting('test.pending.attempt')::uuid)->>'outcome','closed_uncommitted','unknown uncommitted attempt closes without execution');
SELECT is(pg_temp.recover(current_setting('test.pending.attempt')::uuid)->>'outcome','closed_uncommitted','closure reconciliation is idempotent');
SELECT throws_ok($$SELECT public.payroll_run_command('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,NULL,0,'calculate','',current_setting('test.pending.attempt')::uuid)$$,'PT409','payroll_attempt_closed','late original writer is fenced before stale/candidate handling');
SELECT throws_ok($$SELECT pg_temp.recover(current_setting('test.pending.attempt')::uuid,'Changed reason')$$,'PT409','payroll_attempt_conflict','closed identity cannot be reused under changed intent');
SELECT throws_ok($$SELECT public.payroll_run_reconcile('c4421000-0000-4000-8000-000000000001','c4423000-0000-4000-8000-000000000001',gen_random_uuid(),NULL,0,'calculate','',gen_random_uuid())$$,'42501','payroll_forbidden','foreign period cannot create a closure');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.candidates),current_setting('test.before.candidates')::bigint,'recovery neither repeats calculation nor changes candidate count');
SELECT is((SELECT count(*) FROM payroll.run_attempt_closures),1::bigint,'one durable immutable closure only');
SELECT is((SELECT count(*) FROM payroll.audit_events WHERE action='run_attempt_closed'),1::bigint,'closure audited once');
SELECT ok(NOT has_table_privilege('authenticated','payroll.run_attempt_closures','SELECT'),'closure table remains private');
SELECT ok(NOT has_function_privilege('authenticated','payroll.assert_run_attempt_open(uuid,uuid,uuid,jsonb)','EXECUTE'),'closure assertion remains private');
SELECT ok(NOT has_function_privilege('anon','public.payroll_run_reconcile(uuid,uuid,uuid,uuid,integer,text,text,uuid)','EXECUTE'),'anonymous recovery denied');
SELECT throws_ok($$UPDATE payroll.run_attempt_closures SET intent='{}'$$,'55000','payroll_immutable','closure history is immutable');
SELECT * FROM finish();
