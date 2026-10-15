BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e1000000-0000-4000-8000-000000000001','resume-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access)
VALUES ('e1000000-0000-4000-8000-000000000001',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e2000000-0000-4000-8000-000000000001','Resume test','e1000000-0000-4000-8000-000000000001');

SELECT is((SELECT kind FROM platform_private.entitlement_resume('e2000000-0000-4000-8000-000000000001','hr.people',now())),
  'first','no history permits an initial duration');
SELECT ok(NOT has_function_privilege('authenticated','platform_private.entitlement_resume(uuid,text,timestamptz)','EXECUTE'),
  'resume history helper is not callable by authenticated users');
SELECT ok(NOT has_function_privilege('anon','public.platform_tenant_entitlement_snapshot(uuid)','EXECUTE'),
  'snapshot remains unavailable to anonymous callers');

-- Separate capabilities exercise current, expired and historical denials.
INSERT INTO platform_core.tenant_capability_entitlements
  (tenant_id,capability_key,is_granted,valid_from,valid_until,actor_user_id,reason,prior_grant_kind,prior_grant_until)
VALUES
  ('e2000000-0000-4000-8000-000000000001','hr.people',true,now()-interval '2 days',now()+interval '7 days 00:00:00.123456','e1000000-0000-4000-8000-000000000001','finite allocation',NULL,NULL),
  ('e2000000-0000-4000-8000-000000000001','hr.payroll',false,now()-interval '1 day',NULL,'e1000000-0000-4000-8000-000000000001','off preserves allocation','finite',now()+interval '7 days 00:00:00.123456'),
  ('e2000000-0000-4000-8000-000000000001','hr.leave',false,now()-interval '2 days',now()-interval '1 day','e1000000-0000-4000-8000-000000000001','expired temporary denial','finite',now()+interval '7 days 00:00:00.123456'),
  ('e2000000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '2 days',now()-interval '1 day','e1000000-0000-4000-8000-000000000001','expired allocation',NULL,NULL),
  ('e2000000-0000-4000-8000-000000000001','hr.employee_finance',true,now()-interval '2 days',now()-interval '1 day','e1000000-0000-4000-8000-000000000001','old closed grant',NULL,NULL),
  ('e2000000-0000-4000-8000-000000000001','hr.employee_finance',false,now()-interval '1 day',NULL,'e1000000-0000-4000-8000-000000000001','legacy denial',NULL,NULL);

SELECT is((SELECT kind FROM platform_private.entitlement_resume('e2000000-0000-4000-8000-000000000001','hr.people',now())),
  'finite','current finite grant is resumable');
SELECT is((SELECT until_at FROM platform_private.entitlement_resume('e2000000-0000-4000-8000-000000000001','hr.payroll',now())),
  now()+interval '7 days 00:00:00.123456','OFF metadata preserves the exact microsecond deadline');
SELECT is((SELECT kind FROM platform_private.entitlement_resume('e2000000-0000-4000-8000-000000000001','hr.leave',now())),
  'finite','expired temporary denial retains its earlier allocation');
SELECT is((SELECT kind FROM platform_private.entitlement_resume('e2000000-0000-4000-8000-000000000001','hr.payroll',now()+interval '8 days')),
  'expired','elapsed preserved allocation requires explicit renewal');
SELECT is((SELECT kind FROM platform_private.entitlement_resume('e2000000-0000-4000-8000-000000000001','hr.attendance',now())),
  'expired','elapsed grant cannot be silently renewed');
SELECT is((SELECT kind FROM platform_private.entitlement_resume('e2000000-0000-4000-8000-000000000001','hr.employee_finance',now())),
  'unknown','legacy denial after a grant does not guess its previous deadline');

SELECT throws_ok($$INSERT INTO platform_core.tenant_capability_entitlements
  (tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason,prior_grant_until)
  VALUES ('e2000000-0000-4000-8000-000000000001','hr.attendance',false,now(),'e1000000-0000-4000-8000-000000000001','invalid unknown metadata',now()+interval '1 day')$$,
  '23514',NULL,'NULL metadata kind cannot carry a fabricated deadline');
SELECT throws_ok($$INSERT INTO platform_core.tenant_capability_entitlements
  (tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason,prior_grant_kind)
  VALUES ('e2000000-0000-4000-8000-000000000001','hr.attendance',false,now(),'e1000000-0000-4000-8000-000000000001','invalid finite metadata','finite')$$,
  '23514',NULL,'finite metadata requires a deadline');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
SELECT is(jsonb_array_length(public.platform_tenant_entitlement_snapshot('e2000000-0000-4000-8000-000000000001')->'entitlements'),
  5,'snapshot retains all five services');
SELECT is((SELECT e->>'resume_kind' FROM jsonb_array_elements(public.platform_tenant_entitlement_snapshot('e2000000-0000-4000-8000-000000000001')->'entitlements') e WHERE e->>'capability_key'='hr.employee_finance'),
  'unknown','authorized snapshot exposes honest legacy duration uncertainty');
SELECT is((SELECT e->>'evaluator_enabled' FROM jsonb_array_elements(public.platform_tenant_entitlement_snapshot('e2000000-0000-4000-8000-000000000001')->'entitlements') e WHERE e->>'capability_key'='hr.leave'),
  'false','expired denial does not auto-enable a service');
RESET ROLE;

-- Cairo's 2026 autumn transition has a 25-hour local day. Inclusive dates
-- must come from the stored instant, not browser timezone arithmetic.
SELECT is(extract(epoch FROM (('2026-10-30'::timestamp AT TIME ZONE 'Africa/Cairo')-
  ('2026-10-29'::timestamp AT TIME ZONE 'Africa/Cairo')))::integer,90000,
  'Cairo autumn transition retains the 25-hour day');
SELECT is(((('2026-10-30'::timestamp AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'Africa/Cairo')-
  interval '1 microsecond')::date,'2026-10-29'::date,'inclusive last day survives Cairo DST transition');

SELECT * FROM finish();
ROLLBACK;
