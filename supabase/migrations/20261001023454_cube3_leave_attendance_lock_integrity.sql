-- Employee identity is unchanged by balance posting. NO KEY UPDATE still serializes
-- Employee writers while permitting Attendance's Employee FK KEY SHARE after its
-- Employment lock, avoiding the reproduced Employee/Employment lock cycle.
DO $f$
DECLARE
  definition text := pg_catalog.pg_get_functiondef(
    'public.leave_post_balance(uuid,uuid,uuid,uuid,uuid,text,numeric,uuid,text,text,text)'::regprocedure);
  needle text := 'FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee FOR UPDATE;';
BEGIN
  IF pg_catalog.strpos(definition,needle)=0
     OR (pg_catalog.length(definition)-pg_catalog.length(pg_catalog.replace(definition,needle,'')))
          <>pg_catalog.length(needle) THEN
    RAISE EXCEPTION 'unexpected_leave_balance_employee_lock_definition';
  END IF;
  EXECUTE pg_catalog.replace(definition,needle,
    'FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee FOR NO KEY UPDATE;');
END $f$;
