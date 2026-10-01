BEGIN;
SELECT no_plan();

CREATE TEMP TABLE calculator_fixture AS
SELECT jsonb_build_object(
 'tenant_id','dca20000-0000-4000-8000-000000000001',
 'policy_template_id','dca80000-0000-4000-8000-000000000001','policy_version',1,
 'schedule_kind','fixed','operational_date','2026-02-02','timezone_name','UTC',
 'expected_start','2026-02-02T09:00:00Z','expected_end','2026-02-02T17:00:00Z',
 'attribution_start','2026-02-02T07:00:00Z','attribution_end','2026-02-02T19:00:00Z',
 'required_minutes',NULL,'break_minutes',60,'lateness_grace_minutes',0,'early_leave_grace_minutes',0
) wi, jsonb_build_object('tenant_id','dca20000-0000-4000-8000-000000000001',
 'template_id','dca80000-0000-4000-8000-000000000001','version',1,
 'schedule_kind','fixed','fixed_break_start','13:00','fixed_break_end','14:00') policy;

CREATE FUNCTION pg_temp.pair(p_in text,p_out text) RETURNS jsonb LANGUAGE sql AS $f$
 SELECT jsonb_build_array(
 jsonb_build_object('id','dca90000-0000-4000-8000-000000000001','direction','in','happened_at',p_in),
 jsonb_build_object('id','dca90000-0000-4000-8000-000000000002','direction','out','happened_at',p_out))
$f$;
CREATE FUNCTION pg_temp.calculate(p_patch jsonb,p_policy jsonb,p_punches jsonb,p_at timestamptz DEFAULT '2026-02-03T00:00:00Z')
RETURNS jsonb LANGUAGE sql AS $f$
 SELECT "time".calculate_interpretation_values(wi||p_patch,p_policy,p_punches,p_at) FROM calculator_fixture
$f$;

CREATE TEMP TABLE cases(label text,patch jsonb,punches jsonb,expected jsonb);
INSERT INTO cases VALUES
 ('remaining half including break','{}',pg_temp.pair('2026-02-02T12:30Z','2026-02-02T17:00Z'),
  '{"state":"ready","exception_code":null,"owner_permission":null,"gross_worked_minutes":270,"worked_minutes":210,"applied_break_minutes":60,"late_minutes":210,"early_leave_minutes":0}'),
 ('work after break','{}',pg_temp.pair('2026-02-02T14:00Z','2026-02-02T17:00Z'),
  '{"state":"ready","gross_worked_minutes":180,"worked_minutes":180,"applied_break_minutes":0}'),
 ('second-resolution rounding','{}',pg_temp.pair('2026-02-02T12:30:30Z','2026-02-02T14:00:00Z'),
  '{"state":"ready","gross_worked_minutes":90,"worked_minutes":30,"applied_break_minutes":60}'),
 ('settled absence','{}','[]','{"state":"needs_review","exception_code":"absence_candidate","owner_permission":"attendance.approve","worked_minutes":null,"applied_break_minutes":null}'),
 ('one punch','{}','[{"id":"dca90000-0000-4000-8000-000000000001","direction":"in","happened_at":"2026-02-02T09:00Z"}]',
  '{"state":"needs_review","exception_code":"missing_punch","owner_permission":"attendance.correct"}'),
 ('duplicate directions','{}','[{"id":"dca90000-0000-4000-8000-000000000001","direction":"in","happened_at":"2026-02-02T09:00Z"},{"id":"dca90000-0000-4000-8000-000000000002","direction":"in","happened_at":"2026-02-02T10:00Z"}]',
  '{"state":"needs_review","exception_code":"conflicting_punches"}'),
 ('outside attribution','{}',pg_temp.pair('2026-02-02T06:00Z','2026-02-02T17:00Z'),
  '{"state":"needs_review","exception_code":"outside_window","worked_minutes":null}'),
 ('reversed pair','{}',pg_temp.pair('2026-02-02T17:00Z','2026-02-02T09:00Z'),
  '{"state":"needs_review","exception_code":"outside_window"}'),
 ('ambiguous instance','{"expected_start":null}',pg_temp.pair('2026-02-02T09:00Z','2026-02-02T17:00Z'),
  '{"state":"needs_review","exception_code":"ambiguous_local_time"}');
