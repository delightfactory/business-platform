-- Dedicated QA only; all records and source changes roll back.
BEGIN;
DO $$ BEGIN IF current_database() NOT IN ('business_platform_cube4_adam_positive_qa','postgres') OR NOT EXISTS(SELECT 1 FROM pg_database WHERE datname='business_platform_cube4_adam_positive_qa') THEN RAISE EXCEPTION 'dedicated local payroll QA required';END IF;END $$;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
SELECT id::uuid,email,'x',now(),'{}','{}','authenticated','authenticated',now(),now() FROM (VALUES
 ('ea160000-0000-4000-8000-000000000001','edara-owner@example.test'),
 ('ea160000-0000-4000-8000-000000000002','edara-preparer@example.test'),
 ('ea160000-0000-4000-8000-000000000003','edara-denied@example.test'))x(id,email);
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('ea161000-0000-4000-8000-000000000001','NONLEGAL EDARA payroll fixture','ea160000-0000-4000-8000-000000000001'),
 ('ea161000-0000-4000-8000-000000000002','NONLEGAL foreign scope','ea160000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('ea161000-0000-4000-8000-000000000001','ea162000-0000-4000-8000-000000000001','edara.owner',1,ARRAY['payroll.view','payroll.prepare','payroll.review','payroll_config.manage']),
 ('ea161000-0000-4000-8000-000000000001','ea162000-0000-4000-8000-000000000002','edara.preparer',1,ARRAY['payroll.prepare']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('ea161000-0000-4000-8000-000000000001','ea160000-0000-4000-8000-000000000001','ea160000-0000-4000-8000-000000000001'),
 ('ea161000-0000-4000-8000-000000000001','ea160000-0000-4000-8000-000000000002','ea160000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('ea161000-0000-4000-8000-000000000001','ea160000-0000-4000-8000-000000000001','ea162000-0000-4000-8000-000000000001'),
 ('ea161000-0000-4000-8000-000000000001','ea160000-0000-4000-8000-000000000002','ea162000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name,is_default,is_active) VALUES
 ('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','NONLEGAL fixture','NONLEGAL fixture',true,true),
 ('ea161000-0000-4000-8000-000000000002','ea163000-0000-4000-8000-000000000002','NONLEGAL foreign','NONLEGAL foreign',true,true);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'ea161000-0000-4000-8000-000000000001',capability,true,now()-interval '1 minute','ea160000-0000-4000-8000-000000000001','rollback NONLEGAL fixture' FROM unnest(ARRAY['hr.people','hr.payroll'])capability;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000001',true);
SELECT is(public.payroll_run_collection('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001')->'items','[]'::jsonb,'empty collection is a real empty list');
SELECT throws_ok($$SELECT public.payroll_run_collection('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000002')$$,'42501','payroll_forbidden','collection rejects cross-tenant employer');
SELECT throws_ok($$SELECT public.payroll_run_collection('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',NULL,0)$$,'22023','payroll_invalid','collection rejects unbounded/invalid limits');
SELECT set_config('edara.preview',public.payroll_calendar_preview('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','2026-01-01',NULL,1,'following','Africa/Cairo')::text,true);
SELECT set_config('edara.creation',jsonb_build_object('mode','first','revision',0,'reviewed',current_setting('edara.preview')::jsonb,'start','2026-01-01','cutoff',NULL,'payment',1,'month','following','timezone','Africa/Cairo')::text,true);
SELECT set_config('edara.result',public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.creation')::jsonb,'ea164000-0000-4000-8000-000000000001','ea164000-0000-4000-8000-000000000002','ea164000-0000-4000-8000-000000000003')::text,true);
SELECT is(current_setting('edara.result')::jsonb->>'status','review','creation calculates and opens the real review run');
SELECT is(public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.creation')::jsonb,'ea164000-0000-4000-8000-000000000001','ea164000-0000-4000-8000-000000000002','ea164000-0000-4000-8000-000000000003'),current_setting('edara.result')::jsonb,'lost response replays the exact original result');
SELECT throws_ok($$SELECT public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.creation')::jsonb||'{"payment":2}','ea164000-0000-4000-8000-000000000001','ea164000-0000-4000-8000-000000000002','ea164000-0000-4000-8000-000000000003')$$,'PT409','payroll_attempt_conflict','same identity cannot change reviewed fields');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.periods WHERE tenant_id='ea161000-0000-4000-8000-000000000001'),1::bigint,'replay never creates a second period');
SELECT is((SELECT count(*) FROM payroll.candidates WHERE tenant_id='ea161000-0000-4000-8000-000000000001'),1::bigint,'replay never calculates a second candidate');
CREATE FUNCTION pg_temp.edara_calculation_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.tenant_id='ea161000-0000-4000-8000-000000000001' AND NEW.action='run_calculate' THEN RAISE EXCEPTION 'edara_calculation_failed' USING ERRCODE='23514';END IF;RETURN NEW;END $$;
CREATE TRIGGER edara_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.edara_calculation_failure();
SET LOCAL ROLE authenticated;
SELECT set_config('edara.next',(public.payroll_workspace('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001')->'next_preview')::text,true);
SELECT throws_ok($$SELECT public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',jsonb_build_object('mode','next','revision',1,'reviewed',current_setting('edara.next')::jsonb),'ea164000-0000-4000-8000-000000000004','ea164000-0000-4000-8000-000000000005','ea164000-0000-4000-8000-000000000006')$$,'23514','edara_calculation_failed','calculation failure rolls back the complete creation');
RESET ROLE;
DROP TRIGGER edara_failure ON payroll.audit_events;
SELECT is((SELECT count(*) FROM payroll.periods WHERE tenant_id='ea161000-0000-4000-8000-000000000001'),1::bigint,'failed calculation leaves no orphan period');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE tenant_id='ea161000-0000-4000-8000-000000000001'),3::bigint,'failed creation leaves none of its three receipts');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',jsonb_build_object('mode','next','revision',0,'reviewed',current_setting('edara.next')::jsonb),gen_random_uuid(),gen_random_uuid(),gen_random_uuid())$$,'PT409','payroll_stale','stale preview never silently creates another period');
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000002',true);
SELECT is(jsonb_array_length(public.payroll_run_collection('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001')->'items'),1,'preparer can read operational run list without payment privilege');
SELECT is(public.payroll_run_collection('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001')->'items'->0->'paid','null'::jsonb,'preparer never receives unauthorized payment balance');
SELECT throws_ok($$SELECT public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.creation')::jsonb,gen_random_uuid(),gen_random_uuid(),gen_random_uuid())$$,'42501','payroll_forbidden','preparer cannot create calendar without configuration privilege');
-- A saved, uncalculated period is a valid direct task. No new calendar is
-- generated and a preparer needs no calendar-edit permission to calculate it.
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000001',true);
SELECT set_config('edara.saved_period',(public.payroll_generate_next_period('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',1,gen_random_uuid(),current_setting('edara.next')::jsonb)->>'period_id'),true);
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000002',true);
SELECT set_config('edara.existing',jsonb_build_object('mode','existing','period',current_setting('edara.saved_period'))::text,true);
SELECT set_config('edara.existing_result',public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.existing')::jsonb,'ea165000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000002','ea165000-0000-4000-8000-000000000003')::text,true);
SELECT is(current_setting('edara.existing_result')::jsonb->>'period_id',current_setting('edara.saved_period'),'existing-period calculation keeps the selected actual period');
SELECT is(current_setting('edara.existing_result')::jsonb->>'status','review','existing empty period is calculated by preparer without calendar-edit privilege');
SELECT is(public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.existing')::jsonb,'ea165000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000002','ea165000-0000-4000-8000-000000000003'),current_setting('edara.existing_result')::jsonb,'existing-period lost-response replay returns the original run');
SELECT throws_ok($$SELECT public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.existing')::jsonb,gen_random_uuid(),gen_random_uuid(),gen_random_uuid())$$,'PT409','payroll_run_stale','another active run blocks a fresh existing-period attempt');
SELECT throws_ok($$SELECT public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',jsonb_build_object('mode','existing','period','ea163000-0000-4000-8000-000000000002'),gen_random_uuid(),gen_random_uuid(),gen_random_uuid())$$,'42501','payroll_forbidden','existing period must belong to exact tenant and employer');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.periods WHERE tenant_id='ea161000-0000-4000-8000-000000000001'),2::bigint,'existing calculation and replay never generate another period');
SELECT is((SELECT count(*) FROM payroll.candidates WHERE tenant_id='ea161000-0000-4000-8000-000000000001'),2::bigint,'existing calculation and replay generate one candidate only');
SET LOCAL ROLE authenticated;
SELECT public.payroll_run_command('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.saved_period')::uuid,(current_setting('edara.existing_result')::jsonb->>'id')::uuid,(current_setting('edara.existing_result')::jsonb->>'revision')::integer,'cancel','NONLEGAL cancel and restart fixture',gen_random_uuid());
SELECT is(public.payroll_create_run('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001',current_setting('edara.existing')::jsonb,gen_random_uuid(),gen_random_uuid(),gen_random_uuid())->>'status','review','cancelled run can restart on the same saved period');
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.payroll_run_collection('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001')$$,'42501','payroll_forbidden','non-member cannot read payroll collection');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
