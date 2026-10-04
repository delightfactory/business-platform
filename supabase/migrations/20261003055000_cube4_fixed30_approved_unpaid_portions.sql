-- Frozen spec monthly unpaid portions use the selected fixed30 policy.
-- Full30000 cycle minus one unpaid salary/30 day is29000.
CREATE OR REPLACE FUNCTION payroll.monthly_source_parts(p_manifest jsonb,p_employment jsonb,p_reconciled jsonb,p_parts jsonb,p_mode text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE hid uuid:=(p_employment->>'id')::uuid;coverage jsonb;selected jsonb;part jsonb;day jsonb;
 result jsonb:='[]';issues jsonb:='[]';unpaid numeric;paid numeric;summary jsonb;original_n numeric;original_d numeric;new_n numeric;new_d numeric;
BEGIN
 summary:=p_reconciled->'summary'||jsonb_build_object('selected_source','monthly_approved_sources','coverage','approved_leave_sources');
 IF p_reconciled->'issues' IS DISTINCT FROM '[]'::jsonb THEN
  RETURN jsonb_build_object('parts',p_parts,'summary',summary,'issues',p_reconciled->'issues');END IF;
 IF p_manifest->'optional'->>'time'='true' THEN
  SELECT coalesce(jsonb_agg(candidate.value),'[]') INTO selected FROM jsonb_array_elements(p_parts) candidate(value)
   WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(p_manifest->'optional_sources'->'time'->'coverage'->'items') expected
    WHERE expected->>'employment_id'=hid::text AND expected->>'date'=candidate.value->>'date' AND expected->>'expected'='true');
  coverage:=payroll.complete_daily_time_coverage(p_manifest,p_employment,p_reconciled,selected);
  IF coverage->>'complete' IS DISTINCT FROM 'true' THEN
   RETURN jsonb_build_object('parts',p_parts,'summary',summary,'issues',coverage->'issues');END IF;
  summary:=summary||jsonb_build_object('operational_complete',true,'coverage','operational_complete');
 END IF;
 FOR part IN SELECT value FROM jsonb_array_elements(p_parts) LOOP
  SELECT value INTO day FROM jsonb_array_elements(p_reconciled->'days') WHERE value->>'date'=part->>'date';
  unpaid:=coalesce((day->>'absence_units')::numeric,0)+coalesce((day->>'unpaid_leave_units')::numeric,0);
  IF unpaid NOT BETWEEN 0 AND 1 OR unpaid*100<>trunc(unpaid*100) THEN
   issues:=issues||jsonb_build_array(payroll.issue('source_monthly_units_invalid',hid,'payroll_time'));result:=result||jsonb_build_array(part);CONTINUE;
  END IF;
  IF p_mode='fixed_30_day' THEN
   -- Saved full-cycle/join/end salary distribution is unchanged. Approved
   -- unpaid portions subtract the effective salary/30, independently of the
   -- join/end cap. Preserve the dated counterportion as an exact rational.
   original_n:=(part->>'_numerator')::numeric;original_d:=(part->>'_denominator')::numeric;
   new_n:=original_n*300000-((part->>'rate')::numeric*100)*(unpaid*100)*original_d;
   new_d:=original_d*300000;
   result:=result||jsonb_build_array(part||jsonb_build_object('approved_paid_fraction',1-unpaid,'approved_unpaid_fraction',unpaid,
    'unpaid_proration','fixed_30_day','_monthly_original_numerator',original_n::text,'_monthly_original_denominator',original_d::text,
    '_numerator',new_n::text,'_denominator',new_d::text,'raw',(new_n::numeric(1000,40)/new_d)::text));
   CONTINUE;
  END IF;
  paid:=1-unpaid;
  result:=result||jsonb_build_array(part||jsonb_build_object('approved_paid_fraction',paid,'approved_unpaid_fraction',unpaid,
   '_numerator',((part->>'_numerator')::numeric*paid*100)::text,
   '_denominator',((part->>'_denominator')::numeric*100)::text,'raw',((part->>'raw')::numeric*paid)::text));
 END LOOP;
 IF p_mode='fixed_30_day' AND payroll.round_fraction(payroll.parts_fraction(result))<0 THEN
  -- Do not invent a floor or a negative earning. The source needs a reviewed
  -- disposition if approved unpaid portions exceed this period's base.
  issues:=issues||jsonb_build_array(payroll.issue('monthly_unpaid_exceeds_base',hid,'payroll_config'));result:=p_parts;
 END IF;
 RETURN jsonb_build_object('parts',result,'summary',summary||jsonb_build_object('status',CASE WHEN issues='[]'::jsonb THEN 'reconciliation_ready' ELSE 'needs_source_review' END),'issues',issues);
