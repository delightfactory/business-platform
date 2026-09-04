# V1 Implementation Waves

## Status

**Accepted — Phase 0C execution-planning baseline. This is not permission to implement unresolved behavior without Frozen Specs.**

This roadmap translates the V1 capability decomposition into implementation waves while preserving the repository's Definition of Ready/Done and Complexity Budget.

The waves are dependency-driven. They are not permission to implement unresolved product rules inside code.

## Guiding rule

The earliest commercially sellable release is reached by completing the end-to-end HR/payroll job with production-grade platform boundaries — not by finishing every future Platform Core subsystem first.

## Phase 0D — Freeze implementation-ready Specifications and ADRs

**Goal:** remove material ambiguity before Product Code begins.

Required outputs:

1. Platform Foundation Specification
   - tenant / legal entity / site model;
   - membership and explicit tenant context;
   - tenant-isolation invariants;
   - entitlement evaluation/limits/overrides;
   - authorization model and default role templates;
   - Tech Edge control-plane boundaries;
   - sensitive platform audit events.

2. HR People & Work Context Specification
   - employee identity/employment lifecycle;
   - department/job/site assignment;
   - compensation facts;
   - supported pay bases;
   - work-policy/shift variants.

3. Attendance & Leave Specification
   - canonical attendance event contract;
   - source provenance/idempotency;
   - interpretation/exceptions;
   - correction/review behavior;
   - overtime;
   - leave policy/balance/approval behavior;
   - payroll-input boundary.

4. Employee Finance & Payroll Specification
   - penalties/rewards;
   - advances/installments/settlements;
   - payroll component model;
   - Egypt statutory rules;
   - run state machine;
   - locking/reproducibility/corrections;
   - payslip/export/payment-status behavior.

5. Attendance Channel Specification
   - first biometric adapter target;
   - mobile geofence behavior/privacy/offline constraints;
   - device/user mappings;
   - replay/deduplication/error handling.

6. Technology/Deployment ADR set
   - exact web/application stack;
   - persistence/data access approach;
   - authentication provider;
   - deployment/environment strategy;
   - testing and migration execution baseline.

### Phase 0D exit gate

Implementation may begin only when:

- no material V1 behavior is left for Codex to invent;
- core state machines/invariants are explicit;
- authorization and tenant-isolation expectations are testable;
- payroll/financial correction and historical-reproducibility rules are explicit;
- first attendance integration scope is bounded;
- governing specs required by the first implementation wave are **Frozen**.

---

## Wave 1 — Platform Spine

**Goal:** establish the smallest safe, domain-neutral SaaS foundation on which HR can run.

### Capabilities

- PLT-001 Tenant/customer account.
- PLT-002 Employer/legal entity.
- PLT-003 Sites/branches.
- PLT-004 Authentication.
- PLT-005 Membership + explicit tenant context.
- PLT-006 Authorization foundation.
- PLT-007 Entitlements + limits + contract-specific overrides.
- PLT-008 Minimum Tech Edge control plane.
- PLT-009 Sensitive-operation audit foundation.
- PLT-010 Minimum versioned configuration primitives required by downstream specs.

### Intentionally not included

- self-service billing/payment gateway;
- public signup funnel;
- generic workflow engine;
- broad notifications platform;
- generic API product;
- future business-domain tables.

### Wave 1 critical invariants

- no tenant-owned record can be read/written cross-tenant through supported access paths;
- a user with multiple memberships must operate under explicit tenant context;
- UI visibility is not authorization;
- entitlement denial and permission denial are distinguishable concerns;
- disabling an entitlement cannot delete tenant data;
- no role or permission system is duplicated at the site/branch layer;
- privileged helpers are narrowly scoped and security-reviewed.

### Required qualification evidence

- clean database/environment bootstrap;
- positive + negative tenant-isolation tests;
- multi-membership tenant-switch tests;
- authorization negative tests;
- entitlement enable/disable/override/limit tests;
- platform-operator versus tenant-user boundary tests;
- migration/config reproducibility.

### Wave 1 exit

A tenant can be onboarded safely and receive a bounded set of purchased capabilities, but no claim is made yet that the HR product is commercially complete.

---

## Wave 2 — People & Work Context

**Goal:** establish the authoritative workforce model without coupling employee identity to application login.

### Capabilities

- HRP-001 Employee Core.
- HRP-002 Departments/jobs/reporting context.
- HRP-003 Employment and compensation facts.
- HRP-004 Optional employee-user linkage foundation.
- HRP-005 Workforce bulk import.
- HRT-001 Work policies and shifts.

### Critical invariants

- employee can exist without `auth/user` identity;
- employee belongs to the correct tenant/legal employer boundary;
- historical employment/pay facts required by finalized payroll cannot be silently rewritten;
- imports are validated and fail visibly rather than partially mutating silently;
- organization/site entities remain Platform-owned, while employee/job/work rules remain HR-owned.

