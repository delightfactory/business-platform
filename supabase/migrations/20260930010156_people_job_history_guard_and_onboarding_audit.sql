CREATE FUNCTION people.prevent_job_department_change_with_assignments() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  IF NEW.department_id IS DISTINCT FROM OLD.department_id AND EXISTS (
    SELECT 1 FROM people.work_assignments a
    WHERE a.tenant_id=OLD.tenant_id AND a.job_id=OLD.id
  ) THEN
    RAISE EXCEPTION 'people_org_job_department_in_use' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER jobs_department_history_guard BEFORE UPDATE OF department_id ON people.jobs
FOR EACH ROW EXECUTE FUNCTION people.prevent_job_department_change_with_assignments();
REVOKE ALL ON FUNCTION people.prevent_job_department_change_with_assignments() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.create_people_employee(p_tenant_id uuid,p_employee_code text,p_full_name text,
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
      'department_id',p_department_id,'job_id',p_job_id,
      'start_date',p_start_date,'pay_basis',p_pay_basis,'payroll_eligible',p_payroll_eligible));
  RETURN pg_catalog.jsonb_build_object('employee_id',v_employee_id,'employment_id',v_employment_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.create_people_employee(uuid,text,text,uuid,uuid,date,text,numeric,boolean,uuid,uuid)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.create_people_employee(uuid,text,text,uuid,uuid,date,text,numeric,boolean,uuid,uuid)
  TO authenticated;
