-- Cube 1, slice 1: atomic employee onboarding and permission-separated reading.
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;
CREATE SCHEMA people;
REVOKE ALL ON SCHEMA people FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE people.employees (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  employee_code text NOT NULL CHECK (employee_code = pg_catalog.btrim(employee_code) AND pg_catalog.length(employee_code) BETWEEN 1 AND 40),
  full_name text NOT NULL CHECK (full_name = pg_catalog.btrim(full_name) AND pg_catalog.length(full_name) BETWEEN 2 AND 160),
  workforce_status text NOT NULL DEFAULT 'active' CHECK (workforce_status IN ('active','inactive','ended')),
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id,id)
);
CREATE UNIQUE INDEX employees_code_per_tenant_idx ON people.employees(tenant_id, pg_catalog.lower(employee_code));

CREATE TABLE people.departments (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  code text NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(code)) BETWEEN 1 AND 40),
  name text NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(name)) BETWEEN 1 AND 160),
  parent_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,parent_id) REFERENCES people.departments(tenant_id,id) ON DELETE RESTRICT,
  CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE UNIQUE INDEX departments_code_per_tenant_idx ON people.departments(tenant_id,pg_catalog.lower(code));

CREATE TABLE people.jobs (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  code text NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(code)) BETWEEN 1 AND 40),
  name text NOT NULL CHECK (pg_catalog.length(pg_catalog.btrim(name)) BETWEEN 1 AND 160),
  department_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,department_id) REFERENCES people.departments(tenant_id,id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX jobs_code_per_tenant_idx ON people.jobs(tenant_id,pg_catalog.lower(code));

CREATE TABLE people.employments (
  tenant_id uuid NOT NULL,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  employee_id uuid NOT NULL,
  employer_entity_id uuid NOT NULL,
  start_date date NOT NULL,
  end_date date,
  employment_status text NOT NULL DEFAULT 'active' CHECK (employment_status IN ('active','ended')),
  pay_basis text NOT NULL CHECK (pay_basis IN ('monthly','daily')),
  payroll_eligible boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,employer_entity_id) REFERENCES platform_core.tenant_legal_entities(tenant_id,id) ON DELETE RESTRICT,
  CHECK (end_date IS NULL OR end_date >= start_date),
  CHECK ((employment_status='active' AND end_date IS NULL) OR (employment_status='ended' AND end_date IS NOT NULL)),
  CONSTRAINT employee_employment_no_overlap EXCLUDE USING gist (
    tenant_id WITH =, employee_id WITH =,
    pg_catalog.daterange(start_date, end_date + 1, '[)') WITH &&
  )
);
CREATE INDEX employments_employee_idx ON people.employments(tenant_id,employee_id,start_date DESC);

CREATE TABLE people.work_assignments (
  tenant_id uuid NOT NULL,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  employment_id uuid NOT NULL,
  site_id uuid NOT NULL,
  department_id uuid,
  job_id uuid,
  manager_employee_id uuid,
  valid_from date NOT NULL,
  valid_until date,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,employment_id) REFERENCES people.employments(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,site_id) REFERENCES platform_core.tenant_sites(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,department_id) REFERENCES people.departments(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,job_id) REFERENCES people.jobs(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,manager_employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT,
  CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT work_assignment_no_overlap EXCLUDE USING gist (
    tenant_id WITH =, employment_id WITH =,
    pg_catalog.daterange(valid_from,valid_until,'[)') WITH &&
  )
);
CREATE INDEX work_assignments_employment_idx ON people.work_assignments(tenant_id,employment_id,valid_from DESC);

CREATE TABLE people.compensation_versions (
  tenant_id uuid NOT NULL,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  employment_id uuid NOT NULL,
  amount numeric(14,2) NOT NULL CHECK (amount >= 0),
  currency_code text NOT NULL DEFAULT 'EGP' CHECK (currency_code='EGP'),
  valid_from date NOT NULL,
  valid_until date,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  PRIMARY KEY (tenant_id,id),
  FOREIGN KEY (tenant_id,employment_id) REFERENCES people.employments(tenant_id,id) ON DELETE RESTRICT,
  CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT compensation_no_overlap EXCLUDE USING gist (
    tenant_id WITH =, employment_id WITH =,
    pg_catalog.daterange(valid_from,valid_until,'[)') WITH &&
  )
);
CREATE INDEX compensation_employment_idx ON people.compensation_versions(tenant_id,employment_id,valid_from DESC);

CREATE TABLE people.audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  employee_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN ('employee.onboarded')),
  details jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT
);
CREATE FUNCTION people.prevent_audit_mutation() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'people_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER people_audit_append_only BEFORE UPDATE OR DELETE ON people.audit_events
FOR EACH ROW EXECUTE FUNCTION people.prevent_audit_mutation();

