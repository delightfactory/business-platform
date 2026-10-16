BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
SELECT ('fa110000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'service-authority-'||i||'@example.test','fixture',now(),'{}','{}','authenticated','authenticated',now(),now()
FROM generate_series(1,3) i;
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
SELECT ('fa220000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'Service authority '||i,'fa110000-0000-4000-8000-000000000001'
FROM generate_series(1,2) i;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES
 ('fa220000-0000-4000-8000-000000000001','fa330000-0000-4000-8000-000000000001','tenant.owner_admin.v1',1,ARRAY['tenant.administer','tenant.members.manage','tenant.sites.manage','tenant.legal_entities.manage'],true),
 ('fa220000-0000-4000-8000-000000000001','fa330000-0000-4000-8000-000000000002','tenant.member.v1',1,ARRAY[]::text[],false),
 ('fa220000-0000-4000-8000-000000000001','fa330000-0000-4000-8000-000000000003','payroll.payment.recorder.v1',1,ARRAY['payroll.view','payroll.payment_record'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
SELECT 'fa220000-0000-4000-8000-000000000001',id,'fa110000-0000-4000-8000-000000000001'
FROM auth.users WHERE id IN ('fa110000-0000-4000-8000-000000000001','fa110000-0000-4000-8000-000000000002','fa110000-0000-4000-8000-000000000003');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('fa220000-0000-4000-8000-000000000001','fa110000-0000-4000-8000-000000000001','fa330000-0000-4000-8000-000000000001'),
 ('fa220000-0000-4000-8000-000000000001','fa110000-0000-4000-8000-000000000002','fa330000-0000-4000-8000-000000000002'),
 ('fa220000-0000-4000-8000-000000000001','fa110000-0000-4000-8000-000000000003','fa330000-0000-4000-8000-000000000001');
CREATE FUNCTION pg_temp.permitted(p text,u uuid DEFAULT 'fa110000-0000-4000-8000-000000000001') RETURNS boolean LANGUAGE sql AS $$
 SELECT platform_private.has_tenant_permission('fa220000-0000-4000-8000-000000000001',u,p);
$$;
SELECT ok(NOT pg_temp.permitted('payroll.view'),'never-enabled service does not grant inherited access');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
SELECT 'fa220000-0000-4000-8000-000000000001',k,true,now()-interval '1 day','fa110000-0000-4000-8000-000000000001','Synthetic authority fixture'
FROM unnest(ARRAY['hr.people','hr.attendance','hr.leave','hr.payroll','hr.employee_finance']) k;
SELECT ok(pg_temp.permitted(permission),'admin inherits enabled operation: '||permission)
FROM platform_private.admin_service_permission_catalog();
SELECT ok(NOT pg_temp.permitted(p),'employee/operator/unknown right not inherited: '||p)
FROM unnest(ARRAY['attendance.self.capture','people.self.view','leave.self.view','leave.self.request','platform.operator.manage','unknown.permission']) p;
SELECT ok(NOT pg_temp.permitted('payroll.prepare','fa110000-0000-4000-8000-000000000002'),'ordinary member gets no automatic payroll authority');
SELECT ok(NOT platform_private.has_tenant_permission('fa220000-0000-4000-8000-000000000002','fa110000-0000-4000-8000-000000000001','payroll.view'),'admin cannot access another real tenant');
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now() WHERE tenant_id='fa220000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
SELECT ok(NOT pg_temp.permitted(p),'expired payroll removes inherited operation: '||p)
FROM unnest(ARRAY['payroll_config.manage','payroll.prepare','payroll.approve','payroll.lock','payroll.payment_record']) p;
SELECT ok(pg_temp.permitted('payroll.view'),'expired service preserves historical read authority');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES('fa220000-0000-4000-8000-000000000001','hr.payroll',true,now(),'fa110000-0000-4000-8000-000000000001','Synthetic resumed service');
SELECT ok(pg_temp.permitted('payroll.prepare'),'service re-enable restores inherited operation without bundle writes');
UPDATE platform_core.tenant_capability_entitlements SET valid_until=now() WHERE tenant_id='fa220000-0000-4000-8000-000000000001' AND capability_key='hr.people';
SELECT ok(NOT pg_temp.permitted('payroll.prepare') AND NOT pg_temp.permitted('employee_finance.manage'),'missing People dependency disables child operations');
SELECT ok(pg_temp.permitted('payroll.view'),'history survives parent-service expiry');
UPDATE platform_core.tenant_capability_entitlements SET valid_until=NULL WHERE tenant_id='fa220000-0000-4000-8000-000000000001' AND capability_key='hr.people';
UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='fa220000-0000-4000-8000-000000000001' AND user_id='fa110000-0000-4000-8000-000000000001';
SELECT ok(NOT pg_temp.permitted('payroll.view'),'inactive membership loses even historical access');
UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id='fa220000-0000-4000-8000-000000000001' AND user_id='fa110000-0000-4000-8000-000000000001';
UPDATE auth.users SET banned_until=now()+interval '1 day' WHERE id='fa110000-0000-4000-8000-000000000001';
SELECT ok(NOT pg_temp.permitted('payroll.view'),'banned admin denied');
UPDATE auth.users SET banned_until=NULL,email_confirmed_at=NULL WHERE id='fa110000-0000-4000-8000-000000000001';
SELECT ok(NOT pg_temp.permitted('payroll.view'),'unconfirmed admin denied');
UPDATE auth.users SET email_confirmed_at=now() WHERE id='fa110000-0000-4000-8000-000000000001';
UPDATE platform_core.tenants SET lifecycle_state='suspended' WHERE id='fa220000-0000-4000-8000-000000000001';
SELECT ok(NOT pg_temp.permitted('payroll.view'),'suspended tenant denied');
UPDATE platform_core.tenants SET lifecycle_state='active' WHERE id='fa220000-0000-4000-8000-000000000001';
DELETE FROM platform_core.membership_roles WHERE tenant_id='fa220000-0000-4000-8000-000000000001' AND user_id='fa110000-0000-4000-8000-000000000003';
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('fa220000-0000-4000-8000-000000000001','fa110000-0000-4000-8000-000000000003','fa330000-0000-4000-8000-000000000002');
SELECT ok(NOT pg_temp.permitted('payroll.prepare','fa110000-0000-4000-8000-000000000003'),'admin demotion removes inherited rights without leftover bundles');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES('fa220000-0000-4000-8000-000000000001','fa110000-0000-4000-8000-000000000002','fa330000-0000-4000-8000-000000000003');
SELECT ok(pg_temp.permitted('payroll.payment_record','fa110000-0000-4000-8000-000000000002') AND NOT pg_temp.permitted('payroll.prepare','fa110000-0000-4000-8000-000000000002'),'explicit member bundle keeps its exact narrow scope');
SELECT ok(NOT has_function_privilege('authenticated','platform_private.admin_service_permission_catalog()','EXECUTE'),'private map is not an authenticated API');
SELECT * FROM finish();
ROLLBACK;
