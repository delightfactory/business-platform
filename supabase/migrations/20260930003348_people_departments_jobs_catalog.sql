-- Cube 1 bounded People slice: tenant-owned department and job catalogs.
ALTER TABLE people.departments
  ADD COLUMN created_by_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  ADD COLUMN updated_by_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp();
ALTER TABLE people.jobs
  ADD COLUMN created_by_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  ADD COLUMN updated_by_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp();

CREATE INDEX departments_parent_idx ON people.departments(tenant_id,parent_id);
CREATE INDEX jobs_department_idx ON people.jobs(tenant_id,department_id);
REVOKE ALL ON TABLE people.departments,people.jobs FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE people.organization_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  subject_type text NOT NULL CHECK (subject_type IN ('department','job')),
  subject_id uuid NOT NULL,
  event_key text NOT NULL CHECK (event_key IN (
    'department.created','department.updated','department.deactivated','department.reactivated',
    'job.created','job.updated','job.deactivated','job.reactivated')),
  details jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CHECK ((subject_type='department' AND event_key LIKE 'department.%')
      OR (subject_type='job' AND event_key LIKE 'job.%'))
);
CREATE INDEX organization_audit_tenant_created_idx ON people.organization_audit_events(tenant_id,created_at DESC);
CREATE INDEX organization_audit_subject_idx ON people.organization_audit_events(tenant_id,subject_type,subject_id,created_at DESC);
ALTER TABLE people.organization_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.organization_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE people.organization_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION people.prevent_organization_audit_mutation() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'people_org_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER organization_audit_append_only BEFORE UPDATE OR DELETE ON people.organization_audit_events
FOR EACH ROW EXECUTE FUNCTION people.prevent_organization_audit_mutation();
REVOKE ALL ON FUNCTION people.prevent_organization_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.people_org_catalog(p_tenant_id uuid,p_kind text,p_query text DEFAULT NULL,p_page integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_query text := pg_catalog.btrim(COALESCE(p_query,''));
  v_items jsonb; v_has_more boolean;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_org_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN ('departments','jobs') OR pg_catalog.length(v_query)>100
     OR p_page IS NULL OR p_page NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'people_org_query_invalid' USING ERRCODE='22023';
  END IF;
  IF p_kind='departments' THEN
    WITH RECURSIVE hierarchy AS (
      SELECT d.id,d.parent_id,d.is_active,d.is_active AS effectively_active,ARRAY[d.id] AS path
      FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.parent_id IS NULL
      UNION ALL
      SELECT child.id,child.parent_id,child.is_active,
        child.is_active AND parent.effectively_active,parent.path || child.id
      FROM people.departments child JOIN hierarchy parent
        ON child.tenant_id=p_tenant_id AND child.parent_id=parent.id
      WHERE NOT child.id=ANY(parent.path)
    ), page_keys AS (
      SELECT d.id,d.code,d.name,d.parent_id,parent.name AS parent_name,d.is_active,
        COALESCE(h.effectively_active,false) AS effectively_active
      FROM people.departments d
      LEFT JOIN people.departments parent ON parent.tenant_id=d.tenant_id AND parent.id=d.parent_id
      LEFT JOIN hierarchy h ON h.id=d.id
      WHERE d.tenant_id=p_tenant_id AND (v_query='' OR pg_catalog.strpos(pg_catalog.lower(d.code),pg_catalog.lower(v_query))>0
        OR pg_catalog.strpos(pg_catalog.lower(d.name),pg_catalog.lower(v_query))>0)
      ORDER BY d.name,d.id LIMIT 26 OFFSET (p_page-1)*25
    ), page_rows AS (
      SELECT page_keys.*,pg_catalog.row_number() OVER (ORDER BY name,id) AS ordinal FROM page_keys
    )
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',id,'code',code,'name',name,
        'parent_id',parent_id,'parent_name',parent_name,'is_active',is_active,'effectively_active',effectively_active)
        ORDER BY name,id) FILTER (WHERE ordinal<=25),'[]'::jsonb),
      COALESCE(pg_catalog.bool_or(ordinal>25),false)
      INTO v_items,v_has_more FROM page_rows;
  ELSE
    WITH RECURSIVE hierarchy AS (
      SELECT d.id,d.parent_id,d.is_active,d.is_active AS effectively_active,ARRAY[d.id] AS path
      FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.parent_id IS NULL
      UNION ALL
      SELECT child.id,child.parent_id,child.is_active,
        child.is_active AND parent.effectively_active,parent.path || child.id
      FROM people.departments child JOIN hierarchy parent
        ON child.tenant_id=p_tenant_id AND child.parent_id=parent.id
      WHERE NOT child.id=ANY(parent.path)
    ), page_keys AS (
      SELECT j.id,j.code,j.name,j.department_id,d.name AS department_name,j.is_active,
        COALESCE(j.is_active AND (j.department_id IS NULL OR h.effectively_active),false) AS effectively_active
      FROM people.jobs j
      LEFT JOIN people.departments d ON d.tenant_id=j.tenant_id AND d.id=j.department_id
      LEFT JOIN hierarchy h ON h.id=j.department_id
      WHERE j.tenant_id=p_tenant_id AND (v_query='' OR pg_catalog.strpos(pg_catalog.lower(j.code),pg_catalog.lower(v_query))>0
        OR pg_catalog.strpos(pg_catalog.lower(j.name),pg_catalog.lower(v_query))>0)
      ORDER BY j.name,j.id LIMIT 26 OFFSET (p_page-1)*25
    ), page_rows AS (
      SELECT page_keys.*,pg_catalog.row_number() OVER (ORDER BY name,id) AS ordinal FROM page_keys
    )
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',id,'code',code,'name',name,
        'department_id',department_id,'department_name',department_name,'is_active',is_active,'effectively_active',effectively_active)
        ORDER BY name,id) FILTER (WHERE ordinal<=25),'[]'::jsonb),
      COALESCE(pg_catalog.bool_or(ordinal>25),false)
      INTO v_items,v_has_more FROM page_rows;
  END IF;
  RETURN pg_catalog.jsonb_build_object('items',v_items,'has_more',v_has_more,'page',p_page);
