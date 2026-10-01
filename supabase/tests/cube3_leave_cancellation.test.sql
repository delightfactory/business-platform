BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

-- Three narrowly scoped actors: linked employee, Leave manager/recorder, reviewer.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,  raw_user_meta_data,aud,role,created_at,updated_at)VALUES ('d3080000-0000-4000-8000-000000000001','cancel-employee@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()), ('d3080000-0000-4000-8000-000000000002','cancel-manager@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now()), ('d3080000-0000-4000-8000-000000000003','cancel-reviewer@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)VALUES ('d3081000-0000-4000-8000-000000000001','Leave cancellation test','d3080000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)VALUES ('d3081000-0000-4000-8000-000000000001','d3082000-0000-4000-8000-000000000001','cancel.self.v1',1,ARRAY['leave.self.view','leave.self.request','leave.manage'],false), ('d3081000-0000-4000-8000-000000000001','d3082000-0000-4000-8000-000000000002','cancel.hr.v1',1,ARRAY['leave.manage','leave.view','leave_balance.adjust'],false), ('d3081000-0000-4000-8000-000000000001','d3082000-0000-4000-8000-000000000003','cancel.approve.v1',1,ARRAY['leave.approve','leave.view'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)VALUES ('d3081000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000002'), ('d3081000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000002','d3080000-0000-4000-8000-000000000002'), ('d3081000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000003','d3080000-0000-4000-8000-000000000002');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)VALUES ('d3081000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000001','d3082000-0000-4000-8000-000000000001'), ('d3081000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000002','d3082000-0000-4000-8000-000000000002'), ('d3081000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000003','d3082000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)VALUES ('d3081000-0000-4000-8000-000000000001','d3083000-0000-4000-8000-000000000001','Cancellation Employer',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)VALUES ('d3081000-0000-4000-8000-000000000001','d3084000-0000-4000-8000-000000000001','CANCEL-SELF','Linked Employee','d3080000-0000-4000-8000-000000000002'), ('d3081000-0000-4000-8000-000000000001','d3084000-0000-4000-8000-000000000002','CANCEL-NO-USER','Employee without Auth account','d3080000-0000-4000-8000-000000000002');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis)VALUES ('d3081000-0000-4000-8000-000000000001','d3085000-0000-4000-8000-000000000001','d3084000-0000-4000-8000-000000000001','d3083000-0000-4000-8000-000000000001',current_setting('test.today')::date-20,'active','monthly'), ('d3081000-0000-4000-8000-000000000001','d3085000-0000-4000-8000-000000000002','d3084000-0000-4000-8000-000000000002','d3083000-0000-4000-8000-000000000001',current_setting('test.today')::date-20,'active','monthly');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)VALUES ('d3081000-0000-4000-8000-000000000001','d3084000-0000-4000-8000-000000000001',  'd3080000-0000-4000-8000-000000000001','d3080000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)VALUES ('d3081000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','d3080000-0000-4000-8000-000000000002','cancellation fixture'), ('d3081000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','d3080000-0000-4000-8000-000000000002','cancellation fixture');
SELECT is(to_regprocedure('public.leave_my_request_cancellation(uuid,uuid,integer,text,text)') IS NOT NULL,true,'narrow own cancellation-request API is installed');
SELECT is(to_regprocedure('public.leave_request_cancellation(uuid,uuid,integer,text,text)') IS NOT NULL,true,'HR cancellation-request API is installed');
SELECT is(to_regprocedure('public.leave_my_cancellation_history(uuid,uuid,integer,integer)') IS NOT NULL,true,'narrow own cancellation-history API is installed');
SELECT is(to_regprocedure('public.leave_decide_cancellation(uuid,uuid,integer,text,text,text)') IS NOT NULL,true,  'separate cancellation decision API is installed');
SELECT is(to_regprocedure('public.leave_cancel_approved_request(uuid,uuid,integer,text,text)') IS NOT NULL,true,  'direct HR cancellation API is installed');
SELECT ok(has_function_privilege('authenticated','public.leave_cancellation_history(uuid,uuid,integer,integer)','EXECUTE'),  'authenticated scoped cancellation history is exposed');
SELECT ok(NOT has_function_privilege('service_role','public.leave_decide_cancellation(uuid,uuid,integer,text,text,text)','EXECUTE'),  'service role cannot bypass cancellation authorization');
SELECT ok(NOT has_table_privilege('authenticated','leave.cancellation_requests','SELECT'),  'cancellation state has no direct authenticated table access');

