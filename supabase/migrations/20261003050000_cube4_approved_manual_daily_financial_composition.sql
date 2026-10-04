-- The ordinary worker already validates approved manual quantity, eligible
-- days, dated wage completeness and exact earning money. Reuse that same
-- issued earning/tax/insurance composition for one reviewed legal context.
-- Optional Time/Leave and source-loan profiles retain their existing guards.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:='profile:=p_employee->>''pay_basis''=''monthly'' AND';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_profile_boundary';END IF;
 definition:=replace(definition,anchor,'profile:=p_employee->>''pay_basis'' IN(''monthly'',''daily'') AND');
 anchor:='ELSE CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->''lines'') earning';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_profile_evidence';END IF;
 EXECUTE replace(definition,anchor,'ELSE CASE WHEN p_employee->>''pay_basis''=''daily'' THEN ''eg-daily-approved-units-single-context-v1'' WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(p_employee->''lines'') earning');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_manifest';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-daily-approved-units-v1'');'||anchor);
END $patch$;
