-- Actual domain schema/functions. Synthetic rows seeded with source-write triggers bypassed.
-- This qualifies this read/ACL/scope only, not attendance or payroll write workflows.
BEGIN;
CREATE TEMP TABLE results(label text PRIMARY KEY,result text NOT NULL);
CREATE FUNCTION pg_temp.u(n integer) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
 SELECT ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;
CREATE FUNCTION pg_temp.check(label text,ok boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAILED: %',label; END IF;
 INSERT INTO pg_temp.results VALUES(label,'PASS');
END $$;
CREATE FUNCTION pg_temp.expect_error(label text,command text,wanted text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE got text;
BEGIN
 BEGIN EXECUTE command; EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS got=RETURNED_SQLSTATE; END;
 PERFORM pg_temp.check(label,got=wanted);
END $$;
DO $$ BEGIN EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated,anon,service_role',(SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema())); END $$;
SET session_replication_role=replica;
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT pg_temp.u(n),'synthetic-overtime-'||n||'@example.test',now() FROM generate_series(10,15)n;
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
 VALUES(pg_temp.u(1),'Synthetic overtime A',pg_temp.u(10)),(pg_temp.u(2),'Synthetic overtime B',pg_temp.u(10));
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
 SELECT pg_temp.u(1),pg_temp.u(n+50),'synthetic.overtime.'||n,1,
 CASE n WHEN 10 THEN ARRAY['payroll.view','attendance.view'] WHEN 11 THEN ARRAY['payroll.view']
 WHEN 12 THEN ARRAY['attendance.view'] WHEN 13 THEN ARRAY['payroll.prepare','attendance.view']
 WHEN 14 THEN ARRAY['payroll.review','attendance.approve'] ELSE ARRAY['payroll.approve','attendance.correct'] END
 FROM generate_series(10,15)n;
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
 VALUES(pg_temp.u(2),pg_temp.u(60),'synthetic.overtime.10',1,ARRAY['payroll.view','attendance.view']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
 SELECT pg_temp.u(1),pg_temp.u(n),pg_temp.u(10) FROM generate_series(10,15)n;
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES(pg_temp.u(2),pg_temp.u(10),pg_temp.u(10));
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
 SELECT pg_temp.u(1),pg_temp.u(n),pg_temp.u(n+50) FROM generate_series(10,15)n;
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(pg_temp.u(2),pg_temp.u(10),pg_temp.u(60));
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name)
 VALUES(pg_temp.u(1),pg_temp.u(20),'Synthetic employer A'),(pg_temp.u(1),pg_temp.u(21),'Synthetic employer B'),(pg_temp.u(2),pg_temp.u(22),'Synthetic tenant B employer');
INSERT INTO payroll.periods(tenant_id,id,employer_id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by)
 VALUES(pg_temp.u(1),pg_temp.u(30),pg_temp.u(20),pg_temp.u(70),'2030-01-01','2030-02-10','2030-02-10','Africa/Cairo','Synthetic transition',true,pg_temp.u(10)),
 (pg_temp.u(1),pg_temp.u(31),pg_temp.u(21),pg_temp.u(71),'2030-01-01','2030-01-31','2030-01-31','Africa/Cairo','Synthetic other employer',false,pg_temp.u(10)),
 (pg_temp.u(2),pg_temp.u(32),pg_temp.u(22),pg_temp.u(72),'2030-01-01','2030-01-31','2030-01-31','Africa/Cairo','Synthetic other tenant',false,pg_temp.u(10)),
 (pg_temp.u(1),pg_temp.u(33),pg_temp.u(20),pg_temp.u(70),'2030-03-01','2030-03-31','2030-03-31','Africa/Cairo','Synthetic empty',false,pg_temp.u(10));
INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
 VALUES(pg_temp.u(1),pg_temp.u(50),'SYN-A','Synthetic A',pg_temp.u(10)),(pg_temp.u(1),pg_temp.u(51),'SYN-B','Synthetic B',pg_temp.u(10)),(pg_temp.u(2),pg_temp.u(52),'SYN-C','Synthetic C',pg_temp.u(10));
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis)
 VALUES(pg_temp.u(1),pg_temp.u(40),pg_temp.u(50),pg_temp.u(20),'2029-01-01','monthly'),(pg_temp.u(1),pg_temp.u(41),pg_temp.u(51),pg_temp.u(21),'2029-01-01','monthly'),(pg_temp.u(2),pg_temp.u(42),pg_temp.u(52),pg_temp.u(22),'2029-01-01','monthly');

INSERT INTO auth.users(id,email,email_confirmed_at) VALUES(pg_temp.u(16),'synthetic-recorder@example.test',now());
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
 VALUES(pg_temp.u(1),pg_temp.u(66),'synthetic.recorder.only',1,ARRAY['payroll.payment_record']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id) VALUES(pg_temp.u(1),pg_temp.u(16),pg_temp.u(10));
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(pg_temp.u(1),pg_temp.u(16),pg_temp.u(66));
INSERT INTO payroll.final_contexts(tenant_id,id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by)
 SELECT pg_temp.u(CASE WHEN n=408 THEN 2 ELSE 1 END),pg_temp.u(n),pg_temp.u(CASE WHEN n=408 THEN 22 ELSE 20 END),pg_temp.u(CASE WHEN n=408 THEN 32 ELSE 30 END),pg_temp.u(n+1000),pg_temp.u(n+2000),pg_temp.u(n+3000),'{}',jsonb_build_object('starts_on','2030-01-01','ends_on','2030-02-10','timezone','Africa/Cairo'),'{}','{}','synthetic-read-only-fixture',pg_temp.u(10) FROM generate_series(400,408)n;
INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net)
 SELECT pg_temp.u(CASE WHEN n=408 THEN 2 ELSE 1 END),pg_temp.u(CASE WHEN n=408 THEN 22 ELSE 20 END),pg_temp.u(n),pg_temp.u(CASE WHEN n=408 THEN 42 ELSE 40 END),'{}','{}','{}',CASE WHEN n=403 THEN 0 ELSE 100 END FROM generate_series(400,408)n WHERE n<>407;
