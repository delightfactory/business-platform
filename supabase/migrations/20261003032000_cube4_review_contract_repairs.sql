-- Additive review repairs; public financial release remains closed.
-- Exact request/preview or the existing authorized Leave replacement event only.
-- A cancelled unrelated request never licenses a new historical approval.
CREATE OR REPLACE FUNCTION payroll.guard_unbound_leave_approval() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM leave.requests request WHERE request.tenant_id=NEW.tenant_id
  AND request.id=NEW.id AND request.state='approved') THEN RETURN NEW;END IF;
 IF EXISTS(
  SELECT 1 FROM leave.request_days day_row
  JOIN payroll.final_employees final_employee ON final_employee.tenant_id=NEW.tenant_id
   AND final_employee.employer_id=NEW.employer_entity_id AND final_employee.employment_id=NEW.employment_id
  JOIN payroll.final_contexts context ON context.tenant_id=final_employee.tenant_id
   AND context.id=final_employee.output_id AND context.employer_id=final_employee.employer_id
  CROSS JOIN LATERAL jsonb_array_elements(context.manifest->'employees') employee
  WHERE day_row.tenant_id=NEW.tenant_id AND day_row.request_id=NEW.id
   AND day_row.preview_version=NEW.approved_preview_version
   AND context.manifest->'optional'->>'leave'='true'
   AND employee->'employment'->>'id'=NEW.employment_id::text
   AND day_row.leave_date BETWEEN
    greatest((context.manifest->'period'->>'starts_on')::date,(employee->'employment'->>'start_date')::date)
    AND least((context.manifest->'period'->>'ends_on')::date,
     COALESCE((employee->'employment'->>'end_date')::date,(context.manifest->'period'->>'ends_on')::date))
   AND NOT EXISTS(SELECT 1 FROM payroll.output_successions succession
    WHERE succession.tenant_id=context.tenant_id AND succession.original_output=context.id)
   AND NOT EXISTS(SELECT 1 FROM payroll.final_source_bindings binding
    WHERE binding.tenant_id=context.tenant_id AND binding.output_id=context.id
     AND binding.employment_id=NEW.employment_id AND binding.source_domain='leave'
     AND binding.source_date=day_row.leave_date
     AND ((binding.source_identity->>'request_id'=NEW.id::text
       AND binding.source_version->>'approved_preview_version'=NEW.approved_preview_version::text)
      OR EXISTS(SELECT 1 FROM leave.correction_events event
       JOIN leave.requests original ON original.tenant_id=event.tenant_id AND original.id=event.original_request_id
       WHERE event.tenant_id=NEW.tenant_id AND event.replacement_request_id=NEW.id
        AND event.original_request_id::text=binding.source_identity->>'request_id'
        AND event.event_key='hr.corrected' AND event.to_state='superseded'
        AND original.state='superseded'))))
 ) THEN RAISE EXCEPTION 'payroll_locked_leave_addition_requires_correction' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION payroll.guard_unbound_leave_approval() FROM PUBLIC,anon,authenticated,service_role;

-- Versioned immutable statutory presentation, including a zero tax delta.
DO $patch$ DECLARE definition text;before text;after text;BEGIN
 definition:=pg_get_functiondef('payroll.calculate_statutory_employee(jsonb,uuid,jsonb,uuid,jsonb)'::regprocedure);
 before:='''statutory'',true,''amount'',(branch->>''employee_amount'')';after:='''statutory'',true,''presentation'',jsonb_build_object(''schema'',''payroll-statutory-v1'',''visible'',true,''order'',1100,''pack_id'',p_insurance_pack),''amount'',(branch->>''employee_amount'')';
 IF (length(definition)-length(replace(definition,before,'')))/length(before)<>1 THEN
  RAISE EXCEPTION 'unexpected_statutory_presentation_anchor';END IF;
 definition:=replace(definition,before,after);
 before:='''statutory'',true,''amount'',(branch->>''employer_amount'')';after:='''statutory'',true,''presentation'',jsonb_build_object(''schema'',''payroll-statutory-v1'',''visible'',true,''order'',1100,''pack_id'',p_insurance_pack),''amount'',(branch->>''employer_amount'')';
 IF (length(definition)-length(replace(definition,before,'')))/length(before)<>1 THEN
  RAISE EXCEPTION 'unexpected_statutory_presentation_anchor';END IF;
 definition:=replace(definition,before,after);
 before:='''statutory'',true,''amount'',tax_delta::text';after:='''statutory'',true,''presentation'',jsonb_build_object(''schema'',''payroll-statutory-v1'',''visible'',true,''order'',1200,''pack_id'',p_tax_pack),''amount'',tax_delta::text';
 IF (length(definition)-length(replace(definition,before,'')))/length(before)<>1 THEN
  RAISE EXCEPTION 'unexpected_statutory_presentation_anchor';END IF;
 definition:=replace(definition,before,after);
 before:='''pack_id'',p_tax_pack,''facts'',p_facts';after:='''pack_id'',p_tax_pack,''insurance_pack_id'',p_insurance_pack,''facts'',p_facts';
 IF (length(definition)-length(replace(definition,before,'')))/length(before)<>1 THEN
  RAISE EXCEPTION 'unexpected_statutory_presentation_anchor';END IF;
 definition:=replace(definition,before,after);
 EXECUTE definition;
