BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);
SELECT set_config('test.day1',(current_setting('test.today')::date + CASE WHEN extract(dow FROM current_setting('test.today')::date)::integer=0 THEN 7 ELSE 7-extract(dow FROM current_setting('test.today')::date)::integer END)::text,true);

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('e3110000-0000-4000-8000-000000000001','projection-self@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e3110000-0000-4000-8000-000000000002','projection-manager@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()),
       ('e3110000-0000-4000-8000-000000000003','projection-approver@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('e3120000-0000-4000-8000-000000000001','Leave projection tenant','e3110000-0000-4000-8000-000000000002'),
       ('e3120000-0000-4000-8000-000000000002','Other projection tenant','e3110000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('e3120000-0000-4000-8000-000000000001','e3130000-0000-4000-8000-000000000001','projection.self',1,ARRAY['leave.self.view'],false),
       ('e3120000-0000-4000-8000-000000000001','e3130000-0000-4000-8000-000000000002','projection.hr',1,ARRAY['leave.view','leave.manage','leave.approve','leave_balance.adjust'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('e3120000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000002'),
       ('e3120000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000002','e3110000-0000-4000-8000-000000000002'),
       ('e3120000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000003','e3110000-0000-4000-8000-000000000002');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('e3120000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000001','e3130000-0000-4000-8000-000000000001'),
       ('e3120000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000002','e3130000-0000-4000-8000-000000000002'),
       ('e3120000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000003','e3130000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)
VALUES ('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001','Projection Employer',true,true),
       ('e3120000-0000-4000-8000-000000000002','e3140000-0000-4000-8000-000000000002','Other Employer',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000001','PROJECTION-SELF','Projection Self','e3110000-0000-4000-8000-000000000002'),
       ('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000002','PROJECTION-OTHER','Projection HR Employee','e3110000-0000-4000-8000-000000000002');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)
VALUES ('e3120000-0000-4000-8000-000000000001','e3160000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',current_setting('test.today')::date-20,'active','monthly'),
       ('e3120000-0000-4000-8000-000000000001','e3160000-0000-4000-8000-000000000002','e3150000-0000-4000-8000-000000000002','e3140000-0000-4000-8000-000000000001',current_setting('test.today')::date-20,'active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000001','e3110000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('e3120000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','e3110000-0000-4000-8000-000000000002','projection test'),
       ('e3120000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','e3110000-0000-4000-8000-000000000002','projection test');

SELECT has_function('public','leave_payroll_facts',ARRAY['uuid','uuid','date','date','date','uuid','integer']);
SELECT ok(NOT has_table_privilege('authenticated','leave.request_days','SELECT'),'approved day snapshots are RPC-only');
SELECT ok(NOT has_table_privilege('authenticated','leave.request_consumptions','SELECT'),'consumption provenance is RPC-only');
SELECT ok(NOT has_table_privilege('authenticated','leave.cancellation_events','SELECT'),'cancellation provenance is RPC-only');
SELECT ok(has_function_privilege('authenticated','public.leave_payroll_facts(uuid,uuid,date,date,date,uuid,integer)','EXECUTE'),'authenticated can call scoped projection');
SELECT ok(NOT has_function_privilege('anon','public.leave_payroll_facts(uuid,uuid,date,date,date,uuid,integer)','EXECUTE'),'anonymous cannot call projection');
SELECT ok(NOT has_function_privilege('service_role','public.leave_payroll_facts(uuid,uuid,date,date,date,uuid,integer)','EXECUTE'),'service role cannot bypass projection authorization');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3110000-0000-4000-8000-000000000002',true);
SELECT set_config('test.calendar',public.leave_create_calendar('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 'projection-cal','Projection Calendar',current_setting('test.today')::date-5,NULL,ARRAY[5,6]::smallint[],'[]'::jsonb,'source calendar','projection fixture')::text,true);
SELECT set_config('test.period',public.leave_create_year_period('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 current_setting('test.calendar')::uuid,current_setting('test.today')::date-2,current_setting('test.today')::date+20,'Projection period','explicit fixture range')::text,true);
SELECT set_config('test.type',public.leave_create_type('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 'projection-tracked','Projection tracked leave',current_setting('test.today')::date-5,'paid','tracked',true,
 'manual verified policy','projection fixture','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='e3120000-0000-4000-8000-000000000001'
 AND leave_type_id=current_setting('test.type')::uuid AND version=1),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3110000-0000-4000-8000-000000000002',true);
SELECT public.leave_post_balance('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000002','e3140000-0000-4000-8000-000000000001',
 current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',4,current_setting('test.type_version')::uuid,
 'projection-opening','HR verified test balance','Projection fixture account');
SELECT set_config('test.req1',public.leave_record_hr_request('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000002','e3160000-0000-4000-8000-000000000002',
 current_setting('test.type')::uuid,current_setting('test.day1')::date,current_setting('test.day1')::date,false,NULL,'projection source one','projection-req-1')->>'id',true);
SELECT set_config('test.req2',public.leave_record_hr_request('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000002','e3160000-0000-4000-8000-000000000002',
 current_setting('test.type')::uuid,current_setting('test.day1')::date+1,current_setting('test.day1')::date+1,false,NULL,'projection source two','projection-req-2')->>'id',true);
SELECT set_config('test.req3',public.leave_record_hr_request('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000002','e3160000-0000-4000-8000-000000000002',
 current_setting('test.type')::uuid,current_setting('test.day1')::date+2,current_setting('test.day1')::date+2,false,NULL,'projection source three','projection-req-3')->>'id',true);
SELECT set_config('test.pending',public.leave_record_hr_request('e3120000-0000-4000-8000-000000000001','e3150000-0000-4000-8000-000000000002','e3160000-0000-4000-8000-000000000002',
 current_setting('test.type')::uuid,current_setting('test.day1')::date+3,current_setting('test.day1')::date+3,false,NULL,'unapproved pending source','projection-pending')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3110000-0000-4000-8000-000000000003',true);
SELECT public.leave_approve_request('e3120000-0000-4000-8000-000000000001',current_setting('test.req1')::uuid,1,1,'approve projection one','projection-approve-1');
SELECT public.leave_approve_request('e3120000-0000-4000-8000-000000000001',current_setting('test.req2')::uuid,1,1,'approve projection two','projection-approve-2');
SELECT public.leave_approve_request('e3120000-0000-4000-8000-000000000001',current_setting('test.req3')::uuid,1,1,'approve projection three','projection-approve-3');
SELECT set_config('test.baseline',public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 current_setting('test.day1')::date,current_setting('test.day1')::date+3,NULL,NULL,100)::text,true);
SELECT is(jsonb_array_length(current_setting('test.baseline')::jsonb->'items'),3,'only three ever-approved source days are projected; pending is omitted');
SELECT is((current_setting('test.baseline')::jsonb->'items'->0->>'effective_units')::numeric,1::numeric,'approved source carries its factual day quantity');
SELECT is((current_setting('test.baseline')::jsonb->'items'->0->>'approved_by')::uuid,'e3110000-0000-4000-8000-000000000003'::uuid,'approved source retains the actual approver identity');
SELECT ok(current_setting('test.baseline')::jsonb->'items'->0->>'approved_at' IS NOT NULL,'approved source retains its approval timestamp');
SELECT ok((current_setting('test.baseline')::jsonb->'items'->0->>'projection_only')::boolean,'source explicitly marks projection-only');
SELECT ok(NOT (current_setting('test.baseline')::jsonb->'items'->0->>'consumed_by_payroll')::boolean,'projection does not claim payroll consumption');
SELECT set_config('test.cancel1',public.leave_request_cancellation('e3120000-0000-4000-8000-000000000001',current_setting('test.req1')::uuid,2,
 'cancel request through separate review','projection-cancel-request-1')::text,true);
SELECT set_config('test.cancel1accepted',public.leave_decide_cancellation('e3120000-0000-4000-8000-000000000001',
 (current_setting('test.cancel1')::jsonb->'cancellation'->>'id')::uuid,1,'accept','accept cancellation for source one','projection-cancel-accept-1')::text,true);
SELECT is((public.leave_decide_cancellation('e3120000-0000-4000-8000-000000000001',(current_setting('test.cancel1')::jsonb->'cancellation'->>'id')::uuid,
 1,'accept','accept cancellation for source one','projection-cancel-accept-1')->>'state'),'accepted','same cancellation decision key replays');
SELECT set_config('test.directcancel',public.leave_cancel_approved_request('e3120000-0000-4000-8000-000000000001',current_setting('test.req2')::uuid,2,
 'direct cancellation source two','projection-direct-cancel-2')::text,true);
SELECT is((public.leave_cancel_approved_request('e3120000-0000-4000-8000-000000000001',current_setting('test.req2')::uuid,2,
 'direct cancellation source two','projection-direct-cancel-2')->>'state'),'cancelled','same direct-cancel operation key replays');
SELECT set_config('test.after',public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 current_setting('test.day1')::date,current_setting('test.day1')::date+3,NULL,NULL,1)::text,true);
SELECT is(jsonb_array_length(current_setting('test.after')::jsonb->'items'),1,'bounded first page returns one approved source');
SELECT ok((current_setting('test.after')::jsonb->>'has_more')::boolean,'first page advertises a continuation');
SELECT set_config('test.page2',public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 current_setting('test.day1')::date,current_setting('test.day1')::date+3,(current_setting('test.after')::jsonb->>'next_after_date')::date,
 (current_setting('test.after')::jsonb->>'next_after_request_id')::uuid,1)::text,true);
SELECT is(jsonb_array_length(current_setting('test.page2')::jsonb->'items'),1,'keyset cursor returns the second source');
SELECT is((current_setting('test.page2')::jsonb->'items'->0->>'leave_date')::date,current_setting('test.day1')::date+1,'second page advances by date/request key');
SELECT is((current_setting('test.page2')::jsonb->>'has_more')::boolean,true,'second bounded page continues');
SELECT set_config('test.page3',public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 current_setting('test.day1')::date,current_setting('test.day1')::date+3,(current_setting('test.page2')::jsonb->>'next_after_date')::date,
 (current_setting('test.page2')::jsonb->>'next_after_request_id')::uuid,1)::text,true);
SELECT is(jsonb_array_length(current_setting('test.page3')::jsonb->'items'),1,'terminal page returns final approved source');
SELECT is((current_setting('test.page3')::jsonb->>'has_more')::boolean,false,'terminal page stops without a phantom next cursor');
SELECT set_config('test.cancelleditem',public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 current_setting('test.day1')::date,current_setting('test.day1')::date,NULL,NULL,10)::text,true);
SELECT is((current_setting('test.cancelleditem')::jsonb->'items'->0->>'request_id')::uuid,current_setting('test.req1')::uuid,'cancellation preserves stable source request identity');
SELECT is((current_setting('test.cancelleditem')::jsonb->'items'->0->>'original_units')::numeric,1::numeric,'cancelled source retains original approved quantity');
SELECT is((current_setting('test.cancelleditem')::jsonb->'items'->0->>'effective_units')::numeric,0::numeric,'accepted cancellation reduces current exposure to zero');
SELECT is((current_setting('test.cancelleditem')::jsonb->'items'->0->>'cancellation_id')::uuid,(current_setting('test.cancel1accepted')::jsonb->'cancellation'->>'id')::uuid,'source item links its accepted cancellation record');
SELECT set_config('test.cancelhistory',public.leave_cancellation_history('e3120000-0000-4000-8000-000000000001',current_setting('test.req1')::uuid,20,0)::text,true);
SELECT is((current_setting('test.cancelleditem')::jsonb->'items'->0->>'cancellation_event_id')::bigint,(SELECT (evt->>'id')::bigint FROM pg_catalog.jsonb_array_elements(current_setting('test.cancelhistory')::jsonb->'items') AS event_item(evt) WHERE evt->>'event_key'='hr.accepted'),'projection links the accepted event itself, not only the cancellation request');
SELECT is(current_setting('test.cancelleditem')::jsonb->'items'->0->>'cancellation_event_key','hr.accepted','accepted cancellation event is selected by its actual terminal event state');
SELECT is(current_setting('test.cancelleditem')::jsonb->'items'->0->>'cancellation_reason','accept cancellation for source one','accepted cancellation reason is preserved');
SELECT set_config('test.directitem',public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',current_setting('test.day1')::date+1,current_setting('test.day1')::date+1,NULL,NULL,10)::text,true);
SELECT is(current_setting('test.directitem')::jsonb->'items'->0->>'cancellation_event_key','hr.direct_cancelled','direct cancellation maps its distinct terminal event');
SELECT ok((current_setting('test.cancelleditem')::jsonb->'items'->0->'reversal_links'->0->'reversal_entry_ids') IS NOT NULL,'source links exact reversal ledger entry IDs');
SELECT is((current_setting('test.cancelleditem')::jsonb->'items'->0->'reversal_links'->0->>'reversed_units')::numeric,1::numeric,'linked reversal units preserve the exact allocation');
SELECT is((current_setting('test.cancelleditem')::jsonb->'items'->0->>'source_key'),(current_setting('test.baseline')::jsonb->'items'->0->>'source_key'),'cancellation retains request-preview-date source identity');
SELECT ok((current_setting('test.cancelleditem')::jsonb->'items'->0->>'source_version_hash')<> (current_setting('test.baseline')::jsonb->'items'->0->>'source_version_hash'),'current fact hash reflects its cancellation change');
SELECT is((current_setting('test.page3')::jsonb->'items'->0->>'source_version_hash'),(public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',
 current_setting('test.day1')::date+2,current_setting('test.day1')::date+2,NULL,NULL,10)->'items'->0->>'source_version_hash'),'unchanged source hash is stable across repeat reads');
SELECT throws_ok($q$SELECT public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',current_setting('test.today')::date,current_setting('test.today')::date+31,NULL,NULL,50)$q$,
 '22023','leave_payroll_facts_input_invalid','window over 31 inclusive days is rejected');
SELECT throws_ok($q$SELECT public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',current_setting('test.today')::date,current_setting('test.today')::date+1,current_setting('test.today')::date+1,NULL,50)$q$,
 '22023','leave_payroll_facts_input_invalid','partial cursor is rejected');
SELECT throws_ok($q$SELECT public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',current_setting('test.today')::date,current_setting('test.day1')::date,NULL,NULL,101)$q$,
 '22023','leave_payroll_facts_input_invalid','page size above 100 is rejected');
SELECT throws_ok($q$SELECT public.leave_payroll_facts('e3120000-0000-4000-8000-000000000002','e3140000-0000-4000-8000-000000000002',current_setting('test.today')::date,current_setting('test.today')::date+1,NULL,NULL,50)$q$,
 '42501','leave_forbidden','second tenant cannot be queried without its active membership and permission');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','e3110000-0000-4000-8000-000000000001',true);
SELECT throws_ok($q$SELECT public.leave_payroll_facts('e3120000-0000-4000-8000-000000000001','e3140000-0000-4000-8000-000000000001',current_setting('test.today')::date,current_setting('test.today')::date+5,NULL,NULL,50)$q$,
 '42501','leave_forbidden','self-only linked employee cannot read HR projection facts');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;






