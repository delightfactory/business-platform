-- The numeric draft already requires an explicit reviewed base_taxable choice.
-- Carry that existing value to the versioned earning adapter contract. Existing
-- issued packs remain immutable; this affects only future reviewed issuance.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.statutory_draft_pack(payroll.statutory_draft_versions,text)'::regprocedure);
 anchor:=' RETURN pack;';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'unexpected_earning_draft_pack_return';END IF;
 EXECUTE replace(definition,anchor,
  ' pack.earning_rules:=jsonb_build_object(''schema'',''eg-earning-treatment-v1'',''base_taxable'',r->''base_taxable'',
    ''component_treatment'',''reviewed_dated_declarations'',''mixed_rounding'',''taxable_half_up_cent_remainder_nontaxable'');'||anchor);

 definition:=pg_get_functiondef('public.statutory_draft_issue(uuid,integer,uuid,text,boolean,text)'::regprocedure);
 anchor:='engine_adapter,rules,insurance_rules)';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'unexpected_earning_issuance_columns';END IF;
 definition:=replace(definition,anchor,'engine_adapter,rules,insurance_rules,earning_rules)');
 anchor:='''verified'',actor,''eg-cumulative-tax-v1'',pack.rules,pack.insurance_rules);';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'unexpected_earning_issuance_values';END IF;
 EXECUTE replace(definition,anchor,'''verified'',actor,''eg-cumulative-tax-v1'',pack.rules,pack.insurance_rules,pack.earning_rules);');
END $patch$;
