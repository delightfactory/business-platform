-- Disambiguate overlapping attendance attribution windows with an operator-selected operational date.
CREATE OR REPLACE FUNCTION time.attendance_import_resolve_row(p_tenant uuid,p_row jsonb,p_create_instance boolean,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE v_employee_id uuid; v_employee_code text; v_employee_name text; v_site_id uuid; v_site_name text; site_count integer;
 event_key text; direction text; identity_employee_id uuid; identity_site_id uuid; happened_at timestamptz; happened_text text; fingerprint text;
 prior time.manual_punches%ROWTYPE; pending time.unassigned_attendance_evidence%ROWTYPE; attach_id text; candidate record; candidate_count integer; instance time.work_instances%ROWTYPE; instance_id uuid;
 starts timestamptz; ends timestamptz; attr_start timestamptz; attr_end timestamptz; requested_work_date date; candidate_dates date[];
BEGIN
 IF jsonb_typeof(p_row)<>'object' THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('بيانات الصف غير صالحة.')); END IF;
 v_employee_code:=btrim(coalesce(p_row->>'employee_code','')); v_site_name:=btrim(coalesce(p_row->>'site_name',''));
 identity_employee_id:=NULLIF(p_row->>'identity_employee_id','')::uuid; identity_site_id:=NULLIF(p_row->>'identity_site_id','')::uuid;
 event_key:=btrim(coalesce(p_row->>'source_event_key','')); direction:=lower(btrim(coalesce(p_row->>'direction','')));
 happened_text:=btrim(coalesce(p_row->>'happened_at',''));
 IF NULLIF(p_row->>'work_date','') IS NOT NULL THEN
   BEGIN requested_work_date:=NULLIF(p_row->>'work_date','')::date;
   EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تاريخ يوم العمل المختار غير صالح. أعد الفحص واختر تاريخًا من القائمة.')); END;
   IF NULLIF(p_row->>'work_date','') !~ '^\d{4}-\d{2}-\d{2}$' THEN
     RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تاريخ يوم العمل المختار غير صالح. أعد الفحص واختر تاريخًا من القائمة.'));
   END IF;
 END IF;
 IF identity_employee_id IS NOT NULL OR identity_site_id IS NOT NULL THEN
   IF coalesce(current_setting('time.unassigned_attach_id',true),'')='' THEN
     RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تعذر التحقق من هوية مصدر التسجيل.'));
   END IF;
   IF NOT EXISTS(
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
 ), matching AS (
   SELECT coalesce(array_agg(DISTINCT w.operational_date ORDER BY w.operational_date),'{}'::date[]) matched_dates
   FROM windows w WHERE w.expected_start IS NOT NULL AND w.expected_end IS NOT NULL
     AND happened_at>=w.attribution_start AND happened_at<=w.attribution_end
 )
 SELECT chosen.*,matching.matched_dates INTO candidate
 FROM matching LEFT JOIN LATERAL (
   SELECT w.* FROM windows w WHERE w.expected_start IS NOT NULL AND w.expected_end IS NOT NULL
     AND happened_at>=w.attribution_start AND happened_at<=w.attribution_end
     AND w.operational_date=coalesce(requested_work_date,matching.matched_dates[1])
   ORDER BY w.assignment_id LIMIT 1
 ) chosen ON true;
 candidate_dates:=candidate.matched_dates;
 candidate_count:=cardinality(candidate_dates);
 IF candidate_count=0 THEN
   RETURN jsonb_build_object('status','unassigned','errors','[]'::jsonb,'warnings',jsonb_build_array('حُفظ الحدث للمراجعة؛ لا يوجد تكليف وسياسة دوام يطابقان وقت التسجيل والفرع.'),'employee_code',v_employee_code,'full_name',v_employee_name,'employee_id',v_employee_id,'site_id',v_site_id,'site_name',v_site_name,'happened_at',happened_at,'direction',direction,'source_event_key',event_key,'fingerprint',fingerprint,'candidate_work_dates','[]'::jsonb);
 END IF;
 IF requested_work_date IS NOT NULL AND NOT requested_work_date=ANY(candidate_dates) THEN
   RETURN jsonb_build_object('status','rejected','errors',jsonb_build_array('تغيرت الأيام المطابقة لهذا الحدث. أعد الفحص واختر يومًا من النتائج الحالية.'),'candidate_work_dates',to_jsonb(candidate_dates));
 END IF;
 IF requested_work_date IS NULL AND candidate_count>1 THEN
   RETURN jsonb_build_object('status','ambiguous','errors','[]'::jsonb,'warnings',jsonb_build_array('وقت الحدث يطابق أكثر من يوم عمل. اختر تاريخ العمل المقصود قبل التأكيد.'),'candidate_work_dates',to_jsonb(candidate_dates),'employee_code',v_employee_code,'full_name',v_employee_name,'employee_id',v_employee_id,'site_id',v_site_id,'site_name',v_site_name,'happened_at',happened_at,'direction',direction,'source_event_key',event_key,'fingerprint',fingerprint);
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
        'assignment_id',candidate.assignment_id,'candidate_work_dates',to_jsonb(candidate_dates));
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
   'assignment_id',candidate.assignment_id,'instance_id',instance_id,'fingerprint',fingerprint,'candidate_work_dates',to_jsonb(candidate_dates));
