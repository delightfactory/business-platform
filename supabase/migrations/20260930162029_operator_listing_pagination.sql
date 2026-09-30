-- Keep the original list RPCs for existing clients; operator pages use bounded reads.
CREATE INDEX IF NOT EXISTS tenants_display_name_id_idx
  ON platform_core.tenants (display_name,id);
CREATE INDEX IF NOT EXISTS tenant_admin_invite_history_page_idx
  ON platform_core.tenant_admin_onboarding_intents (created_at DESC,id DESC);

CREATE FUNCTION public.platform_tenant_list_page(p_scope text,p_page integer DEFAULT 1,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_page integer := GREATEST(1,LEAST(COALESCE(p_page,1),100000));
  v_query text := NULLIF(pg_catalog.left(pg_catalog.btrim(COALESCE(p_query,'')),120),'');
  v_count integer;
  v_rows jsonb;
BEGIN
  IF p_scope='lifecycle' THEN
    IF NOT public.current_operator_can_manage_tenant_lifecycle() THEN
      RAISE EXCEPTION 'tenant_lifecycle_forbidden' USING ERRCODE='42501';
    END IF;
  ELSIF p_scope='commercial' THEN
    IF NOT public.current_operator_can_manage_commercial_access() THEN
      RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501';
    END IF;
  ELSE
    RAISE EXCEPTION 'operator_tenant_scope_invalid' USING ERRCODE='22023';
  END IF;

  SELECT pg_catalog.count(*)::integer INTO v_count
  FROM platform_core.tenants t
  WHERE v_query IS NULL OR pg_catalog.strpos(pg_catalog.lower(t.display_name),pg_catalog.lower(v_query))>0;
  WITH page_rows AS (
    SELECT t.id,t.display_name,t.lifecycle_state
    FROM platform_core.tenants t
    WHERE v_query IS NULL OR pg_catalog.strpos(pg_catalog.lower(t.display_name),pg_catalog.lower(v_query))>0
    ORDER BY t.display_name,t.id
    LIMIT 25 OFFSET (v_page-1)*25
  )
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'tenant_id',t.id,'display_name',t.display_name,'lifecycle_state',t.lifecycle_state
  ) ORDER BY t.display_name,t.id),'[]'::jsonb) INTO v_rows FROM page_rows t;
  RETURN pg_catalog.jsonb_build_object('rows',v_rows,'page',v_page,'page_size',25,'matching_count',v_count);
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_tenant_list_page(text,integer,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_list_page(text,integer,text) TO authenticated;

CREATE FUNCTION public.platform_tenant_lifecycle_get(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_tenant jsonb;
BEGIN
  IF NOT public.current_operator_can_manage_tenant_lifecycle() THEN
    RAISE EXCEPTION 'tenant_lifecycle_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object('tenant_id',t.id,'tenant_name',t.display_name,
    'lifecycle_state',t.lifecycle_state) INTO v_tenant
  FROM platform_core.tenants t WHERE t.id=p_tenant_id;
  RETURN v_tenant;
END;
$function$;
REVOKE ALL ON FUNCTION public.platform_tenant_lifecycle_get(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_lifecycle_get(uuid) TO authenticated;

CREATE FUNCTION public.tenant_admin_invitation_page(p_page integer DEFAULT 1,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_page integer := GREATEST(1,LEAST(COALESCE(p_page,1),100000));
  v_query text := NULLIF(pg_catalog.left(pg_catalog.btrim(COALESCE(p_query,'')),120),'');
  v_ids uuid[];
  v_count integer;
  v_rows jsonb;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_actor AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE='42501';
  END IF;

  SELECT pg_catalog.count(*)::integer INTO v_count
  FROM platform_core.tenant_admin_onboarding_intents i
  WHERE v_query IS NULL OR pg_catalog.strpos(pg_catalog.lower(i.target_email),pg_catalog.lower(v_query))>0
    OR pg_catalog.strpos(pg_catalog.lower(i.tenant_name),pg_catalog.lower(v_query))>0;
  SELECT COALESCE(pg_catalog.array_agg(p.id ORDER BY p.created_at DESC,p.id DESC),'{}'::uuid[]) INTO v_ids
  FROM (SELECT i.id,i.created_at FROM platform_core.tenant_admin_onboarding_intents i
    WHERE v_query IS NULL OR pg_catalog.strpos(pg_catalog.lower(i.target_email),pg_catalog.lower(v_query))>0
      OR pg_catalog.strpos(pg_catalog.lower(i.tenant_name),pg_catalog.lower(v_query))>0
    ORDER BY i.created_at DESC,i.id DESC LIMIT 25 OFFSET (v_page-1)*25) p;

  -- Expiry and its audit stay atomic, but only the displayed page is touched.
  WITH expired AS (
    UPDATE platform_core.tenant_admin_onboarding_intents i
    SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE i.id=ANY(v_ids) AND i.lifecycle_state='pending' AND i.expires_at<=pg_catalog.now()
    RETURNING i.id,i.issuance
  )
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_class,action,details)
  SELECT e.id,'system','expired',pg_catalog.jsonb_build_object('issuance',e.issuance) FROM expired e;

  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id',i.id,'target_email',i.target_email,'tenant_name',i.tenant_name,
    'lifecycle_state',i.lifecycle_state,'delivery_state',i.delivery_state,
    'issuance',i.issuance,'expires_at',i.expires_at,'created_by_operator_id',i.created_by_operator_id,
    'tenant_id',i.tenant_id
  ) ORDER BY i.created_at DESC,i.id DESC),'[]'::jsonb) INTO v_rows
  FROM platform_core.tenant_admin_onboarding_intents i WHERE i.id=ANY(v_ids);
  RETURN pg_catalog.jsonb_build_object('rows',v_rows,'page',v_page,'page_size',25,'matching_count',v_count);
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_admin_invitation_page(integer,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_admin_invitation_page(integer,text) TO authenticated;

CREATE FUNCTION public.tenant_admin_invitation_get(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_invitation jsonb;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS(SELECT 1 FROM platform_private.platform_operator_grants g JOIN auth.users u ON u.id=g.user_id
    WHERE g.user_id=v_actor AND g.is_active AND g.can_onboard_tenants AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'platform_operator_onboarding_forbidden' USING ERRCODE='42501';
  END IF;

  WITH expired AS (
    UPDATE platform_core.tenant_admin_onboarding_intents i
    SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE i.id=p_invitation_id AND i.lifecycle_state='pending' AND i.expires_at<=pg_catalog.now()
    RETURNING i.id,i.issuance
  )
  INSERT INTO platform_core.tenant_admin_invitation_audit(invitation_id,actor_class,action,details)
  SELECT e.id,'system','expired',pg_catalog.jsonb_build_object('issuance',e.issuance) FROM expired e;

  SELECT pg_catalog.jsonb_build_object('id',i.id,'target_email',i.target_email,'tenant_name',i.tenant_name,
    'lifecycle_state',i.lifecycle_state,'delivery_state',i.delivery_state,'issuance',i.issuance,
    'expires_at',i.expires_at,'created_by_operator_id',i.created_by_operator_id,'tenant_id',i.tenant_id)
    INTO v_invitation FROM platform_core.tenant_admin_onboarding_intents i WHERE i.id=p_invitation_id;
  RETURN v_invitation;
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_admin_invitation_get(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_admin_invitation_get(uuid) TO authenticated;