END $patch$;

CREATE OR REPLACE FUNCTION payroll.report_payslip_lines(p_manifest jsonb,p_result jsonb,p_employment uuid,p_explanation jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 WITH employee AS(SELECT e FROM jsonb_array_elements(p_result->'employees') e WHERE e->>'employment_id'=p_employment::text),
 saved_lines AS(SELECT line,ordinal FROM jsonb_array_elements(p_explanation->'lines') WITH ORDINALITY x(line,ordinal)),
 resolved AS(SELECT l.line,l.ordinal,
  CASE WHEN l.line->>'component'='base' OR l.line->>'component' LIKE 'advance:%' THEN true
   ELSE COALESCE(statutory_metadata.known,metadata.known,false) END known,
  CASE WHEN l.line->>'classification'='employer_cost' THEN false
   WHEN l.line->>'component'='base' OR l.line->>'component' LIKE 'advance:%' THEN true
   ELSE COALESCE(statutory_metadata.visible,metadata.visible) END visible,
  CASE WHEN l.line->>'component'='base' THEN -1 WHEN l.line->>'component' LIKE 'advance:%' THEN 1000 ELSE COALESCE(statutory_metadata.display_order,metadata.display_order,999) END display_order
 FROM saved_lines l LEFT JOIN LATERAL(
  SELECT count(*)>0 AND bool_and(component->'version'->'data'->>'visible' IN('true','false')) AND count(DISTINCT component->'version'->'data'->>'visible')=1 AND count(component->'version'->'data'->>'visible')=count(*) known,
   bool_and(component->'version'->'data'->>'visible'='true') visible,
   min(CASE WHEN component->'version'->'data'->>'order' ~ '^[0-9]{1,3}$' THEN(component->'version'->'data'->>'order')::integer END) display_order
  FROM employee CROSS JOIN LATERAL jsonb_array_elements(employee.e->'lines') raw_line CROSS JOIN LATERAL jsonb_array_elements(raw_line->'details') part
  LEFT JOIN LATERAL(SELECT CASE
   WHEN part->>'component_version' IS NOT NULL THEN(SELECT input FROM jsonb_array_elements(p_manifest->'inputs') input WHERE input->'head'->>'kind'='component' AND input->'version'->>'id'=part->>'component_version' LIMIT 1)
   WHEN part->>'input_version' IS NOT NULL THEN(SELECT payroll.manifest_input(p_manifest,(input->'version'->'data'->>'component_id')::uuid,(p_manifest->'period'->>'starts_on')::date) FROM jsonb_array_elements(p_manifest->'inputs') input WHERE input->'head'->>'kind'='adjustment' AND input->'version'->>'id'=part->>'input_version' LIMIT 1)
   END component) version ON true
  WHERE raw_line->>'component'=l.line->>'component' AND raw_line->>'classification'=l.line->>'classification'
 ) metadata ON true
 LEFT JOIN LATERAL(
  SELECT count(*)=1 AND bool_and(
    raw_line->>'statutory'='true'
    AND raw_line->'presentation'->>'schema'='payroll-statutory-v1'
    AND raw_line->'presentation'->>'visible'='true'
    AND raw_line->'presentation'->>'order' ~ '^[0-9]{1,4}$'
    AND raw_line->>'amount'=l.line->>'amount'
    AND raw_line->>'name'=l.line->>'name'
    AND employee.e->'statutory_calculation'->>'adapter'='eg-employee-statutory-v1'
    AND raw_line->'presentation'->>'pack_id'=CASE WHEN l.line->>'component'='statutory:tax'
      THEN employee.e->'statutory_calculation'->>'pack_id'
      ELSE employee.e->'statutory_calculation'->>'insurance_pack_id' END
  ) known,
  bool_and(raw_line->>'classification'='deduction') visible,
  min(CASE WHEN raw_line->'presentation'->>'order' ~ '^[0-9]{1,4}$'
    THEN (raw_line->'presentation'->>'order')::integer END) display_order
  FROM employee CROSS JOIN LATERAL jsonb_array_elements(employee.e->'lines') raw_line
  WHERE raw_line->>'component'=l.line->>'component'
   AND raw_line->>'classification'=l.line->>'classification'
   AND ((l.line->>'component'='statutory:tax' AND l.line->>'classification'='deduction')
    OR (l.line->>'component' LIKE 'statutory:insurance:%' AND l.line->>'classification'='deduction')
    OR (l.line->>'component' LIKE 'statutory:employer:%' AND l.line->>'classification'='employer_cost'))
 ) statutory_metadata ON l.line->>'component' LIKE 'statutory:%')
 SELECT jsonb_build_object('complete',COALESCE(bool_and(known),true),'lines',COALESCE(jsonb_agg(jsonb_build_object('name',line->>'name','classification',line->>'classification','amount',line->>'amount') ORDER BY display_order,ordinal) FILTER(WHERE known AND visible),'[]')) FROM resolved
$f$;
REVOKE ALL ON FUNCTION payroll.report_payslip_lines(jsonb,jsonb,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
