BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e5000000-0000-4000-8000-000000000001','switch-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('e5000000-0000-4000-8000-000000000002','switch-outsider@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access)
VALUES ('e5000000-0000-4000-8000-000000000001',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
SELECT ('e6000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Switch test '||n,'e5000000-0000-4000-8000-000000000001'
FROM generate_series(1,4) n;

CREATE FUNCTION pg_temp.expected_services(tenant uuid) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_object_agg(e->>'capability_key',jsonb_build_object('valid_from',e->'valid_from','is_granted',e->'is_granted'))
 FROM jsonb_array_elements(public.platform_tenant_entitlement_snapshot(tenant)->'entitlements') e;
$$;
CREATE FUNCTION pg_temp.change_services(tenant uuid,changes jsonb) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.set_tenant_capability_entitlements(tenant,changes,pg_temp.expected_services(tenant));
$$;
-- Presentation-only last_day is not submitted as a second duration input.
CREATE FUNCTION pg_temp.confirmation_changes(plan jsonb) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_agg(jsonb_build_object('capability_key',e->'capability_key','is_granted',e->'is_granted','duration',e->'duration',
   'valid_until',CASE WHEN e->>'duration'='exact' THEN e->'valid_until' ELSE 'null'::jsonb END,
   'last_day',CASE WHEN e->>'duration'='last_day' THEN e->'last_day' ELSE 'null'::jsonb END))
 FROM jsonb_array_elements(plan) e;
$$;
CREATE TEMP TABLE receipts(name text PRIMARY KEY, result jsonb);
GRANT ALL ON receipts TO authenticated;

SELECT ok(NOT has_function_privilege('anon','public.set_tenant_capability_entitlements(uuid,jsonb,jsonb,text)','EXECUTE'),
 'anonymous users cannot mutate services');
SELECT ok(NOT has_function_privilege('service_role','public.set_tenant_capability_entitlements(uuid,jsonb,jsonb,text)','EXECUTE'),
 'service_role is not a service-switch authority');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000001',true);
INSERT INTO receipts VALUES ('initial',pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.payroll","is_granted":true,"duration":"resume"}]'));
SELECT is((SELECT result->>'outcome' FROM receipts WHERE name='initial'),'plan_required','payroll with no People produces an approval plan');
SELECT is((SELECT jsonb_array_length(result->'plan') FROM receipts WHERE name='initial'),2,'initial plan includes exactly People and Payroll');
INSERT INTO receipts VALUES ('enabled',pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 (SELECT pg_temp.confirmation_changes(result->'plan') FROM receipts WHERE name='initial')));
SELECT is((SELECT result->>'outcome' FROM receipts WHERE name='enabled'),'changed','approved dependency plan commits atomically');
SELECT is((SELECT jsonb_array_length(result->'changed') FROM receipts WHERE name='enabled'),2,'both planned services changed');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.payroll","is_granted":true,"duration":"resume"}]')->>'outcome','unchanged','matching desired state is an honest no-op');
SELECT lives_ok($$SELECT public.change_tenant_capability_entitlement('e6000000-0000-4000-8000-000000000001','hr.leave',true,NULL,'legacy leave allocation')$$,
 'legacy reason-required grants remain compatible');
SELECT lives_ok($$SELECT public.change_tenant_capability_entitlement('e6000000-0000-4000-8000-000000000001','hr.employee_finance',true,NULL,'legacy finance allocation')$$,
 'finance allocation participates in the existing evaluator');
INSERT INTO receipts VALUES ('shorten',pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.people","is_granted":true,"duration":"last_day","last_day":"2026-11-01"}]'));
SELECT is((SELECT result->>'outcome' FROM receipts WHERE name='shorten'),'plan_required','shortening People needs approval for dependent deadlines');
SELECT is((SELECT jsonb_array_length(result->'plan') FROM receipts WHERE name='shorten'),4,'all three dependents are included, Attendance is independent');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 (SELECT pg_temp.confirmation_changes(result->'plan') FROM receipts WHERE name='shorten'))->>'outcome','changed',
 'original chosen date and server-derived exact dependent deadlines can be confirmed');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.payroll","is_granted":false,"duration":"indefinite"}]')->>'outcome','changed','ordinary OFF needs no reason');
SELECT throws_ok($$SELECT pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.payroll","is_granted":true,"duration":"exact","valid_until":"2026-11-02T00:00:00Z"}]')$$,
 '22023','tenant_entitlement_input_invalid','fabricated exact timestamp is rejected');
SELECT throws_ok($$SELECT pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.people","is_granted":true,"duration":"exact","valid_until":null}]')$$,
 '22023','tenant_entitlement_input_invalid','exact NULL cannot extend a finite allocation');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.payroll","is_granted":true,"duration":"resume"}]')->>'outcome','changed','ON resumes allocation after OFF');
SELECT is((SELECT (e->>'valid_until')::timestamptz FROM jsonb_array_elements(public.platform_tenant_entitlement_snapshot('e6000000-0000-4000-8000-000000000001')->'entitlements') e
 WHERE e->>'capability_key'='hr.payroll'),'2026-11-02'::timestamp AT TIME ZONE 'Africa/Cairo','OFF/ON preserves the original exact deadline');
INSERT INTO receipts VALUES ('old_expected',pg_temp.expected_services('e6000000-0000-4000-8000-000000000001'));
SELECT pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.attendance","is_granted":true,"duration":"indefinite"}]')->>'outcome';
SELECT is(public.set_tenant_capability_entitlements('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.attendance","is_granted":false,"duration":"indefinite"}]',
 (SELECT result FROM receipts WHERE name='old_expected'))->>'outcome','stale','an outdated expected state cannot overwrite a newer decision');
SELECT set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.set_tenant_capability_entitlements('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.attendance","is_granted":true,"duration":"indefinite"}]',(SELECT result FROM receipts WHERE name='old_expected'))$$,
 '42501','commercial_access_forbidden','matching desired state never bypasses authorization');
RESET ROLE;
SELECT ok((SELECT bool_and(reason IS NULL AND plan_id IS NOT NULL) FROM platform_core.tenant_capability_entitlement_audit_events
 WHERE tenant_id='e6000000-0000-4000-8000-000000000001' AND change_source IN ('operator_switch','operator_plan')),
 'new audit records carry explicit provenance rather than invented reasons');

-- Historical/expired cases are fixtures, never rewrites of actual audit history.
INSERT INTO platform_core.tenant_capability_entitlements
 (tenant_id,capability_key,is_granted,valid_from,valid_until,actor_user_id,reason,prior_grant_kind,prior_grant_until)
VALUES
 ('e6000000-0000-4000-8000-000000000002','hr.people',true,now()-interval '2 days',now()-interval '1 day','e5000000-0000-4000-8000-000000000001','expired People',NULL,NULL),
 ('e6000000-0000-4000-8000-000000000002','hr.attendance',true,now()-interval '2 days',now()-interval '1 day','e5000000-0000-4000-8000-000000000001','previous allocation',NULL,NULL),
 ('e6000000-0000-4000-8000-000000000002','hr.attendance',false,now()-interval '1 day',NULL,'e5000000-0000-4000-8000-000000000001','legacy deny',NULL,NULL),
 ('e6000000-0000-4000-8000-000000000003','hr.attendance',false,now()-interval '2 days',now()-interval '1 day','e5000000-0000-4000-8000-000000000001','temporary denial','finite',now()+interval '7 days 00:00:00.123456');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000001',true);
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000002',
 '[{"capability_key":"hr.payroll","is_granted":true,"duration":"resume"}]')->>'capability_key','hr.people','expired People within a plan requires an explicit duration');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000002',
 '[{"capability_key":"hr.attendance","is_granted":true,"duration":"resume"}]')->>'outcome','duration_required','legacy denial after a grant requires duration choice');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000002',
 '[{"capability_key":"hr.people","is_granted":false,"duration":"indefinite"}]')->>'outcome','changed','OFF after an expired grant is recorded normally');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000002',
 '[{"capability_key":"hr.people","is_granted":true,"duration":"resume"}]')->>'outcome','duration_required','OFF after expiry does not silently renew the elapsed allocation');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000003',
 '[{"capability_key":"hr.attendance","is_granted":true,"duration":"resume"}]')->>'outcome','changed','expired temporary denial resumes the preserved allocation');
