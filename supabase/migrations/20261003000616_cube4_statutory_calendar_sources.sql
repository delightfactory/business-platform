-- Calendar facts for the source-bound financial composition. Neither calendar
-- day counts nor month fragments are legal duration/insurance obligations.
CREATE FUNCTION payroll.employee_statutory_calendar(p_manifest jsonb,p_employee jsonb,p_sources jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE employment jsonb;starts date;ends date;hired date;ended date;month_start date;month_end date;
 scope_from date;scope_through date;fragments jsonb;months jsonb:='[]';years jsonb:='[]';year_number integer;matches integer;
BEGIN
 SELECT count(*),min((e->'employment')::text)::jsonb INTO matches,employment
 FROM jsonb_array_elements(p_manifest->'employees')e WHERE e->'employment'->>'id'=p_employee->>'employment_id';
 IF matches<>1 OR employment->>'employee_id' IS DISTINCT FROM p_employee->>'employee_id' THEN
  RETURN jsonb_build_object('contract','cube4-statutory-calendar-facts-v1','known',false,'reason','employment_source_missing_or_ambiguous',
   'months',NULL,'years',NULL,'legal_duration_days',NULL,'obligation_months',NULL,'financially_qualified',false);
 END IF;
 starts:=(p_employee->>'starts_on')::date;ends:=(p_employee->>'ends_on')::date;
 hired:=(employment->>'start_date')::date;ended:=(employment->>'end_date')::date;
 IF starts IS NULL OR ends IS NULL OR hired IS NULL OR p_manifest->'period'->>'starts_on' IS NULL OR p_manifest->'period'->>'ends_on' IS NULL
  OR NOT isfinite(starts) OR NOT isfinite(ends) OR NOT isfinite(hired)
  OR(ended IS NOT NULL AND(NOT isfinite(ended) OR ended<hired)) OR ends-starts NOT BETWEEN 0 AND 365
  OR starts<>greatest((p_manifest->'period'->>'starts_on')::date,hired)
  OR ends<>least((p_manifest->'period'->>'ends_on')::date,coalesce(ended,(p_manifest->'period'->>'ends_on')::date))
  OR jsonb_typeof(p_sources->'contexts') IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'payroll_statutory_calendar_invalid' USING ERRCODE='22023';
 END IF;
 FOR month_start IN SELECT generate_series(date_trunc('month',starts)::date,date_trunc('month',ends)::date,interval '1 month')::date LOOP
  month_end:=(month_start+interval '1 month'-interval '1 day')::date;
  scope_from:=greatest(starts,month_start);scope_through:=least(ends,month_end);
  SELECT coalesce(jsonb_agg(jsonb_build_object('from',greatest(scope_from,(c->>'from')::date),
   'through',least(scope_through,(c->>'through')::date),'head_id',c->'head_id','version_id',c->'version_id',
   'data',c->'source'->'version'->'data') ORDER BY c->>'from',c->>'version_id'),'[]') INTO fragments
  FROM jsonb_array_elements(p_sources->'contexts')c
  WHERE(c->>'from')::date<=scope_through AND(c->>'through')::date>=scope_from;
  months:=months||jsonb_build_array(jsonb_build_object('month',month_start,'calendar_through',month_end,
   'from',scope_from,'through',scope_through,'calendar_days',scope_through-scope_from+1,
   'full_service_month',hired<=month_start AND(ended IS NULL OR ended>=month_end),
   'service_start_in_month',hired BETWEEN month_start AND month_end,
   'service_end_in_month',ended BETWEEN month_start AND month_end,'contexts',fragments));
 END LOOP;
 FOR year_number IN extract(year FROM starts)::integer..extract(year FROM ends)::integer LOOP
  scope_from:=greatest(starts,make_date(year_number,1,1));scope_through:=least(ends,make_date(year_number,12,31));
  years:=years||jsonb_build_array(jsonb_build_object('year',year_number,'from',scope_from,'through',scope_through,
   'calendar_days',scope_through-scope_from+1,'legal_duration_days',NULL));
 END LOOP;
 RETURN jsonb_build_object('contract','cube4-statutory-calendar-facts-v1','known',true,
  'employment_id',p_employee->'employment_id','employee_id',p_employee->'employee_id','employment',employment,
  'months',months,'years',years,'legal_duration_days',NULL,'obligation_months',NULL,
  'financially_qualified',false);
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow THEN
 RAISE EXCEPTION 'payroll_statutory_calendar_invalid' USING ERRCODE='22023';
END $f$;
REVOKE ALL ON FUNCTION payroll.employee_statutory_calendar(jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION payroll.employee_statutory_sources(jsonb,jsonb) RENAME TO employee_statutory_sources_before_calendar;
CREATE FUNCTION payroll.employee_statutory_sources(p_manifest jsonb,p_employee jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE sources jsonb;BEGIN
 sources:=payroll.employee_statutory_sources_before_calendar(p_manifest,p_employee);
 RETURN sources||jsonb_build_object('calendar',payroll.employee_statutory_calendar(p_manifest,p_employee,sources));
END $f$;
REVOKE ALL ON FUNCTION payroll.employee_statutory_sources(jsonb,jsonb),payroll.employee_statutory_sources_before_calendar(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;anchor text:='''-prior-finals-v1-cumulative-balances-v1-current-earnings-v1''';BEGIN
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 IF(length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_statutory_calendar_engine';END IF;
 EXECUTE replace(definition,anchor,'''-prior-finals-v1-cumulative-balances-v1-current-earnings-v1-calendar-facts-v1''');
END $f$;
