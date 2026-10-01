# Cube 3 — cancellation and exact reversal qualification

## Delivered scope

An employee requests cancellation of approved Leave through `leave_my_request_cancellation`; the approved request and consumption remain effective until HR accepts. A rejected cancellation remains in history and a fresh attempt may be submitted. HR can initiate an attempt for an employee without an account. New attempts require an active approver; unchanged retries replay before that coverage check.

`leave.approve` separately permits acceptance, rejection and direct cancellation of an approved request. `leave.manage` permits initiation only. Every decision records actor, reason, time and versions. Own-only request/history APIs enforce the current employee link even for callers with HR roles. Internal helpers and tables are inaccessible to client roles.

Acceptance/direct cancellation preserves the original approval and preview. Each original consumption receives one immutable, exactly matching positive reversal in its original balance account and period. Partial FIFO allocations across retained and current balances return to those same accounts. A canonical caller operation key is checked across request and cancellation event streams before mutation and reused for the linked audit records; there is no derived key that a caller can preoccupy to prevent closure.

Existing obligations can close after People/Leave entitlement disable; active tenant, membership and permissions remain required. Closure captures existing authoritative Time fact IDs/versions and reports a reconciliation requirement without altering Attendance. No financial period guard is claimed.

## Local evidence

- Supabase CLI 2.106.0 applied migration `20261001030800` normally to isolated local QA databases only.
- `business_platform_cube3_fresh_qa` and `business_platform_cube3_approval_upgrade_qa` both reached 94 migrations. The latter is a normal upgrade of the 82-migration source clone.
- `cube3_leave_cancellation.test.sql`: **51 assertions passed on each path**. These include separate approval permissions, accountless HR operation, pending/rejected/accepted/direct states, mixed-role own-route isolation, queue coverage, disabled service closure, cross-stream key conflicts, a 120-character key, retained fractional allocation restoration and repeat protection.
- Focused regressions on each path: **47 approval assertions and 84 request/scope assertions passed** after the cancellation migration. The later cancellation fixture expansion changed no production SQL or regression tests.
- Function definitions and ACLs matched across fresh/upgrade paths. The source clone's 5 employee, 4 employment and 2 link rows retained their complete row hashes.
- Qualification commands/logs and source hashes are bound to the committed slice by the local `slice6` evidence manifest. No remote migration, PR, main merge or deployment occurred.

The first test attempt tried to mutate an immutable role snapshot; its fixture was corrected to deactivate/reactivate the approver membership. A subsequent disabled-service assertion used an approval-only actor; it was corrected to use the authorized recording actor. Neither failure required changing production behavior.

## Remaining gates

This is a backend slice. Cancellation UI/browser verification, reciprocal Leave/Time races, explicit Attendance reconciliation, correction/replacement, half-day mapping and automatic entitlement policy qualification remain separate requirements. The full database, JavaScript, lint and build gates will run on the final Cube 3 candidate. This document does not close Cube 3 or qualify Cube 4.
