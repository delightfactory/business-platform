-- Explicit prior net income is a reviewed source fact, not a presumed
-- deduction of all employee contributions from historical gross earnings.
DO $f$ DECLARE definition text;anchor text:='''taxable_earnings'',''tax_withheld'',''tax_due'',''coverage_start''';BEGIN
 definition:=pg_get_functiondef('payroll.validate_input(text,jsonb)'::regprocedure);
 IF strpos(definition,anchor)=0 OR strpos(definition,'tax_net_income')<>0 THEN RAISE EXCEPTION 'unexpected_cumulative_opening_validator';END IF;
 definition:=replace(definition,anchor,'''taxable_earnings'',''tax_withheld'',''tax_due'',''tax_net_income'',''coverage_start''');
 anchor:=' IF p_kind=''opening_ytd'' THEN';
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'unexpected_cumulative_opening_branch';END IF;
 EXECUTE replace(definition,anchor,$patch$
 IF p_kind='opening_ytd' AND p_data ? 'tax_net_income' THEN
  IF jsonb_typeof(p_data->'tax_net_income') NOT IN('number','string')
    OR coalesce(p_data->>'tax_net_income','') !~ '^[0-9]+(\.[0-9]{1,2})?$'
    OR coalesce(p_data->>'taxable_earnings','') !~ '^[0-9]+(\.[0-9]{1,2})?$' THEN
    RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
  IF (p_data->>'tax_net_income')::numeric>999999999999.99
    OR (p_data->>'tax_net_income')::numeric>(p_data->>'taxable_earnings')::numeric THEN
    RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 END IF;
 IF p_kind='opening_ytd' THEN$patch$);
END $f$;

