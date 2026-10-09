-- PROPOSAL ONLY: not executed. Fresh independent owned Docker QA only.
-- Apply after Auth ownership setup, before GoTrue/user creation or any app request.
-- Never apply to shared supabase_db_business-platform or its QA database.
BEGIN;
DO $guard$
BEGIN
 IF current_database() <> 'business_platform_ux_owned_qa'
 OR current_user <> 'ux_qa_admin'
 OR NOT (SELECT rolsuper FROM pg_roles WHERE rolname=current_user)
 OR NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='auth' AND nspowner='ux_c93f_auth'::regrole)
 OR EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('postgres','ux_c93f_auth','ux_c93f_rest') AND (rolcanlogin OR rolsuper))
 OR EXISTS (SELECT 1 FROM auth.users)
 OR EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid())
 THEN RAISE EXCEPTION 'owned_qa_setup_preconditions_failed'; END IF;
END $guard$;
-- postgres is the unchanged NOLOGIN application SECURITY DEFINER owner.
-- Restore only the Auth read/function access lost on ownership transfer.
-- No grant to anon/authenticated, no SET ROLE membership, no owner/RLS change.
GRANT USAGE ON SCHEMA auth TO postgres;
GRANT SELECT ON TABLE auth.users TO postgres;
GRANT EXECUTE ON FUNCTION auth.uid(),auth.jwt(),auth.role(),auth.email() TO postgres;
DO $verify$
BEGIN
 IF NOT has_schema_privilege('postgres','auth','USAGE')
 OR NOT has_table_privilege('postgres','auth.users','SELECT')
 OR NOT has_function_privilege('postgres','auth.uid()','EXECUTE')
 OR NOT has_function_privilege('postgres','auth.jwt()','EXECUTE')
 OR NOT has_function_privilege('postgres','auth.role()','EXECUTE')
 OR NOT has_function_privilege('postgres','auth.email()','EXECUTE')
 THEN RAISE EXCEPTION 'owned_qa_auth_read_setup_incomplete'; END IF;
END $verify$;
COMMIT;
