# Cube 3 — prospective configuration recovery and request list qualification

## Corrections

`20261001025105_cube3_leave_configuration_recovery.sql` permits a prospective Calendar/Type revision before an already scheduled version. It resolves the requested effective interval, assigns `max(version)+1`, preserves the next scheduled boundary, and retains historical child snapshots. An expired finite Calendar can resume prospectively without filling its historical gap. Exact-start replacement stays a conflict; it is not a configuration cancellation engine. Existing Leave-Year coverage remains mandatory and a rejected revision rolls back boundaries and audit writes.

`20261001030140_cube3_leave_request_list_summaries.sql` makes own history and HR queues hydrate summaries rather than daily policy evidence. The scoped detail API retains the full daily breakdown. This avoids multiplying a list response by up to 732 dates per item. Permissions, identity checks, pagination and function ACLs are preserved.

## Actual local qualification

- Both isolated QA targets reached **90 migrations** through the normal CLI chain: `business_platform_cube3_fresh_qa` and `business_platform_cube3_upgrade_qa`. No remote target was used.
- Each target passed **159 assertions**: request submission/closure/list payloads (73), prospective recovery (22), configuration integrity (6), calendar/balance foundation (54), and finite-value rejection (4).
- Two real concurrent authenticated races were executed against synthetic QA configuration: Calendar and Type revisions at the same effective start. Session B was observed waiting on the Employer lock; A committed one new version, then B rejected with `23P01`. Each winner appended one created and one superseded audit event. The previously scheduled snapshot remained unchanged, with zero overlapping intervals.
- Function definitions and ACLs matched between creation and upgrade. The original source-clone employees (5), employments (4) and employee links (2) retained their row hashes. Additional concurrency fixtures are synthetic QA data and are recorded separately.
- The list tests preserve the entire 732-date detail while excluding daily evidence from own/HR lists and bounding the fixture history item payload. This is functional payload qualification, not a benchmark of 1,000 companies or 25,000 employees per company.

External evidence is stored under `C:\Users\DELL\AppData\Local\ai-dev-workflow\runs\20261001-cube3-leave`: each target's TAP logs/summaries, `slice3-recovery-function-data-comparison.json`, and `runroot/config-recovery-concurrency-*.json`. Committed identity and source/evidence hashes are recorded separately in the follow-up manifest.

## Limits

These are verified follow-ups to Slice 3A, not full Cube 3 acceptance. Employee/HR interfaces, atomic approval/consumption, cancellation/correction, Attendance reconciliation, annual calculation qualification and Payroll projection remain within the active Cube 3 objective. Physical device acceptance remains deferred by the owner; responsive browser qualification is still required.
