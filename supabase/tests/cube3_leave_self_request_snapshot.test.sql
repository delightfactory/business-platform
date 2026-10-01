BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,
  raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('d3070000-0000-4000-8000-000000000001','snapshot-view@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3070000-0000-4000-8000-000000000002','snapshot-request@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3070000-0000-4000-8000-000000000003','snapshot-relinked@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3070000-0000-4000-8000-000000000004','snapshot-inactive@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3070000-0000-4000-8000-000000000005','snapshot-unlinked@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());

INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('d3071000-0000-4000-8000-000000000001','Leave snapshot contract','d3070000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES
 ('d3071000-0000-4000-8000-000000000001','d3072000-0000-4000-8000-000000000001','leave.snapshot.view-only.v1',1,ARRAY['people.self.view','leave.self.view'],false),
 ('d3071000-0000-4000-8000-000000000001','d3072000-0000-4000-8000-000000000002','leave.snapshot.request.v1',1,ARRAY['people.self.view','leave.self.view','leave.self.request'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000001','active','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000002','active','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000003','active','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000004','inactive','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000005','active','d3070000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000001','d3072000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000002','d3072000-0000-4000-8000-000000000002'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000003','d3072000-0000-4000-8000-000000000002'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000004','d3072000-0000-4000-8000-000000000002'),
 ('d3071000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000005','d3072000-0000-4000-8000-000000000002');

INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('d3071000-0000-4000-8000-000000000001','d3073000-0000-4000-8000-000000000001','Snapshot Employer',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000001','SNAP-1','View only','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000002','SNAP-2','Request enabled','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000003','SNAP-3-OLD','Relinked old identity','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000004','SNAP-3-NEW','Relinked current identity','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000005','SNAP-4','Inactive member','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000006','SNAP-5-OLD','Former linked identity','d3070000-0000-4000-8000-000000000001');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id,linked_at,unlinked_by_user_id,unlinked_at)
VALUES ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000003',
  'd3070000-0000-4000-8000-000000000003','d3070000-0000-4000-8000-000000000001',now()-interval '2 days',
  'd3070000-0000-4000-8000-000000000001',now()-interval '1 day'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000006',
  'd3070000-0000-4000-8000-000000000005','d3070000-0000-4000-8000-000000000001',now()-interval '2 days',
  'd3070000-0000-4000-8000-000000000001',now()-interval '1 day');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000001','d3070000-0000-4000-8000-000000000002'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000002','d3070000-0000-4000-8000-000000000002','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000004','d3070000-0000-4000-8000-000000000003','d3070000-0000-4000-8000-000000000001'),
 ('d3071000-0000-4000-8000-000000000001','d3074000-0000-4000-8000-000000000005','d3070000-0000-4000-8000-000000000004','d3070000-0000-4000-8000-000000000001');

SELECT ok(has_function_privilege('authenticated','public.leave_access_snapshot(uuid)','EXECUTE'),
  'authenticated callers retain access snapshot execution');
SELECT ok(NOT has_function_privilege('anon','public.leave_access_snapshot(uuid)','EXECUTE'),
  'anonymous callers remain denied');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3070000-0000-4000-8000-000000000001',true);
SELECT is((public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')->>'self_access')::boolean,true,
  'active linked self-view member retains own Leave history access');
SELECT is((public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')->>'self_can_request')::boolean,false,
  'self-view-only member does not receive request capability');
SELECT is((public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')->>'can_view')::boolean,false,
  'own permission does not become HR Leave visibility');
SELECT is(public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')->'employers','[]'::jsonb,
  'self-only access still hides employer list');

SELECT set_config('request.jwt.claim.sub','d3070000-0000-4000-8000-000000000002',true);
SELECT is((public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')->>'self_access')::boolean,true,
  'request-enabled member retains self history access');
SELECT is((public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')->>'self_can_request')::boolean,true,
  'active linked member with leave.self.request receives request capability');

SELECT set_config('request.jwt.claim.sub','d3070000-0000-4000-8000-000000000003',true);
SELECT is((public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')->>'self_can_request')::boolean,true,
  'relinked user is authorized from the current live link despite retained unlinked history');

SELECT set_config('request.jwt.claim.sub','d3070000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')$$,
  '42501','leave_forbidden','inactive tenant membership cannot use the access snapshot even with role and link records');

SELECT set_config('request.jwt.claim.sub','d3070000-0000-4000-8000-000000000005',true);
SELECT throws_ok($$SELECT public.leave_access_snapshot('d3071000-0000-4000-8000-000000000001')$$,
  '42501','leave_forbidden','an unlinked historical record alone does not grant self access');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
