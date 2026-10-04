-- Preserve completed statutory context explanations when an approved debt
-- exceeds capacity. The candidate stays unqualified; no partial consumption.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_reviewed_wage_deductions(jsonb,jsonb)'::regprocedure);
 anchor:='RETURN p_employee||jsonb_build_object(''financially_qualified'',false,''net'',NULL,''deduction_plan'',plan,';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_capacity_review_result';END IF;
 definition:=replace(definition,anchor,'RETURN calculated||jsonb_build_object(''financially_qualified'',false,''net'',NULL,''calculated_net'',NULL,''deductions'',p_employee->''deductions'',''deduction_plan'',plan,');
 anchor:='''deduction_unapplied'',plan->''claims'',''issues'',p_employee->''issues''||jsonb_build_array';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_capacity_review_issues';END IF;
 EXECUTE replace(definition,anchor,'''deduction_unapplied'',plan->''claims'',''issues'',calculated->''issues''||jsonb_build_array');
END $patch$;
