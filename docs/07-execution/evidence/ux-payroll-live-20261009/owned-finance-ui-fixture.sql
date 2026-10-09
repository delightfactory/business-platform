BEGIN;
DO $$ BEGIN
 IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' THEN RAISE EXCEPTION 'owned QA only'; END IF;
 IF (select count(*) from auth.users)<>2 THEN RAISE EXCEPTION 'expected synthetic actors only'; END IF;
 IF NOT EXISTS(select 1 from auth.users where id='f9100000-0000-4000-8000-000000000001' and email='ux-self@example.test') THEN RAISE EXCEPTION 'wrong synthetic actor'; END IF;
 IF EXISTS(select 1 from payroll.periods where tenant_id='f5100000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'financial fixture already exists'; END IF;
END $$;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES('f5100000-0000-4000-8000-000000000001','f7120000-0000-4000-8000-000000000001','ux.synthetic.payroll.manager',1,ARRAY['payroll.view','payroll_config.manage','payroll.prepare','payroll.review','payroll.approve','payroll.lock','payroll.correct','payroll.export','payroll.payment_record']);
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES('f5100000-0000-4000-8000-000000000001','f9100000-0000-4000-8000-000000000001','f7120000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES('f5100000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','f9100000-0000-4000-8000-000000000001','Owned synthetic UX payroll qualification; no statutory verification implied');
COMMIT;
