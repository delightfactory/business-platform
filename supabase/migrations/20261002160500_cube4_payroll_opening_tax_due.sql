-- Preserve prior assessed tax independently from money actually withheld.
-- Missing tax_due remains unknown; no existing YTD history is backfilled.
DO $migration$
DECLARE definition text; keys_anchor text := '''taxable_earnings'',''tax_withheld'',''social_base''';
BEGIN
 SELECT pg_get_functiondef('payroll.validate_input(text,jsonb)'::regprocedure) INTO definition;
 IF strpos(definition, keys_anchor) = 0
   OR strpos(definition, ' IF p_kind=''opening_ytd'' THEN') = 0
   OR strpos(definition, 'tax_due') <> 0 THEN
  RAISE EXCEPTION 'unexpected_opening_ytd_validator';
 END IF;
 -- Change only the allow-list; the existing required-money list stays intact.
 definition := overlay(definition placing '''taxable_earnings'',''tax_withheld'',''tax_due'',''social_base'''
   from strpos(definition, keys_anchor) for length(keys_anchor));
 definition := replace(definition, ' IF p_kind=''opening_ytd'' THEN', $validation$
 IF p_kind='opening_ytd' AND p_data ? 'tax_due' THEN
  IF jsonb_typeof(p_data->'tax_due') NOT IN ('string','number')
    OR COALESCE(p_data->>'tax_due','') !~ '^[0-9]+(\.[0-9]{1,2})?$' THEN
   RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
  END IF;
  IF (p_data->>'tax_due')::numeric > 999999999999.99 THEN
   RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
  END IF;
 END IF;
 IF p_kind='opening_ytd' THEN$validation$);
 EXECUTE definition;
END $migration$;

COMMENT ON FUNCTION payroll.validate_input(text,jsonb) IS
 'Validates reviewed payroll inputs. Opening YTD tax_due is prior assessed tax, distinct from tax_withheld; absence is unknown, never inferred or backfilled.';
