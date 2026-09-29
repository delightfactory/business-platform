BEGIN;
SELECT no_plan();

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES
 ('c1000000-0000-4000-8000-000000000001','commercial-operator@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c1000000-0000-4000-8000-000000000002','commercial-admin@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c1000000-0000-4000-8000-000000000003','commercial-member-a@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c1000000-0000-4000-8000-000000000004','commercial-member-b@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());

INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access)
VALUES ('c1000000-0000-4000-8000-000000000001',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('c2000000-0000-4000-8000-000000000001','Commercial A','c1000000-0000-4000-8000-000000000001'),
       ('c2000000-0000-4000-8000-000000000002','Commercial Missing','c1000000-0000-4000-8000-000000000001'),
       ('c2000000-0000-4000-8000-000000000003','Commercial Future','c1000000-0000-4000-8000-000000000001'),
       ('c2000000-0000-4000-8000-000000000004','Commercial Scheduled','c1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,valid_until,actor_user_id,provenance)
VALUES
 ('c2000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',3,now()-interval '1 day',NULL,'c1000000-0000-4000-8000-000000000001','test'),
 ('c2000000-0000-4000-8000-000000000001','tenant.sites','max_sites','limited',3,now()-interval '1 day',NULL,'c1000000-0000-4000-8000-000000000001','test'),
 ('c2000000-0000-4000-8000-000000000003','tenant.users','max_users','limited',3,now()+interval '1 day',NULL,'c1000000-0000-4000-8000-000000000001','future test'),
 ('c2000000-0000-4000-8000-000000000004','tenant.users','max_users','limited',3,now()-interval '1 day',now()+interval '1 day','c1000000-0000-4000-8000-000000000001','current with future'),
 ('c2000000-0000-4000-8000-000000000004','tenant.users','max_users','limited',5,now()+interval '1 day',NULL,'c1000000-0000-4000-8000-000000000001','future schedule');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,
  ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000002','tenant.member.v1',1,ARRAY[]::text[],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000002','active','c1000000-0000-4000-8000-000000000001'),
 ('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000003','active','c1000000-0000-4000-8000-000000000001'),
 ('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000004','inactive','c1000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000001'),
 ('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000003','c3000000-0000-4000-8000-000000000002'),
 ('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000004','c3000000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default)
VALUES ('c2000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000001','Commercial Entity','Commercial Entity Ltd',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES ('c2000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000001','Site One',true,true),
 ('c2000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000002','c4000000-0000-4000-8000-000000000001','Site Two',false,true),
 ('c2000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000003','c4000000-0000-4000-8000-000000000001','Site Inactive',false,false);

SELECT has_function('public','current_operator_can_manage_commercial_access',ARRAY[]::name[],'commercial capability is separately queryable');
SELECT has_function('public','platform_tenant_commercial_list',ARRAY[]::name[],'commercial Tenant list RPC exists');
SELECT has_function('public','platform_tenant_commercial_snapshot',ARRAY['uuid']::name[],'commercial usage snapshot RPC exists');
SELECT has_function('public','change_tenant_capability_limit',ARRAY['uuid','text','text','text','integer','text']::name[],'bounded commercial limit command exists');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_capability_limit_audit_events','SELECT'),'runtime cannot read or rewrite commercial audit directly');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_capability_limits','UPDATE'),'runtime cannot edit effective limits directly');
SELECT ok(NOT has_function_privilege('anon','public.change_tenant_capability_limit(uuid,text,text,text,integer,text)','EXECUTE'),'anonymous users cannot change commercial limits');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
SELECT ok(public.current_operator_can_manage_commercial_access(),'explicit commercial grant grants only its named task');
SELECT ok(NOT public.current_operator_can_manage_operators(),'commercial authority does not imply Operator management');
SELECT ok(NOT public.current_operator_can_manage_tenant_lifecycle(),'commercial authority does not imply lifecycle authority');
SELECT is(pg_catalog.jsonb_array_length(public.platform_tenant_commercial_list()),4,'commercial list returns Tenant identity and lifecycle only');
SELECT is((SELECT (limit_row->>'usage')::integer FROM pg_catalog.jsonb_array_elements(public.platform_tenant_commercial_snapshot('c2000000-0000-4000-8000-000000000001')->'limits') limit_row WHERE limit_row->>'capability_key'='tenant.users'),2,'snapshot reports active seat usage');
SELECT is((SELECT (limit_row->>'usage')::integer FROM pg_catalog.jsonb_array_elements(public.platform_tenant_commercial_snapshot('c2000000-0000-4000-8000-000000000001')->'limits') limit_row WHERE limit_row->>'capability_key'='tenant.sites'),2,'snapshot reports active Site usage across Entities');
SELECT is((SELECT limit_row->>'status' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_commercial_snapshot('c2000000-0000-4000-8000-000000000002')->'limits') limit_row WHERE limit_row->>'capability_key'='tenant.users'),'missing','missing effective limit is surfaced explicitly');
SELECT is((SELECT limit_row->>'status' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_commercial_snapshot('c2000000-0000-4000-8000-000000000003')->'limits') limit_row WHERE limit_row->>'capability_key'='tenant.users'),'future_conflict','future-only limit is surfaced instead of picked arbitrarily');
SELECT is((SELECT limit_row->>'status' FROM pg_catalog.jsonb_array_elements(public.platform_tenant_commercial_snapshot('c2000000-0000-4000-8000-000000000004')->'limits') limit_row WHERE limit_row->>'capability_key'='tenant.users'),'future_conflict','current limit plus a scheduled future row is surfaced as a conflict');
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000001','tenant.users','max_sites','limited',10,'wrong key')$$,
  '22023','commercial_limit_key_invalid','mismatched capability and limit keys are rejected');
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',0,'zero')$$,
  '22023','commercial_limit_value_invalid','limited values must be positive');
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',1,'  ')$$,
  '22023','commercial_limit_reason_required','every change requires a reason');
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000003','tenant.users','max_users','limited',1,'future conflict')$$,
  '23P01','commercial_limit_future_conflict','new limit does not guess around a conflicting future interval');
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000004','tenant.users','max_users','limited',1,'scheduled conflict')$$,
  '23P01','commercial_limit_future_conflict','scheduled interval conflicts with a new open-ended limit');
