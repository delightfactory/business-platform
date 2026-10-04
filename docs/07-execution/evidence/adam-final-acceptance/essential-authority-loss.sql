BEGIN;SELECT no_plan();
CREATE FUNCTION pg_temp.denied(command text) RETURNS text LANGUAGE plpgsql AS $$BEGIN EXECUTE command;RETURN 'SUCCEEDED';EXCEPTION WHEN OTHERS THEN RETURN SQLSTATE;END$$;
CREATE FUNCTION pg_temp.money() RETURNS jsonb LANGUAGE plpgsql AS $$DECLARE r record;result jsonb='{}';v text;BEGIN FOR r IN SELECT schemaname,tablename FROM pg_tables WHERE schemaname IN('payroll','employee_finance','people') LOOP EXECUTE format('SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,''[]'')) FROM %I.%I t',r.schemaname,r.tablename) INTO v;result:=result||jsonb_build_object(r.schemaname||'.'||r.tablename,v);END LOOP;RETURN result;END$$;
SELECT set_config('task.before',pg_temp.money()::text,true);
CREATE TEMP TABLE commands(label text,command text);INSERT INTO commands VALUES
('payment_prepare',$q$SELECT public.payroll_payment_request_prepare('d7001000-0000-4000-8000-000000000001','d7003000-0000-4000-8000-000000000001','25932316-f29c-4f9b-8b1e-565b97d2156f',gen_random_uuid(),'{}')$q$),
('correction_command',$q$SELECT public.payroll_correction_command('d7001000-0000-4000-8000-000000000001','d7003000-0000-4000-8000-000000000001','0cc3217c-3355-4bde-ae7f-0552431cac5f',4,'release','NONLEGAL forbidden authority check',gen_random_uuid())$q$),
('advance_command',$q$SELECT public.payroll_advance_command('d7001000-0000-4000-8000-000000000001','d7003000-0000-4000-8000-000000000001','{"operation":"save","advance":"d7008000-0000-4000-8000-000000000099","employment":"d7006000-0000-4000-8000-000000000001","expected":0,"data":{"principal":"25.00","count":"1","first_period":"4dd27e57-fed6-4b86-a929-04e33f0e843c","effective_on":"2026-08-01","reason":"NONLEGAL denied request"}}',gen_random_uuid())$q$);
GRANT SELECT ON commands TO authenticated;
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='d7001000-0000-4000-8000-000000000001' AND user_id='d6800000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub','d6800000-0000-4000-8000-000000000001',true);
SELECT is(pg_temp.denied(command),'42501','inactive membership denies '||label) FROM commands;
RESET ROLE;SELECT is(pg_temp.money(),current_setting('task.before')::jsonb,'inactive denials preserve all money/People/receipts');
UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id='d7001000-0000-4000-8000-000000000001' AND user_id='d6800000-0000-4000-8000-000000000001';
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='d7001000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.denied($q$SELECT public.payroll_run_command('d7001000-0000-4000-8000-000000000001','d7003000-0000-4000-8000-000000000001','4dd27e57-fed6-4b86-a929-04e33f0e843c',NULL,0,'calculate','NONLEGAL disabled payroll refusal',gen_random_uuid())$q$),'55000','payroll entitlement loss blocks new run operation');
SELECT is(pg_temp.denied(command),'22023','historical payment authority reaches request validation per frozen entitlement policy') FROM commands WHERE label='payment_prepare';
SELECT is(pg_temp.denied(command),'PT409','historical correction authority reaches completed-case state guard per frozen entitlement policy') FROM commands WHERE label='correction_command';
RESET ROLE;
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES('d7001000-0000-4000-8000-000000000001','hr.employee_finance',true,clock_timestamp()-interval '1 minute','d6800000-0000-4000-8000-000000000001','NONLEGAL bounded rollback capability-loss fixture');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='d7001000-0000-4000-8000-000000000001' AND capability_key='hr.employee_finance';
SET LOCAL ROLE authenticated;SELECT is(pg_temp.denied(command),'55000','finance entitlement loss denies new advance save') FROM commands WHERE label='advance_command';
RESET ROLE;SELECT is(pg_temp.money(),current_setting('task.before')::jsonb,'entitlement denials preserve all money/People/receipts');
SELECT * FROM finish();ROLLBACK;