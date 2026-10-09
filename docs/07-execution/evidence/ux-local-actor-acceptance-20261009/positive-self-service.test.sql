-- Current-schema actual caller acceptance. Synthetic fixtures, no login credential.
-- This tests PostgreSQL authorization with supplied claims, not Auth sessions.
BEGIN;
DO $$ BEGIN IF current_database()<>'business_platform_ux_c93f09f_qa' THEN RAISE EXCEPTION 'wrong_database'; END IF; END $$;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('f9100000-0000-4000-8000-000000000001','ux-self@example.test','',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('f9110000-0000-4000-8000-000000000001','UX Synthetic A','f9100000-0000-4000-8000-000000000001'),
('f9110000-0000-4000-8000-000000000002','UX Synthetic B','f9100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('f9110000-0000-4000-8000-000000000001','f9120000-0000-4000-8000-000000000001','ux.self.testing.v1',1,
ARRAY['people.self.view','leave.self.view','leave.self.request','attendance.self.capture'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
VALUES ('f9110000-0000-4000-8000-000000000001','f9100000-0000-4000-8000-000000000001','active','f9100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('f9110000-0000-4000-8000-000000000001','f9100000-0000-4000-8000-000000000001','f9120000-0000-4000-8000-000000000001');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
VALUES ('f9110000-0000-4000-8000-000000000001','f9130000-0000-4000-8000-000000000001','UX-SELF','موظف اصطناعي','f9100000-0000-4000-8000-000000000001');
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
VALUES ('f9110000-0000-4000-8000-000000000001','f9130000-0000-4000-8000-000000000001','f9100000-0000-4000-8000-000000000001','f9100000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='f9100000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claims='{}';
DO $$ DECLARE value jsonb; BEGIN
value:=public.tenant_my_employee_snapshot('f9110000-0000-4000-8000-000000000001');
IF value->>'employee_code' IS DISTINCT FROM 'UX-SELF' OR value ?| ARRAY['salary','compensation','phone','email','legal_id','internal_notes'] THEN RAISE EXCEPTION 'profile_scope_or_privacy'; END IF;
RAISE NOTICE 'PASS active/profile';
value:=public.leave_access_snapshot('f9110000-0000-4000-8000-000000000001');
IF value->>'self_access' IS DISTINCT FROM 'true' OR value->>'self_can_request' IS DISTINCT FROM 'true' OR value->>'can_view' IS DISTINCT FROM 'false' OR value->'employers' IS DISTINCT FROM '[]'::jsonb THEN RAISE EXCEPTION 'self_permission_promoted_to_hr'; END IF;
RAISE NOTICE 'PASS active/leave-access';
value:=public.leave_my_balances('f9110000-0000-4000-8000-000000000001',50,0);
IF value->'items' IS DISTINCT FROM '[]'::jsonb OR value->>'has_more' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'empty_balances'; END IF;
RAISE NOTICE 'PASS active/leave-balances';
value:=public.leave_my_requests('f9110000-0000-4000-8000-000000000001',50,0);
IF value->'items' IS DISTINCT FROM '[]'::jsonb OR value->>'has_more' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'empty_requests'; END IF;
RAISE NOTICE 'PASS active/leave-requests';
value:=public.attendance_mobile_snapshot('f9110000-0000-4000-8000-000000000001');
IF value->>'available' IS DISTINCT FROM 'false' OR value->>'reason' IS DISTINCT FROM 'assignment' OR value ? 'capture_context' THEN RAISE EXCEPTION 'missing_assignment_contract'; END IF;
RAISE NOTICE 'PASS active/attendance-setup';
BEGIN PERFORM public.leave_my_request_detail('f9110000-0000-4000-8000-000000000001','f9140000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'missing_detail_exposed'; EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
RAISE NOTICE 'PASS active/missing-detail';
END $$;
-- Remaining contexts appended by the generator; each case asserts caller-visible SQLSTATE.
DO $case$ BEGIN BEGIN PERFORM public.tenant_my_employee_snapshot('f9110000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS cross-tenant/profile'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.attendance_mobile_snapshot('f9110000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS cross-tenant/attendance'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_access_snapshot('f9110000-0000-4000-8000-000000000002'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS cross-tenant/leave-access'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_my_balances('f9110000-0000-4000-8000-000000000002',50,0); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS cross-tenant/leave-balances'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_my_requests('f9110000-0000-4000-8000-000000000002',50,0); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS cross-tenant/leave-requests'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_my_request_detail('f9110000-0000-4000-8000-000000000002','f9140000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END; RAISE NOTICE 'PASS cross-tenant/leave-detail'; END $case$;
RESET ROLE; UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='f9110000-0000-4000-8000-000000000001'; SET LOCAL ROLE authenticated;
DO $case$ BEGIN BEGIN PERFORM public.tenant_my_employee_snapshot('f9110000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS inactive-membership/profile'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.attendance_mobile_snapshot('f9110000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS inactive-membership/attendance'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_access_snapshot('f9110000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS inactive-membership/leave-access'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_my_balances('f9110000-0000-4000-8000-000000000001',50,0); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS inactive-membership/leave-balances'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_my_requests('f9110000-0000-4000-8000-000000000001',50,0); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS inactive-membership/leave-requests'; END $case$;
DO $case$ BEGIN BEGIN PERFORM public.leave_my_request_detail('f9110000-0000-4000-8000-000000000001','f9140000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'unexpected_success' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END; RAISE NOTICE 'PASS inactive-membership/leave-detail'; END $case$;
RESET ROLE; ROLLBACK; SELECT json_build_object('users',(SELECT count(*) FROM auth.users),'tenants',(SELECT count(*) FROM platform_core.tenants),'employees',(SELECT count(*) FROM people.employees));