END $f$;
REVOKE ALL ON FUNCTION payroll.monthly_source_parts(jsonb,jsonb,jsonb,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;

-- Signed daily counterportions are accepted only when they reconstruct this
-- approved fixed30 contract, or an existing percentage of that exact base.
CREATE FUNCTION payroll.approved_fixed30_counterportion(p_employee jsonb,p_line jsonb,p_part jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE base_part jsonb;original_n numeric;original_d numeric;rate numeric;unpaid numeric;n numeric;d numeric;value numeric;
BEGIN
 IF p_employee->>'pay_basis' IS DISTINCT FROM 'monthly'
  OR p_employee->'source_summary'->>'selected_source' IS DISTINCT FROM 'monthly_approved_sources' THEN RETURN false;END IF;
 SELECT part INTO base_part FROM jsonb_array_elements(p_employee->'lines') line
  CROSS JOIN LATERAL jsonb_array_elements(line->'details') envelope
  CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(envelope->'detail')='array' THEN envelope->'detail' ELSE jsonb_build_array(envelope) END) part
  WHERE line->>'component'='base' AND part->>'date'=p_part->>'date';
 IF base_part->>'unpaid_proration' IS DISTINCT FROM 'fixed_30_day'
  OR coalesce(base_part->>'_monthly_original_numerator','')!~'^[0-9]+(\.0+)?$'
  OR coalesce(base_part->>'_monthly_original_denominator','')!~'^[0-9]+(\.0+)?$' THEN RETURN false;END IF;
 original_n:=(base_part->>'_monthly_original_numerator')::numeric;original_d:=(base_part->>'_monthly_original_denominator')::numeric;
 rate:=(base_part->>'rate')::numeric;unpaid:=(base_part->>'approved_unpaid_fraction')::numeric;
 IF original_d<=0 OR rate<0 OR rate<>round(rate,2) OR unpaid NOT BETWEEN 0 AND 1 OR unpaid*100<>trunc(unpaid*100)
  OR (base_part->>'approved_paid_fraction')::numeric<>1-unpaid
  OR original_n*(base_part->>'denominator')::numeric<>rate*original_d THEN RETURN false;END IF;
 n:=original_n*300000-(rate*100)*(unpaid*100)*original_d;d:=original_d*300000;
 IF (base_part->>'_numerator')::numeric<>n OR (base_part->>'_denominator')::numeric<>d THEN RETURN false;END IF;
 IF p_line->>'component'='base' THEN
  RETURN (p_part->>'_numerator')::numeric=n AND(p_part->>'_denominator')::numeric=d;
 END IF;
 IF p_part->>'calculation' IS DISTINCT FROM 'percentage' OR p_part->>'component_version' IS NULL THEN RETURN false;END IF;
 value:=(p_part->>'assignment_value')::numeric;
 RETURN value>=0 AND value=round(value,2) AND (p_part->>'_denominator')::numeric>0
  AND (p_part->>'_numerator')::numeric*d*100=n*(p_part->>'_denominator')::numeric*value;
EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RETURN false;
END $f$;
REVOKE ALL ON FUNCTION payroll.approved_fixed30_counterportion(jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.reviewed_earning_segment(jsonb,date,date)'::regprocedure);
 anchor:='OR coalesce(part->>''_numerator'','''')!~''^[0-9]+(\.0+)?$''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_fixed30_segment_fraction';END IF;
 EXECUTE replace(definition,anchor,'OR (coalesce(part->>''_numerator'','''')!~''^[0-9]+(\.0+)?$'' AND NOT (coalesce(part->>''_numerator'','''')~''^-[0-9]+(\.0+)?$'' AND payroll.approved_fixed30_counterportion(p_employee,line,part) IS TRUE))');
 definition:=pg_get_functiondef('payroll.earning_date_partitions(jsonb)'::regprocedure);
 anchor:='OR part->>''_numerator'' !~ ''^[0-9]+(\.0+)?$''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_fixed30_partition_fraction';END IF;
 EXECUTE replace(definition,anchor,'OR (part->>''_numerator'' !~ ''^[0-9]+(\.0+)?$'' AND NOT (coalesce(part->>''_numerator'','''')~''^-[0-9]+(\.0+)?$'' AND payroll.approved_fixed30_counterportion(p_employee,line,part) IS TRUE))');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_fixed30_unpaid_manifest';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-approved-fixed30-unpaid-v1'');'||anchor);
END $patch$;
