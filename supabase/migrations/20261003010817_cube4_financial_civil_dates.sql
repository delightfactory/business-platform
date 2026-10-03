-- Extend the existing payment civil-date boundary to correction and advance evidence.
-- Historical source functions, receipt intent and monetary/lock semantics stay intact.
DO $patch$
DECLARE signature text;definition text;old text;replacement text;
BEGIN
 signature:='public.payroll_correction_settlement(uuid,uuid,uuid,integer,uuid,text,numeric,date,text,text,uuid)';
 definition:=pg_get_functiondef(signature::regprocedure);
 old:='OR p_date IS NULL OR p_attempt IS NULL';
 replacement:='OR p_date IS NULL OR NOT isfinite(p_date) OR p_date<DATE ''0001-01-01'' OR p_date>DATE ''9999-12-31'' OR p_attempt IS NULL';
 IF (length(definition)-length(replace(definition,old,'')))/length(old)<>1 THEN
  RAISE EXCEPTION 'unexpected_correction_civil_date_anchor';
 END IF;
 EXECUTE replace(definition,old,replacement);
 signature:='public.payroll_advance_command(uuid,uuid,jsonb,uuid)';
 definition:=pg_get_functiondef(signature::regprocedure);
 old:='OR day>(clock_timestamp() AT TIME ZONE ''Africa/Cairo'')::date';
 replacement:='OR NOT isfinite(day) OR day<DATE ''0001-01-01'' OR day>DATE ''9999-12-31'' OR day>(clock_timestamp() AT TIME ZONE ''Africa/Cairo'')::date';
 IF (length(definition)-length(replace(definition,old,'')))/length(old)<>1 THEN
  RAISE EXCEPTION 'unexpected_advance_civil_date_anchor';
 END IF;
 EXECUTE replace(definition,old,replacement);
END $patch$;
