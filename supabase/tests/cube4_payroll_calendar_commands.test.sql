BEGIN;
DO $$ BEGIN IF current_database() NOT IN ('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required'; END IF; END $$;
SELECT no_plan();
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4410000-0000-4000-8000-000000000001','cube4-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4410000-0000-4000-8000-000000000002','cube4-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4411000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4410000-0000-4000-8000-000000000001'),
 ('c4411000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4410000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4411000-0000-4000-8000-000000000001','c4412000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage']),
 ('c4411000-0000-4000-8000-000000000001','c4412000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4411000-0000-4000-8000-000000000001','c4410000-0000-4000-8000-000000000001','c4410000-0000-4000-8000-000000000001'),
 ('c4411000-0000-4000-8000-000000000001','c4410000-0000-4000-8000-000000000002','c4410000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4411000-0000-4000-8000-000000000001','c4410000-0000-4000-8000-000000000001','c4412000-0000-4000-8000-000000000001'),
 ('c4411000-0000-4000-8000-000000000001','c4410000-0000-4000-8000-000000000002','c4412000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4411000-0000-4000-8000-000000000002','c4413000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4411000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4410000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4411000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4410000-0000-4000-8000-000000000001','Cube4 QA only');
CREATE FUNCTION pg_temp.c4preview(start_day date DEFAULT '2030-01-25',cutoff integer DEFAULT 24) RETURNS jsonb LANGUAGE sql AS $$ SELECT public.payroll_calendar_preview('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001',start_day,cutoff,1,'following','Africa/Cairo') $$;
CREATE FUNCTION pg_temp.c4save(start_day date DEFAULT '2030-01-25',cutoff integer DEFAULT 24,expected integer DEFAULT 0,ky uuid DEFAULT 'c4419000-0000-4000-8000-000000000001',reviewed jsonb DEFAULT NULL,reason text DEFAULT 'Reviewed QA calendar') RETURNS jsonb LANGUAGE sql AS $$ SELECT public.payroll_save_calendar('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001',start_day,cutoff,1,'following','Africa/Cairo',expected,ky,COALESCE(reviewed,current_setting('test.c4quote')::jsonb),reason) $$;
CREATE FUNCTION pg_temp.c4generate(expected integer DEFAULT 1,ky uuid DEFAULT 'c4419000-0000-4000-8000-000000000002') RETURNS jsonb LANGUAGE sql AS $$ SELECT public.payroll_generate_next_period('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001',expected,ky,current_setting('test.c4next')::jsonb) $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;
SELECT ok(NOT has_function_privilege('anon','public.payroll_save_calendar(uuid,uuid,date,integer,integer,text,text,integer,uuid,jsonb,text)','EXECUTE'),'anon cannot save');
SELECT ok(NOT has_function_privilege('service_role','public.payroll_generate_next_period(uuid,uuid,integer,uuid,jsonb)','EXECUTE'),'service role cannot generate');
SELECT ok(NOT has_table_privilege('authenticated','payroll.periods','SELECT'),'private period direct read revoked');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4410000-0000-4000-8000-000000000001',true);
SELECT is(jsonb_array_length(public.payroll_employers('c4411000-0000-4000-8000-000000000001')->'items'),2,'bounded Employer discovery scopes Tenant');
SELECT is(public.payroll_employers('c4411000-0000-4000-8000-000000000001')->>'unique_employer',NULL::text,'multiple Employers receive no implicit default');
SELECT throws_ok($$SELECT public.payroll_calendar_preview('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000002','2030-01-25',24,1,'following','Africa/Cairo')$$,'42501','payroll_forbidden','cross Tenant Employer refused');
SELECT set_config('test.c4quote',pg_temp.c4preview()::text,true);
SELECT set_config('test.c4saved',pg_temp.c4save()::text,true);
SELECT is(pg_temp.c4save(),current_setting('test.c4saved')::jsonb,'exact save receipt replay');
SELECT throws_ok($$SELECT pg_temp.c4save(reason=>'Changed intent')$$,'PT409','payroll_attempt_conflict','same key different canonical intent refused');
SELECT throws_ok($$SELECT pg_temp.c4save(ky=>'c4419000-0000-4000-8000-000000000010')$$,'PT409','payroll_stale','stale expected revision refused');
SELECT set_config('test.c4next',(public.payroll_workspace('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001')->'next_preview')::text,true);
SELECT throws_ok($$SELECT pg_temp.c4generate(0)$$,'PT409','payroll_stale','stale generation refused');
SELECT set_config('test.c4generated',pg_temp.c4generate()::text,true);
SELECT is(pg_temp.c4generate(),current_setting('test.c4generated')::jsonb,'exact period receipt replay');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM payroll.periods WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),2,'two periods without replay duplicates');
SELECT is((SELECT count(*)::integer FROM payroll.audit_events WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),2,'one success audit per distinct command');
SELECT is((SELECT count(*)::integer FROM payroll.command_receipts WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),2,'two distinct receipts');
SELECT is((SELECT min(starts_on)::text FROM payroll.periods WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),'2030-01-25','first historical start preserved');
SELECT is((SELECT min(ends_on)::text FROM payroll.periods WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),'2030-02-24','first historical end preserved');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.c4preview('2030-03-26',25)$$,'22023','payroll_transition_required','transition gap refused');
SELECT set_config('test.c4transition',pg_temp.c4preview('2030-03-25',25)::text,true);
SELECT lives_ok($$SELECT pg_temp.c4save('2030-03-25',25,2,'c4419000-0000-4000-8000-000000000003',current_setting('test.c4transition')::jsonb)$$,'reviewed contiguous future transition saved');
RESET ROLE;
SELECT is((SELECT min(ends_on)::text FROM payroll.periods WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),'2030-02-24','calendar revision preserves history');
SELECT is((SELECT starts_on::text FROM payroll.periods WHERE tenant_id='c4411000-0000-4000-8000-000000000001' AND is_transition),'2030-03-25','transition begins immediately after prior generated end');
CREATE FUNCTION pg_temp.reject_c4audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'qa_audit_failure' USING ERRCODE='P0001'; END $$;
CREATE TRIGGER qa_c4audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_c4audit();
SET LOCAL ROLE authenticated;
SELECT set_config('test.c4next',(public.payroll_workspace('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001')->'next_preview')::text,true);
SELECT throws_ok($$SELECT pg_temp.c4generate(3,'c4419000-0000-4000-8000-000000000004')$$,'P0001','qa_audit_failure','audit failure refuses whole command');
RESET ROLE;
DROP TRIGGER qa_c4audit_failure ON payroll.audit_events;
SELECT is((SELECT count(*)::integer FROM payroll.periods WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),3,'audit failure leaves no period');
SELECT is((SELECT revision FROM payroll.calendar_heads WHERE tenant_id='c4411000-0000-4000-8000-000000000001'),3,'audit failure rolls back CAS revision');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='c4411000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.c4save()$$,'55000','payroll_disabled','current entitlement rechecked before receipt replay');
SELECT lives_ok($$SELECT public.payroll_workspace('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001')$$,'retained scoped history readable after entitlement loss');
RESET ROLE;
UPDATE platform_core.tenant_capability_entitlements SET is_granted=true WHERE tenant_id='c4411000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='c4411000-0000-4000-8000-000000000001' AND user_id='c4410000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.c4save()$$,'42501','payroll_forbidden','membership loss refuses receipt replay');
SELECT set_config('request.jwt.claim.sub','c4410000-0000-4000-8000-000000000002',true);
SELECT lives_ok($$SELECT public.payroll_workspace('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001')$$,'reader can view retained periods');
SELECT throws_ok($$SELECT pg_temp.c4preview()$$,'42501','payroll_forbidden','reader cannot configure');
SELECT throws_ok($$SELECT * FROM payroll.periods$$,'42501','permission denied for schema payroll','direct private schema unavailable');
RESET ROLE;
UPDATE platform_core.tenants SET lifecycle_state='suspended' WHERE id='c4411000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_workspace('c4411000-0000-4000-8000-000000000001','c4413000-0000-4000-8000-000000000001')$$,'42501','payroll_forbidden','Tenant suspension denies ordinary history');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