END;
$function$;
REVOKE ALL ON FUNCTION public.people_org_catalog(uuid,text,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_org_catalog(uuid,text,text,integer) TO authenticated;

CREATE FUNCTION public.people_org_catalog_options(p_tenant_id uuid,p_kind text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_items jsonb; v_truncated boolean;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_org_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN ('departments','jobs') THEN RAISE EXCEPTION 'people_org_query_invalid' USING ERRCODE='22023'; END IF;
  IF p_kind='departments' THEN
    WITH RECURSIVE hierarchy AS (
      SELECT d.id,d.parent_id,d.is_active,d.is_active AS effectively_active,ARRAY[d.id] AS path
      FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.parent_id IS NULL
      UNION ALL
      SELECT child.id,child.parent_id,child.is_active,child.is_active AND parent.effectively_active,parent.path || child.id
      FROM people.departments child JOIN hierarchy parent
        ON child.tenant_id=p_tenant_id AND child.parent_id=parent.id
      WHERE NOT child.id=ANY(parent.path)
    ), options AS (
      SELECT d.id,d.name,d.parent_id,d.is_active,COALESCE(h.effectively_active,false) AS effectively_active,
        pg_catalog.row_number() OVER (ORDER BY d.name,d.id) AS ordinal
      FROM (SELECT * FROM people.departments WHERE tenant_id=p_tenant_id ORDER BY name,id LIMIT 1001) d
      LEFT JOIN hierarchy h ON h.id=d.id
    )
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',id,'name',name,'parent_id',parent_id,
      'is_active',is_active,'effectively_active',effectively_active) ORDER BY name,id) FILTER (WHERE ordinal<=1000),'[]'::jsonb),
      COALESCE(pg_catalog.bool_or(ordinal>1000),false) INTO v_items,v_truncated FROM options;
  ELSE
    WITH RECURSIVE hierarchy AS (
      SELECT d.id,d.parent_id,d.is_active,d.is_active AS effectively_active,ARRAY[d.id] AS path
      FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.parent_id IS NULL
      UNION ALL
      SELECT child.id,child.parent_id,child.is_active,child.is_active AND parent.effectively_active,parent.path || child.id
      FROM people.departments child JOIN hierarchy parent
        ON child.tenant_id=p_tenant_id AND child.parent_id=parent.id
      WHERE NOT child.id=ANY(parent.path)
    ), options AS (
      SELECT j.id,j.name,j.department_id,j.is_active,
        j.is_active AND (j.department_id IS NULL OR COALESCE(h.effectively_active,false)) AS effectively_active,
        pg_catalog.row_number() OVER (ORDER BY j.name,j.id) AS ordinal
      FROM (SELECT * FROM people.jobs WHERE tenant_id=p_tenant_id ORDER BY name,id LIMIT 1001) j
      LEFT JOIN hierarchy h ON h.id=j.department_id
    )
    SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',id,'name',name,'department_id',department_id,
      'is_active',is_active,'effectively_active',effectively_active) ORDER BY name,id) FILTER (WHERE ordinal<=1000),'[]'::jsonb),
      COALESCE(pg_catalog.bool_or(ordinal>1000),false) INTO v_items,v_truncated FROM options;
  END IF;
  RETURN pg_catalog.jsonb_build_object('items',v_items,'truncated',v_truncated);
