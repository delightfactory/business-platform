-- Cube 1 bounded CSV import: validate in tenant scope, then insert all selected
-- employees and their initial work/pay context in one transaction.
CREATE FUNCTION platform_private.validate_people_workforce_import(p_tenant_id uuid,p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_row jsonb; v_other jsonb; v_result jsonb := '[]'::jsonb; v_data jsonb;
  v_index integer := 0; v_row_number integer; v_code text; v_name text; v_employer_name text;
  v_site_name text; v_start_text text; v_start_date date; v_pay_basis text; v_amount_text text;
  v_amount numeric; v_payroll_text text; v_payroll_eligible boolean; v_department_code text; v_job_code text;
  v_employer_id uuid; v_site_id uuid; v_department_id uuid; v_job_id uuid;
  v_employer_count integer; v_site_count integer; v_department_count integer; v_job_count integer;
  v_warning text[]; v_errors text[]; v_duplicate boolean; v_formula boolean;
BEGIN
  IF p_tenant_id IS NULL OR pg_catalog.jsonb_typeof(p_rows) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'people_import_payload_invalid' USING ERRCODE='22023';
  END IF;
  IF pg_catalog.jsonb_array_length(p_rows) NOT BETWEEN 1 AND 100 OR pg_catalog.octet_length(p_rows::text)>1048576 THEN
    RAISE EXCEPTION 'people_import_payload_invalid' USING ERRCODE='22023';
  END IF;
  FOR v_row IN SELECT value FROM pg_catalog.jsonb_array_elements(p_rows) LOOP
    v_index := v_index + 1;
    v_row_number := CASE WHEN pg_catalog.pg_input_is_valid(v_row->>'source_row_number','integer')
      THEN (v_row->>'source_row_number')::integer ELSE v_index+1 END;
    v_row_number := CASE WHEN v_row_number<2 THEN 2 WHEN v_row_number>10001 THEN 10001 ELSE v_row_number END;
    v_code := pg_catalog.btrim(COALESCE(v_row->>'employee_code',''));
    v_name := pg_catalog.btrim(COALESCE(v_row->>'full_name',''));
    v_employer_name := pg_catalog.btrim(COALESCE(v_row->>'employer_name',''));
    v_site_name := pg_catalog.btrim(COALESCE(v_row->>'site_name',''));
    v_start_text := pg_catalog.btrim(COALESCE(v_row->>'start_date',''));
    v_pay_basis := pg_catalog.lower(pg_catalog.btrim(COALESCE(v_row->>'pay_basis','')));
    v_amount_text := pg_catalog.btrim(COALESCE(v_row->>'base_amount',''));
    v_payroll_text := pg_catalog.lower(pg_catalog.btrim(COALESCE(v_row->>'payroll_eligible','')));
    v_department_code := pg_catalog.btrim(COALESCE(v_row->>'department_code',''));
    v_job_code := pg_catalog.btrim(COALESCE(v_row->>'job_code',''));
    v_errors := ARRAY[]::text[]; v_warning := ARRAY[]::text[];
    v_employer_id := NULL; v_site_id := NULL; v_department_id := NULL; v_job_id := NULL;
    v_start_date := NULL; v_amount := NULL; v_payroll_eligible := NULL;

    IF pg_catalog.jsonb_typeof(v_row)<>'object' THEN
      v_errors := ARRAY['تعذر قراءة الصف؛ راجع بنية ملف CSV.'];
    ELSE
      SELECT EXISTS (SELECT 1 FROM pg_catalog.jsonb_each_text(v_row) f
        WHERE f.value ~ '^[[:space:]]*[=+@-]') INTO v_formula;
      IF v_formula THEN v_errors := pg_catalog.array_append(v_errors,'يحتوي الصف على قيمة قد تُفسر كصيغة؛ أزل علامة الصيغة وأعد الفحص.'); END IF;
      IF v_code='' OR pg_catalog.length(v_code)>40 THEN v_errors := pg_catalog.array_append(v_errors,'رمز الموظف مطلوب وبحد أقصى 40 حرفًا.'); END IF;
      IF v_name='' OR pg_catalog.length(v_name)<2 OR pg_catalog.length(v_name)>160 THEN v_errors := pg_catalog.array_append(v_errors,'اسم الموظف مطلوب وبحد أقصى 160 حرفًا.'); END IF;
      IF v_start_text !~ '^\d{4}-\d{2}-\d{2}$' OR NOT pg_catalog.pg_input_is_valid(v_start_text,'date') THEN
        v_errors := pg_catalog.array_append(v_errors,'تاريخ بداية العمل غير صالح؛ استخدم YYYY-MM-DD.');
      ELSE v_start_date := v_start_text::date; END IF;
      IF v_pay_basis NOT IN ('monthly','daily') THEN v_errors := pg_catalog.array_append(v_errors,'طريقة الأجر يجب أن تكون monthly أو daily.'); END IF;
      IF v_amount_text !~ '^\d{1,12}(\.\d{1,2})?$' OR NOT pg_catalog.pg_input_is_valid(v_amount_text,'numeric') THEN
        v_errors := pg_catalog.array_append(v_errors,'الأجر الأساسي يجب أن يكون رقمًا غير سالب وبحد أقصى منزلتين عشريتين.');
      ELSE
        v_amount := v_amount_text::numeric;
        IF v_amount<0 OR v_amount>999999999999.99 THEN v_errors := pg_catalog.array_append(v_errors,'الأجر الأساسي خارج النطاق المسموح.'); END IF;
      END IF;
      IF v_payroll_text NOT IN ('true','false','yes','no','1','0') THEN
        v_errors := pg_catalog.array_append(v_errors,'قيمة إدراج الموظف في الرواتب يجب أن تكون true أو false.');
      ELSE v_payroll_eligible := v_payroll_text IN ('true','yes','1'); END IF;

      IF v_code<>'' THEN
        SELECT EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements(p_rows) WITH ORDINALITY AS x(value,ordinality)
          WHERE x.ordinality<>v_index AND pg_catalog.lower(pg_catalog.btrim(COALESCE(x.value->>'employee_code','')))=pg_catalog.lower(v_code))
          INTO v_duplicate;
        IF v_duplicate THEN v_errors := pg_catalog.array_append(v_errors,'رمز الموظف مكرر داخل الملف.'); END IF;
        IF EXISTS (SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND pg_catalog.lower(e.employee_code)=pg_catalog.lower(v_code)) THEN
          v_errors := pg_catalog.array_append(v_errors,'رمز الموظف مسجل بالفعل في هذه الشركة.');
        END IF;
      END IF;

      IF v_employer_name='' THEN
        SELECT pg_catalog.count(*)::integer,(pg_catalog.array_agg(e.id))[1] INTO v_employer_count,v_employer_id
        FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=p_tenant_id AND e.is_active;
        IF v_employer_count=1 THEN v_warning := pg_catalog.array_append(v_warning,'اختيرت جهة التوظيف النشطة الوحيدة تلقائيًا.');
        ELSE v_errors := pg_catalog.array_append(v_errors,'حدد اسم جهة التوظيف؛ لا توجد جهة نشطة واحدة يمكن اختيارها تلقائيًا.'); END IF;
      ELSE
        SELECT pg_catalog.count(*)::integer,(pg_catalog.array_agg(e.id))[1] INTO v_employer_count,v_employer_id
        FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=p_tenant_id AND e.is_active
          AND pg_catalog.lower(pg_catalog.btrim(e.display_name))=pg_catalog.lower(v_employer_name);
        IF v_employer_count<>1 THEN v_employer_id:=NULL; v_errors := pg_catalog.array_append(v_errors,'جهة التوظيف غير نشطة أو غير معروفة أو اسمها غير فريد.'); END IF;
      END IF;

      IF v_site_name='' THEN
        IF v_employer_id IS NOT NULL THEN
          SELECT pg_catalog.count(*)::integer,(pg_catalog.array_agg(s.id))[1] INTO v_site_count,v_site_id
          FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.legal_entity_id=v_employer_id AND s.is_active;
          IF v_site_count=1 THEN v_warning := pg_catalog.array_append(v_warning,'اختير الفرع النشط الوحيد لجهة التوظيف تلقائيًا.');
          ELSE v_errors := pg_catalog.array_append(v_errors,'حدد اسم الفرع؛ لا يوجد فرع نشط واحد يمكن اختياره تلقائيًا.'); END IF;
        ELSE v_errors := pg_catalog.array_append(v_errors,'تعذر تحديد الفرع قبل اختيار جهة التوظيف.'); END IF;
      ELSIF v_employer_id IS NOT NULL THEN
        SELECT pg_catalog.count(*)::integer,(pg_catalog.array_agg(s.id))[1] INTO v_site_count,v_site_id
        FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant_id AND s.legal_entity_id=v_employer_id AND s.is_active
          AND pg_catalog.lower(pg_catalog.btrim(s.display_name))=pg_catalog.lower(v_site_name);
        IF v_site_count<>1 THEN v_site_id:=NULL; v_errors := pg_catalog.array_append(v_errors,'الفرع غير نشط أو لا يتبع جهة التوظيف أو اسمه غير فريد.'); END IF;
      END IF;

      IF v_department_code<>'' THEN
        WITH RECURSIVE hierarchy AS (
          SELECT d.id,d.parent_id,d.is_active AS effective,ARRAY[d.id] AS path
          FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.parent_id IS NULL
          UNION ALL
          SELECT c.id,c.parent_id,c.is_active AND h.effective,h.path||c.id
          FROM people.departments c JOIN hierarchy h ON c.tenant_id=p_tenant_id AND c.parent_id=h.id
          WHERE NOT c.id=ANY(h.path)
        ) SELECT pg_catalog.count(*)::integer,(pg_catalog.array_agg(d.id))[1] INTO v_department_count,v_department_id
          FROM people.departments d JOIN hierarchy h ON h.id=d.id AND h.effective
          WHERE d.tenant_id=p_tenant_id AND d.is_active AND pg_catalog.lower(d.code)=pg_catalog.lower(v_department_code);
        IF v_department_count<>1 THEN v_department_id:=NULL; v_errors := pg_catalog.array_append(v_errors,'رمز القسم غير معروف أو غير نشط.'); END IF;
      END IF;

      IF v_job_code<>'' THEN
        WITH RECURSIVE hierarchy AS (
          SELECT d.id,d.parent_id,d.is_active AS effective,ARRAY[d.id] AS path
          FROM people.departments d WHERE d.tenant_id=p_tenant_id AND d.parent_id IS NULL
          UNION ALL
          SELECT c.id,c.parent_id,c.is_active AND h.effective,h.path||c.id
          FROM people.departments c JOIN hierarchy h ON c.tenant_id=p_tenant_id AND c.parent_id=h.id
          WHERE NOT c.id=ANY(h.path)
        ) SELECT pg_catalog.count(*)::integer,(pg_catalog.array_agg(j.id))[1] INTO v_job_count,v_job_id
          FROM people.jobs j LEFT JOIN hierarchy h ON h.id=j.department_id
          WHERE j.tenant_id=p_tenant_id AND j.is_active AND pg_catalog.lower(j.code)=pg_catalog.lower(v_job_code)
            AND (j.department_id IS NULL OR COALESCE(h.effective,false));
        IF v_job_count<>1 THEN v_job_id:=NULL; v_errors := pg_catalog.array_append(v_errors,'رمز الوظيفة غير معروف أو غير نشط.');
        ELSIF NOT EXISTS (SELECT 1 FROM people.jobs j WHERE j.tenant_id=p_tenant_id AND j.id=v_job_id
            AND (j.department_id IS NULL OR j.department_id=v_department_id)) THEN
          v_job_id:=NULL; v_errors := pg_catalog.array_append(v_errors,'الوظيفة لا تتبع القسم المحدد.');
        END IF;
      END IF;
    END IF;

    v_data := pg_catalog.jsonb_build_object('source_row_number',v_row_number,'employee_code',v_code,'full_name',v_name,
      'employer_name',v_employer_name,'site_name',v_site_name,'start_date',v_start_text,'pay_basis',v_pay_basis,
      'base_amount',v_amount_text,'payroll_eligible',v_payroll_text,'department_code',v_department_code,'job_code',v_job_code,
      'employer_id',v_employer_id,'site_id',v_site_id,'department_id',v_department_id,'job_id',v_job_id,
      'start_date_value',v_start_date,'amount_value',v_amount,'payroll_eligible_value',v_payroll_eligible);
    v_result := v_result || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'source_row_number',v_row_number,'employee_code',v_code,'full_name',v_name,
      'status',CASE WHEN pg_catalog.cardinality(v_errors)>0 THEN 'rejected'
        WHEN pg_catalog.cardinality(v_warning)>0 THEN 'warning' ELSE 'ready' END,
      'importable',pg_catalog.cardinality(v_errors)=0,'errors',to_jsonb(v_errors),'warnings',to_jsonb(v_warning),'data',v_data));
  END LOOP;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION platform_private.validate_people_workforce_import(uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.preview_people_workforce_import(p_tenant_id uuid,p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid());
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.view')
    OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'workforce_import.execute') THEN
    RAISE EXCEPTION 'people_import_forbidden' USING ERRCODE='42501';
  END IF;
  RETURN platform_private.validate_people_workforce_import(p_tenant_id,p_rows);
END;
$function$;
REVOKE ALL ON FUNCTION public.preview_people_workforce_import(uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.preview_people_workforce_import(uuid,jsonb) TO authenticated;

CREATE FUNCTION public.confirm_people_workforce_import(p_tenant_id uuid,p_rows jsonb)
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
