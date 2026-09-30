ALTER TABLE time.manual_punches
  ADD COLUMN source_type text NOT NULL DEFAULT 'manual' CHECK (source_type IN ('manual','import')),
  ADD COLUMN source_event_key text;
ALTER TABLE time.manual_punches ADD CONSTRAINT manual_punch_source_key_required
  CHECK (source_type='manual' OR (source_event_key IS NOT NULL AND length(btrim(source_event_key)) BETWEEN 1 AND 160));
CREATE UNIQUE INDEX manual_punch_import_source_key_idx
  ON time.manual_punches(tenant_id,source_event_key) WHERE source_event_key IS NOT NULL;

CREATE FUNCTION time.attendance_import_resolve_row(p_tenant uuid,p_row jsonb,p_create_instance boolean,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE v_employee_id uuid; v_employee_code text; v_employee_name text; v_site_id uuid; v_site_name text; site_count integer;
 event_key text; direction text; happened_at timestamptz; happened_text text; fingerprint text;
 prior time.manual_punches%ROWTYPE; candidate record; candidate_count integer; instance time.work_instances%ROWTYPE; instance_id uuid;
 starts timestamptz; ends timestamptz; attr_start timestamptz; attr_end timestamptz;
BEGIN
 IF jsonb_typeof(p_row)<>'object' THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('بيانات الصف غير صالحة.')); END IF;
 v_employee_code:=btrim(coalesce(p_row->>'employee_code','')); v_site_name:=btrim(coalesce(p_row->>'site_name',''));
 event_key:=btrim(coalesce(p_row->>'source_event_key','')); direction:=lower(btrim(coalesce(p_row->>'direction','')));
 happened_text:=btrim(coalesce(p_row->>'happened_at',''));
 IF v_employee_code='' OR length(v_employee_code)>64 OR v_site_name='' OR length(v_site_name)>160
    OR event_key='' OR length(event_key)>160 OR direction NOT IN('in','out')
    OR happened_text !~ '^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:?\d{2})$' THEN
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تحقق من رمز الموظف والفرع والاتجاه ومفتاح الحدث، واكتب الوقت مع فرق توقيت مثل +02:00.'));
 END IF;
 BEGIN happened_at:=happened_text::timestamptz;
 EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('صيغة التاريخ أو فرق التوقيت غير صالح. استخدم تاريخًا ووقتًا واضحين.')); END;
 IF happened_at>transaction_timestamp()+interval '5 minutes' THEN
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('لا يمكن استيراد تسجيل يقع في المستقبل.'));
 END IF;
 SELECT count(*)::integer,(array_agg(e.id ORDER BY e.id))[1],min(e.employee_code),min(e.full_name) INTO candidate_count,v_employee_id,v_employee_code,v_employee_name
 FROM people.employees e WHERE e.tenant_id=p_tenant AND e.employee_code=btrim(coalesce(p_row->>'employee_code',''));
 IF candidate_count=0 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('رمز الموظف غير موجود في هذه الشركة.')); END IF;
 IF candidate_count<>1 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('رمز الموظف غير محدد؛ اطلب مراجعة دليل الموظفين.')); END IF;
 SELECT count(*)::integer,(array_agg(s.id ORDER BY s.id))[1],min(s.display_name) INTO site_count,v_site_id,v_site_name
 FROM platform_core.tenant_sites s WHERE s.tenant_id=p_tenant AND s.is_active
   AND lower(btrim(s.display_name))=lower(btrim(coalesce(p_row->>'site_name','')));
 IF site_count=0 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('اسم الفرع غير موجود أو غير نشط في هذه الشركة.')); END IF;
 IF site_count<>1 THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('اسم الفرع مكرر؛ استخدم فرعًا باسم فريد ثم أعد الفحص.')); END IF;
 fingerprint:=md5(concat_ws(chr(31),v_employee_id::text,v_site_id::text,direction,happened_at::text));
 SELECT * INTO prior FROM time.manual_punches p WHERE p.tenant_id=p_tenant AND p.source_event_key=event_key;
 IF FOUND THEN
   IF prior.payload_fingerprint=fingerprint THEN
     RETURN jsonb_build_object('status','duplicate','errors','[]'::jsonb,'warnings',jsonb_build_array('هذا الحدث مسجل مسبقًا؛ لن يتكرر.'));
   END IF;
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('مفتاح الحدث مستخدم لوقت أو موظف مختلف. راجع مصدر الملف.'));
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
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('لا يوجد تكليف وسياسة دوام يطابقان وقت التسجيل والفرع. تحقق من الفترة والتوقيت.'));
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

