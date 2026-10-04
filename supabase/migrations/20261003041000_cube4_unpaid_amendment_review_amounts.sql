-- Let the existing authorized correction review show the actual calculated
-- replacement money before approval/finalization. No amount is submitted by
-- the browser and no new financial calculation or authority path is added.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('public.payroll_correction_workspace(uuid,uuid,uuid,uuid,text,uuid,uuid)'::regprocedure);
 anchor:='''candidate_id'',r.candidate_id,''approval''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_amendment_money_projection';END IF;
 EXECUTE replace(definition,anchor,$insert$'candidate_id',r.candidate_id,
 'period',(SELECT jsonb_build_object('starts_on',starts_on,'ends_on',ends_on) FROM payroll.periods WHERE tenant_id=r.tenant_id AND id=r.period_id),
 'summary',CASE WHEN r.status IN('review','approved') THEN v.output-'employees'-'issues' END,
 'review_employees',CASE WHEN r.status IN('review','approved') THEN
  (SELECT coalesce(jsonb_agg(payroll.review_employee_detail(employee) ORDER BY employee->>'employment_id'),'[]')
   FROM(SELECT employee FROM jsonb_array_elements(v.output->'employees') employee
    WHERE p_after IS NULL OR (employee->>'employment_id')::uuid>p_after
    ORDER BY (employee->>'employment_id')::uuid LIMIT 30) bounded) ELSE '[]'::jsonb END,
 'review_next_after',CASE WHEN r.status IN('review','approved') AND
  (SELECT count(*) FROM jsonb_array_elements(v.output->'employees') employee WHERE p_after IS NULL OR(employee->>'employment_id')::uuid>p_after)>30 THEN
  (SELECT employee->>'employment_id' FROM jsonb_array_elements(v.output->'employees') employee
   WHERE p_after IS NULL OR(employee->>'employment_id')::uuid>p_after ORDER BY(employee->>'employment_id')::uuid OFFSET 29 LIMIT 1) END,
 'approval'$insert$);
END $patch$;
