BEGIN;
DO $$ BEGIN
IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' OR (SELECT count(*) FROM auth.users)<>2 THEN RAISE EXCEPTION 'owned synthetic QA only'; END IF;
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES('f9110000-0000-4000-8000-000000000001','f9200000-0000-4000-8000-000000000002','active','f9100000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES('f9110000-0000-4000-8000-000000000001','f8120000-0000-4000-8000-000000000001','tenant.member.v1',1,ARRAY[]::text[],false);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('f9110000-0000-4000-8000-000000000001','f9200000-0000-4000-8000-000000000002','f8120000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_branding(tenant_id,display_name,primary_color_key,updated_by_user_id) VALUES('f5100000-0000-4000-8000-000000000001','شركة الاختبار الزرقاء','blue','f9100000-0000-4000-8000-000000000001'),('f9110000-0000-4000-8000-000000000001','شركة الاختبار الخضراء','emerald','f9100000-0000-4000-8000-000000000001') ON CONFLICT(tenant_id) DO UPDATE SET display_name=excluded.display_name,primary_color_key=excluded.primary_color_key;
RAISE NOTICE 'SYNTHETIC_BRANDING_CONTEXT_READY'; END $$;
COMMIT;
