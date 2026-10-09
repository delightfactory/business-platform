-- Current-schema actual caller acceptance. Synthetic fixtures, no login credential.
-- This tests PostgreSQL authorization with supplied claims, not Auth sessions.
BEGIN;
DO $$ BEGIN IF current_database() IS DISTINCT FROM 'business_platform_ux_c93f09f_qa' THEN RAISE EXCEPTION 'wrong_database'; END IF; END $$;
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

INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES('f9110000-0000-4000-8000-000000000001','f9150000-0000-4000-8000-000000000001','Synthetic Employer',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('f9110000-0000-4000-8000-000000000001','f9130000-0000-4000-8000-000000000002','UX-OTHER','Synthetic Other','f9100000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) SELECT 'f9110000-0000-4000-8000-000000000001',('f9160000-0000-4000-8000-00000000000'||i)::uuid,('f9130000-0000-4000-8000-00000000000'||i)::uuid,'f9150000-0000-4000-8000-000000000001','2026-01-01','monthly' FROM generate_series(1,2)i;
INSERT INTO leave.types(tenant_id,id,employer_entity_id,code,name) VALUES('f9110000-0000-4000-8000-000000000001','f9170000-0000-4000-8000-000000000001','f9150000-0000-4000-8000-000000000001','SYNTHETIC','Synthetic Leave');
INSERT INTO leave.requests(tenant_id,id,employee_id,employment_id,employer_entity_id,leave_type_id,start_date,end_date,request_source,created_by,submitted_by,reason,created_at)
SELECT 'f9110000-0000-4000-8000-000000000001',('f9140000-0000-4000-8000-00000000000'||i)::uuid,('f9130000-0000-4000-8000-00000000000'||CASE WHEN i=4 THEN 2 ELSE 1 END)::uuid,('f9160000-0000-4000-8000-00000000000'||CASE WHEN i=4 THEN 2 ELSE 1 END)::uuid,'f9150000-0000-4000-8000-000000000001','f9170000-0000-4000-8000-000000000001','2026-11-01'::date+i,'2026-11-01'::date+i,'employee','f9100000-0000-4000-8000-000000000001','f9100000-0000-4000-8000-000000000001',CASE WHEN i=4 THEN 'SYNTHETIC OTHER PRIVATE REASON' ELSE 'SYNTHETIC OWN REASON' END,'2026-10-01'::timestamptz+make_interval(days=>i) FROM generate_series(1,4)i;
INSERT INTO leave.request_previews(tenant_id,request_id,preview_version,total_units,created_by) SELECT tenant_id,id,1,1,'f9100000-0000-4000-8000-000000000001' FROM leave.requests;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='f9100000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claims='{}';
DO $cases$ DECLARE value jsonb; BEGIN
value:=public.leave_my_requests('f9110000-0000-4000-8000-000000000001',2,0);
IF jsonb_array_length(value->'items') IS DISTINCT FROM 2 OR value->>'has_more' IS DISTINCT FROM 'true' OR value->'items'->0->>'id' IS DISTINCT FROM 'f9140000-0000-4000-8000-000000000003' OR value->'items'->1->>'id' IS DISTINCT FROM 'f9140000-0000-4000-8000-000000000002' OR value::text LIKE '%OTHER PRIVATE%' THEN RAISE EXCEPTION 'own_page_isolation'; END IF;
RAISE NOTICE 'PASS nonempty/own-first-page';
value:=public.leave_my_requests('f9110000-0000-4000-8000-000000000001',2,2);
IF jsonb_array_length(value->'items') IS DISTINCT FROM 1 OR value->>'has_more' IS DISTINCT FROM 'false' OR value->'items'->0->>'id' IS DISTINCT FROM 'f9140000-0000-4000-8000-000000000001' THEN RAISE EXCEPTION 'own_next_page'; END IF;
RAISE NOTICE 'PASS nonempty/own-terminal-page';
value:=public.leave_my_request_detail('f9110000-0000-4000-8000-000000000001','f9140000-0000-4000-8000-000000000001');
IF value->>'id' IS DISTINCT FROM 'f9140000-0000-4000-8000-000000000001' OR value->>'reason' IS DISTINCT FROM 'SYNTHETIC OWN REASON' OR value->>'state' IS DISTINCT FROM 'submitted' THEN RAISE EXCEPTION 'own_detail_missing'; END IF;
RAISE NOTICE 'PASS nonempty/own-detail';
BEGIN PERFORM public.leave_my_request_detail('f9110000-0000-4000-8000-000000000001','f9140000-0000-4000-8000-000000000004'); RAISE EXCEPTION 'other_exposed' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
RAISE NOTICE 'PASS nonempty/other-detail-unavailable';
END $cases$;
RESET ROLE;
-- Add HR visibility to the same actor: the own-service boundary must still stay own-only.
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES('f9110000-0000-4000-8000-000000000001','f9120000-0000-4000-8000-000000000002','ux.hr.fixture.v1',1,ARRAY['leave.view'],false);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('f9110000-0000-4000-8000-000000000001','f9100000-0000-4000-8000-000000000001','f9120000-0000-4000-8000-000000000002');
SET LOCAL ROLE authenticated;
DO $cases$ DECLARE value jsonb; BEGIN
value:=public.leave_my_requests('f9110000-0000-4000-8000-000000000001',50,0);
IF jsonb_array_length(value->'items') IS DISTINCT FROM 3 OR value::text LIKE '%OTHER PRIVATE%' THEN RAISE EXCEPTION 'mixed_role_list_leak'; END IF; RAISE NOTICE 'PASS mixed-role/own-list';
BEGIN PERFORM public.leave_my_request_detail('f9110000-0000-4000-8000-000000000001','f9140000-0000-4000-8000-000000000004'); RAISE EXCEPTION 'mixed_role_other_exposed' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END; RAISE NOTICE 'PASS mixed-role/other-detail-unavailable';
END $cases$;
RESET ROLE; UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='f9110000-0000-4000-8000-000000000001'; SET LOCAL ROLE authenticated;
DO $cases$ BEGIN
BEGIN PERFORM public.leave_my_requests('f9110000-0000-4000-8000-000000000001',50,0); RAISE EXCEPTION 'inactive_list_exposed' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END; RAISE NOTICE 'PASS inactive/nonempty-list-denied';
BEGIN PERFORM public.leave_my_request_detail('f9110000-0000-4000-8000-000000000001','f9140000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'inactive_detail_exposed' USING ERRCODE='ZX001'; EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END; RAISE NOTICE 'PASS inactive/previous-own-detail-unavailable';
END $cases$;
RESET ROLE; ROLLBACK;
SELECT json_build_object('users',(SELECT count(*) FROM auth.users),'tenants',(SELECT count(*) FROM platform_core.tenants),'employees',(SELECT count(*) FROM people.employees),'requests',(SELECT count(*) FROM leave.requests));
