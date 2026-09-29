BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,banned_until,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('b1000000-0000-4000-8000-000000000001','entities-admin@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('b1000000-0000-4000-8000-000000000002','entities-only@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('b1000000-0000-4000-8000-000000000003','sites-only@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('b1000000-0000-4000-8000-000000000004','entities-member@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('b1000000-0000-4000-8000-000000000005','entities-tenant-b@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('b1000000-0000-4000-8000-000000000006','onboard-operator@example.test','hash',now(),NULL,'{}','{}','authenticated','authenticated',now(),now()),
 ('b1000000-0000-4000-8000-000000000007','unverified-entity-manager@example.test','hash',NULL,NULL,'{}','{}','authenticated','authenticated',now(),now());

INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle)
VALUES ('b1000000-0000-4000-8000-000000000006',true,false,true,false);

INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('b2000000-0000-4000-8000-000000000001','Entities A','b1000000-0000-4000-8000-000000000001'),
       ('b2000000-0000-4000-8000-000000000002','Entities B','b1000000-0000-4000-8000-000000000005');
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
VALUES ('b2000000-0000-4000-8000-000000000001','tenant.sites','max_sites','limited',2,now()-interval '1 day','b1000000-0000-4000-8000-000000000001','test'),
       ('b2000000-0000-4000-8000-000000000002','tenant.sites','max_sites','unlimited',NULL,now()-interval '1 day','b1000000-0000-4000-8000-000000000005','test');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES
 ('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000002','tenant.entities.manager.v1',1,ARRAY['tenant.legal_entities.manage'],false),
 ('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000003','tenant.sites.manager.v1',1,ARRAY['tenant.sites.manage'],false),
 ('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000004','tenant.member.v1',1,ARRAY[]::text[],false),
 ('b2000000-0000-4000-8000-000000000002','b3000000-0000-4000-8000-000000000005','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','active','b1000000-0000-4000-8000-000000000001'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000002','active','b1000000-0000-4000-8000-000000000001'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000003','active','b1000000-0000-4000-8000-000000000001'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000004','active','b1000000-0000-4000-8000-000000000001'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000007','active','b1000000-0000-4000-8000-000000000001'),
 ('b2000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000005','active','b1000000-0000-4000-8000-000000000005');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000002','b3000000-0000-4000-8000-000000000002'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000003','b3000000-0000-4000-8000-000000000003'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000004','b3000000-0000-4000-8000-000000000004'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000007','b3000000-0000-4000-8000-000000000002'),
 ('b2000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000005','b3000000-0000-4000-8000-000000000005');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default)
VALUES ('b2000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000001','Main Entity','Main Legal Ltd',true),
       ('b2000000-0000-4000-8000-000000000002','b4000000-0000-4000-8000-000000000002','Tenant B Entity','B Ltd',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('b2000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000001','Main Site',true,true),
       ('b2000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000003','b4000000-0000-4000-8000-000000000001','Recovery Site',false,false),
       ('b2000000-0000-4000-8000-000000000002','b5000000-0000-4000-8000-000000000002','b4000000-0000-4000-8000-000000000002','B Site',true,true);

SELECT has_function('public','tenant_entities_sites_snapshot',ARRAY['uuid']::name[],'bounded Tenant entity and Site snapshot exists');
SELECT has_function('public','manage_tenant_legal_entity',ARRAY['uuid','text','uuid','text','text','text']::name[],'legal entity command exists');
SELECT has_function('public','manage_tenant_site',ARRAY['uuid','text','uuid','uuid','text','text']::name[],'Site command exists');
SELECT ok(NOT has_function_privilege('anon','public.manage_tenant_site(uuid,text,uuid,uuid,text,text)','EXECUTE'),'anonymous users cannot mutate Sites');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_sites','INSERT'),'authenticated users cannot insert Sites directly');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_legal_entities','UPDATE'),'authenticated users cannot update Legal Entities directly');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$SELECT public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')$$,
  '42501','tenant_entities_sites_forbidden','ordinary member cannot read the management snapshot');
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','create',NULL,'b4000000-0000-4000-8000-000000000001','Unauthorized','A test')$$,
  '42501','tenant_sites_manage_forbidden','ordinary member cannot create a Site');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000006',true);
