# Cube 3 Slice 3A — request submission and closure primitives

## Delivered scope

Employee requests resolve the current authenticated account link on the server, with narrow Leave self permissions. HR can record for an employee without an account. Both paths snapshot effective type, calendar and year-period rules per date; pending requests neither require nor reserve balance. Submission requires an available approval queue. Scoped history/detail, bounded pagination, own withdrawal, separate HR rejection and audited type activation are exposed through authenticated RPCs.

Request facts and events remain immutable. Retry keys bind canonical SHA-256 payloads, including the employee and employment derived from the current link; changing that link cannot replay a previous employee's submission. Closure requires current authority and remains available after Leave entitlement ends. The 732-date per-call ceiling bounds processing; it is not statutory eligibility.

## Verification performed locally

- Applied the normal migration chain to both isolated QA targets: `business_platform_cube3_fresh_qa` and `business_platform_cube3_upgrade_qa`, each now at 88 migrations. The latter retains the Cube 1/2 source-clone data. No remote migrations were applied.
- Ran `qa-tests.mjs` against each target for `cube3_leave_request_submission.test.sql`, `cube3_leave_calendar_balance_foundation.test.sql`, `cube3_leave_configuration_integrity.test.sql`, and `cube3_leave_balance_finite_values.test.sql`: **133 assertions per target, zero failures** (69 request assertions plus 64 foundation regressions).
- Compared function definitions and ACLs between both paths: identical. The five original employees, four employments and two account links retained their source-clone row hashes.
- Reproduced an Employee/Employment deadlock between an authenticated balance command and a controlled Attendance foreign-key insertion. Migration `20261001023454_cube3_leave_attendance_lock_integrity.sql` changes only the balance command's Employee lock to `FOR NO KEY UPDATE`, preserving its definition and ACL otherwise. After the fix, both operations completed, with the intended Employment wait and no deadlock. Both test operations were rolled back. This checks the foreign-key seam, **not** an end-to-end Attendance import.
- Initial migration compilation failures rolled back completely. Their SQL syntax was repaired before successful application; test fixture/TAP errors were repaired before the passing runs.

The external evidence directory is `C:\Users\DELL\AppData\Local\ai-dev-workflow\runs\20261001-cube3-leave`. It holds each target's TAP transcripts and summaries, `slice3-function-data-comparison.json`, and `runroot/attendance-employment-lock-{prove-original,verify-fixed}.json`. The final committed source identity and hashes are recorded in `slice3-final-manifest.json` after the commit and focused recheck.

## Remaining Cube 3 work

This slice is a backend checkpoint, not full Cube 3 closure. It does not implement approval/consumption, cancellation/reversal, corrections, complete employee/HR interfaces, Attendance reconciliation, or Payroll facts. Half-day balance quantity is supported; clock mapping is not inferred. Automatic annual grant timing remains subject to the recorded product decision. Prospective configuration recovery is a separate verified follow-up. Browser and complete-suite qualification are required for the cohesive final candidate; physical device acceptance remains deferred by the owner.