CREATE FUNCTION public.preview_attendance_csv_import(p_tenant_id uuid,p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); row_item jsonb; result jsonb; output jsonb:='[]'::jsonb; seen jsonb:='{}'::jsonb; event_key text; row_sig text;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_import_forbidden' USING ERRCODE='42501'; END IF;
 IF p_rows IS NULL OR jsonb_typeof(p_rows)<>'array' THEN RAISE EXCEPTION 'attendance_import_rows_invalid' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_rows) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'attendance_import_rows_invalid' USING ERRCODE='22023'; END IF;
 FOR row_item IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
   event_key:=btrim(coalesce(row_item->>'source_event_key',''));
   row_sig:=md5(concat_ws(chr(31),btrim(coalesce(row_item->>'employee_code','')),btrim(coalesce(row_item->>'site_name','')),btrim(coalesce(row_item->>'happened_at','')),lower(btrim(coalesce(row_item->>'direction','')))));
   IF event_key<>'' AND seen ? event_key THEN
     IF seen->>event_key=row_sig THEN result:=jsonb_build_object('status','duplicate','warnings',jsonb_build_array('مكرر داخل الملف؛ سيُحتسب الحدث مرة واحدة.'),'errors','[]'::jsonb);
     ELSE result:=jsonb_build_object('status','rejected','errors',jsonb_build_array('مفتاح الحدث مكرر داخل الملف ببيانات مختلفة.'),'warnings','[]'::jsonb); END IF;
   ELSE
     result:=time.attendance_import_resolve_row(p_tenant_id,row_item,false,actor);
     IF event_key<>'' THEN seen:=seen||jsonb_build_object(event_key,row_sig); END IF;
   END IF;
   output:=output||jsonb_build_array(row_item||result);
 END LOOP;
 RETURN output;
END $f$;
REVOKE ALL ON FUNCTION public.preview_attendance_csv_import(uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.preview_attendance_csv_import(uuid,jsonb) TO authenticated;

CREATE FUNCTION public.confirm_attendance_csv_import(p_tenant_id uuid,p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); row_item jsonb; result jsonb; output jsonb:='[]'::jsonb; n_accepted integer:=0; n_duplicate integer:=0; n_rejected integer:=0; instance_id uuid; punch_id uuid; fingerprint text; direction text; event_key text; happened_at timestamptz; state text;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_import_forbidden' USING ERRCODE='42501'; END IF;
 IF p_rows IS NULL OR jsonb_typeof(p_rows)<>'array' THEN RAISE EXCEPTION 'attendance_import_rows_invalid' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_rows) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'attendance_import_rows_invalid' USING ERRCODE='22023'; END IF;
 FOR row_item IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
   BEGIN
     result:=time.attendance_import_resolve_row(p_tenant_id,row_item,true,actor);
     state:=result->>'status';
     IF state='ready' THEN
       instance_id:=(result->>'instance_id')::uuid; fingerprint:=result->>'fingerprint';
       event_key:=result->>'source_event_key'; direction:=result->>'direction'; happened_at:=(result->>'happened_at')::timestamptz;
       INSERT INTO time.manual_punches(tenant_id,work_instance_id,direction,happened_at,request_key,payload_fingerprint,actor_user_id,source_type,source_event_key)
         VALUES(p_tenant_id,instance_id,direction,happened_at,gen_random_uuid(),fingerprint,actor,'import',event_key)
         ON CONFLICT(tenant_id,source_event_key) WHERE source_event_key IS NOT NULL DO NOTHING RETURNING id INTO punch_id;
       IF punch_id IS NULL THEN
         SELECT p.id,p.payload_fingerprint INTO punch_id,fingerprint FROM time.manual_punches p WHERE p.tenant_id=p_tenant_id AND p.source_event_key=event_key;
         IF fingerprint=(result->>'fingerprint') THEN state:='duplicate';
         ELSE state:='rejected'; result:=result||jsonb_build_object('errors',jsonb_build_array('وصل حدث بالمفتاح نفسه أثناء الاستيراد وببيانات مختلفة.'));
         END IF;
       ELSE
         PERFORM time.interpret_work_instance(p_tenant_id,instance_id,actor);
         INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
           VALUES(p_tenant_id,actor,'attendance.import.event',instance_id,jsonb_build_object('source_event_key',event_key,'source_type','import','direction',direction,'happened_at',happened_at,'site_id',(SELECT site_id FROM time.work_instances WHERE tenant_id=p_tenant_id AND id=instance_id)));
         state:='accepted';
       END IF;
     END IF;
     result:=result||jsonb_build_object('status',state);
   EXCEPTION WHEN OTHERS THEN
     GET STACKED DIAGNOSTICS event_key=MESSAGE_TEXT;
     result:=jsonb_build_object('status','rejected','errors',jsonb_build_array(CASE WHEN event_key LIKE '%ambiguous%' THEN 'التوقيت المحلي ملتبس بسبب تغيير الساعة؛ لم يُستورد الحدث.' ELSE 'تعذر حفظ هذا الصف؛ لم يتغير سجل الموظف.' END),'warnings','[]'::jsonb);
   END;
   IF result->>'status'='accepted' THEN n_accepted:=n_accepted+1;
   ELSIF result->>'status'='duplicate' THEN n_duplicate:=n_duplicate+1;
   ELSE n_rejected:=n_rejected+1; END IF;
   output:=output||jsonb_build_array(row_item||result);
 END LOOP;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
   VALUES(p_tenant_id,actor,'attendance.import.completed',NULL,jsonb_build_object('accepted_count',n_accepted,'duplicate_count',n_duplicate,'rejected_count',n_rejected,'row_count',jsonb_array_length(p_rows)));
 RETURN jsonb_build_object('accepted_count',n_accepted,'duplicate_count',n_duplicate,'rejected_count',n_rejected,'rows',output);
END $f$;
REVOKE ALL ON FUNCTION public.confirm_attendance_csv_import(uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.confirm_attendance_csv_import(uuid,jsonb) TO authenticated;
