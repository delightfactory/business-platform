BEGIN;
DO $$ BEGIN
 IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' THEN RAISE EXCEPTION 'owned QA only'; END IF;
 IF (SELECT count(*) FROM auth.users)<>2 OR EXISTS(SELECT 1 FROM auth.users WHERE id NOT IN ('f9100000-0000-4000-8000-000000000001','f9200000-0000-4000-8000-000000000002')) THEN RAISE EXCEPTION 'synthetic actors only'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='postgres' AND (rolcanlogin OR rolsuper)) OR NOT has_table_privilege('postgres','auth.users','SELECT') THEN RAISE EXCEPTION 'wrong app role'; END IF;
 IF has_any_column_privilege('postgres','auth.users','UPDATE') THEN RAISE EXCEPTION 'unexpected existing update privilege'; END IF;
END $$;
GRANT UPDATE(updated_at) ON auth.users TO postgres;
DO $$ BEGIN
 IF NOT has_column_privilege('postgres','auth.users','updated_at','UPDATE') OR has_column_privilege('postgres','auth.users','encrypted_password','UPDATE') OR has_column_privilege('postgres','auth.users','id','UPDATE') OR has_table_privilege('postgres','auth.users','UPDATE') THEN RAISE EXCEPTION 'incorrect grant'; END IF;
END $$;
COMMIT;
