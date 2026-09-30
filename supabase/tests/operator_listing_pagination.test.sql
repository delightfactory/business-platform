BEGIN;
SELECT no_plan();

SELECT has_function('public','platform_tenant_list_page',ARRAY['text','integer','text']::name[],'bounded operator tenant page exists');
SELECT has_function('public','platform_tenant_lifecycle_get',ARRAY['uuid']::name[],'single tenant lifecycle read exists');
SELECT has_function('public','tenant_admin_invitation_page',ARRAY['integer','text']::name[],'bounded invitation page exists');
SELECT has_function('public','tenant_admin_invitation_get',ARRAY['uuid']::name[],'single invitation read exists');
SELECT ok(NOT has_function_privilege('anon','public.platform_tenant_list_page(text,integer,text)','EXECUTE'),'anonymous tenant listing is denied');
SELECT ok(NOT has_function_privilege('anon','public.tenant_admin_invitation_page(integer,text)','EXECUTE'),'anonymous invitation listing is denied');

INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
 ('e0000000-0000-4000-8000-000000000001','authenticated','authenticated','scale-lifecycle@example.test','hash',now(),'{}','{}',now(),now()),
 ('e0000000-0000-4000-8000-000000000002','authenticated','authenticated','scale-commercial@example.test','hash',now(),'{}','{}',now(),now()),
 ('e0000000-0000-4000-8000-000000000003','authenticated','authenticated','scale-inviter@example.test','hash',now(),'{}','{}',now(),now()),
 ('e0000000-0000-4000-8000-000000000004','authenticated','authenticated','scale-denied@example.test','hash',now(),'{}','{}',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_manage_tenant_lifecycle,can_manage_commercial_access,can_onboard_tenants)
VALUES
 ('e0000000-0000-4000-8000-000000000001',true,false,true,false,false),
 ('e0000000-0000-4000-8000-000000000002',true,false,false,true,false),
 ('e0000000-0000-4000-8000-000000000003',true,false,false,false,true),
 ('e0000000-0000-4000-8000-000000000004',true,true,false,false,false);

INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
SELECT ('e1000000-0000-4000-8000-' || pg_catalog.lpad(n::text,12,'0'))::uuid,
  'Scale Tenant ' || pg_catalog.lpad(n::text,3,'0'),'e0000000-0000-4000-8000-000000000001'::uuid
FROM pg_catalog.generate_series(1,60) n;

INSERT INTO platform_core.tenant_admin_onboarding_intents(
  id,created_by_operator_id,target_email,tenant_name,legal_entity_name,site_name,
  seat_limit_mode,seat_limit,site_limit_mode,site_limit,expires_at,idempotency_key,request_signature,created_at
)
SELECT ('e3000000-0000-4000-8000-' || pg_catalog.lpad(n::text,12,'0'))::uuid,
  'e0000000-0000-4000-8000-000000000003'::uuid,
  'scale-' || n || '@example.test','Scale Invite ' || pg_catalog.lpad(n::text,3,'0'),
  'Scale Legal','Main','limited',5,'limited',2,
  CASE WHEN n<=30 THEN now()-interval '1 day' ELSE now()+interval '1 day' END,
  pg_catalog.gen_random_uuid(),'{}'::jsonb,now()-interval '1 hour'+n*interval '1 second'
FROM pg_catalog.generate_series(1,60) n;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e0000000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.platform_tenant_list_page('lifecycle',1,NULL)$$,'42501','tenant_lifecycle_forbidden','uncapable operator cannot list lifecycle tenants');
SELECT throws_ok($$SELECT public.platform_tenant_lifecycle_get('e1000000-0000-4000-8000-000000000001')$$,'42501','tenant_lifecycle_forbidden','uncapable operator cannot fetch lifecycle detail');
SELECT throws_ok($$SELECT public.tenant_admin_invitation_page(1,NULL)$$,'42501','platform_operator_onboarding_forbidden','uncapable operator cannot list invitations');
SELECT throws_ok($$SELECT public.tenant_admin_invitation_get('e3000000-0000-4000-8000-000000000001')$$,'42501','platform_operator_onboarding_forbidden','uncapable operator cannot fetch invitation');

