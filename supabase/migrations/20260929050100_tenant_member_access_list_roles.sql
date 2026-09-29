CREATE OR REPLACE FUNCTION public.tenant_member_access_list(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_rows jsonb; v_limits jsonb; v_usage integer; v_limit_rows integer;
BEGIN
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  WITH expired AS (
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=p_tenant_id AND lifecycle_state='pending' AND expires_at<=pg_catalog.now()
    RETURNING id,target_email,issuance
  )
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    SELECT p_tenant_id,id,v_actor,target_email,'expired',pg_catalog.jsonb_build_object('issuance',issuance) FROM expired;

  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'user_id',m.user_id,'email',u.email,'access_state',m.access_state,
    'role_key',CASE WHEN pg_catalog.cardinality(role_rows.role_keys)=1 THEN role_rows.role_keys[1] ELSE NULL END,
    'roles',COALESCE(role_rows.roles,'[]'::jsonb),
    'protected_admin',COALESCE(role_rows.protected_admin,false)
  ) ORDER BY u.email)
  INTO v_rows
  FROM platform_core.tenant_memberships m
  JOIN auth.users u ON u.id=m.user_id
  LEFT JOIN LATERAL (
    SELECT pg_catalog.array_agg(r.role_key ORDER BY r.role_key,r.role_version) AS role_keys,
      pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('role_key',r.role_key,'role_version',r.role_version)
        ORDER BY r.role_key,r.role_version) AS roles,
      pg_catalog.bool_or(r.protects_tenant_admin) AS protected_admin
    FROM platform_core.membership_roles mr
    JOIN platform_core.tenant_roles r ON r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id
    WHERE mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id
  ) role_rows ON true
  WHERE m.tenant_id=p_tenant_id;

  SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_memberships m
  WHERE m.tenant_id=p_tenant_id AND m.access_state='active';
  SELECT pg_catalog.count(*)::integer INTO v_limit_rows FROM platform_core.tenant_capability_limits l
  WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.users'
    AND l.valid_from<=pg_catalog.transaction_timestamp()
    AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());
  IF v_limit_rows<>1 THEN RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000'; END IF;
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',i.id,'target_email',i.target_email,'lifecycle_state',i.lifecycle_state,
    'delivery_state',i.delivery_state,'issuance',i.issuance,'expires_at',i.expires_at)
    ORDER BY i.created_at DESC) INTO v_limits FROM platform_core.tenant_member_invitations i WHERE i.tenant_id=p_tenant_id;
  RETURN pg_catalog.jsonb_build_object('memberships',COALESCE(v_rows,'[]'::jsonb),'invitations',COALESCE(v_limits,'[]'::jsonb),
    'seat_usage',v_usage,'seat_limit',(
      SELECT pg_catalog.jsonb_build_object('mode',l.limit_mode,'value',l.limit_value)
      FROM platform_core.tenant_capability_limits l WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.users'
        AND l.valid_from<=pg_catalog.transaction_timestamp() AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp())
    ));
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_member_access_list(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_member_access_list(uuid) TO authenticated;
