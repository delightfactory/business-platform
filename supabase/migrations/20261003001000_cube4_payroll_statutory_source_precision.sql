-- Actual operational candidate lines may retain trailing zero scale from exact
-- rational arithmetic. Accept that representation without changing a saved
-- amount or permitting fractional cents in the statutory composition worker.
DO $f$
DECLARE definition text; old text:='''^[0-9]+(\.[0-9]{1,2})?$'''; replacement text:='''^[0-9]+(\.[0-9]{1,2}0*)?$''';
BEGIN
 definition:=pg_get_functiondef('payroll.calculate_statutory_employee(jsonb,uuid,jsonb,jsonb)'::regprocedure);
 IF (length(definition)-length(replace(definition,old,'')))/length(old)<>2 THEN
  RAISE EXCEPTION 'unexpected_statutory_worker_precision_contract';
 END IF;
 EXECUTE replace(definition,old,replacement);
END $f$;
