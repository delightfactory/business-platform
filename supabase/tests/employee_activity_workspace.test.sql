BEGIN;
DO $$ BEGIN
  IF current_database() NOT IN('business_platform_cube4_adam_positive_qa','postgres')
    OR current_setting('test.employee_activity_qa',true) IS DISTINCT FROM 'local-synthetic-only' THEN
    RAISE EXCEPTION 'dedicated local synthetic QA database required';
  END IF;
END $$;
SELECT no_plan();

-- NONLEGAL rollback-only read-boundary fixtures. These literal financial rows
-- test history isolation, not payroll calculation, issuance or financial UAT.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
SELECT ('ea160000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'employee-history-'||n||'@example.test','x',now(),'{}','{}','authenticated','authenticated',now(),now()
FROM generate_series(1,3)n;
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES('ea161000-0000-4000-8000-000000000001','NONLEGAL employee history A','ea160000-0000-4000-8000-000000000001'),
('ea161000-0000-4000-8000-000000000002','NONLEGAL employee history B','ea160000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES('ea161000-0000-4000-8000-000000000001','ea162000-0000-4000-8000-000000000001','history.all',1,
ARRAY['people.view','attendance.view','leave.view','payroll.view','employee_finance.view']),
('ea161000-0000-4000-8000-000000000001','ea162000-0000-4000-8000-000000000002','history.people_only',1,ARRAY['people.view']),
('ea161000-0000-4000-8000-000000000001','ea162000-0000-4000-8000-000000000003','history.attendance_only',1,ARRAY['attendance.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
SELECT 'ea161000-0000-4000-8000-000000000001',id,'ea160000-0000-4000-8000-000000000001'
FROM auth.users WHERE id IN('ea160000-0000-4000-8000-000000000001','ea160000-0000-4000-8000-000000000002','ea160000-0000-4000-8000-000000000003');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
SELECT 'ea161000-0000-4000-8000-000000000001',
('ea160000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('ea162000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
FROM generate_series(1,3)n;
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','NONLEGAL A Employer',true),
('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000002','NONLEGAL old Employer',false),
('ea161000-0000-4000-8000-000000000002','ea163000-0000-4000-8000-000000000003','NONLEGAL foreign Employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default)
VALUES('ea161000-0000-4000-8000-000000000001','ea164000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','NONLEGAL site',true),
('ea161000-0000-4000-8000-000000000001','ea164000-0000-4000-8000-000000000002','ea163000-0000-4000-8000-000000000002','NONLEGAL old site',false);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES('ea161000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','ea160000-0000-4000-8000-000000000001','NONLEGAL rollback fixture');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','HISTORY-1','NONLEGAL selected employee','ea160000-0000-4000-8000-000000000001'),
('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000002','HISTORY-2','NONLEGAL other employee','ea160000-0000-4000-8000-000000000001'),
('ea161000-0000-4000-8000-000000000002','ea165000-0000-4000-8000-000000000003','HISTORY-1','NONLEGAL foreign employee','ea160000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,end_date,employment_status,pay_basis)
VALUES('ea161000-0000-4000-8000-000000000001','ea166000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','2026-01-01',NULL,'active','monthly'),
('ea161000-0000-4000-8000-000000000001','ea166000-0000-4000-8000-000000000002','ea165000-0000-4000-8000-000000000002','ea163000-0000-4000-8000-000000000001','2026-01-01',NULL,'active','monthly'),
('ea161000-0000-4000-8000-000000000001','ea166000-0000-4000-8000-000000000003','ea165000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000002','2025-01-01','2025-12-31','ended','monthly');
INSERT INTO time.work_policy_templates(tenant_id,id,code,head_version)
VALUES('ea161000-0000-4000-8000-000000000001','ea167000-0000-4000-8000-000000000001','HISTORY',1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,created_by)
VALUES('ea161000-0000-4000-8000-000000000001','ea167000-0000-4000-8000-000000000001',1,'NONLEGAL history','fixed','UTC',ARRAY[1]::smallint[],'08:00','16:00','ea160000-0000-4000-8000-000000000001');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,work_policy_template_id,work_policy_version,valid_from,valid_until)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea168000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea166000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
CASE WHEN n=3 THEN 'ea164000-0000-4000-8000-000000000002'::uuid ELSE 'ea164000-0000-4000-8000-000000000001'::uuid END,
'ea167000-0000-4000-8000-000000000001',1,CASE WHEN n=3 THEN '2025-01-01'::date ELSE '2026-01-01'::date END,
CASE WHEN n=3 THEN '2026-01-01'::date END FROM generate_series(1,3)n;
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,created_by)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea169000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea168000-0000-4000-8000-'||lpad(CASE WHEN n<=2 THEN '1' WHEN n=3 THEN '3' ELSE '2' END,12,'0'))::uuid,
('ea166000-0000-4000-8000-'||lpad(CASE WHEN n<=2 THEN '1' WHEN n=3 THEN '3' ELSE '2' END,12,'0'))::uuid,
CASE WHEN n=4 THEN 'ea165000-0000-4000-8000-000000000002'::uuid ELSE 'ea165000-0000-4000-8000-000000000001'::uuid END,
CASE WHEN n=3 THEN 'ea164000-0000-4000-8000-000000000002'::uuid ELSE 'ea164000-0000-4000-8000-000000000001'::uuid END,
CASE WHEN n=3 THEN '2025-12-01'::date WHEN n=2 THEN '2026-01-06'::date ELSE '2026-01-05'::date END,
'ea167000-0000-4000-8000-000000000001',1,'UTC','ea160000-0000-4000-8000-000000000001'
FROM generate_series(1,4)n;
INSERT INTO leave.types(tenant_id,id,employer_entity_id,code,name)
VALUES('ea161000-0000-4000-8000-000000000001','ea16a000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','history','NONLEGAL leave');
INSERT INTO leave.requests(tenant_id,id,employee_id,employment_id,employer_entity_id,leave_type_id,start_date,end_date,request_source,created_by,submitted_by,reason)
VALUES('ea161000-0000-4000-8000-000000000001','ea16b000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','ea166000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','ea16a000-0000-4000-8000-000000000001','2026-01-06','2026-01-07','hr','ea160000-0000-4000-8000-000000000001','ea160000-0000-4000-8000-000000000001','NONLEGAL read fixture');
INSERT INTO leave.request_previews(tenant_id,request_id,preview_version,total_units,created_by)
VALUES('ea161000-0000-4000-8000-000000000001','ea16b000-0000-4000-8000-000000000001',1,2,'ea160000-0000-4000-8000-000000000001');

INSERT INTO payroll.calendar_heads(tenant_id,employer_id,revision)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea163000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,1 FROM generate_series(1,2)n;
INSERT INTO payroll.calendar_versions(tenant_id,employer_id,id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea163000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea16c000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,1,'2025-01-01',NULL,31,'ending','UTC','ea160000-0000-4000-8000-000000000001','NONLEGAL history fixture'
FROM generate_series(1,2)n;
INSERT INTO payroll.periods(tenant_id,employer_id,id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea163000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea16d000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('ea16c000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
CASE WHEN n=1 THEN '2026-01-01'::date ELSE '2025-12-01'::date END,
CASE WHEN n=1 THEN '2026-01-31'::date ELSE '2025-12-31'::date END,
CASE WHEN n=1 THEN '2026-01-31'::date ELSE '2025-12-31'::date END,
'UTC','NONLEGAL history period',false,'ea160000-0000-4000-8000-000000000001' FROM generate_series(1,2)n;
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea163000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea16d000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('ea16e000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
'locked','ea160000-0000-4000-8000-000000000001' FROM generate_series(1,2)n;
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea163000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea16e000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('ea16f000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
1,'NONLEGAL-READ-FIXTURE','{}','{}','ea160000-0000-4000-8000-000000000001' FROM generate_series(1,2)n;
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea170000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea163000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('ea16e000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea16f000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'approve',0,'ea160000-0000-4000-8000-000000000001','NONLEGAL read fixture' FROM generate_series(1,2)n;
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
SELECT 'ea161000-0000-4000-8000-000000000001',('ea171000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea163000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('ea16d000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea16e000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('ea16f000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
('ea170000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'{}','{}','{}','{}','NONLEGAL-READ-FIXTURE','ea160000-0000-4000-8000-000000000001' FROM generate_series(1,2)n;
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net)
VALUES('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','ea171000-0000-4000-8000-000000000001','ea166000-0000-4000-8000-000000000001','{}','{}','{}',100),
('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','ea171000-0000-4000-8000-000000000001','ea166000-0000-4000-8000-000000000002','{}','{}','{}',900),
('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000002','ea171000-0000-4000-8000-000000000002','ea166000-0000-4000-8000-000000000003','{}','{}','{}',40);
INSERT INTO payroll.advance_heads(tenant_id,employer_id,id,employment_id,revision,status,version_id)
VALUES('ea161000-0000-4000-8000-000000000001','ea163000-0000-4000-8000-000000000001','ea172000-0000-4000-8000-000000000001','ea166000-0000-4000-8000-000000000001',1,'draft','ea173000-0000-4000-8000-000000000001');
INSERT INTO payroll.advance_versions(tenant_id,advance_id,id,revision,principal,effective_on,first_period,installment_count,installment_amount,reason,created_by)
VALUES('ea161000-0000-4000-8000-000000000001','ea172000-0000-4000-8000-000000000001','ea173000-0000-4000-8000-000000000001',1,500,'2026-01-01','ea16d000-0000-4000-8000-000000000001',1,500,'NONLEGAL read fixture','ea160000-0000-4000-8000-000000000001');

-- Read-only auth tests deliberately run with attendance/leave/payroll/finance
-- entitlements absent: existing historical read guards remain authoritative.
SELECT ok(NOT has_function_privilege('anon','public.people_employee_activity(uuid,uuid,text,uuid,integer)','EXECUTE'),'anonymous execute revoked');
SELECT ok(NOT has_function_privilege('service_role','public.people_employee_activity(uuid,uuid,text,uuid,integer)','EXECUTE'),'service-role execute revoked');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000001',true);
SELECT set_config('history.page',public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance',NULL,1)::text,true);
SELECT is(current_setting('history.page')::jsonb->'items'->0->>'id','ea169000-0000-4000-8000-000000000002','newest operational date appears first');
SELECT is(current_setting('history.page')::jsonb->>'has_more','true','lookahead detects further employee rows');
SELECT is(current_setting('history.page')::jsonb->>'next_after','ea169000-0000-4000-8000-000000000002','cursor is last visible row');
SELECT is(jsonb_array_length(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance','ea169000-0000-4000-8000-000000000002',30)->'items'),2,'next page includes old employment without repeating cursor');
SELECT is(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance','ea169000-0000-4000-8000-000000000001',30)->'items'->0->>'employer_id','ea163000-0000-4000-8000-000000000002','historical record preserves its employer');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance','ea169000-0000-4000-8000-000000000004')$$,'42501','employee_activity_cursor_forbidden','another employee cursor denied');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','leave','ea169000-0000-4000-8000-000000000002')$$,'42501','employee_activity_cursor_forbidden','cursor cannot cross sections');
SELECT is(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','leave')->'items'->0->>'total_units','2.00','exact selected employee leave summary');
SELECT is(jsonb_array_length(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000002','leave')->'items'),0,'authorized empty history is empty');
SELECT lives_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','payroll')$$,'authorized final history read works without exposing drafts');
SELECT lives_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','advances')$$,'authorized advances history read works');
SELECT is(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','payroll')->'items'->0->>'net','100.00','payroll net contains only selected employee, not colleagues');
SELECT is(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','payroll','ea171000-0000-4000-8000-000000000001')->'items'->0->>'net','40.00','prior employment financial history retained');
SELECT is(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','advances')->'items'->0->>'principal','500.00','advance summary comes from exact employee advance');
SELECT is(jsonb_array_length(public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000002','advances')->'items'),0,'another employee cannot inherit matching advance');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000002','ea165000-0000-4000-8000-000000000003','attendance')$$,'42501','employee_activity_forbidden','foreign tenant denied');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000003','attendance')$$,'42501','employee_activity_forbidden','foreign employee id inside own tenant denied');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','all')$$,'22023','employee_activity_invalid','no omnibus unbounded mode');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance',NULL,31)$$,'22023','employee_activity_invalid','page capped at thirty');
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance')$$,'42501','attendance_view_forbidden','People reader has no attendance grant');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','leave')$$,'42501','leave_forbidden','People reader has no leave grant');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','payroll')$$,'42501','payroll_forbidden','People reader has no payroll grant');
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','advances')$$,'42501','finance_forbidden','People reader has no finance grant');
SELECT set_config('request.jwt.claim.sub','ea160000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance')$$,'42501','employee_activity_forbidden','module permission does not grant employee profile access');
SELECT set_config('request.jwt.claim.sub','',true);
SELECT throws_ok($$SELECT public.people_employee_activity('ea161000-0000-4000-8000-000000000001','ea165000-0000-4000-8000-000000000001','attendance')$$,'42501','employee_activity_forbidden','missing identity denied');
RESET ROLE;
SELECT ok(EXISTS(SELECT 1 FROM payroll.audit_events WHERE tenant_id='ea161000-0000-4000-8000-000000000001'
AND action='employee_final_history_access' AND details->>'employee'='ea165000-0000-4000-8000-000000000001'),'final financial reads audited');
SELECT * FROM finish();
ROLLBACK;
