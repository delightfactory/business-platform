-- Original UX plan7.5: saved full-candidate observations, never a new readiness gate.
CREATE FUNCTION payroll.candidate_stage_facts(p_output jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $function$
DECLARE facts jsonb;issue_facts jsonb;
BEGIN
 IF jsonb_typeof(p_output) IS DISTINCT FROM 'object' OR jsonb_typeof(p_output->'employees') IS DISTINCT FROM 'array'
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_output->'employees') e WHERE jsonb_typeof(e) IS DISTINCT FROM 'object')
 THEN RETURN NULL; END IF;
 WITH rows AS (
  SELECT e->'source_summary' s FROM jsonb_array_elements(p_output->'employees') e
 ), normalized AS (
  SELECT
   CASE WHEN s->>'status' IN('reconciliation_ready','needs_source_review','disabled') THEN s->>'status' ELSE 'unknown' END source,
   CASE WHEN s->>'coverage'='operational_complete' AND s->'operational_complete'='true'::jsonb THEN 'operational_complete'
     WHEN s->>'coverage' IN('approved_manual_total','captured_parts_only','approved_leave_sources') THEN s->>'coverage' ELSE 'unknown' END coverage,
   CASE WHEN s->'time_coverage'->>'status' IN('observationally_complete','needs_source_review','disabled','unavailable') THEN s->'time_coverage'->>'status' ELSE 'unknown' END time_coverage,
   CASE WHEN jsonb_typeof(s->'time_enabled')='boolean' THEN s->>'time_enabled' ELSE 'unknown' END time_enabled,
   CASE WHEN jsonb_typeof(s->'leave_enabled')='boolean' THEN s->>'leave_enabled' ELSE 'unknown' END leave_enabled
  FROM rows
 )
 SELECT jsonb_build_object('contract_version',1,'employee_count',count(*),
  'source',jsonb_build_object('reconciliation_ready',count(*) FILTER(WHERE source='reconciliation_ready'),'needs_source_review',count(*) FILTER(WHERE source='needs_source_review'),'disabled',count(*) FILTER(WHERE source='disabled'),'unknown',count(*) FILTER(WHERE source='unknown')),
  'coverage',jsonb_build_object('operational_complete',count(*) FILTER(WHERE coverage='operational_complete'),'approved_manual_total',count(*) FILTER(WHERE coverage='approved_manual_total'),'captured_parts_only',count(*) FILTER(WHERE coverage='captured_parts_only'),'approved_leave_sources',count(*) FILTER(WHERE coverage='approved_leave_sources'),'unknown',count(*) FILTER(WHERE coverage='unknown')),
  'time_coverage',jsonb_build_object('observationally_complete',count(*) FILTER(WHERE time_coverage='observationally_complete'),'needs_source_review',count(*) FILTER(WHERE time_coverage='needs_source_review'),'disabled',count(*) FILTER(WHERE time_coverage='disabled'),'unavailable',count(*) FILTER(WHERE time_coverage='unavailable'),'unknown',count(*) FILTER(WHERE time_coverage='unknown')),
  'time_enabled',jsonb_build_object('true',count(*) FILTER(WHERE time_enabled='true'),'false',count(*) FILTER(WHERE time_enabled='false'),'unknown',count(*) FILTER(WHERE time_enabled='unknown')),
  'leave_enabled',jsonb_build_object('true',count(*) FILTER(WHERE leave_enabled='true'),'false',count(*) FILTER(WHERE leave_enabled='false'),'unknown',count(*) FILTER(WHERE leave_enabled='unknown')),
  'gross_complete',CASE WHEN jsonb_typeof(p_output->'gross_complete')='boolean' THEN p_output->'gross_complete' ELSE NULL END,
  'financially_qualified',CASE WHEN jsonb_typeof(p_output->'financially_qualified')='boolean' THEN p_output->'financially_qualified' ELSE NULL END
 ) INTO facts FROM normalized;
 IF jsonb_typeof(p_output->'issues')='array' THEN
  SELECT jsonb_build_object('blocking_true',count(*) FILTER(WHERE i->'blocking'='true'::jsonb),
   'blocking_false',count(*) FILTER(WHERE i->'blocking'='false'::jsonb),
   'blocking_unknown',count(*) FILTER(WHERE jsonb_typeof(i->'blocking') IS DISTINCT FROM 'boolean'))
  INTO issue_facts FROM jsonb_array_elements(p_output->'issues') i;
 END IF;
 RETURN facts||jsonb_build_object('issues',issue_facts);
END
$function$;
REVOKE ALL ON FUNCTION payroll.candidate_stage_facts(jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.attach_candidate_stage_facts_definition(p_definition text) RETURNS text
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $function$
DECLARE anchor text:='''summary'',summary';occurrences integer;
BEGIN
 occurrences:=(length(p_definition)-length(replace(p_definition,anchor,'')))/length(anchor);
 IF p_definition IS NULL OR occurrences IS DISTINCT FROM 1 OR position('''stage_facts''' IN p_definition)>0
 THEN RAISE EXCEPTION 'payroll_stage_facts_definition_drift'; END IF;
 RETURN replace(p_definition,anchor,'''stage_facts'',payroll.candidate_stage_facts(candidate.output),'||anchor);
END
$function$;
REVOKE ALL ON FUNCTION payroll.attach_candidate_stage_facts_definition(text) FROM PUBLIC,anon,authenticated,service_role;

DO $migration$
DECLARE definition text;
BEGIN
 definition:=pg_get_functiondef('payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean)'::regprocedure);
 EXECUTE payroll.attach_candidate_stage_facts_definition(definition);
END
$migration$;
