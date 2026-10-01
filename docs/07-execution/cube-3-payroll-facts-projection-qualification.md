# Cube3 Leave payroll-facts projection qualification

## Purpose and boundary

Expose a bounded, authenticated snapshot of Leave days that were approved at some point. This is a nonfinancial source projection only. It does not calculate pay, create payroll periods, reserve or consume payroll, mark a fact exported, or change Leave/Time state. Pending requests are absent. A source remains visible after cancellation so downstream reconciliation can see the original approval and its reversal.

## RPC

`public.leave_payroll_facts(p_tenant, p_employer, p_from, p_to, p_after_date, p_after_request_id, p_limit)` returns `{items, limit, has_more, next_after_date, next_after_request_id}`. Dates are explicit and inclusive, `p_to - p_from <= 30` (at most 31 calendar dates), and page size is 1–100. Paging uses the stable tuple `(leave_date, request_id)`; both cursor components must be present together. Employer and date scope are mandatory.

Authorization is one of `leave.view`, `leave.manage`, or `leave.approve`, checked with active tenant, membership, and user authority through `leave.authorized(..., false)`. Historical reads remain available when the People/Leave entitlement is disabled, but actor authority must still be active. An exact tenant/employer match is required. There is no self-service or broad People-directory access. The RPC is executable by `authenticated` only; underlying snapshots remain private.

## Source shape and identity

Each item represents one row in the approved immutable request preview, keyed by `(request_id, approved_preview_version, leave_date)`. `source_key` expresses those fields for downstream deduplication. The item preserves employee, employment, employer, leave type, year period, calendar/type versions, request version, approval preview version, approval actor and timestamp, day-count basis, pay effect, balance mode, eligibility, holiday/rest classification, half-day flag, and original approved units. The `source_version` and `source_version_hash` describe the currently visible Leave state; repeat reads of an unchanged source return the same hash.

An approved request reports its approved quantity as `effective_units`. A cancelled request remains in the result with the same `source_key` and `original_units`, while current `effective_units` is zero. Cancellation event and cancellation identifiers, event key, reason, Time-reconciliation flag, and exact reversal ledger links are included when available. Cancellation advances the visible source version/hash but does not erase or replace the approved source. These are facts about Leave state, not a payroll instruction to pay or reverse money.

Every item carries `projection_only: true` and `consumed_by_payroll: false`. No pending request is emitted. No employee code is used in the cursor.

## Consumer gate

A future Cube4 payroll integration must freshly revalidate each source's current version/hash, authorization, and approved preview; lock the payroll period and the relevant source rows before emitting any monetary result; and make its own idempotent consumption/reversal record. It must reconcile Leave against Time payroll facts before emitting unpaid exposure, including configured half-day interpretation. This projection alone provides no protection against a separate Time payroll fact, duplicate consumer, stale source, or concurrent payroll run. Cube4 must not infer that the work is complete from this endpoint.

## Focused acceptance cases

1. Authenticated HR with active authority can read an explicitly scoped employer; self-only, anonymous, service-role, and another tenant are denied.
2. A tenant/employer mismatch, invalid range, half cursor, or page size outside 1–100 is rejected. A 31-date inclusive window succeeds; a wider window fails.
3. Approved sources appear in `(leave_date, request_id)` order with exact keyset continuation; terminal pages do not advertise a cursor, and pending requests never appear.
4. Repeating an unchanged source read yields the same stable source identity and hash.
5. Accepting a cancellation preserves the original source identity and quantity, changes the visible source version/hash, reports zero current exposure, and links the exact reversal allocation.
6. Direct HR cancellation is represented with its cancellation event as well; replaying either cancellation operation does not add a second reversal.
7. No authenticated table read grants are added for approved day snapshots, consumption records, or cancellation records.
8. The response explicitly states that the projection is not consumed by payroll and makes no financial calculation.


## Executed local qualification

- Supabase CLI 2.106.0 applied this migration normally to three explicit loopback-only QA targets: authoring, fresh application-chain and preserved source-clone upgrade. No remote migration was applied.
- `cube3_leave_payroll_facts_projection.test.sql`: 40 assertions passed on each target, covering approved/pending selection, approval provenance, accepted and direct cancellation event mapping, exact reversal allocation, stable identity/current hash, pagination, bounds and denied caller contexts.
- Both fresh and source-clone upgrade have 98 migrations. Function definitions and ACLs match; full baseline digests for 5 Employees, 4 Employments and 2 account links remain unchanged.
- Evidence: external `slice10-function-data-comparison.json`, per-database logs/summaries and slice10 candidate manifest. Tests ran before commit; only migration header and qualification prose changed afterward.
- Root review removed a contradictory cancellation-state predicate, corrected item indexing, and matched event IDs to their actual bigint schema. Neither monetary calculation nor Time half-day reconciliation is qualified by this projection slice.