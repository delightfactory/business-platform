-- A replacement is pending publication until its exact succession exists.
-- Do not include it beside its still-authoritative original during an atomic
-- batch. Keep all currentness checks; never suppress a published predecessor.
DO $patch$ DECLARE definition text;old text;replacement text;BEGIN
 definition:=pg_get_functiondef('payroll.prior_statutory_outputs(uuid,uuid,date,date,uuid[])'::regprocedure);
 old:='AND NOT EXISTS(SELECT 1 FROM payroll.output_successions s WHERE s.tenant_id=f.tenant_id AND s.original_output=f.id)';
 replacement:=old||'
   AND (r.amendment_of IS NULL OR EXISTS(SELECT 1 FROM payroll.output_successions published
    WHERE published.tenant_id=f.tenant_id AND published.replacement_output=f.id AND published.original_output=r.amendment_of))';
 IF (length(definition)-length(replace(definition,old,'')))/length(old)<>1
  THEN RAISE EXCEPTION 'unexpected_prior_replacement_authority_anchor';END IF;
 EXECUTE replace(definition,old,replacement);
END $patch$;
