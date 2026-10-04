-- Compose explicit reviewed legal intervals. Preserve original ordinary lines
-- rounded once; chronological prefix differences conserve their cents. This
-- allocation must be part of immutable issued earning rules, never a tenant
-- flag or a inferred earning date for period amounts/manual daily units.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.validate_statutory_draft_rules(jsonb)'::regprocedure);
 anchor:='OR(SELECT count(*) FROM jsonb_object_keys(p_rules))<>3';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partition_draft_keys';END IF;
 definition:=replace(definition,anchor,'OR(p_rules-''earning_partition_rounding''-ARRAY[''tax'',''insurance'',''base_taxable''])<>''{}''::jsonb');
 anchor:=' t:=p_rules->''tax'';';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partition_draft_validation';END IF;
 EXECUTE replace(definition,anchor,$insert$
 IF p_rules ? 'earning_partition_rounding' AND
  (jsonb_typeof(p_rules->'earning_partition_rounding') IS DISTINCT FROM 'string'
   OR p_rules->>'earning_partition_rounding' IS DISTINCT FROM 'chronological_prefix_half_up_cent') THEN
  RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 t:=p_rules->'tax';$insert$);
 definition:=pg_get_functiondef('payroll.statutory_draft_pack(payroll.statutory_draft_versions,text)'::regprocedure);
 anchor:=' RETURN pack;';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partition_pack_return';END IF;
 EXECUTE replace(definition,anchor,' IF r ? ''earning_partition_rounding'' THEN pack.earning_rules:=pack.earning_rules||jsonb_build_object(''date_partition_rounding'',r->''earning_partition_rounding'');END IF;'||anchor);
 definition:=pg_get_functiondef('payroll.resolve_taxable_earnings(jsonb,uuid)'::regprocedure);
 anchor:='OR (SELECT count(*) FROM jsonb_object_keys(rules))<>4';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_partition_earning_rules';END IF;
 EXECUTE replace(definition,anchor,'OR(rules-''date_partition_rounding''-ARRAY[''schema'',''base_taxable'',''component_treatment'',''mixed_rounding''])<>''{}''::jsonb OR(rules ? ''date_partition_rounding'' AND rules->>''date_partition_rounding'' IS DISTINCT FROM ''chronological_prefix_half_up_cent'')');
END $patch$;

CREATE FUNCTION payroll.reviewed_earning_segment(p_employee jsonb,p_from date,p_until date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE source jsonb;line jsonb;parts jsonb;before_parts jsonb;through_parts jsonb;selected jsonb;
 lines jsonb:='[]';amount numeric;gross numeric:=0;cost numeric:=0;employee jsonb;
BEGIN
 IF p_from IS NULL OR p_until IS NULL OR NOT isfinite(p_from) OR NOT isfinite(p_until)
  OR p_from>p_until OR p_from<(p_employee->>'starts_on')::date OR p_until>(p_employee->>'ends_on')::date THEN
  RAISE EXCEPTION 'statutory_composition_context_mismatch' USING ERRCODE='22023';END IF;
 FOR line IN SELECT value FROM jsonb_array_elements(p_employee->'lines') LOOP
  IF line->>'classification' NOT IN('earning','employer_cost') THEN
   RAISE EXCEPTION 'financial_profile_composition_required' USING ERRCODE='22023';END IF;
  IF line->>'classification'='earning' THEN
   SELECT value INTO source FROM jsonb_array_elements(payroll.current_earning_sources(p_employee)->'lines')
    WHERE value->>'component'=line->>'component';
   IF source->>'attribution' IS DISTINCT FROM 'saved_salary_distribution'
    OR source->>'declaration_state' IN('unknown_source_declaration','mixed_declarations_require_allocation') THEN
    RAISE EXCEPTION 'payroll_earning_allocation_unknown' USING ERRCODE='22023';END IF;
  END IF;
  SELECT coalesce(jsonb_agg((envelope-'detail'-'raw')||part ORDER BY outer_index,inner_index),'[]') INTO parts
   FROM jsonb_array_elements(line->'details') WITH ORDINALITY outer_item(envelope,outer_index)
   CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(envelope->'detail')='array'
    THEN envelope->'detail' ELSE jsonb_build_array(envelope) END) WITH ORDINALITY inner_item(part,inner_index);
  IF jsonb_array_length(parts)=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(parts) part
   WHERE coalesce(part->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    OR coalesce(part->>'_numerator','')!~'^[0-9]+(\.0+)?$'
    OR coalesce(part->>'_denominator','')!~'^[0-9]+(\.0+)?$'
    OR(part->>'_denominator')::numeric<=0) THEN
   RAISE EXCEPTION 'payroll_earning_allocation_unknown' USING ERRCODE='22023';END IF;
  IF payroll.round_fraction(payroll.parts_fraction(parts))<>(line->>'amount')::numeric
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(parts) part WHERE(part->>'date')::date NOT BETWEEN(p_employee->>'starts_on')::date AND(p_employee->>'ends_on')::date) THEN
   RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
  SELECT coalesce(jsonb_agg(part ORDER BY ordinality),'[]') INTO before_parts
   FROM jsonb_array_elements(parts) WITH ORDINALITY item(part,ordinality) WHERE(part->>'date')::date<p_from;
  SELECT coalesce(jsonb_agg(part ORDER BY ordinality),'[]') INTO through_parts
   FROM jsonb_array_elements(parts) WITH ORDINALITY item(part,ordinality) WHERE(part->>'date')::date<=p_until;
  SELECT coalesce(jsonb_agg(part ORDER BY ordinality),'[]') INTO selected
   FROM jsonb_array_elements(parts) WITH ORDINALITY item(part,ordinality) WHERE(part->>'date')::date BETWEEN p_from AND p_until;
  amount:=payroll.round_fraction(payroll.parts_fraction(through_parts))-payroll.round_fraction(payroll.parts_fraction(before_parts));
  IF line->>'classification'='earning' THEN gross:=gross+amount;ELSE cost:=cost+amount;END IF;
  -- Preserve each source part and version; do not edit unrounded rational facts.
  IF jsonb_array_length(selected)>0 THEN lines:=lines||jsonb_build_array(line||jsonb_build_object('amount',amount::text,'details',selected,
   'earning_segment',jsonb_build_object('from',p_from,'until',p_until,'original_amount',line->'amount','prefix_before',payroll.round_fraction(payroll.parts_fraction(before_parts)),'prefix_through',payroll.round_fraction(payroll.parts_fraction(through_parts)))));END IF;
 END LOOP;
 employee:=p_employee||jsonb_build_object('starts_on',p_from,'ends_on',p_until,'lines',lines,'gross',gross::text,'deductions','0','employer_cost',cost::text);
 RETURN employee;