ALTER TABLE people.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.employments ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.work_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.compensation_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA people FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA people FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION people.prevent_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION platform_private.has_people_permission(p_tenant_id uuid,p_user_id uuid,p_permission text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT p_permission IN ('people.view','people.manage','employment.manage','compensation.view',
      'compensation.manage','org_context.manage','workforce_import.execute')
    AND platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.people',pg_catalog.transaction_timestamp())
    AND (platform_private.has_tenant_permission(p_tenant_id,p_user_id,p_permission)
      OR platform_private.has_tenant_permission(p_tenant_id,p_user_id,'tenant.administer'));
$function$;
REVOKE ALL ON FUNCTION platform_private.has_people_permission(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.people_access_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid());
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  RETURN pg_catalog.jsonb_build_object(
    'can_view',true,
    'can_manage',platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage'),
    'can_manage_employment',platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage'),
    'can_view_compensation',platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.view'),
    'can_manage_compensation',platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage'),
    'can_manage_org',platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage'),
    'can_import',platform_private.has_people_permission(p_tenant_id,v_actor,'workforce_import.execute'));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_access_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_access_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.people_onboarding_options(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'people_onboard_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object(
    'employers',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',e.id,'name',e.display_name)
      ORDER BY e.is_default DESC,e.display_name) FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant_id AND e.is_active),'[]'::jsonb),
    'sites',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',s.id,'name',s.display_name,
      'employer_id',s.legal_entity_id) ORDER BY s.is_default DESC,s.display_name)
      FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.is_active),'[]'::jsonb),
    'departments',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',d.id,'name',d.name)
      ORDER BY d.name) FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.is_active),'[]'::jsonb),
    'jobs',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',j.id,'name',j.name,
      'department_id',j.department_id) ORDER BY j.name) FROM people.jobs j
      WHERE j.tenant_id=p_tenant_id AND j.is_active),'[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_onboarding_options(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_onboarding_options(uuid) TO authenticated;

CREATE FUNCTION public.people_directory(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id',e.id,'code',e.employee_code,'name',e.full_name,
    'status',CASE WHEN e.workforce_status='active' AND emp.start_date>
      pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date
      THEN 'scheduled' ELSE e.workforce_status END,
    'employer',le.display_name,'site',s.display_name,'start_date',emp.start_date
  ) ORDER BY e.full_name,e.id),'[]'::jsonb) INTO v_result
  FROM people.employees e
  LEFT JOIN LATERAL (SELECT * FROM people.employments current_emp WHERE current_emp.tenant_id=e.tenant_id
    AND current_emp.employee_id=e.id AND current_emp.employment_status='active'
    ORDER BY current_emp.start_date DESC LIMIT 1) emp ON true
  LEFT JOIN platform_core.tenant_legal_entities le ON le.tenant_id=emp.tenant_id AND le.id=emp.employer_entity_id
  LEFT JOIN LATERAL (SELECT * FROM people.work_assignments a WHERE a.tenant_id=emp.tenant_id
    AND a.employment_id=emp.id
    AND a.valid_from<=pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date
    AND (a.valid_until IS NULL OR a.valid_until>pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date)
    ORDER BY a.valid_from DESC LIMIT 1) assignment ON true
  LEFT JOIN platform_core.tenant_sites s ON s.tenant_id=assignment.tenant_id AND s.id=assignment.site_id
  WHERE e.tenant_id=p_tenant_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_directory(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_directory(uuid) TO authenticated;

CREATE FUNCTION public.people_employee_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object(
    'id',e.id,'code',e.employee_code,'name',e.full_name,
    'status',CASE WHEN e.workforce_status='active' AND emp.start_date>
      pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date
      THEN 'scheduled' ELSE e.workforce_status END,
    'can_manage',platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage'),
    'employment',CASE WHEN emp.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object(
      'id',emp.id,'employer_id',emp.employer_entity_id,'employer',le.display_name,
      'start_date',emp.start_date,'end_date',emp.end_date,'status',emp.employment_status) END,
    'assignment',CASE WHEN a.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object(
      'id',a.id,'site_id',a.site_id,'site',s.display_name,
      'department',d.name,'job',j.name,'valid_from',a.valid_from,'valid_until',a.valid_until) END
  ) INTO v_result
  FROM people.employees e
  LEFT JOIN LATERAL (SELECT * FROM people.employments x WHERE x.tenant_id=e.tenant_id
    AND x.employee_id=e.id ORDER BY x.start_date DESC LIMIT 1) emp ON true
  LEFT JOIN platform_core.tenant_legal_entities le ON le.tenant_id=emp.tenant_id AND le.id=emp.employer_entity_id
  LEFT JOIN LATERAL (SELECT * FROM people.work_assignments x WHERE x.tenant_id=emp.tenant_id
    AND x.employment_id=emp.id ORDER BY x.valid_from DESC LIMIT 1) a ON true
  LEFT JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id
  LEFT JOIN people.departments d ON d.tenant_id=a.tenant_id AND d.id=a.department_id
  LEFT JOIN people.jobs j ON j.tenant_id=a.tenant_id AND j.id=a.job_id
  WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_snapshot(uuid,uuid) TO authenticated;

CREATE FUNCTION public.people_compensation_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.view') THEN
    RAISE EXCEPTION 'compensation_view_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object('amount',c.amount,'currency',c.currency_code,
    'valid_from',c.valid_from,'valid_until',c.valid_until,'pay_basis',emp.pay_basis)
    INTO v_result
  FROM people.employees e
  JOIN people.employments emp ON emp.tenant_id=e.tenant_id AND emp.employee_id=e.id
  JOIN people.compensation_versions c ON c.tenant_id=emp.tenant_id AND c.employment_id=emp.id
  WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id
  ORDER BY emp.start_date DESC,c.valid_from DESC LIMIT 1;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.people_compensation_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_compensation_snapshot(uuid,uuid) TO authenticated;

