-- CSV confirmation and unassigned evidence attachment both call the resolver below.
-- Materializing imports lock Employment before reading effective Assignment.
-- Employment termination keeps its Employee serialization lock, but NO KEY UPDATE
-- is compatible with the Employee foreign-key KEY SHARE acquired by WI inserts.
CREATE OR REPLACE FUNCTION time.attendance_import_resolve_row(p_tenant uuid,p_row jsonb,p_create_instance boolean,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE v_employee_id uuid; v_employee_code text; v_employee_name text; v_site_id uuid; v_site_name text; site_count integer;
 event_key text; direction text; identity_employee_id uuid; identity_site_id uuid; happened_at timestamptz; happened_text text; fingerprint text;
 prior time.manual_punches%ROWTYPE; pending time.unassigned_attendance_evidence%ROWTYPE; attach_id text; candidate record; candidate_count integer; instance time.work_instances%ROWTYPE; instance_id uuid;
 starts timestamptz; ends timestamptz; attr_start timestamptz; attr_end timestamptz;
BEGIN
 IF jsonb_typeof(p_row)<>'object' THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('بيانات الصف غير صالحة.')); END IF;
 v_employee_code:=btrim(coalesce(p_row->>'employee_code','')); v_site_name:=btrim(coalesce(p_row->>'site_name',''));
 identity_employee_id:=NULLIF(p_row->>'identity_employee_id','')::uuid; identity_site_id:=NULLIF(p_row->>'identity_site_id','')::uuid;
 event_key:=btrim(coalesce(p_row->>'source_event_key','')); direction:=lower(btrim(coalesce(p_row->>'direction','')));
 happened_text:=btrim(coalesce(p_row->>'happened_at',''));
 IF identity_employee_id IS NOT NULL OR identity_site_id IS NOT NULL THEN
   IF coalesce(current_setting('time.unassigned_attach_id',true),'')='' OR NOT EXISTS(
     SELECT 1 FROM time.unassigned_attendance_evidence e WHERE e.tenant_id=p_tenant
       AND e.id=current_setting('time.unassigned_attach_id',true)::uuid
       AND e.employee_id=identity_employee_id AND e.site_id=identity_site_id AND e.source_event_key=event_key
   ) THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تعذر التحقق من هوية مصدر التسجيل.')); END IF;
 END IF;
 IF (identity_employee_id IS NULL AND (v_employee_code='' OR length(v_employee_code)>64)) OR (identity_site_id IS NULL AND (v_site_name='' OR length(v_site_name)>160))
    OR event_key='' OR length(event_key)>160 OR direction NOT IN('in','out')
    OR happened_text !~ '^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:?\d{2})$' THEN
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تحقق من رمز الموظف والفرع والاتجاه ومفتاح الحدث، واكتب الوقت مع فرق توقيت مثل +02:00.'));
 END IF;
 BEGIN happened_at:=happened_text::timestamptz;
 EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('صيغة التاريخ أو فرق التوقيت غير صالح. استخدم تاريخًا ووقتًا واضحين.')); END;
 IF happened_at>transaction_timestamp()+interval '5 minutes' THEN
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('لا يمكن استيراد تسجيل يقع في المستقبل.'));
 END IF;
 IF identity_employee_id IS NOT NULL THEN
   SELECT e.id,e.employee_code,e.full_name INTO v_employee_id,v_employee_code,v_employee_name FROM people.employees e WHERE e.tenant_id=p_tenant AND e.id=identity_employee_id;
   IF NOT FOUND THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('الموظف الأصلي لم يعد موجودًا في هذه الشركة.')); END IF;
 ELSE
   SELECT count(*)::integer,(array_agg(e.id ORDER BY e.id))[1],min(e.employee_code),min(e.full_name) INTO candidate_count,v_employee_id,v_employee_code,v_employee_name
   FROM people.employees e WHERE e.tenant_id=p_tenant AND e.employee_code=btrim(coalesce(p_row->>'employee_code',''));
   IF candidate_count=0 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('رمز الموظف غير موجود في هذه الشركة.')); END IF;
   IF candidate_count<>1 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('رمز الموظف غير محدد؛ اطلب مراجعة دليل الموظفين.')); END IF;
 END IF;
 IF identity_site_id IS NOT NULL THEN
   SELECT s.id,s.display_name INTO v_site_id,v_site_name FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant AND s.id=identity_site_id AND s.is_active;
   IF NOT FOUND THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('الفرع الأصلي لم يعد نشطًا في هذه الشركة.')); END IF;
 ELSE
   SELECT count(*)::integer,(array_agg(s.id ORDER BY s.id))[1],min(s.display_name) INTO site_count,v_site_id,v_site_name
   FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant AND s.is_active
     AND lower(btrim(s.display_name))=lower(btrim(coalesce(p_row->>'site_name','')));
   IF site_count=0 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('اسم الفرع غير موجود أو غير نشط في هذه الشركة.')); END IF;
   IF site_count<>1 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('اسم الفرع مكرر؛ استخدم فرعًا باسم فريد ثم أعد الفحص.')); END IF;
 END IF;
 fingerprint:=md5(concat_ws(chr(31),v_employee_id::text,v_site_id::text,direction,happened_at::text));
 SELECT * INTO prior FROM time.manual_punches p WHERE p.tenant_id=p_tenant AND p.source_event_key=event_key;
 IF FOUND THEN
   IF prior.payload_fingerprint=fingerprint THEN
     RETURN jsonb_build_object('status','duplicate','errors','[]'::jsonb,'warnings',jsonb_build_array('هذا الحدث مسجل مسبقًا؛ لن يتكرر.'));
   END IF;
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('مفتاح الحدث مستخدم لوقت أو موظف مختلف. راجع مصدر الملف.'));
 END IF;

 SELECT * INTO pending FROM time.unassigned_attendance_evidence e WHERE e.tenant_id=p_tenant AND e.source_event_key=event_key;
 IF FOUND AND coalesce(current_setting('time.unassigned_attach_id',true),'')<>pending.id::text THEN
   IF pending.payload_fingerprint=fingerprint THEN RETURN jsonb_build_object('status','duplicate','errors','[]'::jsonb,'warnings',jsonb_build_array('هذا الحدث محفوظ في قائمة التسجيلات بلا تكليف؛ استخدم المراجعة لربطه بعد إصلاح التكليف.'));
   ELSE RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('مفتاح الحدث محفوظ لتسجيل مختلف في قائمة المراجعة.'));
   END IF;
 END IF;

 -- Only materializing calls need a lock. Lock before reading effective Assignment,
 -- matching attendance_open_day and all supported People Assignment mutations.
 IF p_create_instance THEN
   PERFORM 1 FROM people.employments e
     WHERE e.tenant_id=p_tenant AND e.employee_id=v_employee_id
     ORDER BY e.start_date,e.id FOR UPDATE;
 END IF;
 WITH op_dates AS (
   SELECT ((happened_at AT TIME ZONE 'UTC')::date+n)::date operational_date FROM generate_series(-2,1) n
 ), scheduled AS (
   SELECT a.id assignment_id,a.employment_id,a.site_id,emp.employee_id,
     coalesce(o.policy_template_id,a.work_policy_template_id) policy_id,
     coalesce(o.policy_version,a.work_policy_version) policy_version,d.operational_date,
     v.timezone_name,v.schedule_kind,v.work_days,v.shift_start,v.shift_end,v.ends_next_day,
     v.break_minutes,v.required_minutes,v.earliest_punch,v.latest_punch,
     v.attribution_before_minutes,v.attribution_after_minutes,v.lateness_grace_minutes,v.early_leave_grace_minutes,
     CASE WHEN v.schedule_kind='fixed' THEN time.resolve_local(d.operational_date+v.shift_start,v.timezone_name)
       ELSE time.resolve_local(d.operational_date+coalesce(v.earliest_punch,'00:00:00'::time),v.timezone_name) END expected_start,
     CASE WHEN v.schedule_kind='fixed' THEN time.resolve_local((d.operational_date+CASE WHEN v.ends_next_day THEN 1 ELSE 0 END)+v.shift_end,v.timezone_name)
       ELSE time.resolve_local(d.operational_date+coalesce(v.latest_punch,'23:59:59'::time),v.timezone_name) END expected_end
   FROM op_dates d JOIN people.work_assignments a ON a.tenant_id=p_tenant AND d.operational_date>=a.valid_from AND (a.valid_until IS NULL OR d.operational_date<a.valid_until)
   JOIN people.employments emp ON emp.tenant_id=a.tenant_id AND emp.id=a.employment_id AND emp.employee_id=v_employee_id
     AND d.operational_date>=emp.start_date AND (emp.end_date IS NULL OR d.operational_date<=emp.end_date)
   LEFT JOIN LATERAL(SELECT po.policy_template_id,po.policy_version FROM time.work_policy_overrides po
     WHERE po.tenant_id=a.tenant_id AND po.employment_id=emp.id AND po.cancelled_at IS NULL
       AND po.valid_from<=d.operational_date AND po.valid_until>d.operational_date ORDER BY po.valid_from DESC LIMIT 1)o ON true
   JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id AND v.template_id=coalesce(o.policy_template_id,a.work_policy_template_id)
     AND v.version=coalesce(o.policy_version,a.work_policy_version)
   WHERE a.site_id=v_site_id
     AND d.operational_date IN ((happened_at AT TIME ZONE v.timezone_name)::date,(happened_at AT TIME ZONE v.timezone_name)::date-1)
     AND d.operational_date<=(transaction_timestamp() AT TIME ZONE v.timezone_name)::date
     AND extract(dow FROM d.operational_date)::integer+1=ANY(v.work_days)
 ), windows AS (
   SELECT s.*,
     CASE WHEN schedule_kind='fixed' THEN expected_start-make_interval(mins=>attribution_before_minutes) ELSE expected_start END attribution_start,
     CASE WHEN schedule_kind='fixed' THEN expected_end+make_interval(mins=>attribution_after_minutes) ELSE expected_end END attribution_end
   FROM scheduled s
 )
 SELECT * INTO candidate FROM windows w WHERE w.expected_start IS NOT NULL AND w.expected_end IS NOT NULL
   AND happened_at>=w.attribution_start AND happened_at<=w.attribution_end ORDER BY w.operational_date DESC LIMIT 1;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('status','unassigned','errors','[]'::jsonb,'warnings',jsonb_build_array('حُفظ الحدث للمراجعة؛ لا يوجد تكليف وسياسة دوام يطابقان وقت التسجيل والفرع.'),'employee_code',v_employee_code,'full_name',v_employee_name,'employee_id',v_employee_id,'site_id',v_site_id,'site_name',v_site_name,'happened_at',happened_at,'direction',direction,'source_event_key',event_key,'fingerprint',fingerprint);
 END IF;
 SELECT * INTO instance FROM time.work_instances i WHERE i.tenant_id=p_tenant AND i.assignment_id=candidate.assignment_id
   AND i.operational_date=candidate.operational_date;
 IF FOUND THEN
   IF instance.policy_template_id<>candidate.policy_id OR instance.policy_version<>candidate.policy_version THEN
     RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تختلف السياسة المحفوظة لهذا اليوم عن السياسة الفعالة؛ لم يُغيّر السجل.'));
   END IF;
   IF happened_at<instance.attribution_start OR happened_at>instance.attribution_end THEN
     RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('وقت الحدث خارج نافذة هذا اليوم.'));
   END IF;
   instance_id:=instance.id;
 ELSE
   IF NOT p_create_instance THEN
     RETURN jsonb_build_object('status','ready','errors','[]'::jsonb,'warnings','[]'::jsonb,
       'employee_code',v_employee_code,'full_name',v_employee_name,'site_name',v_site_name,
       'happened_at',happened_at,'direction',direction,'source_event_key',event_key,
       'work_date',candidate.operational_date,'policy_id',candidate.policy_id,'policy_version',candidate.policy_version,
       'assignment_id',candidate.assignment_id);
   END IF;
   starts:=candidate.expected_start; ends:=candidate.expected_end;
   attr_start:=candidate.attribution_start; attr_end:=candidate.attribution_end;
   INSERT INTO time.work_instances(tenant_id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,
      expected_start,expected_end,attribution_start,attribution_end,status,created_by,break_minutes,lateness_grace_minutes,early_leave_grace_minutes,schedule_kind,required_minutes)
   VALUES(p_tenant,candidate.assignment_id,candidate.employment_id,candidate.employee_id,candidate.site_id,candidate.operational_date,
      candidate.policy_id,candidate.policy_version,candidate.timezone_name,
      CASE WHEN candidate.schedule_kind='fixed' THEN starts END,CASE WHEN candidate.schedule_kind='fixed' THEN ends END,
      attr_start,attr_end,CASE WHEN starts IS NULL OR ends IS NULL OR attr_start IS NULL OR attr_end IS NULL THEN 'needs_review' ELSE 'open' END,
      p_actor,candidate.break_minutes,candidate.lateness_grace_minutes,candidate.early_leave_grace_minutes,candidate.schedule_kind,candidate.required_minutes)
   ON CONFLICT(tenant_id,assignment_id,operational_date) DO NOTHING RETURNING id INTO instance_id;
   IF instance_id IS NULL THEN
     SELECT * INTO instance FROM time.work_instances i WHERE i.tenant_id=p_tenant AND i.assignment_id=candidate.assignment_id AND i.operational_date=candidate.operational_date;
     IF NOT FOUND OR instance.policy_template_id<>candidate.policy_id OR instance.policy_version<>candidate.policy_version THEN
       RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تغير سجل اليوم أثناء الفحص؛ أعد الفحص قبل الاستيراد.'));
     END IF;
     instance_id:=instance.id;
   END IF;
 END IF;
 RETURN jsonb_build_object('status','ready','errors','[]'::jsonb,'warnings','[]'::jsonb,
   'employee_code',v_employee_code,'full_name',v_employee_name,'site_name',v_site_name,
   'happened_at',happened_at,'direction',direction,'source_event_key',event_key,
   'work_date',candidate.operational_date,'policy_id',candidate.policy_id,'policy_version',candidate.policy_version,
   'assignment_id',candidate.assignment_id,'instance_id',instance_id,'fingerprint',fingerprint);
