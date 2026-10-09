BEGIN;
DO $$ BEGIN IF current_database()<>'business_platform_ux_c93f09f_qa' THEN RAISE EXCEPTION 'wrong_database'; END IF; END $$;
SET LOCAL ROLE anon;
SET LOCAL request.jwt.claim.sub='';
SET LOCAL request.jwt.claims='{}';
DO $case$ BEGIN
 BEGIN PERFORM public.tenant_my_employee_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS anon/profile 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.attendance_mobile_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS anon/attendance 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_access_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS anon/leave-access 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_balances('11111111-1111-4111-8111-111111111111',50,0); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS anon/leave-balances 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_requests('11111111-1111-4111-8111-111111111111',50,0); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS anon/leave-requests 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_request_detail('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS anon/leave-detail 42501';
END $case$;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='';
SET LOCAL request.jwt.claims='{}';
DO $case$ BEGIN
 BEGIN PERFORM public.tenant_my_employee_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-no-actor/profile 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.attendance_mobile_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-no-actor/attendance 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_access_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-no-actor/leave-access 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_balances('11111111-1111-4111-8111-111111111111',50,0); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-no-actor/leave-balances 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_requests('11111111-1111-4111-8111-111111111111',50,0); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-no-actor/leave-requests 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_request_detail('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-no-actor/leave-detail P0002';
END $case$;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='';
SET LOCAL request.jwt.claims='{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
DO $case$ BEGIN
 BEGIN PERFORM public.tenant_my_employee_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-unbound-actor/profile 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.attendance_mobile_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-unbound-actor/attendance 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_access_snapshot('11111111-1111-4111-8111-111111111111'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-unbound-actor/leave-access 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_balances('11111111-1111-4111-8111-111111111111',50,0); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-unbound-actor/leave-balances 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_requests('11111111-1111-4111-8111-111111111111',50,0); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-unbound-actor/leave-requests 42501';
END $case$;
DO $case$ BEGIN
 BEGIN PERFORM public.leave_my_request_detail('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'); RAISE EXCEPTION 'unexpected_read_success' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
 RAISE NOTICE 'PASS authenticated-unbound-actor/leave-detail P0002';
END $case$;
RESET ROLE;
ROLLBACK;
SELECT json_build_object('authUsers',(SELECT count(*) FROM auth.users),'sessions',(SELECT count(*) FROM auth.sessions),'tenants',(SELECT count(*) FROM platform_core.tenants));