END $f$;
REVOKE ALL ON FUNCTION time.attendance_import_resolve_row(uuid,jsonb,boolean,uuid) FROM PUBLIC,anon,authenticated,service_role;


CREATE OR REPLACE FUNCTION public.confirm_attendance_csv_import(p_tenant_id uuid,p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); row_item jsonb; result jsonb; output jsonb:='[]'::jsonb; n_accepted integer:=0; n_duplicate integer:=0; n_rejected integer:=0; n_unassigned integer:=0; n_ambiguous integer:=0; instance_id uuid; punch_id uuid; fingerprint text; direction text; event_key text; happened_at timestamptz; state text;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_import_forbidden' USING ERRCODE='42501'; END IF;
 IF p_rows IS NULL OR jsonb_typeof(p_rows)<>'array' THEN RAISE EXCEPTION 'attendance_import_rows_invalid' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_rows) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'attendance_import_rows_invalid' USING ERRCODE='22023'; END IF;
 FOR row_item IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
   BEGIN
     result:=time.attendance_import_resolve_row(p_tenant_id,row_item,true,actor);
     state:=result->>'status';
     IF state='unassigned' THEN
       INSERT INTO time.unassigned_attendance_evidence(tenant_id,employee_id,source_employee_code,source_employee_name,site_id,source_site_name,direction,happened_at,source_event_key,payload_fingerprint,actor_user_id)
       VALUES(p_tenant_id,(result->>'employee_id')::uuid,result->>'employee_code',result->>'full_name',(result->>'site_id')::uuid,result->>'site_name',result->>'direction',(result->>'happened_at')::timestamptz,result->>'source_event_key',result->>'fingerprint',actor)
       ON CONFLICT(tenant_id,source_event_key) DO NOTHING;
       IF NOT FOUND THEN
         IF EXISTS(SELECT 1 FROM time.unassigned_attendance_evidence e WHERE e.tenant_id=p_tenant_id AND e.source_event_key=result->>'source_event_key' AND e.payload_fingerprint=result->>'fingerprint') THEN state:='duplicate';
         ELSE state:='rejected'; result:=result||jsonb_build_object('errors',jsonb_build_array('مفتاح الحدث محفوظ مسبقًا لبيانات مختلفة.')); END IF;
       ELSE
         INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
         VALUES(p_tenant_id,actor,'attendance.import.unassigned',NULL,jsonb_build_object('source_event_key',result->>'source_event_key','employee_id',result->>'employee_id','site_id',result->>'site_id','direction',result->>'direction','happened_at',result->>'happened_at'));
       END IF;
     END IF;     IF state='ready' THEN
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
    IF result->>'status'='unassigned' THEN n_unassigned:=n_unassigned+1; ELSIF result->>'status'='accepted' THEN n_accepted:=n_accepted+1;
    ELSIF result->>'status'='duplicate' THEN n_duplicate:=n_duplicate+1;
    ELSIF result->>'status'='ambiguous' THEN n_ambiguous:=n_ambiguous+1;
   ELSE n_rejected:=n_rejected+1; END IF;
   output:=output||jsonb_build_array(row_item||result);
 END LOOP;
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
   VALUES(p_tenant_id,actor,'attendance.import.completed',NULL,jsonb_build_object('accepted_count',n_accepted,'duplicate_count',n_duplicate,'rejected_count',n_rejected,'unassigned_count',n_unassigned,'ambiguous_count',n_ambiguous,'row_count',jsonb_array_length(p_rows)));
 RETURN jsonb_build_object('accepted_count',n_accepted,'duplicate_count',n_duplicate,'rejected_count',n_rejected,'unassigned_count',n_unassigned,'ambiguous_count',n_ambiguous,'rows',output);
END $f$;

