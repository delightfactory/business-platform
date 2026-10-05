-- Focused presentation invariants only. Synthetic saved inputs are not legal payroll.
BEGIN;
SELECT plan(17);
CREATE FUNCTION pg_temp.report_fixture() RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('manifest',jsonb_build_object('inputs',jsonb_build_array(
  jsonb_build_object('head',jsonb_build_object('kind','component','id','c4087000-0000-4000-8000-000000000001'),'version',jsonb_build_object('id','c4087100-0000-4000-8000-000000000001','data',jsonb_build_object('visible','true','order','20'))),
  jsonb_build_object('head',jsonb_build_object('kind','component','id','c4087000-0000-4000-8000-000000000002'),'version',jsonb_build_object('id','c4087100-0000-4000-8000-000000000002','data',jsonb_build_object('visible','false','order','10')))
 )),
 'result',jsonb_build_object('employees',jsonb_build_array(jsonb_build_object('employment_id','c4085000-0000-4000-8000-000000000001','starts_on','2030-01-25','lines',jsonb_build_array(
  jsonb_build_object('component','c4087000-0000-4000-8000-000000000001','classification','earning','details',jsonb_build_array(jsonb_build_object('component_version','c4087100-0000-4000-8000-000000000001'))),
  jsonb_build_object('component','c4087000-0000-4000-8000-000000000002','classification','earning','details',jsonb_build_array(jsonb_build_object('component_version','c4087100-0000-4000-8000-000000000002')))
 )))),
 'explanation',jsonb_build_object('lines',jsonb_build_array(
  jsonb_build_object('component','c4087000-0000-4000-8000-000000000001','name','Saved visible allowance','classification','earning','amount','100.03'),
  jsonb_build_object('component','base','name','Saved base','classification','earning','amount','1000.00'),
  jsonb_build_object('component','c4087000-0000-4000-8000-000000000002','name','Saved hidden allowance','classification','earning','amount','30.00'),
  jsonb_build_object('component','advance:c4087200-0000-4000-8000-000000000001','name','Saved advance installment','classification','deduction','amount','25.00')
 )))
$$;
CREATE FUNCTION pg_temp.present(f jsonb) RETURNS jsonb LANGUAGE sql AS $$
 SELECT payroll.report_payslip_lines(f->'manifest',f->'result','c4085000-0000-4000-8000-000000000001',f->'explanation')