END;
$function$;
REVOKE ALL ON FUNCTION public.people_org_catalog_options(uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_org_catalog_options(uuid,text) TO authenticated;

CREATE FUNCTION public.people_org_catalog_record(p_tenant_id uuid,p_kind text,p_record_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_org_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_kind IS NULL THEN RAISE EXCEPTION 'people_org_query_invalid' USING ERRCODE='22023';
  ELSIF p_kind='departments' THEN
    SELECT pg_catalog.jsonb_build_object('id',d.id,'code',d.code,'name',d.name,'parent_id',d.parent_id,'is_active',d.is_active,
      'parent_name',parent.name)
      INTO v_result FROM people.departments d LEFT JOIN people.departments parent
        ON parent.tenant_id=d.tenant_id AND parent.id=d.parent_id
      WHERE d.tenant_id=p_tenant_id AND d.id=p_record_id;
  ELSIF p_kind='jobs' THEN
    SELECT pg_catalog.jsonb_build_object('id',j.id,'code',j.code,'name',j.name,'department_id',j.department_id,'is_active',j.is_active,
      'department_name',department.name)
      INTO v_result FROM people.jobs j LEFT JOIN people.departments department
        ON department.tenant_id=j.tenant_id AND department.id=j.department_id
      WHERE j.tenant_id=p_tenant_id AND j.id=p_record_id;
  ELSE RAISE EXCEPTION 'people_org_query_invalid' USING ERRCODE='22023';
  END IF;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_org_catalog_record(uuid,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_org_catalog_record(uuid,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.people_onboarding_options(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'people_onboard_forbidden' USING ERRCODE='42501';
  END IF;
  WITH RECURSIVE hierarchy AS (
    SELECT d.id,d.parent_id,d.is_active,d.is_active AS effectively_active,ARRAY[d.id] AS path
    FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.parent_id IS NULL
    UNION ALL
    SELECT child.id,child.parent_id,child.is_active,child.is_active AND parent.effectively_active,parent.path || child.id
    FROM people.departments child JOIN hierarchy parent
      ON child.tenant_id=p_tenant_id AND child.parent_id=parent.id
    WHERE NOT child.id=ANY(parent.path)
  )
  SELECT pg_catalog.jsonb_build_object(
    'employers',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',e.id,'name',e.display_name)
      ORDER BY e.is_default DESC,e.display_name) FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.is_active),'[]'::jsonb),
    'sites',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'name',s.display_name,'employer_id',s.legal_entity_id)
      ORDER BY s.is_default DESC,s.display_name) FROM platform_core.tenant_sites s
      WHERE s.tenant_id=p_tenant_id AND s.is_active),'[]'::jsonb),
    'departments',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',d.id,'name',d.name) ORDER BY d.name)
      FROM people.departments d JOIN hierarchy h ON h.id=d.id WHERE d.tenant_id=p_tenant_id AND h.effectively_active),'[]'::jsonb),
    'jobs',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',j.id,'name',j.name,'department_id',j.department_id)
      ORDER BY j.name) FROM people.jobs j LEFT JOIN hierarchy h ON h.id=j.department_id
      WHERE j.tenant_id=p_tenant_id AND j.is_active AND (j.department_id IS NULL OR h.effectively_active)),'[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_onboarding_options(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_onboarding_options(uuid) TO authenticated;

