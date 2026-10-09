DO $$
DECLARE tenant uuid:='f5100000-0000-4000-8000-000000000001';manager uuid:='f9100000-0000-4000-8000-000000000001';
BEGIN
IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' OR (SELECT count(*) FROM auth.users)<>2 THEN RAISE EXCEPTION 'owned synthetic QA only'; END IF;
PERFORM set_config('request.jwt.claim.sub',manager::text,true);
PERFORM public.change_tenant_capability_limit(tenant,'tenant.users','max_users','limited',3,'تهيئة حد اصطناعي لقبول إدارة الأعضاء');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES(tenant,'f7120000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(tenant,manager,'f7120000-0000-4000-8000-000000000001');
RAISE NOTICE 'OWNED_MEMBER_UI_PRECONDITIONS_READY';
END $$;

-- After the initial missing-template refusal, before the last-admin case:
DO $$ BEGIN
IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' THEN RAISE EXCEPTION 'owned synthetic QA only'; END IF;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES('f5100000-0000-4000-8000-000000000001','f7120000-0000-4000-8000-000000000002','tenant.member.v1',1,ARRAY[]::text[],false);
END $$;
