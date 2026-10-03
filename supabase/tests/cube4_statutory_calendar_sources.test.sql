SELECT no_plan();
CREATE TEMP TABLE calendar_scope AS SELECT
 '{"period":{"starts_on":"2026-12-25","ends_on":"2027-01-24"},"employees":[{"employment":{"id":"f1450000-0000-4000-8000-000000000001","employee_id":"f1450000-0000-4000-8000-000000000002","pay_basis":"monthly","start_date":"2026-01-01","end_date":null}}]}'::jsonb manifest,
 '{"employment_id":"f1450000-0000-4000-8000-000000000001","employee_id":"f1450000-0000-4000-8000-000000000002","starts_on":"2026-12-25","ends_on":"2027-01-24"}'::jsonb employee,
 '{"contexts":[{"from":"2026-12-25","through":"2027-01-10","head_id":"f1450000-0000-4000-8000-000000000003","version_id":"old","source":{"version":{"data":{"insurance_status":"insured","insured_wage":"100","reference":"NONLEGAL old wage"}}}},{"from":"2027-01-11","through":"2027-01-24","head_id":"f1450000-0000-4000-8000-000000000003","version_id":"new","source":{"version":{"data":{"insurance_status":"insured","insured_wage":"200","reference":"NONLEGAL changed wage"}}}}]}'::jsonb sources;
CREATE TEMP TABLE calendar_result AS SELECT payroll.employee_statutory_calendar(manifest,employee,sources) value FROM calendar_scope;
SELECT ok(NOT has_function_privilege('authenticated','payroll.employee_statutory_calendar(jsonb,jsonb,jsonb)','EXECUTE'),'calendar composition cannot be supplied by ordinary API actors');
SELECT is((SELECT value->>'known' FROM calendar_result),'true','unique actual employment supplies calendar facts');
SELECT is(jsonb_array_length((SELECT value->'months' FROM calendar_result)),2,'25 to24 crosses two calendar months');
SELECT is((SELECT value->'months'->0->>'calendar_days' FROM calendar_result),'7','December has seven covered dates');
SELECT is((SELECT value->'months'->1->>'calendar_days' FROM calendar_result),'24','January has twenty-four covered dates');
SELECT is(jsonb_array_length((SELECT value->'years' FROM calendar_result)),2,'tax-year boundary remains explicit');
SELECT is((SELECT value->'years'->1->>'year' FROM calendar_result),'2027','new year is not inferred from period name/payment date');
SELECT is((SELECT value->>'legal_duration_days' FROM calendar_result),NULL::text,'calendar days never silently become legal duration');
SELECT is((SELECT value->>'obligation_months' FROM calendar_result),NULL::text,'calendar fragments never silently become insurance obligations');
SELECT is((SELECT value->>'financially_qualified' FROM calendar_result),'false','factual projection does not enable payroll approval');
SELECT is(jsonb_array_length((SELECT value->'months'->1->'contexts' FROM calendar_result)),2,'dated wage change survives inside a month');
SELECT is((SELECT value->'months'->1->'contexts'->0->>'from' FROM calendar_result),'2027-01-01','context is clipped to its own month');
SELECT is((SELECT value->'months'->1->'contexts'->1->'data'->>'insured_wage' FROM calendar_result),'200','actual versioned wage is retained without averaging');
SELECT is((SELECT value->'months'->1->>'full_service_month' FROM calendar_result),'true','service coverage is independent of business-period coverage');
SELECT is(payroll.employee_statutory_calendar((SELECT jsonb_set(manifest,'{employees}','[]') FROM calendar_scope),(SELECT employee FROM calendar_scope),(SELECT sources FROM calendar_scope))->>'known','false','missing actual employment is unknown');
SELECT is(payroll.employee_statutory_calendar((SELECT manifest FROM calendar_scope),(SELECT employee||'{"employee_id":"f1450000-0000-4000-8000-000000000004"}' FROM calendar_scope),(SELECT sources FROM calendar_scope))->>'known','false','another employee cannot borrow source identity');
SELECT throws_ok($$SELECT payroll.employee_statutory_calendar((SELECT manifest FROM calendar_scope),(SELECT employee||'{"starts_on":"2026-12-26"}' FROM calendar_scope),(SELECT sources FROM calendar_scope))$$,'22023','payroll_statutory_calendar_invalid','unreviewed clipping cannot hide a covered date');
SELECT is(payroll.employee_statutory_calendar((SELECT jsonb_set(manifest,'{employees,0,employment,end_date}','"2027-01-05"') FROM calendar_scope),(SELECT employee||'{"ends_on":"2027-01-05"}' FROM calendar_scope),(SELECT sources FROM calendar_scope))->'months'->1->>'service_end_in_month','true','termination month is explicit without inferring contribution amount');
SELECT is(payroll.employee_statutory_calendar((SELECT jsonb_set(manifest,'{employees,0,employment,end_date}','"2027-01-05"') FROM calendar_scope),(SELECT employee||'{"ends_on":"2027-01-05"}' FROM calendar_scope),(SELECT sources FROM calendar_scope))->'months'->1->>'full_service_month','false','termination service month is not a complete service month');
SELECT is(payroll.employee_statutory_calendar((SELECT jsonb_set(manifest,'{employees,0,employment,start_date}','"2026-12-28"') FROM calendar_scope),(SELECT employee||'{"starts_on":"2026-12-28"}' FROM calendar_scope),(SELECT sources FROM calendar_scope))->'months'->0->>'calendar_days','4','join date clips actual covered dates');
SELECT is(payroll.employee_statutory_calendar((SELECT jsonb_set(manifest,'{employees,0,employment,start_date}','"2026-12-28"') FROM calendar_scope),(SELECT employee||'{"starts_on":"2026-12-28"}' FROM calendar_scope),(SELECT sources FROM calendar_scope))->'months'->0->>'service_start_in_month','true','partial joining month is explicit');
SELECT is(payroll.employee_statutory_calendar((SELECT jsonb_set(manifest,'{period}','{"starts_on":"2028-02-01","ends_on":"2028-02-29"}') FROM calendar_scope),(SELECT employee||'{"starts_on":"2028-02-01","ends_on":"2028-02-29"}' FROM calendar_scope),' {"contexts":[]}')->'months'->0->>'calendar_days','29','leap February stays29 factual dates without becoming29 legal monthly days');
SELECT is(payroll.employee_statutory_calendar((SELECT manifest FROM calendar_scope),(SELECT employee FROM calendar_scope),'{"contexts":[]}')->'months'->0->'contexts','[]'::jsonb,'missing insurance facts are absent, never a zero contribution');
-- Reuse one existing rollback operational fixture to prove the annotation reaches
-- the real authenticated calculate path; do not repeat unrelated fixture suites.
\ir cube4_employee_statutory_source_fixture.sql
SELECT is(pg_temp.employee()->'statutory_sources'->'calendar'->>'known','true','real calculate candidate carries actual employment/calendar annotation');
SELECT is(pg_temp.employee()->'statutory_sources'->'calendar'->'months'->0->>'month','2030-01-01','real25Jan to24Feb candidate carries January fragment');
SELECT is(pg_temp.employee()->'statutory_sources'->'calendar'->'months'->1->>'month','2030-02-01','real candidate carries February fragment');
SELECT is(pg_temp.employee()->>'net',NULL::text,'annotation does not bypass existing unqualified net gate');
SELECT * FROM finish();
