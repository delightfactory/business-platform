-- Cube4 Stage2: operationally complete DAILY Time gross only.
-- This is deliberately not source consumption, statutory qualification, legal
-- finalization, public-net exposure, or a Cube3 repair.

CREATE FUNCTION payroll.complete_daily_time_coverage(
  p_manifest jsonb,
  p_employment jsonb,
  p_reconciled jsonb,
  p_parts jsonb
) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE
  hid uuid:=(p_employment->>'id')::uuid;
  first_day date:=greatest((p_manifest->'period'->>'starts_on')::date,(p_employment->>'start_date')::date);
  last_day date:=least((p_manifest->'period'->>'ends_on')::date,coalesce((p_employment->>'end_date')::date,(p_manifest->'period'->>'ends_on')::date));
  coverage jsonb:=p_manifest->'optional_sources'->'time'->'coverage';
  coverage_rows jsonb:=coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(coalesce(coverage->'items','[]'::jsonb))x WHERE (x->>'employment_id')::uuid=hid),'[]'::jsonb);
  source_rows jsonb:=coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(coalesce(p_manifest->'optional_sources'->'time'->'items','[]'::jsonb))x WHERE (x->>'employment_id')::uuid=hid),'[]'::jsonb);
  reconciled_days jsonb:=coalesce(p_reconciled->'days','[]'::jsonb);
  d date;row jsonb;source jsonb;
  expected_days integer:=last_day-first_day+1;required_parts integer:=0;row_count integer;source_count integer;part_count integer;
  expected boolean;complete boolean:=true;
