-- Correction: audit employee import context without treating a client CSV line hint as verified provenance.
CREATE OR REPLACE FUNCTION public.confirm_people_workforce_import(p_tenant_id uuid,p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_preview jsonb; v_row jsonb; v_data jsonb;
  v_employee_id uuid; v_employment_id uuid; v_batch_id uuid := pg_catalog.gen_random_uuid(); v_count integer := 0;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage') THEN
    RAISE EXCEPTION 'people_import_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR pg_catalog.jsonb_typeof(p_rows)<>'array'
     OR pg_catalog.jsonb_array_length(p_rows) NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'people_import_payload_invalid' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.view')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'workforce_import.execute') THEN
    RAISE EXCEPTION 'people_import_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.people',pg_catalog.transaction_timestamp()) THEN
    RAISE EXCEPTION 'people_import_forbidden' USING ERRCODE='42501';
  END IF;
  v_preview := platform_private.validate_people_workforce_import(p_tenant_id,p_rows);
  IF EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements(v_preview) r WHERE (r->>'importable')<>'true') THEN
    RETURN pg_catalog.jsonb_build_object('state','stale','results',v_preview,'imported_count',0);
  END IF;
  BEGIN
    FOR v_row IN SELECT value FROM pg_catalog.jsonb_array_elements(v_preview) LOOP
      v_data := v_row->'data';
      INSERT INTO people.employees(tenant_id,employee_code,full_name,created_by_user_id)
        VALUES(p_tenant_id,v_data->>'employee_code',v_data->>'full_name',v_actor) RETURNING id INTO v_employee_id;
      INSERT INTO people.employments(tenant_id,employee_id,employer_entity_id,start_date,pay_basis,payroll_eligible)
        VALUES(p_tenant_id,v_employee_id,(v_data->>'employer_id')::uuid,(v_data->>'start_date_value')::date,
          v_data->>'pay_basis',(v_data->>'payroll_eligible_value')::boolean) RETURNING id INTO v_employment_id;
      INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,department_id,job_id,valid_from)
        VALUES(p_tenant_id,v_employment_id,(v_data->>'site_id')::uuid,
          NULLIF(v_data->>'department_id','')::uuid,NULLIF(v_data->>'job_id','')::uuid,(v_data->>'start_date_value')::date);
      INSERT INTO people.compensation_versions(tenant_id,employment_id,amount,valid_from)
        VALUES(p_tenant_id,v_employment_id,(v_data->>'amount_value')::numeric,(v_data->>'start_date_value')::date);
      INSERT INTO people.audit_events(tenant_id,employee_id,actor_user_id,event_key,details)
        VALUES(p_tenant_id,v_employee_id,v_actor,'employee.onboarded',pg_catalog.jsonb_build_object(
          'source','workforce_csv_import','import_batch_id',v_batch_id,
          'employment_id',v_employment_id,'employer_id',(v_data->>'employer_id')::uuid,'site_id',(v_data->>'site_id')::uuid,
          'start_date',(v_data->>'start_date_value')::date,'pay_basis',v_data->>'pay_basis',
          'payroll_eligible',(v_data->>'payroll_eligible_value')::boolean,
          'department_id',NULLIF(v_data->>'department_id','')::uuid,'job_id',NULLIF(v_data->>'job_id','')::uuid));
      v_count := v_count+1;
    END LOOP;
  EXCEPTION WHEN unique_violation THEN
    RETURN pg_catalog.jsonb_build_object('state','stale','imported_count',0,
      'message','تغيرت البيانات أثناء التأكيد؛ لم يُضف أي موظف. افحص الملف مرة أخرى.');
  WHEN foreign_key_violation OR check_violation OR exclusion_violation THEN
    RETURN pg_catalog.jsonb_build_object('state','stale','imported_count',0,
      'message','لم تعد بعض البيانات صالحة للتسجيل؛ لم يُضف أي موظف. افحص الملف مرة أخرى.');
  END;
  RETURN pg_catalog.jsonb_build_object('state','imported','imported_count',v_count,'import_batch_id',v_batch_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.confirm_people_workforce_import(uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.confirm_people_workforce_import(uuid,jsonb) TO authenticated;
