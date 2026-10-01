BEGIN;
SELECT no_plan();
CREATE TEMP TABLE coverage_fixture AS
SELECT jsonb_build_object('tenant_id','cea20000-0000-4000-8000-000000000001',
 'employee_id','cea30000-0000-4000-8000-000000000001','employment_id','cea40000-0000-4000-8000-000000000001',
 'policy_template_id','cea80000-0000-4000-8000-000000000001','policy_version',1,
 'schedule_kind','fixed','operational_date','2026-02-02','timezone_name','UTC',
 'expected_start','2026-02-02T09:00:00Z','expected_end','2026-02-02T17:00:00Z',
 'attribution_start','2026-02-02T07:00:00Z','attribution_end','2026-02-02T19:00:00Z',
 'required_minutes',NULL,'break_minutes',60,'lateness_grace_minutes',0,'early_leave_grace_minutes',0) wi,
 jsonb_build_object('tenant_id','cea20000-0000-4000-8000-000000000001',
 'template_id','cea80000-0000-4000-8000-000000000001','version',1,'schedule_kind','fixed',
 'timezone_name','UTC','shift_start','09:00:00','shift_end','17:00:00','ends_next_day',false,
 'break_minutes',60,'fixed_break_start','13:00:00','fixed_break_end','14:00:00') policy,
 'cea50000-0000-4000-8000-000000000001'::uuid employer;
CREATE FUNCTION pg_temp.coverage_source(p_units numeric,p_part text,p_pay text DEFAULT 'paid')
RETURNS jsonb LANGUAGE sql AS $f$
 SELECT jsonb_build_object('tenant_id',wi->'tenant_id','employee_id',wi->'employee_id',
 'employment_id',wi->'employment_id','employer_entity_id',employer,'leave_date',wi->'operational_date',
 'request_id',CASE WHEN p_part='first' THEN 'cea90000-0000-4000-8000-000000000001'
  WHEN p_part='second' THEN 'cea90000-0000-4000-8000-000000000002' ELSE 'cea90000-0000-4000-8000-000000000003' END,
 'approved_preview_version',1,'type_version_id','ceb10000-0000-4000-8000-000000000001',
 'calendar_version_id','ceb20000-0000-4000-8000-000000000001','pay_effect',p_pay,'reference_only',true,
 'units',p_units,'is_half_day',p_units=0.5,'half_day_part',p_part,
 'mapping_state',CASE WHEN p_units=0.5 THEN 'mapped' END,'policy_template_id',wi->'policy_template_id',
 'policy_version',1,'algorithm_version','leave-halfday-v1','mapping_snapshot',jsonb_build_object('mapping',
 "time".leave_halfday_mapping(policy||jsonb_build_object('policy_template_id',wi->'policy_template_id','policy_version',1),'2026-02-02',p_part)))
 FROM coverage_fixture
$f$;
CREATE FUNCTION pg_temp.pair(p_in text,p_out text) RETURNS jsonb LANGUAGE sql AS $f$
 SELECT jsonb_build_array(jsonb_build_object('id','ceb30000-0000-4000-8000-000000000001','direction','in','happened_at',p_in),
 jsonb_build_object('id','ceb30000-0000-4000-8000-000000000002','direction','out','happened_at',p_out))
$f$;
CREATE FUNCTION pg_temp.classify(p_context jsonb,p_punches jsonb DEFAULT '[]',p_at timestamptz DEFAULT '2026-02-03',
 p_wi_patch jsonb DEFAULT '{}',p_policy_patch jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $f$
 SELECT "time".classify_attendance_values(wi||p_wi_patch,policy||p_policy_patch,p_punches,p_context,employer,p_at) FROM coverage_fixture
$f$;

SELECT ok(pg_temp.classify(context) @> expected,label) FROM (VALUES
 ('settled absence without Leave', '[]'::jsonb,'{"kind":"absence","absence_units":1,"leave_units":0,"approval_eligible":true}'::jsonb),
 ('paid half leaves only half unexcused',jsonb_build_array(pg_temp.coverage_source(0.5,'first')),'{"kind":"absence","absence_units":0.5,"leave_units":0.5}'::jsonb),
 ('unpaid second half leaves only half unexcused',jsonb_build_array(pg_temp.coverage_source(0.5,'second','unpaid')),'{"kind":"absence","absence_units":0.5,"leave_units":0.5}'::jsonb),
 ('paid whole date covered',jsonb_build_array(pg_temp.coverage_source(1,NULL)),'{"kind":"leave_covered","absence_units":0,"leave_units":1}'::jsonb),
 ('unpaid whole date covered',jsonb_build_array(pg_temp.coverage_source(1,NULL,'unpaid')),'{"kind":"leave_covered","absence_units":0,"leave_units":1}'::jsonb),
 ('mixed complementary fixed halves cover exact date',jsonb_build_array(pg_temp.coverage_source(0.5,'first'),pg_temp.coverage_source(0.5,'second','unpaid')),'{"kind":"leave_covered","absence_units":0,"leave_units":1}'::jsonb)
) cases(label,context,expected);
SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),'[]',instant) @>
 '{"kind":"review_required","leave_units":1,"approval_eligible":false,"diagnostics":["awaiting_observation_window"]}',
 'covered date waits at/before settlement '||instant) FROM unnest(ARRAY['2026-02-02T18:59:59Z','2026-02-02T19:00:00Z']::timestamptz[]) instant;
