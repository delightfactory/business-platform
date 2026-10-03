-- Private arithmetic only. Caller supplies one already-selected marginal schedule.
-- No legal column selection, exemption, annualization, rounding order or pack activation.
CREATE FUNCTION payroll.progressive_annual_arithmetic(p_base numeric, p_bands jsonb)
RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE
  band jsonb;
  band_count integer;
  band_number integer := 0;
  lower_bound numeric := 0;
  upper_bound numeric;
  rate numeric;
  width numeric;
  amount numeric;
  total numeric := 0;
  segments jsonb := '[]'::jsonb;
BEGIN
  IF p_base IS NULL OR p_base::text IN ('NaN', 'Infinity', '-Infinity') OR p_base < 0
    OR p_bands IS NULL OR jsonb_typeof(p_bands) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'payroll_arithmetic_input_invalid' USING ERRCODE = '22023';
  END IF;
  band_count := jsonb_array_length(p_bands);
  IF band_count NOT BETWEEN 1 AND 32 THEN
    RAISE EXCEPTION 'payroll_arithmetic_input_invalid' USING ERRCODE = '22023';
  END IF;

  -- Validate every band, including bands above this base: a zero base does not
  -- make an invalid schedule acceptable. Only numeric JSON values are admitted.
  FOR band IN SELECT value FROM jsonb_array_elements(p_bands) LOOP
    band_number := band_number + 1;
    IF jsonb_typeof(band) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'payroll_arithmetic_input_invalid' USING ERRCODE = '22023';
    END IF;
    IF NOT (band ? 'upper' AND band ? 'rate')
      OR (SELECT count(*) FROM jsonb_object_keys(band)) <> 2
      OR jsonb_typeof(band->'rate') IS DISTINCT FROM 'number'
      OR jsonb_typeof(band->'upper') NOT IN ('number', 'null') THEN
      RAISE EXCEPTION 'payroll_arithmetic_input_invalid' USING ERRCODE = '22023';
    END IF;
    rate := (band->>'rate')::numeric;
    upper_bound := (band->>'upper')::numeric;
    IF rate::text IN ('NaN', 'Infinity', '-Infinity') OR rate < 0 OR rate > 1
      OR (band_number = band_count AND upper_bound IS NOT NULL)
      OR (band_number < band_count AND upper_bound IS NULL)
      OR (upper_bound IS NOT NULL AND
        (upper_bound::text IN ('NaN', 'Infinity', '-Infinity') OR upper_bound <= lower_bound)) THEN
      RAISE EXCEPTION 'payroll_arithmetic_input_invalid' USING ERRCODE = '22023';
    END IF;

    width := greatest(least(p_base, COALESCE(upper_bound, p_base)) - lower_bound, 0);
    amount := width * rate;
    total := total + amount;
    segments := segments || jsonb_build_array(jsonb_build_object(
      'band', band_number, 'lower', lower_bound, 'upper', upper_bound,
      'rate', rate, 'taxable_width', width, 'unrounded_tax', amount));
    lower_bound := COALESCE(upper_bound, lower_bound);
  END LOOP;
  RETURN jsonb_build_object('base', p_base, 'unrounded_annual_tax', total, 'segments', segments);
END
$function$;

CREATE FUNCTION payroll.floor_annual_base_to_ten(p_base numeric)
RETURNS numeric
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE whole numeric;
BEGIN
  IF p_base IS NULL OR p_base::text IN ('NaN', 'Infinity', '-Infinity') OR p_base < 0 THEN
    RAISE EXCEPTION 'payroll_arithmetic_input_invalid' USING ERRCODE = '22023';
  END IF;
  -- Avoid division precision rounding near a ten-unit boundary.
  whole := floor(p_base);
  RETURN whole - mod(whole, 10);
END
$function$;

REVOKE ALL ON FUNCTION payroll.progressive_annual_arithmetic(numeric, jsonb),
  payroll.floor_annual_base_to_ten(numeric) FROM PUBLIC, anon, authenticated, service_role;
