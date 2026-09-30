BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('f1100000-0000-4000-8000-000000000001','import-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('f1100000-0000-4000-8000-000000000002','import-viewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('f1100000-0000-4000-8000-000000000003','import-no-pay-view@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('f2200000-0000-4000-8000-000000000001','Import Tenant','f1100000-0000-4000-8000-000000000001'),
 ('f2200000-0000-4000-8000-000000000002','Other Tenant','f1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('f2200000-0000-4000-8000-000000000001','f3300000-0000-4000-8000-000000000001','import.admin',1,ARRAY['tenant.administer']),
 ('f2200000-0000-4000-8000-000000000001','f3300000-0000-4000-8000-000000000002','import.viewer',1,ARRAY['people.view']),
 ('f2200000-0000-4000-8000-000000000001','f3300000-0000-4000-8000-000000000003','import.no-pay-view',1,
   ARRAY['people.manage','employment.manage','compensation.manage','workforce_import.execute']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('f2200000-0000-4000-8000-000000000001','f1100000-0000-4000-8000-000000000001','f1100000-0000-4000-8000-000000000001'),
 ('f2200000-0000-4000-8000-000000000001','f1100000-0000-4000-8000-000000000002','f1100000-0000-4000-8000-000000000001'),
 ('f2200000-0000-4000-8000-000000000001','f1100000-0000-4000-8000-000000000003','f1100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('f2200000-0000-4000-8000-000000000001','f1100000-0000-4000-8000-000000000001','f3300000-0000-4000-8000-000000000001'),
 ('f2200000-0000-4000-8000-000000000001','f1100000-0000-4000-8000-000000000002','f3300000-0000-4000-8000-000000000002'),
 ('f2200000-0000-4000-8000-000000000001','f1100000-0000-4000-8000-000000000003','f3300000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES
 ('f2200000-0000-4000-8000-000000000001','f4400000-0000-4000-8000-000000000001','Employer A',true),
 ('f2200000-0000-4000-8000-000000000002','f4400000-0000-4000-8000-000000000002','Foreign Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES
 ('f2200000-0000-4000-8000-000000000001','f5500000-0000-4000-8000-000000000001','f4400000-0000-4000-8000-000000000001','Main Branch',true),
 ('f2200000-0000-4000-8000-000000000002','f5500000-0000-4000-8000-000000000002','f4400000-0000-4000-8000-000000000002','Foreign Branch',true);
INSERT INTO people.departments(tenant_id,id,code,name,is_active) VALUES
 ('f2200000-0000-4000-8000-000000000001','f6600000-0000-4000-8000-000000000001','OPS','Operations',true),
 ('f2200000-0000-4000-8000-000000000001','f6600000-0000-4000-8000-000000000002','OFF','Inactive Dept',false),
 ('f2200000-0000-4000-8000-000000000001','f6600000-0000-4000-8000-000000000003','SALES','Sales',true);
INSERT INTO people.jobs(tenant_id,id,code,name,department_id,is_active) VALUES
 ('f2200000-0000-4000-8000-000000000001','f7700000-0000-4000-8000-000000000001','CASH','Cashier','f6600000-0000-4000-8000-000000000001',true),
 ('f2200000-0000-4000-8000-000000000001','f7700000-0000-4000-8000-000000000002','MGR','Manager',NULL,true),
 ('f2200000-0000-4000-8000-000000000001','f7700000-0000-4000-8000-000000000003','SALESREP','Sales Representative','f6600000-0000-4000-8000-000000000003',true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('f2200000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute',
  'f1100000-0000-4000-8000-000000000001','Import test entitlement');

SELECT ok(NOT has_function_privilege('anon','public.preview_people_workforce_import(uuid,jsonb)','EXECUTE'),
  'signed-out users cannot preview employee imports');
SELECT ok(NOT has_table_privilege('authenticated','people.employees','INSERT'),
  'import does not grant direct employee table writes');
SELECT ok(pg_catalog.strpos(pg_catalog.pg_get_functiondef('public.confirm_people_workforce_import(uuid,jsonb)'::regprocedure),'pg_advisory_xact_lock')
    < pg_catalog.strpos(pg_catalog.pg_get_functiondef('public.confirm_people_workforce_import(uuid,jsonb)'::regprocedure),'workforce_import.execute'),
  'confirmation rechecks import permission after acquiring the tenant locks');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1100000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001','[]'::jsonb)$$,
  '42501','people_import_forbidden','people.view alone cannot inspect salary-bearing import preview');
SELECT set_config('request.jwt.claim.sub','f1100000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001','[]'::jsonb)$$,
  '42501','people_import_forbidden','import requires compensation.view');
SELECT set_config('request.jwt.claim.sub','f1100000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000002','[]'::jsonb)$$,
  '42501','people_import_forbidden','import is denied outside the authorized Tenant');
SELECT throws_ok($$SELECT public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001','[]'::jsonb)$$,
  '22023','people_import_payload_invalid','empty preview batches are rejected');
SELECT set_config('test.preview',public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":2,"employee_code":"CSV-1","full_name":"Ready Worker","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"2500.00","payroll_eligible":"true","department_code":"OPS","job_code":"CASH"}]')::text,true);
SELECT is(current_setting('test.preview')::jsonb->0->>'status','ready','valid row receives ready preview');
SELECT is((current_setting('test.preview')::jsonb->0->>'importable')::boolean,true,'ready row is importable');
RESET ROLE;
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.employees WHERE tenant_id='f2200000-0000-4000-8000-000000000001'),0,
  'preview never writes employee data');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1100000-0000-4000-8000-000000000001',true);
SELECT is((public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":3,"employee_code":"CSV-2","full_name":"Default Worker","employer_name":"","site_name":"","start_date":"2026-09-30","pay_basis":"daily","base_amount":"100","payroll_eligible":"false","department_code":"","job_code":""}]')->0->>'status'),
  'warning','single safe employer/site defaults require an explicit warning review');
SELECT ok((public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":4,"employee_code":"CSV-3","full_name":"Bad Employer","employer_name":"Foreign Employer","site_name":"Foreign Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true"}]')->0->'errors') @> '["جهة التوظيف غير نشطة أو غير معروفة أو اسمها غير فريد."]'::jsonb,
  'cross-Tenant employer name is rejected');
SELECT is((public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":5,"employee_code":"CSV-4","full_name":"Inactive Department","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true","department_code":"OFF"}]')->0->>'status'),
  'rejected','inactive department code is rejected');
SELECT is((public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":6,"employee_code":"CSV-5","full_name":"Wrong Job","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true","department_code":"OPS","job_code":"SALESREP"}]')->0->>'status'),
  'rejected','job and department mismatch is rejected');
SELECT is((public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":6,"employee_code":"CSV-6","full_name":"=1+1","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true"}]')->0->>'status'),
  'rejected','formula-like cell values are rejected before import');
SELECT is((SELECT pg_catalog.count(*) FROM pg_catalog.jsonb_array_elements(public.preview_people_workforce_import(
  'f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":7,"employee_code":"CSV-DUP","full_name":"Duplicate One","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true"},{"source_row_number":8,"employee_code":"csv-dup","full_name":"Duplicate Two","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true"}]')) AS r(value) WHERE r.value->>'status'='rejected'),2::bigint,
  'duplicate codes in one file reject every matching row');

SELECT set_config('test.partial',public.confirm_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":10,"employee_code":"CSV-10","full_name":"Atomic Good","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true"},{"source_row_number":11,"employee_code":"CSV-11","full_name":"Atomic Bad","employer_name":"Wrong","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true"}]')::text,true);
SELECT is(current_setting('test.partial')::jsonb->>'state','stale','stale selected row returns a failed batch result');
SELECT is((current_setting('test.partial')::jsonb->>'imported_count')::integer,0,'stale selected rows import zero employees');
RESET ROLE;
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.employees WHERE tenant_id='f2200000-0000-4000-8000-000000000001'),0,
  'one rejected selected row rolls back all selected employees');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1100000-0000-4000-8000-000000000001',true);
SELECT set_config('test.success',public.confirm_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":12,"employee_code":"CSV-A","full_name":"Import A","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"2500.00","payroll_eligible":"true","department_code":"OPS","job_code":"CASH"},{"source_row_number":13,"employee_code":"CSV-B","full_name":"Import B","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"daily","base_amount":"180.50","payroll_eligible":"false","department_code":"","job_code":""}]')::text,true);
SELECT is(current_setting('test.success')::jsonb->>'state','imported','selected ready rows are committed together');
SELECT is((current_setting('test.success')::jsonb->>'imported_count')::integer,2,'commit reports imported row count');
RESET ROLE;
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.employees WHERE tenant_id='f2200000-0000-4000-8000-000000000001'),2,
  'all selected employees were inserted');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.employments WHERE tenant_id='f2200000-0000-4000-8000-000000000001'),2,
  'matching Employments were inserted');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.work_assignments WHERE tenant_id='f2200000-0000-4000-8000-000000000001'),2,
  'matching initial assignments were inserted');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.compensation_versions WHERE tenant_id='f2200000-0000-4000-8000-000000000001'),2,
  'matching base compensation records were inserted');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.audit_events WHERE tenant_id='f2200000-0000-4000-8000-000000000001'
  AND details->>'source'='workforce_csv_import' AND actor_user_id='f1100000-0000-4000-8000-000000000001'),2,
  'one actor audit event is written per imported Employee');
SELECT is((SELECT pg_catalog.count(*)::integer FROM people.audit_events WHERE tenant_id='f2200000-0000-4000-8000-000000000001'
  AND details->>'source'='workforce_csv_import' AND details ? 'source_row_number'),0,
  'client source line hint is not stored as verified audit provenance');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f1100000-0000-4000-8000-000000000001',true);
SELECT is((public.preview_people_workforce_import('f2200000-0000-4000-8000-000000000001',
  '[{"source_row_number":14,"employee_code":"csv-a","full_name":"Already Imported","employer_name":"Employer A","site_name":"Main Branch","start_date":"2026-09-30","pay_basis":"monthly","base_amount":"100","payroll_eligible":"true"}]')->0->>'status'),
  'rejected','employee codes already present in the Tenant are rejected');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
