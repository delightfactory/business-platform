\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'business_platform_scale_qa' THEN
    RAISE EXCEPTION 'This regression is restricted to business_platform_scale_qa (connected to %)', current_database();
  END IF;
END
$$;

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA extensions;
DROP SCHEMA IF EXISTS qa_attendance_lock_regression CASCADE;
CREATE SCHEMA qa_attendance_lock_regression;

SELECT gen_random_uuid() AS actor_id \gset
SELECT gen_random_uuid() AS tenant_id \gset
SELECT gen_random_uuid() AS role_id \gset
SELECT gen_random_uuid() AS entity_id \gset
SELECT gen_random_uuid() AS original_site_id \gset
SELECT gen_random_uuid() AS changed_site_id \gset
SELECT gen_random_uuid() AS policy_id \gset
SELECT ('LOCK-' || replace(gen_random_uuid()::text, '-', '')) AS employee_code \gset
SELECT (timezone('Africa/Cairo', transaction_timestamp())::date - 1)::text AS start_date \gset
SELECT timezone('Africa/Cairo', transaction_timestamp())::date::text AS today \gset

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES (:'actor_id', :'employee_code' || '@qa.example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES (:'tenant_id','Attendance import concurrency QA',:'actor_id');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot)
VALUES (:'tenant_id',:'role_id','qa.attendance.import.lock',1,
  ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.manage','attendance.manage','attendance_policy.manage']);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES (:'tenant_id',:'actor_id',:'actor_id');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES (:'tenant_id',:'actor_id',:'role_id');
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES
  (:'tenant_id','hr.people',true,now()-interval '1 minute',:'actor_id','QA concurrency regression'),
  (:'tenant_id','hr.attendance',true,now()-interval '1 minute',:'actor_id','QA concurrency regression');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES (:'tenant_id',:'entity_id','Concurrency QA employer',true);
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default)
VALUES
  (:'tenant_id',:'original_site_id',:'entity_id','QA Original',true),
  (:'tenant_id',:'changed_site_id',:'entity_id','QA Changed',false);
INSERT INTO time.work_policy_templates(tenant_id,id,code,is_active,head_version)
VALUES (:'tenant_id',:'policy_id','QA-FLEX',true,1);
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,
  required_minutes,earliest_punch,latest_punch,created_by)
VALUES (:'tenant_id',:'policy_id',1,'QA flexible','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,
  '00:00','23:59',:'actor_id');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'actor_id', false);
SELECT public.create_people_employee(:'tenant_id','' || :'employee_code','Concurrency QA employee',
  :'entity_id',:'original_site_id',:'start_date','monthly',1000,true) AS created_employee \gset
RESET ROLE;

SELECT id AS employee_id FROM people.employees WHERE tenant_id=:'tenant_id' AND employee_code=:'employee_code' \gset
SELECT id AS employment_id FROM people.employments WHERE tenant_id=:'tenant_id' AND employee_id=:'employee_id' \gset
UPDATE people.work_assignments
SET work_policy_template_id=:'policy_id',work_policy_version=1
WHERE tenant_id=:'tenant_id' AND employment_id=:'employment_id';

CREATE FUNCTION qa_attendance_lock_regression.hold_lock_then_transfer(
  p_tenant uuid,p_employment uuid,p_actor uuid,p_today date,p_site uuid)
RETURNS text LANGUAGE plpgsql AS $function$
DECLARE transfer_result jsonb;
BEGIN
  PERFORM 1 FROM people.employments
  WHERE tenant_id=p_tenant AND id=p_employment FOR UPDATE;
  PERFORM pg_sleep(5);
  PERFORM set_config('request.jwt.claim.sub', p_actor::text, false);
  transfer_result:=public.schedule_people_work_assignment(
    p_tenant, p_employment, p_today, p_site, NULL, NULL, NULL);
  RETURN transfer_result::text;
END
$function$;

CREATE FUNCTION qa_attendance_lock_regression.run_import(p_tenant uuid,p_actor uuid,p_employee_code text)
RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE import_result jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_actor::text, false);
  import_result:=public.confirm_attendance_csv_import(
    p_tenant,
    jsonb_build_array(jsonb_build_object(
      'employee_code', p_employee_code,
      'site_name', 'QA Original',
      'happened_at', to_char(transaction_timestamp() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS') || '+00:00',
      'direction', 'in',
      'source_event_key', 'qa-lock-' || p_tenant)));
  RETURN import_result;
END
$function$;

SELECT extensions.dblink_connect('lock_holder',
  'dbname=business_platform_scale_qa user=supabase_admin application_name=qa-attendance-lock-holder');
SELECT extensions.dblink_connect('importer',
  'dbname=business_platform_scale_qa user=supabase_admin application_name=qa-attendance-importer');
SELECT extensions.dblink_send_query('lock_holder',format(
  'SELECT qa_attendance_lock_regression.hold_lock_then_transfer(%L::uuid,%L::uuid,%L::uuid,%L::date,%L::uuid)',
  :'tenant_id',:'employment_id',:'actor_id',:'today',:'changed_site_id'));

DO $wait_for_holder$
DECLARE holder_pid integer; deadline timestamptz:=clock_timestamp()+interval '10 seconds';
BEGIN
  LOOP
    SELECT pid INTO holder_pid FROM pg_stat_activity
    WHERE application_name='qa-attendance-lock-holder' AND wait_event='PgSleep';
    EXIT WHEN holder_pid IS NOT NULL;
    IF clock_timestamp()>deadline THEN RAISE EXCEPTION 'lock holder did not reach its controlled pause'; END IF;
    PERFORM pg_sleep(0.05);
  END LOOP;
END
$wait_for_holder$;

SELECT extensions.dblink_send_query('importer',format(
  'SELECT qa_attendance_lock_regression.run_import(%L::uuid,%L::uuid,%L::text)',
  :'tenant_id',:'actor_id',:'employee_code'));

DO $assert_import_waits$
DECLARE deadline timestamptz:=clock_timestamp()+interval '10 seconds'; blocked boolean:=false;
BEGIN
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_stat_activity importer
      WHERE importer.application_name='qa-attendance-importer'
        AND importer.wait_event_type='Lock'
        AND EXISTS (
          SELECT 1 FROM unnest(pg_blocking_pids(importer.pid)) AS blocker(pid)
          JOIN pg_stat_activity holder ON holder.pid=blocker.pid
          WHERE holder.application_name='qa-attendance-lock-holder'))
    INTO blocked;
    EXIT WHEN blocked;
    IF clock_timestamp()>deadline THEN RAISE EXCEPTION 'CSV import did not wait on the Employment lock'; END IF;
    PERFORM pg_sleep(0.05);
  END LOOP;
END
$assert_import_waits$;
\echo Confirmed: CSV import is blocked by the Employment lock.

SELECT transfer_result FROM extensions.dblink_get_result('lock_holder') AS result(transfer_result text) \gset
SELECT import_result FROM extensions.dblink_get_result('importer') AS result(import_result jsonb) \gset

SELECT CASE WHEN :'import_result'::jsonb #>> '{rows,0,status}'='unassigned' THEN 'PASS'
  ELSE (1/0)::text END AS revalidation_result;
SELECT CASE WHEN :'transfer_result' LIKE '%transferred%' THEN 'PASS'
  ELSE (1/0)::text END AS transfer_result;
\echo Passed: after the transfer commits, CSV import revalidates and classifies the stale-site event as unassigned.

SELECT extensions.dblink_disconnect('importer');
SELECT extensions.dblink_disconnect('lock_holder');
DROP SCHEMA qa_attendance_lock_regression CASCADE;
