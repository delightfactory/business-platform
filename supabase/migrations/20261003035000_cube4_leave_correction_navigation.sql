-- Read-only, authorized navigation from an exact Leave request to its open
-- correction duties. URL values never establish output/source membership.
CREATE FUNCTION public.payroll_leave_correction_context(p_tenant uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE request leave.requests%ROWTYPE;result jsonb;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.correct',false);
 SELECT * INTO request FROM leave.requests WHERE tenant_id=p_tenant AND id=p_request;
 IF request.id IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 WITH RECURSIVE family(id) AS(
  SELECT request.id
  UNION
  SELECT CASE WHEN event.original_request_id=family.id THEN event.replacement_request_id ELSE event.original_request_id END
  FROM family JOIN leave.correction_events event ON event.tenant_id=p_tenant
   AND family.id IN(event.original_request_id,event.replacement_request_id)
  JOIN leave.requests related ON related.tenant_id=p_tenant
   AND related.id=CASE WHEN event.original_request_id=family.id THEN event.replacement_request_id ELSE event.original_request_id END
   AND related.employer_entity_id=request.employer_entity_id AND related.employment_id=request.employment_id
 ), current_observations AS(
  SELECT observation.* FROM payroll.source_correction_observations observation
  WHERE observation.tenant_id=p_tenant AND observation.employer_id=request.employer_entity_id
   AND observation.employment_id=request.employment_id AND observation.source_domain='leave'
   AND (observation.current_source_identity->>'request_id')::uuid IN(SELECT id FROM family)
   AND payroll.bound_source_envelope(p_tenant,'leave',observation.source_date,
    (observation.current_source_identity->>'request_id')::uuid)->>'fingerprint'=observation.current_lineage_fingerprint
   AND NOT EXISTS(SELECT 1 FROM payroll.correction_request_links link
    JOIN payroll.correction_cases correction ON correction.tenant_id=link.tenant_id AND correction.id=link.case_id
    WHERE link.tenant_id=p_tenant AND link.request_id=observation.requirement_id
     AND correction.status='completed' AND payroll.correction_requirement_is_current(p_tenant,correction.id,observation.requirement_id))
 ), output_sources AS(
  SELECT target,observation.id FROM current_observations observation
   CROSS JOIN LATERAL jsonb_array_elements(payroll.correction_observation_outputs(
    jsonb_populate_record(NULL::payroll.source_correction_observations,to_jsonb(observation)))) target
 ), outputs AS(
  SELECT target,jsonb_agg(DISTINCT id ORDER BY id) sources FROM output_sources GROUP BY target
 )
 SELECT jsonb_build_object('request_id',request.id,'employer_id',request.employer_entity_id,'employment_id',request.employment_id,
  'outputs',COALESCE(jsonb_agg(target||jsonb_build_object('source_ids',sources) ORDER BY target->>'starts_on',target->>'id'),'[]'::jsonb)) INTO result FROM outputs;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_leave_correction_context(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_leave_correction_context(uuid,uuid) TO authenticated;