SELECT ok(pg_temp.calculate(patch,f.policy,punches) @> expected,label) FROM cases CROSS JOIN calculator_fixture f;
SELECT is(pg_temp.calculate('{}',policy,'[]','2026-02-02T18:59:59Z')->>'state','open','before settlement stays open') FROM calculator_fixture;
SELECT is(pg_temp.calculate('{}',policy,'[]','2026-02-02T19:00:00Z')->>'state','open','exact settlement boundary stays open') FROM calculator_fixture;
SELECT is(pg_temp.calculate('{}',policy,'[]','2026-02-02T19:00:01Z')->>'exception_code','absence_candidate','strictly after settlement is absence') FROM calculator_fixture;
SELECT ok(pg_temp.calculate('{"break_minutes":30}',NULL,pg_temp.pair('2026-02-02T14:00Z','2026-02-02T17:00Z')) @>
 '{"gross_worked_minutes":180,"worked_minutes":150,"applied_break_minutes":30}', 'missing placement keeps legacy aggregate break');
SELECT is(pg_temp.calculate('{"break_minutes":0}',policy,pg_temp.pair('2026-02-02T09:00Z','2026-02-02T17:00Z'))->>'exception_code','break_placement_invalid','zero break with placement remains invalid') FROM calculator_fixture;
SELECT ok(pg_temp.calculate('{"operational_date":"2026-02-02","expected_start":"2026-02-02T22:00Z","expected_end":"2026-02-03T06:00Z","attribution_start":"2026-02-02T20:00Z","attribution_end":"2026-02-03T08:00Z","break_minutes":30}',
 policy||'{"fixed_break_start":"01:00","fixed_break_end":"01:30"}',pg_temp.pair('2026-02-02T22:00Z','2026-02-03T06:00Z')) @>
 '{"state":"ready","gross_worked_minutes":480,"worked_minutes":450,"applied_break_minutes":30}','overnight break belongs to following local date') FROM calculator_fixture;
SELECT is(pg_temp.calculate('{"operational_date":"2026-03-08","timezone_name":"America/New_York","expected_start":"2026-03-08T05:00Z","expected_end":"2026-03-08T08:00Z","attribution_start":"2026-03-08T04:00Z","attribution_end":"2026-03-08T10:00Z"}',
 policy||'{"fixed_break_start":"02:00","fixed_break_end":"03:00"}',pg_temp.pair('2026-03-08T05:00Z','2026-03-08T08:00Z'),'2026-03-09')->>'exception_code','break_placement_invalid','DST gap cannot manufacture break placement') FROM calculator_fixture;

CREATE TEMP TABLE half_context AS
SELECT jsonb_build_array(jsonb_build_object('is_half_day',true,'units',0.5,'half_day_part','first','mapping_state','mapped',
 'policy_template_id',wi->>'policy_template_id','policy_version',1,'algorithm_version','leave-halfday-v1',
 'mapping_snapshot',jsonb_build_object('mapping',jsonb_build_object('schedule_kind','fixed',
 'excused_intervals',jsonb_build_array(jsonb_build_object('start_at','2026-02-02T09:00Z','end_at','2026-02-02T12:30Z')),
 'remaining_intervals',jsonb_build_array(jsonb_build_object('start_at','2026-02-02T12:30Z','end_at','2026-02-02T13:00Z'),jsonb_build_object('start_at','2026-02-02T14:00Z','end_at','2026-02-02T17:00Z')),
 'break_interval',jsonb_build_array(jsonb_build_object('start_at','2026-02-02T13:00Z','end_at','2026-02-02T14:00Z')))))) context FROM calculator_fixture;
CREATE FUNCTION pg_temp.overlay(p_base jsonb,p_patch jsonb,p_policy jsonb,p_context jsonb,p_enabled boolean)
RETURNS jsonb LANGUAGE sql AS $f$
 SELECT to_jsonb("time".apply_leave_context_to_interpretation(jsonb_populate_record(NULL::"time".interpretations,p_base),
 jsonb_populate_record(NULL::"time".work_instances,wi||p_patch),jsonb_populate_record(NULL::"time".work_policy_versions,p_policy),p_context,p_enabled)) FROM calculator_fixture
