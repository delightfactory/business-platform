-- UNEXECUTED PROPOSAL: fresh explicit owner approval required after reported refusal.
-- Dedicated QA Auth ownership only; role membership/CREATE prerequisites removed
-- in the same atomic transaction before COMMIT. No LOGIN/password/SUPERUSER change.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
DO $guard$
BEGIN
 IF current_database()<>'business_platform_ux_c93f09f_qa' OR current_user<>'postgres' THEN RAISE EXCEPTION 'wrong_database_or_actor'; END IF;
 IF EXISTS(SELECT 1 FROM auth.users) OR EXISTS(SELECT 1 FROM auth.sessions) OR EXISTS(SELECT 1 FROM auth.refresh_tokens) THEN RAISE EXCEPTION 'expected_empty_auth'; END IF;
 IF EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid()) THEN RAISE EXCEPTION 'qa_must_be_disconnected'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ux_c93f_auth' AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole) THEN RAISE EXCEPTION 'expected_disabled_qa_auth_role'; END IF;
 IF (SELECT pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname='auth')<>'postgres' THEN RAISE EXCEPTION 'expected_original_auth_owner'; END IF;
 IF has_database_privilege('ux_c93f_auth',current_database(),'CREATE') THEN RAISE EXCEPTION 'unexpected_prior_create'; END IF;
 IF (SELECT count(*) FROM pg_auth_members a JOIN pg_roles r ON r.oid=a.roleid JOIN pg_roles m ON m.oid=a.member WHERE r.rolname='ux_c93f_auth' AND m.rolname='postgres')<>1 THEN RAISE EXCEPTION 'unexpected_membership_count'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_auth_members a JOIN pg_roles r ON r.oid=a.roleid JOIN pg_roles m ON m.oid=a.member JOIN pg_roles g ON g.oid=a.grantor WHERE r.rolname='ux_c93f_auth' AND m.rolname='postgres' AND g.rolname='supabase_admin' AND a.admin_option AND NOT a.inherit_option AND NOT a.set_option) THEN RAISE EXCEPTION 'unexpected_membership_options'; END IF;
END $guard$;
-- Snapshot only non-Auth QA function contracts; no credentials or row values.
SELECT set_config('ux_qa.application_function_digest',(SELECT md5(string_agg(pg_get_functiondef(p.oid),E'\n' ORDER BY p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname NOT IN ('auth','pg_catalog','information_schema') AND p.prokind='f'),true);
-- Separate grantor identity preserves the original supabase_admin membership.
GRANT ux_c93f_auth TO postgres WITH ADMIN FALSE, INHERIT FALSE, SET TRUE GRANTED BY postgres;
GRANT CREATE ON DATABASE business_platform_ux_c93f09f_qa TO ux_c93f_auth;
ALTER SCHEMA auth OWNER TO ux_c93f_auth;
DO $ownership$
DECLARE item record;
BEGIN
 FOR item IN SELECT c.relname,c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='auth' AND c.relkind IN ('r','p','S','v','m') ORDER BY c.relkind='S', c.oid LOOP
  EXECUTE format('ALTER %s auth.%I OWNER TO ux_c93f_auth',CASE item.relkind WHEN 'S' THEN 'SEQUENCE' WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW' ELSE 'TABLE' END,item.relname);
 END LOOP;
 FOR item IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='auth' AND p.prokind='f' LOOP
  EXECUTE format('ALTER FUNCTION %s OWNER TO ux_c93f_auth',item.signature);
 END LOOP;
 FOR item IN SELECT t.typname FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='auth' AND t.typtype='e' LOOP
  EXECUTE format('ALTER TYPE auth.%I OWNER TO ux_c93f_auth',item.typname);
 END LOOP;
END $ownership$;

-- Remove ONLY the newly added membership, not the original supabase_admin grant.
REVOKE ux_c93f_auth FROM postgres GRANTED BY postgres RESTRICT;
REVOKE CREATE ON DATABASE business_platform_ux_c93f09f_qa FROM ux_c93f_auth RESTRICT;
DO $verify$
BEGIN
 IF has_database_privilege('ux_c93f_auth',current_database(),'CREATE') THEN RAISE EXCEPTION 'create_cleanup_failed'; END IF;
 IF (SELECT count(*) FROM pg_auth_members a JOIN pg_roles r ON r.oid=a.roleid JOIN pg_roles m ON m.oid=a.member WHERE r.rolname='ux_c93f_auth' AND m.rolname='postgres')<>1 OR NOT EXISTS(SELECT 1 FROM pg_auth_members a JOIN pg_roles r ON r.oid=a.roleid JOIN pg_roles m ON m.oid=a.member JOIN pg_roles g ON g.oid=a.grantor WHERE r.rolname='ux_c93f_auth' AND m.rolname='postgres' AND g.rolname='supabase_admin' AND a.admin_option AND NOT a.inherit_option AND NOT a.set_option) THEN RAISE EXCEPTION 'membership_cleanup_failed'; END IF;
 IF current_setting('ux_qa.application_function_digest') IS DISTINCT FROM (SELECT md5(string_agg(pg_get_functiondef(p.oid),E'\n' ORDER BY p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname NOT IN ('auth','pg_catalog','information_schema') AND p.prokind='f') THEN RAISE EXCEPTION 'application_contract_changed'; END IF;
 IF (SELECT pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname='auth')<>'ux_c93f_auth' THEN RAISE EXCEPTION 'auth_owner_transfer_incomplete'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ux_c93f_auth' AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole)) THEN RAISE EXCEPTION 'qa_role_boundary_changed'; END IF;
END $verify$;
COMMIT;