CREATE FUNCTION payroll.employee_cumulative_balances(p_sources jsonb,p_employee jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE year_number integer;prior jsonb;opening jsonb;data jsonb;current_source jsonb;last_source jsonb;first_prior jsonb;anchor date;
 years jsonb:='[]';issues jsonb:='[]';refs jsonb;known boolean;net numeric;due numeric;duration numeric;through_date date;first_source boolean;
BEGIN
 FOR year_number IN extract(year FROM (p_employee->>'starts_on')::date)::integer..extract(year FROM (p_employee->>'ends_on')::date)::integer LOOP
  known:=true;net:=NULL;due:=NULL;duration:=NULL;through_date:=NULL;last_source:=NULL;first_prior:=NULL;refs:='[]';first_source:=true;
  anchor:=greatest((p_employee->>'starts_on')::date,make_date(year_number,1,1));
  SELECT coalesce(jsonb_agg(s ORDER BY s->>'ends_on',s->>'starts_on',s->>'output_id',s->>'employment_id'),'[]') INTO prior
  FROM jsonb_array_elements(p_sources->'prior_outputs')s WHERE s->'statutory_context'->>'calendar_year'=year_number::text;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_sources->'issues')i WHERE i->>'code'='opening_ytd_ambiguous') THEN
   known:=false;
   issues:=issues||jsonb_build_array(payroll.issue('opening_ytd_ambiguous',(p_employee->>'employment_id')::uuid,'payroll_ytd'));
  ELSIF EXISTS(SELECT 1 FROM jsonb_array_elements(p_sources->'prior_outputs')s WHERE NOT coalesce(payroll.prior_statutory_output_usable(s),false)) THEN
   known:=false;
   issues:=issues||jsonb_build_array(payroll.issue('prior_statutory_context_unqualified',(p_employee->>'employment_id')::uuid,'payroll_compliance'));
  ELSIF jsonb_array_length(prior)>0 THEN
   FOR current_source IN SELECT value FROM jsonb_array_elements(prior) LOOP
    IF first_source THEN first_prior:=current_source;END IF;
    IF NOT first_source AND (
      (current_source->'statutory_calculation'->'facts'->>'prior_net_income')::numeric<>net
      OR (current_source->'statutory_calculation'->'facts'->>'prior_tax_due')::numeric<>due
      OR (current_source->'statutory_calculation'->'tax'->>'duration_days')::numeric<=duration
      OR (current_source->'statutory_calculation'->'facts'->>'earning_from')::date<>through_date+1) THEN
     known:=false;EXIT;
    END IF;
    -- Each result is cumulative. Replace the running balance; do not add
    -- cumulative results together or subtract historical insurance twice.
    net:=(current_source->'statutory_calculation'->'facts'->>'prior_net_income')::numeric
      +(current_source->'statutory_calculation'->'facts'->>'current_taxable_earnings')::numeric
      -(current_source->'statutory_calculation'->'insurance'->>'tax_deductible_employee_total')::numeric;
    due:=(current_source->'statutory_calculation'->'tax'->>'cumulative_tax_due')::numeric;
    duration:=(current_source->'statutory_calculation'->'tax'->>'duration_days')::numeric;
    through_date:=(current_source->'statutory_calculation'->'facts'->>'earning_until')::date;
    refs:=refs||jsonb_build_array(current_source->'output_id');last_source:=current_source;first_source:=false;
   END LOOP;
   IF NOT known THEN issues:=issues||jsonb_build_array(payroll.issue('prior_ytd_chain_inconsistent',(p_employee->>'employment_id')::uuid,'payroll_compliance'));END IF;
   SELECT o->'source'->'version'->'data' INTO data FROM jsonb_array_elements(p_sources->'openings')o WHERE o->>'year'=year_number::text;
   IF (data->>'coverage_end')::date>=(first_prior->'statutory_calculation'->'facts'->>'earning_from')::date THEN
    known:=false;issues:=issues||jsonb_build_array(payroll.issue('opening_ytd_after_final_requires_review',(p_employee->>'employment_id')::uuid,'payroll_ytd'));
   ELSIF data ?& ARRAY['tax_net_income','tax_due'] AND (
     (data->>'tax_net_income')::numeric<>(first_prior->'statutory_calculation'->'facts'->>'prior_net_income')::numeric
     OR (data->>'tax_due')::numeric<>(first_prior->'statutory_calculation'->'facts'->>'prior_tax_due')::numeric) THEN
    known:=false;issues:=issues||jsonb_build_array(payroll.issue('prior_ytd_chain_inconsistent',(p_employee->>'employment_id')::uuid,'payroll_compliance'));
   END IF;
  ELSIF anchor=make_date(year_number,1,1) THEN
   net:=0;due:=0;duration:=0;through_date:=anchor-1;
  ELSE
   SELECT o INTO opening FROM jsonb_array_elements(p_sources->'openings')o WHERE o->>'year'=year_number::text;
   data:=opening->'source'->'version'->'data';
   IF data IS NULL OR NOT(data ?& ARRAY['tax_net_income','tax_due','coverage_start','coverage_end','tax_duration_days']) THEN
    known:=false;issues:=issues||jsonb_build_array(payroll.issue('opening_tax_net_income_unknown',(p_employee->>'employment_id')::uuid,'payroll_ytd'));
   ELSE
    net:=(data->>'tax_net_income')::numeric;due:=(data->>'tax_due')::numeric;duration:=(data->>'tax_duration_days')::numeric;
    through_date:=(data->>'coverage_end')::date;
    refs:=jsonb_build_array(opening->'source'->'version'->'id');
   END IF;
  END IF;
  IF known AND through_date<anchor-1 THEN
   known:=false;issues:=issues||jsonb_build_array(payroll.issue('prior_ytd_coverage_gap',(p_employee->>'employment_id')::uuid,'payroll_ytd'));
  END IF;
  years:=years||jsonb_build_array(jsonb_build_object('year',year_number,'known',known,
    'basis',CASE WHEN last_source IS NOT NULL THEN 'locked_cumulative_result' WHEN anchor=make_date(year_number,1,1) THEN 'year_start' ELSE 'reviewed_opening' END,
    'prior_net_income',CASE WHEN known THEN net END,'prior_tax_due',CASE WHEN known THEN due END,
    'prior_duration_days',CASE WHEN known THEN duration END,'through',CASE WHEN known THEN through_date END,'source_ids',refs));
 END LOOP;
 RETURN jsonb_build_object('contract','cube4-cumulative-balances-v1','years',years,'issues',issues,'financially_qualified',false);
