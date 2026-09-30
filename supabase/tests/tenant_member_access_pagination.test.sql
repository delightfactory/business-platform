BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
SELECT ('e7000000-0000-4000-8000-' || pg_catalog.lpad(n::text,12,'0'))::uuid,
  'page-user-' || pg_catalog.lpad(n::text,3,'0') || '@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()
FROM pg_catalog.generate_series(1,31) AS n;
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e7100000-0000-4000-8000-000000000001','Paged members A','e7000000-0000-4000-8000-000000000001'),
  ('e7100000-0000-4000-8000-000000000002','Paged members B','e7000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
VALUES ('e7100000-0000-4000-8000-000000000001','tenant.users','max_users','limited',50,now()-interval '1 day',
  'e7000000-0000-4000-8000-000000000001','test');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('e7100000-0000-4000-8000-000000000001','e7200000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,
  ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
SELECT 'e7100000-0000-4000-8000-000000000001',
  ('e7000000-0000-4000-8000-' || pg_catalog.lpad(n::text,12,'0'))::uuid,'active',
  'e7000000-0000-4000-8000-000000000001'
FROM pg_catalog.generate_series(1,31) AS n;
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e7100000-0000-4000-8000-000000000001','e7000000-0000-4000-8000-000000000001',
  'e7200000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_member_invitations(tenant_id,target_email,created_by_user_id,expires_at,idempotency_key,request_signature,created_at)
VALUES
  ('e7100000-0000-4000-8000-000000000001','old-invite@example.test','e7000000-0000-4000-8000-000000000001',
    now()-interval '1 day','e7300000-0000-4000-8000-000000000001','{}',now()-interval '2 days'),
  ('e7100000-0000-4000-8000-000000000001','new-invite@example.test','e7000000-0000-4000-8000-000000000001',
    now()+interval '1 day','e7300000-0000-4000-8000-000000000002','{}',now()-interval '1 day');
INSERT INTO platform_core.tenant_member_invitations(tenant_id,target_email,created_by_user_id,expires_at,idempotency_key,request_signature,created_at)
SELECT 'e7100000-0000-4000-8000-000000000001',
  'bulk-invite-' || pg_catalog.lpad(n::text,3,'0') || '@example.test',
  'e7000000-0000-4000-8000-000000000001',now()+interval '1 day',
  ('e7300000-0000-4000-8000-' || pg_catalog.lpad((n+2)::text,12,'0'))::uuid,
  '{}'::jsonb,now()-n*interval '1 minute'
FROM pg_catalog.generate_series(1,30) AS n;

SELECT ok(NOT pg_catalog.has_function_privilege('anon','public.tenant_member_access_page(uuid,text,integer,text)','EXECUTE'),
  'anonymous callers cannot execute the listing RPC');
SELECT ok(NOT pg_catalog.has_function_privilege('service_role','public.tenant_member_access_page(uuid,text,integer,text)','EXECUTE'),
  'service role has no direct listing grant');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000001',true);
SELECT is((public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001')->>'member_count')::integer,31,
  'member tab reports the full count');
SELECT is((public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001')->>'seat_usage')::integer,31,
  'seat usage still counts active memberships');
SELECT is(pg_catalog.jsonb_array_length(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001')->'rows'),25,
  'first page returns at most 25 memberships');
SELECT is(pg_catalog.jsonb_array_length(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','members',2)->'rows'),6,
  'second page contains the remaining memberships');
SELECT is(pg_catalog.jsonb_array_length(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','members',99999)->'rows'),0,
  'out-of-range pages remain bounded');
SELECT is(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','members',1)->'rows'->0->>'email',
  'page-user-031@example.test','member sort is deterministic with a unique tie breaker');
SELECT is(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','members',2)->'rows'->0->>'email',
  'page-user-006@example.test','next page starts after first page');
SELECT is((public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','members',1,'USER-031')->>'matching_count')::integer,1,
  'case-insensitive member search reports matching count');
SELECT is(pg_catalog.jsonb_array_length(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','members',1,'USER-031')->'rows'),1,
  'member search returns only the matching row');
SELECT is((public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','invitations')->>'invitation_count')::integer,32,
  'invitation tab reports full count');
SELECT is(pg_catalog.jsonb_array_length(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','invitations')->'rows'),25,
  'first invitation page is bounded');
SELECT is(pg_catalog.jsonb_array_length(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','invitations',2)->'rows'),7,
  'second invitation page contains the remaining rows');
SELECT is(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','invitations',1,'old-invite')->'rows'->0->>'lifecycle_state',
  'expired','expired invitation displays correctly without a write');
SELECT is((public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','invitations',1,'old-invite')->>'matching_count')::integer,1,
  'invitation search reports matching count');
SELECT is(public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','summary')->'rows','[]'::jsonb,
  'invite form summary contains no user or invitation rows');
SELECT throws_ok($$SELECT public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001','invalid')$$,
  '22023','tenant_member_view_invalid','unknown listing views are rejected');
SELECT throws_ok($$SELECT public.tenant_member_access_page('e7100000-0000-4000-8000-000000000002')$$,
  '42501','tenant_members_manage_forbidden','admin cannot list another tenant');
SELECT set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.tenant_member_access_page('e7100000-0000-4000-8000-000000000001')$$,
  '42501','tenant_members_manage_forbidden','ordinary member cannot list users');
RESET ROLE;
SELECT is((SELECT lifecycle_state FROM platform_core.tenant_member_invitations WHERE target_email='old-invite@example.test'),
  'pending','reading does not mutate invitation lifecycle');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_membership_audit_events WHERE target_email='old-invite@example.test'),0,
  'reading does not append an expiry audit event');

SELECT * FROM finish();
ROLLBACK;