-- Establish the effective configuration and opening balance through actual RPCs.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT set_config('test.calendar',public.leave_create_calendar('d3081000-0000-4000-8000-000000000001', 'd3083000-0000-4000-8000-000000000001','cancel-calendar','Cancellation Calendar', current_setting('test.today')::date-20,NULL,ARRAY[5,6]::smallint[],'[]'::jsonb, 'cancellation test policy','Explicit test calendar')::text,true);
SELECT set_config('test.period',public.leave_create_year_period('d3081000-0000-4000-8000-000000000001', 'd3083000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid, current_setting('test.today')::date-10,current_setting('test.today')::date+60, 'Cancellation test period','Explicit test period')::text,true);
SELECT set_config('test.old_period',public.leave_create_year_period('d3081000-0000-4000-8000-000000000001','d3083000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date-20,current_setting('test.today')::date-11,'Retained earlier balance period','Preserve carried balance provenance')::text,true);
SELECT set_config('test.type',public.leave_create_type('d3081000-0000-4000-8000-000000000001', 'd3083000-0000-4000-8000-000000000001','cancel-tracked','Cancellation tracked leave', current_setting('test.today')::date-20,'paid','tracked',true,'manual test policy', 'Tracked test policy permits half day','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.type_version',(SELECT id::text FROM leave.type_versions  WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type')::uuid AND version=1),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT set_config('test.self_opening',public.leave_post_balance('d3081000-0000-4000-8000-000000000001', 'd3084000-0000-4000-8000-000000000001','d3083000-0000-4000-8000-000000000001', current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',3.00, current_setting('test.type_version')::uuid,'cancel-self-open','HR-verified test balance','Self test opening')->>'account_id',true);
SELECT set_config('test.accountless_opening',public.leave_post_balance('d3081000-0000-4000-8000-000000000001', 'd3084000-0000-4000-8000-000000000002','d3083000-0000-4000-8000-000000000001', current_setting('test.type')::uuid,current_setting('test.period')::uuid,'opening',5.00, current_setting('test.type_version')::uuid,'cancel-accountless-open','HR-verified test balance','Accountless test opening')->>'account_id',true);
SELECT set_config('test.accountless_old_account',public.leave_post_balance('d3081000-0000-4000-8000-000000000001','d3084000-0000-4000-8000-000000000002','d3083000-0000-4000-8000-000000000001',current_setting('test.type')::uuid,current_setting('test.old_period')::uuid,'opening',0.25,current_setting('test.type_version')::uuid,'cancel-old-opening','Verified retained prior-period balance','Retained balance test opening')->>'account_id',true);
RESET ROLE;

-- Employee self-submits;
-- a distinct approver commits the leave and its debit.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000001',true);
SELECT set_config('test.self_request',public.leave_submit_own_request('d3081000-0000-4000-8000-000000000001', current_setting('test.type')::uuid,current_setting('test.today')::date+1,current_setting('test.today')::date+1, false,NULL,'Self leave for cancellation acceptance','self-cancel-request')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT set_config('test.self_approved',public.leave_approve_request('d3081000-0000-4000-8000-000000000001', current_setting('test.self_request')::uuid,1,1,'approve employee request','approve-self-for-cancel')::text,true);
SELECT set_config('test.self_approved_by',current_setting('test.self_approved')::jsonb->>'approved_by',true);
SELECT set_config('test.self_approved_at',current_setting('test.self_approved')::jsonb->>'approved_at',true);
RESET ROLE;

-- Own cancellation request does not mutate approval or refund anything;
-- only a
-- separate reviewer acceptance performs the exact reversal.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000001',true);
SELECT set_config('test.self_cancel',public.leave_my_request_cancellation('d3081000-0000-4000-8000-000000000001', current_setting('test.self_request')::uuid,2,'Employee requests cancellation','self-cancel-open')::text,true);
SELECT is((current_setting('test.self_cancel')::jsonb->>'state'),'pending','own cancellation opens a pending review');
SELECT is((current_setting('test.self_cancel')::jsonb->'request'->>'state'),'approved','request remains approved while cancellation is pending');
RESET ROLE;
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND account_id=current_setting('test.self_opening')::uuid),2.00, 'pending cancellation keeps the committed consumption and does not refund the balance early');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000001',true);
SELECT throws_ok(format($q$SELECT public.leave_my_request_cancellation('d3081000-0000-4000-8000-000000000001','%s',2,'Duplicate pending request','self-cancel-duplicate')$q$, current_setting('test.self_request')),'23514','leave_cancellation_pending','only one pending cancellation exists for an approved request');
SELECT throws_ok(format($q$SELECT public.leave_my_request_cancellation('d3081000-0000-4000-8000-000000000001','%s',2,'Cross-stream reused key','self-cancel-request')$q$, current_setting('test.self_request')),'23505','leave_idempotency_conflict','a request-event key cannot be reused for cancellation before any new effect');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT is(jsonb_array_length(public.leave_cancellation_queue('d3081000-0000-4000-8000-000000000001',50,0)->'items'),1, 'reviewer receives a separately owned cancellation queue item');
SELECT throws_ok($q$SELECT public.leave_decide_cancellation('d3081000-0000-4000-8000-000000000001',(current_setting('test.self_cancel')::jsonb->'cancellation'->>'id')::uuid,1,'accept','Previously occupied request key','approve-self-for-cancel')$q$,'23505','leave_idempotency_conflict','occupied decision key rejects safely and leaves a fresh key available');
SELECT set_config('test.self_cancel_rejected',public.leave_decide_cancellation('d3081000-0000-4000-8000-000000000001', (current_setting('test.self_cancel')::jsonb->'cancellation'->>'id')::uuid,1,'reject', 'Cancellation is not approved','self-cancel-reject')::text,true);
SELECT is((current_setting('test.self_cancel_rejected')::jsonb->>'state'),'rejected','reviewer may reject cancellation independently');
SELECT is((current_setting('test.self_cancel_rejected')::jsonb->'request'->>'state'),'approved','rejection preserves approved Leave');
SELECT set_config('test.self_cancel_replay',public.leave_decide_cancellation('d3081000-0000-4000-8000-000000000001', (current_setting('test.self_cancel')::jsonb->'cancellation'->>'id')::uuid,1,'reject', 'Cancellation is not approved','self-cancel-reject')::text,true);
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND account_id=current_setting('test.self_opening')::uuid AND entry_kind='cancellation_reversal'),0, 'rejection and same-key replay do not reverse approved consumption');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND account_id=current_setting('test.self_opening')::uuid),2.00,'rejected cancellation retains the original one-unit debit');
RESET ROLE;