END $f$;
REVOKE ALL ON FUNCTION payroll.reviewed_earning_segment(jsonb,date,date) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.compose_reviewed_statutory_segments(p_manifest jsonb,p_employee jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE context jsonb;data jsonb;balance jsonb;sources jsonb:=p_employee->'statutory_sources';
 child jsonb;calculated jsonb;segment jsonb;segments jsonb:='[]';year_balances jsonb:='{}';
 years jsonb:='[]';claims jsonb:='[]';bindings jsonb:='[]';qualifications jsonb:='[]';
 legal_lines jsonb:='[]';lines jsonb;issues jsonb;code text;pack payroll.statutory_packs;
 previous date:=(p_employee->>'starts_on')::date-1;starts date;ends date;year_number integer;
 gross numeric:=0;employee_social numeric:=0;employer_social numeric:=0;tax numeric:=0;net numeric;
 operational_cost numeric:=0;seen_months text[]:='{}';claim jsonb;employment uuid:=(p_employee->>'employment_id')::uuid;
BEGIN
 IF p_employee->>'gross_complete' IS DISTINCT FROM 'true' THEN RETURN p_employee;END IF;
 IF p_employee->>'pay_basis'<>'monthly' OR(p_employee->>'deductions')::numeric<>0
  OR coalesce((p_manifest->'optional'->>'time')::boolean,false) OR coalesce((p_manifest->'optional'->>'leave')::boolean,false)
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_manifest->'advances','[]')) source WHERE source->>'employment_id'=employment::text)
  OR sources->'calendar'->>'known' IS DISTINCT FROM 'true'
  OR jsonb_array_length(sources->'contexts') NOT BETWEEN 2 AND 24 THEN
  RAISE EXCEPTION 'financial_profile_composition_required' USING ERRCODE='22023';END IF;
 FOR balance IN SELECT value FROM jsonb_array_elements(sources->'cumulative_balances'->'years') LOOP
  IF balance->>'known' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'statutory_prior_balance_required' USING ERRCODE='22023';END IF;
  year_balances:=jsonb_set(year_balances,ARRAY[balance->>'year'],balance);
 END LOOP;
 FOR context IN SELECT value FROM jsonb_array_elements(sources->'contexts') ORDER BY value->>'from',value->>'version_id' LOOP
  data:=context->'source'->'version'->'data';starts:=(context->>'from')::date;ends:=(context->>'through')::date;year_number:=extract(year FROM starts);
  IF starts<>previous+1 OR starts>ends OR ends>(p_employee->>'ends_on')::date
   OR extract(year FROM ends)<>year_number OR data->>'calculation_from' IS DISTINCT FROM starts::text
   OR data->>'calculation_until' IS DISTINCT FROM ends::text THEN
   RAISE EXCEPTION 'statutory_composition_context_mismatch' USING ERRCODE='22023';END IF;
  balance:=year_balances->year_number::text;
  IF balance IS NULL OR balance->>'through' IS DISTINCT FROM(starts-1)::text THEN
   RAISE EXCEPTION 'statutory_prior_balance_required' USING ERRCODE='22023';END IF;
  child:=payroll.reviewed_earning_segment(p_employee,starts,ends);
  child:=child||jsonb_build_object('statutory_sources',sources||jsonb_build_object('contexts',jsonb_build_array(context),
   'cumulative_balances',jsonb_build_object('years',jsonb_build_array(balance))));
  calculated:=payroll.compose_statutory_review(p_manifest,child);
  IF NOT(calculated ? 'statutory_calculation') OR calculated->>'financially_qualified' IS DISTINCT FROM 'true' THEN
   RETURN p_employee||jsonb_build_object('issues',p_employee->'issues'||coalesce(calculated->'issues','[]'),
    'statutory_segments',segments,'financially_qualified',false,'net',NULL);END IF;
  SELECT * INTO pack FROM payroll.statutory_packs WHERE id=(calculated->'statutory_calculation'->>'pack_id')::uuid;
  IF pack.earning_rules->>'date_partition_rounding' IS DISTINCT FROM 'chronological_prefix_half_up_cent' THEN
   RAISE EXCEPTION 'statutory_partition_rules_required' USING ERRCODE='22023';END IF;
  FOR claim IN SELECT value FROM jsonb_array_elements(calculated->'statutory_context'->'obligation_months') LOOP
   IF claim->>'month'=ANY(seen_months) THEN RAISE EXCEPTION 'insurance_month_already_consumed' USING ERRCODE='22023';END IF;
   seen_months:=array_append(seen_months,claim->>'month');claims:=claims||jsonb_build_array(claim);
  END LOOP;
  segment:=jsonb_build_object('starts_on',starts,'ends_on',ends,'gross',calculated->'gross',
   'statutory_context',calculated->'statutory_context','statutory_calculation',calculated->'statutory_calculation',
   'statutory_source_binding',calculated->'statutory_source_binding','financial_qualification',calculated->'financial_qualification');
  segments:=segments||jsonb_build_array(segment);bindings:=bindings||jsonb_build_array(calculated->'statutory_source_binding');
  qualifications:=qualifications||jsonb_build_array(calculated->'financial_qualification');
  SELECT coalesce(jsonb_agg(line),'[]') INTO lines FROM jsonb_array_elements(calculated->'lines') line WHERE line->>'component' LIKE 'statutory:%';
  legal_lines:=legal_lines||lines;gross:=gross+(calculated->>'gross')::numeric;
  employee_social:=employee_social+(calculated->'statutory_calculation'->'insurance'->>'employee_total')::numeric;
  employer_social:=employer_social+(calculated->'statutory_calculation'->'insurance'->>'employer_total')::numeric;
  tax:=tax+(calculated->'statutory_calculation'->'tax'->>'current_tax_delta')::numeric;
  operational_cost:=operational_cost+(child->>'employer_cost')::numeric;
  balance:=balance||jsonb_build_object('through',ends,'prior_net_income',
   (calculated->'statutory_calculation'->'facts'->>'prior_net_income')::numeric
    +(calculated->'statutory_calculation'->'facts'->>'current_taxable_earnings')::numeric
    -(calculated->'statutory_calculation'->'insurance'->>'tax_deductible_employee_total')::numeric,
   'prior_tax_due',calculated->'statutory_calculation'->'tax'->'cumulative_tax_due',
   'prior_duration_days',calculated->'statutory_calculation'->'tax'->'duration_days','basis','current_reviewed_segment');
  year_balances:=jsonb_set(year_balances,ARRAY[year_number::text],balance);previous:=ends;
 END LOOP;
 IF previous<>(p_employee->>'ends_on')::date OR gross<>(p_employee->>'gross')::numeric
  OR operational_cost<>(p_employee->>'employer_cost')::numeric THEN
  RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
 -- Aggregate only the tax display line; keep every segment and pack in details.
 SELECT coalesce(jsonb_agg(line),'[]') INTO lines FROM jsonb_array_elements(legal_lines) line WHERE line->>'component'<>'statutory:tax';
 SELECT jsonb_agg(detail ORDER BY ordinality) INTO issues FROM jsonb_array_elements(legal_lines) WITH ORDINALITY item(line,ordinality)
  CROSS JOIN LATERAL jsonb_array_elements(line->'details') detail WHERE line->>'component'='statutory:tax';
 SELECT line INTO calculated FROM jsonb_array_elements(legal_lines) line WHERE line->>'component'='statutory:tax' LIMIT 1;
 lines:=lines||jsonb_build_array(calculated||jsonb_build_object('amount',tax::text,'details',issues));
 net:=gross-employee_social-tax;
 IF net<0 THEN RAISE EXCEPTION 'negative_statutory_balance' USING ERRCODE='22023';END IF;
 SELECT jsonb_agg(value ORDER BY value->>'year') INTO years FROM jsonb_each(year_balances);
 SELECT coalesce(jsonb_agg(issue),'[]') INTO issues FROM jsonb_array_elements(p_employee->'issues') issue
  WHERE issue->>'code'<>'statutory_earning_attribution_required';
 RETURN p_employee||jsonb_build_object('lines',(p_employee->'lines')||lines,'issues',issues,
  'statutory_deductions',(employee_social+tax)::text,'statutory_contributions',employer_social::text,
  'employer_cost',(operational_cost+employer_social)::text,'total_employer_cost',(gross+operational_cost+employer_social)::text,
  'net',net::text,'calculated_net',net::text,'financially_qualified',true,'statutory_segments',segments,
  'statutory_context',jsonb_build_object('calendar_year','multiple_reviewed_segments','category','reviewed_segments',
   'insured_wage_source','reviewed_segment_sources','insured_wage',(SELECT CASE WHEN count(DISTINCT value->'statutory_context'->'insured_wage')=1 THEN min((value->'statutory_context'->>'insured_wage')::numeric)::text ELSE 'see_statutory_segments' END FROM jsonb_array_elements(segments)),'obligation_months',claims,'segments',segments,'years',years),
  'statutory_source_binding',jsonb_build_object('segments',bindings),
  'financial_qualification',jsonb_build_object('profile','eg-reviewed-context-year-segments-v1','segments',qualifications));
