# Cancellation history status — local qualification

`20261001031300` adds `latest_event` to the existing scoped history response independently of the requested page. It returns the same event shape or JSON null. This lets the UI determine the current cancellation status with one bounded call instead of scanning an arbitrary number of oldest history pages.

The history authorization/paging body, signature and grants are preserved. `leave_my_cancellation_history` remains unchanged and continues enforcing the current employee link, including mixed HR/self roles. The existing tenant/request/event index supports the latest-event lookup. No history is changed, and no permission is broadened.

## Executed verification

Supabase CLI 2.106.0 applied the normal chain to isolated authoring, fresh application-chain and preserved source-clone upgrade QA. Node 24.16.0 / PostgreSQL 17.6.

- Authoring: 65 focused pgTAP assertions passed.
- Fresh and source-clone upgrade: each passed 116 assertions across latest-event history (65) and cancellation/reversal regression (51).
- The fixture appends 205 historical rejected attempts, then exercises actual authenticated pending, rejection and acceptance calls. First, middle and empty pages all expose the latest event. Empty history, current-link/own scope, mixed-role denial and disabled-service history reads are covered.
- Both target chains contain 101 migrations. Function definitions and ACLs match; baseline full-row digests for 5 employees, 4 employments and 2 account links remain preserved against the untouched source.
- Commands/logs: `qa-tests.mjs`, both target `qa-approval-tests.mjs`, `qa-approval-preservation-compare.mjs slice14`; local comparison artifact `slice14-function-data-comparison.json`. Tests precede this commit; no production SQL/test changes followed the passing run.

UI changes consuming this field are separate uncommitted work and still require browser qualification. This backend slice does not close Cube 3 or authorize a main merge/deployment.
