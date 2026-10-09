
DO $$ DECLARE tenant uuid:='f5100000-0000-4000-8000-000000000001';manager uuid:='f9100000-0000-4000-8000-000000000001';employee_user uuid:='f9200000-0000-4000-8000-000000000002';employer uuid:='f5130000-0000-4000-8000-000000000001';calendar uuid;period uuid;type_id uuid;today date:=(now() at time zone 'Africa/Cairo')::date; BEGIN
IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' OR (select count(*) from auth.users)<>2 THEN RAISE EXCEPTION 'owned synthetic QA only'; END IF;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES(tenant,'f6120000-0000-4000-8000-000000000001','ux.synthetic.leave.hr',1,ARRAY['leave.manage','leave.view','leave.approve','leave_balance.adjust']),(tenant,'f6120000-0000-4000-8000-000000000002','ux.synthetic.leave.self',1,ARRAY['leave.self.view','leave.self.request']);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(tenant,manager,'f6120000-0000-4000-8000-000000000001'),(tenant,employee_user,'f6120000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES(tenant,'hr.leave',true,now()-interval '1 minute',manager,'Owned synthetic UX Leave qualification');
PERFORM set_config('request.jwt.claim.sub',manager::text,true);
calendar:=public.leave_create_calendar(tenant,employer,'UX-LEAVE','تقويم الاختبار المحلي',today-20,NULL,ARRAY[5,6]::smallint[],'[]'::jsonb,'Synthetic test-only working calendar','تهيئة تقويم اصطناعي للاختبار');
period:=public.leave_create_year_period(tenant,employer,calendar,today-10,today+60,'فترة الاختبار المحلي','فترة اصطناعية لاختبار الواجهة');
type_id:=public.leave_create_type(tenant,employer,'UX-UNPAID','إجازة اختبار بدون أجر',today-20,'unpaid','untracked',true,'Synthetic test-only policy','نوع اصطناعي لاختبار الطلب والمراجعة','working_days');
INSERT INTO platform_private.platform_operator_grants(user_id,is_active,can_manage_operators,can_onboard_tenants,can_manage_tenant_lifecycle,can_manage_commercial_access) VALUES(manager,true,true,true,true,true);
RAISE NOTICE 'OWNED_GROUPED_LEAVE_FIXTURE_READY'; END $$;
