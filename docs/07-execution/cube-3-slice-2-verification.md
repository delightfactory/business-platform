# Cube 3 Slice 2 — calendar and balance foundation verification

Date: 2026-10-01. Branch: `codex/cube3-leave-v1`. Parent: `06fa867a1db6df6e43f780acd93091a25b98cc1b`. This document ships in the implementation commit; external verification manifests record the exact resulting HEAD and file hashes.

## Delivered scope

- Employer-scoped, versioned Leave calendars, weekly rest and holidays, independent of Attendance.
- Explicit employer balance-year periods with continuous calendar coverage and overlap prevention.
- Versioned Leave types: paid/unpaid, tracked/untracked, working/calendar days and permitted half days are independent decisions.
- Employee/type/year balance accounts, immutable opening/grant/adjustment ledger, unique annual grant per account and period regardless of policy version, idempotent posting and nonnegative balances.
- Narrow current-user balance history and permission-scoped HR balance/configuration RPCs with bounded account pagination.
- Audited configuration changes, future-only immutable version boundaries and preservation of existing year-period coverage.

Files: `20261001011428_cube3_leave_calendar_balance_foundation.sql`, `20261001015100_cube3_leave_configuration_integrity.sql`, `20261001020124_cube3_leave_balance_finite_values.sql`, and their three focused pgTAP files under `supabase/tests`.

## Actual checks

PostgreSQL 17.6, Supabase CLI 2.106.0, Node 24.16.0. Only the named local QA databases were migrated.

| Check | Observed result |
|---|---|
| Upgrade QA application history, 83 → 86 migrations | Passed through normal guarded CLI push |
| Fresh application QA chain, through 86 migrations | Passed; Supabase framework Auth/Storage/extensions retained |
| Calendar/balance pgTAP | 54 assertions passed on each database |
| Configuration integrity pgTAP | 6 assertions passed on each database |
| Finite numeric balance regression pgTAP | 4 assertions passed on each database; rejects NaN and both infinities at RPC boundary and NaN at ledger CHECK |
| Final application function definitions and ACL | Fresh and upgrade equal, normalizing line endings |
| Original source-clone data preservation | 5 Employee, 4 Employment and 2 link rows retained with identical ordered row-JSON hashes |
| Two real authenticated connections: calendar revision vs year-period creation | Original function reproduced SQLSTATE 40P01; corrected functions both completed with controlled lock wait |

The concurrency harness holds the Employer lock at the year-period creation seam, invokes the actual revision RPC in a second session, observes its database lock wait, then calls the actual year-period RPC. Both test transactions roll back. The corrected shared order is Employer → Calendar/Type; coverage is rechecked under these locks. This is a reproduced and resolved deadlock, not an inference from source.

A separate authenticated pre-fix reproduction showed `NaN` was accepted by the balance RPC and a privileged ledger insert; both infinity inputs reached numeric overflow instead of the input boundary. All four regression cases now reject as intended. The change adds one finite-value CHECK and one RPC input predicate, preserving the rest of the balance command.

External evidence in the isolated run directory: `calendar-concurrency-prove-original.json`, `calendar-concurrency-verify-fixed.json`, `slice2-function-data-comparison.json`, test logs and CLI logs. Separate synthetic QA identity/calendar fixtures are excluded from comparison of original source IDs; original demo and remote databases were untouched. No production database migration, deployment or merge was performed.

Tests cover authenticated scoping, cross-Tenant denial, duplicate grants across policy revisions, replay/conflicting keys, balance precision and underflow, untracked types, historical balance retention, pagination, disabled-service history, append-only data, finite calendar continuation, preserved holidays, invalid period ends and rollback of revisions that break coverage.

## Scope remaining

This is a database foundation slice, **not Cube 3 closure or a finished Leave interface**. Configuration and ledger interfaces, complete request/approval/cancellation/correction journeys, annual eligibility and availability policy, effective half-day Attendance mapping, approved Attendance conflicts, Payroll facts and final full regression remain subsequent work. The annual grant timing decision requested from the owner remains unresolved; these primitives do not claim to implement a legally qualified annual entitlement calculator. No new JavaScript or user journey was changed in this slice; the complete application build and regression suite remain a final Cube 3 gate.
