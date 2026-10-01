BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

-- HR recorder, approver, manager-only actor, and two Employees. All workflow
-- effects below are exercised through authenticated public RPCs.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('d3140000-0000-4000-8000-000000000001','correction-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3140000-0000-4000-8000-000000000002','correction-approver@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3140000-0000-4000-8000-000000000003','correction-manager-only@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('d3140000-0000-4000-8000-000000000004','correction-other-employee@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
 VALUES('d3141000-0000-4000-8000-000000000001','Leave correction test','d3140000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 ('d3141000-0000-4000-8000-000000000001','d3142000-0000-4000-8000-000000000001','corr.manage.approve.v1',1,ARRAY['leave.manage','leave.view','leave.approve','leave_balance.adjust'],false),
 ('d3141000-0000-4000-8000-000000000001','d3142000-0000-4000-8000-000000000002','corr.approve.v1',1,ARRAY['leave.approve','leave.view'],false),
 ('d3141000-0000-4000-8000-000000000001','d3142000-0000-4000-8000-000000000003','corr.manage.v1',1,ARRAY['leave.manage','leave.view','leave_balance.adjust'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('d3141000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000001'),
 ('d3141000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000002','d3140000-0000-4000-8000-000000000001'),
 ('d3141000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000003','d3140000-0000-4000-8000-000000000001'),
 ('d3141000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000004','d3140000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('d3141000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000001','d3142000-0000-4000-8000-000000000001'),
 ('d3141000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000002','d3142000-0000-4000-8000-000000000002'),
 ('d3141000-0000-4000-8000-000000000001','d3140000-0000-4000-8000-000000000003','d3142000-0000-4000-8000-000000000003');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default,is_active)
 VALUES('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001','Correction Employer',true,true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES
 ('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','CORR-A','Correction Employee A','d3140000-0000-4000-8000-000000000001'),
 ('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000002','CORR-B','Correction Employee B','d3140000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,employment_status,pay_basis) VALUES
 ('d3141000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.today')::date-30,'active','monthly'),
 ('d3141000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000002','d3144000-0000-4000-8000-000000000002','d3143000-0000-4000-8000-000000000001',current_setting('test.today')::date-30,'active','monthly');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('d3141000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','d3140000-0000-4000-8000-000000000001','correction test'),
 ('d3141000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','d3140000-0000-4000-8000-000000000001','correction test');

SELECT is(to_regprocedure('public.leave_correct_approved_request(uuid,uuid,integer,integer,uuid,integer,integer,text,text)') IS NOT NULL,true,'dedicated atomic correction RPC is installed');
SELECT ok(NOT has_function_privilege('anon','public.leave_correct_approved_request(uuid,uuid,integer,integer,uuid,integer,integer,text,text)','EXECUTE'),'anon cannot execute correction RPC');
SELECT ok(NOT has_function_privilege('service_role','public.leave_correct_approved_request(uuid,uuid,integer,integer,uuid,integer,integer,text,text)','EXECUTE'),'service role cannot bypass correction authority');
SELECT ok(NOT has_table_privilege('authenticated','leave.request_corrections','SELECT'),'correction links have no direct authenticated table access');
SELECT ok(NOT has_table_privilege('authenticated','leave.correction_events','SELECT'),'correction events have no direct authenticated table access');

-- Establish one long-lived calendar and nonoverlapping retained/current periods.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.calendar',public.leave_create_calendar('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001','corr-calendar','Correction Calendar',current_setting('test.today')::date-30,NULL,ARRAY[5,6]::smallint[],'[]'::jsonb,'Test calendar','Explicit correction fixture')::text,true);
SELECT set_config('test.old_period',public.leave_create_year_period('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date-30,current_setting('test.today')::date-1,'Retained period','Historical FIFO provenance')::text,true);
SELECT set_config('test.period',public.leave_create_year_period('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,current_setting('test.today')::date,current_setting('test.today')::date+90,'Current period','Current correction fixtures')::text,true);
SELECT set_config('test.type_a',public.leave_create_type('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001','corr-a','Tracked type A',current_setting('test.today')::date-30,'paid','tracked',true,'Test policy','Explicit tracked policy','calendar_days')::text,true);
SELECT set_config('test.type_b',public.leave_create_type('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001','corr-b','Tracked type B',current_setting('test.today')::date-30,'paid','tracked',true,'Test policy','Second tracked policy','calendar_days')::text,true);
SELECT set_config('test.type_c',public.leave_create_type('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001','corr-c','Tracked type C',current_setting('test.today')::date-30,'paid','tracked',true,'Test policy','No balance policy','calendar_days')::text,true);
RESET ROLE;
SELECT set_config('test.date1',(current_setting('test.today')::date + (7-extract(isodow FROM current_setting('test.today')::date)::integer)%7 + 7)::text,true);
SELECT set_config('test.date2',(current_setting('test.date1')::date+1)::text,true);
SELECT set_config('test.date3',(current_setting('test.date1')::date+2)::text,true);
SELECT set_config('test.type_a_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type_a')::uuid AND version=1),true);
SELECT set_config('test.type_b_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type_b')::uuid AND version=1),true);
SELECT set_config('test.type_c_version',(SELECT id::text FROM leave.type_versions WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND leave_type_id=current_setting('test.type_c')::uuid AND version=1),true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.old_account',public.leave_post_balance('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.old_period')::uuid,'opening',0.25,current_setting('test.type_a_version')::uuid,'corr-old-opening','Verified retained fractional balance','Correction FIFO opening')->>'account_id',true);
SELECT set_config('test.a_account',public.leave_post_balance('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.period')::uuid,'opening',4.00,current_setting('test.type_a_version')::uuid,'corr-a-opening','Verified test balance','Correction opening A')->>'account_id',true);
SELECT set_config('test.b_account',public.leave_post_balance('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.type_b')::uuid,current_setting('test.period')::uuid,'opening',2.00,current_setting('test.type_b_version')::uuid,'corr-b-opening','Verified test balance','Correction opening B')->>'account_id',true);
RESET ROLE;

-- Same-type replacement: preparation may overlap, ordinary approval may not;
-- correction atomically preserves old source and reapplies FIFO on replacement.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.old1',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date1')::date,current_setting('test.date1')::date,false,NULL,'Original approval one','corr-record-old1')->>'id',true);
SELECT set_config('test.new1',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date1')::date,current_setting('test.date1')::date,false,NULL,'Replacement approval one','corr-record-new1')->>'id',true);
SELECT set_config('test.other_employee_request',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000002','d3145000-0000-4000-8000-000000000002',current_setting('test.type_a')::uuid,current_setting('test.date1')::date,current_setting('test.date1')::date,false,NULL,'Other employee request','corr-record-other-employee')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT set_config('test.approved1',public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.old1')::uuid,1,1,'approve original','corr-approve-old1')::text,true);
SELECT throws_ok(format($q$SELECT public.leave_approve_request('d3141000-0000-4000-8000-000000000001','%s',1,1,'ordinary approval overlap','corr-ordinary-new1')$q$,current_setting('test.new1')),'23514','leave_request_overlap','ordinary approval cannot bypass the approved overlap');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000003',true);
SELECT throws_ok(format($q$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001','%s',2,1,'%s',1,1,'manager has manage only','corr-forbidden')$q$,current_setting('test.old1'),current_setting('test.new1')),'42501','leave_forbidden','leave.manage without leave.approve cannot replace an approved request');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT set_config('test.corrected1',public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.old1')::uuid,2,1,current_setting('test.new1')::uuid,1,1,'Correct date allocation to the same type','corr-correct-one')::text,true);
SELECT is(current_setting('test.corrected1')::jsonb->>'state','corrected','authorized reviewer completes atomic same-type correction');
SELECT is(public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.old1')::uuid,2,1,current_setting('test.new1')::uuid,1,1,'Correct date allocation to the same type','corr-correct-one')->>'state','corrected','same operation key and payload replays stored correction result');
SELECT throws_ok(format($q$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001','%s',2,1,'%s',1,1,'Changed payload reason','corr-correct-one')$q$,current_setting('test.old1'),current_setting('test.new1')),'23505','leave_idempotency_conflict','changed payload under same key conflicts');
SELECT throws_ok(format($q$SELECT public.leave_approve_request('d3141000-0000-4000-8000-000000000001','%s',1,1,'Reuse correction key in ordinary approval','corr-correct-one')$q$,current_setting('test.other_employee_request')),'23505','leave_idempotency_conflict','correction key cannot be reused across request approval stream');
RESET ROLE;
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id=current_setting('test.old1')::uuid),'superseded','original immutable approval remains visible as superseded');
SELECT is((SELECT approved_preview_version FROM leave.requests WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id=current_setting('test.old1')::uuid),1,'supersession preserves original approved preview');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND correction_id=(current_setting('test.corrected1')::jsonb->>'correction_id')::uuid AND entry_kind='correction_reversal'),2,'reversal is emitted for each exact FIFO source allocation');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND account_id=current_setting('test.old_account')::uuid AND correction_id=(current_setting('test.corrected1')::jsonb->>'correction_id')::uuid AND entry_kind='correction_reversal'),0.25,'fractional original allocation is reversed into the exact retained account');
SELECT is((SELECT sum(units)::numeric FROM leave.request_consumptions WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND request_id=current_setting('test.new1')::uuid AND account_id=current_setting('test.old_account')::uuid),0.25,'same-type replacement reuses restored retained funds in FIFO order');
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND account_id=current_setting('test.old_account')::uuid),0.00,'restored retained funds are consumed once by the approved replacement');
SELECT is((SELECT count(*)::integer FROM leave.correction_events WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND original_request_id=current_setting('test.old1')::uuid),1,'one immutable correction event records the paired transition');

