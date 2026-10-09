-- Owned synthetic configuration only; avoids reading/requesting real device location.
BEGIN;
DO $$ DECLARE tenant uuid:='f5100000-0000-4000-8000-000000000001'; source uuid; snapshot jsonb; BEGIN
IF current_database()<>'business_platform_ux_owned_qa' OR current_user<>'ux_qa_admin' OR (SELECT count(*) FROM auth.users)<>2 THEN RAISE EXCEPTION 'owned synthetic QA only'; END IF;
SELECT id INTO STRICT source FROM time.channel_sources WHERE tenant_id=tenant AND kind='mobile';
PERFORM set_config('request.jwt.claim.sub','f9100000-0000-4000-8000-000000000001',true);
PERFORM public.attendance_channel_save_source(tenant,source,'الحضور من الهاتف','mobile','f5140000-0000-4000-8000-000000000001',true,'{"geofence":false,"retention_seconds":300}'::jsonb,'سياسة اختبار محلي دون قراءة موقع الجهاز');
PERFORM set_config('request.jwt.claim.sub','f9200000-0000-4000-8000-000000000002',true);
snapshot:=public.attendance_mobile_snapshot(tenant);
IF snapshot->>'geofence_required' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'no real device location must be requested'; END IF;
RAISE NOTICE 'LOCAL_POLICY_VERSION % GEOFENCE_FALSE',snapshot->>'policy_version';
END $$;
COMMIT;
