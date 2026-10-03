-- Freeze prior authoritative employee outputs into the calculation manifest.
-- Never sum cumulative tax results, infer missing prior values, or consume a
-- superseded output twice. Numeric/YTD composition remains a separate step.
CREATE FUNCTION payroll.prior_statutory_outputs(p_tenant uuid,p_employer uuid,p_from date,p_until date,p_people uuid[])
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'output_id',f.id,'run_id',f.run_id,'run_status',r.status,
   'employment_id',e.employment_id,'employee_id',h.employee_id,
   'starts_on',p.starts_on,'ends_on',p.ends_on,'engine_version',f.engine_version,
   'financially_qualified',f.result->'financially_qualified',
   'statutory_context',e.statutory_context,'calculation_count',calculation.match_count,
   'statutory_calculation',calculation.value->'statutory_calculation'
 ) ORDER BY p.ends_on,p.starts_on,f.id,e.employment_id),'[]')
 FROM payroll.final_contexts f
 JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id AND p.employer_id=f.employer_id
 JOIN payroll.runs r ON r.tenant_id=f.tenant_id AND r.id=f.run_id AND r.employer_id=f.employer_id
 JOIN payroll.final_employees e ON e.tenant_id=f.tenant_id AND e.output_id=f.id AND e.employer_id=f.employer_id
 JOIN people.employments h ON h.tenant_id=e.tenant_id AND h.id=e.employment_id AND h.employer_entity_id=f.employer_id
 LEFT JOIN LATERAL (
   SELECT count(*)::integer AS match_count,
     CASE WHEN count(*)=1 THEN jsonb_agg(value)->0 END AS value
   FROM jsonb_array_elements(CASE WHEN jsonb_typeof(f.result->'employees')='array' THEN f.result->'employees' ELSE '[]'::jsonb END)
   WHERE value->>'employment_id'=e.employment_id::text
 ) calculation ON true
 WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND h.employee_id=ANY(p_people)
   AND p.ends_on<p_from AND p.ends_on>=make_date(extract(year FROM p_from)::integer,1,1)
   AND p_from<=p_until
   AND NOT EXISTS(SELECT 1 FROM payroll.output_successions s WHERE s.tenant_id=f.tenant_id AND s.original_output=f.id)
$f$;
REVOKE ALL ON FUNCTION payroll.prior_statutory_outputs(uuid,uuid,date,date,uuid[]) FROM PUBLIC,anon,authenticated,service_role;