-- Different leave type replacement: original type is reversed; new type funds it.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.old2',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date2')::date,current_setting('test.date2')::date,false,NULL,'Original type A','corr-record-old2')->>'id',true);
SELECT set_config('test.new2',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_b')::uuid,current_setting('test.date2')::date,current_setting('test.date2')::date,false,NULL,'Replacement type B','corr-record-new2')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT set_config('test.approved2',public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.old2')::uuid,1,1,'approve type A','corr-approve-old2')::text,true);
SELECT set_config('test.corrected2',public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.old2')::uuid,2,1,current_setting('test.new2')::uuid,1,1,'Replace with correct leave type','corr-correct-two')::text,true);
SELECT is(current_setting('test.corrected2')::jsonb->'replacement'->>'leave_type_id',current_setting('test.type_b'),'correction supports a separately submitted replacement type');
RESET ROLE;
SELECT is((SELECT sum(delta_days)::numeric FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND account_id=current_setting('test.b_account')::uuid),1.00,'replacement allocates against the distinct target type balance');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND correction_id=(current_setting('test.corrected2')::jsonb->>'correction_id')::uuid AND leave_type_id=current_setting('test.type_a')::uuid AND entry_kind='correction_reversal'),1,'different-type correction reverses only the original type source');

-- Insufficient replacement balance rolls back original supersession, reversal,
-- link, and event. The old approval remains fully effective.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.old3',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date3')::date,current_setting('test.date3')::date,false,NULL,'Original with funded type','corr-record-old3')->>'id',true);
SELECT set_config('test.new3',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_c')::uuid,current_setting('test.date3')::date,current_setting('test.date3')::date,false,NULL,'Replacement without balance','corr-record-new3')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT set_config('test.approved3',public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.old3')::uuid,1,1,'approve original funded request','corr-approve-old3')::text,true);
SELECT throws_ok(format($q$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001','%s',99,1,'%s',1,1,'Wrong expected version','corr-cas')$q$,current_setting('test.old3'),current_setting('test.new3')),'PT409','leave_request_version_conflict','both sides require current compare-and-set versions');
SELECT throws_ok(format($q$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001','%s',2,1,'%s',1,1,'Insufficient target type balance','corr-shortage')$q$,current_setting('test.old3'),current_setting('test.new3')),'23514','leave_balance_insufficient','replacement shortage aborts the full correction');
RESET ROLE;
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id=current_setting('test.old3')::uuid),'approved','failed correction leaves original approval active');
SELECT is((SELECT count(*)::integer FROM leave.request_corrections WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND original_request_id=current_setting('test.old3')::uuid),0,'failed correction leaves no correction link');
SELECT is((SELECT count(*)::integer FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND entry_kind='correction_reversal' AND reversal_of_entry_id IN (SELECT c.ledger_entry_id FROM leave.request_consumptions c WHERE c.tenant_id='d3141000-0000-4000-8000-000000000001' AND c.request_id=current_setting('test.old3')::uuid)),0,'failed correction leaves no partial ledger reversals');

-- Read projection carries the exact lineage and never marks itself consumed.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT set_config('test.facts',public.leave_payroll_facts('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.date1')::date,current_setting('test.date2')::date,NULL,NULL,100)::text,true);
SELECT ok((SELECT bool_and((x->>'projection_only')::boolean AND NOT (x->>'consumed_by_payroll')::boolean)
  FROM jsonb_array_elements(current_setting('test.facts')::jsonb->'items') x),'correction payroll source rows are read-only projections');
SELECT ok((SELECT bool_or(x->>'request_id'=current_setting('test.old1') AND x->>'request_state'='superseded'
  AND (x->>'effective_units')::numeric=0 AND x->>'correction_id'=(current_setting('test.corrected1')::jsonb->>'correction_id')
  AND x->>'linked_request_id'=current_setting('test.new1'))
  FROM jsonb_array_elements(current_setting('test.facts')::jsonb->'items') x),'superseded original remains linked with zero effective units');
SELECT ok((SELECT bool_or(x->>'request_id'=current_setting('test.new1') AND x->>'request_state'='approved'
  AND (x->>'effective_units')::numeric=1 AND x->>'source_key' LIKE current_setting('test.new1')||':%')
  FROM jsonb_array_elements(current_setting('test.facts')::jsonb->'items') x),'replacement appears as a separate approved source identity');
RESET ROLE;


-- Focused current-HEAD compatibility, audit, chains, closure and rollback tests.
SELECT is((SELECT count(*)::integer FROM leave.request_events WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND request_id=current_setting('test.new1')::uuid AND event_key='hr.approved'),1,'replacement keeps exactly one normal approval audit event after replay');
SELECT ok((current_setting('test.corrected1')::jsonb->'replacement') ? 'half_day_part','full-day detail preserves header mapping field');
SELECT ok((current_setting('test.corrected1')::jsonb->'replacement'->'days'->0) ?& ARRAY['half_day_part','halfday_mapping_state','halfday_mapping_snapshot','halfday_policy_template_id','halfday_policy_version','halfday_algorithm_version'],'full-day detail preserves all null mapping evidence fields');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.untracked',public.leave_create_type('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001','corr-untracked','Untracked correction fixture',current_setting('test.today')::date-30,'paid','untracked',true,'Explicit test policy','No balance accounting','calendar_days')::text,true);
SELECT set_config('test.chain',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date1')::date+0,current_setting('test.date1')::date+0,false,NULL,'Fixture chain','record-chain')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT set_config('test.chain_result',(public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.new1')::uuid,2,1,current_setting('test.chain')::uuid,1,1,'Correction fixture corr-chain','corr-chain'))::text,true);
SELECT set_config('test.chain_facts',public.leave_payroll_facts('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.date1')::date,current_setting('test.date1')::date,NULL,NULL,100)::text,true);
SELECT ok((SELECT bool_or(x->>'request_id'=current_setting('test.new1') AND x->>'request_state'='superseded' AND x->>'replacement_request_id'=current_setting('test.chain') AND x->'incoming_correction_links'->0->>'original_request_id'=current_setting('test.old1') AND (x->>'effective_units')::numeric=0) FROM jsonb_array_elements(current_setting('test.chain_facts')::jsonb->'items') x),'chain middle source has current outbound replacement and retained inbound lineage');
SELECT is(public.leave_payroll_facts('d3141000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001',current_setting('test.date1')::date,current_setting('test.date1')::date,NULL,NULL,100),current_setting('test.chain_facts')::jsonb,'chain lineage and source hashes repeat deterministically');
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.old1')::uuid,2,1,current_setting('test.chain')::uuid,1,1,'Correction fixture corr-terminal','corr-terminal')$test$,'PT409','leave_request_version_conflict','superseded original cannot be corrected again');
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.chain')::uuid,2,1,current_setting('test.new1')::uuid,1,1,'Correction fixture corr-terminal-new','corr-terminal-new')$test$,'PT409','leave_request_version_conflict','approved or historical replacement cannot be reused as submitted replacement');
SELECT throws_ok($test$SELECT public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.other_employee_request')::uuid,1,1,'Try reserved audit key','leave-internal:correction-approval:fake')$test$,'23505','leave_idempotency_conflict','caller cannot claim reserved approval audit namespace');
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.chain')::uuid,2,1,current_setting('test.new3')::uuid,1,1,'Correction fixture leave-internal:fake','leave-internal:fake')$test$,'23505','leave_idempotency_conflict','correction caller cannot claim internal namespace');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.pending_old',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.untracked')::uuid,current_setting('test.date1')::date+10,current_setting('test.date1')::date+10,false,NULL,'Fixture pending_old','record-pending_old')->>'id',true);
SELECT set_config('test.pending_new',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.untracked')::uuid,current_setting('test.date1')::date+10,current_setting('test.date1')::date+10,false,NULL,'Fixture pending_new','record-pending_new')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.pending_old')::uuid,1,1,'Approve fixture pending_old','approve-pending_old');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT public.leave_request_cancellation('d3141000-0000-4000-8000-000000000001',current_setting('test.pending_old')::uuid,2,'Cancellation awaiting decision','corr-pending-cancel');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.pending_old')::uuid,2,1,current_setting('test.pending_new')::uuid,1,1,'Correction fixture corr-pending','corr-pending')$test$,'23514','leave_cancellation_pending','pending cancellation must be resolved before correction');
RESET ROLE;
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id=current_setting('test.pending_old')::uuid),'approved','pending conflict preserves original approval');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.audit_old',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date1')::date+11,current_setting('test.date1')::date+11,false,NULL,'Fixture audit_old','record-audit_old')->>'id',true);
SELECT set_config('test.audit_new',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.type_a')::uuid,current_setting('test.date1')::date+11,current_setting('test.date1')::date+11,false,NULL,'Fixture audit_new','record-audit_new')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.audit_old')::uuid,1,1,'Approve fixture audit_old','approve-audit_old');
RESET ROLE;
SELECT set_config('test.ledger_before',(SELECT count(*)::text FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001'),true);
CREATE FUNCTION pg_temp.fail_correction_approval_event() RETURNS trigger LANGUAGE plpgsql AS $f$ BEGIN IF NEW.event_key='hr.approved' AND NEW.operation_key LIKE 'leave-internal:%' THEN RAISE EXCEPTION 'test_audit_failure' USING ERRCODE='P0001'; END IF; RETURN NEW; END $f$;
CREATE TRIGGER test_fail_correction_audit BEFORE INSERT ON leave.request_events FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_correction_approval_event();
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.audit_old')::uuid,2,1,current_setting('test.audit_new')::uuid,1,1,'Correction fixture corr-audit-rollback','corr-audit-rollback')$test$,'P0001','test_audit_failure','failed normal approval audit aborts the entire correction');
RESET ROLE;
DROP TRIGGER test_fail_correction_audit ON leave.request_events;
SELECT is((SELECT count(*)::text FROM leave.ledger_entries WHERE tenant_id='d3141000-0000-4000-8000-000000000001'),current_setting('test.ledger_before'),'audit failure rolls back reversals and replacement consumption');
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id=current_setting('test.audit_old')::uuid),'approved','audit failure rolls back supersession');
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id=current_setting('test.audit_new')::uuid),'submitted','audit failure rolls back replacement approval');
SELECT is((SELECT count(*)::integer FROM leave.request_corrections WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND original_request_id=current_setting('test.audit_old')::uuid),0,'audit failure rolls back correction relation');
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND user_id='d3140000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.audit_old')::uuid,2,1,current_setting('test.audit_new')::uuid,1,1,'Correction fixture corr-inactive','corr-inactive')$test$,'42501','leave_forbidden','inactive approver cannot correct or discover request state');
RESET ROLE;
UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND user_id='d3140000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000099',current_setting('test.audit_old')::uuid,2,1,current_setting('test.audit_new')::uuid,1,1,'Correction fixture corr-wrong-tenant','corr-wrong-tenant')$test$,'42501','leave_forbidden','wrong tenant is denied before request lookup');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.half_old',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.untracked')::uuid,current_setting('test.date1')::date+12,current_setting('test.date1')::date+12,false,NULL,'Fixture half_old','record-half_old')->>'id',true);
SELECT set_config('test.half_new',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.untracked')::uuid,current_setting('test.date1')::date+12,current_setting('test.date1')::date+12,true,'first','Fixture half_new','record-half_new')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.half_old')::uuid,1,1,'Approve fixture half_old','approve-half_old');
RESET ROLE;
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES('d3141000-0000-4000-8000-000000000001','hr.attendance',true,now()-interval '1 minute','d3140000-0000-4000-8000-000000000001','halfday correction test');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES('d3141000-0000-4000-8000-000000000001','d3148000-0000-4000-8000-000000000001','d3143000-0000-4000-8000-000000000001','Correction site',true,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES('d3141000-0000-4000-8000-000000000001','d3147000-0000-4000-8000-000000000001','CORR-FIXED',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,required_minutes,earliest_punch,latest_punch,attribution_before_minutes,attribution_after_minutes,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes,auto_approve_clean,fixed_break_start,fixed_break_end,flexible_halfday_break_minutes) VALUES('d3141000-0000-4000-8000-000000000001','d3147000-0000-4000-8000-000000000001',1,'Correction fixed mapping','fixed','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],'09:00','17:00',false,60,NULL,NULL,NULL,120,360,'d3140000-0000-4000-8000-000000000001',false,15,15,false,'13:00','14:00',NULL);
INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from,valid_until) VALUES('d3141000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001','d3148000-0000-4000-8000-000000000001','d3147000-0000-4000-8000-000000000001',1,current_setting('test.today')::date,NULL);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT is((public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.half_old')::uuid,2,1,current_setting('test.half_new')::uuid,1,1,'Correction fixture corr-half-refresh','corr-half-refresh'))->>'state','refresh_required','changed Attendance policy requires explicit preview refresh');
SELECT public.leave_hr_refresh_halfday_preview('d3141000-0000-4000-8000-000000000001',current_setting('test.half_new')::uuid,1,'second','Review mapped second portion','corr-half-map');
SELECT set_config('test.half_corrected',(public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.half_old')::uuid,2,1,current_setting('test.half_new')::uuid,2,2,'Correction fixture corr-half-mapped','corr-half-mapped'))::text,true);
SELECT is(current_setting('test.half_corrected')::jsonb->>'state','corrected','reviewed mapped half-day replacement can be approved');
SELECT is(current_setting('test.half_corrected')::jsonb->'replacement'->>'half_day_part','first','replacement header retains original submitted part');
SELECT is(current_setting('test.half_corrected')::jsonb->'replacement'->'days'->0->>'half_day_part','second','replacement day retains reviewed effective part');
SELECT is(current_setting('test.half_corrected')::jsonb->'replacement'->'days'->0->>'halfday_mapping_state','mapped','replacement detail retains mapped evidence');
RESET ROLE;

-- Reserve only new caller keys; retain legitimate events stored before this migration.
INSERT INTO leave.request_events(tenant_id,request_id,actor_user_id,event_key,from_state,to_state,from_version,to_version,reason,operation_key,payload_hash,result)
SELECT tenant_id,request_id,actor_user_id,event_key,from_state,to_state,from_version,to_version,reason,'leave-internal:legacy-record',payload_hash,result
FROM leave.request_events WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND operation_key='corr-record-other-employee';
INSERT INTO leave.cancellation_events(tenant_id,cancellation_id,request_id,actor_user_id,event_key,from_state,to_state,from_version,to_version,reason,operation_key,payload_hash,result,time_reconciliation_required,time_fact_refs)
SELECT tenant_id,cancellation_id,request_id,actor_user_id,event_key,from_state,to_state,from_version,to_version,reason,'leave-internal:legacy-cancel',payload_hash,result,time_reconciliation_required,time_fact_refs
FROM leave.cancellation_events WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND operation_key='corr-pending-cancel';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT is(public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000002','d3145000-0000-4000-8000-000000000002',current_setting('test.type_a')::uuid,current_setting('test.date1')::date,current_setting('test.date1')::date,false,NULL,'Other employee request','leave-internal:legacy-record')->>'id',current_setting('test.other_employee_request'),'legitimate preexisting reserved-prefix request key remains replayable');
SELECT is(public.leave_request_cancellation('d3141000-0000-4000-8000-000000000001',current_setting('test.pending_old')::uuid,2,'Cancellation awaiting decision','leave-internal:legacy-cancel')->>'state','pending','legitimate preexisting reserved-prefix cancellation key remains replayable');
SELECT throws_ok($test$SELECT public.leave_request_cancellation('d3141000-0000-4000-8000-000000000001',current_setting('test.pending_old')::uuid,2,'New reserved cancellation key','leave-internal:new-cancel')$test$,'23505','leave_idempotency_conflict','new cancellation cannot claim reserved internal namespace');
RESET ROLE;

-- Current Employment state remains a gate even when its dates still cover both requests.
UPDATE people.employments SET employment_status='ended',end_date=current_setting('test.today')::date+90 WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id='d3145000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.audit_old')::uuid,2,1,current_setting('test.audit_new')::uuid,1,1,'Ended employment correction','corr-ended')$test$,'23514','leave_employment_range_unavailable','ended Employment blocks new replacement approval');
RESET ROLE;
UPDATE people.employments SET employment_status='active',end_date=NULL WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id='d3145000-0000-4000-8000-000000000001';
-- Seed an explicit legacy Time fact AFTER approval to exercise original-side reconciliation.
-- These private fixture inserts model retained facts; Leave must only return their exact IDs/versions.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000001',true);
SELECT set_config('test.time_old',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.untracked')::uuid,current_setting('test.date1')::date+13,current_setting('test.date1')::date+13,false,NULL,'Original legacy Time fixture','record-time-old')->>'id',true);
SELECT set_config('test.time_new',public.leave_record_hr_request('d3141000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001','d3145000-0000-4000-8000-000000000001',current_setting('test.untracked')::uuid,current_setting('test.date1')::date+14,current_setting('test.date1')::date+14,false,NULL,'Replacement legacy Time fixture','record-time-new')->>'id',true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT public.leave_approve_request('d3141000-0000-4000-8000-000000000001',current_setting('test.time_old')::uuid,1,1,'Approve before legacy Time fixture','approve-time-old');
RESET ROLE;
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,schedule_kind,break_minutes,created_by)
SELECT 'd3141000-0000-4000-8000-000000000001','d3149000-0000-4000-8000-000000000001',a.id,'d3145000-0000-4000-8000-000000000001','d3144000-0000-4000-8000-000000000001',a.site_id,current_setting('test.date1')::date+13,a.work_policy_template_id,a.work_policy_version,'Africa/Cairo','fixed',60,'d3140000-0000-4000-8000-000000000001'
FROM people.work_assignments a WHERE a.tenant_id='d3141000-0000-4000-8000-000000000001' AND a.employment_id='d3145000-0000-4000-8000-000000000001' AND a.valid_until IS NULL;
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by)
VALUES('d3141000-0000-4000-8000-000000000001','d3149100-0000-4000-8000-000000000001','d3149000-0000-4000-8000-000000000001',1,'ready','legacy-time-fixture','d3140000-0000-4000-8000-000000000001');
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
VALUES('d3141000-0000-4000-8000-000000000001','d3149200-0000-4000-8000-000000000001','d3149000-0000-4000-8000-000000000001',1,'d3149100-0000-4000-8000-000000000001','{"outcome":"absence"}'::jsonb,'d3140000-0000-4000-8000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT throws_ok($test$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001',current_setting('test.time_old')::uuid,2,1,current_setting('test.time_new')::uuid,1,1,'Legacy Time reconciliation required','corr-time-old')$test$,'23514','leave_attendance_fact_conflict','current legacy fact on original-only date blocks supersession');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM time.attendance_facts WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND work_instance_id='d3149000-0000-4000-8000-000000000001'),1,'correction never rewrites or deletes legacy Time fact');
SELECT is((SELECT state FROM leave.requests WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND id=current_setting('test.time_old')::uuid),'approved','Time conflict retains old approved source');

-- Current authorized approval cannot correct an unrelated employee request and
-- manager-only recording authority is not enough. Disabled service blocks new work.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','d3140000-0000-4000-8000-000000000002',true);
SELECT throws_ok(format($q$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001','%s',2,1,'%s',1,1,'Wrong employee replacement','corr-other-employee')$q$,current_setting('test.old1'),current_setting('test.other_employee_request')),'P0002','leave_request_unavailable','cross-employee replacement fails closed');
RESET ROLE;
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now()
 WHERE tenant_id='d3141000-0000-4000-8000-000000000001' AND capability_key IN ('hr.people','hr.leave');
SELECT throws_ok(format($q$SELECT public.leave_correct_approved_request('d3141000-0000-4000-8000-000000000001','%s',2,1,'%s',1,1,'Disabled work should fail','corr-disabled')$q$,current_setting('test.old3'),current_setting('test.new3')),'55000','leave_new_work_disabled','correction cannot grow new Leave work after capability closure');

SELECT * FROM finish();
ROLLBACK;