CREATE FUNCTION public.save_people_department(p_tenant_id uuid,p_department_id uuid,p_code text,p_name text,
  p_parent_id uuid,p_is_active boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_code text := pg_catalog.btrim(p_code); v_name text := pg_catalog.btrim(p_name);
  v_existing people.departments%ROWTYPE; v_id uuid; v_parent_available boolean := true; v_cycle boolean := false;
  v_event text; v_details jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage') THEN
    RAISE EXCEPTION 'people_org_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR p_is_active IS NULL OR v_code IS NULL OR pg_catalog.length(v_code) NOT BETWEEN 1 AND 40
     OR v_name IS NULL OR pg_catalog.length(v_name) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'people_org_input_invalid' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,0));
  IF p_department_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM people.departments WHERE tenant_id=p_tenant_id AND id=p_department_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'people_org_department_not_found' USING ERRCODE='P0002'; END IF;
  END IF;
  IF p_parent_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM people.departments WHERE tenant_id=p_tenant_id AND id=p_parent_id) THEN
      RAISE EXCEPTION 'people_org_parent_unavailable' USING ERRCODE='23503';
    END IF;
    IF p_parent_id=p_department_id THEN RAISE EXCEPTION 'people_org_department_cycle' USING ERRCODE='23514'; END IF;
    WITH RECURSIVE descendants(id,parent_id,path) AS (
      SELECT d.id,d.parent_id,ARRAY[d.id] FROM people.departments d
      WHERE d.tenant_id=p_tenant_id AND d.id=p_department_id
      UNION ALL
      SELECT child.id,child.parent_id,parent.path || child.id
      FROM people.departments child JOIN descendants parent
        ON child.tenant_id=p_tenant_id AND child.parent_id=parent.id
      WHERE NOT child.id=ANY(parent.path)
    ) SELECT COALESCE(pg_catalog.bool_or(id=p_parent_id),false) INTO v_cycle FROM descendants;
    IF v_cycle THEN RAISE EXCEPTION 'people_org_department_cycle' USING ERRCODE='23514'; END IF;
    WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
      SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
      WHERE d.tenant_id=p_tenant_id AND d.id=p_parent_id
      UNION ALL
      SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
      FROM people.departments parent JOIN ancestors chain
        ON parent.tenant_id=p_tenant_id AND parent.id=chain.parent_id
      WHERE NOT parent.id=ANY(chain.path)
    ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_parent_available FROM ancestors;
    IF NOT v_parent_available AND (p_department_id IS NULL OR p_parent_id IS DISTINCT FROM v_existing.parent_id
       OR (p_is_active AND NOT v_existing.is_active)) THEN
      RAISE EXCEPTION 'people_org_parent_unavailable' USING ERRCODE='23503';
    END IF;
  END IF;
  IF p_department_id IS NULL THEN
    INSERT INTO people.departments(tenant_id,code,name,parent_id,is_active,created_by_user_id,updated_by_user_id)
      VALUES(p_tenant_id,v_code,v_name,p_parent_id,p_is_active,v_actor,v_actor) RETURNING id INTO v_id;
    v_event := 'department.created';
    v_details := pg_catalog.jsonb_build_object('code',v_code,'name',v_name,'parent_id',p_parent_id,'is_active',p_is_active);
  ELSE
    IF v_existing.code=v_code AND v_existing.name=v_name AND v_existing.parent_id IS NOT DISTINCT FROM p_parent_id
       AND v_existing.is_active=p_is_active THEN
      RETURN pg_catalog.jsonb_build_object('id',p_department_id,'state','unchanged');
    END IF;
    UPDATE people.departments SET code=v_code,name=v_name,parent_id=p_parent_id,is_active=p_is_active,
      updated_by_user_id=v_actor,updated_at=pg_catalog.transaction_timestamp()
      WHERE tenant_id=p_tenant_id AND id=p_department_id;
    v_id := p_department_id;
    v_event := CASE WHEN v_existing.is_active AND NOT p_is_active THEN 'department.deactivated'
      WHEN NOT v_existing.is_active AND p_is_active THEN 'department.reactivated' ELSE 'department.updated' END;
    v_details := pg_catalog.jsonb_build_object('before',pg_catalog.jsonb_build_object('code',v_existing.code,'name',v_existing.name,
        'parent_id',v_existing.parent_id,'is_active',v_existing.is_active),
      'after',pg_catalog.jsonb_build_object('code',v_code,'name',v_name,'parent_id',p_parent_id,'is_active',p_is_active));
  END IF;
  INSERT INTO people.organization_audit_events(tenant_id,actor_user_id,subject_type,subject_id,event_key,details)
    VALUES(p_tenant_id,v_actor,'department',v_id,v_event,v_details);
  RETURN pg_catalog.jsonb_build_object('id',v_id,'state',pg_catalog.split_part(v_event,'.',2));