$f$;
CREATE TEMP TABLE observed AS SELECT pg_temp.calculate('{}',policy,pg_temp.pair('2026-02-02T12:30Z','2026-02-02T17:00Z')) base FROM calculator_fixture;
SELECT ok(pg_temp.overlay(base,'{}',policy,context,true) @> '{"state":"ready","leave_units":0.5,"leave_compatibility_state":"compatible","late_minutes":0,"early_leave_minutes":0,"worked_minutes":210,"applied_break_minutes":60}', 'fixed half overlay preserves observations and recalculates remaining obligation') FROM observed,calculator_fixture,half_context;
SELECT ok(pg_temp.overlay(base,'{}',policy,context,false) @> '{"leave_evidence":[],"leave_units":0,"leave_compatibility_state":"none","late_minutes":210}', 'Attendance off suppresses Leave without altering base observations') FROM observed,calculator_fixture,half_context;
SELECT is(pg_temp.overlay(base,'{}',policy,'[]',true)->>'leave_compatibility_state','none','empty Leave context remains none') FROM observed,calculator_fixture;
SELECT is(pg_temp.overlay(base||'{"state":"needs_review","exception_code":"outside_window","owner_permission":"attendance.correct"}','{}',policy,context,true)->>'exception_code','outside_window','half Leave preserves independent recovery diagnostic') FROM observed,calculator_fixture,half_context;
SELECT is(pg_temp.overlay(base,'{}',policy,'[{"units":1}]',true)->>'exception_code','leave_full_date_covered','current full coverage stays explicit review during extraction') FROM observed,calculator_fixture;
SELECT is(pg_temp.overlay(base,'{}',policy,jsonb_set(context,'{0,policy_version}','2'),true)->>'exception_code','leave_mapping_review_required','mismatched frozen mapping stays review') FROM observed,calculator_fixture,half_context;
SELECT is(pg_temp.overlay(base,'{}',policy,jsonb_set(context,'{0,mapping_snapshot,mapping,remaining_intervals,0,start_at}','"bad"'),true)->>'exception_code','leave_mapping_review_required','malformed domain mapping retains its recovery diagnostic') FROM observed,calculator_fixture,half_context;
SELECT is(pg_temp.overlay(pg_temp.calculate('{}',policy,pg_temp.pair('2026-02-02T09:00Z','2026-02-02T17:00Z')),'{}',policy,context,true)->>'leave_compatibility_state','review_required','excused-work overlap is not silently approved') FROM calculator_fixture,half_context;
SELECT is(pg_temp.overlay(base||'{"input_fingerprint":"keep-source","reason":"ignored"}','{}',policy,context,true)->>'input_fingerprint','keep-source','overlay preserves fields outside its calculation') FROM observed,calculator_fixture,half_context;

WITH variants AS (
 SELECT part,wi||'{"break_minutes":45}' instance,policy||'{"break_minutes":45,"fixed_break_start":"12:00","fixed_break_end":"12:45","shift_start":"09:00","shift_end":"17:00","ends_next_day":false,"timezone_name":"UTC","policy_version":1,"head_version":1,"id":"dca80000-0000-4000-8000-000000000001"}' frozen_policy
 FROM calculator_fixture CROSS JOIN unnest(ARRAY['first','second']) part
), mapped AS (
 SELECT *,"time".leave_halfday_mapping(frozen_policy,'2026-02-02',part) mapping,
 CASE WHEN part='first' THEN pg_temp.pair('2026-02-02T13:22Z','2026-02-02T17:00Z') ELSE pg_temp.pair('2026-02-02T09:00Z','2026-02-02T13:22Z') END punches FROM variants
), reviewed AS (
 SELECT *,pg_temp.overlay("time".calculate_interpretation_values(instance,frozen_policy,punches,'2026-02-03'),instance,frozen_policy,
 jsonb_build_array(jsonb_build_object('units',0.5,'is_half_day',true,'half_day_part',part,'mapping_state','mapped','policy_template_id',instance->>'policy_template_id','policy_version',1,'algorithm_version','leave-halfday-v1','mapping_snapshot',jsonb_build_object('mapping',mapping))),true) result FROM mapped
)
SELECT ok(result @> jsonb_build_object('state','ready','leave_compatibility_state','compatible','worked_minutes',CASE WHEN part='first' THEN 218 ELSE 217 END,'late_minutes',0,'early_leave_minutes',0),'odd fixed remaining half preserves exact '||part||' allocation') FROM reviewed;

CREATE TEMP TABLE flexible AS SELECT wi||'{"schedule_kind":"flexible","required_minutes":481,"break_minutes":60,"expected_start":null,"expected_end":null}' wi,
 policy||'{"schedule_kind":"flexible","required_minutes":481,"flexible_halfday_break_minutes":30}' policy,
 jsonb_build_array(jsonb_build_object('is_half_day',true,'units',0.5,'half_day_part',NULL,'mapping_state','mapped','policy_template_id',wi->>'policy_template_id','policy_version',1,'algorithm_version','leave-halfday-v1',
 'mapping_snapshot','{"mapping":{"schedule_kind":"flexible","state":"mapped","remaining_net_threshold_minutes":241,"halfday_break_minutes":30}}'::jsonb)) context FROM calculator_fixture;
