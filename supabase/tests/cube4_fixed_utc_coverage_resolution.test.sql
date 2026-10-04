BEGIN;
DO $$BEGIN IF current_database()<>'business_platform_cube4_adam_positive_browser_qa' THEN RAISE EXCEPTION 'Owned browser QA181 required';END IF;END$$;
SELECT no_plan();SELECT set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000001',true);
CREATE TEMP TABLE original_coverage AS SELECT payroll.capture_optional_sources('d6201000-0000-4000-8000-000000000001','d6203000-0000-4000-8000-000000000001','d620e000-0000-4000-8000-000000000001') snapshot;
CREATE TEMP TABLE original_run AS SELECT to_jsonb(r) snapshot FROM payroll.runs r WHERE r.id='574b5cf3-3c80-44dc-9f29-24fd3c496228';
CREATE TEMP TABLE original_bounds AS SELECT day,policy,payroll.time_expected_bounds(day,policy) bounds FROM(VALUES
 ('2024-02-29'::date,'{"schedule_kind":"fixed","timezone_name":"UTC","work_days":[1,2,3,4,5,6,7],"shift_start":"22:00","shift_end":"06:00","ends_next_day":true,"attribution_before_minutes":120,"attribution_after_minutes":360}'::jsonb),
 ('2026-01-04'::date,'{"schedule_kind":"flexible","timezone_name":"Etc/UTC","work_days":[1,2,3,4,5,6,7],"required_minutes":480,"earliest_punch":"08:00","latest_punch":"20:00"}'::jsonb),
 ('2026-03-29'::date,'{"schedule_kind":"fixed","timezone_name":"Europe/London","work_days":[1,2,3,4,5,6,7],"shift_start":"01:30","shift_end":"08:00","ends_next_day":false,"attribution_before_minutes":0,"attribution_after_minutes":0}'::jsonb)) fixture(day,policy);
-- APPLY_DELTA_HERE
SELECT is(payroll.coverage_local_instant(stamp,zone),time.resolve_local(stamp,zone),'exact civil instant for '||zone||' '||stamp::text) FROM(VALUES
 ('2024-02-29 23:59:59.123456'::timestamp,'UTC'),('2026-12-31 23:59:59'::timestamp,'Etc/UTC'),
 ('2026-03-29 01:30'::timestamp,'Europe/London'),('2026-10-25 01:30'::timestamp,'Europe/London'),
 ('2026-04-24 00:30'::timestamp,'Africa/Cairo'),('2026-02-01 08:00'::timestamp,'Africa/Cairo'),
 ('2026-02-01 08:00'::timestamp,'unsupported/zone'),(NULL::timestamp,'UTC'),('infinity'::timestamp,'UTC'),('-infinity'::timestamp,'Etc/UTC')) samples(stamp,zone);
SELECT is(payroll.time_expected_bounds(day,policy),bounds,'unchanged expected-window payload for '||(policy->>'timezone_name')) FROM original_bounds;
SELECT is(payroll.capture_optional_sources('d6201000-0000-4000-8000-000000000001','d6203000-0000-4000-8000-000000000001','d620e000-0000-4000-8000-000000000001'),(SELECT snapshot FROM original_coverage),'all31 captured facts and coverage provenance remain byte-equivalent JSON');
SELECT is((SELECT snapshot->'time' FROM original_coverage),(SELECT input_manifest->'optional_sources'->'time' FROM payroll.candidates WHERE id='0d67eeca-998f-4b42-b8ac-8cad5f94ae2f'),'original approved candidate Time capture remains current');
SELECT is((SELECT to_jsonb(r) FROM payroll.runs r WHERE r.id='574b5cf3-3c80-44dc-9f29-24fd3c496228'),(SELECT snapshot FROM original_run),'approvedrevision2 lifecycle and approval identifiers untouched');
SELECT ok(NOT has_function_privilege('authenticated','payroll.coverage_local_instant(timestamp without time zone,text)','EXECUTE') AND NOT has_function_privilege('service_role','payroll.coverage_local_instant(timestamp without time zone,text)','EXECUTE'),'coverage helper does not expose a new API or bypass path');
SELECT * FROM finish();ROLLBACK;