REVOKE ALL ON FUNCTION public.confirm_attendance_csv_import(uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.confirm_attendance_csv_import(uuid,jsonb) TO authenticated;


CREATE OR REPLACE FUNCTION public.attach_unassigned_attendance_evidence_for_date(p_tenant_id uuid,p_evidence_id uuid,p_reason text,p_work_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); evidence time.unassigned_attendance_evidence%ROWTYPE; old_resolution time.unassigned_attendance_resolutions%ROWTYPE; row_data jsonb; result jsonb; punch_id uuid; instance_id uuid;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
   OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_unassigned_forbidden' USING ERRCODE='42501'; END IF;
 IF p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'attendance_unassigned_reason_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO evidence FROM time.unassigned_attendance_evidence WHERE tenant_id=p_tenant_id AND id=p_evidence_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'attendance_unassigned_not_found' USING ERRCODE='P0002'; END IF;
 SELECT * INTO old_resolution FROM time.unassigned_attendance_resolutions WHERE tenant_id=p_tenant_id AND unassigned_evidence_id=evidence.id;
 IF FOUND THEN RETURN jsonb_build_object('status','already_attached','work_instance_id',old_resolution.work_instance_id); END IF;
 PERFORM set_config('time.unassigned_attach_id',evidence.id::text,true);
  row_data:=jsonb_build_object('employee_code',evidence.source_employee_code,'site_name',evidence.source_site_name,'identity_employee_id',evidence.employee_id,'identity_site_id',evidence.site_id,'happened_at',evidence.happened_at,'direction',evidence.direction,'source_event_key',evidence.source_event_key,'work_date',p_work_date);
 result:=time.attendance_import_resolve_row(p_tenant_id,row_data,true,actor);
 IF result->>'status'='ambiguous' THEN RAISE EXCEPTION 'attendance_unassigned_work_date_required' USING ERRCODE='22023',DETAIL='وقت الحدث يطابق أكثر من يوم عمل. اختر التاريخ المقصود من القائمة.'; END IF;
 IF result->>'status'<>'ready' OR result->>'employee_id' IS NOT NULL AND (result->>'employee_id')::uuid<>evidence.employee_id OR result->>'site_id' IS NOT NULL AND (result->>'site_id')::uuid<>evidence.site_id THEN
   RAISE EXCEPTION 'attendance_unassigned_assignment_unavailable' USING ERRCODE='23514',DETAIL=coalesce(result->'errors'->>0,'راجع تكليف الموظف والسياسة والفرع في تاريخ الحدث.');
 END IF;
 instance_id:=(result->>'instance_id')::uuid;
 IF NOT EXISTS(SELECT 1 FROM people.work_assignments a JOIN people.employments emp ON emp.tenant_id=a.tenant_id AND emp.id=a.employment_id
   WHERE a.tenant_id=p_tenant_id AND a.id=(result->>'assignment_id')::uuid AND emp.employee_id=evidence.employee_id AND a.site_id=evidence.site_id) THEN
   RAISE EXCEPTION 'attendance_unassigned_assignment_mismatch' USING ERRCODE='23514';
 END IF;
 INSERT INTO time.manual_punches(tenant_id,work_instance_id,direction,happened_at,request_key,payload_fingerprint,actor_user_id,source_type,source_event_key)
 VALUES(p_tenant_id,instance_id,evidence.direction,evidence.happened_at,gen_random_uuid(),evidence.payload_fingerprint,actor,'import',evidence.source_event_key)
 ON CONFLICT(tenant_id,source_event_key) WHERE source_event_key IS NOT NULL DO NOTHING RETURNING id INTO punch_id;
 IF punch_id IS NULL THEN RAISE EXCEPTION 'attendance_unassigned_source_conflict' USING ERRCODE='23505'; END IF;
 PERFORM time.interpret_work_instance(p_tenant_id,instance_id,actor);
 INSERT INTO time.unassigned_attendance_resolutions(tenant_id,unassigned_evidence_id,work_instance_id,manual_punch_id,reason,actor_user_id)
 VALUES(p_tenant_id,evidence.id,instance_id,punch_id,btrim(p_reason),actor);
 INSERT INTO time.attendance_audit_events(tenant_id,actor_user_id,event_key,work_instance_id,details)
 VALUES(p_tenant_id,actor,'attendance.import.unassigned.attached',instance_id,jsonb_build_object('evidence_id',evidence.id,'source_event_key',evidence.source_event_key,'manual_punch_id',punch_id,'reason',btrim(p_reason)));
 RETURN jsonb_build_object('status','attached','work_instance_id',instance_id,'manual_punch_id',punch_id);
END $f$;


REVOKE ALL ON FUNCTION public.attach_unassigned_attendance_evidence_for_date(uuid,uuid,text,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attach_unassigned_attendance_evidence_for_date(uuid,uuid,text,date) TO authenticated;
CREATE OR REPLACE FUNCTION public.attach_unassigned_attendance_evidence(p_tenant_id uuid,p_evidence_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 RETURN public.attach_unassigned_attendance_evidence_for_date(p_tenant_id,p_evidence_id,p_reason,NULL);
END $f$;
REVOKE ALL ON FUNCTION public.attach_unassigned_attendance_evidence(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attach_unassigned_attendance_evidence(uuid,uuid,text) TO authenticated;
CREATE OR REPLACE FUNCTION time.attendance_unassigned_candidate_resolution(p_tenant_id uuid,p_evidence_id uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE evidence time.unassigned_attendance_evidence%ROWTYPE; row_data jsonb; result jsonb; previous_attach_id text:=current_setting('time.unassigned_attach_id',true);
BEGIN
 SELECT * INTO evidence FROM time.unassigned_attendance_evidence WHERE tenant_id=p_tenant_id AND id=p_evidence_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','rejected','candidate_work_dates','[]'::jsonb); END IF;
 PERFORM pg_catalog.set_config('time.unassigned_attach_id',evidence.id::text,true);
 row_data:=jsonb_build_object('employee_code',evidence.source_employee_code,'site_name',evidence.source_site_name,
   'identity_employee_id',evidence.employee_id,'identity_site_id',evidence.site_id,'happened_at',evidence.happened_at,
   'direction',evidence.direction,'source_event_key',evidence.source_event_key);
  result:=time.attendance_import_resolve_row(p_tenant_id,row_data,false,p_actor);
  PERFORM pg_catalog.set_config('time.unassigned_attach_id',coalesce(previous_attach_id,''),true);
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION time.attendance_unassigned_candidate_resolution(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.attendance_unassigned_evidence_queue(p_tenant_id uuid,p_after uuid DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb; has_more boolean; next_cursor uuid;
BEGIN
 IF actor IS NULL OR NOT (platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.view') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.manage') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.correct') OR platform_private.has_tenant_permission(p_tenant_id,actor,'attendance.approve') OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')) THEN RAISE EXCEPTION 'attendance_unassigned_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'attendance_unassigned_limit_invalid' USING ERRCODE='22023'; END IF;
 WITH page AS (
   SELECT e.id,e.employee_id,e.source_employee_code,e.source_employee_name,e.site_id,e.source_site_name,e.direction,e.happened_at,e.source_type,e.source_event_key,e.created_at,
     r.id IS NOT NULL AS resolved,r.work_instance_id,r.reason AS resolution_reason,r.created_at AS resolved_at
   FROM time.unassigned_attendance_evidence e LEFT JOIN time.unassigned_attendance_resolutions r ON r.tenant_id=e.tenant_id AND r.unassigned_evidence_id=e.id
   WHERE e.tenant_id=p_tenant_id AND (p_after IS NULL OR e.id<p_after)
   ORDER BY e.id DESC LIMIT p_limit+1
 ), list AS (SELECT * FROM page ORDER BY id DESC LIMIT p_limit),
 resolved AS (SELECT l.*,time.attendance_unassigned_candidate_resolution(p_tenant_id,l.id,actor) AS date_resolution FROM list l)
  SELECT coalesce(jsonb_agg(jsonb_build_object(
       'id',resolved.id,'employee_id',resolved.employee_id,'source_employee_code',resolved.source_employee_code,
       'source_employee_name',resolved.source_employee_name,'site_id',resolved.site_id,'source_site_name',resolved.source_site_name,
       'direction',resolved.direction,'happened_at',resolved.happened_at,'source_type',resolved.source_type,
       'source_event_key',resolved.source_event_key,'created_at',resolved.created_at,'resolved',resolved.resolved,
       'work_instance_id',resolved.work_instance_id,'resolution_reason',resolved.resolution_reason,'resolved_at',resolved.resolved_at,
       'candidate_work_dates',coalesce(resolved.date_resolution->'candidate_work_dates','[]'::jsonb),
       'date_resolution_status',resolved.date_resolution->>'status',
       'date_resolution_warnings',coalesce(resolved.date_resolution->'warnings','[]'::jsonb)) ORDER BY resolved.id DESC),'[]'::jsonb),
   (SELECT count(*)>p_limit FROM page),(SELECT id FROM list ORDER BY id ASC LIMIT 1)
 INTO result,has_more,next_cursor FROM resolved;
 RETURN jsonb_build_object('items',coalesce(result,'[]'::jsonb),'has_more',coalesce(has_more,false),'next_cursor',CASE WHEN has_more THEN next_cursor::text ELSE NULL END);
END $f$;
REVOKE ALL ON FUNCTION public.attendance_unassigned_evidence_queue(uuid,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.attendance_unassigned_evidence_queue(uuid,uuid,integer) TO authenticated;