SELECT is(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),'[]','2026-02-02T19:00:01Z')->>'kind','leave_covered','strictly after settlement allows covered classification');
SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)))->'observations' @>
 '{"first_in":null,"last_out":null,"gross_worked_minutes":null,"worked_minutes":null,"applied_break_minutes":null}', 'covered no-punch date fabricates no observed work');
SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),pg_temp.pair('2026-02-02T10:00Z','2026-02-02T16:00Z')) @>
 '{"kind":"leave_covered","absence_units":0,"observations":{"gross_worked_minutes":360,"worked_minutes":300,"applied_break_minutes":60,"late_minutes":60,"early_leave_minutes":60},"diagnostics":["observed_work_during_excused"]}', 'full coverage retains valid short actual work and late/early');
SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),pg_temp.pair('2026-02-02T09:00Z','2026-02-02T12:00Z'),'2026-02-02T12:01Z',
 '{"schedule_kind":"flexible","required_minutes":481,"expected_start":null,"expected_end":null}',
 '{"schedule_kind":"flexible","required_minutes":481,"fixed_break_start":null,"fixed_break_end":null}') @>
 '{"kind":"leave_covered","observations":{"exception_code":"short_workday","gross_worked_minutes":180,"worked_minutes":120},"diagnostics":["short_workday","observed_work_during_excused"]}', 'full coverage retains flexible short_workday before end without invented wages');
SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(0.5,'first')),pg_temp.pair('2026-02-02T12:30Z','2026-02-02T17:00Z')) @>
 '{"kind":"worked","evaluated_observations":{"worked_minutes":210,"late_minutes":0,"early_leave_minutes":0}}','remaining-half actual work uses shared compatible calculation');
SELECT is(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(0.5,'first')),pg_temp.pair('2026-02-02T09:00Z','2026-02-02T17:00Z'))->>'kind','review_required','excused overlap does not fabricate fractional absence');

SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),punches)->'diagnostics' @> jsonb_build_array(diagnostic)
 AND pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),punches)->>'kind'='review_required',label)
 FROM (VALUES
 ('full Leave cannot hide reversed punches',pg_temp.pair('2026-02-02T17:00Z','2026-02-02T09:00Z'),'outside_window'),
 ('full Leave cannot hide outside attribution',pg_temp.pair('2026-02-02T06:00Z','2026-02-02T17:00Z'),'outside_window'),
 ('full Leave cannot hide duplicate direction',jsonb_set(pg_temp.pair('2026-02-02T09:00Z','2026-02-02T17:00Z'),'{1,direction}','"in"'),'conflicting_punches'),
 ('full Leave cannot hide missing exit',jsonb_build_array(pg_temp.pair('2026-02-02T09:00Z','2026-02-02T17:00Z')->0),'missing_punch')
 ) cases(label,punches,diagnostic);
SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),pg_temp.pair('2026-02-02T09:00Z','2026-02-02T17:00Z'),'2026-02-03','{}','{"fixed_break_end":"15:00:00"}') @>
 '{"kind":"review_required","diagnostics":["break_placement_invalid"]}', 'full coverage preserves invalid break diagnostic');
SELECT ok(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL)),'[]','2026-02-03','{"attribution_end":null}') @>
 '{"kind":"review_required","diagnostics":["ambiguous_local_time"]}', 'NULL attribution never settles as covered');

SELECT is(pg_temp.classify(jsonb_build_array(source))->>'kind','review_required',label) FROM (VALUES
 ('wrong Employer source refused',jsonb_set(pg_temp.coverage_source(0.5,'first'),'{employer_entity_id}','"cea50000-0000-4000-8000-000000000002"')),
 ('wrong Employee source refused',jsonb_set(pg_temp.coverage_source(0.5,'first'),'{employee_id}','"cea30000-0000-4000-8000-000000000002"')),
 ('wrong Employment source refused',jsonb_set(pg_temp.coverage_source(0.5,'first'),'{employment_id}','"cea40000-0000-4000-8000-000000000002"')),
 ('cross-tenant source refused',jsonb_set(pg_temp.coverage_source(0.5,'first'),'{tenant_id}','"cea20000-0000-4000-8000-000000000002"')),
 ('wrong date source refused',jsonb_set(pg_temp.coverage_source(0.5,'first'),'{leave_date}','"2026-02-03"')),
 ('missing legacy mapping refused',pg_temp.coverage_source(0.5,'first')-'mapping_snapshot'),
 ('incompatible frozen policy refused',jsonb_set(pg_temp.coverage_source(0.5,'first'),'{policy_version}','2')),
 ('altered excused spans refused',jsonb_set(pg_temp.coverage_source(0.5,'first'),'{mapping_snapshot,mapping,excused_intervals}','[]')),
 ('unknown frozen pay effect refused',jsonb_set(pg_temp.coverage_source(1,NULL),'{pay_effect}','null')),
 ('malformed persisted numeric evidence stays review',jsonb_set(pg_temp.coverage_source(1,NULL),'{units}','"bad"'))
 ) cases(label,source);