### Qualification evidence

- tenant isolation across workforce data;
- lifecycle tests for hire/active/inactive/end states defined by Specs;
- compensation/work-policy effective-date tests;
- bulk-import validation/rejection evidence;
- desktop/mobile UX acceptance for core People workflows.

### Wave 2 exit

An HR operator can onboard and structure a workforce with sufficient employment and work-policy context for downstream time/payroll processing.

---

## Wave 3 — Attendance, Exceptions & Leave

**Goal:** make time/leave operational and produce reviewable facts that may feed payroll without directly mutating money.

### Capabilities

- HRT-002 Canonical attendance events.
- HRT-003 Manual/admin attendance entry.
- HRT-004 Spreadsheet attendance import.
- HRT-005 Attendance interpretation/exceptions.
- HRT-006 Overtime determination.
- HRT-007 Exception review/correction.
- HRL-001 Leave types/policies.
- HRL-002 Leave balances/entries.
- HRL-003 Bounded leave request/approval.
- Core attendance/leave reports required to operate/reconcile the workflow.

### Critical invariants

- source event, interpreted fact and payroll financial effect are distinct records/concepts;
- raw attendance never silently creates an irreversible deduction;
- missing/duplicate/replayed source events are handled deterministically;
- correction preserves provenance/auditability;
- leave and attendance can operate independently where logically valid;
- simple approval behavior remains domain-bounded, not a hidden generic workflow engine.

### Qualification evidence

- normalized event contract tests;
- duplicate/idempotency/replay tests;
- attendance-policy edge cases defined by Specs;
- missing-punch and correction regression tests;
- leave balance/approval tests;
- explicit proof that raw attendance cannot directly finalize money impact;
- representative mobile/desktop operator workflows.

### Wave 3 exit

The platform can produce trusted, reviewable attendance/leave/overtime facts from manual/imported data and expose approved payroll inputs through the defined boundary.

---

## Wave 4 — Employee Finance & Payroll Core

**Goal:** complete the first commercially valuable HR job: correct, reviewable, reproducible payroll.

### Capabilities

- HRF-001 Penalties/deduction adjustments.
- HRF-002 Rewards/bonus adjustments.
- HRF-003 Advances/loans.
- HRF-004 Installment schedule/payroll deduction.
- HRF-005 Manual settlement/correction.
- HRPY-001 Payroll configuration/components.
- HRPY-002 Egypt statutory rule set.
- HRPY-003 Payroll run.
- HRPY-004 Approved input contract.
- HRPY-005 Draft/review/approve/lock state machine.
- HRPY-006 Frozen calculation context/reproducibility.
- HRPY-007 Post-lock correction path.
- HRPY-008 Payslip.
- HRPY-009 Payroll export.
- HRPY-010 Payment status.
- Core payroll/employee-finance reports.

### Critical invariants

- Payroll can run with People + compensation even when Attendance/Leave/Employee Finance entitlements are not enabled; enabled domains contribute through explicit inputs.
- money impact must be attributable to a source/reason and effective payroll period;
- finalized payroll never depends on mutable current configuration alone;
- locked payroll cannot be silently mutated/recalculated;
- post-lock corrections use explicit adjustment/reversal/amendment semantics;
- advance balances and installment deductions remain reconcilable;
- statutory rule versions used by a finalized run are preserved.

### Qualification evidence

- deterministic payroll calculation tests;
- statutory-boundary and effective-date tests;
- salary component/input combination tests;
- advance/installment reconciliation tests;
- state-transition authorization tests;
- lock immutability tests;
- post-lock correction tests;
- historical reproduction test after configuration/rule changes;
- fresh-environment E2E: employee → time/leave/finance inputs → payroll → review → approval → lock → payslip/export;
- independently reviewable calculation evidence for representative scenarios.

### Wave 4 exit

**Commercial Core milestone:** the product can manage a bounded workforce/payroll cycle end to end using manual/spreadsheet attendance input. This is the first point at which controlled pilot selling can begin if the launch customer does not require an unimplemented attendance channel.

---

## Wave 5 — Attendance Channels: Biometric + Mobile

**Goal:** make V1 deployable across the primary real-world attendance modes requested for the market without coupling HR logic to device vendors.

### Capabilities

- HRT-008 first prioritized biometric/device connector.
- HRT-009 mobile geofence attendance.
- minimum PLT-011/PLT-012 support required for connector state/evidence.
- focused employee punch surface for mobile attendance, without building full ESS.

### Biometric boundaries

