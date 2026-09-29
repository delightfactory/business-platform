ALTER TABLE platform_core.tenant_legal_entities
  ADD COLUMN legal_name text,
  ADD CONSTRAINT tenant_legal_entity_legal_name_shape
    CHECK (legal_name IS NULL OR (pg_catalog.btrim(legal_name)<>'' AND pg_catalog.length(legal_name)<=200)),
  ADD CONSTRAINT tenant_legal_entity_default_must_be_active CHECK (NOT is_default OR is_active);
ALTER TABLE platform_core.tenant_sites
  ADD CONSTRAINT tenant_site_default_must_be_active CHECK (NOT is_default OR is_active);

CREATE TABLE platform_core.tenant_entities_sites_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  resource_type text NOT NULL CHECK(resource_type IN ('legal_entity','site')),
  resource_id uuid NOT NULL,
  action text NOT NULL CHECK(action IN ('created','updated','default_changed','deactivated','reactivated')),
  before_state jsonb,
  after_state jsonb NOT NULL,
  reason text NOT NULL CHECK(pg_catalog.btrim(reason)<>'' AND pg_catalog.length(reason)<=500),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp()
);
ALTER TABLE platform_core.tenant_entities_sites_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_entities_sites_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE platform_core.tenant_entities_sites_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX tenant_entities_sites_audit_tenant_time_idx
  ON platform_core.tenant_entities_sites_audit_events(tenant_id,created_at DESC);

CREATE FUNCTION platform_core.prevent_tenant_entities_sites_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'Tenant identity and Site audit events are append-only' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION platform_core.prevent_tenant_entities_sites_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER tenant_entities_sites_audit_append_only
BEFORE UPDATE OR DELETE ON platform_core.tenant_entities_sites_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_tenant_entities_sites_audit_mutation();

CREATE FUNCTION public.tenant_entities_sites_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_site_limit jsonb;
  v_limit_count integer;
  v_result jsonb;
  v_can_entities boolean := platform_private.has_tenant_permission(p_tenant_id,(SELECT auth.uid()),'tenant.legal_entities.manage');
  v_can_sites boolean := platform_private.has_tenant_permission(p_tenant_id,(SELECT auth.uid()),'tenant.sites.manage');
BEGIN
  IF NOT v_can_entities AND NOT v_can_sites THEN
    RAISE EXCEPTION 'tenant_entities_sites_forbidden' USING ERRCODE='42501';
  END IF;

  SELECT pg_catalog.count(*)::integer INTO v_limit_count
  FROM platform_core.tenant_capability_limits l
  WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.sites' AND l.limit_key='max_sites'
    AND l.valid_from<=pg_catalog.transaction_timestamp()
    AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());
  IF v_limit_count<>1 THEN RAISE EXCEPTION 'tenant_sites_limit_unavailable' USING ERRCODE='55000'; END IF;
  SELECT pg_catalog.jsonb_build_object('mode',l.limit_mode,'value',l.limit_value) INTO v_site_limit
  FROM platform_core.tenant_capability_limits l
  WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.sites' AND l.limit_key='max_sites'
    AND l.valid_from<=pg_catalog.transaction_timestamp()
    AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());

  SELECT pg_catalog.jsonb_build_object(
    'tenant_id',t.id,'tenant_name',t.display_name,
    'site_limit',v_site_limit,
    'can_manage_legal_entities',v_can_entities,'can_manage_sites',v_can_sites,
    'site_usage',(SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_sites s WHERE s.tenant_id=t.id AND s.is_active),
    'entities',COALESCE((
      SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',e.id,'display_name',e.display_name,'legal_name',CASE WHEN v_can_entities THEN e.legal_name ELSE NULL END,
        'is_active',e.is_active,'is_default',e.is_default,
        'active_site_count',(SELECT pg_catalog.count(*)::integer FROM platform_core.tenant_sites active_site
          WHERE active_site.tenant_id=e.tenant_id AND active_site.legal_entity_id=e.id AND active_site.is_active),
        'sites',CASE WHEN v_can_sites THEN COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id',s.id,'display_name',s.display_name,'is_active',s.is_active,'is_default',s.is_default
        ) ORDER BY s.is_default DESC,s.display_name,s.id) FROM platform_core.tenant_sites s
          WHERE s.tenant_id=e.tenant_id AND s.legal_entity_id=e.id),'[]'::jsonb) ELSE '[]'::jsonb END
      ) ORDER BY e.is_default DESC,e.display_name,e.id)
      FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=t.id
    ),'[]'::jsonb)
  ) INTO v_result
  FROM platform_core.tenants t WHERE t.id=p_tenant_id AND t.lifecycle_state='active';
  IF v_result IS NULL THEN RAISE EXCEPTION 'tenant_entities_sites_unavailable' USING ERRCODE='P0002'; END IF;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_entities_sites_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_entities_sites_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.manage_tenant_legal_entity(
  p_tenant_id uuid,p_action text,p_entity_id uuid,p_display_name text,p_legal_name text,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action));
  v_display text := NULLIF(pg_catalog.btrim(p_display_name),'');
  v_legal text := NULLIF(pg_catalog.btrim(p_legal_name),'');
  v_reason text := NULLIF(pg_catalog.btrim(p_reason),'');
  v_before jsonb; v_after jsonb; v_entity uuid; v_current_display text; v_current_legal text;
  v_is_active boolean; v_is_default boolean;
  v_previous_default uuid; v_make_default boolean;