END $f$;
REVOKE ALL ON FUNCTION payroll.employee_cumulative_balances(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION payroll.employee_statutory_sources(jsonb,jsonb) RENAME TO employee_statutory_sources_before_cumulative_balances;
CREATE FUNCTION payroll.employee_statutory_sources(p_manifest jsonb,p_employee jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE result jsonb;balances jsonb;issues jsonb;BEGIN
 result:=payroll.employee_statutory_sources_before_cumulative_balances(p_manifest,p_employee);
 balances:=payroll.employee_cumulative_balances(result,p_employee);
 issues:=result->'issues';
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(balances->'years')y WHERE y->>'known' IS DISTINCT FROM 'true') THEN
  SELECT coalesce(jsonb_agg(i ORDER BY i),'[]') INTO issues FROM jsonb_array_elements(issues)i
  WHERE i->>'code' NOT IN('opening_ytd_unknown','opening_ytd_ambiguous','opening_tax_due_unknown','opening_tax_coverage_unknown');
 END IF;
 RETURN result||jsonb_build_object('cumulative_balances',balances,'issues',issues||(balances->'issues'));
END $f$;

ALTER FUNCTION payroll.build_review(jsonb) RENAME TO build_review_before_cumulative_balances;
CREATE FUNCTION payroll.build_review(p_manifest jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE result jsonb;employees jsonb:='[]';e jsonb;known_ids jsonb:='[]';issues jsonb;
BEGIN
 result:=payroll.build_review_before_cumulative_balances(p_manifest);
 FOR e IN SELECT value FROM jsonb_array_elements(result->'employees') LOOP
  IF jsonb_array_length(e->'statutory_sources'->'cumulative_balances'->'years')>0
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(e->'statutory_sources'->'cumulative_balances'->'years')y WHERE y->>'known' IS DISTINCT FROM 'true') THEN
   known_ids:=known_ids||jsonb_build_array(e->'employment_id');
   SELECT coalesce(jsonb_agg(i ORDER BY i),'[]') INTO issues FROM jsonb_array_elements(e->'issues')i
   WHERE i->>'code' NOT IN('opening_ytd_unknown','opening_ytd_ambiguous','opening_tax_due_unknown','opening_tax_coverage_unknown');
   e:=e||jsonb_build_object('issues',issues);
  END IF;
  employees:=employees||jsonb_build_array(e);
 END LOOP;
 SELECT coalesce(jsonb_agg(i ORDER BY i),'[]') INTO issues FROM jsonb_array_elements(result->'issues')i
 WHERE NOT(known_ids ? (i->>'employment_id') AND i->>'code' IN('opening_ytd_unknown','opening_ytd_ambiguous','opening_tax_due_unknown','opening_tax_coverage_unknown'));
 RETURN result||jsonb_build_object('employees',employees,'issues',issues);
END $f$;
REVOKE ALL ON FUNCTION payroll.employee_statutory_sources(jsonb,jsonb),payroll.employee_statutory_sources_before_cumulative_balances(jsonb,jsonb),
 payroll.build_review(jsonb),payroll.build_review_before_cumulative_balances(jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;anchor text:='''-prior-finals-v1''';BEGIN
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_cumulative_balances_engine';END IF;
 EXECUTE replace(definition,anchor,'''-prior-finals-v1-cumulative-balances-v1''');
END $f$;
