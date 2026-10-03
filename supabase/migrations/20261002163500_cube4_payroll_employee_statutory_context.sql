-- Reviewed employee facts, not a legal rule pack or a statutory calculation.
ALTER TABLE payroll.input_heads DROP CONSTRAINT input_heads_kind_check;
ALTER TABLE payroll.input_heads ADD CONSTRAINT input_heads_kind_check
 CHECK(kind IN('component','recurring','manual_units','adjustment','opening_ytd','policy','statutory_context'));
CREATE UNIQUE INDEX payroll_employee_statutory_context_once
 ON payroll.input_heads(tenant_id,employer_id,employment_id) WHERE kind='statutory_context';

CREATE FUNCTION payroll.validate_employee_statutory_context(p_data jsonb) RETURNS void
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $function$
DECLARE date_key text; date_text text; parsed date; wage numeric;
BEGIN
 IF jsonb_typeof(p_data) IS DISTINCT FROM 'object'
  OR p_data-ARRAY['tax_treatment_code','insurance_status','insurance_category','insured_wage','insurance_from','insurance_until','reference','reason']<>'{}'::jsonb
  OR jsonb_typeof(p_data->'tax_treatment_code') IS DISTINCT FROM 'string'
  OR COALESCE(p_data->>'tax_treatment_code','') !~ '^[0-9]{2}$'
  OR p_data->>'tax_treatment_code'='00'
  OR COALESCE(p_data->>'insurance_status','') NOT IN('insured','not_insured')
  OR jsonb_typeof(p_data->'reference') IS DISTINCT FROM 'string'
  OR jsonb_typeof(p_data->'reason') IS DISTINCT FROM 'string'
  OR length(btrim(COALESCE(p_data->>'reference',''))) NOT BETWEEN 3 AND 160
  OR length(btrim(COALESCE(p_data->>'reason',''))) NOT BETWEEN 3 AND 500 THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
 IF p_data->>'insurance_status'='not_insured' THEN
  IF p_data ?| ARRAY['insurance_category','insured_wage','insurance_from','insurance_until'] THEN
   RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
  END IF;
  RETURN;
 END IF;
 IF jsonb_typeof(p_data->'insurance_category') IS DISTINCT FROM 'string'
  OR length(btrim(COALESCE(p_data->>'insurance_category',''))) NOT BETWEEN 2 AND 160
  OR jsonb_typeof(p_data->'insured_wage') NOT IN('number','string')
  OR COALESCE(p_data->>'insured_wage','') !~ '^[0-9]+(\.[0-9]{1,2})?$' THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
 wage:=(p_data->>'insured_wage')::numeric;
 IF wage<=0 OR wage>999999999999.99 OR NOT(p_data ? 'insurance_from') THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
 FOREACH date_key IN ARRAY ARRAY['insurance_from','insurance_until'] LOOP
  IF p_data ? date_key THEN
   date_text:=p_data->>date_key;
   IF jsonb_typeof(p_data->date_key) IS DISTINCT FROM 'string'
    OR COALESCE(date_text,'') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
   END IF;
   BEGIN parsed:=date_text::date;
   EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN
    RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
   END;
   IF NOT isfinite(parsed) OR parsed<DATE '1900-01-01' OR parsed>DATE '2200-12-31'
    OR to_char(parsed,'YYYY-MM-DD')<>date_text THEN
    RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
   END IF;
  END IF;
 END LOOP;
 IF p_data ? 'insurance_until' AND(p_data->>'insurance_until')::date<(p_data->>'insurance_from')::date THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
END $function$;
REVOKE ALL ON FUNCTION payroll.validate_employee_statutory_context(jsonb) FROM PUBLIC,anon,authenticated,service_role;

DO $migration$
DECLARE definition text; anchor text; function_id regprocedure;
BEGIN
 function_id:='payroll.validate_input(text,jsonb)'::regprocedure;
 SELECT pg_get_functiondef(function_id) INTO definition;
 anchor:='DECLARE keys text[]; val numeric; BEGIN';
 IF strpos(definition,anchor)=0 OR strpos(definition,'validate_employee_statutory_context')<>0 THEN
  RAISE EXCEPTION 'unexpected_employee_statutory_validator';
 END IF;
 EXECUTE replace(definition,anchor,anchor||$patch$
 IF p_kind='statutory_context' THEN
  PERFORM payroll.validate_employee_statutory_context(p_data); RETURN;
 END IF;$patch$);

 function_id:='public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)'::regprocedure;
 SELECT pg_get_functiondef(function_id) INTO definition;
 FOREACH anchor IN ARRAY ARRAY[
  'p_kind NOT IN(''component'',''policy'',''recurring'',''manual_units'',''adjustment'',''opening_ytd'')',
  'p_kind IN(''recurring'',''manual_units'',''adjustment'',''opening_ytd'')',
  'p_kind IN(''component'',''recurring'',''opening_ytd'')'] LOOP
  IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_employee_statutory_command'; END IF;
  definition:=replace(definition,anchor,left(anchor,length(anchor)-1)||',''statutory_context'')');
 END LOOP;
 anchor:='p_kind<>''component'' AND current.effective_until IS NOT NULL';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_employee_statutory_expiry_guard'; END IF;
 definition:=replace(definition,anchor,'p_kind NOT IN(''component'',''statutory_context'') AND current.effective_until IS NOT NULL');
 anchor:=' PERFORM payroll.validate_input(p_kind,p_data);';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_employee_statutory_command_validation'; END IF;
 definition:=replace(definition,anchor,$patch$
 IF p_kind='statutory_context' AND(NOT isfinite(p_from) OR(p_until IS NOT NULL AND NOT isfinite(p_until))) THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
$patch$||anchor);
 EXECUTE definition;

 function_id:='payroll.stale_reasons_before_advances(jsonb,jsonb)'::regprocedure;
 SELECT pg_get_functiondef(function_id) INTO definition;
 anchor:='ARRAY[''policy'',''component'',''recurring'',''manual_units'',''adjustment'',''opening_ytd'']';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_employee_statutory_stale_chain'; END IF;
 EXECUTE replace(definition,anchor,'ARRAY[''policy'',''component'',''recurring'',''manual_units'',''adjustment'',''opening_ytd'',''statutory_context'']');

 function_id:='payroll.validate_correction_input_context(payroll.input_heads,payroll.input_versions,date,date,jsonb)'::regprocedure;
 SELECT pg_get_functiondef(function_id) INTO definition;
 anchor:='BEGIN SELECT * INTO bounds';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_employee_statutory_correction_context'; END IF;
 EXECUTE replace(definition,anchor,$patch$BEGIN
 IF head.kind='statutory_context' AND(NOT isfinite(p_from) OR(p_until IS NOT NULL AND NOT isfinite(p_until))) THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
 SELECT * INTO bounds$patch$);
END $migration$;