BEGIN
  IF p_tenant_id IS NULL OR v_action IS NULL OR v_action NOT IN ('create','update','default','deactivate','reactivate') THEN
    RAISE EXCEPTION 'tenant_legal_entity_input_invalid' USING ERRCODE='22023';
  END IF;
  IF v_reason IS NULL OR pg_catalog.length(v_reason)>500 THEN RAISE EXCEPTION 'tenant_identity_reason_required' USING ERRCODE='22023'; END IF;
  IF v_action IN ('create','update') AND (v_display IS NULL OR pg_catalog.length(v_display)>160 OR (v_legal IS NOT NULL AND pg_catalog.length(v_legal)>200)) THEN
    RAISE EXCEPTION 'tenant_legal_entity_name_invalid' USING ERRCODE='22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.legal_entities.manage') THEN
    RAISE EXCEPTION 'tenant_legal_entities_manage_forbidden' USING ERRCODE='42501';
  END IF;

  IF v_action='create' THEN
    SELECT NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.is_active AND e.is_default) INTO v_make_default;
    INSERT INTO platform_core.tenant_legal_entities(tenant_id,display_name,legal_name,is_default)
      VALUES(p_tenant_id,v_display,v_legal,v_make_default) RETURNING id INTO v_entity;
    v_after:=pg_catalog.jsonb_build_object('display_name',v_display,'legal_name',v_legal,'is_active',true,'is_default',v_make_default);
    INSERT INTO platform_core.tenant_entities_sites_audit_events(tenant_id,actor_user_id,resource_type,resource_id,action,before_state,after_state,reason)
      VALUES(p_tenant_id,v_actor,'legal_entity',v_entity,'created',NULL,v_after,v_reason);
    RETURN pg_catalog.jsonb_build_object('state','created','entity_id',v_entity);
  END IF;

  SELECT display_name,legal_name,is_active,is_default INTO v_current_display,v_current_legal,v_is_active,v_is_default
  FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant_id AND id=p_entity_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_legal_entity_not_found' USING ERRCODE='P0002'; END IF;
  v_entity:=p_entity_id;
  v_before:=pg_catalog.jsonb_build_object('display_name',v_current_display,'legal_name',v_current_legal,'is_active',v_is_active,'is_default',v_is_default);

  IF v_action='update' THEN
    IF v_current_display IS NOT DISTINCT FROM v_display AND v_current_legal IS NOT DISTINCT FROM v_legal THEN
      RETURN pg_catalog.jsonb_build_object('state','unchanged','entity_id',v_entity);
    END IF;
    UPDATE platform_core.tenant_legal_entities SET display_name=v_display,legal_name=v_legal
    WHERE tenant_id=p_tenant_id AND id=v_entity;
    v_after:=pg_catalog.jsonb_build_object('display_name',v_display,'legal_name',v_legal,'is_active',v_is_active,'is_default',v_is_default);
  ELSIF v_action='default' THEN
    IF NOT v_is_active THEN RAISE EXCEPTION 'tenant_legal_entity_inactive' USING ERRCODE='23514'; END IF;
    IF v_is_default THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','entity_id',v_entity); END IF;
    SELECT id INTO v_previous_default FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant_id AND is_default;
    UPDATE platform_core.tenant_legal_entities SET is_default=false WHERE tenant_id=p_tenant_id AND is_default;
    UPDATE platform_core.tenant_legal_entities SET is_default=true WHERE tenant_id=p_tenant_id AND id=v_entity;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_default',true,'previous_default_id',v_previous_default);
  ELSIF v_action='deactivate' THEN
    IF NOT v_is_active THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','entity_id',v_entity); END IF;
    IF EXISTS(SELECT 1 FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.legal_entity_id=v_entity AND s.is_active) THEN
      RAISE EXCEPTION 'tenant_legal_entity_has_active_sites' USING ERRCODE='23514';
    END IF;
    UPDATE platform_core.tenant_legal_entities SET is_active=false,is_default=false WHERE tenant_id=p_tenant_id AND id=v_entity;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_active',false,'is_default',false);
  ELSE
    IF v_is_active THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','entity_id',v_entity); END IF;
    SELECT NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.is_active AND e.is_default) INTO v_make_default;
    UPDATE platform_core.tenant_legal_entities SET is_active=true,is_default=v_make_default WHERE tenant_id=p_tenant_id AND id=v_entity;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_active',true,'is_default',v_make_default);
  END IF;

  INSERT INTO platform_core.tenant_entities_sites_audit_events(tenant_id,actor_user_id,resource_type,resource_id,action,before_state,after_state,reason)
  VALUES(p_tenant_id,v_actor,'legal_entity',v_entity,
    CASE WHEN v_action='update' THEN 'updated' WHEN v_action='default' THEN 'default_changed' WHEN v_action='deactivate' THEN 'deactivated' ELSE 'reactivated' END,
    v_before,v_after,v_reason);
  RETURN pg_catalog.jsonb_build_object('state',CASE WHEN v_action='update' THEN 'updated' ELSE v_action END,'entity_id',v_entity);
