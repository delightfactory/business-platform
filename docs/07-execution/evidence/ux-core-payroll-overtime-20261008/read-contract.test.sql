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
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,work_days,shift_start,shift_end,created_by)
 VALUES(pg_temp.u(1),pg_temp.u(80),1,'Synthetic fixed','fixed',ARRAY[1,2,3,4,5]::smallint[],'09:00','17:00',pg_temp.u(10)),
 (pg_temp.u(2),pg_temp.u(80),1,'Synthetic fixed','fixed',ARRAY[1,2,3,4,5]::smallint[],'09:00','17:00',pg_temp.u(10));
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,status,created_by)
 SELECT pg_temp.u(CASE WHEN n=108 THEN 2 ELSE 1 END),pg_temp.u(n),pg_temp.u(90),pg_temp.u(CASE WHEN n=107 THEN 41 WHEN n=108 THEN 42 ELSE 40 END),pg_temp.u(CASE WHEN n=107 THEN 51 WHEN n=108 THEN 52 ELSE 50 END),pg_temp.u(91),
 CASE WHEN n=105 THEN date'2030-02-05' ELSE date'2030-01-02'+(n-100) END,pg_temp.u(80),1,'Africa/Cairo',CASE WHEN n=104 THEN 'open' ELSE 'approved' END,pg_temp.u(10)
 FROM generate_series(100,109)n;
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by)
 SELECT pg_temp.u(CASE WHEN n=108 THEN 2 ELSE 1 END),pg_temp.u(n+500),pg_temp.u(n),1,'ready','synthetic-before-source',pg_temp.u(10) FROM generate_series(100,109)n;
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
 SELECT pg_temp.u(CASE WHEN n=108 THEN 2 ELSE 1 END),pg_temp.u(n+1000),pg_temp.u(n),1,pg_temp.u(n+500),
 jsonb_build_object('outcome',CASE WHEN n=106 THEN 'leave_covered' WHEN n=109 THEN 'unknown' ELSE 'worked' END,'input_fingerprint',CASE WHEN n=100 THEN 'synthetic-stale' ELSE time.work_instance_interpretation_fingerprint(pg_temp.u(CASE WHEN n=108 THEN 2 ELSE 1 END),pg_temp.u(n)) END),pg_temp.u(10)
 FROM generate_series(100,109)n;
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
 VALUES(pg_temp.u(1),pg_temp.u(2105),pg_temp.u(105),2,pg_temp.u(605),jsonb_build_object('outcome','worked','input_fingerprint',time.work_instance_interpretation_fingerprint(pg_temp.u(1),pg_temp.u(105))),pg_temp.u(10));
INSERT INTO time.attendance_overtime_candidates(tenant_id,id,work_instance_id,attendance_fact_id,policy_template_id,policy_version,raw_minutes,candidate_minutes,category,actor_user_id)
 SELECT pg_temp.u(CASE WHEN n=108 THEN 2 ELSE 1 END),pg_temp.u(n+2000),pg_temp.u(n),pg_temp.u(n+1000),pg_temp.u(80),1,
 CASE WHEN n=100 THEN 30 WHEN n=101 THEN 45 WHEN n=106 THEN 20 ELSE 90 END,
 CASE WHEN n=100 THEN 30 WHEN n=101 THEN 45 WHEN n=106 THEN 20 ELSE 90 END,'ordinary',pg_temp.u(10) FROM generate_series(100,109)n;
INSERT INTO time.attendance_overtime_candidates(tenant_id,id,work_instance_id,attendance_fact_id,policy_template_id,policy_version,raw_minutes,candidate_minutes,category,actor_user_id)
 VALUES(pg_temp.u(1),pg_temp.u(3105),pg_temp.u(105),pg_temp.u(2105),pg_temp.u(80),1,10,10,'ordinary',pg_temp.u(10));
INSERT INTO time.attendance_overtime_review_events(tenant_id,candidate_id,decision,reason,actor_user_id)
 VALUES(pg_temp.u(1),pg_temp.u(2103),'rejected','Synthetic rejection',pg_temp.u(10));
