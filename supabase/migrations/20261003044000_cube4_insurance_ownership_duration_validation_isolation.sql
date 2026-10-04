-- Preserve43000 and its failing regression evidence. Its key-list replacement
-- also expanded the existing duration presence/all-or-none arrays. Insurance
-- ownership has a separate check and must never become mandatory for uninsured
-- dated contexts or cause a duration failure for an otherwise valid source.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.validate_employee_statutory_context(jsonb)'::regprocedure);
 anchor:='IF p_data ?| ARRAY[''calculation_from'',''calculation_until'',''tax_duration_days'',''insurance_obligation_month'',''insurance_owner_period'',''insurance_obligation_reference'']';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_duration_presence';END IF;
 definition:=replace(definition,anchor,'IF p_data ?| ARRAY[''calculation_from'',''calculation_until'',''tax_duration_days'']');
 anchor:='NOT(p_data ?& ARRAY[''calculation_from'',''calculation_until'',''tax_duration_days'',''insurance_obligation_month'',''insurance_owner_period'',''insurance_obligation_reference''])';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_insurance_duration_completeness';END IF;
 EXECUTE replace(definition,anchor,'NOT(p_data ?& ARRAY[''calculation_from'',''calculation_until'',''tax_duration_days''])');
END $patch$;