-- A fresh key permits a new request after rejection;
-- acceptance closes the parent.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT set_config('test.self_cancel_second',public.leave_request_cancellation('d3081000-0000-4000-8000-000000000001', current_setting('test.self_request')::uuid,2,'Manager submits a new cancellation attempt','hr-cancel-second')::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT set_config('test.self_cancel_accepted',public.leave_decide_cancellation('d3081000-0000-4000-8000-000000000001', (current_setting('test.self_cancel_second')::jsonb->'cancellation'->>'id')::uuid,1,'accept', 'Acceptance with exact reversal','self-cancel-accept')::text,true);
SELECT is((current_setting('test.self_cancel_accepted')::jsonb->>'state'),'accepted','reviewer accepts the second cancellation request');
SELECT is((current_setting('test.self_cancel_accepted')::jsonb->'request'->>'state'),'cancelled','accepted cancellation marks parent cancelled');
SELECT is((current_setting('test.self_cancel_accepted')::jsonb->>'reversal_count')::integer,1,'acceptance reverses the single original allocation');
SELECT is((current_setting('test.self_cancel_accepted')::jsonb->>'time_reconciliation_required')::boolean,false, 'acceptance reports no Time reconciliation when no Attendance fact exists');
SELECT is((public.leave_decide_cancellation('d3081000-0000-4000-8000-000000000001', (current_setting('test.self_cancel_second')::jsonb->'cancellation'->>'id')::uuid,1,'accept', 'Acceptance with exact reversal','self-cancel-accept')->>'state'),'accepted','same-key acceptance retry replays its result');
RESET ROLE;

-- Record and approve for an Employee without a Tenant account. One requested
-- cancellation is rejected;
-- a fresh request is accepted after entitlement off.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT set_config('test.accountless_request_b',public.leave_record_hr_request('d3081000-0000-4000-8000-000000000001', 'd3084000-0000-4000-8000-000000000002','d3085000-0000-4000-8000-000000000002',current_setting('test.type')::uuid, current_setting('test.today')::date+2,current_setting('test.today')::date+2,false,NULL, 'Accountless employee Leave B','accountless-record-b')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT set_config('test.accountless_approved_b',public.leave_approve_request('d3081000-0000-4000-8000-000000000001', current_setting('test.accountless_request_b')::uuid,1,1,'approve accountless Leave B','accountless-approve-b')::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000001',true);
SELECT throws_ok($q$SELECT public.leave_my_request_cancellation('d3081000-0000-4000-8000-000000000001',current_setting('test.accountless_request_b')::uuid,2,'Wrong employee','self-cancel-other-employee')$q$,'P0002','leave_request_unavailable','mixed manage and self permissions cannot use own route for another Employee');
SELECT throws_ok($q$SELECT public.leave_my_cancellation_history('d3081000-0000-4000-8000-000000000001',current_setting('test.accountless_request_b')::uuid,50,0)$q$,'P0002','leave_request_unavailable','mixed HR permissions cannot widen own cancellation history');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT set_config('test.accountless_cancel_b1',public.leave_request_cancellation('d3081000-0000-4000-8000-000000000001', current_setting('test.accountless_request_b')::uuid,2,'HR requests cancellation of accountless Leave','accountless-cancel-b1')::text,true);
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND user_id='d3080000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT is(public.leave_request_cancellation('d3081000-0000-4000-8000-000000000001',current_setting('test.accountless_request_b')::uuid,2,'HR requests cancellation of accountless Leave','accountless-cancel-b1')->>'state','pending','idempotent replay of an existing cancellation succeeds after approver coverage closes');
SELECT throws_ok($q$SELECT public.leave_request_cancellation('d3081000-0000-4000-8000-000000000001',current_setting('test.accountless_request_b')::uuid,2,'Another HR cancellation attempt','accountless-cancel-no-approver')$q$,'23514','leave_approval_queue_unavailable','new cancellation is blocked when no active approver can own it');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND user_id='d3080000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT set_config('test.accountless_cancel_b1_rejected',public.leave_decide_cancellation('d3081000-0000-4000-8000-000000000001', (current_setting('test.accountless_cancel_b1')::jsonb->'cancellation'->>'id')::uuid,1,'reject', 'Keep the approved accountless leave','accountless-cancel-b1-reject')::text,true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT set_config('test.accountless_cancel_b2',public.leave_request_cancellation('d3081000-0000-4000-8000-000000000001', current_setting('test.accountless_request_b')::uuid,2,'Fresh HR cancellation attempt','accountless-cancel-b2')::text,true);
SELECT set_config('test.accountless_request_c',public.leave_record_hr_request('d3081000-0000-4000-8000-000000000001', 'd3084000-0000-4000-8000-000000000002','d3085000-0000-4000-8000-000000000002',current_setting('test.type')::uuid, current_setting('test.today')::date+3,current_setting('test.today')::date+3,false,NULL, 'Accountless employee Leave C','accountless-record-c')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT set_config('test.accountless_approved_c',public.leave_approve_request('d3081000-0000-4000-8000-000000000001', current_setting('test.accountless_request_c')::uuid,1,1,'approve accountless Leave C','accountless-approve-c')::text,true);
RESET ROLE;

-- Ending both entitlements blocks new work but authorized closure still performs
-- an exact accepted reversal or direct HR cancellation;
-- no Time rows are rewritten.
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND capability_key IN ('hr.people','hr.leave');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT set_config('test.accountless_cancel_b2_accepted',public.leave_decide_cancellation('d3081000-0000-4000-8000-000000000001', (current_setting('test.accountless_cancel_b2')::jsonb->'cancellation'->>'id')::uuid,1,'accept', 'Close existing approved Leave after entitlement disable','accountless-cancel-b2-accept')::text,true);
SELECT is((current_setting('test.accountless_cancel_b2_accepted')::jsonb->>'state'),'accepted', 'existing cancellation can be accepted while Leave is disabled');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT throws_ok($q$SELECT public.leave_cancel_approved_request('d3081000-0000-4000-8000-000000000001',current_setting('test.accountless_request_c')::uuid,2,'Manager cannot finalize cancellation','manage-only-direct')$q$,'42501','leave_forbidden','leave.manage may initiate cancellation but cannot directly cancel approved leave');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT set_config('test.accountless_direct_c',public.leave_cancel_approved_request('d3081000-0000-4000-8000-000000000001', current_setting('test.accountless_request_c')::uuid,2,'HR direct cancellation of accountless request',repeat('c',120))::text,true);
SELECT is(public.leave_cancel_approved_request('d3081000-0000-4000-8000-000000000001',current_setting('test.accountless_request_c')::uuid,2,'HR direct cancellation of accountless request',repeat('c',120))->>'state','cancelled','maximum-length direct cancellation key replays without a second reversal');
SELECT is((current_setting('test.accountless_direct_c')::jsonb->>'state'),'cancelled', 'authorized HR can directly cancel an approved accountless Employee request during closure');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000002',true);
SELECT throws_ok(format($q$SELECT public.leave_record_hr_request('d3081000-0000-4000-8000-000000000001', 'd3084000-0000-4000-8000-000000000002','d3085000-0000-4000-8000-000000000002','%s', current_setting('test.today')::date+4,current_setting('test.today')::date+4,false,NULL,'new work disabled','disabled-record')$q$, current_setting('test.type')),'55000','leave_new_work_disabled','disabled entitlement blocks new HR Leave records');
RESET ROLE;

-- Exact single-entry reversals, immutable original approval provenance, rejection,
-- cancellation audit, bounded read APIs, and no Attendance mutation.
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND id=current_setting('test.self_request')::uuid),'cancelled','accepted self cancellation is retained as terminal history');
SELECT is((SELECT approved_preview_version FROM leave.requests WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND id=current_setting('test.self_request')::uuid),1,'cancellation preserves approved preview provenance');
SELECT is((SELECT approved_by::text FROM leave.requests WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND id=current_setting('test.self_request')::uuid),current_setting('test.self_approved_by'),  'cancellation preserves the original approval actor');
SELECT is((SELECT approved_at FROM leave.requests WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND id=current_setting('test.self_request')::uuid),current_setting('test.self_approved_at')::timestamptz,  'cancellation preserves the original approval timestamp');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND account_id=current_setting('test.self_opening')::uuid AND entry_kind='cancellation_reversal'),1,  'accepted self cancellation appends one reversal and replay appends none');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries rev JOIN leave.request_consumptions x  ON x.tenant_id=rev.tenant_id AND x.account_id=rev.account_id AND x.ledger_entry_id=rev.reversal_of_entry_id  WHERE rev.tenant_id='d3081000-0000-4000-8000-000000000001' AND rev.entry_kind='cancellation_reversal'    AND x.request_id=current_setting('test.self_request')::uuid AND rev.delta_days=x.units),1,  'reversal references the exact original consumption and amount');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND account_id=current_setting('test.self_opening')::uuid),3.00,'exact self cancellation reversal restores the original test balance');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND account_id=current_setting('test.accountless_opening')::uuid AND entry_kind='cancellation_reversal'),2,  'accepted request and direct HR closure each reverse one accountless Leave allocation');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND account_id=current_setting('test.accountless_opening')::uuid),5.00,'accountless reversals restore only the two cancelled units');
SELECT is((SELECT count(DISTINCT account_id)::integer FROM leave.request_consumptions WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND request_id=current_setting('test.accountless_request_b')::uuid),2,'approved request allocated a retained fractional balance and a current-period balance');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND account_id=current_setting('test.accountless_old_account')::uuid),0.25,'cancellation restores the exact retained fraction to its original period');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3081000-0000-4000-8000-000000000001' AND account_id=current_setting('test.accountless_old_account')::uuid AND entry_kind='cancellation_reversal'),1,'same-key acceptance retry does not refund the retained allocation twice');
SELECT is((SELECT count(*)::integer FROM leave.cancellation_events WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND event_key='hr.accepted' AND request_id=current_setting('test.accountless_request_b')::uuid),1,  'second cancellation decision is audited once after the first attempt was rejected');
SELECT is((SELECT count(*)::integer FROM leave.cancellation_events WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND event_key='hr.direct_cancelled' AND request_id=current_setting('test.accountless_request_c')::uuid),1,  'direct HR cancellation has an attributable append-only cancellation event');
SELECT is((SELECT count(*)::integer FROM leave.cancellation_events WHERE tenant_id='d3081000-0000-4000-8000-000000000001'  AND request_id=current_setting('test.accountless_request_b')::uuid AND event_key='hr.rejected'),1,  'rejected cancellation attempt remains visible after a later attempt is opened');
SELECT is((SELECT count(*)::integer FROM time.attendance_facts f JOIN time.work_instances i  ON i.tenant_id=f.tenant_id AND i.id=f.work_instance_id WHERE i.tenant_id='d3081000-0000-4000-8000-000000000001'),0,  'Leave cancellation creates or changes no Attendance facts');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000001',true);
SELECT ok(jsonb_array_length(public.leave_my_cancellation_history('d3081000-0000-4000-8000-000000000001', current_setting('test.self_request')::uuid,50,0)->'items')>=3, 'linked employee can read their own requested, rejected, and accepted cancellation history without people.view');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3080000-0000-4000-8000-000000000003',true);
SELECT is(jsonb_array_length(public.leave_cancellation_queue('d3081000-0000-4000-8000-000000000001',50,0)->'items'),0, 'review queue is empty after all pending cancellations are resolved');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
