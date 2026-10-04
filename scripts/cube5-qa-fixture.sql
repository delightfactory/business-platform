-- QA-only synthetic fixture. Caller supplies freshly created confirmed synthetic Auth users.
-- Run only in business_platform_cube5_adam_channels_qa; never deploy this file.
CREATE FUNCTION pg_temp.seed_cube5_fixture(p_operator uuid,p_employee_user uuid) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE tenant uuid:='f5100000-0000-4000-8000-000000000001';employer uuid:='f5130000-0000-4000-8000-000000000001';site uuid:='f5140000-0000-4000-8000-000000000001';policy uuid:='f5150000-0000-4000-8000-000000000001';person jsonb;mobile uuid;external uuid;
BEGIN
 IF current_database()<>'business_platform_cube5_adam_channels_qa' THEN RAISE EXCEPTION 'cube5_fixture_wrong_database'; END IF;
 INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES(tenant,'Cube5 Synthetic QA',p_operator);
 INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin) VALUES
 (tenant,'f5120000-0000-4000-8000-000000000001','cube5.synthetic.operator',1,ARRAY['tenant.administer','tenant.members.manage','people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage','attendance.view','attendance.manage','attendance.correct','attendance.approve','attendance_policy.manage'],false),
 (tenant,'f5120000-0000-4000-8000-000000000002','employee.attendance.self.v1',1,ARRAY['attendance.self.capture'],false);
 INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id) VALUES(tenant,p_operator,'active',p_operator),(tenant,p_employee_user,'active',p_operator);
 INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(tenant,p_operator,'f5120000-0000-4000-8000-000000000001'),(tenant,p_employee_user,'f5120000-0000-4000-8000-000000000002');
 INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES(tenant,'hr.people',true,now()-interval '1 day',p_operator,'Synthetic QA'),(tenant,'hr.attendance',true,now()-interval '1 day',p_operator,'Synthetic QA');
 INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default) VALUES(tenant,employer,'Synthetic employer',true);
 INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES(tenant,site,employer,'Synthetic UTC site',true,true);
 INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES(tenant,policy,'CUBE5-QA',true,1);
 INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by)
 VALUES(tenant,policy,1,'Synthetic all-day work','flexible','UTC',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59:59',p_operator);
 PERFORM set_config('request.jwt.claim.sub',p_operator::text,true);
 person:=public.create_people_employee(tenant,'CUBE5-SYN-1','موظف تجريبي',employer,site,(now() AT TIME ZONE 'UTC')::date-30,'monthly',1000,true);
 UPDATE people.work_assignments SET work_policy_template_id=policy,work_policy_version=1 WHERE tenant_id=tenant AND employment_id=(person->>'employment_id')::uuid;
 INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id) VALUES(tenant,(person->>'employee_id')::uuid,p_employee_user,p_operator);
 mobile:=public.attendance_channel_save_source(tenant,NULL,'الحضور من الهاتف','mobile',site,true,'{"geofence":false,"retention_seconds":300}'::jsonb,'Synthetic QA capture');
 external:=public.attendance_channel_save_source(tenant,NULL,'مصدر تجريبي','external',site,true,'{}'::jsonb,'Synthetic QA gateway');
 RETURN jsonb_build_object('tenant_id',tenant,'employee_id',person->>'employee_id','employment_id',person->>'employment_id','site_id',site,'mobile_source_id',mobile,'external_source_id',external,'operator_id',p_operator,'employee_user_id',p_employee_user);
END $f$;
