-- Only expired precise location evidence is removed; attendance history stays intact.
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'business-platform-location-retention',
  '*/5 * * * *',
  'SELECT time.purge_expired_channel_location();'
);

-- Bound this application's scheduler logs without changing unrelated jobs.
SELECT cron.schedule(
  'business-platform-cron-history-retention',
  '17 2 * * *',
  $command$
    DELETE FROM cron.job_run_details
    WHERE end_time < now() - interval '30 days'
      AND jobid IN (
        SELECT jobid FROM cron.job
        WHERE jobname IN (
          'business-platform-location-retention',
          'business-platform-cron-history-retention'
        )
      );
  $command$
);

-- Private Auth readiness state is accessed through trusted functions only.
ALTER TABLE platform_private.platform_auth_password_readiness ENABLE ROW LEVEL SECURITY;