SELECT throws_ok($$SELECT public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','create',NULL,'Operator access',NULL,'A test')$$,
  '42501','tenant_legal_entities_manage_forbidden','Operator onboarding capability alone grants no access to an existing Tenant');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000007',true);
SELECT throws_ok($$SELECT public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','create',NULL,'Unverified access',NULL,'A test')$$,
  '42501','tenant_legal_entities_manage_forbidden','unverified Auth user cannot perform Tenant mutations');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000002',true);
SELECT ok((public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->>'can_manage_legal_entities')::boolean,
  'Entity-only manager can read required context and sees its own capability');
SELECT ok(NOT (public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->>'can_manage_sites')::boolean,
  'Entity-only manager does not inherit Site authority');
SELECT is(public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->'entities'->0->'sites','[]'::jsonb,
  'Entity-only manager receives no Site details');
SELECT is((public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->'entities'->0->>'active_site_count')::integer,1,
  'Entity-only manager receives only the active Site count needed for lifecycle guidance');
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','create',NULL,'b4000000-0000-4000-8000-000000000001','Unauthorized','A test')$$,
  '42501','tenant_sites_manage_forbidden','Entity permission does not authorize Site mutation');
SELECT throws_ok($$SELECT public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','create',NULL,'Denied',NULL,'   ')$$,
  '22023','tenant_identity_reason_required','every mutation requires a bounded audit reason');
RESET ROLE;

UPDATE platform_core.tenants SET lifecycle_state='suspended' WHERE id='b2000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','create',NULL,'b4000000-0000-4000-8000-000000000001','Suspended write','A test')$$,
  '42501','tenant_sites_manage_forbidden','suspended Tenant rejects Site mutations');
RESET ROLE;
UPDATE platform_core.tenants SET lifecycle_state='active' WHERE id='b2000000-0000-4000-8000-000000000001';

CREATE TEMP TABLE entities_sites_fixture(entity_new uuid,site_new uuid,site_reactivate uuid);
INSERT INTO entities_sites_fixture DEFAULT VALUES;
GRANT SELECT ON entities_sites_fixture TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000003',true);
SELECT ok((public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->>'can_manage_sites')::boolean,
  'Site-only manager can read required entity context and sees Site authority');
SELECT ok(NOT (public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->>'can_manage_legal_entities')::boolean,
  'Site-only manager does not inherit Entity authority');
SELECT is(public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->'entities'->0->>'legal_name',NULL,
  'Site-only manager does not read the Legal Entity legal name');
SELECT throws_ok($$SELECT public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','create',NULL,'Denied',NULL,'A test')$$,
  '42501','tenant_legal_entities_manage_forbidden','Site permission does not authorize Entity mutation');
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','create',NULL,'b4000000-0000-4000-8000-000000000002','Cross tenant','A test')$$,
  '23503','tenant_site_entity_unavailable','Site cannot be linked to another Tenant Entity');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is((public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->>'site_usage')::integer,1,
  'initial default Site counts toward active usage');
SELECT is(public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','update','b4000000-0000-4000-8000-000000000001','Main Entity Display','Main Legal Updated','Correct legal identity')->>'state','updated',
  'legal and display identities can be changed independently');
RESET ROLE;
SELECT ok((SELECT display_name='Main Entity Display' AND legal_name='Main Legal Updated'
  FROM platform_core.tenant_legal_entities WHERE tenant_id='b2000000-0000-4000-8000-000000000001' AND id='b4000000-0000-4000-8000-000000000001'),
  'Legal Entity display and legal names remain separate');
