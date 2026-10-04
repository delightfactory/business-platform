-- Presentation-only compatibility with the already frozen reviewed segment
-- contract. Never recompute money or consult a current catalog/legal pack.
CREATE FUNCTION payroll.grouped_statutory_line_valid(p_employee jsonb,p_line jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE segment jsonb;calculation jsonb;branch jsonb;expected jsonb:='[]';total numeric:=0;
 first_pack text;matched_pack text;matches integer:=0;component text:=p_line->>'component';
 previous date:=(p_employee->>'starts_on')::date-1;starts date;ends date;
BEGIN
 IF jsonb_typeof(p_employee->'statutory_segments') IS DISTINCT FROM 'array'
  OR jsonb_array_length(p_employee->'statutory_segments') NOT BETWEEN 2 AND 24
  OR jsonb_typeof(p_line->'details') IS DISTINCT FROM 'array' THEN RETURN false;END IF;
 FOR segment IN SELECT value FROM jsonb_array_elements(p_employee->'statutory_segments') LOOP
  calculation:=segment->'statutory_calculation';starts:=(segment->>'starts_on')::date;ends:=(segment->>'ends_on')::date;
  IF starts IS NULL OR ends IS NULL OR NOT isfinite(starts) OR NOT isfinite(ends) OR starts IS DISTINCT FROM previous+1 OR ends<starts OR ends>(p_employee->>'ends_on')::date THEN RETURN false;END IF;
  previous:=ends;
  IF calculation->>'adapter' IS DISTINCT FROM 'eg-employee-statutory-v1'
   OR calculation->'tax'->>'adapter' IS DISTINCT FROM 'eg-cumulative-tax-v1'
   OR coalesce(calculation->>'pack_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   OR calculation->'tax'->>'pack_id' IS DISTINCT FROM calculation->>'pack_id'
   OR calculation->'tax'->>'earning_from' IS DISTINCT FROM segment->>'starts_on'
   OR calculation->'tax'->>'earning_until' IS DISTINCT FROM segment->>'ends_on'
   OR calculation->'facts'->>'earning_from' IS DISTINCT FROM segment->>'starts_on'
   OR calculation->'facts'->>'earning_until' IS DISTINCT FROM segment->>'ends_on'
   OR calculation->'tax'->>'current_tax_delta' IS NULL THEN RETURN false;END IF;
  IF component='statutory:tax' THEN
   IF first_pack IS NULL THEN first_pack:=calculation->>'pack_id';END IF;
   expected:=expected||jsonb_build_array(calculation->'tax');
   total:=total+(calculation->'tax'->>'current_tax_delta')::numeric;
  ELSE
   IF jsonb_typeof(calculation->'insurance'->'lines') IS DISTINCT FROM 'array' THEN RETURN false;END IF;
   FOR branch IN SELECT value FROM jsonb_array_elements(calculation->'insurance'->'lines') LOOP
    IF component=(CASE WHEN p_line->>'classification'='deduction' THEN 'statutory:insurance:'
      WHEN p_line->>'classification'='employer_cost' THEN 'statutory:employer:' END)||(branch->>'branch')||':'||(branch->>'month') THEN
     IF calculation->'insurance'->>'adapter' IS DISTINCT FROM 'eg-insurance-month-v1'
      OR calculation->'insurance'->>'pack_id' IS DISTINCT FROM calculation->>'insurance_pack_id' THEN RETURN false;END IF;
     matches:=matches+1;matched_pack:=calculation->>'insurance_pack_id';
     expected:=jsonb_build_array(branch);
     total:=(branch->>CASE WHEN p_line->>'classification'='deduction' THEN 'employee_amount' ELSE 'employer_amount' END)::numeric;
    END IF;
   END LOOP;
  END IF;
 END LOOP;
 IF previous IS DISTINCT FROM (p_employee->>'ends_on')::date THEN RETURN false;END IF;
 IF component='statutory:tax' THEN
  RETURN coalesce(p_line->>'classification'='deduction' AND first_pack IS NOT NULL
   AND p_line->'presentation'->>'pack_id'=first_pack AND p_line->'details'=expected
   AND (p_line->>'amount')::numeric=total,false);
 END IF;
 RETURN coalesce(matches=1 AND matched_pack IS NOT NULL
  AND p_line->'presentation'->>'pack_id'=matched_pack AND p_line->'details'=expected
  AND (p_line->>'amount')::numeric=total,false);
EXCEPTION WHEN data_exception THEN RETURN false;
END $f$;
REVOKE ALL ON FUNCTION payroll.grouped_statutory_line_valid(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.report_payslip_lines(jsonb,jsonb,uuid,jsonb)'::regprocedure);
 anchor:=$old$AND employee.e->'statutory_calculation'->>'adapter'='eg-employee-statutory-v1'
    AND raw_line->'presentation'->>'pack_id'=CASE WHEN l.line->>'component'='statutory:tax'
      THEN employee.e->'statutory_calculation'->>'pack_id'
      ELSE employee.e->'statutory_calculation'->>'insurance_pack_id' END$old$;
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_grouped_statutory_presentation';END IF;
 EXECUTE replace(definition,anchor,$insert$AND CASE WHEN employee.e ? 'statutory_segments' THEN payroll.grouped_statutory_line_valid(employee.e,raw_line)
    ELSE employee.e->'statutory_calculation'->>'adapter'='eg-employee-statutory-v1'
     AND raw_line->'presentation'->>'pack_id'=CASE WHEN l.line->>'component'='statutory:tax'
      THEN employee.e->'statutory_calculation'->>'pack_id'
      ELSE employee.e->'statutory_calculation'->>'insurance_pack_id' END END$insert$);
END $patch$;
