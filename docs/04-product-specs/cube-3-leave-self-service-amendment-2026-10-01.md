# Cube 3 Leave Self-Service Amendment — Business Platform V1

## Status

Accepted product amendment — 2026-10-01.

## Purpose and authority

This scoped amendment clarifies the Cube 3 Leave workflow in the Frozen Attendance & Leave Specification. It adds a bounded employee-owned Leave view and request path while preserving HR-owned Leave operations and the existing platform access model.

This amendment does not amend or erase DEC-014. Full Employee Self-Service (`hr.ess`) and full Manager Self-Service (`hr.mss`) remain deferred. DEC-014 continues to permit focused employee or manager surfaces required by a V1 workflow; this amendment names one such surface for Leave. No broad ESS portal, unrelated People self-service, or general approval/workflow engine is included.

If this amendment differs from the original Cube 3 Leave wording, this amendment governs only those Leave-specific points. The rest of the Frozen Attendance & Leave Specification and accepted architecture remain in force.

## Accepted product decisions

### Bounded own-Leave surface

- A user may view only the own Employee profile, Leave records, balance, and requests belonging to the Employee currently linked to that same authenticated User in the active Tenant.
- `people.self.view` provides only the minimal own-Employee context needed to identify the linked Employee. It does not grant `people.view`, People administration, compensation access, or access to another Employee.
- `leave.self.view` and `leave.self.request` provide own-record viewing and own-request submission/withdrawal. They do not grant HR access to other Employees' Leave data.
- New Leave requests/records, grants, and adjustments require active `hr.people` and `hr.leave` entitlements, an active same-Tenant Membership, current authoritative Tenant context, valid Employment, the required permission, and the applicable resource scope. Leave does not require `hr.attendance`.
- Own historical Leave/profile reads and authorized closure of existing work remain available after `hr.people` or `hr.leave` is disabled, subject to active Membership, current Tenant context, the matching active Employee↔User link for the own surface, and the relevant self/HR Permission. This limited historical path does not require `people.view` and cannot create new work or increase balance. A missing, inactive, or mismatched link denies the own-Employee surface. Employee↔User links remain optional for the rest of People and Leave workflows.
- HR operations continue to use the existing Leave permission family: `leave.view`, `leave.manage`, `leave.approve`, and `leave_balance.adjust`. This amendment does not define a new role template or permission inheritance rule.

### Record, request, approval, and cancellation

- HR may record Leave on behalf of an Employee, including an Employee without a User account; employees with the required same-Tenant Employee↔User link may submit their own Leave request. Recording/submission and approval are distinct steps guarded by their separate `leave.manage` and `leave.approve` permissions. No record is implicitly approved merely because it was entered by HR.
- Leave-record transitions are `draft → submitted`, `submitted → approved | rejected | withdrawn`, and `approved → cancelled | superseded`. `cancelled` is reached only after an approved cancellation request; `superseded` is reached only through a governed correction that links a replacement. Rejected, withdrawn, cancelled, and superseded records remain historical and are not edited in place.
- A submitter may withdraw their own pending request. Approval is a single authorized decision using `leave.approve`; the requester is not barred from approving their own request when they separately hold that Permission. Every submission, decision, withdrawal, and cancellation decision is audited with actor identity, decision time, and reason. No maker-checker rule is added.
- Every submitted request has an identified authorized owner/queue. An ownerless submitted request is an invalid state.
- After approval, the Employee may request cancellation; an authorized HR approver decides `accepted` or `rejected`. The cancellation request has status `pending`, then `accepted` or `rejected`. Acceptance changes the Leave record to `cancelled` and appends the required balance reversal/restore entry. Rejection leaves the approved Leave and its ledger effect intact. A cancellation request does not edit or erase the original Leave evidence.
- Pending requests do not reserve or consume balance. Balance eligibility is rechecked when HR approves, and the approval decision plus balance consumption commit atomically against the current ledger and Leave policy. Only approval appends the Leave-consumption entry.
- `superseded` is a historical terminal state used only when a governed correction replaces a prior record; the prior record and its link to the replacement remain inspectable. No in-place rewrite of approved history is allowed.

### Leave calendar, leave year, and annual grants

- Leave owns an independently configured, Employer-scoped Leave Calendar and Leave Year within the Tenant. The account-period boundaries are explicit configuration; they are not inferred from Payroll Calendar or Attendance Work Policy. No calendar-year, fiscal-year, or hire-anniversary default is imposed.
- Annual Leave is counted in eligible working days under the configured Leave Calendar; weekly-rest days and official holidays are excluded according to Article 124 of the cited law. A Leave Type that permits half-day use consumes `0.5` balance day. This does not define the intraday clock interval or the remaining Attendance obligation for a half-day.
- Leave-day eligibility and balance periods use the configured Leave Calendar/Leave Year. This does not create an Attendance dependency; Leave remains usable when `hr.attendance` is not entitled or enabled.
- An annual entitlement creates at most one grant per Employer Legal Entity + Employee + Leave Type + configured Leave-Year account period. A policy-version change is provenance for the grant, not a new uniqueness period and must not create a duplicate grant. A changed amount does not cause a second grant; a separately authorized correction is an attributable compensating ledger entry.
- Opening balances and authorized adjustments remain explicit, attributable ledger entries. Unused balance does not expire automatically. Complex carry-forward matrices and expiration rules remain deferred. No pending request reserves balance, and no policy edit rewrites prior grants or approved consumption.

