-- Credential readiness is required to grant Admin authority; removing it still protects the last recoverable Admin.
CREATE OR REPLACE FUNCTION public.change_tenant_admin_role(p_tenant_id uuid,p_user_id uuid,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_tenant_state text;
  v_admin_role uuid;
  v_member_role uuid;
  v_before jsonb;
  v_after jsonb;
  v_has_admin boolean;
BEGIN
  IF p_action NOT IN ('promote','demote') THEN
    RAISE EXCEPTION 'tenant_admin_role_action_invalid' USING ERRCODE='22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=p_tenant_id;
  IF NOT FOUND OR v_tenant_state<>'active' THEN
    RAISE EXCEPTION 'tenant_admin_role_tenant_unavailable' USING ERRCODE='55000';
  END IF;
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.administer')
     OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_admin_role_forbidden' USING ERRCODE='42501';
  END IF;

  PERFORM 1
  FROM platform_core.tenant_memberships m
  JOIN auth.users u ON u.id=m.user_id
  WHERE m.tenant_id=p_tenant_id AND m.user_id=p_user_id AND m.access_state='active'
    AND (p_action='demote' OR (u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
    AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
    AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness ready WHERE ready.user_id=u.id))))
  FOR UPDATE OF m;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant_admin_role_target_unavailable' USING ERRCODE='42501';
  END IF;

  SELECT role_id INTO v_admin_role FROM platform_core.tenant_roles
  WHERE tenant_id=p_tenant_id AND role_key='tenant.owner_admin.v1' AND role_version=1
    AND protects_tenant_admin
    AND permission_snapshot @> ARRAY['tenant.administer','tenant.members.manage']::text[];
  IF v_admin_role IS NULL THEN
    RAISE EXCEPTION 'tenant_admin_role_template_unavailable' USING ERRCODE='55000';
  END IF;
  SELECT role_id INTO v_member_role FROM platform_core.tenant_roles
  WHERE tenant_id=p_tenant_id AND role_key='tenant.member.v1' AND role_version=1 AND NOT protects_tenant_admin;
  IF v_member_role IS NULL THEN
    RAISE EXCEPTION 'tenant_member_role_template_unavailable' USING ERRCODE='55000';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM platform_core.membership_roles assignment
    JOIN platform_core.tenant_roles role_snapshot USING (tenant_id,role_id)
    WHERE assignment.tenant_id=p_tenant_id AND assignment.user_id=p_user_id
      AND role_snapshot.protects_tenant_admin
  ) INTO v_has_admin;

  IF p_action='promote' THEN
    IF EXISTS (SELECT 1 FROM platform_core.membership_roles WHERE tenant_id=p_tenant_id AND user_id=p_user_id AND role_id=v_admin_role) THEN
      RETURN pg_catalog.jsonb_build_object('state','already_admin','tenant_id',p_tenant_id,'user_id',p_user_id);
    END IF;
  ELSE
    IF NOT v_has_admin THEN
      RETURN pg_catalog.jsonb_build_object('state','already_member','tenant_id',p_tenant_id,'user_id',p_user_id);
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM platform_core.tenant_memberships m
      JOIN auth.users u ON u.id=m.user_id
      JOIN platform_core.membership_roles assignment ON assignment.tenant_id=m.tenant_id AND assignment.user_id=m.user_id
      JOIN platform_core.tenant_roles role_snapshot ON role_snapshot.tenant_id=assignment.tenant_id AND role_snapshot.role_id=assignment.role_id
      WHERE m.tenant_id=p_tenant_id AND m.user_id<>p_user_id AND m.access_state='active'
        AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
        AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
        AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>''
        AND (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness ready WHERE ready.user_id=u.id))
        AND role_snapshot.protects_tenant_admin
        AND role_snapshot.permission_snapshot @> ARRAY['tenant.administer','tenant.members.manage']::text[]
    ) THEN
      RAISE EXCEPTION 'tenant_admin_last_recoverable' USING ERRCODE='23514';
    END IF;
  END IF;

  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('role_key',r.role_key,'role_version',r.role_version)
    ORDER BY r.role_key,r.role_version),'[]'::jsonb) INTO v_before
  FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING (tenant_id,role_id)
  WHERE mr.tenant_id=p_tenant_id AND mr.user_id=p_user_id;

  IF p_action='promote' THEN
    DELETE FROM platform_core.membership_roles mr USING platform_core.tenant_roles r
    WHERE mr.tenant_id=p_tenant_id AND mr.user_id=p_user_id
      AND r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id AND r.role_key='tenant.member.v1';
    INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
    VALUES(p_tenant_id,p_user_id,v_admin_role);
  ELSE
    DELETE FROM platform_core.membership_roles mr USING platform_core.tenant_roles r
    WHERE mr.tenant_id=p_tenant_id AND mr.user_id=p_user_id
      AND r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id AND r.protects_tenant_admin;
    INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
    VALUES(p_tenant_id,p_user_id,v_member_role) ON CONFLICT DO NOTHING;
  END IF;

  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('role_key',r.role_key,'role_version',r.role_version)
    ORDER BY r.role_key,r.role_version),'[]'::jsonb) INTO v_after
  FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING (tenant_id,role_id)
  WHERE mr.tenant_id=p_tenant_id AND mr.user_id=p_user_id;

  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,actor_user_id,subject_user_id,action,details)
  VALUES(p_tenant_id,v_actor,p_user_id,CASE WHEN p_action='promote' THEN 'admin_role_promoted' ELSE 'admin_role_demoted' END,
    pg_catalog.jsonb_build_object('before',v_before,'after',v_after,'operation',p_action));

  RETURN pg_catalog.jsonb_build_object('state',CASE WHEN p_action='promote' THEN 'promoted' ELSE 'demoted' END,
    'tenant_id',p_tenant_id,'user_id',p_user_id,'seat_usage_unchanged',true);
END;
$function$;
REVOKE ALL ON FUNCTION public.change_tenant_admin_role(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_tenant_admin_role(uuid,uuid,text) TO authenticated;
