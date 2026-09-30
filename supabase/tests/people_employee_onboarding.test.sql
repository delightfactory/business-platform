BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('e1000000-0000-4000-8000-000000000001','people-test-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('e1000000-0000-4000-8000-000000000002','people-test-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('e1000000-0000-4000-8000-000000000003','people-test-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('e2000000-0000-4000-8000-000000000001','People Test One','e1000000-0000-4000-8000-000000000001'),
 ('e2000000-0000-4000-8000-000000000002','People Test Two','e1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','people.test.admin',1,ARRAY['tenant.administer']),
 ('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000002','people.test.viewer',1,ARRAY['people.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000001'),
 ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000003','e1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','e3000000-0000-4000-8000-000000000001'),
 ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000003','e3000000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES
 ('e2000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','Employer One',true),
 ('e2000000-0000-4000-8000-000000000002','e4000000-0000-4000-8000-000000000002','Employer Two',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES
 ('e2000000-0000-4000-8000-000000000001','e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','Site One',true),
 ('e2000000-0000-4000-8000-000000000002','e5000000-0000-4000-8000-000000000002','e4000000-0000-4000-8000-000000000002','Site Two',true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('e2000000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute',
  'e1000000-0000-4000-8000-000000000001','People test entitlement');

SELECT ok(NOT has_table_privilege('authenticated','people.employees','SELECT'),'no direct employee table access');
SELECT ok(NOT has_table_privilege('authenticated','people.compensation_versions','SELECT'),'no direct salary table access');
SELECT ok(NOT has_function_privilege('anon','public.create_people_employee(uuid,text,text,uuid,uuid,date,text,numeric,boolean,uuid,uuid)','EXECUTE'),
  'signed-out users cannot create employees');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
SELECT lives_ok($$SELECT public.create_people_employee(
  'e2000000-0000-4000-8000-000000000001','EMP-1','Sample Worker',
  'e4000000-0000-4000-8000-000000000001','e5000000-0000-4000-8000-000000000001',
  CURRENT_DATE,'monthly',2500.00,true)$$,'employee, employment, assignment and salary save together');
SELECT is(pg_catalog.jsonb_array_length(public.people_directory('e2000000-0000-4000-8000-000000000001')),1,
  'authorized admin sees the saved employee');
SELECT throws_ok($$SELECT public.create_people_employee(
  'e2000000-0000-4000-8000-000000000001','EMP-2','Wrong Site',
  'e4000000-0000-4000-8000-000000000001','e5000000-0000-4000-8000-000000000002',
  CURRENT_DATE,'monthly',2500.00,true)$$,'23503','people_site_unavailable','cross-Tenant Site is denied');
SELECT throws_ok($$SELECT public.create_people_employee(
  'e2000000-0000-4000-8000-000000000002','EMP-3','Wrong Tenant',
  'e4000000-0000-4000-8000-000000000002','e5000000-0000-4000-8000-000000000002',
  CURRENT_DATE,'monthly',2500.00,true)$$,'42501','people_onboard_forbidden','other Tenant is denied');
SELECT throws_ok($$SELECT public.create_people_employee(
  'e2000000-0000-4000-8000-000000000001','EMP-1','Duplicate Worker',
  'e4000000-0000-4000-8000-000000000001','e5000000-0000-4000-8000-000000000001',
  CURRENT_DATE,'monthly',2500.00,true)$$,'23505','duplicate key value violates unique constraint "employees_code_per_tenant_idx"',
  'employee code is unique within a Tenant');
RESET ROLE;

SELECT is((SELECT pg_catalog.count(*)::integer FROM people.employees WHERE employee_code='EMP-1'),1,
  'one employee persists after rejections');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.employments WHERE tenant_id='e2000000-0000-4000-8000-000000000001'),1,
  'employment persisted');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.work_assignments WHERE tenant_id='e2000000-0000-4000-8000-000000000001'),1,
  'assignment persisted');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.compensation_versions WHERE tenant_id='e2000000-0000-4000-8000-000000000001'),1,
  'salary persisted without direct table access');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.audit_events WHERE tenant_id='e2000000-0000-4000-8000-000000000001'),1,
  'onboarding audit persisted');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000003',true);
SELECT is(pg_catalog.jsonb_array_length(public.people_directory('e2000000-0000-4000-8000-000000000001')),1,
  'People viewer can read the directory');
SELECT throws_ok($$SELECT public.people_compensation_snapshot('e2000000-0000-4000-8000-000000000001',
  (public.people_directory('e2000000-0000-4000-8000-000000000001')->0->>'id')::uuid)$$,
  '42501','compensation_view_forbidden','People viewer cannot read salary');
SELECT ok(NOT (public.people_employee_snapshot('e2000000-0000-4000-8000-000000000001',
  (public.people_directory('e2000000-0000-4000-8000-000000000001')->0->>'id')::uuid)
  ->'employment' ? 'pay_basis'),'People viewer does not receive pay basis');
SELECT ok(NOT (public.people_employee_snapshot('e2000000-0000-4000-8000-000000000001',
  (public.people_directory('e2000000-0000-4000-8000-000000000001')->0->>'id')::uuid)
  ->'employment' ? 'payroll_eligible'),'People viewer does not receive payroll eligibility');
SELECT throws_ok($$SELECT public.people_directory('e2000000-0000-4000-8000-000000000002')$$,
  '42501','people_view_forbidden','viewer cannot read another Tenant');
RESET ROLE;

CREATE FUNCTION pg_temp.fail_people_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'people_audit_failure' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER fail_people_audit BEFORE INSERT ON people.audit_events
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_people_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.create_people_employee(
  'e2000000-0000-4000-8000-000000000001','EMP-4','Rollback Worker',
  'e4000000-0000-4000-8000-000000000001','e5000000-0000-4000-8000-000000000001',
  CURRENT_DATE,'monthly',2500.00,true)$$,'55000','people_audit_failure','audit failure rolls back onboarding');
RESET ROLE;
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.employees WHERE employee_code='EMP-4'),0,
  'audit failure leaves no partial employee');
DROP TRIGGER fail_people_audit ON people.audit_events;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
SELECT lives_ok($$SELECT public.create_people_employee(
  'e2000000-0000-4000-8000-000000000001','EMP-FUTURE','Future Worker',
  'e4000000-0000-4000-8000-000000000001','e5000000-0000-4000-8000-000000000001',
  pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date + 7,
  'monthly',2500.00,true)$$,'future hire can be scheduled');
SELECT is((SELECT item->>'status' FROM pg_catalog.jsonb_array_elements(
  public.people_directory('e2000000-0000-4000-8000-000000000001')) item
  WHERE item->>'code'='EMP-FUTURE'),'scheduled','future hire is not active yet');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