END $f$;
REVOKE ALL ON FUNCTION time.attendance_import_resolve_row(uuid,jsonb,boolean,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.end_people_employment(p_tenant_id uuid,p_employee_id uuid,p_employment_id uuid,p_end_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_today date := pg_catalog.timezone('Africa/Cairo',pg_catalog.transaction_timestamp())::date;
  v_employment people.employments%ROWTYPE; v_employee people.employees%ROWTYPE;
  v_assignment people.work_assignments%ROWTYPE; v_comp people.compensation_versions%ROWTYPE;
  v_before jsonb; v_after jsonb; v_pending_assignments jsonb := '[]'::jsonb; v_pending_compensation jsonb := '[]'::jsonb;
  v_assignment_before jsonb; v_previous_assignment_id uuid; v_comp_before jsonb; v_previous_comp_id uuid;
  v_current_assignment_id uuid; v_current_compensation_id uuid;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'employment.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'org_context.manage')
     OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'compensation.manage') THEN
    RAISE EXCEPTION 'people_employment_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_tenant_id IS NULL OR p_employee_id IS NULL OR p_employment_id IS NULL OR p_end_date IS NULL THEN
    RAISE EXCEPTION 'people_employment_end_input_invalid' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_employee FROM people.employees e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_not_found' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_employment FROM people.employments e
    WHERE e.tenant_id=p_tenant_id AND e.id=p_employment_id AND e.employee_id=p_employee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_not_found' USING ERRCODE='P0002'; END IF;
  IF v_employment.employment_status<>'active' THEN
    RAISE EXCEPTION 'people_employment_not_active' USING ERRCODE='23514';
  END IF;
  IF v_employment.start_date>v_today THEN
    RAISE EXCEPTION 'people_employment_not_started' USING ERRCODE='23514';
  END IF;
  IF p_end_date>v_today THEN
    RAISE EXCEPTION 'people_employment_future_end_unsupported' USING ERRCODE='22023';
  END IF;
  IF p_end_date<v_employment.start_date THEN
    RAISE EXCEPTION 'people_employment_end_before_start' USING ERRCODE='22023';
  END IF;
  IF EXISTS (SELECT 1 FROM people.work_assignments a WHERE a.tenant_id=p_tenant_id
      AND a.employment_id=p_employment_id AND a.valid_from>p_end_date AND a.valid_from<=v_today)
     OR EXISTS (SELECT 1 FROM people.compensation_versions c WHERE c.tenant_id=p_tenant_id
      AND c.employment_id=p_employment_id AND c.valid_from>p_end_date AND c.valid_from<=v_today) THEN
    RAISE EXCEPTION 'people_employment_end_after_effective_change' USING ERRCODE='23514';
  END IF;
  SELECT * INTO v_assignment FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
      AND a.valid_from<=p_end_date AND (a.valid_until IS NULL OR a.valid_until>p_end_date)
    ORDER BY a.valid_from DESC,a.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_current_assignment_missing' USING ERRCODE='23514'; END IF;
  SELECT * INTO v_comp FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
      AND c.valid_from<=p_end_date AND (c.valid_until IS NULL OR c.valid_until>p_end_date)
    ORDER BY c.valid_from DESC,c.id DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_current_compensation_missing' USING ERRCODE='23514'; END IF;
  v_current_assignment_id := v_assignment.id;
  v_current_compensation_id := v_comp.id;

  v_before := pg_catalog.jsonb_build_object('employment_status',v_employment.employment_status,
    'end_date',v_employment.end_date,'employee_status',v_employee.workforce_status,
    'assignment_id',v_assignment.id,'assignment_valid_until',v_assignment.valid_until,
    'compensation_version_id',v_comp.id,'compensation_valid_until',v_comp.valid_until);

  FOR v_assignment IN SELECT * FROM people.work_assignments a
    WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id AND a.valid_from>v_today
    ORDER BY a.valid_from FOR UPDATE
  LOOP
    SELECT a.id INTO v_previous_assignment_id FROM people.work_assignments a
      WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id
        AND a.valid_until=v_assignment.valid_from AND a.id<>v_assignment.id
      ORDER BY a.valid_from DESC,a.id DESC LIMIT 1;
    v_assignment_before := pg_catalog.jsonb_build_object('id',v_assignment.id,'site_id',v_assignment.site_id,
      'department_id',v_assignment.department_id,'job_id',v_assignment.job_id,
      'manager_employee_id',v_assignment.manager_employee_id,'valid_from',v_assignment.valid_from,
      'valid_until',v_assignment.valid_until);
    DELETE FROM people.work_assignments WHERE tenant_id=p_tenant_id AND id=v_assignment.id;
    IF v_previous_assignment_id IS NOT NULL THEN
      UPDATE people.work_assignments SET valid_until=NULL WHERE tenant_id=p_tenant_id AND id=v_previous_assignment_id;
    END IF;
    v_pending_assignments := v_pending_assignments || pg_catalog.jsonb_build_array(v_assignment_before);
    INSERT INTO people.work_assignment_audit_events(tenant_id,employment_id,actor_user_id,event_key,assignment_id,details)
      VALUES(p_tenant_id,p_employment_id,v_actor,'assignment.transfer_cancelled',v_assignment.id,
        pg_catalog.jsonb_build_object('cancelled',v_assignment_before,'reason','employment_ended'));
  END LOOP;

  FOR v_comp IN SELECT * FROM people.compensation_versions c
    WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id AND c.valid_from>v_today
    ORDER BY c.valid_from FOR UPDATE
  LOOP
    SELECT c.id INTO v_previous_comp_id FROM people.compensation_versions c
      WHERE c.tenant_id=p_tenant_id AND c.employment_id=p_employment_id
        AND c.valid_until=v_comp.valid_from AND c.id<>v_comp.id
      ORDER BY c.valid_from DESC,c.id DESC LIMIT 1;
    v_comp_before := pg_catalog.jsonb_build_object('id',v_comp.id,'amount',v_comp.amount,
      'currency',v_comp.currency_code,'valid_from',v_comp.valid_from,'valid_until',v_comp.valid_until);
    DELETE FROM people.compensation_versions WHERE tenant_id=p_tenant_id AND id=v_comp.id;
    IF v_previous_comp_id IS NOT NULL THEN
      UPDATE people.compensation_versions SET valid_until=NULL WHERE tenant_id=p_tenant_id AND id=v_previous_comp_id;
    END IF;
    v_pending_compensation := v_pending_compensation || pg_catalog.jsonb_build_array(v_comp_before);
    INSERT INTO people.compensation_audit_events(tenant_id,employment_id,actor_user_id,event_key,subject_version_id,details)
      VALUES(p_tenant_id,p_employment_id,v_actor,'compensation.change_cancelled',v_comp.id,
        pg_catalog.jsonb_build_object('cancelled',v_comp_before,'reason','employment_ended'));
  END LOOP;

  UPDATE people.work_assignments SET valid_until=p_end_date+1
    WHERE tenant_id=p_tenant_id AND id=v_current_assignment_id;
  UPDATE people.compensation_versions SET valid_until=p_end_date+1
    WHERE tenant_id=p_tenant_id AND id=v_current_compensation_id;
  UPDATE people.employments SET end_date=p_end_date,employment_status='ended'
    WHERE tenant_id=p_tenant_id AND id=p_employment_id;
  UPDATE people.employees SET workforce_status='ended',updated_at=pg_catalog.transaction_timestamp()
    WHERE tenant_id=p_tenant_id AND id=p_employee_id;
  v_after := pg_catalog.jsonb_build_object('employment_status','ended','end_date',p_end_date,
    'employee_status','ended','assignment_id',v_current_assignment_id,'assignment_valid_until',p_end_date+1,
    'compensation_version_id',v_current_compensation_id,'compensation_valid_until',p_end_date+1);
  INSERT INTO people.employment_lifecycle_audit_events(tenant_id,employee_id,employment_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_employee_id,p_employment_id,v_actor,'employment.ended',pg_catalog.jsonb_build_object(
      'before',v_before,'after',v_after,'cancelled_future_assignments',v_pending_assignments,
      'cancelled_future_compensation',v_pending_compensation,
      'handoff_required',pg_catalog.jsonb_build_array('payroll_final_settlement','leave_balance_review','finance_balance_review')));
  RETURN pg_catalog.jsonb_build_object('employment_id',p_employment_id,'end_date',p_end_date,'state','ended');
END;
$function$;
REVOKE ALL ON FUNCTION public.end_people_employment(uuid,uuid,uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.end_people_employment(uuid,uuid,uuid,date) TO authenticated;