SELECT is((SELECT (e->>'valid_until')::timestamptz FROM jsonb_array_elements(public.platform_tenant_entitlement_snapshot('e6000000-0000-4000-8000-000000000003')->'entitlements') e
 WHERE e->>'capability_key'='hr.attendance'),now()+interval '7 days 00:00:00.123456','resumed deadline keeps microsecond precision');
SELECT is(pg_temp.change_services('e6000000-0000-4000-8000-000000000003',
 jsonb_build_array(jsonb_build_object('capability_key','hr.attendance','is_granted',false,'duration','last_day',
 'last_day',(now() AT TIME ZONE 'Africa/Cairo')::date)))->>'outcome','changed','today is valid as the inclusive last day of a denial');
SELECT throws_ok($$SELECT pg_temp.change_services('e6000000-0000-4000-8000-000000000003',
 jsonb_build_array(jsonb_build_object('capability_key','hr.attendance','is_granted',false,'duration','last_day',
 'last_day',(now() AT TIME ZONE 'Africa/Cairo')::date-1)))$$,'22023','tenant_entitlement_expiry_invalid','yesterday is rejected by server time');
RESET ROLE;

-- A future descendant in the computed closure blocks the whole People OFF plan.
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()+interval '1 day'
WHERE tenant_id='e6000000-0000-4000-8000-000000000001' AND capability_key='hr.employee_finance' AND valid_until>clock_timestamp();
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('e6000000-0000-4000-8000-000000000001','hr.employee_finance',false,now()+interval '1 day','e5000000-0000-4000-8000-000000000001','scheduled denial');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.change_services('e6000000-0000-4000-8000-000000000001',
 '[{"capability_key":"hr.people","is_granted":false,"duration":"indefinite"}]')$$,
 '23P01','tenant_entitlement_future_conflict','a derived sibling future conflict blocks all writes');