INSERT INTO payroll.payment_heads(tenant_id,output_id,revision) SELECT pg_temp.u(1),pg_temp.u(n),7 FROM generate_series(400,407)n;
INSERT INTO payroll.payment_events(tenant_id,employer_id,output_id,id,kind,original_event,paid_on,reference,reason,evidence_meaning,actor_id,actor_label)
 SELECT pg_temp.u(1),pg_temp.u(20),pg_temp.u(n),pg_temp.u(n+4000),'payment',NULL,'2030-01-05','SYN-PAY','Synthetic external payment','external_payment_recorded',pg_temp.u(10),'Synthetic actor' FROM generate_series(401,404)n WHERE n<>403;
INSERT INTO payroll.payment_allocations(tenant_id,output_id,event_id,employment_id,amount)
 SELECT pg_temp.u(1),pg_temp.u(n),pg_temp.u(n+4000),pg_temp.u(40),CASE WHEN n=401 THEN 40 ELSE 100 END FROM generate_series(401,404)n WHERE n<>403;
INSERT INTO payroll.payment_events(tenant_id,employer_id,output_id,id,kind,original_event,paid_on,reference,reason,evidence_meaning,actor_id,actor_label)
 VALUES(pg_temp.u(1),pg_temp.u(20),pg_temp.u(404),pg_temp.u(5404),'compensation',pg_temp.u(4404),'2030-01-06','SYN-CORRECT','Synthetic mistaken record','mistaken_record_only',pg_temp.u(10),'Synthetic actor');
INSERT INTO payroll.payment_allocations(tenant_id,output_id,event_id,employment_id,amount)
 VALUES(pg_temp.u(1),pg_temp.u(404),pg_temp.u(5404),pg_temp.u(40),100);
INSERT INTO payroll.output_successions(tenant_id,original_output,replacement_output,actor_id,reason)
 VALUES(pg_temp.u(1),pg_temp.u(405),pg_temp.u(406),pg_temp.u(10),'Synthetic successor');
CREATE TEMP TABLE before_ledger AS SELECT
 (SELECT jsonb_agg(to_jsonb(t) ORDER BY output_id) FROM payroll.payment_heads t) heads,
 (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM payroll.payment_events t) events,
 (SELECT jsonb_agg(to_jsonb(t) ORDER BY event_id,employment_id) FROM payroll.payment_allocations t) allocations,
 (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM payroll.final_contexts t) contexts;