CREATE FUNCTION public.create_people_employee(p_tenant_id uuid,p_employee_code text,p_full_name text,
  p_employer_entity_id uuid,p_site_id uuid,p_start_date date,p_pay_basis text,p_base_amount numeric,
  p_payroll_eligible boolean,p_department_id uuid DEFAULT NULL,p_job_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_employee_id uuid; v_employment_id uuid;
  v_code text := pg_catalog.btrim(p_employee_code); v_name text := pg_catalog.btrim(p_full_name);
  v_site_employer uuid;
BEGIN
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'people_onboard_forbidden' USING ERRCODE='42501';
  END IF;
  IF v_code IS NULL OR pg_catalog.length(v_code) NOT BETWEEN 1 AND 40
     OR v_name IS NULL OR pg_catalog.length(v_name) NOT BETWEEN 2 AND 160
     OR p_start_date IS NULL OR p_pay_basis IS NULL OR p_pay_basis NOT IN ('monthly','daily')
     OR p_base_amount IS NULL OR p_base_amount < 0 OR p_base_amount > 999999999999.99
     OR p_payroll_eligible IS NULL THEN
    RAISE EXCEPTION 'people_onboard_invalid' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM platform_core.tenant_legal_entities e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employer_entity_id AND e.is_active) THEN
    RAISE EXCEPTION 'people_employer_unavailable' USING ERRCODE='23503';
  END IF;
  SELECT s.legal_entity_id INTO v_site_employer FROM platform_core.tenant_sites s
    WHERE s.tenant_id=p_tenant_id AND s.id=p_site_id AND s.is_active;
  IF v_site_employer IS NULL OR v_site_employer<>p_employer_entity_id THEN
    RAISE EXCEPTION 'people_site_unavailable' USING ERRCODE='23503';
  END IF;
  IF p_department_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM people.departments d
    WHERE d.tenant_id=p_tenant_id AND d.id=p_department_id AND d.is_active) THEN
    RAISE EXCEPTION 'people_department_unavailable' USING ERRCODE='23503';
  END IF;
  IF p_job_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM people.jobs j
    WHERE j.tenant_id=p_tenant_id AND j.id=p_job_id AND j.is_active
      AND (j.department_id IS NULL OR j.department_id=p_department_id)) THEN
    RAISE EXCEPTION 'people_job_unavailable' USING ERRCODE='23503';
  END IF;
  INSERT INTO people.employees(tenant_id,employee_code,full_name,created_by_user_id)
    VALUES(p_tenant_id,v_code,v_name,v_actor) RETURNING id INTO v_employee_id;
  INSERT INTO people.employments(tenant_id,employee_id,employer_entity_id,start_date,pay_basis,payroll_eligible)
    VALUES(p_tenant_id,v_employee_id,p_employer_entity_id,p_start_date,p_pay_basis,p_payroll_eligible)
    RETURNING id INTO v_employment_id;
  INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,department_id,job_id,valid_from)
    VALUES(p_tenant_id,v_employment_id,p_site_id,p_department_id,p_job_id,p_start_date);
  INSERT INTO people.compensation_versions(tenant_id,employment_id,amount,valid_from)
    VALUES(p_tenant_id,v_employment_id,p_base_amount,p_start_date);
  INSERT INTO people.audit_events(tenant_id,employee_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,v_employee_id,v_actor,'employee.onboarded',pg_catalog.jsonb_build_object(
      'employment_id',v_employment_id,'employer_id',p_employer_entity_id,'site_id',p_site_id,
      'start_date',p_start_date,'pay_basis',p_pay_basis,'payroll_eligible',p_payroll_eligible));
  RETURN pg_catalog.jsonb_build_object('employee_id',v_employee_id,'employment_id',v_employment_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.create_people_employee(uuid,text,text,uuid,uuid,date,text,numeric,boolean,uuid,uuid)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.create_people_employee(uuid,text,text,uuid,uuid,date,text,numeric,boolean,uuid,uuid)
  TO authenticated;