BEGIN
  IF p_manifest->'optional'->>'time' IS DISTINCT FROM 'true'
     OR coverage->>'contract' IS DISTINCT FROM 'cube4-time-coverage-v1'
     OR coverage->>'enabled' IS DISTINCT FROM 'true'
     OR p_reconciled->'issues' IS DISTINCT FROM '[]'::jsonb THEN
    RETURN jsonb_build_object('complete',false,'issues',jsonb_build_array(payroll.issue('source_time_coverage_unqualified',hid,'payroll_time')));
  END IF;

  -- The capture must be an exhaustive inclusive civil-date grid, not merely
  -- a list of dates on which a source happened to return a fact.
  IF expected_days<1 OR jsonb_array_length(coverage_rows)<>expected_days
     OR EXISTS(SELECT 1 FROM jsonb_array_elements(coverage_rows)x
               WHERE (x->>'employment_id')::uuid IS DISTINCT FROM hid
                  OR (x->>'date')::date NOT BETWEEN first_day AND last_day)
     OR EXISTS(SELECT 1 FROM jsonb_array_elements(coverage_rows)x
               GROUP BY x->>'date' HAVING count(*)<>1) THEN
    complete:=false;
  END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(source_rows)x
            WHERE (x->>'employment_id')::uuid IS DISTINCT FROM hid
               OR (x->>'date')::date NOT BETWEEN first_day AND last_day) THEN
    complete:=false;
  END IF;
  SELECT count(*) INTO required_parts FROM jsonb_array_elements(coverage_rows)x WHERE (x->>'expected')::boolean IS TRUE;

  FOR d IN SELECT first_day+n FROM generate_series(0,expected_days-1)n LOOP
    SELECT count(*) INTO row_count FROM jsonb_array_elements(coverage_rows)x WHERE (x->>'date')::date=d;
    SELECT x INTO row FROM jsonb_array_elements(coverage_rows)x WHERE (x->>'date')::date=d LIMIT 1;
    IF row_count<>1 THEN complete:=false;CONTINUE;END IF;
    expected:=(row->>'expected')::boolean;
    IF expected IS NULL OR row->>'employee_id' IS DISTINCT FROM p_employment->>'employee_id'
       OR jsonb_typeof(row->'provenance'->'instances') IS DISTINCT FROM 'array' THEN
      complete:=false;CONTINUE;
    END IF;
    IF expected IS DISTINCT FROM true THEN
      -- A civil non-workday is permitted only when it has no materialized
      -- instance and no captured fact that contradicts the schedule.
      IF row->>'state' IS DISTINCT FROM 'scheduled_nonworkday'
         OR coalesce(jsonb_array_length(row->'provenance'->'instances'),0)<>0
         OR EXISTS(SELECT 1 FROM jsonb_array_elements(source_rows)x WHERE (x->>'employment_id')::uuid=hid AND (x->>'date')::date=d)
      THEN complete:=false;END IF;
      CONTINUE;
    END IF;

    IF row->>'state' IS DISTINCT FROM 'approved_fact_current' OR row->>'elapsed' IS DISTINCT FROM 'true' THEN complete:=false;END IF;
    SELECT count(*) INTO source_count FROM jsonb_array_elements(source_rows)x WHERE (x->>'employment_id')::uuid=hid AND (x->>'date')::date=d;
    SELECT x INTO source FROM jsonb_array_elements(source_rows)x WHERE (x->>'employment_id')::uuid=hid AND (x->>'date')::date=d LIMIT 1;
    IF source_count<>1 THEN complete:=false;CONTINUE;END IF;
    IF source->>'employee_id' IS DISTINCT FROM p_employment->>'employee_id'
       OR source->>'work_instance_id' IS NULL OR source->>'fact_id' IS NULL OR source->>'fact_version' IS NULL
       OR source->>'interpretation_id' IS NULL OR source->>'interpretation_version' IS NULL
       OR row->'provenance'->'latest_fact'->>'id' IS NULL OR row->'provenance'->'latest_fact'->>'version' IS NULL
       OR row->'provenance'->'latest_fact'->>'interpretation_id' IS NULL
       OR row->'provenance'->'latest_interpretation'->>'id' IS NULL OR row->'provenance'->'latest_interpretation'->>'version' IS NULL
       OR coalesce(jsonb_array_length(row->'provenance'->'instances'),0)<>1
       OR (SELECT count(*) FROM jsonb_array_elements(row->'provenance'->'instances')i WHERE i->>'id'=source->>'work_instance_id')<>1
       OR row->'provenance'->'latest_fact'->>'id' IS DISTINCT FROM source->>'fact_id'
       OR row->'provenance'->'latest_fact'->>'version' IS DISTINCT FROM source->>'fact_version'
       OR row->'provenance'->'latest_fact'->>'interpretation_id' IS DISTINCT FROM source->>'interpretation_id'
       OR row->'provenance'->'latest_interpretation'->>'id' IS DISTINCT FROM source->>'interpretation_id'
       OR row->'provenance'->'latest_interpretation'->>'version' IS DISTINCT FROM source->>'interpretation_version'
    THEN complete:=false;END IF;
    SELECT count(*) INTO row_count FROM jsonb_array_elements(reconciled_days)x WHERE (x->>'date')::date=d;
    IF row_count<>1 OR (SELECT x->>'time_fact_count' FROM jsonb_array_elements(reconciled_days)x WHERE (x->>'date')::date=d) <> '1'
       OR (SELECT x->>'work_units' FROM jsonb_array_elements(reconciled_days)x WHERE (x->>'date')::date=d) IS NULL THEN complete:=false;END IF;
  END LOOP;

  -- Every expected date gets exactly one dated rate part. Unknown, duplicate,
  -- or missing mappings fail the whole employee; no zero/partial default.
  part_count:=jsonb_array_length(coalesce(p_parts,'[]'::jsonb));
  IF part_count<>required_parts
     OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_parts,'[]'::jsonb))x
               WHERE (x->>'date')::date NOT BETWEEN first_day AND last_day)
     OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_parts,'[]'::jsonb))x
               GROUP BY x->>'date' HAVING count(*)<>1)
      OR EXISTS(SELECT 1 FROM generate_series(0,expected_days-1)n
                WHERE (first_day+n)::date IN(SELECT (x->>'date')::date FROM jsonb_array_elements(coalesce(coverage_rows,'[]'::jsonb))x WHERE (x->>'expected')::boolean IS TRUE)
                  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_parts,'[]'::jsonb))x WHERE (x->>'date')::date=(first_day+n)::date)) THEN
    complete:=false;
  END IF;

  RETURN jsonb_build_object('complete',complete,'issues',CASE WHEN complete THEN '[]'::jsonb ELSE jsonb_build_array(payroll.issue('source_time_coverage_unqualified',hid,'payroll_time')) END);
END $f$;