-- Structural admission only. Legal proof and numeric reconciliation remain
-- separate gates; incomplete historical snapshots must not look like zero YTD.
CREATE FUNCTION payroll.prior_statutory_output_usable(p_source jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE calculation jsonb:=p_source->'statutory_calculation';facts jsonb;tax jsonb;insurance jsonb;key text;first_date date;last_date date;
BEGIN
 IF p_source->>'financially_qualified' IS DISTINCT FROM 'true'
   OR p_source->>'run_status' IS DISTINCT FROM 'locked' OR p_source->>'calculation_count' IS DISTINCT FROM '1'
   OR calculation->>'adapter' IS DISTINCT FROM 'eg-employee-statutory-v1'
   OR jsonb_typeof(p_source->'statutory_context') IS DISTINCT FROM 'object' THEN RETURN false;END IF;
 facts:=calculation->'facts';tax:=calculation->'tax';insurance:=calculation->'insurance';
 IF jsonb_typeof(facts) IS DISTINCT FROM 'object' OR jsonb_typeof(tax) IS DISTINCT FROM 'object'
   OR jsonb_typeof(insurance) IS DISTINCT FROM 'object'
   OR coalesce(facts->>'insurance_status','') NOT IN('insured','not_insured') THEN RETURN false;END IF;
 FOREACH key IN ARRAY ARRAY['prior_net_income','current_taxable_earnings','cumulative_duration_days','prior_tax_due'] LOOP
   IF jsonb_typeof(facts->key) IS DISTINCT FROM 'number' OR coalesce(facts->>key,'') !~ '^[0-9]+(\.[0-9]+)?$' THEN RETURN false;END IF;
 END LOOP;
 FOREACH key IN ARRAY ARRAY['duration_days','cumulative_tax_due','prior_tax_due','current_tax_delta'] LOOP
   IF jsonb_typeof(tax->key) IS DISTINCT FROM 'number' OR coalesce(tax->>key,'') !~ '^-?[0-9]+(\.[0-9]+)?$' THEN RETURN false;END IF;
 END LOOP;
 FOREACH key IN ARRAY ARRAY['employee_total','employer_total','tax_deductible_employee_total'] LOOP
   IF jsonb_typeof(insurance->key) IS DISTINCT FROM 'number' OR coalesce(insurance->>key,'') !~ '^[0-9]+(\.[0-9]+)?$' THEN RETURN false;END IF;
 END LOOP;
 IF (facts->>'cumulative_duration_days')::numeric<=0 OR (facts->>'cumulative_duration_days')::numeric>360
   OR facts->'cumulative_duration_days'<>tax->'duration_days' OR facts->'prior_tax_due'<>tax->'prior_tax_due'
   OR (tax->>'cumulative_tax_due')::numeric<0
   OR (tax->>'current_tax_delta')::numeric<>(tax->>'cumulative_tax_due')::numeric-(tax->>'prior_tax_due')::numeric
   OR (insurance->>'tax_deductible_employee_total')::numeric>(insurance->>'employee_total')::numeric
   OR (insurance->>'tax_deductible_employee_total')::numeric>(facts->>'current_taxable_earnings')::numeric THEN RETURN false;END IF;
 IF facts->>'insurance_status'='not_insured' AND (
   (insurance->>'employee_total')::numeric<>0 OR (insurance->>'employer_total')::numeric<>0
   OR (insurance->>'tax_deductible_employee_total')::numeric<>0) THEN RETURN false;END IF;
 IF coalesce(facts->>'earning_from','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   OR coalesce(facts->>'earning_until','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   OR facts->'earning_from' IS DISTINCT FROM tax->'earning_from'
   OR facts->'earning_until' IS DISTINCT FROM tax->'earning_until' THEN RETURN false;END IF;
 BEGIN first_date:=(facts->>'earning_from')::date;last_date:=(facts->>'earning_until')::date;
 EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN false;END;
 RETURN coalesce(first_date<=last_date AND extract(year FROM first_date)=extract(year FROM last_date)
   AND first_date>=(p_source->>'starts_on')::date AND last_date<=(p_source->>'ends_on')::date
   AND p_source->'statutory_context'->>'calendar_year'=extract(year FROM last_date)::integer::text,false);
END $f$;
REVOKE ALL ON FUNCTION payroll.prior_statutory_output_usable(jsonb) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION payroll.run_manifest(uuid,uuid,uuid) RENAME TO run_manifest_before_prior_statutory_outputs;
CREATE FUNCTION payroll.run_manifest(p_tenant uuid,p_employer uuid,p_period uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE m jsonb;people_ids uuid[];
BEGIN
 m:=payroll.run_manifest_before_prior_statutory_outputs(p_tenant,p_employer,p_period);
 SELECT array_agg(DISTINCT (e->'employment'->>'employee_id')::uuid)
 INTO people_ids FROM jsonb_array_elements(m->'employees')e;
 RETURN m||jsonb_build_object('engine',(m->>'engine')||'-prior-finals-v1',
   'prior_statutory_outputs',payroll.prior_statutory_outputs(p_tenant,p_employer,
     (m->'period'->>'starts_on')::date,(m->'period'->>'ends_on')::date,people_ids));
END $f$;

ALTER FUNCTION payroll.stale_reasons(jsonb,jsonb) RENAME TO stale_reasons_before_prior_statutory_outputs;
CREATE FUNCTION payroll.stale_reasons(p_old jsonb,p_current jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT payroll.stale_reasons_before_prior_statutory_outputs(p_old,p_current)||
   CASE WHEN p_old->'prior_statutory_outputs' IS DISTINCT FROM p_current->'prior_statutory_outputs'
     THEN '["prior_statutory_outputs_changed"]'::jsonb ELSE '[]'::jsonb END
$f$;

ALTER FUNCTION payroll.employee_statutory_sources(jsonb,jsonb) RENAME TO employee_statutory_sources_before_prior_outputs;
CREATE FUNCTION payroll.employee_statutory_sources(p_manifest jsonb,p_employee jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE result jsonb;prior jsonb;issues jsonb;
BEGIN
 result:=payroll.employee_statutory_sources_before_prior_outputs(p_manifest,p_employee);
 SELECT coalesce(jsonb_agg(s ORDER BY s->>'ends_on',s->>'starts_on',s->>'output_id',s->>'employment_id'),'[]')
 INTO prior FROM jsonb_array_elements(coalesce(p_manifest->'prior_statutory_outputs','[]'))s
 WHERE s->>'employee_id'=p_employee->>'employee_id';
 issues:=result->'issues';
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(prior)s WHERE NOT coalesce(payroll.prior_statutory_output_usable(s),false)) THEN
   issues:=issues||jsonb_build_array(payroll.issue('prior_statutory_context_unqualified',
     (p_employee->>'employment_id')::uuid,'payroll_compliance'));
 END IF;
 RETURN result||jsonb_build_object('prior_outputs',prior,'issues',issues);
END $f$;
REVOKE ALL ON FUNCTION payroll.run_manifest(uuid,uuid,uuid),
 payroll.run_manifest_before_prior_statutory_outputs(uuid,uuid,uuid),
 payroll.stale_reasons(jsonb,jsonb),payroll.stale_reasons_before_prior_statutory_outputs(jsonb,jsonb),
 payroll.employee_statutory_sources(jsonb,jsonb),payroll.employee_statutory_sources_before_prior_outputs(jsonb,jsonb)
FROM PUBLIC,anon,authenticated,service_role;
