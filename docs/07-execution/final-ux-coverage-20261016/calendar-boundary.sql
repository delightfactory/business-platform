BEGIN READ ONLY;
SELECT 'foreign_saved_instances='||count(*) FROM time.work_instances WHERE tenant_id='444dbbab-b569-47ca-beae-2bacbce266c6' AND operational_date>='2026-10-01' AND operational_date<'2026-11-01';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','64b1a759-4660-4f6c-ad93-c4afbc27bc09',true);
SELECT 'own_days='||jsonb_array_length(public.attendance_month_calendar('a21c4ddf-83f8-4851-abc6-2e226c65a661','2026-10-01')->'days');
DO $block$
BEGIN
  BEGIN
    PERFORM public.attendance_month_calendar('444dbbab-b569-47ca-beae-2bacbce266c6','2026-10-01');
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'attendance_view_forbidden' THEN RAISE; END IF;
    RAISE NOTICE 'PASS real foreign tenant calendar denied 42501';
    RETURN;
  END;
  RAISE EXCEPTION 'FAIL foreign tenant read unexpectedly succeeded';
END
$block$;
ROLLBACK;
