-- A stale reviewed version is a deterministic business conflict, not a database
-- serialization failure. PostgREST 14 retries user-raised 40001 indefinitely.
-- Preserve each current function body, signature, security settings and ACL;
-- replace only its explicit SQLSTATE assignment for these existing CAS errors.
DO $migration$
DECLARE
  signature text;
  function_oid oid;
  definition text;
  updated_definition text;
BEGIN
  FOREACH signature IN ARRAY ARRAY[
    'leave.request_cancellation_internal(uuid,uuid,integer,text,text,boolean)',
    'public.leave_approve_request(uuid,uuid,integer,integer,text,text)',
    'public.leave_cancel_approved_request(uuid,uuid,integer,text,text)',
    'public.leave_decide_cancellation(uuid,uuid,integer,text,text,text)',
    'public.leave_hr_refresh_halfday_preview(uuid,uuid,integer,text,text,text)',
    'public.leave_my_refresh_halfday_preview(uuid,uuid,integer,text,text,text)',
    'public.leave_refresh_request_preview(uuid,uuid,integer,text,text)',
    'public.leave_reject_request(uuid,uuid,integer,text,text)',
    'public.leave_withdraw_own_request(uuid,uuid,integer,text,text)'
  ] LOOP
    function_oid := pg_catalog.to_regprocedure(signature);
    IF function_oid IS NULL THEN
      RAISE EXCEPTION 'leave_conflict_function_missing: %', signature;
    END IF;
    definition := pg_catalog.pg_get_functiondef(function_oid);
    updated_definition := pg_catalog.regexp_replace(
      definition, '(ERRCODE[[:space:]]*=[[:space:]]*)''40001''', '\1''PT409''', 'gi');
    IF updated_definition = definition THEN
      RAISE EXCEPTION 'leave_conflict_assignment_missing: %', signature;
    END IF;
    EXECUTE updated_definition;
  END LOOP;
END
$migration$;

NOTIFY pgrst, 'reload schema';
