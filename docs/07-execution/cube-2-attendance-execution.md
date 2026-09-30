# Cube 2 — fixed-shift manual attendance slice

Status: first local vertical slice implemented; the remaining Cube 2 Attendance scope is open. Leave belongs to Cube 3.

## Delivered

- `hr.attendance` entitlement and the fixed `attendance.reader.v1`, `attendance.operator.v1`, and `attendance.reviewer.v1` bundles gate the Attendance route and RPCs. Table access remains revoked; SECURITY DEFINER RPCs validate Tenant, entitlement and permission with pinned `search_path`.
- An authorized day open materializes at most 50 Work Instances per page, using an employee-code keyset cursor. A candidate is eligible only when its operational date has begun in that Work Policy version's IANA timezone. Cairo is the UI's default date only; it is not a global server-side cutoff. Opening a day pins Employment, Assignment, policy version and timezone/expected instants. Later People/policy changes do not reinterpret an existing instance.
- Fixed overnight shifts remain one operational day. Local timestamps that are ambiguous or nonexistent under timezone rules fail closed for review rather than being guessed.
- Manual IN/OUT entries are append-only and idempotent by request key and payload. A reviewer with `attendance.correct` can append a missing event only on a review/approved record and must provide a reason; it has a distinct audit event. A manager also must provide a reason when appending to any non-open record. The legacy five-argument entry RPCs are revoked from `authenticated`; the six-argument local-time RPC is the only user-callable append path. Corrections preserve original evidence and require a reason.
- Interpretation produces a bounded `ready` or owned `needs_review` result. An elapsed day with no evidence creates one missing-punch review. Approval is an explicit action producing an immutable, versioned nonfinancial fact. Later evidence/correction marks the instance for review; reapproval preserves the prior fact and links the new version to it.

## Deliberate V1 boundary

This slice supports fixed shifts and manual events only. It does not implement flexible shifts, dated overrides, CSV/device ingestion, absence/late valuation, overtime, leave, bulk exception handling, scheduled work-instance creation, or a Payroll feed/lock check. The fact is not a Payroll input. Before Payroll consumes attendance, the same-transaction Payroll gate must identify locked runs that consumed a prior fact, reject or route changes through an explicit linked correction/amendment, and keep paid ledger entries immutable. No dummy Payroll-lock table is present.

## Evidence

Migrations `20260930102608_cube2_manual_attendance_v1.sql`, `20260930104100_cube2_manual_attendance_integrity.sql`, and `20260930105500_cube2_manual_attendance_review_entries.sql` are local-only changes; all three are applied to local Supabase, and the database was not reset. The integrity migration corrects interpretation, expired-day handling and candidate paging. The final additive migration enforces reasoned entries for every non-open state, revokes the unreasoned five-argument RPCs from `authenticated`, and checks matching idempotency requests before state/reason gates so an in-flight retry survives a state transition. Focused test `supabase/tests/attendance_manual_workflow.test.sql` passed 32 pgTAP assertions for tenant/access denial, bounded day opening, Cairo overnight interpretation, missing-review ownership, reader denial, reasoned reviewer event/audit, request idempotency/conflict, correction/reapproval, immutable source, and DST ambiguity.

`npm run typecheck`, `npm run lint`, `npm run build`, and `git diff --check` passed. No production or remote database was changed.
