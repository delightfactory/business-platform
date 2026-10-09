DO $$ DECLARE tenant uuid:='f5100000-0000-4000-8000-000000000001';manager uuid:='f9100000-0000-4000-8000-000000000001';employer uuid:='f5130000-0000-4000-8000-000000000001';employee uuid;period uuid;type_id uuid;version_id uuid;today date:=(now() AT TIME ZONE 'Africa/Cairo')::date;
BEGIN
IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' OR (SELECT count(*) FROM auth.users)<>2 THEN RAISE EXCEPTION 'owned synthetic QA only'; END IF;
PERFORM set_config('request.jwt.claim.sub',manager::text,true);
SELECT employee_id INTO STRICT employee FROM people.employee_user_links WHERE tenant_id=tenant AND user_id='f9200000-0000-4000-8000-000000000002';
SELECT id INTO STRICT period FROM leave.year_periods WHERE tenant_id=tenant AND employer_entity_id=employer;
type_id:=public.leave_create_type(tenant,employer,'UX-ANNUAL','إجازة سنوية للاختبار',today-20,'paid','tracked',true,'Synthetic test-only annual policy','تهيئة نوع سنوي اصطناعي لمساري السحب والرفض','working_days');
SELECT id INTO STRICT version_id FROM leave.type_versions WHERE tenant_id=tenant AND leave_type_id=type_id AND version=1;
PERFORM public.leave_post_balance(tenant,employee,employer,type_id,period,'opening',10,version_id,'ux-v10-opening','Synthetic test-only balance fixture','رصيد اصطناعي مسبق لاختبار طلب سنوي');
RAISE NOTICE 'OWNED_ANNUAL_PRECONDITIONS_READY';
END $$;
