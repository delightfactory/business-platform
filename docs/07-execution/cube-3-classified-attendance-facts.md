# Cube 3: reviewed attendance classification

This slice adds explicit approval and correction of settled absence and fully covered Leave days. A mapped half-day without punches records absence 0.5 plus the exact Leave source 0.5. Whole coverage records `leave_covered`, absence 0, and Leave 1. Genuine observed work remains separately preserved; invalid observation evidence cannot be approved through this path.

## API and invariants

`attendance_review_classification(tenant, work_instance)` is read-only. Its tokens identify the current fact and interpretation, current canonical input, source context, and reviewed plan. `attendance_commit_classification` requires all tokens, a reason of 3–500 characters, and an idempotency key of 1–120 characters. Changed current input returns `PT409` (HTTP 409).

Initial approval requires `attendance.approve`; correcting an existing fact also requires `attendance.correct`, with the existing tenant-admin alternative. Current membership, entitlement, and scope are rechecked after locks. The writer locks Employment before Work Instance and does not acquire Leave locks beneath Work Instance.

Each successful operation appends private evidence, an interpretation, a canonical contract-version-2 fact, an audit event, and an immutable operation receipt. Client roles cannot read or write the private evidence/receipt tables. A receipt replays its original result after later successors; changed intent under the same key returns `23505` (HTTP 409). Older facts are retained intact.

Detail preserves history, strips `pay_effect` recursively without `leave.view` or tenant-admin permission, and exposes source reconciliation. The existing bounded Payroll projection includes full-covered days exactly once, with authoritative latest fact identity, nominal Leave/absence quantities, source references, independent observations, and reconciliation status. These quantities are nonfinancial inputs. Leave sources remain reference-only; the Time writer does not consume Leave balances.

## Local qualification

- Normal migration application through 108 on both the previously qualified fresh chain and the retained-data upgrade chain.
- 41 scoped attendance, Leave, and People SQL suites: 1,874 assertions on each database, no failed files. The new classified-fact suite contributes 46 assertions.
- Actual PostgREST: initial commit 200, stale review 409/`PT409`, altered receipt 409/`23505`, exact original replay after an explicit successor, and approve-only correction denied with 403/`42501`. Exactly two committed facts/evidence/receipts remain for the two successful HTTP writes.
- Nine controlled races observe an actual PostgreSQL blocking edge: cancellation, manual punch, replacement, ordinary absence approval, and concurrent classified commits. Both source-first and classified-commit-first orders are exercised where applicable. Stale reviewed commits fail, same-key concurrent requests replay exactly, immutable history is retained, and ordinary replacement keeps its existing fact-conflict refusal.
- Function definitions and ACLs match between fresh/upgrade databases; the original source's five employee, four employment, and two account-link rows retain their complete row digests.
- Independent review: PASS from a fresh read-only reviewer. This used the same provider as the orchestrator, a weaker separation than an external-provider review.

Authoring base: `94ed8f20299172e77ae671a953ddee28c1ba0a33`. Local evidence is recorded outside the repository under the run's `slice25-*` artifacts. No deployment or remote migration is part of this slice.

## Remaining Cube 3 closure

The joint Leave/Time approval, replacement, and cancellation-reconciliation coordinator still needs to discover and lock the complete affected-date union, review prospective context, and append required successors atomically with Leave transitions and one joint receipt. Its HR interface and full user journeys remain required. The current separate cancellation path deliberately exposes pending Time reconciliation, and ordinary replacement remains conservative. Annual entitlement policy and Cube 4 money rules are not resolved by these nonfinancial classifications. This slice does not establish full Cube 3 completion.