INSERT INTO time.attendance_overtime_classification_events(tenant_id,candidate_id,version,review_event_id,ordinary_day_minutes,ordinary_night_minutes,weekly_rest_minutes,official_holiday_minutes,reason,request_fingerprint,actor_user_id)
 VALUES(pg_temp.u(1),pg_temp.u(2102),1,999,90,0,0,0,'Synthetic classification','synthetic-classified',pg_temp.u(10));
SET session_replication_role=origin;
SELECT pg_temp.check('authenticated execute granted',has_function_privilege('authenticated','public.payroll_unclassified_overtime(uuid,uuid,uuid,date,text,uuid,integer)','EXECUTE'));
SELECT pg_temp.check('anon execute denied',NOT has_function_privilege('anon','public.payroll_unclassified_overtime(uuid,uuid,uuid,date,text,uuid,integer)','EXECUTE'));
SELECT pg_temp.check('service_role execute denied',NOT has_function_privilege('service_role','public.payroll_unclassified_overtime(uuid,uuid,uuid,date,text,uuid,integer)','EXECUTE'));
SELECT pg_temp.check('empty search_path',proconfig @> ARRAY['search_path=""']) FROM pg_proc WHERE oid='public.payroll_unclassified_overtime(uuid,uuid,uuid,date,text,uuid,integer)'::regprocedure;
SELECT pg_temp.check('no direct source-table grant',NOT has_table_privilege('authenticated','time.attendance_overtime_candidates','SELECT'));
SELECT set_config('request.jwt.claim.sub',pg_temp.u(10)::text,false);
SET ROLE authenticated;
DO $$ DECLARE r jsonb; BEGIN
 r:=public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30));
 PERFORM pg_temp.check('all eligible instances only',(r->'totals'->>'instances')::int=4);
 PERFORM pg_temp.check('current unclassified minutes only',(r->'totals'->>'minutes')::int=105);
 PERFORM pg_temp.check('actual reconciliation currentness',(r->'totals'->>'reconciliation_required')::int=1);
 PERFORM pg_temp.check('more-than31-day period supported',EXISTS(SELECT 1 FROM jsonb_array_elements(r->'items')i WHERE i->>'operational_date'='2030-02-05'));
 PERFORM pg_temp.check('only minimal fields',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'items')i,jsonb_object_keys(i)k WHERE k NOT IN('work_instance_id','operational_date','employee_code','unclassified_count','unclassified_minutes','reconciliation_required')));
 PERFORM pg_temp.check('latest fact excludes older candidate',EXISTS(SELECT 1 FROM jsonb_array_elements(r->'items')i WHERE i->>'work_instance_id'=pg_temp.u(105)::text AND i->>'unclassified_minutes'='10'));
 PERFORM pg_temp.check('leave-covered approved fact included',EXISTS(SELECT 1 FROM jsonb_array_elements(r->'items')i WHERE i->>'work_instance_id'=pg_temp.u(106)::text));
 PERFORM pg_temp.check('classified rejected pending unknown excluded',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'items')i WHERE i->>'work_instance_id'=ANY(ARRAY[pg_temp.u(102)::text,pg_temp.u(103)::text,pg_temp.u(104)::text,pg_temp.u(109)::text])));
 PERFORM pg_temp.check('other employer and tenant excluded',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'items')i WHERE i->>'work_instance_id'=ANY(ARRAY[pg_temp.u(107)::text,pg_temp.u(108)::text])));
 PERFORM pg_temp.check('final page cursor absent',r->>'has_more'='false' AND r->'next_cursor'='null'::jsonb);
 r:=public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(33));
 PERFORM pg_temp.check('empty approved source exact',r->'items'='[]'::jsonb AND r->'totals'->>'minutes'='0');
 r:=public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),NULL,NULL,NULL,1);
 PERFORM pg_temp.check('totals not paginated sample',jsonb_array_length(r->'items')=1 AND r->'totals'->>'minutes'='105' AND r->>'has_more'='true');
 PERFORM pg_temp.check('triple cursor from last visible item',r->'next_cursor'->>'work_instance_id'=pg_temp.u(100)::text AND r->'next_cursor'->>'operational_date'='2030-01-02' AND r->'next_cursor'->>'employee_code'='SYN-A');
 r:=public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),'2030-01-02','SYN-A',pg_temp.u(100),1);
 PERFORM pg_temp.check('cursor advances without duplicate',r->'items'->0->>'work_instance_id'=pg_temp.u(101)::text AND r->'totals'->>'minutes'='105');
