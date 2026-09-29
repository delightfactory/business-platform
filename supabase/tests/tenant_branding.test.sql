BEGIN;
SELECT no_plan();

SELECT has_table('platform_core', 'tenant_branding', 'Tenant branding settings are stored in Core');
SELECT has_table('platform_core', 'tenant_branding_audit_events', 'branding changes have a dedicated audit log');
SELECT has_function('public', 'tenant_branding_snapshot', ARRAY['uuid']::name[], 'branding snapshot RPC exists');
SELECT has_function('public', 'save_tenant_branding', ARRAY['uuid','text','text','text','boolean','text']::name[], 'reasoned save RPC exists');
SELECT has_function('public', 'tenant_branding_storage_allowed', ARRAY['text','boolean']::name[], 'Storage policy uses a bounded authorization helper');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_branding','SELECT'), 'authenticated users cannot read branding tables directly');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_branding_audit_events','INSERT'), 'authenticated users cannot write branding audit directly');
SELECT ok(NOT has_function_privilege('anon','public.save_tenant_branding(uuid,text,text,text,boolean,text)','EXECUTE'), 'anonymous users cannot save branding');
SELECT is((SELECT public FROM storage.buckets WHERE id='tenant-branding'), false, 'branding bucket is private');
SELECT is((SELECT file_size_limit::bigint FROM storage.buckets WHERE id='tenant-branding'), 2097152::bigint, 'branding bucket caps objects at 2 MiB');
SELECT ok(NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='storage' AND tablename='objects'
  AND policyname LIKE 'tenant_branding_object_%' AND cmd='DELETE'), 'authenticated users have no branding object delete policy');

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,banned_until,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e1000000-0000-4000-8000-000000000001','branding-admin-a@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
       ('e1000000-0000-4000-8000-000000000002','branding-member-a@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
       ('e1000000-0000-4000-8000-000000000003','branding-admin-b@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e2000000-0000-4000-8000-000000000001','Branding Tenant A','e1000000-0000-4000-8000-000000000001'),
       ('e2000000-0000-4000-8000-000000000002','Branding Tenant B','e1000000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
       ('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000002','tenant.member.v1',1,ARRAY[]::text[],false),
       ('e2000000-0000-4000-8000-000000000002','e3000000-0000-4000-8000-000000000003','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001','active','e1000000-0000-4000-8000-000000000001'),
       ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','active','e1000000-0000-4000-8000-000000000001'),
       ('e2000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000003','active','e1000000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default)
VALUES ('e2000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001','A Legal Entity','A Legal Name Ltd',true),
       ('e2000000-0000-4000-8000-000000000002','e4000000-0000-4000-8000-000000000002','B Legal Entity','B Legal Name Ltd',true);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001'),
       ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','e3000000-0000-4000-8000-000000000002'),
       ('e2000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000003','e3000000-0000-4000-8000-000000000003');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
SELECT is(public.tenant_branding_storage_allowed('e2000000-0000-4000-8000-000000000001',false),true,'active Tenant member may read same-Tenant branding objects');
SELECT is(public.tenant_branding_storage_allowed('e2000000-0000-4000-8000-000000000002',false),false,'member cannot read another Tenant branding objects');
SELECT is(public.tenant_branding_storage_allowed('e2000000-0000-4000-8000-000000000001',true),false,'ordinary Member cannot write branding objects');
SELECT is(public.tenant_branding_storage_allowed('../e2000000-0000-4000-8000-000000000001',false),false,'malformed Storage tenant path is rejected');
SELECT throws_ok($$SELECT public.tenant_branding_snapshot('e2000000-0000-4000-8000-000000000002')$$,'42501','tenant_branding_unavailable','Tenant member cannot read a different Tenant snapshot');
SELECT throws_ok($$SELECT public.save_tenant_branding('e2000000-0000-4000-8000-000000000001','No access','blue',NULL,false,'test')$$,'42501','tenant_branding_forbidden','ordinary Member cannot change branding');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
SELECT is(public.tenant_branding_storage_allowed('e2000000-0000-4000-8000-000000000001',true),true,'Tenant Admin may upload to its own branding path');
SELECT is(public.tenant_branding_storage_allowed('e2000000-0000-4000-8000-000000000002',true),false,'Tenant Admin cannot upload to another Tenant path');
SELECT is(public.tenant_branding_snapshot('e2000000-0000-4000-8000-000000000001')->>'tenant_name','Branding Tenant A','snapshot falls back to the Tenant display name');
SELECT is(public.save_tenant_branding('e2000000-0000-4000-8000-000000000001','Aster','violet',NULL,false,'Brand refresh')->>'state','saved','Admin saves an audited display override');
SELECT is(public.tenant_branding_snapshot('e2000000-0000-4000-8000-000000000001')->>'tenant_name','Aster','snapshot uses the display override');
SELECT is(public.tenant_branding_snapshot('e2000000-0000-4000-8000-000000000001')->>'primary_color_key','violet','snapshot returns the selected safe color');
SELECT throws_ok($$SELECT public.save_tenant_branding('e2000000-0000-4000-8000-000000000002','Cross Tenant','blue',NULL,false,'test')$$,'42501','tenant_branding_forbidden','Tenant Admin cannot update another Tenant');
SELECT throws_ok($$SELECT public.save_tenant_branding('e2000000-0000-4000-8000-000000000001','Invalid','pink',NULL,false,'test')$$,'22023','tenant_branding_input_invalid','unsupported color is rejected');
RESET ROLE;
SELECT is((SELECT legal_name FROM platform_core.tenant_legal_entities WHERE tenant_id='e2000000-0000-4000-8000-000000000001'),'A Legal Name Ltd','branding does not write Legal Entity legal names');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_branding_audit_events WHERE tenant_id='e2000000-0000-4000-8000-000000000001'),1,'successful branding change writes one audit event');

CREATE FUNCTION pg_temp.fail_branding_audit() RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN RAISE EXCEPTION 'audit_failure_test' USING ERRCODE='P0001'; END; $function$;
CREATE TRIGGER fail_branding_audit BEFORE INSERT ON platform_core.tenant_branding_audit_events
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_branding_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.save_tenant_branding('e2000000-0000-4000-8000-000000000001','Rollback','blue',NULL,false,'Audit must persist')$$,
  'P0001','audit_failure_test','audit insertion failure aborts the branding mutation');
SELECT is(public.tenant_branding_snapshot('e2000000-0000-4000-8000-000000000001')->>'tenant_name','Aster','failed audit leaves prior branding unchanged');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