SELECT is(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(0.5,'first'),jsonb_set(pg_temp.coverage_source(0.5,'first'),'{request_id}','"cea90000-0000-4000-8000-000000000002"')))->>'kind','review_required','same-part halves cannot prove whole coverage');
SELECT is(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(1,NULL),pg_temp.coverage_source(0.5,'first')))->>'kind','review_required','sum greater than one cannot prove coverage');
SELECT is(pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(0.5,'first'),pg_temp.coverage_source(0.5,'first')))->>'kind','review_required','duplicate request source cannot double count');
WITH frozen AS (
 SELECT wi||'{"schedule_kind":"flexible","required_minutes":481,"expected_start":null,"expected_end":null}' instance,
 policy||'{"schedule_kind":"flexible","required_minutes":481,"flexible_halfday_break_minutes":30,"fixed_break_start":null,"fixed_break_end":null}' flexible_policy,employer FROM coverage_fixture
), source AS (
 SELECT *,pg_temp.coverage_source(0.5,NULL)||jsonb_build_object('mapping_snapshot',jsonb_build_object('mapping',
 "time".leave_halfday_mapping(flexible_policy||jsonb_build_object('policy_template_id',instance->'policy_template_id','policy_version',1),'2026-02-02',NULL))) half FROM frozen
)
SELECT ok("time".classify_attendance_values(instance,flexible_policy,'[]',CASE WHEN double_half THEN
 jsonb_build_array(half,jsonb_set(half,'{request_id}','"cea90000-0000-4000-8000-000000000004"')) ELSE jsonb_build_array(half) END,
 employer,'2026-02-03') @> expected,label) FROM source CROSS JOIN (VALUES
 (false,'{"kind":"absence","absence_units":0.5,"leave_units":0.5}'::jsonb,'mapped flexible half with odd requirement remains nominal half absence'),
 (true,'{"kind":"review_required","approval_eligible":false}'::jsonb,'two flexible halves cannot prove complementary full-day spans')
 ) cases(double_half,expected,label);
SELECT ok(pg_temp.classify(jsonb_build_array(jsonb_set(pg_temp.coverage_source(1,NULL),'{leave_date}','"2026-03-08"')),
 pg_temp.pair('2026-03-08T06:00Z','2026-03-08T08:00Z'),'2026-03-09',
 '{"operational_date":"2026-03-08","timezone_name":"America/New_York","expected_start":"2026-03-08T06:00Z","expected_end":"2026-03-08T08:00Z","attribution_start":"2026-03-08T05:00Z","attribution_end":"2026-03-08T10:00Z"}',
 '{"fixed_break_start":"02:00:00","fixed_break_end":"03:00:00"}') @>
 '{"kind":"review_required","diagnostics":["break_placement_invalid"]}', 'full Leave cannot hide DST break gap');
SELECT throws_ok($$SELECT pg_temp.classify(NULL)$$,'22023','attendance_classification_invalid_input','missing source array is a programming error');

CREATE TEMP TABLE effects_before AS SELECT (SELECT count(*) FROM "time".interpretations) q,(SELECT count(*) FROM "time".attendance_facts) f,
 (SELECT count(*) FROM "time".work_instances) w,(SELECT count(*) FROM leave.ledger_entries) l,(SELECT count(*) FROM "time".attendance_audit_events) a;
SELECT pg_temp.classify(jsonb_build_array(pg_temp.coverage_source(0.5,'first'))) IS NOT NULL;
SELECT ok((SELECT count(*) FROM "time".interpretations)=q AND (SELECT count(*) FROM "time".attendance_facts)=f AND
 (SELECT count(*) FROM "time".work_instances)=w AND (SELECT count(*) FROM leave.ledger_entries)=l AND (SELECT count(*) FROM "time".attendance_audit_events)=a,'classification preview appends zero operational effects') FROM effects_before;
SELECT ok(NOT has_function_privilege(r,'"time".classify_attendance_values(jsonb,jsonb,jsonb,jsonb,uuid,timestamp with time zone)','EXECUTE'),r||' cannot execute private classifier')
 FROM unnest(ARRAY['anon','authenticated','service_role']) r;
SELECT ok(NOT has_function_privilege(r,'platform_private.approved_leave_classification_context(uuid,uuid)','EXECUTE'),r||' cannot execute richer source reader')
 FROM unnest(ARRAY['anon','authenticated','service_role']) r;
SELECT * FROM finish();
ROLLBACK;