END;
$function$;
REVOKE ALL ON FUNCTION public.save_people_department(uuid,uuid,text,text,uuid,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_people_department(uuid,uuid,text,text,uuid,boolean) TO authenticated;

CREATE FUNCTION public.save_people_job(p_tenant_id uuid,p_job_id uuid,p_code text,p_name text,
  p_department_id uuid,p_is_active boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_code text := pg_catalog.btrim(p_code); v_name text := pg_catalog.btrim(p_name);
  v_existing people.jobs%ROWTYPE; v_id uuid; v_department_available boolean := true;
  v_event text; v_details jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage') THEN
    RAISE EXCEPTION 'people_org_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR p_is_active IS NULL OR v_code IS NULL OR pg_catalog.length(v_code) NOT BETWEEN 1 AND 40
     OR v_name IS NULL OR pg_catalog.length(v_name) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'people_org_input_invalid' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,0));
  IF p_job_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM people.jobs WHERE tenant_id=p_tenant_id AND id=p_job_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'people_org_job_not_found' USING ERRCODE='P0002'; END IF;
  END IF;
  IF p_department_id IS NOT NULL THEN
    WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
      SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
      WHERE d.tenant_id=p_tenant_id AND d.id=p_department_id
      UNION ALL
      SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
      FROM people.departments parent JOIN ancestors chain
        ON parent.tenant_id=p_tenant_id AND parent.id=chain.parent_id
      WHERE NOT parent.id=ANY(chain.path)
    ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_department_available FROM ancestors;
    IF NOT v_department_available AND (p_job_id IS NULL OR p_department_id IS DISTINCT FROM v_existing.department_id
       OR (p_is_active AND NOT v_existing.is_active)) THEN
      RAISE EXCEPTION 'people_org_department_unavailable' USING ERRCODE='23503';
    END IF;
  END IF;
  IF p_job_id IS NULL THEN
    INSERT INTO people.jobs(tenant_id,code,name,department_id,is_active,created_by_user_id,updated_by_user_id)
      VALUES(p_tenant_id,v_code,v_name,p_department_id,p_is_active,v_actor,v_actor) RETURNING id INTO v_id;
    v_event := 'job.created';
    v_details := pg_catalog.jsonb_build_object('code',v_code,'name',v_name,'department_id',p_department_id,'is_active',p_is_active);
  ELSE
    IF v_existing.code=v_code AND v_existing.name=v_name AND v_existing.department_id IS NOT DISTINCT FROM p_department_id
       AND v_existing.is_active=p_is_active THEN
      RETURN pg_catalog.jsonb_build_object('id',p_job_id,'state','unchanged');
    END IF;
    UPDATE people.jobs SET code=v_code,name=v_name,department_id=p_department_id,is_active=p_is_active,
      updated_by_user_id=v_actor,updated_at=pg_catalog.transaction_timestamp()
      WHERE tenant_id=p_tenant_id AND id=p_job_id;
    v_id := p_job_id;
    v_event := CASE WHEN v_existing.is_active AND NOT p_is_active THEN 'job.deactivated'
      WHEN NOT v_existing.is_active AND p_is_active THEN 'job.reactivated' ELSE 'job.updated' END;
    v_details := pg_catalog.jsonb_build_object('before',pg_catalog.jsonb_build_object('code',v_existing.code,'name',v_existing.name,
        'department_id',v_existing.department_id,'is_active',v_existing.is_active),
      'after',pg_catalog.jsonb_build_object('code',v_code,'name',v_name,'department_id',p_department_id,'is_active',p_is_active));
  END IF;
  INSERT INTO people.organization_audit_events(tenant_id,actor_user_id,subject_type,subject_id,event_key,details)
    VALUES(p_tenant_id,v_actor,'job',v_id,v_event,v_details);
  RETURN pg_catalog.jsonb_build_object('id',v_id,'state',pg_catalog.split_part(v_event,'.',2));
