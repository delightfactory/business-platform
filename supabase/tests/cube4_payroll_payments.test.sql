BEGIN;
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required';END IF;END $$;
SELECT no_plan();
-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4450000-0000-4000-8000-000000000001','cube4-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4450000-0000-4000-8000-000000000002','cube4-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4451000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4450000-0000-4000-8000-000000000001'),
 ('c4451000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4450000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4451000-0000-4000-8000-000000000001','c4452000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve','payroll.lock','payroll.export','payroll.payment_record','payroll.correct']),
 ('c4451000-0000-4000-8000-000000000001','c4452000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['payroll.review']);
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4451000-0000-4000-8000-000000000001','c4452000-0000-4000-8000-000000000003','qa.payroll.viewonly',1,ARRAY['payroll.view']),
 ('c4451000-0000-4000-8000-000000000001','c4452000-0000-4000-8000-000000000004','qa.payroll.recordonly',1,ARRAY['payroll.payment_record']),
 ('c4451000-0000-4000-8000-000000000001','c4452000-0000-4000-8000-000000000005','qa.payroll.recordcorrect',1,ARRAY['payroll.view','payroll.payment_record','payroll.correct']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4451000-0000-4000-8000-000000000001','c4450000-0000-4000-8000-000000000001','c4450000-0000-4000-8000-000000000001'),
 ('c4451000-0000-4000-8000-000000000001','c4450000-0000-4000-8000-000000000002','c4450000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4451000-0000-4000-8000-000000000001','c4450000-0000-4000-8000-000000000001','c4452000-0000-4000-8000-000000000001'),
 ('c4451000-0000-4000-8000-000000000001','c4450000-0000-4000-8000-000000000002','c4452000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4451000-0000-4000-8000-000000000002','c4453000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4451000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4450000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4451000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4450000-0000-4000-8000-000000000001','Cube4 QA only');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4451000-0000-4000-8000-000000000001','c4453500-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4451000-0000-4000-8000-000000000001','c4454000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','c4450000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4451000-0000-4000-8000-000000000001','c4455000-0000-4000-8000-000000000001','c4454000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4451000-0000-4000-8000-000000000001','c4456000-0000-4000-8000-000000000001','c4455000-0000-4000-8000-000000000001',3000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4451000-0000-4000-8000-000000000001','c4456500-0000-4000-8000-000000000001','c4455000-0000-4000-8000-000000000001','c4453500-0000-4000-8000-000000000001','2030-01-01');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4451000-0000-4000-8000-000000000001','c4454000-0000-4000-8000-000000000004','RUNQA2','Synthetic Second Employee','c4450000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4451000-0000-4000-8000-000000000001','c4455000-0000-4000-8000-000000000004','c4454000-0000-4000-8000-000000000004','c4453000-0000-4000-8000-000000000001','2030-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4451000-0000-4000-8000-000000000001','c4456000-0000-4000-8000-000000000004','c4455000-0000-4000-8000-000000000004',1000,'2030-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4451000-0000-4000-8000-000000000001','c4456500-0000-4000-8000-000000000004','c4455000-0000-4000-8000-000000000004','c4453500-0000-4000-8000-000000000001','2030-01-01');
CREATE FUNCTION pg_temp.approval(operation text DEFAULT 'approve',expected integer DEFAULT 1,attempt uuid DEFAULT 'c4459100-0000-4000-8000-000000000001',reason text DEFAULT 'Synthetic candidate reviewed') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_candidate_approval('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,expected,operation,reason,attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.approval(text,integer,uuid,text) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4450000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001','2030-01-25',24,25,'ending','Africa/Cairo'),'Synthetic foundation calendar')->>'period_id'),true);
SELECT public.payroll_save_input('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2030-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic proration"}','save',gen_random_uuid());
RESET ROLE;
-- Privileged test-only candidate result. No legal pack is inserted or claimed qualified.
-- This simulates an eventual trusted adapter contract solely to exercise approval/append atomicity inside ROLLBACK.
SELECT set_config('test.run','c4459200-0000-4000-8000-000000000001',true);
SELECT set_config('test.candidate','c4459200-0000-4000-8000-000000000002',true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,'draft','c4450000-0000-4000-8000-000000000001');
SELECT set_config('test.manifest',payroll.run_manifest('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT set_config('test.synthetic_output',payroll.build_review(current_setting('test.manifest')::jsonb)::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"4000"')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,0,net}','"3000"'),'{employees,0,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,1,net}','"1000"'),'{employees,1,issues}','[]'),'{employees,1,statutory_context}','{"calendar_year":2030,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2030-01","2030-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.manifest')::jsonb,current_setting('test.synthetic_output')::jsonb,'c4450000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id=current_setting('test.candidate')::uuid,revision=1 WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
SET LOCAL ROLE authenticated;
SELECT pg_temp.approval();
RESET ROLE;
SELECT set_config('test.output',payroll.append_final_output('c4451000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4450000-0000-4000-8000-000000000001',2,gen_random_uuid())::text,true);
CREATE FUNCTION pg_temp.payment(expected integer DEFAULT 0,operation text DEFAULT 'allocations',allocations jsonb DEFAULT '[{"employment_id":"c4455000-0000-4000-8000-000000000001","amount":"1000.00"}]',attempt uuid DEFAULT 'c4459400-0000-4000-8000-000000000001',reference text DEFAULT 'External bank reference',original uuid DEFAULT NULL,confirmed boolean DEFAULT true,paid_date date DEFAULT CURRENT_DATE) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_record_payment('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,expected,operation,paid_date,reference,'Synthetic external evidence only',allocations,original,confirmed,attempt)
$$;
CREATE FUNCTION pg_temp.workspace(employer uuid DEFAULT 'c4453000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_payment_workspace('c4451000-0000-4000-8000-000000000001',employer,current_setting('test.output')::uuid)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.payment(integer,text,jsonb,uuid,text,uuid,boolean,date),pg_temp.workspace(uuid) TO authenticated;
SELECT ok(NOT has_table_privilege('authenticated','payroll.payment_events','SELECT'),'payment evidence has no direct caller access');
SELECT ok(NOT has_function_privilege('service_role','payroll.payment_balances(uuid,uuid)','EXECUTE'),'service-role cannot bypass audited payment projection');
SELECT ok(NOT has_function_privilege('authenticated','payroll.output_has_ever_paid(uuid,uuid)','EXECUTE'),'historical fact is private correction foundation');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4450000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT pg_temp.workspace()$$,'42501','payroll_forbidden','review-only actor receives no final payable through payment projection');
SELECT throws_ok($$SELECT pg_temp.payment()$$,'42501','payroll_forbidden','review-only actor cannot record payment');
SELECT set_config('request.jwt.claim.sub','c4450000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$SELECT pg_temp.workspace('c4453000-0000-4000-8000-000000000003')$$,'42501','payroll_forbidden','wrong Employer cannot disclose final amounts');
SELECT throws_ok($$SELECT public.payroll_payment_workspace('c4451000-0000-4000-8000-000000000002','c4453000-0000-4000-8000-000000000002',current_setting('test.output')::uuid)$$,'42501','payroll_forbidden','cross-Tenant denied before output lookup');
SELECT is((pg_temp.workspace()->'summary'->>'payable')::numeric,4000::numeric,'payable comes from immutable scoped Employee finals');
SELECT is(pg_temp.workspace()->'summary'->>'status','unpaid','new finalized obligation initially unpaid');
SELECT throws_ok($$SELECT pg_temp.payment(allocations=>'[{"employment_id":"c4455000-0000-4000-8000-000000000001","amount":"0"}]')$$,'22023','payroll_payment_invalid','zero new payment refused');
SELECT throws_ok($$SELECT pg_temp.payment(allocations=>'[{"employment_id":"c4455000-0000-4000-8000-000000000001","amount":"-1.00"}]')$$,'22023','payroll_payment_invalid','negative new payment refused');
SELECT throws_ok($$SELECT pg_temp.payment(allocations=>'[{"employment_id":"c4455000-0000-4000-8000-000000000001","amount":"3000.01"}]')$$,'23514','payroll_payment_excess','Employee excess refused even if run has sufficient remaining');
SELECT throws_ok($$SELECT pg_temp.payment(allocations=>'[{"employment_id":"c4455000-0000-4000-8000-000000000001","amount":"0.005"}]')$$,'22023','payroll_payment_invalid','payment fractions beyond exact cents refused');
SELECT throws_ok($$SELECT pg_temp.payment(allocations=>'[{"employment_id":"c4455000-0000-4000-8000-000000000009","amount":"1.00"}]')$$,'42501','payroll_forbidden','foreign Employee allocation refused without balances');
SELECT throws_ok($$SELECT pg_temp.payment(allocations=>'[{"employment_id":"c4455000-0000-4000-8000-000000000001","amount":"1"},{"employment_id":"c4455000-0000-4000-8000-000000000001","amount":"2"}]')$$,'22023','payroll_payment_invalid','duplicate Employee allocation is not silently combined');
SELECT throws_ok($$SELECT pg_temp.payment(confirmed=>false)$$,'22023','payroll_payment_invalid','external payment attestation mandatory');
SELECT throws_ok($$SELECT pg_temp.payment(paid_date=>CURRENT_DATE+2)$$,'22023','payroll_payment_invalid','future external payment evidence refused');
SELECT set_config('test.first_payment',pg_temp.payment()::text,true);
SELECT is(pg_temp.payment(),current_setting('test.first_payment')::jsonb,'identical attempt replay returns original payment receipt');
SELECT is(pg_temp.payment(allocations=>'[{"amount":"1000","employment_id":"C4455000-0000-4000-8000-000000000001"}]'),current_setting('test.first_payment')::jsonb,'canonical cents UUID casing and key order preserve exact intent');
SELECT throws_ok($$SELECT pg_temp.payment(reference=>'Changed bank reference')$$,'PT409','payroll_attempt_conflict','altered same-attempt evidence rejected');
SELECT throws_ok($$SELECT pg_temp.payment(attempt=>gen_random_uuid())$$,'PT409','payroll_payment_stale','competing same-revision request cannot add payment');
SELECT is(pg_temp.workspace()->'summary'->>'status','partially_paid','partial allocation produces meaningful run state');
SELECT is((pg_temp.workspace()->'employees'->0->>'remaining')::numeric,2000::numeric,'partial allocation affects exactly selected Employee');
SELECT is((pg_temp.workspace()->'employees'->1->>'remaining')::numeric,1000::numeric,'unselected Employee remains fully outstanding');
SELECT is(pg_temp.workspace()->'history'->0->>'actor_label','cube4-manager@test.invalid','history attributes payment actor');
SELECT is((public.payroll_payment_workspace('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,p_event=>(current_setting('test.first_payment')::jsonb->>'event_id')::uuid)->'employees'->0->>'entry_amount')::numeric,1000::numeric,'bounded entry detail shows attributable exact Employee allocation');
SELECT throws_ok($$SELECT public.payroll_payment_workspace('c4451000-0000-4000-8000-000000000001','c4453000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,p_event=>'c4459400-0000-4000-8000-000000000009')$$,'42501','payroll_forbidden','unscoped payment entry detail cannot disclose amounts');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM payroll.payment_events WHERE tenant_id='c4451000-0000-4000-8000-000000000001'),1,'replay never appends a second event');
SELECT ok(EXISTS(SELECT 1 FROM payroll.audit_events WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND action='payment_workspace_access'),'financial payment access is audited');
CREATE FUNCTION pg_temp.reject_payment_access_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='payment_workspace_access' THEN RAISE EXCEPTION 'qa_payment_access_audit_failure' USING ERRCODE='P0001';END IF;RETURN NEW;END $$;
CREATE TRIGGER qa_payment_access_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_payment_access_audit();
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.workspace()$$,'P0001','qa_payment_access_audit_failure','protected payment amounts are not returned when mandatory access audit fails');
RESET ROLE;
DROP TRIGGER qa_payment_access_audit_failure ON payroll.audit_events;
UPDATE platform_core.membership_roles SET role_id='c4452000-0000-4000-8000-000000000003' WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND user_id='c4450000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT pg_temp.workspace()$$,'view-only actor may read audited reconciliation');
SELECT throws_ok($$SELECT pg_temp.payment()$$,'42501','payroll_forbidden','current permission loss checked before successful receipt replay');
RESET ROLE;
UPDATE platform_core.membership_roles SET role_id='c4452000-0000-4000-8000-000000000004' WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND user_id='c4450000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT lives_ok($$SELECT pg_temp.workspace()$$,'payment-only actor gets narrow audited task projection without general review');
SELECT is((public.payroll_payment_access('c4451000-0000-4000-8000-000000000001')->>'can_correct_record')::boolean,false,'payment recorder is not implicitly correction actor');
SELECT throws_ok($$SELECT pg_temp.payment(expected=>1,operation=>'compensate',allocations=>'[]',attempt=>gen_random_uuid(),original=>(current_setting('test.first_payment')::jsonb->>'event_id')::uuid)$$,'42501','payroll_forbidden','wrong-record correction requires separate current correction authority');
RESET ROLE;
UPDATE platform_core.membership_roles SET role_id='c4452000-0000-4000-8000-000000000005' WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND user_id='c4450000-0000-4000-8000-000000000001';
CREATE FUNCTION pg_temp.reject_payment_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='payment_remaining' THEN RAISE EXCEPTION 'qa_payment_audit_failure' USING ERRCODE='P0001';END IF;RETURN NEW;END $$;
CREATE TRIGGER qa_payment_audit_failure BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_payment_audit();
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.payment(expected=>1,operation=>'remaining',allocations=>'[]',attempt=>'c4459400-0000-4000-8000-000000000002')$$,'P0001','qa_payment_audit_failure','missing mandatory audit rolls back payment event/allocations/CAS/receipt');
RESET ROLE;
DROP TRIGGER qa_payment_audit_failure ON payroll.audit_events;
SELECT is((SELECT revision FROM payroll.payment_heads WHERE tenant_id='c4451000-0000-4000-8000-000000000001'),1,'audit failure restores payment revision');
SELECT is((SELECT count(*)::int FROM payroll.payment_events WHERE tenant_id='c4451000-0000-4000-8000-000000000001'),1,'audit failure leaves no new event');
SELECT is((SELECT count(*)::int FROM payroll.payment_allocations WHERE tenant_id='c4451000-0000-4000-8000-000000000001'),1,'audit failure leaves no new allocations');
SELECT ok(NOT EXISTS(SELECT 1 FROM payroll.command_receipts WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND attempt_key='c4459400-0000-4000-8000-000000000002'),'audit failure leaves no success receipt');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND capability_key='hr.payroll';
SET LOCAL ROLE authenticated;
SELECT set_config('test.remaining_payment',pg_temp.payment(expected=>1,operation=>'remaining',allocations=>'[]',attempt=>'c4459400-0000-4000-8000-000000000002')::text,true);
SELECT is((current_setting('test.remaining_payment')::jsonb->>'amount')::numeric,3000::numeric,'entitlement-loss closure records only all remaining existing final allocations');
SELECT is(pg_temp.workspace()->'summary'->>'status','paid','full remaining reconciles run exactly');
SELECT is((pg_temp.workspace()->'summary'->>'remaining')::numeric,0::numeric,'paid obligation has zero remaining');
SELECT throws_ok($$SELECT pg_temp.payment(expected=>2,operation=>'remaining',allocations=>'[]',attempt=>gen_random_uuid())$$,'23514','payroll_payment_complete','no second full-remaining payment when all Employees paid');
SELECT set_config('test.compensation',pg_temp.payment(expected=>2,operation=>'compensate',allocations=>'[]',original=>(current_setting('test.first_payment')::jsonb->>'event_id')::uuid,attempt=>'c4459400-0000-4000-8000-000000000003')::text,true);
SELECT is((current_setting('test.compensation')::jsonb->>'amount')::numeric,1000::numeric,'mistaken-record correction compensates complete original allocations only');
SELECT is((pg_temp.workspace()->'summary'->>'remaining')::numeric,1000::numeric,'corrected mistaken recording restores remaining obligation without changing final payable');
RESET ROLE;
UPDATE platform_core.membership_roles SET role_id='c4452000-0000-4000-8000-000000000004' WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND user_id='c4450000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.payment(expected=>2,operation=>'compensate',allocations=>'[]',original=>(current_setting('test.first_payment')::jsonb->>'event_id')::uuid,attempt=>'c4459400-0000-4000-8000-000000000003')$$,'42501','payroll_forbidden','correction permission loss checked before compensation receipt replay');
RESET ROLE;
UPDATE platform_core.membership_roles SET role_id='c4452000-0000-4000-8000-000000000005' WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND user_id='c4450000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.payment(expected=>2,operation=>'compensate',allocations=>'[]',original=>(current_setting('test.first_payment')::jsonb->>'event_id')::uuid,attempt=>'c4459400-0000-4000-8000-000000000003'),current_setting('test.compensation')::jsonb,'restored current authority recovers original compensation outcome without repeat');
SELECT throws_ok($$SELECT pg_temp.payment(expected=>3,operation=>'compensate',allocations=>'[]',original=>(current_setting('test.first_payment')::jsonb->>'event_id')::uuid,attempt=>gen_random_uuid())$$,'23514','payroll_payment_compensated','same original cannot be compensated twice');
SELECT pg_temp.payment(expected=>3,operation=>'compensate',allocations=>'[]',original=>(current_setting('test.remaining_payment')::jsonb->>'event_id')::uuid,attempt=>gen_random_uuid());
SELECT is((pg_temp.workspace()->'summary'->>'paid')::numeric,0::numeric,'fully compensated history reconciles currently recorded paid to zero');
SELECT is((pg_temp.workspace()->'summary'->>'payable')::numeric,4000::numeric,'mistaken-payment correction never changes immutable payable');
SELECT is((pg_temp.workspace()->'summary'->>'ever_paid')::boolean,true,'compensation to zero never erases ever-paid history');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM payroll.payment_events WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND kind='payment'),2,'original historical payment evidence retained');
SELECT ok(payroll.output_has_ever_paid('c4451000-0000-4000-8000-000000000001',current_setting('test.output')::uuid),'authoritative correction-route fact stays paid after compensation');
-- Privileged synthetic replacement solely exercises the private succession guard. No public lock exists.
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) SELECT tenant_id,employer_id,period_id,'c4459200-0000-4000-8000-000000000007','cancelled',created_by FROM payroll.runs WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) SELECT tenant_id,employer_id,'c4459200-0000-4000-8000-000000000007','c4459200-0000-4000-8000-000000000009',1,'NONLEGAL ROLLBACK SUCCESSION FIXTURE',input_manifest,output,created_by FROM payroll.candidates WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND id=current_setting('test.candidate')::uuid;
INSERT INTO payroll.approval_events(tenant_id,id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason) SELECT tenant_id,'c4459200-0000-4000-8000-000000000008',employer_id,'c4459200-0000-4000-8000-000000000007','c4459200-0000-4000-8000-000000000009','approve',1,actor_id,'NONLEGAL ROLLBACK SUCCESSION FIXTURE' FROM payroll.approval_events WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND id=(SELECT approval_id FROM payroll.final_contexts WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND id=current_setting('test.output')::uuid);
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by) SELECT tenant_id,'c4459500-0000-4000-8000-000000000001',employer_id,period_id,'c4459200-0000-4000-8000-000000000007','c4459200-0000-4000-8000-000000000009','c4459200-0000-4000-8000-000000000008',legal_employer,period_snapshot,manifest,result,'NONLEGAL ROLLBACK SUCCESSION FIXTURE',finalized_by FROM payroll.final_contexts WHERE tenant_id='c4451000-0000-4000-8000-000000000001' AND id=current_setting('test.output')::uuid;
SELECT throws_ok($$INSERT INTO payroll.output_successions VALUES('c4451000-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'c4459500-0000-4000-8000-000000000001','c4450000-0000-4000-8000-000000000001','Cannot replace historically paid run',now())$$,'23514','payroll_paid_correction_route_required','ever-paid forbids replacement even after all recordings compensated');
SELECT throws_ok($$UPDATE payroll.payment_events SET reason='Rewrite history' WHERE tenant_id='c4451000-0000-4000-8000-000000000001'$$,'55000','payroll_immutable','payment evidence immutable');
SELECT throws_ok($$DELETE FROM payroll.payment_allocations WHERE tenant_id='c4451000-0000-4000-8000-000000000001'$$,'55000','payroll_immutable','payment allocations cannot be erased');
SET LOCAL ROLE authenticated;
SELECT is((pg_temp.payment(expected=>4,attempt=>gen_random_uuid(),reference=>'New real external evidence')->>'remaining')::numeric,3000::numeric,'new real payment can be recorded after wrong-record compensation with explicit fresh evidence');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
