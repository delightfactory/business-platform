-- Preserve operational date distribution without assigning legal earning dates,
-- paid units, a rounded tax-year amount or a payment-date attribution.
CREATE FUNCTION payroll.earning_date_partitions(p_employee jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE sources jsonb;line jsonb;part jsonb;entry record;scope record;parts jsonb;fraction jsonb;
 starts date;ends date;d date;known boolean;reason text;rows jsonb:='[]';segments jsonb;indices jsonb;selected jsonb;
BEGIN
 sources:=payroll.current_earning_sources(p_employee);
 starts:=(p_employee->>'starts_on')::date;ends:=(p_employee->>'ends_on')::date;
 IF starts IS NULL OR ends IS NULL OR NOT isfinite(starts) OR NOT isfinite(ends) OR ends-starts NOT BETWEEN 0 AND 365 THEN
  RAISE EXCEPTION 'payroll_earning_dates_invalid' USING ERRCODE='22023';END IF;
 FOR entry IN SELECT value,ordinality FROM jsonb_array_elements(sources->'lines') WITH ORDINALITY LOOP
  line:=entry.value;parts:=line->'source_parts';segments:='[]';reason:=NULL;
  known:=line->>'attribution'='saved_salary_distribution';
  IF NOT known THEN reason:=CASE WHEN line->>'attribution'='approved_period_amount' THEN 'period_amount_needs_earning_scope' ELSE 'daily_payable_quantity_is_not_dated_work' END;
  ELSIF jsonb_array_length(parts)=0 THEN known:=false;reason:='dated_parts_missing';
  ELSE
   FOR part IN SELECT value FROM jsonb_array_elements(parts) LOOP
    IF part->>'date' IS NULL OR part->>'_numerator' IS NULL OR part->>'_denominator' IS NULL THEN
     known:=false;reason:='dated_parts_missing';EXIT;
    END IF;
    IF part->>'date' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
     OR part->>'_numerator' !~ '^[0-9]+(\.0+)?$' OR part->>'_denominator' !~ '^[0-9]+(\.0+)?$'
     OR(part->>'_denominator')::numeric<=0 THEN RAISE EXCEPTION 'payroll_earning_dates_invalid' USING ERRCODE='22023';END IF;
    d:=(part->>'date')::date;
    IF d<starts OR d>ends OR to_char(d,'YYYY-MM-DD')<>part->>'date' THEN RAISE EXCEPTION 'payroll_earning_dates_invalid' USING ERRCODE='22023';END IF;
   END LOOP;
  END IF;
  IF known THEN
   fraction:=payroll.parts_fraction(parts);
   IF payroll.round_fraction(fraction)<>(line->>'amount')::numeric THEN RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
   FOR scope IN SELECT date_trunc('month',(p->>'date')::date)::date AS month FROM jsonb_array_elements(parts)p GROUP BY 1 ORDER BY 1 LOOP
    SELECT jsonb_agg(p ORDER BY ordinality),jsonb_agg(ordinality-1 ORDER BY ordinality) INTO selected,indices
    FROM jsonb_array_elements(parts) WITH ORDINALITY AS items(p,ordinality) WHERE date_trunc('month',(p->>'date')::date)::date=scope.month;
    segments:=segments||jsonb_build_array(jsonb_build_object('month',scope.month,'year',extract(year FROM scope.month)::integer,
     'fraction',payroll.parts_fraction(selected),'source_part_indexes',indices,'rounded_amount',NULL));
   END LOOP;
  ELSE fraction:=NULL;END IF;
  rows:=rows||jsonb_build_array(jsonb_build_object('source_line_index',entry.ordinality-1,'component',line->'component','amount',line->'amount',
   'operational_date_distribution_known',known,'reason',reason,'fraction',fraction,'months',CASE WHEN known THEN segments END,
   'legal_earning_attribution_known',false));
 END LOOP;
 RETURN jsonb_build_object('contract','cube4-operational-earning-partitions-v1','lines',rows,'financially_qualified',false);
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
 RAISE EXCEPTION 'payroll_earning_dates_invalid' USING ERRCODE='22023';
END $f$;
REVOKE ALL ON FUNCTION payroll.earning_date_partitions(jsonb) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION payroll.employee_statutory_sources(jsonb,jsonb) RENAME TO employee_statutory_sources_before_earning_partitions;
CREATE FUNCTION payroll.employee_statutory_sources(p_manifest jsonb,p_employee jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT payroll.employee_statutory_sources_before_earning_partitions(p_manifest,p_employee)
  ||jsonb_build_object('earning_partitions',payroll.earning_date_partitions(p_employee))
$f$;
REVOKE ALL ON FUNCTION payroll.employee_statutory_sources(jsonb,jsonb),payroll.employee_statutory_sources_before_earning_partitions(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;anchor text:='''-prior-finals-v1-cumulative-balances-v1-current-earnings-v1-calendar-facts-v1''';BEGIN
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 IF(length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_earning_partitions_engine';END IF;
 EXECUTE replace(definition,anchor,'''-prior-finals-v1-cumulative-balances-v1-current-earnings-v1-calendar-facts-v1-earning-partitions-v1''');
END $f$;
