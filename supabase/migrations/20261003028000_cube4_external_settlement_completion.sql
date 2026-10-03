-- Finish a routed correction only after all its approved responsibilities are
-- external evidence and completely covered. Other responsibility routes stay open.
DO $patch$ DECLARE definition text;old text;replacement text;BEGIN
 definition:=pg_get_functiondef('public.payroll_correction_settlement(uuid,uuid,uuid,integer,uuid,text,numeric,date,text,text,uuid)'::regprocedure);
 old:='UPDATE payroll.correction_cases SET revision=revision+1 WHERE tenant_id=p_tenant AND id=c.id;';
 replacement:='UPDATE payroll.correction_cases SET status=CASE WHEN
  NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.responsibilities) responsibility
   WHERE responsibility->>''basis'' IS DISTINCT FROM ''external_reviewed'')
  AND NOT EXISTS(
   SELECT 1 FROM(
    SELECT (responsibility->>''employment_id'')::uuid employment_id,
     CASE WHEN(responsibility->>''amount'')::numeric>0 THEN ''employee_extra_payment'' ELSE ''employee_recovery'' END direction,
     sum(abs((responsibility->>''amount'')::numeric)) capacity
    FROM jsonb_array_elements(p.responsibilities) responsibility
    WHERE responsibility->>''basis''=''external_reviewed''
    GROUP BY 1,2
   ) required WHERE required.capacity>(
    SELECT COALESCE(sum(settlement.amount),0) FROM payroll.correction_settlements settlement
    WHERE settlement.tenant_id=p_tenant AND settlement.proposal_id=p.id
     AND settlement.employment_id=required.employment_id AND settlement.direction=required.direction)
  ) THEN ''completed'' ELSE status END,revision=revision+1 WHERE tenant_id=p_tenant AND id=c.id;';
 IF (length(definition)-length(replace(definition,old,'')))/length(old)<>1
  THEN RAISE EXCEPTION 'unexpected_settlement_completion_anchor';END IF;
 EXECUTE replace(definition,old,replacement);
END $patch$;