SELECT set_config('request.jwt.claim.sub','e0000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.platform_tenant_list_page('commercial',1,NULL)$$,'42501','commercial_access_forbidden','lifecycle authority does not expose commercial listing');
SELECT throws_ok($$SELECT public.platform_tenant_list_page('unknown',1,NULL)$$,'22023','operator_tenant_scope_invalid','unknown listing scope is rejected');
SELECT is((public.platform_tenant_list_page('lifecycle',1,'Scale Tenant')->>'matching_count')::integer,60,'tenant search returns all matching count');
SELECT is(pg_catalog.jsonb_array_length(public.platform_tenant_list_page('lifecycle',1,'Scale Tenant')->'rows'),25,'tenant page is capped at 25');
SELECT is(public.platform_tenant_list_page('lifecycle',1,'Scale Tenant')->'rows'->0->>'display_name','Scale Tenant 001','tenant order starts with name and ID');
SELECT is(public.platform_tenant_list_page('lifecycle',2,'Scale Tenant')->'rows'->0->>'display_name','Scale Tenant 026','tenant next page does not repeat the first');
SELECT is(public.platform_tenant_list_page('lifecycle',1,'tenant 060')->'rows'->0->>'display_name','Scale Tenant 060','tenant search ignores case');
SELECT is(public.platform_tenant_lifecycle_get('e1000000-0000-4000-8000-000000000060')->>'tenant_name','Scale Tenant 060','single tenant detail works outside first page');

SELECT set_config('request.jwt.claim.sub','e0000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.platform_tenant_list_page('lifecycle',1,NULL)$$,'42501','tenant_lifecycle_forbidden','commercial authority does not expose lifecycle listing');
SELECT is(pg_catalog.jsonb_array_length(public.platform_tenant_list_page('commercial',3,'Scale Tenant')->'rows'),10,'commercial page has remaining rows only');

SELECT set_config('request.jwt.claim.sub','e0000000-0000-4000-8000-000000000003',true);
SELECT is((public.tenant_admin_invitation_page(1,'Scale Invite')->>'matching_count')::integer,60,'invitation search returns all matching count');
SELECT is(pg_catalog.jsonb_array_length(public.tenant_admin_invitation_page(1,'Scale Invite')->'rows'),25,'invitation page is capped at 25');
SELECT is(public.tenant_admin_invitation_page(1,'Scale Invite')->'rows'->0->>'tenant_name','Scale Invite 060','invitation order is newest first');
SELECT is(public.tenant_admin_invitation_page(2,'Scale Invite')->'rows'->0->>'tenant_name','Scale Invite 035','invitation next page has stable boundary');
SELECT is(public.tenant_admin_invitation_page(1,'SCALE-60@EXAMPLE.TEST')->'rows'->0->>'target_email','scale-60@example.test','invitation search matches email without case');
SELECT is(public.tenant_admin_invitation_get('e3000000-0000-4000-8000-000000000001')->>'lifecycle_state','expired','selected invitation outside current page expires on detail read');
SELECT is(public.tenant_admin_invitation_get('e3000000-0000-4000-8000-000000000001')->>'id','e3000000-0000-4000-8000-000000000001','selected invitation stays addressable outside page');
RESET ROLE;

SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_admin_invitation_audit WHERE action='expired'),21,
  'only expired invitations read on page two or selected by ID were audited once');
SELECT is((SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_admin_invitation_audit WHERE invitation_id='e3000000-0000-4000-8000-000000000001' AND action='expired'),1,
  'repeated selected detail reads do not duplicate expiry audit');
SELECT * FROM finish();
ROLLBACK;