END $$;
SELECT pg_temp.expect_error('other employer period','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(31))','42501');
SELECT pg_temp.expect_error('other tenant period','SELECT public.payroll_unclassified_overtime(pg_temp.u(2),pg_temp.u(22),pg_temp.u(30))','42501');
SELECT pg_temp.expect_error('cross employer cursor','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),date''2030-01-09'',''SYN-B'',pg_temp.u(107))','42501');
SELECT pg_temp.expect_error('cross tenant cursor','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),date''2030-01-10'',''SYN-C'',pg_temp.u(108))','42501');
SELECT pg_temp.expect_error('cursor tuple tampering','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),date''2030-01-03'',''SYN-A'',pg_temp.u(100))','42501');
SELECT pg_temp.expect_error('cursor missing code','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),date''2030-01-02'',NULL,pg_temp.u(100))','22023');
SELECT pg_temp.expect_error('cursor outside period','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),date''2029-12-31'',''SYN-A'',pg_temp.u(100))','22023');
SELECT pg_temp.expect_error('cursor long code','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),date''2030-01-02'',repeat(''X'',65),pg_temp.u(100))','22023');
SELECT pg_temp.expect_error('zero limit','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),NULL,NULL,NULL,0)','22023');
SELECT pg_temp.expect_error('over max limit','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),NULL,NULL,NULL,21)','22023');
SELECT pg_temp.expect_error('null limit','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),NULL,NULL,NULL,NULL)','22023');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(11)::text,false);
SELECT pg_temp.expect_error('payroll only no source disclosure','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))','42501');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(12)::text,false);
SELECT pg_temp.expect_error('attendance only no payroll scope','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))','42501');
SELECT set_config('request.jwt.claim.sub','',false);
SELECT pg_temp.expect_error('missing actor','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))','42501');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(13)::text,false);
SELECT pg_temp.check('preparer plus attendance accepted',public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))->'totals'->>'minutes'='105');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(14)::text,false);
SELECT pg_temp.check('reviewer plus attendance approver accepted',public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))->'totals'->>'minutes'='105');
SELECT set_config('request.jwt.claim.sub',pg_temp.u(15)::text,false);
SELECT pg_temp.check('current approval read amendment preserved',public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))->'totals'->>'minutes'='105');
RESET ROLE;
SET session_replication_role=replica;
INSERT INTO time.attendance_overtime_classification_events(tenant_id,candidate_id,version,review_event_id,ordinary_day_minutes,ordinary_night_minutes,weekly_rest_minutes,official_holiday_minutes,reason,request_fingerprint,actor_user_id)
 VALUES(pg_temp.u(1),pg_temp.u(2100),1,999,30,0,0,0,'Synthetic resolved after cursor','synthetic-resolved',pg_temp.u(10));
SET session_replication_role=origin;
SELECT set_config('request.jwt.claim.sub',pg_temp.u(10)::text,false);
SET ROLE authenticated;
SELECT pg_temp.check('resolved cursor still continues',public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),'2030-01-02','SYN-A',pg_temp.u(100),1)->'items'->0->>'work_instance_id'=pg_temp.u(101)::text);
RESET ROLE;
UPDATE auth.users SET email_confirmed_at=NULL WHERE id=pg_temp.u(10);
SET ROLE authenticated;
SELECT pg_temp.expect_error('unconfirmed identity stays denied','SELECT public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))','42501');
RESET ROLE;
SELECT jsonb_build_object('cases',count(*),'results',jsonb_agg(to_jsonb(results) ORDER BY label)) FROM results;
ROLLBACK;
