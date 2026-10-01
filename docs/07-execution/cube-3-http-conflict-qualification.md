# Leave deterministic HTTP conflicts — local qualification

## Reproduced defect and change

The actual employee cancellation Server Action remained pending for a stale request version. The local QA PostgREST image is `public.ecr.aws/supabase/postgrest:v14.13`. Database activity showed repeated execution of the cancellation RPC without a blocking PID, and CPU was elevated. The preserved Next log also contains earlier cancellation POSTs taking more than two minutes. No cancellation was committed by the stale attempt.

The authoritative explanation is Supabase's [SQLSTATE 40001 RPC troubleshooting](https://supabase.com/docs/guides/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b): explicitly raising serialization failure causes automatic retries in affected PostgREST versions. A reviewed-version mismatch is a deterministic application conflict.

Migration `20261001090221_cube3_deterministic_conflict_http_status.sql` changes explicit stale-version SQLSTATE assignments to `PT409`, preserving the error messages and HTTP conflict meaning. It targets nine exact Leave function signatures, including half-day preview refresh and the private cancellation command. Existing source definitions are replaced without changing permissions, owner, OID, signatures, security settings, business predicates, lock order or idempotency. Missing targets or missing assignments abort the migration. Historical migrations are retained; actual database serialization failures remain untouched.

This is specifically the Leave boundary. Existing Attendance/operator functions with explicit `40001` are outside this slice and remain follow-up work; this document does not claim platform-wide remediation.

## Executed verification

Only the named local databases were migrated through the normal guarded Supabase CLI chain: authoring `business_platform_cube3_upgrade_qa`, fresh application-chain QA `business_platform_cube3_fresh_qa`, and preserved source-clone upgrade `business_platform_cube3_approval_upgrade_qa`. Fresh and source-clone chains each contain 102 migrations after this change.

- Each qualification database passed **386 pgTAP assertions** across request submission (84), half-day mapping (139), cancellation/reversal (51), latest-event history (65), and atomic approval (47).
- `qa-approval-preservation-compare.mjs slice15` confirms identical function definitions and ACLs on fresh/upgrade and retained full-row hashes for the source's 5 employees, 4 employments and 2 employee links.
- Authenticated `qa-cancellation-http-conflict.mjs` against authoring QA returned HTTP **409**, code **PT409**, unchanged message `leave_request_version_conflict`, in an observed **43ms**. The five-second test deadline bounds this regression check; the measured latency is not a performance SLA.
- A same-payload replay of an already committed cancellation returned HTTP **200** in an observed **29ms**, without changing request detail or history.
- The previously pending browser action recovered to the Arabic stale-version message with the reason retained. A subsequent valid browser submission created one pending cancellation and left the Leave parent approved. Complete employee UI qualification is a separate slice.
- Independent read-only source review passed. `clean-code-guard` found no actionable defect in this focused migration; `test-guard` found no issue in the two expected SQLSTATE updates. `git diff --check` passed.

Commands: the guarded `qa-upgrade-cli.mjs`, `qa-fresh-cli.mjs`, `qa-approval-upgrade-cli.mjs`; `qa-approval-tests.mjs` with the five named SQL files on both qualification databases; `qa-approval-preservation-compare.mjs slice15`; `qa-cancellation-http-conflict.mjs`. External run evidence includes `slice15-function-data-comparison.json`, both pgTAP logs/summaries and `runroot/qa-cancellation-http-conflict.json`. No remote database, deployment or main merge occurred.