- one prioritized practical connector path is V1 scope;
- no promise of universal device compatibility;
- connector handles transport/mapping/retry/replay, not payroll rules;
- normalized attendance contract is unchanged when a new vendor is later added;
- LAN-only device integration may use a bounded local connector/gateway if the selected hardware requires it.

### Mobile boundaries

- location is captured only when necessary for attendance punch validation/evidence;
- no continuous employee tracking by default;
- mobile attendance is separately entitled from biometric attendance;
- mobile punch access requires a linked user account; other employees still do not require login accounts;
- privacy, permission-denied, location-unavailable, offline and replay behavior must be explicit in the Specs.

### Qualification evidence

- connector deduplication/retry/outage/recovery tests;
- authoritative mapping tests preventing cross-tenant device contamination;
- device/source provenance visible in attendance evidence;
- geofence inside/outside/boundary tests;
- permission denied/location unavailable/offline behavior;
- mobile security and tenant/user linkage negative tests;
- representative real-device and real-mobile acceptance before claiming support.

### Wave 5 exit

V1 supports both requested attendance-channel families through optional entitlements while preserving a single Attendance Core.

---

## Wave 6 — Commercial Hardening & Pilot Qualification

**Goal:** turn completed capability slices into a supportable commercial product rather than a collection of working modules.

### Required work

- onboarding flow for real tenant setup;
- safe entitlement/limit operations through Tech Edge control plane;
- role/permission defaults refined from pilot workflows;
- operational exports/imports and recovery procedures;
- core reports/reconciliation views;
- Arabic-first UX copy/polish if confirmed by the Product Spec for this product;
- desktop/laptop and mobile acceptance across all primary workflows;
- accessibility/keyboard/touch review appropriate to each surface;
- production/staging environment runbook;
- backup/restore/recovery baseline appropriate to stage;
- support diagnostics without exposing sensitive tenant data;
- fresh-environment migration rehearsal;
- security/privacy review for employee, payroll, location and biometric-related data;
- seeded/demo tenant strategy without production data.

### V1 release qualification

The exact release candidate revision must demonstrate:

1. Tenant onboarding and entitlement assignment.
2. Cross-tenant isolation and authoritative authorization.
3. Employee onboarding/import without mandatory user accounts.
4. Work-policy/shift assignment.
5. Attendance via manual/import plus supported biometric connector.
6. Mobile geofence attendance when entitlement is enabled.
7. Attendance interpretation, review/correction and overtime.
8. Leave recording/approval/balance handling.
9. Penalty/reward/advance/installment workflows.
10. Egypt payroll calculation from frozen rule/input context.
11. Payroll review → approval → lock.
12. Post-lock correction path.
13. Payslip and export.
14. Payroll payment-status tracking.
15. Sensitive-operation audit evidence.
16. Capability-disabled UX + server-authoritative denial.
17. Clean database/environment bootstrap with no hidden manual fixes.
18. Representative desktop/laptop and mobile acceptance.
19. No committed secrets/sensitive production data.
20. Governing Specs, ADRs and release scope aligned to the exact candidate.

## Commercial release boundary

### In V1

- Platform tenant/membership/isolation/authorization/entitlement spine.
- Tech Edge manual control plane for customer access/contracts/limits.
- People and workforce import.
- Work policies/shifts.
- Attendance core, manual and spreadsheet input.
- Attendance interpretation/corrections/overtime.
- Leave.
- Penalties/rewards.
- Advances/installments/settlements.
- Egypt payroll.
- Review/approval/lock/reproducibility/corrections.
- Payslip/export/payment status.
- One prioritized biometric connector.
- Optional mobile geofence attendance.
- Core operational reporting.

### Not in V1

- self-service billing/payment gateway/coupons;
- full Contracts/Documents capability;
- full ESS/MSS portals;
- advanced approval/workflow engine;
- recruitment/performance/training;
- expense management;
- full accounting/GL/treasury;
- multi-country payroll;
- universal biometric integration;
- native mobile applications;
- generic API/webhook product;
- advanced analytics/AI;
- future CRM/Sales/Inventory/Procurement/Finance domains.

## Recommended coding sequence inside each wave

Within a wave, prefer thin vertical slices that reach authoritative persistence and tests rather than building all UI first or all database structure first.

Typical slice order:

```text
Frozen Spec
  -> migration / data invariant
  -> authoritative service/RPC/application behavior
  -> authorization/tenant-isolation tests
  -> domain tests
  -> UI workflow
  -> desktop/mobile acceptance
  -> exact-HEAD qualification
```

Do not weaken a failed gate to preserve schedule. Correct the implementation or revise the governing Spec through change control.

## Next planning action after Phase 0C approval

Proceed to **Phase 0D — Implementation-Ready Specs & ADRs**, starting with the Platform Foundation Specification because Wave 1 blocks every tenant-owned business domain.