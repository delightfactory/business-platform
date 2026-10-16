-- Preserve source errors as actionable blockers, including historical candidates.
CREATE FUNCTION payroll.review_issue_list(p_issues jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT coalesce(jsonb_agg(CASE WHEN jsonb_typeof(i)='object'
  AND nullif(i->>'code','') IS NOT NULL AND nullif(i->>'owner','') IS NOT NULL
  THEN i ELSE payroll.issue('source_issue_invalid',NULL,'payroll_sources') END ORDER BY ord),'[]'::jsonb)
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_issues)='array' THEN p_issues ELSE '[null]'::jsonb END)
 WITH ORDINALITY x(i,ord)
$f$;
REVOKE ALL ON FUNCTION payroll.review_issue_list(jsonb) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$
DECLARE definition text;anchor text;
BEGIN
 definition:=pg_get_functiondef('payroll.daily_source_parts(jsonb,jsonb,jsonb,jsonb,numeric,numeric)'::regprocedure);
 anchor:='issues:=issues||p_reconciled->''issues'';';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_issue_merge';END IF;
 EXECUTE replace(definition,anchor,'issues:=issues||(p_reconciled->''issues'');');

 -- A current approved worked fact uses NULL absence for not-applicable. Treat
 -- only that explicit worked outcome as zero absence; never infer a missing day.
 definition:=pg_get_functiondef('payroll.reconcile_employee_sources(jsonb,jsonb)'::regprocedure);
 anchor:='absence:=payroll.capture_quantity(fact->''absence_units'');';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_worked_absence_contract';END IF;
 EXECUTE replace(definition,anchor,anchor||$insert$
   IF fact->>'outcome'='worked' AND absence IS NULL
    AND fact->>'classification_reconciliation_required'='false'
    AND (fact->>'worked_minutes')::numeric>=0
    AND (fact->>'leave_units')::numeric IN(0,0.5) THEN absence:=0;END IF;
$insert$);

 -- Normalize only the in-memory read projection. Keep original candidate and
 -- frozen financial history intact; malformed issues remain blocking.
 definition:=pg_get_functiondef('payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean)'::regprocedure);
 anchor:='SELECT * INTO candidate FROM payroll.candidates WHERE tenant_id=p_tenant AND id=run.candidate_id;';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_candidate_read';END IF;
 EXECUTE replace(definition,anchor,anchor||$insert$
  candidate.output:=jsonb_set(candidate.output,'{issues}',payroll.review_issue_list(candidate.output->'issues'));
  candidate.output:=jsonb_set(candidate.output,'{employees}',coalesce((SELECT jsonb_agg(
   e||jsonb_build_object('issues',payroll.review_issue_list(e->'issues')) ORDER BY ord)
   FROM jsonb_array_elements(candidate.output->'employees') WITH ORDINALITY x(e,ord)),'[]'::jsonb));
$insert$);
 -- A changed source interpretation must force a fresh candidate before approval.
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_worked_day_manifest';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-worked-day-reconciliation-v1'');'||anchor);
END $patch$;
