BEGIN;
SELECT plan(9);

SELECT is(time.resolve_local('2026-10-18 09:00','Africa/Cairo'), '2026-10-18 06:00+00'::timestamptz, 'Cairo normal local time keeps its UTC instant');
SELECT is(time.resolve_local('2026-04-24 00:30','Africa/Cairo'), NULL::timestamptz, 'Cairo spring gap remains rejected');
SELECT is(time.resolve_local('2026-10-29 23:30','Africa/Cairo'), NULL::timestamptz, 'Cairo autumn overlap remains rejected');
SELECT is(time.resolve_local('2026-10-18 09:00','UTC'), '2026-10-18 09:00+00'::timestamptz, 'other valid zones keep the catalog path');
SELECT is(time.resolve_local('2026-11-01 01:30','America/New_York'), NULL::timestamptz, 'other-zone overlap remains rejected');
SELECT is(time.resolve_local('2026-10-18 09:00','Not/AZone'), NULL::timestamptz, 'invalid zones remain rejected');
SELECT is(time.resolve_local('2026-10-18 09:00',NULL), NULL::timestamptz, 'missing zones remain rejected');
SELECT ok(NOT has_function_privilege('authenticated','time.resolve_local(timestamp,text)','EXECUTE'), 'tenant sessions cannot invoke the private resolver directly');
SELECT ok(NOT has_function_privilege('anon','time.resolve_local(timestamp,text)','EXECUTE'), 'anonymous sessions cannot invoke the private resolver directly');

SELECT * FROM finish();
ROLLBACK;
