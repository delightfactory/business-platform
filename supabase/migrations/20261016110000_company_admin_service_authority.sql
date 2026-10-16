-- Company administrators inherit service operations without mutable bundle copies.
-- Explicit member grants and the existing identity/lifecycle checks stay intact.
CREATE FUNCTION platform_private.admin_service_permission_catalog()
RETURNS TABLE(permission text,capability_key text,history_read boolean)
LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT permission,capability_key,history_read FROM (VALUES
 ('people.view','hr.people',true),('people.manage','hr.people',false),
 ('employment.manage','hr.people',false),('org_context.manage','hr.people',false),
 ('compensation.view','hr.people',true),('compensation.manage','hr.people',false),
 ('workforce_import.execute','hr.people',false),
 ('attendance_policy.manage','hr.attendance',false),
 ('attendance.view','hr.attendance',true),('attendance.manage','hr.attendance',false),
 ('attendance.correct','hr.attendance',false),('attendance.approve','hr.attendance',false),
 ('leave.view','hr.leave',true),('leave.manage','hr.leave',false),
 ('leave.approve','hr.leave',false),('leave_balance.adjust','hr.leave',false),
 ('payroll.view','hr.payroll',true),('payroll.review','hr.payroll',true),
 ('payroll_config.manage','hr.payroll',false),('payroll.prepare','hr.payroll',false),
 ('payroll.approve','hr.payroll',false),('payroll.correct','hr.payroll',false),
 ('payroll.lock','hr.payroll',false),('payroll.export','hr.payroll',true),
 ('payroll.payment_record','hr.payroll',false),
 ('employee_finance.view','hr.employee_finance',true),
 ('employee_finance.manage','hr.employee_finance',false),
 ('employee_finance.approve','hr.employee_finance',false)
 ) service(permission,capability_key,history_read);
$f$;
REVOKE ALL ON FUNCTION platform_private.admin_service_permission_catalog() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION platform_private.has_tenant_permission(p_tenant_id uuid,p_user_id uuid,p_permission text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT p_user_id IS NOT NULL AND EXISTS (
  SELECT 1 FROM platform_core.tenants t
  JOIN platform_core.tenant_memberships m ON m.tenant_id=t.id
  JOIN platform_core.membership_roles mr ON mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id
  JOIN platform_core.tenant_roles r ON r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id
  JOIN auth.users u ON u.id=m.user_id
  WHERE t.id=p_tenant_id AND t.lifecycle_state='active'
   AND m.user_id=p_user_id AND m.access_state='active'
   AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
   AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
   AND (r.permission_snapshot @> ARRAY[p_permission]::text[]
    OR (r.protects_tenant_admin AND r.permission_snapshot @> ARRAY['tenant.administer']::text[]
     AND EXISTS (
      SELECT 1 FROM platform_private.admin_service_permission_catalog() s
      WHERE s.permission=p_permission AND (
       platform_private.tenant_capability_is_enabled(p_tenant_id,s.capability_key,pg_catalog.now())
       OR (s.history_read AND EXISTS (
        SELECT 1 FROM platform_core.tenant_capability_entitlements e
        WHERE e.tenant_id=p_tenant_id AND e.capability_key=s.capability_key
         AND e.is_granted AND e.valid_from<=pg_catalog.now()
       ))
      )
     )
    ))
 );
$f$;

DO $coverage$
BEGIN
 IF EXISTS (
  SELECT 1 FROM platform_private.people_role_bundle_catalog() b
  CROSS JOIN LATERAL unnest(b.permission_snapshot) p(permission)
  WHERE p.permission NOT IN ('attendance.self.capture','people.self.view','leave.self.view','leave.self.request')
   AND NOT EXISTS (SELECT 1 FROM platform_private.admin_service_permission_catalog() s WHERE s.permission=p.permission)
 ) THEN RAISE EXCEPTION 'admin_service_permission_mapping_incomplete'; END IF;
END $coverage$;
NOTIFY pgrst,'reload schema';
