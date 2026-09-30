-- Cube 1: optional Employee to existing Tenant User link.
CREATE TABLE people.employee_user_links (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  employee_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  linked_by_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  linked_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  unlinked_by_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  unlinked_at timestamptz,
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT,
  CHECK ((unlinked_at IS NULL AND unlinked_by_user_id IS NULL) OR
    (unlinked_at IS NOT NULL AND unlinked_by_user_id IS NOT NULL AND unlinked_at >= linked_at))
);
CREATE UNIQUE INDEX employee_user_links_one_employee_idx ON people.employee_user_links(tenant_id,employee_id) WHERE unlinked_at IS NULL;
CREATE UNIQUE INDEX employee_user_links_one_user_idx ON people.employee_user_links(tenant_id,user_id) WHERE unlinked_at IS NULL;
CREATE INDEX employee_user_links_history_idx ON people.employee_user_links(tenant_id,employee_id,linked_at DESC);
ALTER TABLE people.employee_user_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.employee_user_links FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE people.employee_user_link_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  employee_id uuid NOT NULL,
  link_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN ('employee.user_linked','employee.user_unlinked')),
  details jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,link_id) REFERENCES people.employee_user_links(tenant_id,id) ON DELETE RESTRICT
);
ALTER TABLE people.employee_user_link_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.employee_user_link_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE people.employee_user_link_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION people.prevent_employee_user_link_audit_mutation() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'people_employee_user_link_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER employee_user_link_audit_append_only BEFORE UPDATE OR DELETE ON people.employee_user_link_audit_events
FOR EACH ROW EXECUTE FUNCTION people.prevent_employee_user_link_audit_mutation();
REVOKE ALL ON FUNCTION people.prevent_employee_user_link_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.people_employee_user_link_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id) THEN
    RAISE EXCEPTION 'people_employee_unavailable' USING ERRCODE='P0002';
  END IF;
  SELECT pg_catalog.jsonb_build_object('linked',l.id IS NOT NULL,'link_id',l.id,'user_id',l.user_id,
    'email',u.email,'display_name',COALESCE(NULLIF(pg_catalog.btrim(u.raw_user_meta_data->>'full_name'),''),u.email),
    'linked_at',l.linked_at)
    INTO v_result
  FROM (SELECT 1) x
  LEFT JOIN people.employee_user_links l ON l.tenant_id=p_tenant_id AND l.employee_id=p_employee_id AND l.unlinked_at IS NULL
  LEFT JOIN auth.users u ON u.id=l.user_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_user_link_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_user_link_snapshot(uuid,uuid) TO authenticated;

CREATE FUNCTION public.people_employee_user_link_options(p_tenant_id uuid,p_employee_id uuid,p_query text DEFAULT '',p_page integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_query text := pg_catalog.left(pg_catalog.btrim(COALESCE(p_query,'')),100);
  v_page integer := pg_catalog.least(1000,pg_catalog.greatest(1,COALESCE(p_page,1))); v_rows jsonb; v_more boolean;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage') THEN
    RAISE EXCEPTION 'people_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id) THEN
    RAISE EXCEPTION 'people_employee_unavailable' USING ERRCODE='P0002';
  END IF;
  WITH candidates AS (
    SELECT m.user_id,u.email,COALESCE(NULLIF(pg_catalog.btrim(u.raw_user_meta_data->>'full_name'),''),u.email) AS display_name
    FROM platform_core.tenant_memberships m JOIN platform_core.tenants t ON t.id=m.tenant_id
    JOIN auth.users u ON u.id=m.user_id
    WHERE m.tenant_id=p_tenant_id AND m.access_state='active' AND t.lifecycle_state='active'
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND NOT EXISTS (SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id
        AND l.user_id=m.user_id AND l.unlinked_at IS NULL)
      AND (v_query='' OR u.email ILIKE '%'||v_query||'%' OR u.raw_user_meta_data->>'full_name' ILIKE '%'||v_query||'%')
    ORDER BY pg_catalog.lower(COALESCE(NULLIF(u.raw_user_meta_data->>'full_name',''),u.email)),m.user_id
    OFFSET (v_page-1)*50 LIMIT 51
  )
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('user_id',user_id,'email',email,'display_name',display_name)
    ORDER BY pg_catalog.lower(display_name),user_id) FILTER (WHERE ordinal<=50),'[]'::jsonb),
    COALESCE(pg_catalog.bool_or(ordinal>50),false)
    INTO v_rows,v_more FROM (SELECT *,pg_catalog.row_number() OVER (ORDER BY pg_catalog.lower(display_name),user_id) ordinal FROM candidates) q;
  RETURN pg_catalog.jsonb_build_object('items',v_rows,'page',v_page,'page_size',50,
    'has_more',v_more);
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_user_link_options(uuid,uuid,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_user_link_options(uuid,uuid,text,integer) TO authenticated;

CREATE FUNCTION public.link_people_employee_user(p_tenant_id uuid,p_employee_id uuid,p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_link_id uuid;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage') THEN
    RAISE EXCEPTION 'people_manage_forbidden' USING ERRCODE='42501';
  END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_unavailable' USING ERRCODE='P0002'; END IF;
  IF NOT EXISTS (SELECT 1 FROM platform_core.tenant_memberships m JOIN platform_core.tenants t ON t.id=m.tenant_id
    JOIN auth.users u ON u.id=m.user_id WHERE m.tenant_id=p_tenant_id AND m.user_id=p_user_id
      AND m.access_state='active' AND t.lifecycle_state='active' AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'people_link_member_unavailable' USING ERRCODE='23503';
  END IF;
  IF EXISTS (SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id AND l.employee_id=p_employee_id AND l.unlinked_at IS NULL) THEN
    RAISE EXCEPTION 'people_employee_already_linked' USING ERRCODE='23505';
  END IF;
  IF EXISTS (SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id AND l.user_id=p_user_id AND l.unlinked_at IS NULL) THEN
    RAISE EXCEPTION 'people_user_already_linked' USING ERRCODE='23505';
  END IF;
  INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
    VALUES(p_tenant_id,p_employee_id,p_user_id,v_actor) RETURNING id INTO v_link_id;
  INSERT INTO people.employee_user_link_audit_events(tenant_id,employee_id,link_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_employee_id,v_link_id,v_actor,'employee.user_linked',pg_catalog.jsonb_build_object('user_id',p_user_id));
  RETURN pg_catalog.jsonb_build_object('state','linked','link_id',v_link_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.link_people_employee_user(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.link_people_employee_user(uuid,uuid,uuid) TO authenticated;

CREATE FUNCTION public.unlink_people_employee_user(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_link people.employee_user_links%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage') THEN
    RAISE EXCEPTION 'people_manage_forbidden' USING ERRCODE='42501';
  END IF;
  PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_unavailable' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_link FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id
    AND l.employee_id=p_employee_id AND l.unlinked_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_not_linked' USING ERRCODE='P0002'; END IF;
  UPDATE people.employee_user_links SET unlinked_at=pg_catalog.transaction_timestamp(),unlinked_by_user_id=v_actor
    WHERE tenant_id=p_tenant_id AND id=v_link.id;
  INSERT INTO people.employee_user_link_audit_events(tenant_id,employee_id,link_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_employee_id,v_link.id,v_actor,'employee.user_unlinked',pg_catalog.jsonb_build_object('user_id',v_link.user_id));
  RETURN pg_catalog.jsonb_build_object('state','unlinked','link_id',v_link.id);
END;
$function$;
REVOKE ALL ON FUNCTION public.unlink_people_employee_user(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.unlink_people_employee_user(uuid,uuid) TO authenticated;
