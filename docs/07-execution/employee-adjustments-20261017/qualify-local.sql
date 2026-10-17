\set ON_ERROR_STOP on
BEGIN;
DO $test$
DECLARE t uuid:='444dbbab-b569-47ca-beae-2bacbce266c6'; actor uuid:='56a6a503-0080-41ec-9a53-f513cab323fb';
 employer uuid:='abd43fa7-5025-4385-a471-2ae74ad15488'; employee uuid:='774d7c16-f63d-40b0-823f-0b55bc60431e';
 employment uuid:='66d9b313-a1b4-4295-b1ea-431147a1041e'; period uuid:='305df214-1234-48a0-85ea-cc277fbb5375';
 component jsonb; command jsonb; replay jsonb; approved jsonb; fields jsonb; workspace jsonb; review jsonb;
 attempt uuid:=gen_random_uuid(); other_command jsonb; run_id uuid; reader_actor uuid:=gen_random_uuid(); reader_role uuid:=gen_random_uuid();
BEGIN
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenants WHERE id=t) THEN RAISE EXCEPTION 'Owned synthetic fixture required'; END IF;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 workspace:=public.people_employee_adjustments(t,employee);
 IF workspace->'period'->>'id'<>period::text THEN RAISE EXCEPTION 'Current period not selected'; END IF;
 component:=public.payroll_save_input(t,employer,'component',NULL,NULL,NULL,0,'2026-10-01',NULL,
  '{"key":"qa_profile_reward","name":"مكافأة اختبار الملف","classification":"earning","calculation":"fixed","base":"","value":"0","taxable":"true","social":"false","visible":"true","active":"true","order":"100","behavior":"period_input","proration":"paid_full_period","reason":"اختبار محلي فقط"}',
  'save',gen_random_uuid());
 fields:=jsonb_build_object('component_id',component->>'id','amount','500','reason','مكافأة اختبار محلي','reference','تسجيل من ملف الموظف');
 command:=public.payroll_save_input(t,employer,'adjustment',employment,period,NULL,0,'2026-10-01','2026-11-01',fields,'save',attempt);
 replay:=public.payroll_save_input(t,employer,'adjustment',employment,period,NULL,0,'2026-10-01','2026-11-01',fields,'save',attempt);
 IF command<>replay THEN RAISE EXCEPTION 'Receipt replay duplicated command'; END IF;
 review:=payroll.build_review(payroll.run_manifest(t,employer,period));
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(review->'employees')e CROSS JOIN LATERAL jsonb_array_elements(e->'lines')l WHERE l->>'component'='adjustment:'||(command->>'id')) THEN RAISE EXCEPTION 'Draft entered calculation'; END IF;
 approved:=public.payroll_save_input(t,employer,'adjustment',employment,period,(command->>'id')::uuid,1,'2026-10-01','2026-11-01',fields,'approve',gen_random_uuid());
 review:=payroll.build_review(payroll.run_manifest(t,employer,period));
 IF (SELECT count(*) FROM jsonb_array_elements(review->'employees')e CROSS JOIN LATERAL jsonb_array_elements(e->'lines')l WHERE e->>'employment_id'=employment::text AND l->>'component'='adjustment:'||(command->>'id') AND (l->>'amount')::numeric=500)<>1 THEN RAISE EXCEPTION 'Approved reward not included exactly once'; END IF;
 other_command:=public.payroll_save_input(t,employer,'adjustment','8838af47-3428-4cf1-a651-7c50cdfe5737',period,NULL,0,'2026-10-01','2026-11-01',fields,'save',gen_random_uuid());
 workspace:=public.people_employee_adjustments(t,employee,period,NULL,NULL,(other_command->>'id')::uuid);
 IF workspace->'focused_record'<>'null'::jsonb OR EXISTS(SELECT 1 FROM jsonb_array_elements(workspace->'records')r WHERE r->>'employment_id'<>employment::text) THEN RAISE EXCEPTION 'Other employee leaked'; END IF;
 workspace:=public.people_employee_adjustments(t,employee,period,NULL,NULL,(command->>'id')::uuid);
 IF workspace->'focused_record'->>'status'<>'approved' THEN RAISE EXCEPTION 'Approved status missing'; END IF;
 BEGIN
  PERFORM public.people_employee_adjustments(t,employee,gen_random_uuid());
  RAISE EXCEPTION 'Wrong period accepted';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
 BEGIN
  PERFORM public.people_employee_adjustments(gen_random_uuid(),employee,period);
  RAISE EXCEPTION 'Other tenant accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.payroll_save_input(t,employer,'adjustment',employment,period,(command->>'id')::uuid,1,'2026-10-01','2026-11-01',fields,'approve',gen_random_uuid());
  RAISE EXCEPTION 'Stale revision accepted';
 EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
 PERFORM public.payroll_save_input(t,employer,'adjustment',employment,period,(command->>'id')::uuid,2,'2026-10-01','2026-11-01',fields,'cancel',gen_random_uuid());
 review:=payroll.build_review(payroll.run_manifest(t,employer,period));
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(review->'employees')e CROSS JOIN LATERAL jsonb_array_elements(e->'lines')l WHERE l->>'component'='adjustment:'||(command->>'id')) THEN RAISE EXCEPTION 'Cancelled reward still included'; END IF;
 component:=public.payroll_save_input(t,employer,'component',NULL,NULL,NULL,0,'2026-10-01',NULL,
  '{"key":"qa_profile_penalty","name":"جزاء اختبار الملف","classification":"deduction","calculation":"fixed","base":"","value":"0","taxable":"false","social":"false","visible":"true","active":"true","order":"100","behavior":"period_input","proration":"paid_full_period","reason":"اختبار محلي فقط"}',
  'save',gen_random_uuid());
 fields:=jsonb_build_object('component_id',component->>'id','amount','100','reason','جزاء اختبار محلي','reference','تسجيل من ملف الموظف','deduction_category','employer_penalty');
 command:=public.payroll_save_input(t,employer,'adjustment',employment,period,NULL,0,'2026-10-01','2026-11-01',fields,'save',gen_random_uuid());
 PERFORM public.payroll_save_input(t,employer,'adjustment',employment,period,(command->>'id')::uuid,1,'2026-10-01','2026-11-01',fields,'approve',gen_random_uuid());
 review:=payroll.build_review(payroll.run_manifest(t,employer,period));
 IF (SELECT count(*) FROM jsonb_array_elements(review->'employees')e CROSS JOIN LATERAL jsonb_array_elements(e->'lines')l WHERE e->>'employment_id'=employment::text AND l->>'component'='adjustment:'||(command->>'id') AND l->>'classification'='deduction' AND (l->>'amount')::numeric=100)<>1 THEN RAISE EXCEPTION 'Approved penalty not included once'; END IF;
 SELECT id INTO run_id FROM payroll.runs WHERE tenant_id=t AND employer_id=employer AND period_id=period LIMIT 1;
 IF run_id IS NULL THEN RAISE EXCEPTION 'Existing synthetic run required'; END IF;
 INSERT INTO payroll.people_frozen_contexts(tenant_id,employer_id,employment_id,period_id,run_id,source_snapshot) VALUES(t,employer,employment,period,run_id,'{}');
 workspace:=public.people_employee_adjustments(t,employee,period);
 IF workspace->>'locked'<>'true' THEN RAISE EXCEPTION 'Frozen state not projected'; END IF;
 BEGIN
  PERFORM public.payroll_save_input(t,employer,'adjustment',employment,period,NULL,0,'2026-10-01','2026-11-01',fields,'save',gen_random_uuid());
  RAISE EXCEPTION 'Frozen period accepted new adjustment';
 EXCEPTION WHEN check_violation THEN NULL; END;
 INSERT INTO auth.users(id,email,email_confirmed_at,aud,role,created_at,updated_at) VALUES(reader_actor,reader_actor::text||'@test.invalid',now(),'authenticated','authenticated',now(),now());
 INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES(t,reader_role,'qa.profile.reader',1,ARRAY['people.view']);
 INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES(t,reader_actor,actor);
 INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(t,reader_actor,reader_role);
 PERFORM set_config('request.jwt.claim.sub',reader_actor::text,true);
 PERFORM public.people_employee_snapshot(t,employee);
 BEGIN
  PERFORM public.people_employee_adjustments(t,employee,period);
  RAISE EXCEPTION 'People-only reader accessed financial adjustments';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN
  PERFORM public.people_employee_adjustments(t,employee,period);
  RAISE EXCEPTION 'Unauthenticated read accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF has_function_privilege('anon','public.people_employee_adjustments(uuid,uuid,uuid,date,uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous execute granted'; END IF;
 RAISE NOTICE 'PASS: current period, draft exclusion, receipt replay, approved reward/penalty each once, employee/focus isolation, period/tenant denial, stale rejection, cancellation exclusion, frozen read/write, people-only financial denial, anonymous denial/ACL';
END $test$;
ROLLBACK;
