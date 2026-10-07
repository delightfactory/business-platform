-- Isolated synthetic PostgreSQL 17.6; run after prerequisite migration only.
-- No auth/provider/employee data. This does NOT qualify full attempt concurrency.
BEGIN;
DO $test$
DECLARE
  id uuid := '017f22e2-79b0-7cc3-98c4-dc0c0c07398f';
  issued bigint := 1645557742000;
  instant timestamptz := pg_catalog.to_timestamp(1645557742);
  role_name text; signature text; privilege_name text;
  generated uuid; before_time timestamptz; after_time timestamptz;
  floor_value bigint;
BEGIN
  -- RFC9562 external vector, not a generated round-trip assertion.
  IF leave.attempt_form_issued_ms(id) IS DISTINCT FROM issued THEN RAISE EXCEPTION 'RFC vector mismatch'; END IF;
  IF NOT leave.attempt_form_is_admissible(id,instant,0) THEN RAISE EXCEPTION 'Admission boundary denied'; END IF;
  IF NOT leave.attempt_form_is_admissible(id,instant+interval '24 hours'-interval '1 millisecond',0)
    THEN RAISE EXCEPTION 'Unexpired window denied'; END IF;
  IF leave.attempt_form_is_admissible(id,instant+interval '24 hours',0)
    THEN RAISE EXCEPTION 'Expired ID admitted'; END IF;
  IF leave.attempt_form_is_admissible(id,instant-interval '1 millisecond',0)
    THEN RAISE EXCEPTION 'Future ID admitted'; END IF;
  IF leave.attempt_form_is_admissible(id,instant+interval '1 hour',issued)
    THEN RAISE EXCEPTION 'Pruned ID resurrected after clock rollback'; END IF;
  IF leave.attempt_form_is_admissible(id,instant,issued+1)
    THEN RAISE EXCEPTION 'Below-watermark ID admitted'; END IF;
  IF leave.attempt_form_is_admissible(NULL,instant,0)
     OR leave.attempt_form_is_admissible(id,NULL,0)
     OR leave.attempt_form_is_admissible(id,instant,NULL)
     OR leave.attempt_form_is_admissible(id,instant,-1)
     OR leave.attempt_form_is_admissible(id,'infinity',0)
     OR leave.attempt_form_is_admissible(id,'-infinity',0)
    THEN RAISE EXCEPTION 'Invalid context admitted'; END IF;
  IF leave.attempt_form_is_admissible('017f22e2-79b0-4cc3-98c4-dc0c0c07398f',instant,0)
     OR leave.attempt_form_is_admissible('017f22e2-79b0-7cc3-78c4-dc0c0c07398f',instant,0)
    THEN RAISE EXCEPTION 'Legacy/wrong-variant ID admitted'; END IF;
  before_time:=clock_timestamp(); generated:=leave.new_attempt_form_id(); after_time:=clock_timestamp();
  IF leave.attempt_form_issued_ms(generated) NOT BETWEEN floor(extract(epoch FROM before_time)*1000)::bigint
    AND floor(extract(epoch FROM after_time)*1000)::bigint
    THEN RAISE EXCEPTION 'Generator did not use DB clock'; END IF;
  IF NOT leave.attempt_form_is_admissible(generated,after_time,0)
    THEN RAISE EXCEPTION 'Generated ID denied'; END IF;
  floor_value:=leave.advance_attempt_prune_floor(issued);
  IF floor_value<>issued OR leave.advance_attempt_prune_floor(issued-1)<>issued
     OR leave.advance_attempt_prune_floor(issued)<>issued
    THEN RAISE EXCEPTION 'Floor decreased or non-idempotent'; END IF;
  BEGIN
    PERFORM leave.advance_attempt_prune_floor(floor(extract(epoch FROM clock_timestamp())*1000)::bigint);
    RAISE EXCEPTION 'Unexpired floor accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN PERFORM leave.advance_attempt_prune_floor(-1); RAISE EXCEPTION 'Negative floor accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN PERFORM leave.advance_attempt_prune_floor(NULL); RAISE EXCEPTION 'Null floor accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
    FOREACH signature IN ARRAY ARRAY['leave.new_attempt_form_id()',
      'leave.attempt_form_issued_ms(uuid)','leave.attempt_form_is_admissible(uuid,timestamp with time zone,bigint)',
      'leave.advance_attempt_prune_floor(bigint)'] LOOP
      IF has_function_privilege(role_name,signature,'EXECUTE') THEN RAISE EXCEPTION 'Unexpected execute % %',role_name,signature; END IF;
    END LOOP;
    FOREACH privilege_name IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE'] LOOP
      IF has_table_privilege(role_name,'leave.attempt_prune_floor',privilege_name)
        THEN RAISE EXCEPTION 'Unexpected floor access % %',role_name,privilege_name; END IF;
    END LOOP;
  END LOOP;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='leave.attempt_prune_floor'::regclass)
    THEN RAISE EXCEPTION 'RLS missing'; END IF;
  IF EXISTS(SELECT 1 FROM pg_proc WHERE oid IN ('leave.new_attempt_form_id()'::regprocedure,
      'leave.attempt_form_issued_ms(uuid)'::regprocedure,'leave.attempt_form_is_admissible(uuid,timestamptz,bigint)'::regprocedure,
      'leave.advance_attempt_prune_floor(bigint)'::regprocedure)
    AND NOT coalesce(proconfig @> ARRAY['search_path=""'],false))
    THEN RAISE EXCEPTION 'search_path contract mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM pg_proc WHERE oid IN ('leave.attempt_form_issued_ms(uuid)'::regprocedure,
      'leave.attempt_form_is_admissible(uuid,timestamptz,bigint)'::regprocedure) AND prosecdef)
    THEN RAISE EXCEPTION 'Pure helpers unexpectedly elevated'; END IF;
  RAISE NOTICE 'PASS: RFC vector, expiry/future/rollback-floor, invalid inputs, DB clock, monotonic floor, role ACL and RLS';
END $test$;
ROLLBACK;
