-- Keep the historical tenant_member_access_list RPC for existing clients. This
-- read-only endpoint bounds returned rows and leaves expiry/audit to mutations.
CREATE INDEX tenant_membership_created_page_idx
  ON platform_core.tenant_memberships(tenant_id,created_at DESC,user_id DESC);
DROP INDEX platform_core.tenant_member_invitation_tenant_history_idx;
CREATE INDEX tenant_member_invitation_tenant_history_idx
  ON platform_core.tenant_member_invitations(tenant_id,created_at DESC,id DESC);

CREATE FUNCTION public.tenant_member_access_page(
  p_tenant_id uuid, p_view text DEFAULT 'members', p_page integer DEFAULT 1, p_query text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_view text := COALESCE(p_view,'members');
  v_page integer := GREATEST(1,LEAST(COALESCE(p_page,1),100000));
  v_query text := NULLIF(pg_catalog.left(pg_catalog.btrim(COALESCE(p_query,'')),120),'');
  v_rows jsonb := '[]'::jsonb;
  v_member_count integer;
  v_invitation_count integer;
  v_match_count integer := 0;
  v_usage integer;
  v_limit_rows integer;
  v_limit jsonb;
  v_page_user_ids uuid[];
  v_page_invitation_ids uuid[];
BEGIN
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF v_view NOT IN ('members','invitations','summary') THEN
    RAISE EXCEPTION 'tenant_member_view_invalid' USING ERRCODE='22023';
  END IF;

  SELECT pg_catalog.count(*)::integer,
    pg_catalog.count(*) FILTER (WHERE m.access_state='active')::integer
    INTO v_member_count,v_usage
  FROM platform_core.tenant_memberships m WHERE m.tenant_id=p_tenant_id;
  SELECT pg_catalog.count(*)::integer INTO v_invitation_count
  FROM platform_core.tenant_member_invitations i WHERE i.tenant_id=p_tenant_id;
  SELECT pg_catalog.count(*)::integer,
    pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('mode',l.limit_mode,'value',l.limit_value))
    INTO v_limit_rows,v_limit
  FROM platform_core.tenant_capability_limits l
  WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.users'
    AND l.valid_from<=pg_catalog.transaction_timestamp()
    AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());
  IF v_limit_rows<>1 THEN RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000'; END IF;

  IF v_view='members' THEN
    IF v_query IS NULL THEN
      v_match_count := v_member_count;
      SELECT COALESCE(pg_catalog.array_agg(page.user_id ORDER BY page.created_at DESC,page.user_id DESC),ARRAY[]::uuid[])
        INTO v_page_user_ids
      FROM (
        SELECT m.user_id,m.created_at FROM platform_core.tenant_memberships m
        WHERE m.tenant_id=p_tenant_id ORDER BY m.created_at DESC,m.user_id DESC
        LIMIT 25 OFFSET (v_page-1)*25
      ) page;
    ELSE
      SELECT pg_catalog.count(*)::integer INTO v_match_count
      FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
      WHERE m.tenant_id=p_tenant_id AND pg_catalog.strpos(pg_catalog.lower(u.email),pg_catalog.lower(v_query))>0;
      SELECT COALESCE(pg_catalog.array_agg(page.user_id ORDER BY page.created_at DESC,page.user_id DESC),ARRAY[]::uuid[])
        INTO v_page_user_ids
      FROM (
        SELECT m.user_id,m.created_at
        FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
        WHERE m.tenant_id=p_tenant_id AND pg_catalog.strpos(pg_catalog.lower(u.email),pg_catalog.lower(v_query))>0
        ORDER BY m.created_at DESC,m.user_id DESC
        LIMIT 25 OFFSET (v_page-1)*25
      ) page;
    END IF;
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'user_id',m.user_id,'email',m.email,'access_state',m.access_state,
      'role_key',CASE WHEN pg_catalog.cardinality(roles.role_keys)=1 THEN roles.role_keys[1] ELSE NULL END,
      'roles',COALESCE(roles.roles,'[]'::jsonb),'protected_admin',COALESCE(roles.protected_admin,false)
    ) ORDER BY m.created_at DESC,m.user_id DESC),'[]'::jsonb) INTO v_rows
    FROM (
      SELECT memberships.tenant_id,memberships.user_id,memberships.access_state,memberships.created_at,u.email
      FROM platform_core.tenant_memberships memberships JOIN auth.users u ON u.id=memberships.user_id
      WHERE memberships.tenant_id=p_tenant_id AND memberships.user_id=ANY(v_page_user_ids)
    ) m LEFT JOIN LATERAL (
      SELECT pg_catalog.array_agg(r.role_key ORDER BY r.role_key,r.role_version) AS role_keys,
        pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('role_key',r.role_key,'role_version',r.role_version)
          ORDER BY r.role_key,r.role_version) AS roles,
        pg_catalog.bool_or(r.protects_tenant_admin) AS protected_admin
      FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r
        ON r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id
      WHERE mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id
    ) roles ON true;
  ELSIF v_view='invitations' THEN
    IF v_query IS NULL THEN
      v_match_count := v_invitation_count;
      SELECT COALESCE(pg_catalog.array_agg(page.id ORDER BY page.created_at DESC,page.id DESC),ARRAY[]::uuid[])
        INTO v_page_invitation_ids
      FROM (
        SELECT i.id,i.created_at FROM platform_core.tenant_member_invitations i
        WHERE i.tenant_id=p_tenant_id ORDER BY i.created_at DESC,i.id DESC
        LIMIT 25 OFFSET (v_page-1)*25
      ) page;
    ELSE
      SELECT pg_catalog.count(*)::integer INTO v_match_count
      FROM platform_core.tenant_member_invitations i
      WHERE i.tenant_id=p_tenant_id AND pg_catalog.strpos(pg_catalog.lower(i.target_email),pg_catalog.lower(v_query))>0;
      SELECT COALESCE(pg_catalog.array_agg(page.id ORDER BY page.created_at DESC,page.id DESC),ARRAY[]::uuid[])
        INTO v_page_invitation_ids
      FROM (
        SELECT i.id,i.created_at FROM platform_core.tenant_member_invitations i
        WHERE i.tenant_id=p_tenant_id AND pg_catalog.strpos(pg_catalog.lower(i.target_email),pg_catalog.lower(v_query))>0
        ORDER BY i.created_at DESC,i.id DESC
        LIMIT 25 OFFSET (v_page-1)*25
      ) page;
    END IF;
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',i.id,'target_email',i.target_email,
      'lifecycle_state',CASE WHEN i.lifecycle_state='pending' AND i.expires_at<=pg_catalog.now() THEN 'expired' ELSE i.lifecycle_state END,
      'delivery_state',i.delivery_state,'issuance',i.issuance,'expires_at',i.expires_at
    ) ORDER BY i.created_at DESC,i.id DESC),'[]'::jsonb) INTO v_rows
    FROM platform_core.tenant_member_invitations i
    WHERE i.tenant_id=p_tenant_id AND i.id=ANY(v_page_invitation_ids);
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'rows',v_rows,'view',v_view,'page',v_page,'page_size',25,'matching_count',v_match_count,
    'member_count',v_member_count,'invitation_count',v_invitation_count,
    'seat_usage',v_usage,'seat_limit',v_limit->0
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_member_access_page(uuid,text,integer,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_member_access_page(uuid,text,integer,text) TO authenticated;
