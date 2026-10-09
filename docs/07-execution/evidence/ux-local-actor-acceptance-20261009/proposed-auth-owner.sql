-- PROPOSAL ONLY: not executed. Requires owner approval after reported 42501.
-- Scope: Auth objects in the empty, isolated current-source QA database only.
-- No LOGIN, password, superuser, application-object or shared database changes.
BEGIN;
DO $guard$
BEGIN
 IF current_database()<>'business_platform_ux_c93f09f_qa' THEN RAISE EXCEPTION 'wrong_database'; END IF;
 IF EXISTS(SELECT 1 FROM auth.users) OR EXISTS(SELECT 1 FROM auth.sessions) THEN RAISE EXCEPTION 'expected_empty_auth'; END IF;
 IF EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid()) THEN RAISE EXCEPTION 'qa_must_be_disconnected'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ux_c93f_auth' AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole) THEN RAISE EXCEPTION 'expected_disabled_qa_auth_role'; END IF;
END $guard$;
ALTER SCHEMA auth OWNER TO ux_c93f_auth;
DO $ownership$
DECLARE item record;
BEGIN
 FOR item IN SELECT c.relname,c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='auth' AND c.relkind IN ('r','p','S','v','m') LOOP
  EXECUTE format('ALTER %s auth.%I OWNER TO ux_c93f_auth',CASE item.relkind WHEN 'S' THEN 'SEQUENCE' WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW' ELSE 'TABLE' END,item.relname);
 END LOOP;
 FOR item IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='auth' AND p.prokind='f' LOOP
  EXECUTE format('ALTER FUNCTION %s OWNER TO ux_c93f_auth',item.signature);
 END LOOP;
 FOR item IN SELECT t.typname FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='auth' AND t.typtype='e' LOOP
  EXECUTE format('ALTER TYPE auth.%I OWNER TO ux_c93f_auth',item.typname);
 END LOOP;
END $ownership$;
COMMIT;
