-- Reuse existing exhaustive Time coverage, Leave reconciliation and approved
-- manual payable-total selection. No overtime or monthly absence policy is inferred.
CREATE FUNCTION payroll.daily_optional_financial_profile(p_manifest jsonb,p_employee jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE summary jsonb:=p_employee->'source_summary';employment text:=p_employee->>'employment_id';source jsonb;ot jsonb;
BEGIN
 IF NOT coalesce((p_manifest->'optional'->>'time')::boolean,false)
  AND NOT coalesce((p_manifest->'optional'->>'leave')::boolean,false) THEN RETURN true;END IF;
 IF p_employee->>'pay_basis' IS DISTINCT FROM 'daily'
  OR p_employee->>'gross_complete' IS DISTINCT FROM 'true'
  OR summary->>'status' IS DISTINCT FROM 'reconciliation_ready' THEN RETURN false;END IF;
 IF summary->>'selected_source'='time' THEN
  IF summary->>'operational_complete' IS DISTINCT FROM 'true'
   OR summary->>'coverage' IS DISTINCT FROM 'operational_complete' THEN RETURN false;END IF;
 ELSIF summary->>'selected_source'='manual' THEN
  IF summary->>'coverage' IS DISTINCT FROM 'approved_manual_total' THEN RETURN false;END IF;
 ELSE RETURN false;END IF;
 FOR source IN SELECT value FROM jsonb_array_elements(coalesce(p_manifest->'optional_sources'->'time'->'items','[]'))
  WHERE value->>'employment_id'=employment LOOP
  IF coalesce((source->>'late_minutes')::numeric,0)>0
   OR coalesce((source->>'early_leave_minutes')::numeric,0)>0 THEN RETURN false;END IF;
  FOR ot IN SELECT value FROM jsonb_array_elements(coalesce(source->'overtime','[]')) LOOP
   IF ot->>'decision' IS DISTINCT FROM 'rejected' AND (ot->>'minutes' IS NULL OR (ot->>'minutes')::numeric>0) THEN RETURN false;END IF;
  END LOOP;
 END LOOP;
 RETURN true;
END $f$;
REVOKE ALL ON FUNCTION payroll.daily_optional_financial_profile(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='AND coalesce((p_manifest->''optional''->>''time'')::boolean,false)=false
      AND coalesce((p_manifest->''optional''->>''leave'')::boolean,false)=false';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_optional_profile_boundary';END IF;
 definition:=replace(definition,anchor,'AND payroll.daily_optional_financial_profile(p_manifest,p_employee)');
 anchor:='''time_leave_valuation'',''none''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_optional_valuation_evidence';END IF;
 definition:=replace(definition,anchor,'''time_leave_valuation'',CASE WHEN p_employee->>''pay_basis''=''daily'' THEN ''existing_approved_daily_payable_units'' ELSE ''none'' END');
 anchor:='     RETURN calculated||jsonb_build_object(''statutory_context''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_unqualified_net_boundary';END IF;
 EXECUTE replace(definition,anchor,'     IF qualification->>''ready'' IS DISTINCT FROM ''true'' THEN calculated:=calculated||jsonb_build_object(''net'',NULL,''calculated_net'',NULL);END IF;'||anchor);
 definition:=pg_get_functiondef('payroll.build_review(jsonb)'::regprocedure);
 anchor:=' IF jsonb_array_length(employees)>0 AND NOT EXISTS';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_optional_root_boundary';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF jsonb_array_length(employees)>0 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee
  WHERE employee->>'financially_qualified' IS DISTINCT FROM 'true'
   OR NOT payroll.daily_optional_financial_profile(p_manifest,employee)) THEN
  SELECT coalesce(jsonb_agg(issue),'[]') INTO issues FROM jsonb_array_elements(issues) issue
   WHERE issue->>'code' NOT IN('time_integration_pending','leave_integration_pending');
  result:=result||jsonb_build_object('gross_complete',true,'gross',
   (SELECT sum((employee->>'gross')::numeric)::text FROM jsonb_array_elements(employees) employee));
 END IF;
 IF jsonb_array_length(employees)>0 AND NOT EXISTS$insert$);
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_optional_manifest';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-daily-reconciled-sources-v1'');'||anchor);
END $patch$;