EXCEPTION WHEN SQLSTATE '22023' THEN
 GET STACKED DIAGNOSTICS code=MESSAGE_TEXT;
 RETURN p_employee||jsonb_build_object('issues',p_employee->'issues'||jsonb_build_array(payroll.issue(code,employment,'payroll_compliance')),
  'financially_qualified',false,'net',NULL);
END $f$;
REVOKE ALL ON FUNCTION payroll.compose_reviewed_statutory_segments(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.compose_statutory_review(jsonb,jsonb)'::regprocedure);
 anchor:=' IF jsonb_array_length(sources->''contexts'')<>1';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_context_composition_branch';END IF;
 EXECUTE replace(definition,anchor,' IF jsonb_array_length(sources->''contexts'')>1 THEN RETURN payroll.compose_reviewed_statutory_segments(p_manifest,p_employee);END IF;'||anchor);
 definition:=pg_get_functiondef('payroll.prior_statutory_outputs(uuid,uuid,date,date,uuid[])'::regprocedure);
 anchor:='calculation.value->''statutory_calculation''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_segment_prior_calculation';END IF;
 definition:=replace(definition,anchor,'segment.value->''statutory_calculation''');
 anchor:='''statutory_context'',e.statutory_context';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_segment_prior_context';END IF;
 definition:=replace(definition,anchor,'''statutory_context'',coalesce(segment.value->''statutory_context'',e.statutory_context)');
 anchor:='''starts_on'',p.starts_on,''ends_on'',p.ends_on';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_segment_prior_dates';END IF;
 definition:=replace(definition,anchor,'''starts_on'',coalesce(segment.value->>''starts_on'',p.starts_on::text),''ends_on'',coalesce(segment.value->>''ends_on'',p.ends_on::text)');
 anchor:=' ) calculation ON true';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_segment_prior_join';END IF;
 EXECUTE replace(definition,anchor,anchor||' CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN calculation.value ? ''statutory_segments'' THEN calculation.value->''statutory_segments'' ELSE jsonb_build_array(calculation.value) END) segment(value)');
 definition:=pg_get_functiondef('payroll.build_review(jsonb)'::regprocedure);
 anchor:=' SELECT coalesce(jsonb_agg(DISTINCT issue)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_segment_issue_reconciliation';END IF;
 EXECUTE replace(definition,anchor,$insert$
 SELECT coalesce(jsonb_agg(issue),'[]') INTO issues FROM jsonb_array_elements(issues) issue
 WHERE NOT(issue->>'code'='statutory_earning_attribution_required'
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(employees) employee WHERE employee->>'employment_id'=issue->>'employment_id'
   AND employee->'financial_qualification'->>'profile'='eg-reviewed-context-year-segments-v1'));
 SELECT coalesce(jsonb_agg(DISTINCT issue)$insert$);
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_segment_engine';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-reviewed-context-year-v1'');'||anchor);
END $patch$;
