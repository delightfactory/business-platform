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

INSERT INTO people.employees(tenant_id,id,employee_code,full_name,created_by_user_id)
 SELECT pg_temp.u(1),pg_temp.u(n+60000),'S'||n,'Synthetic load employee',pg_temp.u(10) FROM generate_series(5000,5299)n;
INSERT INTO people.employments(tenant_id,id,employee_id,employer_entity_id,start_date,pay_basis)
 SELECT pg_temp.u(1),pg_temp.u(n+70000),pg_temp.u(n+60000),pg_temp.u(20),'2029-01-01','monthly' FROM generate_series(5000,5299)n;
INSERT INTO time.work_instances(tenant_id,id,assignment_id,employment_id,employee_id,site_id,operational_date,policy_template_id,policy_version,timezone_name,status,created_by)
 SELECT pg_temp.u(1),pg_temp.u(n),pg_temp.u(n+10000),pg_temp.u(n+70000),pg_temp.u(n+60000),pg_temp.u(91),'2030-01-20',pg_temp.u(80),1,'Africa/Cairo','approved',pg_temp.u(10) FROM generate_series(5000,5299)n;
INSERT INTO time.interpretations(tenant_id,id,work_instance_id,version,state,input_fingerprint,created_by)
 SELECT pg_temp.u(1),pg_temp.u(n+20000),pg_temp.u(n),1,'ready','synthetic',pg_temp.u(10) FROM generate_series(5000,5299)n;
INSERT INTO time.attendance_facts(tenant_id,id,work_instance_id,version,interpretation_id,fact,actor_user_id)
 SELECT pg_temp.u(1),pg_temp.u(n+30000),pg_temp.u(n),1,pg_temp.u(n+20000),jsonb_build_object('outcome','worked','input_fingerprint',time.work_instance_interpretation_fingerprint(pg_temp.u(1),pg_temp.u(n))),pg_temp.u(10) FROM generate_series(5000,5299)n;
INSERT INTO time.attendance_overtime_candidates(tenant_id,id,work_instance_id,attendance_fact_id,policy_template_id,policy_version,raw_minutes,candidate_minutes,category,actor_user_id)
 SELECT pg_temp.u(1),pg_temp.u(n+40000),pg_temp.u(n),pg_temp.u(n+30000),pg_temp.u(80),1,10,10,'ordinary',pg_temp.u(10) FROM generate_series(5000,5299)n;
SET session_replication_role=origin;
SELECT pg_temp.check('review event unique tenant/candidate',EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='time.attendance_overtime_review_events'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (tenant_id, candidate_id)'));
SELECT set_config('request.jwt.claim.sub',pg_temp.u(10)::text,false);
SET ROLE authenticated;
DO $$ DECLARE r jsonb; started timestamptz; elapsed numeric; BEGIN
 started:=clock_timestamp();
 r:=public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30));
 elapsed:=extract(epoch FROM clock_timestamp()-started)*1000;
 PERFORM pg_temp.check('304 eligible rows full totals and bounded20',r->'totals'->>'instances'='304' AND r->'totals'->>'minutes'='3105' AND jsonb_array_length(r->'items')=20 AND r->>'has_more'='true');
 RAISE NOTICE 'MEASUREMENT first_page_ms=% instances=304 items=20',elapsed;
 started:=clock_timestamp();
 r:=public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),'2030-01-20','S5016',pg_temp.u(5016),20);
 elapsed:=extract(epoch FROM clock_timestamp()-started)*1000;
 PERFORM pg_temp.check('same date continuation no skipped record',r->'items'->0->>'work_instance_id'=pg_temp.u(5017)::text AND r->'totals'->>'instances'='304');
 RAISE NOTICE 'MEASUREMENT next_page_ms=% instances=304 items=20',elapsed;
END $$;
RESET ROLE;
UPDATE people.employees SET employee_code='SYN-RENAMED' WHERE tenant_id=pg_temp.u(1) AND id=pg_temp.u(50);
SET ROLE authenticated;
DO $$ DECLARE code text; detail text; BEGIN
 BEGIN PERFORM public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30),'2030-01-02','SYN-A',pg_temp.u(100),20);
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,detail=MESSAGE_TEXT; END;
 PERFORM pg_temp.check('changed employee code cursor is resettable scope failure',code='42501' AND detail='payroll_overtime_cursor_forbidden');
 PERFORM pg_temp.check('fresh page after code change succeeds',public.payroll_unclassified_overtime(pg_temp.u(1),pg_temp.u(20),pg_temp.u(30))->'totals'->>'instances'='304');
END $$;
RESET ROLE;
SELECT jsonb_build_object('cases',count(*),'results',jsonb_agg(to_jsonb(results) ORDER BY label)) FROM results;
ROLLBACK;
