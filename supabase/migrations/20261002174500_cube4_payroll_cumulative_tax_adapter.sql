-- Dated cumulative tax adapter. No rules are seeded or made legally qualified.
-- Insurance and earning attribution must be established before candidate integration.
ALTER TABLE payroll.statutory_packs ADD COLUMN rules jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE FUNCTION payroll.calculate_cumulative_tax(p_pack uuid, p_context jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $f$
DECLARE
 pack payroll.statutory_packs; rules jsonb; col jsonb; selected jsonb;
 key text; amount numeric; duration numeric; prior numeric; exemption numeric;
 annual_raw numeric; annual_base numeric; selection_base numeric;
 threshold numeric; last_threshold numeric := 0; idx integer := 0; selected_idx integer;
 annual_tax numeric; cumulative_tax numeric; delta numeric; trace jsonb;
 earning_from date; earning_until date;
BEGIN
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 IF NOT FOUND OR pack.state<>'verified' OR pack.engine_adapter IS DISTINCT FROM 'eg-cumulative-tax-v1'
   OR jsonb_typeof(pack.review_evidence->'numeric_comparisons') IS DISTINCT FROM 'array'
   OR jsonb_array_length(pack.review_evidence->'numeric_comparisons')=0 THEN
   RAISE EXCEPTION 'payroll_statutory_pack_unqualified' USING ERRCODE='22023';
 END IF;
 rules:=pack.rules;
 IF jsonb_typeof(rules) IS DISTINCT FROM 'object' OR
   NOT (rules ?& ARRAY['schema','tax_treatment_code','day_basis','personal_exemption','base_rounding','column_basis','tax_rounding','columns'])
   OR (SELECT count(*) FROM jsonb_object_keys(rules))<>8
   OR rules->>'schema' IS DISTINCT FROM 'eg-cumulative-tax-v1'
   OR rules->>'base_rounding' IS DISTINCT FROM 'floor10'
   OR COALESCE(rules->>'column_basis','') NOT IN ('annual_raw','annual_floor10')
   OR rules->>'tax_rounding' IS DISTINCT FROM 'cumulative_half_up_cent'
   OR jsonb_typeof(rules->'day_basis') IS DISTINCT FROM 'number'
   OR (rules->>'day_basis')::numeric<>360
   OR jsonb_typeof(rules->'personal_exemption') IS DISTINCT FROM 'number'
   OR (rules->>'personal_exemption')::numeric NOT BETWEEN 0 AND 1000000000
   OR jsonb_typeof(rules->'tax_treatment_code') IS DISTINCT FROM 'string'
   OR rules->>'tax_treatment_code' !~ '^[0-9]{2}$'
   OR jsonb_typeof(rules->'columns') IS DISTINCT FROM 'array'
   OR jsonb_array_length(rules->'columns') NOT BETWEEN 1 AND 16 THEN
   RAISE EXCEPTION 'payroll_statutory_rules_invalid' USING ERRCODE='22023';
 END IF;
 IF jsonb_typeof(p_context) IS DISTINCT FROM 'object' OR
   NOT (p_context ?& ARRAY['cumulative_net_before_personal_exemption','cumulative_duration_days','prior_tax_due','earning_from','earning_until','tax_treatment_code','source_reference'])
   OR (SELECT count(*) FROM jsonb_object_keys(p_context))<>7
   OR p_context->>'tax_treatment_code' IS DISTINCT FROM rules->>'tax_treatment_code'
   OR jsonb_typeof(p_context->'source_reference') IS DISTINCT FROM 'string'
   OR length(btrim(p_context->>'source_reference')) NOT BETWEEN 1 AND 160 THEN
   RAISE EXCEPTION 'payroll_statutory_context_invalid' USING ERRCODE='22023';
 END IF;
 FOREACH key IN ARRAY ARRAY['cumulative_net_before_personal_exemption','cumulative_duration_days','prior_tax_due'] LOOP
   IF jsonb_typeof(p_context->key) IS DISTINCT FROM 'number' THEN
     RAISE EXCEPTION 'payroll_statutory_context_invalid' USING ERRCODE='22023';
   END IF;
   amount:=(p_context->>key)::numeric;
   IF amount::text IN ('NaN','Infinity','-Infinity') OR amount<0 OR amount>1000000000000
     OR amount<>round(amount,2) THEN
     RAISE EXCEPTION 'payroll_statutory_context_invalid' USING ERRCODE='22023';
   END IF;
 END LOOP;
 duration:=(p_context->>'cumulative_duration_days')::numeric;
 prior:=(p_context->>'prior_tax_due')::numeric;
 IF duration<=0 OR duration>360 THEN
   RAISE EXCEPTION 'payroll_statutory_context_invalid' USING ERRCODE='22023';
 END IF;
 FOREACH key IN ARRAY ARRAY['earning_from','earning_until'] LOOP
   IF jsonb_typeof(p_context->key) IS DISTINCT FROM 'string' OR p_context->>key !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
     RAISE EXCEPTION 'payroll_statutory_context_invalid' USING ERRCODE='22023';
   END IF;
 END LOOP;
 BEGIN
   earning_from:=(p_context->>'earning_from')::date;
   earning_until:=(p_context->>'earning_until')::date;
 EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN
   RAISE EXCEPTION 'payroll_statutory_context_invalid' USING ERRCODE='22023';
 END;
 IF NOT isfinite(pack.effective_from) OR (pack.effective_until IS NOT NULL AND NOT isfinite(pack.effective_until))
   OR earning_from>earning_until OR extract(year FROM earning_from)<>extract(year FROM earning_until)
   OR earning_from<pack.effective_from OR (pack.effective_until IS NOT NULL AND earning_until>=pack.effective_until) THEN
   RAISE EXCEPTION 'payroll_statutory_period_unsupported' USING ERRCODE='22023';
 END IF;
 exemption:=(rules->>'personal_exemption')::numeric;
 annual_raw:=greatest((p_context->>'cumulative_net_before_personal_exemption')::numeric*360/duration-exemption,0);
 annual_base:=payroll.floor_annual_base_to_ten(annual_raw);
 selection_base:=CASE rules->>'column_basis' WHEN 'annual_raw' THEN annual_raw ELSE annual_base END;
 -- Validate all columns, not only the one reached by the employee's income.
 FOR col IN SELECT value FROM jsonb_array_elements(rules->'columns') LOOP
   idx:=idx+1;
   IF jsonb_typeof(col) IS DISTINCT FROM 'object' OR NOT(col ?& ARRAY['through','bands'])
     OR (SELECT count(*) FROM jsonb_object_keys(col))<>2
     OR jsonb_typeof(col->'through') NOT IN ('number','null') THEN
     RAISE EXCEPTION 'payroll_statutory_rules_invalid' USING ERRCODE='22023';
   END IF;
   threshold:=(col->>'through')::numeric;
   IF (idx=jsonb_array_length(rules->'columns') AND threshold IS NOT NULL)
     OR (idx<jsonb_array_length(rules->'columns') AND threshold IS NULL)
     OR (threshold IS NOT NULL AND (threshold::text IN ('NaN','Infinity','-Infinity') OR threshold<=last_threshold)) THEN
     RAISE EXCEPTION 'payroll_statutory_rules_invalid' USING ERRCODE='22023';
   END IF;
   PERFORM payroll.progressive_annual_arithmetic(0,col->'bands');
   IF selected IS NULL AND (threshold IS NULL OR selection_base<=threshold) THEN selected:=col;selected_idx:=idx; END IF;
   last_threshold:=coalesce(threshold,last_threshold);
 END LOOP;
 trace:=payroll.progressive_annual_arithmetic(annual_base,selected->'bands');
 annual_tax:=(trace->>'unrounded_annual_tax')::numeric;
 cumulative_tax:=round(annual_tax*duration/360,2);
 -- Signed delta preserves corrections/refunds. Withheld cash is not prior due tax.
 delta:=cumulative_tax-prior;
 RETURN jsonb_build_object('adapter','eg-cumulative-tax-v1','pack_id',pack.id,'pack_version',pack.version,
   'earning_from',earning_from,'earning_until',earning_until,'source_reference',p_context->>'source_reference',
   'annual_raw_after_exemption',annual_raw,'annual_base',annual_base,'column',selected_idx,
   'duration_days',duration,'annual_tax_unrounded',annual_tax,'cumulative_tax_due',cumulative_tax,
   'prior_tax_due',prior,'current_tax_delta',delta,'trace',trace);
END $f$;
REVOKE ALL ON FUNCTION payroll.calculate_cumulative_tax(uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
