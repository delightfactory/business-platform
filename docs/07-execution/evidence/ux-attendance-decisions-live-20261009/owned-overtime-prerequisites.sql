DO $$ DECLARE tenant uuid:='f5100000-0000-4000-8000-000000000001';manager uuid:='f9100000-0000-4000-8000-000000000001';policy uuid:='f5150000-0000-4000-8000-000000000011';today date:=(now() AT TIME ZONE 'UTC')::date;person jsonb;instance uuid;
BEGIN
IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' OR (SELECT count(*) FROM auth.users)<>2 THEN RAISE EXCEPTION 'owned synthetic QA only'; END IF;
PERFORM set_config('request.jwt.claim.sub',manager::text,true);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version) VALUES(tenant,policy,'UX-OT-QA',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by,overtime_enabled,overtime_minimum_minutes,overtime_rounding_minutes) VALUES(tenant,policy,1,'Synthetic overtime-enabled','flexible','UTC',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59:59',manager,true,15,15);
person:=public.create_people_employee(tenant,'UX-OT-SYN-1','موظف إضافي اصطناعي','f5130000-0000-4000-8000-000000000001','f5140000-0000-4000-8000-000000000001',today-30,'monthly',1000,true);
UPDATE people.work_assignments SET work_policy_template_id=policy,work_policy_version=1 WHERE tenant_id=tenant AND employment_id=(person->>'employment_id')::uuid;
PERFORM public.attendance_open_day(tenant,today-3,NULL,50);
SELECT id INTO STRICT instance FROM time.work_instances WHERE tenant_id=tenant AND employee_id=(person->>'employee_id')::uuid AND operational_date=today-3;
PERFORM public.record_manual_attendance_punch_local(tenant,instance,'in',(today-3+'09:00'::time)::timestamp,gen_random_uuid(),'دخول اصطناعي قبل مراجعة الإضافي');
PERFORM public.record_manual_attendance_punch_local(tenant,instance,'out',(today-3+'11:00'::time)::timestamp,gen_random_uuid(),'انصراف اصطناعي قبل مراجعة الإضافي');
RAISE NOTICE 'OWNED_OVERTIME_PREREQUISITE_INSTANCE %',instance;
END $$;
