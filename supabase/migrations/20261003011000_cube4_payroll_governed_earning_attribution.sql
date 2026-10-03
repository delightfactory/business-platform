-- Earning treatment is versioned pack data. No default legal rule is seeded.
ALTER TABLE payroll.statutory_packs ADD COLUMN earning_rules jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE FUNCTION payroll.resolve_taxable_earnings(p_employee jsonb,p_pack uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE pack payroll.statutory_packs;rules jsonb;sources jsonb;line jsonb;part jsonb;
 taxable_parts jsonb;amount numeric;taxable numeric;total_taxable numeric:=0;total_nontaxable numeric:=0;
 lines jsonb:='[]';starts date;ends date;fraction jsonb;
BEGIN
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 IF NOT FOUND OR pack.state<>'verified' OR pack.engine_adapter IS DISTINCT FROM 'eg-cumulative-tax-v1'
  OR jsonb_typeof(pack.review_evidence->'numeric_comparisons') IS DISTINCT FROM 'array'
  OR jsonb_array_length(pack.review_evidence->'numeric_comparisons')=0 THEN
  RAISE EXCEPTION 'payroll_statutory_pack_unqualified' USING ERRCODE='22023';END IF;
 rules:=pack.earning_rules;
 IF jsonb_typeof(rules) IS DISTINCT FROM 'object' OR NOT(rules ?& ARRAY['schema','base_taxable','component_treatment','mixed_rounding'])
  OR (SELECT count(*) FROM jsonb_object_keys(rules))<>4 OR rules->>'schema' IS DISTINCT FROM 'eg-earning-treatment-v1'
  OR jsonb_typeof(rules->'base_taxable') IS DISTINCT FROM 'boolean'
  OR rules->>'component_treatment' IS DISTINCT FROM 'reviewed_dated_declarations'
  OR rules->>'mixed_rounding' IS DISTINCT FROM 'taxable_half_up_cent_remainder_nontaxable' THEN
  RAISE EXCEPTION 'payroll_earning_rules_unqualified' USING ERRCODE='22023';END IF;
 IF p_employee->>'gross_complete' IS DISTINCT FROM 'true' OR coalesce(p_employee->>'gross','') !~ '^[0-9]+(\.[0-9]{1,2}0*)?$'
  OR coalesce(p_employee->>'starts_on','') !~ '^\d{4}-\d{2}-\d{2}$' OR coalesce(p_employee->>'ends_on','') !~ '^\d{4}-\d{2}-\d{2}$' THEN
  RAISE EXCEPTION 'payroll_earning_sources_invalid' USING ERRCODE='22023';END IF;
 BEGIN starts:=(p_employee->>'starts_on')::date;ends:=(p_employee->>'ends_on')::date;
 EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN RAISE EXCEPTION 'payroll_earning_sources_invalid' USING ERRCODE='22023';END;
 IF starts>ends OR NOT isfinite(pack.effective_from) OR(pack.effective_until IS NOT NULL AND NOT isfinite(pack.effective_until))
  OR starts<pack.effective_from OR(pack.effective_until IS NOT NULL AND ends>=pack.effective_until) THEN
  RAISE EXCEPTION 'payroll_statutory_period_unsupported' USING ERRCODE='22023';END IF;
 sources:=payroll.current_earning_sources(p_employee);
 FOR line IN SELECT value FROM jsonb_array_elements(sources->'lines') LOOP
  amount:=(line->>'amount')::numeric;
  IF line->>'component'='base' THEN taxable:=CASE WHEN(rules->>'base_taxable')::boolean THEN amount ELSE 0 END;
  ELSIF line->>'declaration_state'='uniform_declared_taxable' THEN taxable:=amount;
  ELSIF line->>'declaration_state'='uniform_declared_nontaxable' THEN taxable:=0;
  ELSIF line->>'declaration_state'='mixed_declarations_require_allocation' THEN
   taxable_parts:='[]';
   FOR part IN SELECT value FROM jsonb_array_elements(line->'source_parts') LOOP
    IF coalesce(part->>'_numerator','') !~ '^[0-9]+(\.0+)?$' OR coalesce(part->>'_denominator','') !~ '^[0-9]+(\.0+)?$'
     OR(part->>'_denominator')::numeric<=0 THEN RAISE EXCEPTION 'payroll_earning_allocation_unknown' USING ERRCODE='22023';END IF;
    IF part->'declared_taxable'='true'::jsonb THEN taxable_parts:=taxable_parts||jsonb_build_array(part);END IF;
   END LOOP;
   -- Verify the original total using exact parts, then round the taxable share
   -- once under the explicit pack rule. The complementary share retains cents.
   IF payroll.round_fraction(payroll.parts_fraction(line->'source_parts'))<>amount THEN
    RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
   fraction:=payroll.parts_fraction(taxable_parts);taxable:=payroll.round_fraction(fraction);
  ELSE RAISE EXCEPTION 'payroll_earning_allocation_unknown' USING ERRCODE='22023';END IF;
  IF taxable<0 OR taxable>amount THEN RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
  total_taxable:=total_taxable+taxable;total_nontaxable:=total_nontaxable+amount-taxable;
  lines:=lines||jsonb_build_array(line||jsonb_build_object('taxable_amount',taxable,'nontaxable_amount',amount-taxable,'rounding',rules->>'mixed_rounding'));
 END LOOP;
 IF total_taxable+total_nontaxable<>(p_employee->>'gross')::numeric THEN
  RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
 RETURN jsonb_build_object('contract','eg-earning-attribution-v1','pack_id',pack.id,'pack_version',pack.version,
  'earning_rules',rules,'taxable_earnings',total_taxable,'nontaxable_earnings',total_nontaxable,'lines',lines,'financially_qualified',false);
END $f$;
CREATE FUNCTION payroll.calculate_statutory_employee_with_earnings(p_employee jsonb,p_pack uuid,p_facts jsonb,p_insurance jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE earnings jsonb;result jsonb;BEGIN
 IF jsonb_typeof(p_facts) IS DISTINCT FROM 'object' OR p_facts ? 'current_taxable_earnings' THEN
  RAISE EXCEPTION 'payroll_statutory_employee_invalid' USING ERRCODE='22023';END IF;
 earnings:=payroll.resolve_taxable_earnings(p_employee,p_pack);
 result:=payroll.calculate_statutory_employee(p_employee,p_pack,p_facts||jsonb_build_object('current_taxable_earnings',earnings->'taxable_earnings'),p_insurance);
 RETURN jsonb_set(result,'{statutory_calculation,earning_attribution}',earnings);
END $f$;
REVOKE ALL ON FUNCTION payroll.resolve_taxable_earnings(jsonb,uuid),
 payroll.calculate_statutory_employee_with_earnings(jsonb,uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