SET session_replication_role=origin;
SELECT set_config('request.jwt.claim.sub',pg_temp.u(10)::text,false);
SET ROLE authenticated;
DO $$ DECLARE r jsonb; BEGIN
 r:=public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(400));
 PERFORM pg_temp.check('unpaid positive saved obligation',r->>'status'='unpaid' AND r->>'payable_sign'='positive' AND r->>'remaining_count'='1');
 PERFORM pg_temp.check('exact output period revision',r->>'output_id'=pg_temp.u(400)::text AND r->'period'->>'id'=pg_temp.u(30)::text AND r->>'revision'='7');
 PERFORM pg_temp.check('no amounts or personal records',NOT(r ? 'paid') AND NOT(r ? 'remaining') AND NOT(r ? 'payable') AND NOT(r ? 'employees') AND NOT(r ? 'history'));
 r:=public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(401));
 PERFORM pg_temp.check('partial external payment recorded',r->>'status'='partially_paid' AND r->>'ever_paid'='true' AND r->>'remaining_count'='1');
 r:=public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(402));
 PERFORM pg_temp.check('full external payment recorded',r->>'status'='paid' AND r->>'remaining_count'='0');
 r:=public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(403));
 PERFORM pg_temp.check('zero payable distinct from unpaid',r->>'status'='unpaid' AND r->>'payable_sign'='zero' AND r->>'remaining_count'='0' AND r->>'employee_count'='1');
 r:=public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(404));
 PERFORM pg_temp.check('compensation preserves ever paid',r->>'status'='unpaid' AND r->>'ever_paid'='true' AND r->>'remaining_count'='1');
 r:=public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(405));
 PERFORM pg_temp.check('superseded immutable record disclosed',r->>'superseded'='true');
 r:=public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(407));
 PERFORM pg_temp.check('empty final scope distinct',r->>'employee_count'='0' AND r->>'payable_sign'='zero');
END $$;
SELECT pg_temp.expect_error('cross employer output','SELECT public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(21),pg_temp.u(400))','42501');
SELECT pg_temp.expect_error('cross tenant output','SELECT public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(408))','42501');
SELECT pg_temp.expect_error('missing output','SELECT public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(999))','42501');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(16)::text,false);
SELECT pg_temp.check('record-only reader admitted',public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(400))->>'status'='unpaid');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(15)::text,false);
SELECT pg_temp.expect_error('approval-only not payment read','SELECT public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(400))','42501');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(12)::text,false);
SELECT pg_temp.expect_error('attendance-only not payment read','SELECT public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(400))','42501');
SELECT set_config('request.jwt.claim.sub','',false);
SELECT pg_temp.expect_error('missing payment actor','SELECT public.payroll_payment_facts(pg_temp.u(1),pg_temp.u(20),pg_temp.u(400))','42501');
RESET ROLE;
SELECT pg_temp.check('exactly one preserved audit per successful call',(SELECT count(*)=8 FROM payroll.audit_events WHERE action='payment_workspace_access'));
SELECT pg_temp.check('only minimal aggregate audit vocabulary',NOT EXISTS(SELECT 1 FROM payroll.audit_events WHERE details->>'aggregate_only' IS DISTINCT FROM 'true' OR details->>'employee_count'<>'0' OR details->>'history_count'<>'0' OR details->'event'<>'null'::jsonb));
SELECT pg_temp.check('no payment ledger mutation',
 (SELECT heads IS NOT DISTINCT FROM(SELECT jsonb_agg(to_jsonb(t) ORDER BY output_id) FROM payroll.payment_heads t)
  AND events IS NOT DISTINCT FROM(SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM payroll.payment_events t)
  AND allocations IS NOT DISTINCT FROM(SELECT jsonb_agg(to_jsonb(t) ORDER BY event_id,employment_id) FROM payroll.payment_allocations t)
  AND contexts IS NOT DISTINCT FROM(SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM payroll.final_contexts t) FROM before_ledger));
SELECT pg_temp.check('no advisory locks acquired',NOT EXISTS(SELECT 1 FROM pg_locks WHERE pid=pg_backend_pid() AND locktype='advisory'));
SELECT pg_temp.check('volatile audited security definer',provolatile='v' AND prosecdef AND proconfig @> ARRAY['search_path=""']) FROM pg_proc WHERE oid='public.payroll_payment_facts(uuid,uuid,uuid)'::regprocedure;
SELECT pg_temp.check('authenticated execute only',has_function_privilege('authenticated','public.payroll_payment_facts(uuid,uuid,uuid)','EXECUTE') AND NOT has_function_privilege('anon','public.payroll_payment_facts(uuid,uuid,uuid)','EXECUTE') AND NOT has_function_privilege('service_role','public.payroll_payment_facts(uuid,uuid,uuid)','EXECUTE'));
SET session_replication_role=replica;
SELECT pg_temp.expect_error('negative final net excluded by existing schema',
 'INSERT INTO payroll.final_employees(tenant_id,employer_id,output_id,employment_id,employee_snapshot,explanation,statutory_context,net) VALUES(pg_temp.u(1),pg_temp.u(20),pg_temp.u(407),pg_temp.u(40),''{}'',''{}'',''{}'',-1)','23514');
SELECT jsonb_build_object('cases',count(*),'results',jsonb_agg(to_jsonb(results) ORDER BY label)) FROM results;
ROLLBACK;