SELECT lives_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000002','tenant.users','max_users','unlimited',NULL,'Repair missing user limit')$$,
  'a missing effective limit can be repaired without a future conflict');
SELECT lives_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000002','tenant.sites','max_sites','limited',1,'Repair missing Site limit')$$,
  'the second independent limit can also be initialized');

CREATE TEMP TABLE commercial_results(label text,result jsonb);
GRANT SELECT,INSERT ON commercial_results TO authenticated;
INSERT INTO commercial_results SELECT 'users',public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',1,'Temporary seat reduction');
INSERT INTO commercial_results SELECT 'sites',public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000001','tenant.sites','max_sites','limited',1,'Temporary Site reduction');
SELECT ok((SELECT (result->>'over_capacity')::boolean FROM commercial_results WHERE label='users'),'lowering below active seats is allowed and surfaced as over-capacity');
SELECT ok((SELECT (result->>'over_capacity')::boolean FROM commercial_results WHERE label='sites'),'lowering below active Sites is allowed and surfaced as over-capacity');
RESET ROLE;
SELECT ok((SELECT old_limit.valid_until=new_limit.valid_from AND new_limit.valid_from=event.effective_at
  FROM platform_core.tenant_capability_limits old_limit
  JOIN platform_core.tenant_capability_limits new_limit ON new_limit.tenant_id=old_limit.tenant_id AND new_limit.capability_key=old_limit.capability_key
    AND new_limit.limit_key=old_limit.limit_key AND new_limit.valid_from>old_limit.valid_from
  JOIN platform_core.tenant_capability_limit_audit_events event ON event.tenant_id=new_limit.tenant_id
    AND event.capability_key=new_limit.capability_key AND event.limit_key=new_limit.limit_key AND event.effective_at=new_limit.valid_from
  WHERE new_limit.tenant_id='c2000000-0000-4000-8000-000000000001' AND new_limit.capability_key='tenant.users' LIMIT 1),
  'replacement is effective at the exact prior close and audited instant');
SELECT is((SELECT reason FROM platform_core.tenant_capability_limit_audit_events WHERE tenant_id='c2000000-0000-4000-8000-000000000001'
  AND capability_key='tenant.users' ORDER BY id DESC LIMIT 1),'Temporary seat reduction','reason is stored in the same audit event');
SELECT ok(NOT has_table_privilege('authenticated','platform_core.tenant_capability_limit_audit_events','UPDATE'),'limit audit remains append-only to authenticated runtime');

CREATE FUNCTION pg_temp.fail_commercial_audit() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'commercial_audit_failure' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER fail_commercial_audit BEFORE INSERT ON platform_core.tenant_capability_limit_audit_events
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_commercial_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',4,'audit failure rollback')$$,
  '55000','commercial_audit_failure','audit failure aborts the limit change');
RESET ROLE;
DROP TRIGGER fail_commercial_audit ON platform_core.tenant_capability_limit_audit_events;
DROP FUNCTION pg_temp.fail_commercial_audit();
SELECT is((SELECT limit_value FROM platform_core.tenant_capability_limits WHERE tenant_id='c2000000-0000-4000-8000-000000000001'
  AND capability_key='tenant.users' AND valid_until IS NULL),1,'audit failure rolls back the new effective limit');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('c2000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',10,'unauthorized')$$,
  '42501','commercial_access_forbidden','Tenant Admin cannot change Operator commercial limits');
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.set_tenant_member_access('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000004','active')$$,
  'P0001','tenant_member_limit_full','Member reactivation observes newly reduced max_users');
SELECT throws_ok($$SELECT public.manage_tenant_site('c2000000-0000-4000-8000-000000000001','create',NULL,'c4000000-0000-4000-8000-000000000001','Site Three','capacity test')$$,
  '23514','tenant_sites_capacity_reached','Site creation observes newly reduced max_sites');
SELECT throws_ok($$SELECT public.manage_tenant_site('c2000000-0000-4000-8000-000000000001','reactivate','c5000000-0000-4000-8000-000000000003',NULL,NULL,'capacity test')$$,
  '23514','tenant_sites_capacity_reached','Site reactivation observes newly reduced max_sites');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