$$;
SELECT is(pg_temp.present(pg_temp.report_fixture())->>'complete','true','complete saved visibility is qualified for presentation');
SELECT is(jsonb_array_length(pg_temp.present(pg_temp.report_fixture())->'lines'),3,'hidden component omitted while base and installment remain');
SELECT is(pg_temp.present(pg_temp.report_fixture())->'lines'->0->>'name','Saved base','base precedes configured components');
SELECT is(pg_temp.present(pg_temp.report_fixture())->'lines'->1->>'name','Saved visible allowance','frozen component name retained');
SELECT is(pg_temp.present(pg_temp.report_fixture())->'lines'->1->>'amount','100.03','finalized rounded amount retained exactly');
SELECT is(pg_temp.present(pg_temp.report_fixture())->'lines'->2->>'classification','deduction','saved installment stays explicit');
SELECT is(pg_temp.present(jsonb_set(pg_temp.report_fixture(),'{manifest,inputs,0,version,data,visible}','"false"'))->'lines'->1->>'name','Saved advance installment','saved hidden flag overrides presentation without deleting installment');
SELECT is(pg_temp.present(pg_temp.report_fixture() #- '{manifest,inputs,0,version,data,visible}')->>'complete','false','missing saved flag blocks distribution instead of guessing visible');
SELECT ok(NOT(pg_temp.present(pg_temp.report_fixture() #- '{manifest,inputs,0,version,data,visible}')->'lines' @> '[{"name":"Saved visible allowance"}]'),'unknown visibility does not leak the component');
SELECT is(pg_temp.present(jsonb_set(pg_temp.report_fixture(),'{explanation,lines,0,classification}','"employer_cost"'))->>'complete','false','unmatched contribution identity is incomplete');
SELECT is(pg_temp.present(jsonb_set(pg_temp.report_fixture(),'{result,employees,0,employment_id}','"c4085000-0000-4000-8000-000000000002"'))->>'complete','false','different employment cannot supply visibility metadata');
SELECT is(pg_temp.present(jsonb_set(pg_temp.report_fixture(),'{explanation,lines}','[]'))->'lines','[]'::jsonb,'empty finalized detail remains an empty presentation');

-- The employee starts later; adjustment calculation still resolves the component
-- at the saved period start. A successor changes both visibility and order.
CREATE FUNCTION pg_temp.midperiod_adjustment(first_visible boolean) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f jsonb:=pg_temp.report_fixture();inputs jsonb;adjustment_line jsonb;comparison_line jsonb;BEGIN
 inputs:=f->'manifest'->'inputs';
 inputs:=jsonb_set(jsonb_set(jsonb_set(inputs,'{0,version,effective_from}','"2030-01-25"'),'{0,version,revision}','1'),'{0,version,data,visible}',to_jsonb(first_visible::text));
 inputs:=jsonb_set(jsonb_set(jsonb_set(inputs,'{1,version,effective_from}','"2030-01-25"'),'{1,version,revision}','1'),'{1,version,data,visible}','"true"');
 inputs:=inputs||jsonb_build_array(jsonb_build_object('head',inputs->0->'head','version',jsonb_build_object('id','c4087100-0000-4000-8000-000000000003','revision',2,'effective_from','2030-02-01','data',jsonb_build_object('visible',(NOT first_visible)::text,'order','1'))),jsonb_build_object('head',jsonb_build_object('kind','adjustment','id','c4087000-0000-4000-8000-000000000004'),'version',jsonb_build_object('id','c4087100-0000-4000-8000-000000000004','data',jsonb_build_object('component_id','c4087000-0000-4000-8000-000000000001'))));
 f:=jsonb_set(f,'{manifest,inputs}',inputs);
 f:=jsonb_set(f,'{manifest}',f->'manifest'||jsonb_build_object('period',jsonb_build_object('starts_on','2030-01-25')));
 f:=jsonb_set(f,'{result,employees,0,starts_on}','"2030-02-10"');
 f:=jsonb_set(f,'{result,employees,0,lines}',jsonb_build_array(jsonb_build_object('component','adjustment:c4087000-0000-4000-8000-000000000004','classification','earning','details',jsonb_build_array(jsonb_build_object('input_version','c4087100-0000-4000-8000-000000000004'))),f->'result'->'employees'->0->'lines'->1));
 adjustment_line:=(f->'explanation'->'lines'->0)||jsonb_build_object('component','adjustment:c4087000-0000-4000-8000-000000000004');
 comparison_line:=(f->'explanation'->'lines'->2)||jsonb_build_object('name','Saved comparison allowance');
 RETURN jsonb_set(f,'{explanation,lines}',jsonb_build_array(adjustment_line,comparison_line));
END $$;
SELECT is(pg_temp.present(pg_temp.midperiod_adjustment(false))->>'complete','true','mid-period hire retains known period-start adjustment metadata');
SELECT is(jsonb_array_length(pg_temp.present(pg_temp.midperiod_adjustment(false))->'lines'),1,'period-start hidden adjustment is not exposed by later visible successor');
SELECT is(jsonb_array_length(pg_temp.present(pg_temp.midperiod_adjustment(true))->'lines'),2,'period-start visible adjustment is not hidden by later hidden successor');
SELECT is(pg_temp.present(pg_temp.midperiod_adjustment(true))->'lines'->0->>'name','Saved comparison allowance','old display order retained instead of newer order before hire');
SELECT is(pg_temp.present(pg_temp.midperiod_adjustment(true))->'lines'->1->>'amount','100.03','saved adjustment amount unchanged by metadata resolution');
SELECT * FROM finish();
ROLLBACK;