SELECT ok(pg_temp.overlay("time".calculate_interpretation_values(wi,policy,pg_temp.pair('2026-02-02T09:00Z','2026-02-02T13:31Z'),'2026-02-03'),wi,policy,context,true) @>
 '{"state":"ready","worked_minutes":241,"applied_break_minutes":30,"leave_compatibility_state":"compatible"}','odd flexible requirement needs241 net with explicit half break') FROM flexible;
SELECT is(pg_temp.overlay("time".calculate_interpretation_values(wi,policy,pg_temp.pair('2026-02-02T09:00Z','2026-02-02T13:30Z'),'2026-02-03'),wi,policy,context,true)->>'exception_code','leave_remaining_half_threshold_not_met','240 net cannot meet odd half obligation') FROM flexible;
SELECT is(pg_temp.overlay('{"state":"ready","gross_worked_minutes":271}',wi,NULL,context,true)->>'leave_compatibility_state','review_required','missing frozen flexible policy cannot prove compatibility') FROM flexible;

SELECT throws_ok($$SELECT pg_temp.overlay('{"state":"ready"}','{}',NULL,NULL,true)$$,'22023','apply_leave_context_invalid_input','NULL context is a programming error');
SELECT throws_ok($$SELECT pg_temp.overlay('{"state":"ready"}','{}',NULL,'{}',true)$$,'22023','apply_leave_context_invalid_input','object context is rejected');
SELECT throws_ok($$SELECT pg_temp.overlay('{"state":"ready"}','{}',NULL,'[]',NULL)$$,'22023','apply_leave_context_invalid_input','unknown Attendance capability is rejected');
SELECT throws_ok($$SELECT pg_temp.overlay('{}','{}',NULL,'[]',true)$$,'22023','apply_leave_context_invalid_input','absent interpretation is rejected');
SELECT throws_ok($$SELECT pg_temp.calculate('{"schedule_kind":"bad"}',NULL,'[]')$$,'22023','calculate_interpretation_values_invalid_input','invalid schedule is rejected');
SELECT throws_ok($$SELECT pg_temp.calculate('{}',NULL,'[{"id":"dca90000-0000-4000-8000-000000000001","direction":"bad","happened_at":"2026-02-02"}]')$$,'22023','calculate_interpretation_values_invalid_input','invalid normalized direction is rejected');

CREATE TEMP TABLE effects_before AS SELECT (SELECT count(*) FROM "time".interpretations) interpretations,(SELECT count(*) FROM "time".attendance_facts) facts,
 (SELECT count(*) FROM "time".work_instances) instances,(SELECT count(*) FROM leave.ledger_entries) ledger,(SELECT count(*) FROM "time".attendance_audit_events) audit;
SELECT is(pg_temp.calculate('{}',policy,pg_temp.pair('2026-02-02T12:30Z','2026-02-02T17:00Z')),base,'same explicit input produces identical observation') FROM observed,calculator_fixture;
SELECT pg_temp.overlay(base,'{}',policy,context,true) IS NOT NULL FROM observed,calculator_fixture,half_context;
SELECT ok((SELECT count(*) FROM "time".interpretations)=interpretations AND (SELECT count(*) FROM "time".attendance_facts)=facts AND
 (SELECT count(*) FROM "time".work_instances)=instances AND (SELECT count(*) FROM leave.ledger_entries)=ledger AND (SELECT count(*) FROM "time".attendance_audit_events)=audit,'pure preview appends zero operational effects') FROM effects_before;
SELECT ok(NOT has_function_privilege(r,signature,'EXECUTE'),r||' cannot execute '||signature)
FROM unnest(ARRAY['anon','authenticated','service_role']) r CROSS JOIN unnest(ARRAY[
 '"time".calculate_interpretation_values(jsonb,jsonb,jsonb,timestamp with time zone)',
 '"time".apply_leave_context_to_interpretation("time".interpretations,"time".work_instances,"time".work_policy_versions,jsonb,boolean)',
 '"time".interpret_work_instance(uuid,uuid,uuid)','"time".snapshot_approved_leave_on_interpretation()']) signature;
SELECT * FROM finish();
ROLLBACK;
