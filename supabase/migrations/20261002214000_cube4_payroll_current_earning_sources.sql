-- Current monetary sources for statutory composition. Component declarations
-- are not legal treatment; base-pay treatment and mixed-share rounding must
-- come from the governed adapter, never an inferred tenant exemption.
CREATE FUNCTION payroll.current_earning_sources(p_employee jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE line jsonb;lines jsonb:='[]';amount numeric;taxable numeric:=0;nontaxable numeric:=0;
 base numeric:=0;unresolved numeric:=0;flags integer;parts integer;missing boolean;all_true boolean;all_false boolean;state text;
BEGIN
 IF jsonb_typeof(p_employee->'lines') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION 'payroll_earning_sources_invalid' USING ERRCODE='22023';END IF;
 FOR line IN SELECT value FROM jsonb_array_elements(p_employee->'lines') WHERE value->>'classification'='earning' LOOP
  IF coalesce(line->>'amount','') !~ '^[0-9]+(\.[0-9]+)?$'
    OR jsonb_typeof(line->'details') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'payroll_earning_sources_invalid' USING ERRCODE='22023';END IF;
  amount:=(line->>'amount')::numeric;
  IF amount<>round(amount,2) THEN RAISE EXCEPTION 'payroll_earning_sources_invalid' USING ERRCODE='22023';END IF;
  IF line->>'component'='base' THEN
   base:=base+amount;state:='base_treatment_requires_verified_pack';
  ELSE
   SELECT count(*),count(*) FILTER(WHERE jsonb_typeof(p->'declared_taxable')='boolean'),
     coalesce(bool_and(p->'declared_taxable'='true'::jsonb),false),coalesce(bool_and(p->'declared_taxable'='false'::jsonb),false)
   INTO parts,flags,all_true,all_false FROM jsonb_array_elements(line->'details')p;
   missing:=parts=0 OR parts<>flags;
   IF missing THEN state:='unknown_source_declaration';unresolved:=unresolved+amount;
   ELSIF all_true THEN state:='uniform_declared_taxable';taxable:=taxable+amount;
   ELSIF all_false THEN state:='uniform_declared_nontaxable';nontaxable:=nontaxable+amount;
   ELSE state:='mixed_declarations_require_allocation';unresolved:=unresolved+amount;
   END IF;
  END IF;
  -- Keep saved exact parts, version identities and rational fields intact.
  -- A daily manual total distributed by the salary engine is not evidence of
  -- work on each date. A one-time amount has period scope, not payment-date
  -- or first-day earning attribution.
  lines:=lines||jsonb_build_array(jsonb_build_object('component',line->'component','name',line->'name',
   'amount',line->'amount','declaration_state',state,
   'declared_taxable_amount',CASE WHEN state='uniform_declared_taxable' THEN amount WHEN state='uniform_declared_nontaxable' THEN 0 END,
   'declared_nontaxable_amount',CASE WHEN state='uniform_declared_nontaxable' THEN amount WHEN state='uniform_declared_taxable' THEN 0 END,
   'earning_from',p_employee->'starts_on','earning_until',p_employee->'ends_on',
   'attribution',CASE WHEN line->>'component' LIKE 'adjustment:%' THEN 'approved_period_amount'
     WHEN line->>'component'='base' AND p_employee->>'pay_basis'='daily' THEN 'preserved_daily_source_basis'
     ELSE 'saved_salary_distribution' END,'source_parts',line->'details'));
 END LOOP;
 RETURN jsonb_build_object('contract','cube4-current-earning-sources-v1','operational_complete',p_employee->'gross_complete',
   'base_amount',base,'declared_taxable_components',taxable,'declared_nontaxable_components',nontaxable,
   'unresolved_component_amount',unresolved,'lines',lines,'financially_qualified',false);
END $f$;
REVOKE ALL ON FUNCTION payroll.current_earning_sources(jsonb) FROM PUBLIC,anon,authenticated,service_role;

ALTER FUNCTION payroll.employee_statutory_sources(jsonb,jsonb) RENAME TO employee_statutory_sources_before_current_earnings;
CREATE FUNCTION payroll.employee_statutory_sources(p_manifest jsonb,p_employee jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT payroll.employee_statutory_sources_before_current_earnings(p_manifest,p_employee)
   ||jsonb_build_object('current_earnings',payroll.current_earning_sources(p_employee))
$f$;
REVOKE ALL ON FUNCTION payroll.employee_statutory_sources(jsonb,jsonb),
 payroll.employee_statutory_sources_before_current_earnings(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;anchor text:='''-prior-finals-v1-cumulative-balances-v1''';BEGIN
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_current_earning_sources_engine';END IF;
 EXECUTE replace(definition,anchor,'''-prior-finals-v1-cumulative-balances-v1-current-earnings-v1''');
END $f$;