SELECT is((SELECT display_name FROM platform_core.tenants WHERE id='b2000000-0000-4000-8000-000000000001'),'Entities A',
  'updating a Legal Entity does not rename its Tenant');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is(public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','create',NULL,'Second Entity','Second Legal Ltd','Add another Legal Entity')->>'state','created',
  'Tenant Admin can create another Legal Entity');
RESET ROLE;
UPDATE entities_sites_fixture SET entity_new=(SELECT id FROM platform_core.tenant_legal_entities
  WHERE tenant_id='b2000000-0000-4000-8000-000000000001' AND display_name='Second Entity');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is(public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','default',(SELECT entity_new FROM entities_sites_fixture),NULL,NULL,'Use second Entity')->>'state','default',
  'active Legal Entity can become the Tenant default');
RESET ROLE;
SELECT ok((SELECT after_state->>'previous_default_id'='b4000000-0000-4000-8000-000000000001'
  FROM platform_core.tenant_entities_sites_audit_events WHERE tenant_id='b2000000-0000-4000-8000-000000000001'
    AND resource_type='legal_entity' AND action='default_changed' ORDER BY id DESC LIMIT 1),
  'Legal Entity default audit identifies the prior default');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is(public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','default','b4000000-0000-4000-8000-000000000001',NULL,NULL,'Restore primary Entity')->>'state','default',
  'default can be switched back to the primary Legal Entity');
SELECT is(public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','deactivate',(SELECT entity_new FROM entities_sites_fixture),NULL,NULL,'Close unused Entity')->>'state','deactivate',
  'an Entity with no active Sites can be deactivated');
SELECT is(public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','create',NULL,'b4000000-0000-4000-8000-000000000001','Second Site','Open second location')->>'state','created',
  'Site creation succeeds within effective max_sites');
RESET ROLE;
UPDATE entities_sites_fixture SET site_new=(SELECT id FROM platform_core.tenant_sites WHERE tenant_id='b2000000-0000-4000-8000-000000000001' AND display_name='Second Site');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is((public.tenant_entities_sites_snapshot('b2000000-0000-4000-8000-000000000001')->>'site_usage')::integer,2,
  'new Site is included in aggregate usage');
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','create',NULL,'b4000000-0000-4000-8000-000000000001','Over capacity','Open a third location')$$,
  '23514','tenant_sites_capacity_reached','site creation fails closed at max_sites');
SELECT is(public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','default',(SELECT site_new FROM entities_sites_fixture),NULL,NULL,'Use second site')->>'state','default',
  'active Site can become the Tenant default');
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','update','b5000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000002','Move attempt','Move test')$$,
  '0A000','tenant_site_move_not_supported','Sites cannot be moved between Entities');
RESET ROLE;
SELECT ok((SELECT after_state->>'previous_default_id'='b5000000-0000-4000-8000-000000000001'
  FROM platform_core.tenant_entities_sites_audit_events WHERE tenant_id='b2000000-0000-4000-8000-000000000001'
    AND resource_type='site' AND action='default_changed' ORDER BY id DESC LIMIT 1),
  'default-change audit identifies the prior default Site');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000002','create',NULL,'Cross tenant',NULL,'A test')$$,
  '42501','tenant_legal_entities_manage_forbidden','Tenant A actor cannot mutate Tenant B data');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','deactivate','b4000000-0000-4000-8000-000000000001',NULL,NULL,'Close Entity')$$,
  '23514','tenant_legal_entity_has_active_sites','Entity with active Sites cannot be deactivated');
SELECT is(public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','deactivate',(SELECT site_new FROM entities_sites_fixture),NULL,NULL,'Close unused Site')->>'state','deactivate',
  'Site can be deactivated without deletion');
SELECT is(public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','deactivate','b5000000-0000-4000-8000-000000000001',NULL,NULL,'Close default Site')->>'state','deactivate',
  'last active Site can be deactivated without deleting its record');