END;
$function$;
REVOKE ALL ON FUNCTION public.save_people_job(uuid,uuid,text,text,uuid,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_people_job(uuid,uuid,text,text,uuid,boolean) TO authenticated;

CREATE FUNCTION people.validate_work_assignment_catalog() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $function$
DECLARE v_department_available boolean; v_job people.jobs%ROWTYPE;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(NEW.tenant_id::text,0));
  IF NEW.department_id IS NOT NULL THEN
    WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
      SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
      WHERE d.tenant_id=NEW.tenant_id AND d.id=NEW.department_id
      UNION ALL
      SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
      FROM people.departments parent JOIN ancestors chain
        ON parent.tenant_id=NEW.tenant_id AND parent.id=chain.parent_id
      WHERE NOT parent.id=ANY(chain.path)
    ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_department_available FROM ancestors;
    IF NOT v_department_available THEN RAISE EXCEPTION 'people_assignment_department_unavailable' USING ERRCODE='23503'; END IF;
  END IF;
  IF NEW.job_id IS NOT NULL THEN
    SELECT * INTO v_job FROM people.jobs j WHERE j.tenant_id=NEW.tenant_id AND j.id=NEW.job_id;
    IF NOT FOUND OR NOT v_job.is_active THEN RAISE EXCEPTION 'people_assignment_job_unavailable' USING ERRCODE='23503'; END IF;
    IF v_job.department_id IS NOT NULL AND v_job.department_id IS DISTINCT FROM NEW.department_id THEN
      RAISE EXCEPTION 'people_assignment_job_department_mismatch' USING ERRCODE='23514';
    END IF;
    IF v_job.department_id IS NOT NULL THEN
      WITH RECURSIVE ancestors(id,parent_id,is_active,path) AS (
        SELECT d.id,d.parent_id,d.is_active,ARRAY[d.id] FROM people.departments d
        WHERE d.tenant_id=NEW.tenant_id AND d.id=v_job.department_id
        UNION ALL
        SELECT parent.id,parent.parent_id,parent.is_active,chain.path || parent.id
        FROM people.departments parent JOIN ancestors chain
          ON parent.tenant_id=NEW.tenant_id AND parent.id=chain.parent_id
        WHERE NOT parent.id=ANY(chain.path)
      ) SELECT COALESCE(pg_catalog.bool_and(is_active),false) INTO v_department_available FROM ancestors;
      IF NOT v_department_available THEN RAISE EXCEPTION 'people_assignment_job_unavailable' USING ERRCODE='23503'; END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER work_assignment_catalog_active BEFORE INSERT OR UPDATE ON people.work_assignments
FOR EACH ROW EXECUTE FUNCTION people.validate_work_assignment_catalog();
REVOKE ALL ON FUNCTION people.validate_work_assignment_catalog() FROM PUBLIC,anon,authenticated,service_role;