END;
$function$;
REVOKE ALL ON FUNCTION public.manage_tenant_legal_entity(uuid,text,uuid,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.manage_tenant_legal_entity(uuid,text,uuid,text,text,text) TO authenticated;

CREATE FUNCTION public.manage_tenant_site(
  p_tenant_id uuid,p_action text,p_site_id uuid,p_legal_entity_id uuid,p_display_name text,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_actor uuid := (SELECT auth.uid());
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action));
  v_display text := NULLIF(pg_catalog.btrim(p_display_name),'');
  v_reason text := NULLIF(pg_catalog.btrim(p_reason),'');
  v_site uuid; v_current_entity uuid; v_current_display text; v_is_active boolean; v_is_default boolean;
  v_limit_mode text; v_limit_value integer; v_limit_count integer; v_usage integer;
  v_before jsonb; v_after jsonb;
  v_previous_default uuid; v_make_default boolean;
BEGIN
  IF p_tenant_id IS NULL OR v_action IS NULL OR v_action NOT IN ('create','update','default','deactivate','reactivate') THEN
    RAISE EXCEPTION 'tenant_site_input_invalid' USING ERRCODE='22023';
  END IF;
  IF v_action<>'create' AND p_legal_entity_id IS NOT NULL THEN
    RAISE EXCEPTION 'tenant_site_move_not_supported' USING ERRCODE='0A000';
  END IF;
  IF v_reason IS NULL OR pg_catalog.length(v_reason)>500 THEN RAISE EXCEPTION 'tenant_identity_reason_required' USING ERRCODE='22023'; END IF;
  IF v_action IN ('create','update') AND (v_display IS NULL OR pg_catalog.length(v_display)>160) THEN
    RAISE EXCEPTION 'tenant_site_name_invalid' USING ERRCODE='22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.sites.manage') THEN
    RAISE EXCEPTION 'tenant_sites_manage_forbidden' USING ERRCODE='42501';
  END IF;

  IF v_action='create' THEN
    IF p_legal_entity_id IS NULL OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.id=p_legal_entity_id AND e.is_active) THEN
      RAISE EXCEPTION 'tenant_site_entity_unavailable' USING ERRCODE='23503';
    END IF;
    SELECT count(*)::integer,pg_catalog.max(l.limit_mode),pg_catalog.max(l.limit_value)
      INTO v_limit_count,v_limit_mode,v_limit_value
    FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.sites' AND l.limit_key='max_sites'
      AND l.valid_from<=pg_catalog.transaction_timestamp()
      AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());
    IF v_limit_count<>1 OR v_limit_mode NOT IN ('limited','unlimited') THEN RAISE EXCEPTION 'tenant_sites_limit_unavailable' USING ERRCODE='55000'; END IF;
    SELECT count(*)::integer INTO v_usage FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active;
    IF v_limit_mode='limited' AND v_usage>=v_limit_value THEN RAISE EXCEPTION 'tenant_sites_capacity_reached' USING ERRCODE='23514'; END IF;
    SELECT NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active AND s.is_default)
      INTO v_make_default;
    INSERT INTO platform_core.tenant_sites(tenant_id,legal_entity_id,display_name,is_default)
    VALUES(p_tenant_id,p_legal_entity_id,v_display,v_make_default) RETURNING id INTO v_site;
    v_after:=pg_catalog.jsonb_build_object('legal_entity_id',p_legal_entity_id,'display_name',v_display,'is_active',true,'is_default',v_make_default);
    INSERT INTO platform_core.tenant_entities_sites_audit_events(tenant_id,actor_user_id,resource_type,resource_id,action,before_state,after_state,reason)
    VALUES(p_tenant_id,v_actor,'site',v_site,'created',NULL,v_after,v_reason);
    RETURN pg_catalog.jsonb_build_object('state','created','site_id',v_site);
  END IF;

  SELECT legal_entity_id,display_name,is_active,is_default INTO v_current_entity,v_current_display,v_is_active,v_is_default
  FROM platform_core.tenant_sites WHERE tenant_id=p_tenant_id AND id=p_site_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_site_not_found' USING ERRCODE='P0002'; END IF;
  v_site:=p_site_id;
  v_before:=pg_catalog.jsonb_build_object('legal_entity_id',v_current_entity,'display_name',v_current_display,'is_active',v_is_active,'is_default',v_is_default);

  IF v_action='update' THEN
    IF v_display IS NOT DISTINCT FROM v_current_display THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    UPDATE platform_core.tenant_sites SET display_name=v_display WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('display_name',v_display);
  ELSIF v_action='default' THEN
    IF NOT v_is_active OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.id=v_current_entity AND e.is_active) THEN
      RAISE EXCEPTION 'tenant_site_inactive' USING ERRCODE='23514';
    END IF;
    IF v_is_default THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    SELECT id INTO v_previous_default FROM platform_core.tenant_sites WHERE tenant_id=p_tenant_id AND is_default;
    UPDATE platform_core.tenant_sites SET is_default=false WHERE tenant_id=p_tenant_id AND is_default;
    UPDATE platform_core.tenant_sites SET is_default=true WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_default',true,'previous_default_id',v_previous_default);
  ELSIF v_action='deactivate' THEN
    IF NOT v_is_active THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    UPDATE platform_core.tenant_sites SET is_active=false,is_default=false WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_active',false,'is_default',false);
  ELSE
    IF v_is_active THEN RETURN pg_catalog.jsonb_build_object('state','unchanged','site_id',v_site); END IF;
    IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.id=v_current_entity AND e.is_active) THEN
      RAISE EXCEPTION 'tenant_site_entity_unavailable' USING ERRCODE='23503';
    END IF;
    SELECT count(*)::integer,pg_catalog.max(l.limit_mode),pg_catalog.max(l.limit_value)
      INTO v_limit_count,v_limit_mode,v_limit_value
    FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.sites' AND l.limit_key='max_sites'
      AND l.valid_from<=pg_catalog.transaction_timestamp()
      AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());
    IF v_limit_count<>1 OR v_limit_mode NOT IN ('limited','unlimited') THEN RAISE EXCEPTION 'tenant_sites_limit_unavailable' USING ERRCODE='55000'; END IF;
    SELECT count(*)::integer INTO v_usage FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active;
    IF v_limit_mode='limited' AND v_usage>=v_limit_value THEN RAISE EXCEPTION 'tenant_sites_capacity_reached' USING ERRCODE='23514'; END IF;
    SELECT NOT EXISTS(SELECT 1 FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active AND s.is_default)
      INTO v_make_default;
    UPDATE platform_core.tenant_sites SET is_active=true,is_default=v_make_default WHERE tenant_id=p_tenant_id AND id=v_site;
    v_after:=v_before || pg_catalog.jsonb_build_object('is_active',true,'is_default',v_make_default);
  END IF;

  INSERT INTO platform_core.tenant_entities_sites_audit_events(tenant_id,actor_user_id,resource_type,resource_id,action,before_state,after_state,reason)
  VALUES(p_tenant_id,v_actor,'site',v_site,
    CASE WHEN v_action='update' THEN 'updated' WHEN v_action='default' THEN 'default_changed' WHEN v_action='deactivate' THEN 'deactivated' ELSE 'reactivated' END,
    v_before,v_after,v_reason);
  RETURN pg_catalog.jsonb_build_object('state',CASE WHEN v_action='update' THEN 'updated' ELSE v_action END,'site_id',v_site);
END;
$function$;
REVOKE ALL ON FUNCTION public.manage_tenant_site(uuid,text,uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.manage_tenant_site(uuid,text,uuid,uuid,text,text) TO authenticated;
