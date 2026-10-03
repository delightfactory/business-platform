BEGIN;
DO $$ BEGIN IF current_database() NOT IN('business_platform_cube4_upgrade_qa','business_platform_cube4_fresh_qa') THEN RAISE EXCEPTION 'Cube4 dedicated QA identity required';END IF;END $$;
SELECT no_plan();
-- Privileged NONLEGAL fixture links its FK through the real lifecycle trigger, never disabling it.
CREATE FUNCTION pg_temp.link_fixture_correction(p_case uuid,p_proposal uuid,p_status text) RETURNS void LANGUAGE plpgsql SET search_path='' AS $fixture$
BEGIN
 IF p_status NOT IN('approved','routed') THEN RAISE EXCEPTION 'invalid_fixture_status';END IF;
 UPDATE payroll.correction_cases SET proposal_id=p_proposal,revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;
 UPDATE payroll.correction_cases SET status='review',revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;
 UPDATE payroll.correction_cases SET status='approved',revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;
 IF p_status='routed' THEN UPDATE payroll.correction_cases SET status='routed',revision=revision+1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=p_case;END IF;
END $fixture$;

-- New Payroll-only synthetic actors and tenants; all changes are rolled back.
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
 ('c4470000-0000-4000-8000-000000000001','cube4-advance-manager@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now()),
 ('c4470000-0000-4000-8000-000000000002','cube4-advance-reader@test.invalid','x',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id) VALUES
 ('c4471000-0000-4000-8000-000000000001','Cube4 synthetic Payroll QA','c4470000-0000-4000-8000-000000000001'),
 ('c4471000-0000-4000-8000-000000000002','Cube4 synthetic other Tenant','c4470000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000001','qa.payroll.manager',1,ARRAY['payroll.view','payroll.prepare','payroll_config.manage','payroll.review','payroll.approve','payroll.lock','payroll.export','payroll.payment_record','payroll.correct','employee_finance.view','employee_finance.manage','employee_finance.approve']),
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000002','qa.payroll.reader',1,ARRAY['employee_finance.view']);
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000003','qa.payroll.viewonly',1,ARRAY['payroll.view']),
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000004','qa.payroll.recordonly',1,ARRAY['payroll.payment_record']),
 ('c4471000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000005','qa.payroll.recordcorrect',1,ARRAY['payroll.view','payroll.payment_record','payroll.correct','employee_finance.view','employee_finance.manage','employee_finance.approve']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000001'),
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000002','c4470000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000001','c4472000-0000-4000-8000-000000000001'),
 ('c4471000-0000-4000-8000-000000000001','c4470000-0000-4000-8000-000000000002','c4472000-0000-4000-8000-000000000002');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,legal_name) VALUES
 ('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','Payroll Employer A','Payroll Employer A'),
 ('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','Payroll Employer B','Payroll Employer B'),
 ('c4471000-0000-4000-8000-000000000002','c4473000-0000-4000-8000-000000000002','Other Tenant Employer','Other Tenant Employer');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES
 ('c4471000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','c4470000-0000-4000-8000-000000000001','Cube4 QA only'),
 ('c4471000-0000-4000-8000-000000000001','hr.payroll',true,now()-interval '1 minute','c4470000-0000-4000-8000-000000000001','Cube4 QA only');
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4471000-0000-4000-8000-000000000001','c4473500-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','Candidate synthetic site',true);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4471000-0000-4000-8000-000000000001','c4474000-0000-4000-8000-000000000001','RUNQA','Synthetic Monthly Employee','c4470000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4471000-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000001','c4474000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','2020-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476000-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000001',3000,'2020-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476500-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000001','c4473500-0000-4000-8000-000000000001','2020-01-01');
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4471000-0000-4000-8000-000000000001','c4474000-0000-4000-8000-000000000004','RUNQA2','Synthetic Second Employee','c4470000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4471000-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000004','c4474000-0000-4000-8000-000000000004','c4473000-0000-4000-8000-000000000001','2020-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476000-0000-4000-8000-000000000004','c4475000-0000-4000-8000-000000000004',1000,'2020-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476500-0000-4000-8000-000000000004','c4475000-0000-4000-8000-000000000004','c4473500-0000-4000-8000-000000000001','2020-01-01');

INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason) VALUES('c4471000-0000-4000-8000-000000000001','hr.employee_finance',true,now()-interval '1 minute','c4470000-0000-4000-8000-000000000001','Slice7 synthetic Finance only');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c4470000-0000-4000-8000-000000000001',true);
SELECT set_config('test.period',(public.payroll_save_calendar('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','2020-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','2020-01-25',24,25,'ending','Africa/Cairo'),'Synthetic Finance schedule')->>'period_id'),true);
SELECT public.payroll_generate_next_period('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',1,gen_random_uuid(),(public.payroll_workspace('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001')->'next_preview'));
SELECT public.payroll_generate_next_period('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',2,gen_random_uuid(),(public.payroll_workspace('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001')->'next_preview'));
SELECT public.payroll_generate_next_period('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',3,gen_random_uuid(),(public.payroll_workspace('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001')->'next_preview'));
SELECT public.payroll_save_input('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','policy',NULL,NULL,NULL,0,'2020-01-01',NULL,'{"mode":"calendar_days","reason":"Synthetic policy"}','save',gen_random_uuid());
RESET ROLE;
SELECT set_config('test.future_period',(SELECT id::text FROM payroll.periods WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND starts_on='2020-04-25'),true);
CREATE FUNCTION pg_temp.intent(op text,expected integer,data jsonb DEFAULT '{}',aid uuid DEFAULT 'c4478000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('operation',op,'advance',aid,'employment','c4475000-0000-4000-8000-000000000001','expected',expected,'data',CASE WHEN op='save' THEN jsonb_build_object('principal','100.00','count','3','first_period',current_setting('test.period'),'effective_on','2020-01-25','reason','Synthetic principal schedule')||data ELSE jsonb_build_object('reference','Synthetic external evidence','reason','Reviewed synthetic operation','confirmed','yes','date',CURRENT_DATE::text)||data END)
$$;
CREATE FUNCTION pg_temp.command(op text,expected integer,data jsonb DEFAULT '{}',attempt uuid DEFAULT NULL,aid uuid DEFAULT 'c4478000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_advance_command('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',pg_temp.intent(op,expected,data,aid),COALESCE(attempt,gen_random_uuid()))
$$;
CREATE FUNCTION pg_temp.resolve(op text,expected integer,data jsonb DEFAULT '{}',attempt uuid DEFAULT NULL,aid uuid DEFAULT 'c4478000-0000-4000-8000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_resolve_advance_attempt('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',pg_temp.intent(op,expected,data,aid),attempt)
$$;
GRANT EXECUTE ON FUNCTION pg_temp.intent(text,integer,jsonb,uuid),pg_temp.command(text,integer,jsonb,uuid,uuid),pg_temp.resolve(text,integer,jsonb,uuid,uuid) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('save',0)->>'status','draft','principal starts as a draft without obligation');
RESET ROLE;
SELECT is(payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001'),0::numeric,'draft has no disbursement debt');
SELECT is((SELECT array_agg(amount ORDER BY ordinal) FROM payroll.advance_installments WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),ARRAY[33.33,33.33,33.34]::numeric[],'integer cents put exact remainder in final installment');
SELECT is((SELECT sum(amount) FROM payroll.advance_installments WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),100.00::numeric,'schedule exactly reconciles principal');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.command('activate',1)$$,'23514','finance_activation_blocked','external activation requires approval');
SELECT is(pg_temp.command('approve',1,'{}','c4479000-0000-4000-8000-000000000001')->>'status','approved','approved schedule still waits external disbursement');
SELECT is(pg_temp.command('approve',1,'{}','c4479000-0000-4000-8000-000000000001')->>'revision','2','approval receipt replay does not duplicate revision');
SELECT is(pg_temp.command('activate',2)->>'outstanding','100.00','external evidence activates exact principal');
SELECT throws_ok($$SELECT pg_temp.command('cancel',3)$$,'23514','finance_cancel_blocked','cannot cancel responsibility after disbursement');
SELECT throws_ok($$SELECT pg_temp.command('save',3)$$,'23514','finance_schedule_immutable','active principal and schedule are immutable');
SELECT throws_ok($$SELECT pg_temp.command('settle',3,'{"amount":"100.01"}')$$,'23514','finance_settlement_excess','no negative loan balance');
SELECT is(pg_temp.command('settle',3,'{"amount":"40.00"}')->>'outstanding','60.00','partial external settlement reduces only evidenced amount');
RESET ROLE;
SELECT set_config('test.settlement',(SELECT id::text FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND kind='settlement'),true);
SELECT is((SELECT array_agg(payroll.installment_remaining(tenant_id,id) ORDER BY ordinal) FROM payroll.advance_installments WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),ARRAY[0,26.66,33.34]::numeric[],'early settlement allocation is deterministic oldest installment first');
SELECT throws_ok($$UPDATE payroll.advance_events SET delta=0 WHERE id=current_setting('test.settlement')::uuid$$,'55000','payroll_immutable','settlement evidence cannot be rewritten');
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('compensate',4,jsonb_build_object('original',current_setting('test.settlement')))->>'outstanding','100.00','compensating correction restores original balance without deleting evidence');
SELECT throws_ok($$SELECT pg_temp.command('compensate',5,jsonb_build_object('original',current_setting('test.settlement')))$$,'23514','finance_compensation_invalid','same mistaken settlement cannot be compensated twice');
SELECT is(pg_temp.command('settle',5,'{"amount":"100.00"}')->>'status','settled','settled is derived from explained zero ledger balance');
RESET ROLE;
SELECT set_config('test.whole_settlement',(SELECT id::text FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND kind='settlement' AND delta=-100),true);
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('compensate',6,jsonb_build_object('original',current_setting('test.whole_settlement')))->>'status','active','compensation reopens derived nonzero status');
RESET ROLE;
SELECT set_config('test.second_installment',(SELECT id::text FROM payroll.advance_installments WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND ordinal=2),true);
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('defer',7,jsonb_build_object('installment',current_setting('test.second_installment'),'target_period',current_setting('test.future_period')))->>'outstanding','100.00','reviewed deferral preserves entire debt');
RESET ROLE;
UPDATE people.employments SET end_date='2020-05-10',employment_status='ended' WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id='c4475000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('termination',8)->>'outstanding','100.00','termination review records responsibility without forgiveness');
RESET ROLE;
UPDATE platform_core.tenant_capability_entitlements SET is_granted=false WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND capability_key='hr.employee_finance';
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('settle',9,'{"amount":"10.00"}')->>'outstanding','90.00','authorized existing obligation closes after entitlement loss');
SELECT throws_ok($$SELECT pg_temp.command('save',0,'{}',NULL,'c4478000-0000-4000-8000-000000000002')$$,'55000','finance_disabled','disabled Finance cannot create new obligation');
RESET ROLE;
SELECT ok(jsonb_array_length(payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->'advances')>0,'existing active obligation remains visible when optional Finance disabled');
UPDATE platform_core.tenant_capability_entitlements SET is_granted=true WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND capability_key='hr.employee_finance';
SET LOCAL ROLE authenticated;
-- Writer-first resolution models committed but lost whole Server Action response.
SELECT pg_temp.command('save',0,'{}','c4479100-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','c4470000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT pg_temp.resolve('save',0,'{}','c4479100-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000002')$$,'42501','payroll_forbidden','reader cannot resolve original mutation authority');
SELECT set_config('request.jwt.claim.sub','c4470000-0000-4000-8000-000000000001',true);
SELECT is(pg_temp.resolve('save',0,'{}','c4479100-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000002')->>'resolution','committed','restored authority recovers committed original receipt');
SELECT throws_ok($$SELECT pg_temp.resolve('save',0,'{"principal":"200.00"}','c4479100-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000002')$$,'PT409','payroll_attempt_conflict','receipt recovery cannot change original principal');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.advance_versions WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000002'),1::bigint,'committed recovery has exactly one source version');
SELECT is((SELECT count(*) FROM payroll.command_receipts WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND attempt_key='c4479100-0000-4000-8000-000000000001'),1::bigint,'committed recovery has one receipt');
SET LOCAL ROLE authenticated;
-- Rejected request response-loss must not strand the journal: authority-bound absence closes it.
SELECT throws_ok($$SELECT pg_temp.command('save',0,'{"principal":"-1"}','c4479100-0000-4000-8000-000000000002','c4478000-0000-4000-8000-000000000003')$$,'22023','finance_invalid','invalid mutation rolls back before receipt');
SELECT is(pg_temp.resolve('save',0,'{"principal":"-1"}','c4479100-0000-4000-8000-000000000002','c4478000-0000-4000-8000-000000000003')->>'resolution','closed_without_commit','lost validation response has durable definitive absence proof');
SELECT throws_ok($$SELECT pg_temp.command('save',0,'{"principal":"-1"}','c4479100-0000-4000-8000-000000000002','c4478000-0000-4000-8000-000000000003')$$,'PT409','finance_attempt_closed','delayed original cannot commit after journal release');
SELECT is(pg_temp.resolve('save',0,'{"principal":"-1"}','c4479100-0000-4000-8000-000000000002','c4478000-0000-4000-8000-000000000003')->>'resolution','closed_without_commit','absence resolution itself is idempotent');
SELECT throws_ok($$SELECT pg_temp.resolve('save',0,'{"principal":"200.00"}','c4479100-0000-4000-8000-000000000002','c4478000-0000-4000-8000-000000000003')$$,'PT409','payroll_attempt_conflict','tombstone is bound to original invalid intent');
-- Resolver-first valid request wins serialization: late writer must be fenced, not merely ignored by UI.
SELECT is(pg_temp.resolve('save',0,'{}','c4479100-0000-4000-8000-000000000003','c4478000-0000-4000-8000-000000000004')->>'resolution','closed_without_commit','resolver-first creates terminal uncommitted fence');
SELECT throws_ok($$SELECT pg_temp.command('save',0,'{}','c4479100-0000-4000-8000-000000000003','c4478000-0000-4000-8000-000000000004')$$,'PT409','finance_attempt_closed','valid delayed writer cannot escape terminal fence');
SELECT is(pg_temp.command('save',0,'{}',NULL,'c4478000-0000-4000-8000-000000000004')->>'status','draft','new explicit attempt works after definitive closure');
SELECT is(pg_temp.command('cancel',1,'{}',NULL,'c4478000-0000-4000-8000-000000000004')->>'status','cancelled','cancel is available before approval or disbursement');
RESET ROLE;
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000004'),0::bigint,'pre-obligation cancellation creates no money movement');
-- Mistaken disbursement evidence, never a refund or an extinguishment of genuine debt.
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('save',0,'{}',NULL,'c4478000-0000-4000-8000-000000000005')->>'status','draft','mistaken principal fixture begins separately');
SELECT is(pg_temp.command('approve',1,'{}',NULL,'c4478000-0000-4000-8000-000000000005')->>'status','approved','principal evidence requires ordinary approval');
SELECT is(pg_temp.command('activate',2,'{}',NULL,'c4478000-0000-4000-8000-000000000005')->>'outstanding','100.00','mistaken evidence is retained as original disbursement');
RESET ROLE;
SELECT set_config('test.wrong_disbursement',(SELECT id::text FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000005' AND kind='disbursement'),true);
SELECT set_config('test.genuine_disbursement',(SELECT id::text FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000001' AND kind='disbursement'),true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.command('correct_disbursement',10,jsonb_build_object('original',current_setting('test.genuine_disbursement')))$$,'23514','finance_principal_reconciliation_required','any previous repayment precludes mistaken-disbursement shortcut');
SELECT is(pg_temp.command('correct_disbursement',3,jsonb_build_object('original',current_setting('test.wrong_disbursement')),'c4479100-0000-4000-8000-000000000010','c4478000-0000-4000-8000-000000000005')->>'status','record_corrected','reversed erroneous disbursement is never labelled settled');
SELECT is(pg_temp.resolve('correct_disbursement',3,jsonb_build_object('original',current_setting('test.wrong_disbursement')),'c4479100-0000-4000-8000-000000000010','c4478000-0000-4000-8000-000000000005')->>'resolution','committed','lost wrong-evidence response recovers original receipt');
SELECT throws_ok($$SELECT pg_temp.command('correct_disbursement',4,jsonb_build_object('original',current_setting('test.wrong_disbursement')),NULL,'c4478000-0000-4000-8000-000000000005')$$,'23514','finance_principal_reconciliation_required','principal evidence reversal occurs once');
SELECT is(pg_temp.command('save',0,jsonb_build_object('corrected_advance','c4478000-0000-4000-8000-000000000005','principal','75.00'),NULL,'c4478000-0000-4000-8000-000000000006')->>'status','draft','correct principal starts linked replacement with independent approval');
RESET ROLE;
SELECT is(payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000005'),0::numeric,'corrected record has exact signed zero balance');
SELECT is((SELECT delta FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=current_setting('test.wrong_disbursement')::uuid),100::numeric,'original disbursement evidence remains immutable');
SELECT is((SELECT count(*) FROM payroll.advance_allocations WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000005'),0::bigint,'wrong evidence reversal invents no repayment allocations');
SELECT is((SELECT original_id::text FROM payroll.advance_replacements WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND replacement_id='c4478000-0000-4000-8000-000000000006'),'c4478000-0000-4000-8000-000000000005','replacement attribution is immutable and explicit');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.advance_sources('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid))x WHERE x->>'advance'='c4478000-0000-4000-8000-000000000005'),'corrected erroneous principal never appears as due debt');
SELECT ok(NOT has_function_privilege('authenticated','payroll.advance_sources(uuid,uuid,uuid,uuid)','EXECUTE'),'private source projection is inaccessible');
SELECT ok(NOT has_table_privilege('authenticated','payroll.advance_allowances','INSERT'),'ordinary caller cannot fabricate legal allowance');
SELECT ok(NOT has_table_privilege('authenticated','payroll.advance_attempt_closures','INSERT'),'ordinary caller cannot issue absence proof directly');
SELECT set_config('test.manifest',payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(current_setting('test.manifest')::jsonb)->'issues')i WHERE i->>'code'='advance_caps_unqualified'),'due installment without verified allowance is owned blocker');
SELECT is(payroll.build_review(current_setting('test.manifest')::jsonb)->>'net',NULL::text,'due projection never fabricates legal net');
SELECT is((payroll.build_review(current_setting('test.manifest')::jsonb)->>'deductions')::numeric,0::numeric,'unqualified due never silently becomes applied deduction');
SELECT ok(payroll.stale_reasons(current_setting('test.manifest')::jsonb,current_setting('test.manifest')::jsonb||'{"advances":[]}')?'advances_changed','ledger/schedule context participates in freshness');
SELECT ok(NOT EXISTS(SELECT 1 FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND kind='payroll_deduction'),'review calculation never consumes principal');
-- Trusted NONLEGAL adapter fixture solely inside ROLLBACK. No public legal qualification or bank operation.
INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,source_references,review_evidence,state,verified_by,engine_adapter) VALUES('c447a000-0000-4000-8000-000000000001','EG','egypt_payroll','SYNTHETIC_NONLEGAL_ROLLBACK','2020-01-01','["ROLLBACK_ONLY_NO_LEGAL_CLAIM"]','{"NONLEGAL":"adapter interface fixture"}','verified','c4470000-0000-4000-8000-000000000001','SYNTHETIC_NONLEGAL_ROLLBACK');
-- Accepted insufficient-capacity disposition: preserve debt and explicitly defer
-- the unapplied installment. The injected cap is NONLEGAL, not a legal golden.
-- Roll back this branch before the existing full-consumption journey resumes.
CREATE FUNCTION pg_temp.insufficient_capacity_disposition() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;review jsonb;deferred jsonb;installment uuid;revision integer;before_balance numeric;BEGIN
 BEGIN
  SELECT i.id,h.revision,payroll.advance_balance(h.tenant_id,h.id) INTO installment,revision,before_balance FROM payroll.advance_heads h JOIN payroll.advance_installments i ON i.tenant_id=h.tenant_id AND i.version_id=h.version_id AND i.ordinal=1 WHERE h.tenant_id='c4471000-0000-4000-8000-000000000001' AND h.id='c4478000-0000-4000-8000-000000000001';
  INSERT INTO payroll.advance_allowances(tenant_id,employer_id,period_id,employment_id,installment_id,source_revision,amount,qualified_pack,wage_basis,category,obligation_identity,evidence) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'c4475000-0000-4000-8000-000000000001',installment,revision,10,'c447a000-0000-4000-8000-000000000001',3000,'SYNTHETIC_NONLEGAL','2020-01/CAPPED_ROLLBACK','NONLEGAL insufficient-capacity interface only');
  review:=payroll.build_review(payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid));
  deferred:=pg_temp.command('defer',revision,jsonb_build_object('installment',installment,'target_period',current_setting('test.future_period')));
  result:=jsonb_build_object('allowed',review->>'deductions','requires_review',EXISTS(SELECT 1 FROM jsonb_array_elements(review->'issues')x WHERE x->>'code'='advance_carry_forward_required'),'before_balance',before_balance,'after_balance',deferred->>'outstanding','unpaid_installment',payroll.installment_remaining('c4471000-0000-4000-8000-000000000001',installment),'current_removed',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->'advances')x WHERE x->>'installment'=installment::text),'future_retained',EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.future_period')::uuid)->'advances')x WHERE x->>'installment'=installment::text AND(x->>'outstanding')::numeric=23.33));
  RAISE EXCEPTION 'rollback capped fixture branch' USING ERRCODE='P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 RETURN result;
END $$;
CREATE TEMP TABLE capped_disposition ON COMMIT DROP AS SELECT pg_temp.insufficient_capacity_disposition() AS result;
SELECT ok((SELECT (result->>'allowed')::numeric=10 AND(result->>'requires_review')::boolean FROM capped_disposition),'limited NONLEGAL capacity exposes approved carry-forward review instead of silently consuming the remainder');
SELECT ok((SELECT (result->>'before_balance')::numeric=90 AND(result->>'after_balance')::numeric=90 AND(result->>'unpaid_installment')::numeric=23.33 FROM capped_disposition),'public reviewed deferral keeps exact debt and unapplied installment without creating a repayment');
SELECT ok((SELECT (result->>'current_removed')::boolean AND(result->>'future_retained')::boolean FROM capped_disposition),'reviewed unapplied installment leaves current period and remains due in the chosen future period');
INSERT INTO payroll.advance_allowances(tenant_id,employer_id,period_id,employment_id,installment_id,source_revision,amount,qualified_pack,wage_basis,category,obligation_identity,evidence)
SELECT h.tenant_id,h.employer_id,current_setting('test.period')::uuid,h.employment_id,i.id,h.revision,payroll.installment_remaining(h.tenant_id,i.id),'c447a000-0000-4000-8000-000000000001',3000,'SYNTHETIC_NONLEGAL','2020-01/ROLLBACK_ONLY','NONLEGAL interface only' FROM payroll.advance_heads h JOIN payroll.advance_installments i ON i.tenant_id=h.tenant_id AND i.version_id=h.version_id AND i.ordinal=1 WHERE h.tenant_id='c4471000-0000-4000-8000-000000000001' AND h.id='c4478000-0000-4000-8000-000000000001';
SELECT set_config('test.manifest',payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)::text,true);
SELECT is((payroll.build_review(current_setting('test.manifest')::jsonb)->>'deductions')::numeric,23.33::numeric,'qualified interface allowance contributes exact remaining cents only');
SELECT is((SELECT e->'advance_deductions'->0->>'consumed_amount' FROM jsonb_array_elements(payroll.build_review(current_setting('test.manifest')::jsonb)->'employees')e WHERE e->>'employment_id'='c4475000-0000-4000-8000-000000000001'),'23.33','actual candidate explanation names consumed installment amount');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(current_setting('test.manifest')::jsonb)->'issues')i WHERE i->>'code'='statutory_adapter_unqualified'),'synthetic allowance does not qualify legal net engine');
SELECT set_config('test.run','c4479200-0000-4000-8000-000000000001',true);
SELECT set_config('test.candidate','c4479200-0000-4000-8000-000000000002',true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,'draft','c4470000-0000-4000-8000-000000000001');
SELECT set_config('test.synthetic_output',payroll.build_review(current_setting('test.manifest')::jsonb)::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"3976.67"')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,0,net}','"2976.67"'),'{employees,0,statutory_context}','{"calendar_year":2020,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2020-01","2020-02"]}')::text,true);
SELECT set_config('test.synthetic_output',jsonb_set(jsonb_set(jsonb_set(current_setting('test.synthetic_output')::jsonb,'{employees,1,net}','"1000"'),'{employees,1,issues}','[]'),'{employees,1,statutory_context}','{"calendar_year":2020,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2020-01","2020-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.manifest')::jsonb,current_setting('test.synthetic_output')::jsonb,'c4470000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id=current_setting('test.candidate')::uuid,revision=1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid;
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,1,'approve','NONLEGAL rollback interface',gen_random_uuid());
RESET ROLE;
CREATE FUNCTION pg_temp.reject_advance_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='advance_locked_consumption' THEN RAISE EXCEPTION 'advance_audit_fault' USING ERRCODE='23514';END IF;RETURN NEW;END $$;
CREATE TRIGGER advance_audit_fault BEFORE INSERT ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_advance_audit();
SELECT throws_ok($$SELECT payroll.append_final_output('c4471000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4470000-0000-4000-8000-000000000001',2,'c4479300-0000-4000-8000-000000000001')$$,'23514','advance_audit_fault','ledger audit failure rolls back final append and advance together');
SELECT is((SELECT count(*) FROM payroll.final_contexts WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),0::bigint,'failed loan posting leaves no final output');
SELECT is(payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001'),90::numeric,'failed loan audit leaves original debt untouched');
SELECT is((SELECT status FROM payroll.runs WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id=current_setting('test.run')::uuid),'approved','failed posting preserves approved review for safe retry');
DROP TRIGGER advance_audit_fault ON payroll.audit_events;
SELECT set_config('test.output',payroll.append_final_output('c4471000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4470000-0000-4000-8000-000000000001',2,'c4479300-0000-4000-8000-000000000001')::text,true);
SELECT is(payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001'),66.67::numeric,'locked output atomically consumes only exact allowed installment');
SELECT is(payroll.append_final_output('c4471000-0000-4000-8000-000000000001',current_setting('test.run')::uuid,current_setting('test.candidate')::uuid,'c4470000-0000-4000-8000-000000000001',2,'c4479300-0000-4000-8000-000000000001'),current_setting('test.output')::uuid,'private append receipt recovers without second deduction');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND kind='payroll_deduction'),1::bigint,'exactly one locked deduction movement');
SELECT is((SELECT sum(amount) FROM payroll.advance_allocations a JOIN payroll.advance_events e ON e.tenant_id=a.tenant_id AND e.id=a.event_id WHERE e.tenant_id='c4471000-0000-4000-8000-000000000001' AND e.output_id=current_setting('test.output')::uuid),23.33::numeric,'ledger allocations reconcile actual final output deduction');
SELECT ok(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid)->'advances')a WHERE a->>'installment'=(SELECT id::text FROM payroll.advance_installments WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000001' AND ordinal=1)),'consumed original cannot be deducted again by ordinary run');
SELECT throws_ok($$UPDATE payroll.advance_allocations SET amount=0 WHERE tenant_id='c4471000-0000-4000-8000-000000000001'$$,'55000','payroll_immutable','locked consumption allocation is immutable');
SET LOCAL ROLE authenticated;
SELECT throws_ok($$SELECT pg_temp.command('correct_deduction',11,jsonb_build_object('original',(SELECT id FROM payroll.advance_events WHERE kind='payroll_deduction'),'correction_case','c4479900-0000-4000-8000-000000000001'))$$,'42501',NULL,'ordinary caller cannot inspect private ledger to fabricate correction');
SELECT set_config('request.jwt.claim.sub','c4470000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$SELECT public.payroll_advance_workspace('c4471000-0000-4000-8000-000000000002','c4473000-0000-4000-8000-000000000002')$$,'42501','finance_forbidden','Finance reader cannot cross Tenant scope');
RESET ROLE;
SELECT ok(NOT has_table_privilege('authenticated','payroll.advance_events','SELECT'),'workspace is only narrow Finance read projection');


SELECT set_config('request.jwt.claim.sub','c4470000-0000-4000-8000-000000000001',true);
-- Synthetic approved unpaid replacement preserves original deduction and reattributes it with compensation.
INSERT INTO payroll.correction_cases(tenant_id,employer_id,id,original_output,status,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000001',current_setting('test.output')::uuid,'draft','c4470000-0000-4000-8000-000000000001');
INSERT INTO payroll.correction_proposals(tenant_id,employer_id,case_id,id,revision,typed_changes,source_changes,source_scope,reason,reference,responsibilities,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000002',1,'[]','[]',payroll.correction_scope('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001')||jsonb_build_object('affected_outputs',payroll.correction_affected_outputs('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','[]',current_setting('test.output')::uuid)),'SYNTHETIC NONLEGAL replacement attribution fixture','ROLLBACK_ONLY','[]','c4470000-0000-4000-8000-000000000001');
SELECT pg_temp.link_fixture_correction('c4479400-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000002','approved');
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,amendment_of,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'c4479400-0000-4000-8000-000000000003','draft',current_setting('test.output')::uuid,'c4470000-0000-4000-8000-000000000001');
INSERT INTO payroll.amendment_runs VALUES('c4471000-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000003','c4479400-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000002');
INSERT INTO payroll.advance_allowances(tenant_id,employer_id,period_id,employment_id,installment_id,source_revision,amount,qualified_pack,wage_basis,category,obligation_identity,evidence)
SELECT h.tenant_id,h.employer_id,current_setting('test.period')::uuid,h.employment_id,i.id,h.revision,23.33,'c447a000-0000-4000-8000-000000000001',3000,'SYNTHETIC_NONLEGAL','2020-01/ROLLBACK_ONLY','NONLEGAL replacement interface only' FROM payroll.advance_heads h JOIN payroll.advance_installments i ON i.tenant_id=h.tenant_id AND i.version_id=h.version_id AND i.ordinal=1 WHERE h.tenant_id='c4471000-0000-4000-8000-000000000001' AND h.id='c4478000-0000-4000-8000-000000000001';
SELECT set_config('test.amend_manifest',payroll.amendment_manifest('c4471000-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000003')::text,true);
SELECT is((SELECT a->>'outstanding' FROM jsonb_array_elements(current_setting('test.amend_manifest')::jsonb->'advances')a WHERE a->>'advance'='c4478000-0000-4000-8000-000000000001'),'23.33','unpaid amendment restores only original scoped deduction in private projection');
SELECT set_config('test.amend_output',payroll.build_review(current_setting('test.amend_manifest')::jsonb)::text,true);
SELECT set_config('test.amend_output',jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.amend_output')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"3976.67"')::text,true);
SELECT set_config('test.amend_output',jsonb_set(jsonb_set(current_setting('test.amend_output')::jsonb,'{employees,0,net}','"2976.67"'),'{employees,0,statutory_context}','{"calendar_year":2020,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2020-01","2020-02"]}')::text,true);
SELECT set_config('test.amend_output',jsonb_set(jsonb_set(jsonb_set(current_setting('test.amend_output')::jsonb,'{employees,1,net}','"1000"'),'{employees,1,issues}','[]'),'{employees,1,statutory_context}','{"calendar_year":2020,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_FIXTURE_ONLY","insured_wage":"0.00","obligation_months":["2020-01","2020-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000003','c4479400-0000-4000-8000-000000000004',1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.amend_manifest')::jsonb,current_setting('test.amend_output')::jsonb,'c4470000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',revision=1,candidate_id='c4479400-0000-4000-8000-000000000004' WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id='c4479400-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.period')::uuid,'c4479400-0000-4000-8000-000000000003','c4479400-0000-4000-8000-000000000004',1,'approve','NONLEGAL amendment reviewed',gen_random_uuid());
RESET ROLE;
SELECT set_config('test.replacement',(payroll.append_correction_outputs('c4471000-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000001',3,'c4470000-0000-4000-8000-000000000001','c4479400-0000-4000-8000-000000000005')->'replacements'->0->>'replacement_output'),true);
SELECT is(payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001'),66.67::numeric,'replacement does not charge Employee principal twice');
SELECT is((SELECT count(*) FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND output_id=current_setting('test.output')::uuid AND kind='payroll_deduction'),1::bigint,'original locked deduction remains immutable after replacement');
SELECT is((SELECT sum(delta) FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND output_id=current_setting('test.replacement')::uuid),0::numeric,'replacement compensates old and records new exact attribution');
-- Paid original remains payable/paid evidence; governed correction only appends loan ledger compensation.
SET LOCAL ROLE authenticated;
SELECT public.payroll_record_payment('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001',current_setting('test.replacement')::uuid,0,'allocations',CURRENT_DATE,'NONLEGAL external payroll payment','ROLLBACK payment evidence','[{"employment_id":"c4475000-0000-4000-8000-000000000001","amount":"1.00"}]',NULL,true,gen_random_uuid());
RESET ROLE;
SELECT set_config('test.paid_deduction',(SELECT id::text FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND output_id=current_setting('test.replacement')::uuid AND kind='payroll_deduction'),true);
INSERT INTO payroll.correction_cases(tenant_id,employer_id,id,original_output,status,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4479500-0000-4000-8000-000000000001',current_setting('test.replacement')::uuid,'draft','c4470000-0000-4000-8000-000000000001');
INSERT INTO payroll.correction_proposals(tenant_id,employer_id,case_id,id,revision,typed_changes,source_changes,source_scope,reason,reference,responsibilities,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4479500-0000-4000-8000-000000000001','c4479500-0000-4000-8000-000000000002',1,'[]','[]','{}','NONLEGAL reviewed responsibility fixture','ROLLBACK_ONLY',jsonb_build_array(jsonb_build_object('employment_id','c4475000-0000-4000-8000-000000000001','output_id',current_setting('test.replacement'),'basis','external_reviewed','amount','23.33','reference','NONLEGAL approved responsibility','source','ROLLBACK_ONLY')),'c4470000-0000-4000-8000-000000000001');
SELECT pg_temp.link_fixture_correction('c4479500-0000-4000-8000-000000000001','c4479500-0000-4000-8000-000000000002','routed');
SET LOCAL ROLE authenticated;
RESET ROLE;
-- Opposite signed employee_recovery is never compensation authority.
INSERT INTO payroll.correction_cases(tenant_id,employer_id,id,original_output,status,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4479500-0000-4000-8000-000000000003',current_setting('test.replacement')::uuid,'draft','c4470000-0000-4000-8000-000000000001');
INSERT INTO payroll.correction_proposals(tenant_id,employer_id,case_id,id,revision,typed_changes,source_changes,source_scope,reason,reference,responsibilities,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4479500-0000-4000-8000-000000000003','c4479500-0000-4000-8000-000000000004',1,'[]','[]','{}','NONLEGAL negative recovery fixture','NEGATIVE_RECOVERY_ONLY',jsonb_build_array(jsonb_build_object('employment_id','c4475000-0000-4000-8000-000000000001','output_id',current_setting('test.replacement'),'basis','external_reviewed','amount','-23.33','reference','NONLEGAL opposite responsibility','source','ROLLBACK_ONLY')),'c4470000-0000-4000-8000-000000000001');
SELECT pg_temp.link_fixture_correction('c4479500-0000-4000-8000-000000000003','c4479500-0000-4000-8000-000000000004','routed');
SELECT set_config('test.sign_before',jsonb_build_object('balance',payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001'),'revision',(SELECT revision FROM payroll.advance_heads WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id='c4478000-0000-4000-8000-000000000001'),'events',(SELECT count(*) FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),'audit',(SELECT count(*) FROM payroll.audit_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),'receipts',(SELECT count(*) FROM payroll.command_receipts WHERE tenant_id='c4471000-0000-4000-8000-000000000001'))::text,true);
SET LOCAL ROLE authenticated;
SELECT is(jsonb_array_length(public.payroll_advance_correction_choices('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001',current_setting('test.paid_deduction')::uuid,'NEGATIVE_RECOVERY_ONLY')->'items'),0,'negative employee recovery omitted from compensation choices');
SELECT throws_ok($$SELECT public.payroll_advance_correction_choices('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001',current_setting('test.paid_deduction')::uuid,'',NULL,'c4479500-0000-4000-8000-000000000003')$$,'42501','finance_forbidden','negative responsibility cannot be selected through reference projection');
SELECT throws_ok($$SELECT pg_temp.command('correct_deduction',13,jsonb_build_object('original',current_setting('test.paid_deduction'),'correction_case','c4479500-0000-4000-8000-000000000003'),'c4479600-0000-4000-8000-000000000001')$$,'23514','finance_governed_correction_required','negative recovery refuses direct compensation command');
RESET ROLE;
SELECT is(jsonb_build_object('balance',payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001'),'revision',(SELECT revision FROM payroll.advance_heads WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id='c4478000-0000-4000-8000-000000000001'),'events',(SELECT count(*) FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),'audit',(SELECT count(*) FROM payroll.audit_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001'),'receipts',(SELECT count(*) FROM payroll.command_receipts WHERE tenant_id='c4471000-0000-4000-8000-000000000001')),current_setting('test.sign_before')::jsonb,'opposite signed denial has no ledger revision success audit or receipt effects');
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.command('correct_deduction',13,jsonb_build_object('original',current_setting('test.paid_deduction'),'correction_case','c4479500-0000-4000-8000-000000000001'))->>'outstanding','90.00','reviewed paid correction appends exact compensating loan entry');
RESET ROLE;
SELECT ok(payroll.output_has_ever_paid('c4471000-0000-4000-8000-000000000001',current_setting('test.replacement')::uuid),'paid historical fact survives loan compensation');
SELECT is((SELECT paid FROM payroll.payment_balances('c4471000-0000-4000-8000-000000000001',current_setting('test.replacement')::uuid) WHERE employment_id='c4475000-0000-4000-8000-000000000001'),1::numeric,'loan compensation never changes original Payroll payment ledger');
SELECT is((SELECT net FROM payroll.final_employees WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND output_id=current_setting('test.replacement')::uuid AND employment_id='c4475000-0000-4000-8000-000000000001'),2976.67::numeric,'loan compensation never rewrites paid final net');
SET LOCAL ROLE authenticated;
SELECT is(public.payroll_advance_correction_choices('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000001',current_setting('test.paid_deduction')::uuid)->>'already_compensated','true','reload after committed correction keeps protected journal recovery reachable');
RESET ROLE;
-- Cycle2: one installment fully consumed by an unpaid original must be virtually restored.
-- Separate Employer isolates this fixture from the 84 original assertions above.
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default) VALUES('c4471000-0000-4000-8000-000000000001','c4473500-0000-4000-8000-000000000007','c4473000-0000-4000-8000-000000000003','Single-installment Employer B',false);
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id) VALUES('c4471000-0000-4000-8000-000000000001','c4474000-0000-4000-8000-000000000007','SINGLEB','Synthetic fully consumed loan','c4470000-0000-4000-8000-000000000001');
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis) VALUES('c4471000-0000-4000-8000-000000000001','c4475000-0000-4000-8000-000000000007','c4474000-0000-4000-8000-000000000007','c4473000-0000-4000-8000-000000000003','2020-01-01','monthly');
INSERT INTO people.compensation_versions(tenant_id,id,employment_id,amount,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476000-0000-4000-8000-000000000007','c4475000-0000-4000-8000-000000000007',2000,'2020-01-01');
INSERT INTO people.work_assignments(tenant_id,id,employment_id,site_id,valid_from) VALUES('c4471000-0000-4000-8000-000000000001','c4476500-0000-4000-8000-000000000007','c4475000-0000-4000-8000-000000000007','c4473500-0000-4000-8000-000000000007','2020-01-01');
SET LOCAL ROLE authenticated;
SELECT set_config('test.single_period',(public.payroll_save_calendar('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','2020-01-25',24,25,'ending','Africa/Cairo',0,gen_random_uuid(),public.payroll_calendar_preview('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','2020-01-25',24,25,'ending','Africa/Cairo'),'Single installment NONLEGAL fixture')->>'period_id'),true);
RESET ROLE;
CREATE FUNCTION pg_temp.single_command(op text,expected integer) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.payroll_advance_command('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003',jsonb_build_object('operation',op,'advance','c4478000-0000-4000-8000-000000000007','employment','c4475000-0000-4000-8000-000000000007','expected',expected,'data',CASE WHEN op='save' THEN jsonb_build_object('principal','25.00','count','1','first_period',current_setting('test.single_period'),'effective_on','2020-01-25','reason','Single installment rollback fixture') ELSE jsonb_build_object('date',CURRENT_DATE::text,'reference','ROLLBACK_ONLY','reason','Single installment NONLEGAL evidence','confirmed','yes') END),gen_random_uuid())
$$;
GRANT EXECUTE ON FUNCTION pg_temp.single_command(text,integer) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT pg_temp.single_command('save',0);
SELECT pg_temp.single_command('approve',1);
SELECT pg_temp.single_command('activate',2);
RESET ROLE;
INSERT INTO payroll.advance_allowances(tenant_id,employer_id,period_id,employment_id,installment_id,source_revision,amount,qualified_pack,wage_basis,category,obligation_identity,evidence)
SELECT h.tenant_id,h.employer_id,current_setting('test.single_period')::uuid,h.employment_id,i.id,h.revision,25,'c447a000-0000-4000-8000-000000000001',2000,'SYNTHETIC_NONLEGAL','2020-01/ROLLBACK_SINGLE','Synthetic allowance interface only' FROM payroll.advance_heads h JOIN payroll.advance_installments i ON i.tenant_id=h.tenant_id AND i.version_id=h.version_id WHERE h.tenant_id='c4471000-0000-4000-8000-000000000001' AND h.id='c4478000-0000-4000-8000-000000000007';
SELECT set_config('test.single_manifest',payroll.run_manifest('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003',current_setting('test.single_period')::uuid)::text,true);
SELECT set_config('test.single_result',payroll.build_review(current_setting('test.single_manifest')::jsonb)::text,true);
-- This privileged fixture is NONLEGAL; setting qualification does not implement statutory formulas.
SELECT set_config('test.single_result',jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.single_result')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"1975.00"'),'{employees,0,net}','"1975.00"'),'{employees,0,statutory_context}','{"calendar_year":2020,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_ONLY","insured_wage":"0.00","obligation_months":["2020-01","2020-02"]}')::text,true);
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003',current_setting('test.single_period')::uuid,'c4479700-0000-4000-8000-000000000001','draft','c4470000-0000-4000-8000-000000000001');
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','c4479700-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000002',1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.single_manifest')::jsonb,current_setting('test.single_result')::jsonb,'c4470000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',candidate_id='c4479700-0000-4000-8000-000000000002',revision=1 WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id='c4479700-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003',current_setting('test.single_period')::uuid,'c4479700-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000002',1,'approve','Single NONLEGAL original',gen_random_uuid());
RESET ROLE;
SELECT set_config('test.single_original',payroll.append_final_output('c4471000-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000002','c4470000-0000-4000-8000-000000000001',2,'c4479700-0000-4000-8000-000000000003')::text,true);
SELECT is(payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000007'),0::numeric,'single installment original consumes entire principal');
SELECT ok(NOT payroll.output_has_ever_paid('c4471000-0000-4000-8000-000000000001',current_setting('test.single_original')::uuid),'fully consumed fixture remains externally never-paid');
SELECT is(jsonb_array_length(payroll.advance_sources('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003',current_setting('test.single_period')::uuid)),0,'ordinary projection excludes fully consumed loan');
INSERT INTO payroll.correction_cases(tenant_id,employer_id,id,original_output,status,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','c4479700-0000-4000-8000-000000000004',current_setting('test.single_original')::uuid,'draft','c4470000-0000-4000-8000-000000000001');
INSERT INTO payroll.correction_proposals(tenant_id,employer_id,case_id,id,revision,typed_changes,source_changes,source_scope,reason,reference,responsibilities,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','c4479700-0000-4000-8000-000000000004','c4479700-0000-4000-8000-000000000005',1,'[]','[]',payroll.correction_scope('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003')||jsonb_build_object('affected_outputs',payroll.correction_affected_outputs('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','[]',current_setting('test.single_original')::uuid)),'SYNTHETIC NONLEGAL zero-balance amendment','ROLLBACK_SINGLE','[]','c4470000-0000-4000-8000-000000000001');
SELECT pg_temp.link_fixture_correction('c4479700-0000-4000-8000-000000000004','c4479700-0000-4000-8000-000000000005','approved');
INSERT INTO payroll.runs(tenant_id,employer_id,period_id,id,status,amendment_of,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003',current_setting('test.single_period')::uuid,'c4479700-0000-4000-8000-000000000006','draft',current_setting('test.single_original')::uuid,'c4470000-0000-4000-8000-000000000001');
INSERT INTO payroll.amendment_runs VALUES('c4471000-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000006','c4479700-0000-4000-8000-000000000004','c4479700-0000-4000-8000-000000000005');
SELECT set_config('test.single_amend_manifest',payroll.amendment_manifest('c4471000-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000006')::text,true);
SELECT is(current_setting('test.single_amend_manifest')::jsonb->'advances'->0->>'outstanding','25.00','zero-current-balance amendment virtually restores exact unpaid allocation');
SELECT is(current_setting('test.single_amend_manifest')::jsonb->'advances'->0->'allowance','null'::jsonb,'pre-consumption allowance revision cannot authorize restored installment');
SELECT ok(EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.build_review(current_setting('test.single_amend_manifest')::jsonb)->'issues')x WHERE x->>'code'='advance_caps_unqualified'),'missing current allowance blocks fully consumed amendment rather than dropping debt');
INSERT INTO payroll.advance_allowances(tenant_id,employer_id,period_id,employment_id,installment_id,source_revision,amount,qualified_pack,wage_basis,category,obligation_identity,evidence)
SELECT h.tenant_id,h.employer_id,current_setting('test.single_period')::uuid,h.employment_id,i.id,h.revision,25,'c447a000-0000-4000-8000-000000000001',2000,'SYNTHETIC_NONLEGAL','2020-01/ROLLBACK_SINGLE','Synthetic restored allowance interface only' FROM payroll.advance_heads h JOIN payroll.advance_installments i ON i.tenant_id=h.tenant_id AND i.version_id=h.version_id WHERE h.tenant_id='c4471000-0000-4000-8000-000000000001' AND h.id='c4478000-0000-4000-8000-000000000007';
SELECT set_config('test.single_amend_manifest',payroll.amendment_manifest('c4471000-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000006')::text,true);
SELECT set_config('test.single_amend_result',payroll.build_review(current_setting('test.single_amend_manifest')::jsonb)::text,true);
SELECT is(current_setting('test.single_amend_result')::jsonb->'employees'->0->'advance_deductions'->0->>'consumed_amount','25.00','qualified private fixture restores exact alternative consumption');
SELECT set_config('test.single_amend_result',jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(current_setting('test.single_amend_result')::jsonb,'{issues}','[]'),'{employees,0,issues}','[]'),'{financially_qualified}','true'),'{net}','"1975.00"'),'{employees,0,net}','"1975.00"'),'{employees,0,statutory_context}','{"calendar_year":2020,"category":"SYNTHETIC_NONLEGAL","insured_wage_source":"ROLLBACK_ONLY","insured_wage":"0.00","obligation_months":["2020-01","2020-02"]}')::text,true);
INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,id,revision,engine_version,input_manifest,output,created_by) VALUES('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003','c4479700-0000-4000-8000-000000000006','c4479700-0000-4000-8000-000000000007',1,'SYNTHETIC_NONLEGAL_ROLLBACK',current_setting('test.single_amend_manifest')::jsonb,current_setting('test.single_amend_result')::jsonb,'c4470000-0000-4000-8000-000000000001');
UPDATE payroll.runs SET status='review',revision=1,candidate_id='c4479700-0000-4000-8000-000000000007' WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND id='c4479700-0000-4000-8000-000000000006';
SET LOCAL ROLE authenticated;
SELECT public.payroll_candidate_approval('c4471000-0000-4000-8000-000000000001','c4473000-0000-4000-8000-000000000003',current_setting('test.single_period')::uuid,'c4479700-0000-4000-8000-000000000006','c4479700-0000-4000-8000-000000000007',1,'approve','Single NONLEGAL amendment',gen_random_uuid());
RESET ROLE;
SELECT set_config('test.single_successor',(payroll.append_correction_outputs('c4471000-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000004',3,'c4470000-0000-4000-8000-000000000001','c4479700-0000-4000-8000-000000000008')->'replacements'->0->>'replacement_output'),true);
SELECT is(payroll.advance_balance('c4471000-0000-4000-8000-000000000001','c4478000-0000-4000-8000-000000000007'),0::numeric,'unchanged fully consumed replacement retains zero principal debt');
SELECT is((SELECT sum(delta) FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000007' AND output_id=current_setting('test.single_successor')::uuid),0::numeric,'successor compensation and exact deduction reconcile atomically');
SELECT is((SELECT delta FROM payroll.advance_events WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND advance_id='c4478000-0000-4000-8000-000000000007' AND output_id=current_setting('test.single_original')::uuid AND kind='payroll_deduction'),(-25)::numeric,'original fully consumed deduction remains immutable');
SELECT is((SELECT net FROM payroll.final_employees WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND output_id=current_setting('test.single_successor')::uuid AND employment_id='c4475000-0000-4000-8000-000000000007'),1975::numeric,'alternative final payable preserves exact loan deduction');
SELECT is((SELECT net FROM payroll.final_employees WHERE tenant_id='c4471000-0000-4000-8000-000000000001' AND output_id=current_setting('test.single_original')::uuid AND employment_id='c4475000-0000-4000-8000-000000000007'),1975::numeric,'original never-paid payable remains immutable');
SELECT * FROM finish();
ROLLBACK;
