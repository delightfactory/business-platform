BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e3000000-0000-4000-8000-000000000001','limit-editor@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
  ('e3000000-0000-4000-8000-000000000002','limit-member@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_commercial_access)
VALUES ('e3000000-0000-4000-8000-000000000001',true,true);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e4000000-0000-4000-8000-000000000001','Limit editor','e3000000-0000-4000-8000-000000000001'),
  ('e4000000-0000-4000-8000-000000000002','Limit audit rollback','e3000000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('e4000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','active','e3000000-0000-4000-8000-000000000001'),
  ('e4000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000002','active','e3000000-0000-4000-8000-000000000001');
SELECT ok(NOT has_function_privilege('anon','public.set_tenant_capability_limit(uuid,text,text,text,integer,timestamptz,text)','EXECUTE'),
  'anonymous callers cannot edit limits');
SELECT ok(NOT has_function_privilege('service_role','public.set_tenant_capability_limit(uuid,text,text,text,integer,timestamptz,text)','EXECUTE'),
  'service_role is not the new mutation authority');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3000000-0000-4000-8000-000000000001',true);
SELECT is(public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',3,NULL)->>'outcome',
  'changed','missing limit can be set without a fabricated reason');
SELECT is(public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',1,
  (SELECT (l->>'valid_from')::timestamptz FROM jsonb_array_elements(public.platform_tenant_commercial_snapshot('e4000000-0000-4000-8000-000000000001')->'limits') l
    WHERE l->>'capability_key'='tenant.users'),'  optional note  ')->>'over_capacity',
  'true','lowering below usage reports over-capacity without removing users');
SELECT is(public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',1,NULL)->>'outcome',
  'unchanged','desired state reconciliation precedes stale token check');
SELECT is(public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',2,NULL)->>'outcome',
  'stale','different desired state cannot overwrite a newer limit');
SELECT throws_ok($$SELECT public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users',NULL,NULL,NULL)$$,
  '22023','commercial_limit_value_invalid','NULL mode fails closed');
SELECT throws_ok($$SELECT public.change_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',2,'')$$,
  '22023','commercial_limit_reason_required','legacy caller still requires a reason');
SELECT set_config('request.jwt.claim.sub','e3000000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',1,NULL)$$,
  '42501','commercial_access_forbidden','matching desired state does not bypass commercial authority');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_capability_limit_audit_events WHERE tenant_id='e4000000-0000-4000-8000-000000000001'),
  2,'unchanged, stale and denied calls append no audit event');
SELECT is((SELECT operator_note FROM platform_core.tenant_capability_limit_audit_events WHERE tenant_id='e4000000-0000-4000-8000-000000000001' ORDER BY id DESC LIMIT 1),
  'optional note','operator note stays separate and trimmed');
SELECT ok((SELECT bool_and(reason IS NULL AND change_source='operator_limit_editor') FROM platform_core.tenant_capability_limit_audit_events WHERE tenant_id='e4000000-0000-4000-8000-000000000001'),
  'routine limit edits have honest source with no invented human reason');
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_memberships WHERE tenant_id='e4000000-0000-4000-8000-000000000001' AND access_state='active'),
  2,'lower limit retains existing memberships');

-- Future scheduling wins over a superficially matching current state.
UPDATE platform_core.tenant_capability_limits SET valid_until=now()+interval '1 day'
WHERE tenant_id='e4000000-0000-4000-8000-000000000001' AND valid_until IS NULL;
INSERT INTO platform_core.tenant_capability_limits(tenant_id,capability_key,limit_key,limit_mode,limit_value,valid_from,actor_user_id,provenance)
VALUES ('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',5,now()+interval '1 day','e3000000-0000-4000-8000-000000000001','future test');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000001','tenant.users','max_users','limited',1,NULL)$$,
  '23P01','commercial_limit_future_conflict','future conflict is checked before unchanged');
RESET ROLE;

CREATE FUNCTION pg_temp.fail_limit_editor_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'limit_editor_audit_failure' USING ERRCODE='55000'; END;
$$;
CREATE TRIGGER fail_limit_editor_audit BEFORE INSERT ON platform_core.tenant_capability_limit_audit_events
FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_limit_editor_audit();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3000000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT public.set_tenant_capability_limit('e4000000-0000-4000-8000-000000000002','tenant.users','max_users','limited',2,NULL)$$,
  '55000','limit_editor_audit_failure','audit failure rolls back the new limit atomically');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM platform_core.tenant_capability_limits WHERE tenant_id='e4000000-0000-4000-8000-000000000002'),
  0,'audit failure leaves no new limit row');
SELECT * FROM finish();
ROLLBACK;