RESET ROLE;
SELECT ok(NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites WHERE tenant_id='b2000000-0000-4000-8000-000000000001' AND is_active AND is_default),
  'deactivating the final default leaves no active default');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is(public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','deactivate','b4000000-0000-4000-8000-000000000001',NULL,NULL,'Close inactive Entity')->>'state','deactivate',
  'last active Entity may be deactivated after Sites are inactive');
RESET ROLE;
SELECT ok(NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id='b2000000-0000-4000-8000-000000000001' AND is_active AND is_default),
  'Tenant may have no active default Entity while setup is incomplete');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is(public.manage_tenant_legal_entity('b2000000-0000-4000-8000-000000000001','reactivate','b4000000-0000-4000-8000-000000000001',NULL,NULL,'Restore Entity')->>'state','reactivate',
  'Entity can be reactivated and becomes default when none is active');
RESET ROLE;
SELECT ok((SELECT is_active AND is_default FROM platform_core.tenant_legal_entities
  WHERE tenant_id='b2000000-0000-4000-8000-000000000001' AND id='b4000000-0000-4000-8000-000000000001'),
  'first reactivated Entity is selected as the default');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT is(public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','reactivate','b5000000-0000-4000-8000-000000000001',NULL,NULL,'Restore main Site')->>'state','reactivate',
  'first reactivated Site is selected as the default');
SELECT is(public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','reactivate',(SELECT site_new FROM entities_sites_fixture),NULL,NULL,'Restore second Site')->>'state','reactivate',
  'second Site can be reactivated within max_sites');
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','reactivate','b5000000-0000-4000-8000-000000000003',NULL,NULL,'Restore Site')$$,
  '23514','tenant_sites_capacity_reached','reactivation at active Site capacity fails closed');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_entities_sites_audit_events
  WHERE tenant_id='b2000000-0000-4000-8000-000000000001'),13,'each committed identity/default/lifecycle mutation appends audit');
SELECT ok((SELECT bool_and(pg_catalog.btrim(reason)<>'') FROM platform_core.tenant_entities_sites_audit_events
  WHERE tenant_id='b2000000-0000-4000-8000-000000000001'),'every audit record has a reason');

CREATE FUNCTION platform_core.test_fail_entities_sites_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN IF NEW.action='updated' AND NEW.resource_type='site' THEN RAISE EXCEPTION 'simulated_identity_audit_failure' USING ERRCODE='55000'; END IF; RETURN NEW; END;
$function$;
CREATE TRIGGER test_fail_entities_sites_audit BEFORE INSERT ON platform_core.tenant_entities_sites_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.test_fail_entities_sites_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.manage_tenant_site('b2000000-0000-4000-8000-000000000001','update','b5000000-0000-4000-8000-000000000001',NULL,'Should roll back','Audit test')$$,
  '55000','simulated_identity_audit_failure','audit failure rejects the Site update');
RESET ROLE;
DROP TRIGGER test_fail_entities_sites_audit ON platform_core.tenant_entities_sites_audit_events;
DROP FUNCTION platform_core.test_fail_entities_sites_audit();
SELECT is((SELECT display_name FROM platform_core.tenant_sites WHERE tenant_id='b2000000-0000-4000-8000-000000000001' AND id='b5000000-0000-4000-8000-000000000001'),
  'Main Site','failed audit rolls back the Site update');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_entities_sites_audit_events WHERE tenant_id='b2000000-0000-4000-8000-000000000001'),13,
  'failed audit does not leave an audit row or mutation');
SELECT throws_ok($$UPDATE platform_core.tenant_entities_sites_audit_events SET reason='edited' WHERE tenant_id='b2000000-0000-4000-8000-000000000001'$$,
  '55000','Tenant identity and Site audit events are append-only','audit history cannot be rewritten');

SELECT * FROM finish();
ROLLBACK;
