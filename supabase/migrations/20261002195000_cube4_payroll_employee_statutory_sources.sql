-- Resolve actual source versions before any legal earning/month attribution.
CREATE FUNCTION payroll.employee_statutory_sources(p_manifest jsonb,p_employee jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE
 employment uuid:=(p_employee->>'employment_id')::uuid;
 person uuid:=(p_employee->>'employee_id')::uuid;
 starts date:=(p_employee->>'starts_on')::date; ends date:=(p_employee->>'ends_on')::date;
 mini jsonb; context_head uuid; head_count integer; d date; item jsonb; previous_version text;
 contexts jsonb:='[]'; openings jsonb:='[]'; issues jsonb:='[]'; gap boolean:=false;
 year_number integer; anchor date; candidates jsonb; opening jsonb;
BEGIN
 IF employment IS NULL OR person IS NULL OR starts IS NULL OR ends IS NULL OR NOT isfinite(starts) OR NOT isfinite(ends)
   OR ends-starts NOT BETWEEN 0 AND 365 THEN
   RAISE EXCEPTION 'payroll_statutory_source_scope_invalid' USING ERRCODE='22023';
 END IF;
 mini:=jsonb_build_object('inputs',coalesce((SELECT jsonb_agg(i) FROM jsonb_array_elements(p_manifest->'inputs')i
   WHERE i->'head'->>'kind'='statutory_context' AND i->'head'->>'employment_id'=employment::text),'[]'));
 SELECT count(DISTINCT i->'head'->>'id'),min(i->'head'->>'id')::uuid INTO head_count,context_head FROM jsonb_array_elements(mini->'inputs')i;
 IF head_count>1 THEN
   issues:=issues||jsonb_build_array(payroll.issue('employee_statutory_context_ambiguous',employment,'payroll_inputs'));
 ELSIF head_count=0 THEN gap:=true;
 ELSE
   FOR d IN SELECT generate_series(starts,ends,interval '1 day')::date ORDER BY 1 LOOP
     item:=payroll.manifest_input(mini,context_head,d);
     IF item IS NULL OR coalesce(item->'version'->>'status','') NOT IN ('draft','approved','applied')
       OR (item->'version'->>'effective_until' IS NOT NULL AND (item->'version'->>'effective_until')::date<=d) THEN
       gap:=true;previous_version:=NULL;CONTINUE;
     END IF;
     IF previous_version IS NOT DISTINCT FROM item->'version'->>'id' AND jsonb_array_length(contexts)>0 THEN
       contexts:=jsonb_set(contexts,ARRAY[(jsonb_array_length(contexts)-1)::text,'through'],to_jsonb(d));
     ELSE
       contexts:=contexts||jsonb_build_array(jsonb_build_object('from',d,'through',d,'head_id',context_head,
         'version_id',item->'version'->>'id','source',item));
     END IF;
     previous_version:=item->'version'->>'id';
   END LOOP;
 END IF;
 IF gap THEN issues:=issues||jsonb_build_array(payroll.issue('employee_statutory_context_missing',employment,'payroll_inputs')); END IF;
 -- Select opening facts for every calendar year touched, without assigning
 -- company-cycle earnings or taxable duration to those years.
 FOR year_number IN extract(year FROM starts)::integer..extract(year FROM ends)::integer LOOP
   anchor:=greatest(starts,make_date(year_number,1,1));
   SELECT coalesce(jsonb_agg(i),'[]') INTO candidates FROM(
     SELECT payroll.manifest_input(p_manifest,(h->>'id')::uuid,anchor) AS i FROM(
       SELECT DISTINCT x->'head' AS h FROM jsonb_array_elements(p_manifest->'inputs')x
       WHERE x->'head'->>'kind'='opening_ytd' AND
         (x->'head'->>'employment_id'=employment::text OR x->'head'->>'employee_id'=person::text)
     )heads
   )resolved WHERE i->'version'->'data'->>'year'=year_number::text
     AND coalesce(i->'version'->>'status','') IN ('draft','approved','applied')
     AND (i->'version'->>'effective_until' IS NULL OR (i->'version'->>'effective_until')::date>anchor);
   IF jsonb_array_length(candidates)<>1 THEN
     issues:=issues||jsonb_build_array(payroll.issue(CASE WHEN jsonb_array_length(candidates)=0 THEN 'opening_ytd_unknown' ELSE 'opening_ytd_ambiguous' END,employment,'payroll_ytd'));
     CONTINUE;
   END IF;
   opening:=candidates->0;
   openings:=openings||jsonb_build_array(jsonb_build_object('year',year_number,'as_of',anchor,'source',opening));
   IF NOT(opening->'version'->'data' ? 'tax_due') OR opening->'version'->'data'->'tax_due'='null'::jsonb THEN
     issues:=issues||jsonb_build_array(payroll.issue('opening_tax_due_unknown',employment,'payroll_ytd'));
   END IF;
   IF NOT(opening->'version'->'data' ?& ARRAY['coverage_start','coverage_end','tax_duration_days']) THEN
     issues:=issues||jsonb_build_array(payroll.issue('opening_tax_coverage_unknown',employment,'payroll_ytd'));
   END IF;
 END LOOP;
 IF extract(year FROM starts)<>extract(year FROM ends) THEN
   issues:=issues||jsonb_build_array(payroll.issue('statutory_earning_attribution_required',employment,'compliance'));
 END IF;
 RETURN jsonb_build_object('contract','cube4-employee-statutory-sources-v1','employment_id',employment,
   'employee_id',person,'contexts',contexts,'openings',openings,'issues',issues,'financially_qualified',false);
END $f$;
REVOKE ALL ON FUNCTION payroll.employee_statutory_sources(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
ALTER FUNCTION payroll.build_review(jsonb) RENAME TO build_review_before_statutory_sources;
CREATE FUNCTION payroll.build_review(p_manifest jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE result jsonb;e jsonb;sources jsonb;employees jsonb:='[]';issues jsonb;employee_issues jsonb;
BEGIN
 result:=payroll.build_review_before_statutory_sources(p_manifest);issues:=result->'issues';
 FOR e IN SELECT value FROM jsonb_array_elements(result->'employees') LOOP
   sources:=payroll.employee_statutory_sources(p_manifest,e);
   SELECT coalesce(jsonb_agg(i ORDER BY i),'[]') INTO employee_issues FROM(
     SELECT DISTINCT i FROM jsonb_array_elements((e->'issues')||(sources->'issues'))i
   )unique_issues;
   employees:=employees||jsonb_build_array(e||jsonb_build_object('statutory_sources',sources,'issues',employee_issues));
   issues:=issues||(sources->'issues');
 END LOOP;
 SELECT coalesce(jsonb_agg(i ORDER BY i),'[]') INTO issues FROM(SELECT DISTINCT i FROM jsonb_array_elements(issues)i)unique_issues;
 RETURN result||jsonb_build_object('employees',employees,'issues',issues);
END $f$;
REVOKE ALL ON FUNCTION payroll.build_review(jsonb),payroll.build_review_before_statutory_sources(jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;anchor text:='''-advances-v1-statutory-sources-v1''';BEGIN
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
   RAISE EXCEPTION 'unexpected_employee_statutory_engine_anchor';
 END IF;
 EXECUTE replace(definition,anchor,'''-advances-v1-statutory-sources-v1-employee-facts-v1''');
END $f$;
