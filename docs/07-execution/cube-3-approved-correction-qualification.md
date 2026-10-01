# Cube 3 approved Leave correction qualification

Local backend qualification on 2026-10-01 for migration `20261001093604_cube3_leave_approved_replacement.sql`.

## Behavior and invariants

`leave_correct_approved_request` accepts an already-approved original and a separately submitted replacement belonging to the same Tenant, Employee, Employment and Employer. It requires current approval authority, enabled new work, exact request/preview versions and a reason. It reverses the original's exact allocation entries and approves/consumes the replacement in one transaction. Shortage, stale preview, pending cancellation, inactive authority or a conflicting Time fact leaves the original and ledger intact. No approved fact is rewritten.

The original becomes `superseded`; linked immutable correction evidence and the replacement's normal `hr.approved` audit event are written atomically. Mapping-aware preview checks run before and after WorkInstance locks. Header/day mapping fields remain inspectable. Correction chains expose deterministic outbound lineage and ordered inbound history; superseded Payroll projection sources retain identity with zero effective units. Payroll remains projection-only and unconsumed.

All three command streams enforce operation-key exclusivity. The internal correction-approval namespace blocks new caller use while preserving legitimate previously stored request/cancellation replays. Deterministic version conflicts return `PT409`.

## Migration and regression evidence

The final source was applied through the normal CLI migration chain to a rebuilt clean application schema and to a preserved source-clone upgrade, both inside the named local QA container. Each contains 103 migration records. Earlier development failures were repaired before qualification: a PL/pgSQL record/query alias collision and the PostgreSQL 100-argument JSON-builder limit. The rebuilt clean chain required no manual function repair.

`cube3_leave_approved_replacement.test.sql` provides 61 assertions, including exact FIFO reversal and reuse, different-type replacement, shortage and injected-audit rollback, mapped previews, chains/hash identity, permissions, stale/terminal requests, pending cancellation, historical key replay and retained Time evidence. The initial assertion that restored same-type FIFO funds should remain unused was corrected: separate assertions now prove reversal into the exact retained account, reuse by the replacement, and the resulting account balance.

Root ran all 36 Cube3, Attendance and People test files on clean and upgrade QA: 1,464 assertions per target, no failures. Function definitions and ACLs match; five baseline Employees, four Employments and two Employee/User links remain identical to the untouched source database. No production database was targeted.

## Observed concurrency evidence

The externally authored, independently executed `qa-approved-correction-races.mjs` pins loopback 55322, the QA container and `business_platform_cube3_approval_upgrade_qa`. All six controlled races passed:

1. Direct cancellation wins; correction observes cancellation and conflicts.
2. Correction wins; direct cancellation rejects the superseded original.
3. Time approval wins; correction conflicts with the exact committed fact/version.
4. Correction wins; Time approval rejects the newly approved Leave.
5. Pending cancellation creation wins; correction rejects pending cancellation.
6. Correction wins; pending cancellation creation rejects the superseded original.

Each race requires live `wait_event_type=Lock` and a matching `pg_blocking_pids` edge between known sessions before releasing the winner. It asserts exact loser errors, request states/versions, audit/relation/allocation/reversal counts, balance, retained Time facts, exact successful replay and unchanged losing retries. No elapsed sleep substitutes for a barrier.

Independent read-only review inspected both the helper and `result-6215cbfb-1f5f-4171-a125-59fb4ebda1dd.json`, confirming all six barriers and outcomes. This proves these controlled winner orderings, not exhaustive randomized or reconciled half-day contention. Fixture/proof rows are retained in isolated QA.

## Scope still open

The linked correction UI and paired Leave/Time fact correction remain unfinished. This backend retains the existing conservative Time conflict gate; it does not stand in for the required half-day reconciliation. Annual eligibility/calculation, HR record/balance interfaces, final Cube3 closure and Cube4 remain separate required work. No merge, deployment, remote migration or Payroll lock/consumption is claimed.