### Entitlement disable and payroll boundary

- When `hr.people` or `hr.leave` is disabled, the system preserves historical Leave and balance records and permits authorized, bounded closure of already-open work through the specific historical access path above. It blocks new requests, Leave records, annual grants, and positive balance growth. Closure may append only the reversal/audit facts required to finish an existing cancellation or correction. It does not require tenant-wide `people.view`.
- Cube 3 exposes approved Leave payroll facts through a Tenant-scoped, attributable, versioned, idempotent read-only projection boundary. The Cube 3 projection is `projection_only` and `consumed: false`; it does not create or lock a Payroll run and does not claim that Payroll has consumed Leave.
- Cube 3 does not implement a Payroll lock check or Payroll mutation. Before a future Cube 4 consumer accepts any Leave projection, Cube 4 must add the transactionally enforced lock/version comparison and linked correction or next-period adjustment required by the frozen Payroll contract. Cube 3 cannot reopen or mutate a locked run.
- Leave may affect Attendance interpretation only through a versioned Time-domain operation. It must not silently edit an approved Attendance fact or count the same absence and approved Leave twice in downstream input. A correction preserves prior facts and records its reason and supersession/reversal relationship.

## Explicitly pending verification

The Leave Calendar working-day rule and `0.5` balance-day unit for permitted half-day Leave are fixed above. Legal/compliance verification remains required for statutory proration and rounding, Employee eligibility categories and changes between categories, and the clock-time interval/Attendance obligation associated with half-day Leave. Do not infer those values from examples in the existing specification. The official law cited in §13 of the Attendance & Leave Specification is the source to qualify; DEC-023's production statutory qualification gate remains in force. This amendment assumes no new statutory personal attributes exist in the People model; any such data requirement needs explicit legal evidence and privacy review before collection or use.

Before code depends on statutory proration, category transitions, or half-day timing/Attendance behavior, the owning team must complete that verification and add accepted evidence/rules. A half-day amount may use `0.5` balance day only where the configured Leave Type permits it; that number alone does not define a clock interval or remaining Attendance obligation. The Leave request, review, and ledger workflow may be qualified independently of the pending details.

## Technical recommendation — not an additional product decision

Prefer a small Tenant-scoped relational Leave model, append-only balance ledger, and narrowly scoped transactional commands for approval, cancellation, and annual-grant idempotency. Enforce the annual-grant uniqueness invariant at the database boundary using the Employer Legal Entity, Employee, Leave Type, and configured account-period identity; retain policy version as audit provenance only. Reuse the existing authoritative Membership, Tenant, Permission, Entitlement, audit, and transaction contracts. Do not add a generic workflow, accrual, calendar, or rules engine.

This recommendation follows ADR-008's authoritative access/transaction boundary and ADR-004's stable permission model; implementation details remain subject to review against those sources.

## Sources and preserved decisions

- DEC-014 remains unchanged: full ESS/MSS and generic approval/workflow are deferred; focused employee/manager surfaces may exist only for V1 workflows.
- DEC-012: Payroll does not require Attendance, Leave, or Employee Finance entitlements; enabled domains contribute through approved input boundaries.
- DEC-016: every material workflow needs an operational end state or explicit handoff.
- `docs/02-blueprint/v1-capability-decomposition.md`: HRL-001 through HRL-003 are mandatory under `hr.leave`; Leave must not require Attendance; HRS-001 full ESS and HRS-002 full MSS remain deferred.
- `docs/04-product-specs/attendance-leave-spec.md`: Leave types, ledger, one-stage approval, Attendance/Payroll boundary, and Leave permissions.
- `docs/04-product-specs/hr-people-work-context-spec.md`: Employee↔User link is optional and does not itself grant Membership or permissions.
- `docs/04-product-specs/employee-finance-payroll-spec.md` and `docs/04-product-specs/payroll-calendar-and-cutoff-amendment.md`: Payroll-period identity and immutable post-lock correction/payment treatment.
- `docs/03-architecture/adr/ADR-003-entitlement-precedence-and-disable-semantics.md`, `ADR-004-authorization-permissions-and-role-templates.md`, and `ADR-008-authoritative-data-access-and-transaction-boundaries.md`.
- `docs/06-governance/decision-log.md`: DEC-012, DEC-014, DEC-016, and DEC-023.