RESET ROLE;
CREATE FUNCTION pg_temp.fail_service_plan_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN IF NEW.capability_key='hr.payroll' THEN RAISE EXCEPTION 'service_plan_audit_failure' USING ERRCODE='55000'; END IF; RETURN NEW; END;
$$;
CREATE TRIGGER fail_service_plan_audit BEFORE INSERT ON platform_core.tenant_capability_entitlement_audit_events
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_service_plan_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.change_services('e6000000-0000-4000-8000-000000000004',
 '[{"capability_key":"hr.people","is_granted":true,"duration":"indefinite"},{"capability_key":"hr.payroll","is_granted":true,"duration":"resume"}]')$$,
 '55000','service_plan_audit_failure','failure on the second audit entry rolls back the complete dependency plan');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_capability_entitlements WHERE tenant_id='e6000000-0000-4000-8000-000000000004'),
 0,'neither first nor second service persists after audit failure');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_capability_entitlement_audit_events WHERE tenant_id='e6000000-0000-4000-8000-000000000004'),
 0,'no partial audit plan persists');
ALTER TABLE platform_core.tenant_capability_entitlements DISABLE TRIGGER tenant_capability_entitlement_no_overlap;
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('e6000000-0000-4000-8000-000000000004','hr.employee_finance',true,now()-interval '2 days','e5000000-0000-4000-8000-000000000001','corrupt imported grant'),
 ('e6000000-0000-4000-8000-000000000004','hr.employee_finance',false,now()-interval '1 day','e5000000-0000-4000-8000-000000000001','corrupt imported denial');
ALTER TABLE platform_core.tenant_capability_entitlements ENABLE TRIGGER tenant_capability_entitlement_no_overlap;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.change_services('e6000000-0000-4000-8000-000000000004',
 '[{"capability_key":"hr.people","is_granted":true,"duration":"indefinite"}]')$$,
 '55000','tenant_entitlement_conflict','a parent plan cannot derive state from conflicting descendant rows');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
