-- Close a routed responsibility only from its actual qualified frozen target
-- or its independently recorded external evidence. No financial recalculation.
CREATE FUNCTION payroll.correction_responsibilities_complete(p_tenant uuid,p_proposal uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT EXISTS(SELECT 1 FROM payroll.correction_proposals p WHERE p.tenant_id=p_tenant AND p.id=p_proposal
  AND jsonb_array_length(p.responsibilities)>0
  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.responsibilities) r
   WHERE r->>'basis' NOT IN('external_reviewed','period_component'))
  AND NOT EXISTS(
   SELECT 1 FROM (SELECT (r->>'employment_id')::uuid employment,
    CASE WHEN (r->>'amount')::numeric>0 THEN 'employee_extra_payment' ELSE 'employee_recovery' END direction,
    sum(abs((r->>'amount')::numeric)) amount
    FROM jsonb_array_elements(p.responsibilities) r WHERE r->>'basis'='external_reviewed' GROUP BY 1,2) required
   WHERE required.amount IS DISTINCT FROM (SELECT coalesce(sum(s.amount),0) FROM payroll.correction_settlements s
    WHERE s.tenant_id=p_tenant AND s.proposal_id=p.id AND s.employment_id=required.employment AND s.direction=required.direction))
  AND NOT EXISTS(
   SELECT 1 FROM (SELECT (r->>'employment_id')::uuid employment,(r->>'component_id')::uuid component,
    coalesce((r->>'target_period')::uuid,p.target_period) period,sum((r->>'amount')::numeric) amount
    FROM jsonb_array_elements(p.responsibilities) r WHERE r->>'basis'='period_component' GROUP BY 1,2,3) required
   WHERE NOT EXISTS(
    SELECT 1 FROM payroll.correction_targets target
    JOIN payroll.input_heads h ON h.tenant_id=target.tenant_id AND h.id=target.head_id
    JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.status='approved'
    JOIN payroll.input_frozen_versions frozen ON frozen.tenant_id=v.tenant_id AND frozen.version_id=v.id
    JOIN payroll.final_contexts f ON f.tenant_id=frozen.tenant_id AND f.run_id=frozen.run_id
    JOIN payroll.final_employees e ON e.tenant_id=f.tenant_id AND e.output_id=f.id AND e.employment_id=target.employment_id
    WHERE target.tenant_id=p_tenant AND target.proposal_id=p.id AND target.case_id=p.case_id
     AND target.employment_id=required.employment AND target.amount=required.amount
     AND h.kind='adjustment' AND h.period_id=required.period AND f.period_id=required.period
     AND v.data->>'component_id'=required.component::text AND (v.data->>'amount')::numeric=abs(required.amount)
     AND f.result->>'financially_qualified'='true'
     AND NOT EXISTS(SELECT 1 FROM payroll.output_successions succession WHERE succession.tenant_id=f.tenant_id AND succession.original_output=f.id)
     AND EXISTS(SELECT 1 FROM jsonb_array_elements(f.result->'employees') employee
      CROSS JOIN LATERAL jsonb_array_elements(employee->'lines') line
      CROSS JOIN LATERAL jsonb_array_elements(line->'details') detail
      WHERE employee->>'employment_id'=target.employment_id::text
       AND line->>'component'='adjustment:'||h.id::text AND (line->>'amount')::numeric=abs(required.amount)
       AND line->>'classification'=CASE WHEN required.amount>0 THEN 'earning' ELSE 'deduction' END
       AND detail->>'input_version'=v.id::text AND (detail->>'raw')::numeric=abs(required.amount)))))
 $f$;
REVOKE ALL ON FUNCTION payroll.correction_responsibilities_complete(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.complete_consumed_correction_targets(p_tenant uuid,p_run uuid,p_actor uuid)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE c payroll.correction_cases;details jsonb;
BEGIN
 FOR c IN SELECT cc.* FROM payroll.correction_cases cc WHERE cc.tenant_id=p_tenant AND cc.status='routed'
  AND EXISTS(SELECT 1 FROM payroll.correction_targets target JOIN payroll.input_versions v ON v.tenant_id=target.tenant_id AND v.head_id=target.head_id
   JOIN payroll.input_frozen_versions frozen ON frozen.tenant_id=v.tenant_id AND frozen.version_id=v.id
   WHERE target.tenant_id=cc.tenant_id AND target.case_id=cc.id AND target.proposal_id=cc.proposal_id AND frozen.run_id=p_run)
  ORDER BY cc.id FOR UPDATE
 LOOP
  IF NOT payroll.correction_responsibilities_complete(p_tenant,c.proposal_id) THEN CONTINUE;END IF;
  UPDATE payroll.correction_cases SET status='completed',revision=revision+1 WHERE tenant_id=p_tenant AND id=c.id;
  details:=jsonb_build_object('case_id',c.id,'proposal_id',c.proposal_id,'run_id',p_run,'revision',c.revision+1,'basis','qualified_frozen_target_consumption');
  INSERT INTO payroll.correction_events(tenant_id,case_id,proposal_id,operation,actor_id,reason,details)
   VALUES(p_tenant,c.id,c.proposal_id,'target_consumed',p_actor,'Approved linked responsibilities consumed by qualified payroll',details);
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details)
   VALUES(p_tenant,c.employer_id,p_actor,'correction_target_consumed',details);
 END LOOP;
END $f$;
REVOKE ALL ON FUNCTION payroll.complete_consumed_correction_targets(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;anchor text;start_at integer;end_at integer;
BEGIN
 definition:=pg_get_functiondef('payroll.append_final_output_single(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
 anchor:=' RETURN output;';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_linked_target_finalization_anchor';END IF;
 EXECUTE replace(definition,anchor,' PERFORM payroll.complete_consumed_correction_targets(p_tenant,p_run,p_actor);'||anchor);
 -- Preserve external settlement capacity, authority, receipt, and one revision.
 definition:=pg_get_functiondef('public.payroll_correction_settlement(uuid,uuid,uuid,integer,uuid,text,numeric,date,text,text,uuid)'::regprocedure);
 anchor:='UPDATE payroll.correction_cases SET status=CASE WHEN';
 start_at:=position(anchor IN definition);end_at:=position('revision=revision+1 WHERE tenant_id=p_tenant AND id=c.id;' IN definition);
 IF start_at=0 OR end_at<=start_at THEN RAISE EXCEPTION 'unexpected_linked_target_settlement_anchor';END IF;
 definition:=substr(definition,1,start_at-1)||'UPDATE payroll.correction_cases SET status=CASE WHEN payroll.correction_responsibilities_complete(p_tenant,p.id) THEN ''completed'' ELSE status END,'||substr(definition,end_at);
 EXECUTE definition;
END $patch$;
