-- Source coverage is an explicit reviewed fact; no statutory day counting is inferred.
CREATE FUNCTION payroll.validate_opening_coverage(p_data jsonb,p_effective_from date DEFAULT NULL)
RETURNS void LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $function$
DECLARE key text; date_text text; parsed date; starts date; ends date; duration numeric;
BEGIN
 IF NOT(p_data ?| ARRAY['coverage_start','coverage_end','tax_duration_days']) THEN RETURN; END IF;
 IF NOT(p_data ?& ARRAY['coverage_start','coverage_end','tax_duration_days'])
  OR COALESCE(p_data->>'year','') !~ '^[0-9]{4}$'
  OR jsonb_typeof(p_data->'tax_duration_days') NOT IN('number','string')
  OR COALESCE(p_data->>'tax_duration_days','') !~ '^[0-9]+(\.[0-9]{1,2})?$' THEN
  RAISE EXCEPTION 'payroll_opening_coverage_invalid' USING ERRCODE='22023';
 END IF;
 duration:=(p_data->>'tax_duration_days')::numeric;
 -- Representation bound for one calendar year, not a legal annualization rule.
 IF duration<0 OR duration>366 THEN RAISE EXCEPTION 'payroll_opening_coverage_invalid' USING ERRCODE='22023'; END IF;
 FOREACH key IN ARRAY ARRAY['coverage_start','coverage_end'] LOOP
  date_text:=p_data->>key;
  IF jsonb_typeof(p_data->key) IS DISTINCT FROM 'string'
   OR COALESCE(date_text,'') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
   RAISE EXCEPTION 'payroll_opening_coverage_invalid' USING ERRCODE='22023';
  END IF;
  BEGIN parsed:=date_text::date;
  EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN
   RAISE EXCEPTION 'payroll_opening_coverage_invalid' USING ERRCODE='22023';
  END;
  IF NOT isfinite(parsed) OR to_char(parsed,'YYYY-MM-DD')<>date_text
   OR extract(year FROM parsed)::integer<>(p_data->>'year')::integer THEN
   RAISE EXCEPTION 'payroll_opening_coverage_invalid' USING ERRCODE='22023';
  END IF;
  IF key='coverage_start' THEN starts:=parsed; ELSE ends:=parsed; END IF;
 END LOOP;
 IF ends<starts OR p_effective_from IS NOT NULL AND(NOT isfinite(p_effective_from) OR ends>=p_effective_from) THEN
  RAISE EXCEPTION 'payroll_opening_coverage_invalid' USING ERRCODE='22023';
 END IF;
END $function$;
REVOKE ALL ON FUNCTION payroll.validate_opening_coverage(jsonb,date) FROM PUBLIC,anon,authenticated,service_role;

DO $migration$
DECLARE definition text; anchor text; function_id regprocedure;
BEGIN
 SELECT pg_get_functiondef('payroll.validate_input(text,jsonb)'::regprocedure) INTO definition;
 anchor:='''taxable_earnings'',''tax_withheld'',''tax_due'',''social_base''';
 IF strpos(definition,anchor)=0 OR strpos(definition,'coverage_start')<>0 THEN RAISE EXCEPTION 'unexpected_opening_coverage_validator'; END IF;
 definition:=replace(definition,anchor,'''taxable_earnings'',''tax_withheld'',''tax_due'',''coverage_start'',''coverage_end'',''tax_duration_days'',''social_base''');
 anchor:=' IF p_kind=''opening_ytd'' THEN';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_opening_coverage_validation_branch'; END IF;
 EXECUTE replace(definition,anchor,anchor||E'\n  PERFORM payroll.validate_opening_coverage(p_data);');

 function_id:='public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)'::regprocedure;
 SELECT pg_get_functiondef(function_id) INTO definition;
 anchor:=' PERFORM payroll.validate_input(p_kind,p_data);';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_opening_coverage_command'; END IF;
 EXECUTE replace(definition,anchor,anchor||E'\n IF p_kind=''opening_ytd'' THEN PERFORM payroll.validate_opening_coverage(p_data,p_from); END IF;');

 function_id:='payroll.validate_correction_input_context(payroll.input_heads,payroll.input_versions,date,date,jsonb)'::regprocedure;
 SELECT pg_get_functiondef(function_id) INTO definition;
 anchor:='SELECT * INTO bounds';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_opening_coverage_correction'; END IF;
 EXECUTE replace(definition,anchor,E'IF head.kind=''opening_ytd'' THEN PERFORM payroll.validate_opening_coverage(p_data,p_from); END IF;\n '||anchor);
END $migration$;
