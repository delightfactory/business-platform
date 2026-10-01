BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

-- HR recorder, approver, manager-only actor, and two Employees. All workflow
-- effects below are exercised through authenticated public RPCs.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('d3300000-0000-4000-8000-000000000001','correction-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3300000-0000-4000-8000-000000000002','correction-approver@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3300000-0000-4000-8000-000000000003','correction-manager-only@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3300000-0000-4000-8000-000000000004','correction-other-employee@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
 VALUES('d3301000-0000-4000-8000-000000000001','Leave correction test','d3300000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('d3301000-0000-4000-8000-000000000001','d3302000-0000-4000-8000-000000000001','corr.manage.approve.v1',1,ARRAY['leave.manage','leave.view','leave.approve','leave_balance.adjust'],false),
 ('d3301000-0000-4000-8000-000000000001','d3302000-0000-4000-8000-000000000002','corr.approve.v1',1,ARRAY['leave.approve','leave.view'],false),
 ('d3301000-0000-4000-8000-000000000001','d3302000-0000-4000-8000-000000000003','corr.manage.v1',1,ARRAY['leave.manage','leave.view','leave_balance.adjust'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('d3301000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000001'),
 ('d3301000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000002','d3300000-0000-4000-8000-000000000001'),
 ('d3301000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000003','d3300000-0000-4000-8000-000000000001'),
 ('d3301000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000004','d3300000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('d3301000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000001','d3302000-0000-4000-8000-000000000001'),
 ('d3301000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000002','d3302000-0000-4000-8000-000000000002'),
 ('d3301000-0000-4000-8000-000000000001','d3300000-0000-4000-8000-000000000003','d3302000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)
 VALUES('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001','Correction Employer',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES
 ('d3301000-0000-4000-8000-000000000001','d3304000-0000-4000-8000-000000000001','CORR-A','Correction Employee A','d3300000-0000-4000-8000-000000000001'),
 ('d3301000-0000-4000-8000-000000000001','d3304000-0000-4000-8000-000000000002','CORR-B','Correction Employee B','d3300000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis) VALUES
 ('d3301000-0000-4000-8000-000000000001','d3305000-0000-4000-8000-000000000001','d3304000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.today')::date-179,'active','monthly'),
 ('d3301000-0000-4000-8000-000000000001','d3305000-0000-4000-8000-000000000002','d3304000-0000-4000-8000-000000000002','d3303000-0000-4000-8000-000000000001',current_setting('test.today')::date-179,'active','monthly');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('d3301000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','d3300000-0000-4000-8000-000000000001','correction test'),
 ('d3301000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','d3300000-0000-4000-8000-000000000001','correction test');

UPDATE people.employments SET start_date=current_setting('test.today')::date-1100 WHERE tenant_id='d3301000-0000-4000-8000-000000000001' AND employee_id='d3304000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3300000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001','annual','Annual calendar',current_setting('test.today')::date-1100,NULL,ARRAY[6]::smallint[],'[]','Verified calendar','Annual test')::text,true);
SELECT set_config('test.period',public.leave_create_year_period('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date-364,current_setting('test.today')::date,'Annual current','Annual test')::text,true);
SELECT set_config('test.old_period',public.leave_create_year_period('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date-700,current_setting('test.today')::date-611,'Annual 90 service days','Annual test')::text,true);
SELECT set_config('test.type',public.leave_create_type('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001','annual','Annual paid',current_setting('test.today')::date-1100,'paid','tracked',true,'Verified annual type','Annual test','working_days')::text,true);
RESET ROLE;
CREATE FUNCTION pg_temp.quote(employee_suffix integer,period_key text,as_of date,rates jsonb DEFAULT '[]') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.leave_preview_annual_entitlement('d3301000-0000-4000-8000-000000000001',('d3304000-0000-4000-8000-'||lpad(employee_suffix::text,12,'0'))::uuid,'d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,current_setting(period_key)::uuid,as_of,rates,'HR verified category'); $$;
CREATE FUNCTION pg_temp.post(employee_suffix integer,period_key text,q jsonb,ky text) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.leave_post_annual_entitlement('d3301000-0000-4000-8000-000000000001',('d3304000-0000-4000-8000-'||lpad(employee_suffix::text,12,'0'))::uuid,'d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,current_setting(period_key)::uuid,(q->>'as_of')::date,q->'rates',q->>'source',q->>'review_hash','Verified annual entitlement',ky); $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('test.a',pg_temp.quote(1,'test.period',current_setting('test.today')::date)::text,true);
SELECT is((current_setting('test.a')::jsonb->>'target_total')::numeric,7.40,'180 service days grant 15*180/365 rounded upwards');
SELECT is((pg_temp.quote(1,'test.period',current_setting('test.today')::date-1)->>'target_total')::numeric,0.00,'179 days not eligible');
SELECT is((pg_temp.quote(2,'test.old_period',current_setting('test.today')::date-611)->>'target_total')::numeric,5.18,'21*90/365 rounds to5.18');
SELECT throws_ok($$SELECT pg_temp.quote(1,'test.period',current_setting('test.today')::date+1)$$,'22023','leave_annual_input_invalid','future service cannot be granted');
SELECT set_config('test.rates',jsonb_build_array(jsonb_build_object('from',current_setting('test.today')::date-89,'annual_days',30,'source','HR qualifying category'))::text,true);
SELECT is((pg_temp.quote(1,'test.period',current_setting('test.today')::date,current_setting('test.rates')::jsonb)->>'target_total')::numeric,11.10,'dated category: 90*15 +90*30, divide once then round');
SELECT is(jsonb_array_length(pg_temp.quote(1,'test.period',current_setting('test.today')::date,current_setting('test.rates')::jsonb)->'segments'),2,'dated rate change preserves two contiguous evidence segments');
SELECT set_config('test.split',jsonb_build_array(jsonb_build_object('from',current_setting('test.today')::date-364,'annual_days',21,'source','Evidence one'),jsonb_build_object('from',current_setting('test.today')::date-363,'annual_days',21,'source','Evidence two'),jsonb_build_object('from',current_setting('test.today')::date-362,'annual_days',21,'source','Evidence three'))::text,true);
SELECT is((pg_temp.quote(2,'test.period',current_setting('test.today')::date,current_setting('test.split')::jsonb)->>'target_total')::numeric,21.00,'split sources never create numeric overgrant at exact21');
SELECT throws_ok($$SELECT pg_temp.quote(2,'test.period',current_setting('test.today')::date,'[{"from":"2000-01-01","annual_days":30,"source":"bad"}]')$$,'22023','leave_annual_rates_invalid','rate date before service refused');
SELECT throws_ok($$SELECT pg_temp.quote(2,'test.period',current_setting('test.today')::date,jsonb_build_array(jsonb_build_object('from',current_setting('test.today')::date-364,'annual_days',15,'source','Invalid reduction')))$$,'23514','leave_annual_rate_below_policy','override cannot fall below applicable company rule');
SELECT throws_ok($$SELECT pg_temp.quote(1,'test.period',current_setting('test.today')::date,'[{"from":null,"annual_days":30,"source":"Missing date"}]')$$,'22023','leave_annual_rates_invalid','null rate date is invalid');
RESET ROLE;
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('d3301000-0000-4000-8000-000000000001','d3304000-0000-4000-8000-000000000003','ANNUAL-TRANSITION','Annual transition','d3300000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis) VALUES('d3301000-0000-4000-8000-000000000001','d3305000-0000-4000-8000-000000000003','d3304000-0000-4000-8000-000000000003','d3303000-0000-4000-8000-000000000001',current_setting('test.today')::date-365,'active','monthly');
SET LOCAL ROLE authenticated;
SELECT is((pg_temp.quote(3,'test.period',current_setting('test.today')::date)->>'target_total')::numeric,15.02,'service-year boundary uses364*15 +1*21 in current365day period');
SELECT is(jsonb_array_length(pg_temp.quote(3,'test.period',current_setting('test.today')::date)->'segments'),2,'service-year transition is split into dated segments');
SELECT throws_ok($$SELECT public.leave_preview_annual_entitlement('d3301000-0000-4000-8000-000000000099','d3304000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,current_setting('test.period')::uuid,current_setting('test.today')::date,'[]','HR verified')$$,'42501','leave_forbidden','cross-tenant calculator denied');
SELECT set_config('test.posted',pg_temp.post(1,'test.period',current_setting('test.a')::jsonb,'annual-first')::text,true);
SELECT is(current_setting('test.posted')::jsonb->>'state','posted','first reviewed grant posts');
SELECT is((pg_temp.post(1,'test.period',current_setting('test.a')::jsonb,'annual-first')->>'replay')::boolean,true,'same intent returns recorded receipt before current recalculation');
SELECT throws_ok($$SELECT pg_temp.post(1,'test.period',current_setting('test.a')::jsonb,'annual-different-key')$$,'PT409','leave_annual_review_conflict','stale cumulative grant cannot post twice with another key');
SELECT set_config('test.noop',pg_temp.post(1,'test.period',pg_temp.quote(1,'test.period',current_setting('test.today')::date),'annual-noop')::text,true);
SELECT is(current_setting('test.noop')::jsonb->>'state','up_to_date','already granted amount creates no second ledger entry');
SELECT set_config('test.special',pg_temp.post(1,'test.period',pg_temp.quote(1,'test.period',current_setting('test.today')::date,current_setting('test.rates')::jsonb),'annual-category')::text,true);
SELECT is((current_setting('test.special')::jsonb->'quote'->>'delta')::numeric,3.70,'category uplift appends only cumulative difference');
SELECT throws_ok($$SELECT pg_temp.quote(1,'test.period',current_setting('test.today')::date)$$,'23514','leave_annual_reduction_requires_review','recalculation cannot erase earlier category entitlement');
SELECT lives_ok($$SELECT public.leave_save_annual_policy('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,0,16,22,170,365,'Company benefit evidence','Worker favourable policy')$$,'bounded company policy is configurable');
SELECT throws_ok($$SELECT public.leave_save_annual_policy('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,0,16,22,170,365,'Company benefit evidence','Worker favourable policy')$$,'PT409','leave_annual_review_conflict','stale company setting cannot overwrite new version');
SELECT throws_ok($$SELECT public.leave_save_annual_policy('d3301000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,1,14,21,180,365,'Company evidence','Below minima')$$,'22023','leave_annual_input_invalid','settings cannot reduce default minimum rates');
SELECT set_config('request.jwt.claim.sub','d3300000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT pg_temp.quote(1,'test.period',current_setting('test.today')::date)$$,'42501','leave_forbidden','approve/view actor cannot calculate or grant balances');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3301000-0000-4000-8000-000000000001' AND entry_kind='annual_grant'),1,'exactly one base annual grant');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3301000-0000-4000-8000-000000000001' AND entry_kind='adjustment'),1,'one category difference ledger entry');
SELECT is((SELECT sum(delta_days) FROM leave.ledger_entries WHERE tenant_id='d3301000-0000-4000-8000-000000000001'),11.10,'ledger total matches cumulative target');
SELECT throws_ok($$UPDATE leave.annual_policies SET first_year_days=20 WHERE tenant_id='d3301000-0000-4000-8000-000000000001'$$,'55000','leave_snapshot_immutable','company policy history immutable');
SELECT throws_ok($$DELETE FROM leave.annual_calculations WHERE tenant_id='d3301000-0000-4000-8000-000000000001'$$,'55000','leave_snapshot_immutable','calculation receipt history immutable');
SELECT ok(NOT has_function_privilege('anon','public.leave_post_annual_entitlement(uuid,uuid,uuid,uuid,uuid,date,jsonb,text,text,text,text)','EXECUTE'),'anon cannot call annual posting');
SELECT ok(NOT has_function_privilege('authenticated','leave.annual_quote(uuid,uuid,uuid,uuid,uuid,date,jsonb,text)','EXECUTE'),'private quote not directly callable');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3300000-0000-4000-8000-000000000001',true);
SELECT set_config('test.version',(SELECT public.leave_annual_context('d3301000-0000-4000-8000-000000000001','d3304000-0000-4000-8000-000000000002','d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,current_setting('test.period')::uuid)->'policy'->>'version'),true);
SELECT is(current_setting('test.version'),'1','context reads saved company version');
SELECT is((public.leave_annual_context('d3301000-0000-4000-8000-000000000001','d3304000-0000-4000-8000-000000000001','d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,current_setting('test.period')::uuid)->'last_calculation'->'quote'->'rates')::text,current_setting('test.rates')::jsonb::text,'last calculation restores dated HR eligibility evidence');
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d3301000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type')::uuid AND version=1),true);
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT public.leave_post_balance('d3301000-0000-4000-8000-000000000001','d3304000-0000-4000-8000-000000000002','d3303000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',1,current_setting('test.type_version')::uuid,'annual-manual-opening','Legacy verified balance','Manual opening test')$$,'manual opening remains available independently');
SELECT throws_ok($$SELECT pg_temp.quote(2,'test.period',current_setting('test.today')::date)$$,'23514','leave_annual_manual_balance_requires_review','automatic accrual cannot double grant manual opening');
RESET ROLE;
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()-interval '1 second' WHERE tenant_id='d3301000-0000-4000-8000-000000000001' AND capability_key='hr.leave';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.quote(3,'test.period',current_setting('test.today')::date)$$,'55000','leave_new_work_disabled','disabled capability blocks new annual accrual');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
