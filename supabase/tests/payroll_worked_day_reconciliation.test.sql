BEGIN;
SELECT plan(10);
SELECT is(payroll.review_issue_list('[null]')->0->>'blocking','true','malformed historical issue remains blocking');
SELECT is(payroll.review_issue_list('[null]')->0->>'owner','payroll_sources','malformed issue has actionable owner');
SELECT is(payroll.review_issue_list('[]'),'[]'::jsonb,'empty issues remain empty');
SELECT is(payroll.review_issue_list(jsonb_build_array(payroll.issue('source_quantity_unknown')))->0->>'code','source_quantity_unknown','real blocker retained');
CREATE TEMP TABLE worked_case AS
SELECT jsonb_build_object('id','00000000-0000-0000-0000-000000000003','tenant_id','00000000-0000-0000-0000-000000000001','employer_entity_id','00000000-0000-0000-0000-000000000002','employee_id','00000000-0000-0000-0000-000000000004','start_date','2026-10-16','payroll_eligible',true) employment,
jsonb_build_object('period',jsonb_build_object('id','00000000-0000-0000-0000-000000000005','tenant_id','00000000-0000-0000-0000-000000000001','employer_id','00000000-0000-0000-0000-000000000002','starts_on','2026-10-16','ends_on','2026-10-16'),
'inputs','[]'::jsonb,'optional',jsonb_build_object('time',true,'leave',false),
'optional_sources',jsonb_build_object('contract','cube4-optional-capture-v1','leave',jsonb_build_object('enabled',false),
'time',jsonb_build_object('enabled',true,'items',jsonb_build_array(jsonb_build_object('date','2026-10-16','employment_id','00000000-0000-0000-0000-000000000003','employee_id','00000000-0000-0000-0000-000000000004','outcome','worked','worked_minutes',480,'leave_units',0,'absence_units',NULL,'classification_reconciliation_required',false,'leave_bindings','[]'::jsonb))))) manifest;
SELECT is(payroll.reconcile_employee_sources(manifest,employment)->'issues','[]'::jsonb,'current approved worked fact reconciles without invented absence') FROM worked_case;
SELECT is(payroll.reconcile_employee_sources(manifest,employment)->'days'->0->>'work_units','1','worked day contributes one unit') FROM worked_case;
SELECT is(payroll.reconcile_employee_sources(jsonb_set(manifest,'{optional_sources,time,items,0,classification_reconciliation_required}','true'),employment)->'days'->0->>'work_units',NULL::text,'stale classification cannot supply payable units') FROM worked_case;
SELECT is(payroll.reconcile_employee_sources(jsonb_set(manifest,'{optional_sources,time,items,0,outcome}','"absence"'),employment)->'days'->0->>'work_units',NULL::text,'unknown absence is not converted to zero') FROM worked_case;
SELECT is(payroll.daily_source_parts(manifest,employment,jsonb_build_object('days',jsonb_build_array(jsonb_build_object('time_fact_count',1)),'issues',jsonb_build_array(payroll.issue('source_quantity_unknown'))),'[]',1000,1000)->'issues'->0->>'code','source_quantity_unknown','source errors survive JSON merge as objects') FROM worked_case;
SELECT is(payroll.daily_source_parts(manifest,employment,payroll.reconcile_employee_sources(manifest,employment),'[{"date":"2026-10-16","rate":"1000"}]',1000,1000)->>'units','1','normal approved day supplies daily calculation') FROM worked_case;
SELECT * FROM finish();
ROLLBACK;
