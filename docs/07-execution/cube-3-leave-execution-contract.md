# Cube 3 — Leave Execution Contract

## Status

Planning contract governed by Accepted DEC-025 and [Cube 3 Leave Self-Service Amendment](../04-product-specs/cube-3-leave-self-service-amendment-2026-10-01.md). It does not claim implementation exists.

## Scope

- HR configures Leave, records it for any Employee (including one without an account), manages balances, and owns review/approval.
- A linked Employee sees only their own Employee profile, Leave, and balance; submits/follows/withdraws a pending request; and requests cancellation after approval for HR's decision.
- Leave uses its own Employer-scoped Calendar and configured Leave Year. Leave requires `hr.people` and `hr.leave` for new work, but never requires Attendance.
- Approved Leave facts appear in a read-only, versioned, idempotent Payroll projection marked `projection_only` and `consumed: false`. Cube 3 adds no money calculation, Payroll consumer, period lock, or locked-run mutation.
- Full ESS/MSS, general People self-service, and general/multi-level approval remain deferred. DEC-014 is unchanged.

## Permissions and isolation

| Task | Permission | Scope |
|---|---|---|
| Own Employee profile | `people.self.view` | Current linked Employee only; does not imply `people.view` |
| Own Leave, balance, request status | `leave.self.view` | Linked Employee's records only |
| Submit/withdraw own pending request; request cancellation | `leave.self.request` | Linked Employee's records only |
| HR view/record/manage | `leave.view`, `leave.manage` | Authorized Tenant scope; same-Tenant active Employment |
| HR approve/reject/cancel decision | `leave.approve` | Authorized Tenant scope; separate from recording |
| HR balance opening/adjustment | `leave_balance.adjust` | Audited ledger entry with reason |

Every new operation checks active Membership, authoritative Tenant context/state, entitlement, Permission, resource scope, and same-Tenant links server-side. A link grants no Membership or Permission. New work requires active `hr.people` + `hr.leave`; self-service also requires the current active same-Tenant Employee↔User link. Do not require `hr.attendance` or tenant-wide `people.view`. Historical read/closure follows the explicit disabled-entitlement exception below and still checks Membership, Tenant state, scoped Permission, and resource/link scope.

When either People or Leave entitlement is disabled, keep historical records readable and allow authorized closure of already-open work through current Membership, Tenant context, resource/link scope, and scoped Permission. Block new requests/records/grants/adjustments and positive balance growth. Closure may append only required reversal/audit entries; never delete history.

## Configuration, balance, and transitions

- Configure an Employer-scoped Leave Calendar and explicit Leave-Year boundaries; do not infer them from Payroll Calendar or Attendance Work Policy. Annual Leave counts configured working days, excluding weekly rest and official holidays per Article 124 of the cited law.
- A permitted half-day consumes `0.5` balance day. That quantity alone does not define clock timing or remaining Attendance obligation. Proration/rounding, category transitions, and half-day timing remain legal/compliance verification gates; do not code dependent behavior before accepted evidence.
- Grant uniqueness key: Employer Legal Entity + Employee + Leave Type + Leave-Year account period. Policy version is provenance, never a new grant period. Unused balance does not expire automatically; complex carry-forward/expiry rules remain deferred.
- Ledger entries are attributable and append-only: opening/grant, approved consumption, authorized adjustment, and linked cancellation/correction reversals. Pending requests reserve no balance.
- Record transitions: `draft → submitted`; `submitted → approved | rejected | withdrawn`; `approved → cancelled | superseded`. A submitter may withdraw while pending. Every submitted item has an authorized owner/queue.
- `leave.manage` records/submits; `leave.approve` separately decides. Self-approval is allowed when the requester also holds `leave.approve`. Record actor, time, decision, and reason. Revalidate policy/Employment/overlap/balance and commit approval plus consumption atomically.
- After approval, the Employee may request cancellation (`pending → accepted | rejected`); HR decides. Acceptance cancels and reverses balance once; rejection preserves the approved Leave. `superseded` is only through a governed linked correction; do not rewrite approved history.

## Attendance and Payroll boundaries

- Leave works without Attendance. Any Leave effect on Attendance goes through a versioned Time-domain operation; never silently edit an approved fact or count the same absence and Leave twice. If no such operation exists, keep Leave reviewable without inventing an Attendance result.
- The Payroll projection exposes approved facts, source/version identity, and `consumed: false`; it carries no monetary valuation or claim of consumption. Before future Cube 4 consumption, Cube 4 must add a transactional lock/version check and route changes to a linked correction/adjustment. Cube 3 does not implement that gate or unlock Payroll.

## UX and qualification gates

- Preserve the HR forms and the HR path for Employees without accounts. Add a focused own-Leave surface, not a broad portal. Use Arabic-first RTL on phone, tablet, and desktop; show own balance/state/next action and explain errors with a recovery step.
- Test own-only isolation (including missing/inactive/cross-Tenant links), permissions and both entitlement states; HR recording without an account; submit/withdraw/approve/self-approve/cancel accept/reject; reason/actor/time audit; owner assignment; invalid/overlapping Employment/Leave.
- Test pending-no-reservation, concurrent approvals against one balance, exactly-once consumption/reversal, grant uniqueness across policy versions, non-expiring remainder, and disabled-entitlement closure without growth.
- Test Leave with Attendance absent; ensure any Time integration versions approved facts and prevents duplicate absence. Verify projection is read-only, approved-only, idempotent, versioned, and unconsumed; do not test/claim Cube 3 money or lock behavior.
- Verify annual working-day rules against accepted legal evidence. Half-day balance tests may assert `0.5` only for a type that permits it; do not infer its clock interval/Attendance obligation. Hold proration/category/half-day timing cases until the legal gate is accepted.
- Qualify clean database install and local upgrade, tenant/security cases, and Arabic RTL forms at mobile/tablet/desktop sizes. No remote database, deployment, or production acceptance is part of Cube 3.
- Do not claim full Cube 3 closure while an enabled V1 annual-entitlement or half-day capability lacks its required implemented calculation. The working-day/holiday rule and permitted `0.5` balance unit are fixed; proration/rounding, category changes, and half-day timing remain verification gates. Independent request/review/ledger slices may proceed while those dependent cases are held.

## Governing references

The amendment above; `attendance-leave-spec.md`; `hr-people-work-context-spec.md`; `employee-finance-payroll-spec.md`; `payroll-calendar-and-cutoff-amendment.md`; `v1-capability-decomposition.md`; `v1-implementation-waves.md`; DEC-012/014/015/016/023/025; ADR-003/004/008.
