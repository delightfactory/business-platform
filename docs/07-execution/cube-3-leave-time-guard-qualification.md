# Cube 3 — reciprocal Leave/Time guard qualification

## Implemented boundary

`platform_private.approved_leave_conflicts_with_work_instance` reads the approved preview's eligible dates for the exact tenant, employee, employment and operational date. It ignores service entitlement state so disabling Leave cannot make an existing obligation disappear. It acquires no Leave-request locks and is inaccessible to client roles.

Manual worked-fact approval, absence approval and absence correction check this guard after their existing Work Instance lock. Automatic clean approval withholds conflicting days. Bulk approval preserves the dedicated `leave_conflict_review_required` item reason and locks instances in operational-date/ID order. The attendance interface has explicit Arabic conflict feedback; unknown save failures ask the user to reload and verify instead of claiming no commit occurred.

The migration replaces exact qualified function anchors with fail-closed occurrence checks. Existing signatures, security properties and grants remain unchanged. Leave's existing approval check already rejects a committed Attendance fact; this slice closes the reciprocal path. It does not convert 0.5 Leave units into clock time or reconcile historical conflicts.

## Executed local gates

- Supabase CLI 2.106.0 applied `20261001030900` normally to isolated QA only. Fresh and source-clone upgrade paths both reached **95 migrations**.
- Each path passed **301 assertions across seven files**: reciprocal guard (18), Leave approval (47), manual Attendance (110), automatic approval (31), bulk review (21), People/Attendance temporal integrity (18) and CSV import (56).
- A guarded Node/pg harness on `business_platform_cube3_upgrade_qa` used real public configuration, employee, assignment, punch, Leave approval and Attendance approval RPCs. A fresh synthetic tenant kept the browser tenant's Attendance setting intact.
- **Leave-first:** actual Leave approval held the Work Instance until commit; the second session's Attendance approval was observed waiting via `pg_blocking_pids`, then rejected with `23514 / leave_conflict_review_required`. Final state: approved Leave, zero Attendance facts.
- **Time-first:** actual Attendance approval held the Work Instance until commit; the second session's Leave approval was observed waiting, then rejected with `23514 / leave_attendance_fact_conflict`. Final state: pending Leave, exactly one Attendance fact.
- Race run ID: `6da3e514-5049-4063-a06d-67c3b21d95f4`. Local `runroot/qa-leave-time-concurrency-result.json` records fixture IDs, backend PIDs, observed blocking edges, results and final state. SQL text was masked to the observer; RPC identity is established by the issued calls and their correlated backend PIDs, not by claiming visible query text.
- Function definitions/ACLs matched across fresh/upgrade paths; the source clone's 5 employees, 4 employments and 2 links retained complete row hashes. `npm run typecheck` and scoped ESLint passed for the three attendance UI files.
- The `slice7` manifest binds committed source hashes to local reports and race evidence. No remote migration, main merge or deployment occurred.

Initial harness attempts stopped at QA prerequisites: the browser tenant had Attendance disabled, and an authenticated role could not set privileged `deadlock_timeout`. The harness now creates its own synthetic tenant and sets the timeout before switching role. These were harness corrections; production behavior was unchanged.

## Remaining acceptance

The conservative guard requires explicit review for any covered Leave day. Half-day mapping, permitted worked/absent remainder, explicit correction and nonfinancial Payroll reconciliation are still required before Cube 3 closure. Attendance conflict browser feedback and the final full candidate build/test gates remain pending. This is not a financial-period lock and does not qualify Payroll consumption.