CREATE FUNCTION payroll.lock_calculate_current_employments(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE period payroll.periods%ROWTYPE; n bigint;
BEGIN
  SELECT * INTO period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  SELECT count(*) INTO n FROM people.employments h
   WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND h.start_date<=period.ends_on
     AND (h.end_date IS NULL OR h.end_date>=period.starts_on);
  IF n>20000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
  -- lock_run_scope already acquired the tenant/source-scope advisory locks and
  -- stable People discovery set. WorkInstance BEFORE INSERT policy guard
  -- explicitly locks Employment; its immediate FK also binds the parent.
  -- Parent protection fences new instances, overrides and Leave requests.
  -- Existing punch/interpretation writers may lock only WorkInstance: lock
  -- those rows after Employment so their source identities cannot race.
  PERFORM 1 FROM people.employments h
   WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND h.start_date<=period.ends_on
     AND (h.end_date IS NULL OR h.end_date>=period.starts_on)
   ORDER BY h.id FOR UPDATE;
  PERFORM 1 FROM time.work_instances i
   WHERE i.tenant_id=p_tenant AND i.employment_id IN(
     SELECT h.id FROM people.employments h
      WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible
        AND h.start_date<=period.ends_on AND (h.end_date IS NULL OR h.end_date>=period.starts_on))
     AND i.operational_date BETWEEN period.starts_on AND period.ends_on
   ORDER BY i.id FOR UPDATE;
END $f$;

REVOKE ALL ON FUNCTION payroll.complete_daily_time_coverage(jsonb,jsonb,jsonb,jsonb),payroll.lock_calculate_current_employments(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$
DECLARE definition text;old text;new text;manifest_definition text;command_definition text;
BEGIN
  -- The current base is deliberately the only builder patched. Later wrappers
  -- (advances/statutory/attention) remain composition-only.
  definition:=pg_get_functiondef('payroll.build_review_before_advances(jsonb)'::regprocedure);
  IF position('cube4-review-v4-daily-sources' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_complete_daily_builder_engine';END IF;
  old:='source_context jsonb;daily_context jsonb;heads record;';
  IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_complete_daily_builder_declaration';END IF;
  definition:=replace(definition,old,'source_context jsonb;daily_context jsonb;coverage_check jsonb;heads record;');
  old:=$anchor$complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('source_time_coverage_unqualified',hid,'payroll_time'));$anchor$;
  IF (length(definition)-length(replace(definition,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'unexpected_complete_daily_guard';END IF;
  new:=$replacement$coverage_check:=payroll.complete_daily_time_coverage(employee_manifest,h,source_context,base_parts);
     IF coverage_check->>'complete' IS DISTINCT FROM 'true' THEN
       complete:=false;employee_issues:=employee_issues||(coverage_check->'issues');
     ELSE
       source_context:=jsonb_set(source_context,'{summary}',source_context->'summary'||jsonb_build_object('operational_complete',true,'coverage','operational_complete','status','reconciliation_ready'));
     END IF;$replacement$;
  definition:=replace(definition,old,new);
  definition:=replace(definition,'-- No authoritative expected-workday calendar exists in this stage. Missing civil dates are not assumed unpaid or worked.',
    '-- Require canonical expected-day coverage; missing dates never imply absence or work.');
  definition:=replace(definition,'cube4-review-v4-daily-sources','cube4-review-v5-complete-daily-time');
  EXECUTE definition;

  manifest_definition:=pg_get_functiondef('payroll.run_manifest_before_corrections(uuid,uuid,uuid)'::regprocedure);
  IF position('cube4-review-v4-daily-sources' IN manifest_definition)=0 THEN RAISE EXCEPTION 'unexpected_complete_daily_manifest_engine';END IF;
  EXECUTE replace(manifest_definition,'cube4-review-v4-daily-sources','cube4-review-v5-complete-daily-time');

  command_definition:=pg_get_functiondef('public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
  old:='manifest:=payroll.run_manifest(p_tenant,p_employer,p_period);';
  IF position(old IN command_definition)=0 THEN RAISE EXCEPTION 'unexpected_complete_daily_command_scope';END IF;
  -- Receipt replay returns before source locks. Fresh CALCULATE alone needs
  -- protected capture, followed by a current-authority recheck after waiting.
  new:='IF platform_private.tenant_capability_is_enabled(p_tenant,''hr.attendance'',clock_timestamp()) OR platform_private.tenant_capability_is_enabled(p_tenant,''hr.leave'',clock_timestamp()) THEN
    PERFORM payroll.lock_calculate_current_employments(p_tenant,p_employer,p_period);
  END IF;
  a:=payroll.authorized(p_tenant,''payroll.prepare'',true);
  '||old;
  EXECUTE replace(command_definition,old,new);
END $patch$;

-- The engine suffix is part of the immutable candidate identity. A current
-- manifest therefore stales old candidates; no candidate/source is rewritten.
