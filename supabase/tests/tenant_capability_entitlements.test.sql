BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('d1000000-0000-4000-8000-000000000001','entitlement-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d1000000-0000-4000-8000-000000000002','entitlement-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access)
VALUES ('d1000000-0000-4000-8000-000000000001',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d2000000-0000-4000-8000-000000000001','Entitlement Test','d1000000-0000-4000-8000-000000000001'),
       ('d2000000-0000-4000-8000-000000000002','Corrupt Entitlement Test','d1000000-0000-4000-8000-000000000001');

SELECT has_function('public','platform_tenant_entitlement_snapshot',ARRAY['uuid']::name[],'Operator entitlement snapshot exists');
SELECT has_function('public','change_tenant_capability_entitlement',ARRAY['uuid','text','boolean','date','text']::name[],'bounded entitlement command exists');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_capability_entitlements','INSERT'),'authenticated cannot insert entitlements directly');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_capability_entitlement_audit_events','UPDATE'),'authenticated cannot rewrite entitlement audit');
SELECT ok(NOT has_function_privilege('anon','public.change_tenant_capability_entitlement(uuid,text,boolean,date,text)','EXECUTE'),'anonymous callers cannot change entitlements');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
SELECT ok(public.current_operator_can_manage_commercial_access(),'commercial Operator can manage entitlement decisions');
SELECT is((SELECT e->>'status' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_entitlement_snapshot('d2000000-0000-4000-8000-000000000001')->'entitlements') e WHERE e->>'capability_key'='hr.people'),'missing','optional People capability defaults denied');
SELECT is((SELECT e->>'evaluator_enabled' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_entitlement_snapshot('d2000000-0000-4000-8000-000000000001')->'entitlements') e WHERE e->>'capability_key'='hr.payroll'),'false','missing payroll capability evaluates disabled');
SELECT throws_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.other',true,NULL,'invalid key')$$,
  '22023','tenant_entitlement_input_invalid','only the bounded V1 keys are accepted');
SELECT throws_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.people',true,NULL,' ')$$,
  '22023','tenant_entitlement_reason_required','every decision requires a reason');
SELECT throws_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.payroll',true,NULL,'without People')$$,
  '23514','tenant_entitlement_people_required','Payroll cannot be granted while People is absent');
SELECT lives_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.people',true,NULL,'enable people')$$,
  'People grant is recorded');
SELECT lives_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.payroll',true,NULL,'enable payroll')$$,
  'Payroll grant is permitted while People remains enabled');
SELECT throws_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.people',false,CURRENT_DATE+7,'expire after a week')$$,
  '23514','tenant_entitlement_payroll_must_end_first','People denial is rejected while Payroll is effective, regardless of denial expiry');
SELECT throws_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.people',true,CURRENT_DATE+1,'shorten People')$$,
  '23514','tenant_entitlement_payroll_must_end_first','People cannot be shortened across the active Payroll interval');
SELECT lives_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.payroll',false,NULL,'disable payroll first')$$,
  'Payroll can be denied before People');
SELECT lives_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.people',false,NULL,'disable People second')$$,
  'People can be denied after Payroll ends');
SELECT is((SELECT e->>'evaluator_enabled' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_entitlement_snapshot('d2000000-0000-4000-8000-000000000001')->'entitlements') e WHERE e->>'capability_key'='hr.people'),'false','effective denial evaluates disabled');
RESET ROLE;

SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_capability_entitlement_audit_events
  WHERE tenant_id='d2000000-0000-4000-8000-000000000001'),4,'each successful change has its own audit event');
SELECT is((SELECT reason FROM platform_core.tenant_capability_entitlement_audit_events
  WHERE tenant_id='d2000000-0000-4000-8000-000000000001' ORDER BY id DESC LIMIT 1),'disable People second','audit stores the required reason');
SELECT ok((SELECT e.valid_until = following.valid_from FROM platform_core.tenant_capability_entitlements e
  JOIN platform_core.tenant_capability_entitlements following ON following.tenant_id=e.tenant_id AND following.capability_key=e.capability_key
    AND following.valid_from > e.valid_from
  WHERE e.tenant_id='d2000000-0000-4000-8000-000000000001' AND e.capability_key='hr.people' LIMIT 1),
  'superseded and replacement intervals meet exactly without overlap');
SELECT throws_ok($$INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
  VALUES ('d2000000-0000-4000-8000-000000000001','hr.people',true,pg_catalog.clock_timestamp()-interval '1 hour','d1000000-0000-4000-8000-000000000001','overlap attempt')$$,
  '23P01','tenant_entitlement_interval_overlap','overlapping decisions are rejected');

-- Simulate corrupted imported state. The evaluator must never pick one effective row.
ALTER TABLE platform_core.tenant_capability_entitlements DISABLE TRIGGER tenant_capability_entitlement_no_overlap;
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('d2000000-0000-4000-8000-000000000002','hr.payroll',true,pg_catalog.clock_timestamp()-interval '1 hour',
  'd1000000-0000-4000-8000-000000000001','corrupt fixture'),
 ('d2000000-0000-4000-8000-000000000002','hr.payroll',false,pg_catalog.clock_timestamp()-interval '30 minutes',
  'd1000000-0000-4000-8000-000000000001','corrupt fixture');
ALTER TABLE platform_core.tenant_capability_entitlements ENABLE TRIGGER tenant_capability_entitlement_no_overlap;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
SELECT is((SELECT e->>'status' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_entitlement_snapshot('d2000000-0000-4000-8000-000000000002')->'entitlements') e WHERE e->>'capability_key'='hr.payroll'),'conflict','multiple effective decisions are reported as corrupt');
SELECT is((SELECT e->>'evaluator_enabled' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_entitlement_snapshot('d2000000-0000-4000-8000-000000000002')->'entitlements') e WHERE e->>'capability_key'='hr.payroll'),'false','conflicting Payroll rows fail closed');
SELECT is((SELECT e->>'evaluator_enabled' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_entitlement_snapshot('d2000000-0000-4000-8000-000000000002')->'entitlements') e WHERE e->>'capability_key'='hr.people'),'false','missing People remains denied in the other Tenant');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.platform_tenant_entitlement_snapshot('d2000000-0000-4000-8000-000000000001')$$,
  '42501','commercial_access_forbidden','Tenant users cannot access Operator entitlement controls');
SELECT throws_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.people',true,NULL,'unauthorized')$$,
  '42501','commercial_access_forbidden','Tenant users cannot change commercial entitlement');
RESET ROLE;

CREATE FUNCTION pg_temp.fail_entitlement_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'entitlement_audit_failure' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER fail_entitlement_audit BEFORE INSERT ON platform_core.tenant_capability_entitlement_audit_events
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_entitlement_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.change_tenant_capability_entitlement('d2000000-0000-4000-8000-000000000001','hr.people',true,NULL,'audit rollback')$$,
  '55000','entitlement_audit_failure','audit failure rolls the decision back atomically');
RESET ROLE;
DROP TRIGGER fail_entitlement_audit ON platform_core.tenant_capability_entitlement_audit_events;
DROP FUNCTION pg_temp.fail_entitlement_audit();
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_capability_entitlements
  WHERE tenant_id='d2000000-0000-4000-8000-000000000001' AND capability_key='hr.people' AND valid_until IS NULL),1,
  'audit failure leaves the previous effective decision untouched');

SELECT * FROM finish();
ROLLBACK;
