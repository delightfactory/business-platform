-- Expose the exact own-request authorization used by Leave RPCs to the UI.
-- Existing access checks and visibility fields intentionally remain unchanged.
CREATE OR REPLACE FUNCTION public.leave_access_snapshot(p_tenant uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE
  a uuid:=auth.uid(); can_view boolean; can_manage boolean; can_approve boolean;
  can_adjust boolean; self_access boolean; self_can_request boolean;
  enabled boolean; employers jsonb; employer_more boolean;
BEGIN
  IF a IS NULL OR NOT EXISTS(
    SELECT 1 FROM platform_core.tenants t
    JOIN platform_core.tenant_memberships m ON m.tenant_id=t.id
    JOIN auth.users u ON u.id=m.user_id
    WHERE t.id=p_tenant AND t.lifecycle_state='active' AND m.user_id=a
      AND m.access_state='active' AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=now())
  ) THEN
    RAISE EXCEPTION 'leave_forbidden' USING ERRCODE='42501';
  END IF;
  can_view:=platform_private.has_tenant_permission(p_tenant,a,'leave.view')
    OR platform_private.has_tenant_permission(p_tenant,a,'leave.manage')
    OR platform_private.has_tenant_permission(p_tenant,a,'leave.approve');
  can_manage:=platform_private.has_tenant_permission(p_tenant,a,'leave.manage');
  can_approve:=platform_private.has_tenant_permission(p_tenant,a,'leave.approve');
  can_adjust:=platform_private.has_tenant_permission(p_tenant,a,'leave_balance.adjust');
  self_access:=platform_private.has_leave_self_permission(p_tenant,a,'leave.self.view');
  self_can_request:=platform_private.has_leave_self_permission(p_tenant,a,'leave.self.request');
  IF NOT (can_view OR can_manage OR can_approve OR can_adjust OR self_access) THEN
    RAISE EXCEPTION 'leave_forbidden' USING ERRCODE='42501';
  END IF;
  enabled:=platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',now())
    AND platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',now());
  SELECT coalesce(jsonb_agg(x.item ORDER BY x.display_name,x.id),'[]'::jsonb)
    INTO employers
    FROM (
      SELECT e.id,e.display_name,
        jsonb_build_object('id',e.id,'display_name',e.display_name,'is_active',e.is_active) item
      FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant AND e.is_active
        AND (can_view OR can_manage OR can_approve OR can_adjust)
      ORDER BY e.display_name,e.id LIMIT 100
    ) x;
  SELECT EXISTS(
    SELECT 1 FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant AND e.is_active
      AND (can_view OR can_manage OR can_approve OR can_adjust)
    ORDER BY e.display_name,e.id OFFSET 100 LIMIT 1
  ) INTO employer_more;
  RETURN jsonb_build_object(
    'can_view',can_view,'can_manage',can_manage,'can_approve',can_approve,
    'can_adjust',can_adjust,'self_access',self_access,
    'self_can_request',self_can_request,'new_work_enabled',enabled,
    'employers',employers,'employers_has_more',employer_more
  );
END $f$;
REVOKE ALL ON FUNCTION public.leave_access_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_access_snapshot(uuid) TO authenticated;
