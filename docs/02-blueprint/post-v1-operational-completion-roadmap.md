# Post-V1 Operational Completion Roadmap

## Status

**Accepted planning principle; capability details remain subject to later Specs and prioritization.**

This document prevents the initial release strategy from being misread as "build only the minimum forever." V1 deliberately implements the smallest commercially coherent end-to-end workflows, while post-launch development deepens lifecycle completeness, operational controls, automation, integration, and scale according to real customer use.

This is not a calendar commitment and does not authorize speculative infrastructure. It is a continuity map for completing each operational cycle without redesigning its foundations.

## Governing principle: no dead-end workflows

A supported process must never stop at a state where the user has created operational responsibility but the product provides no defined way to finish, reject, cancel, correct, reconcile, close, or hand it off.

When a downstream capability is outside the active release, the current release must still provide an explicit safe boundary such as:

- a completed/final status;
- rejection/cancellation;
- correction or compensating adjustment;
- reconciliation status;
- export/file handoff;
- documented external continuation;
- operator-controlled closure;
- preserved historical record with a defined next action.

A manual or external handoff may be valid in an early release when it is explicit, auditable where required, and does not hide unfinished system state.

## Capability maturity model

### M1 — Viable end-to-end

The customer can complete the core business job safely from entry to a defined operational outcome. Necessary manual/external handoffs are explicit.

This is the minimum bar for V1 capabilities.

### M2 — Operational completeness

Add the lifecycle paths that remove routine operational friction: bulk actions, correction paths, closing/reopening rules, reconciliation, exception queues, better history, recurring operations, and support tooling.

### M3 — Automation and integration

Replace repeated manual handoffs where justified with scheduled processing, device/system connectors, ERP/accounting/bank integrations, notifications, APIs/webhooks, and operational automation.

### M4 — Scale and advanced control

Add proven enterprise needs such as richer approval depth, policy variation, higher-volume operations, advanced analytics, delegated administration, and dedicated operational controls.

The maturity sequence is directional, not mandatory. A real customer requirement may justify advancing one capability sooner while another remains at M1/M2.

---

# Domain continuity map

## 1. Platform / customer operations

### V1 completion boundary

Tenant can be onboarded, granted capabilities/limits, administered, suspended/reactivated, and audited through the Tech Edge control plane.

### Post-V1 operational depth

Potential follow-on work, only when commercially justified:

- richer subscription/contract lifecycle and renewal handling;
- expiry/grace-period operational flows;
- plan/bundle management UX;
- onboarding templates and bulk tenant setup;
- customer-facing billing visibility;
- invoices/payment collection integrations;
- partner/channel commission operations;
- tenant support/recovery tooling;
- controlled delegated administration;
- account closure/retention/export workflows.

A tenant must never become stuck because billing automation is deferred: V1 manual control-plane access state is the explicit operational boundary.

## 2. People / employment lifecycle

### V1 completion boundary

Employee can be created/imported, assigned to legal employer/site/organization context, provided payroll/work facts, activated/inactivated/ended according to the People Spec, and retained historically without requiring a login account.

### Post-V1 operational depth

- richer employee-change history and effective-dated transfers;
- bulk organizational changes;
- contract lifecycle when enabled;
- employee document management when enabled;
- onboarding/offboarding checklists based on proven needs;
- employee data-change requests;
- ESS/MSS profile workflows;
- richer organizational structures and delegated administration.

The V1 employee lifecycle must still end safely without Contracts, Documents, or ESS being present.

## 3. Attendance / time

### V1 completion boundary

Attendance events enter through supported sources, are normalized/interpreted, exceptions can be reviewed/corrected, overtime is resolved where applicable, and approved facts can be handed to Payroll.

### Post-V1 operational depth

- richer shift/rota scheduling variants;
- recurring exception queues and operational alerts;
- broader biometric/device fleet management;
- additional device/vendor adapters;
- attendance import mapping UX;
- advanced rounding/grace/policy variants proven by customers;
- field/offsite attendance controls;
- richer manager review surfaces;
- attendance close/reopen periods if real operating models require them;
- API/webhook ingestion after concrete integration demand.

Raw events must never form a dead end: unresolved events remain visible as exceptions rather than silently disappearing from payroll responsibility.

## 4. Leave

### V1 completion boundary

Leave can be recorded/requested, reviewed using the bounded approval model, balances are updated under the defined policy, and resulting approved facts are available to downstream attendance/payroll behavior.

### Post-V1 operational depth

- richer accrual/carry-forward policy variants;
- multi-level approval where customers prove the need;
- delegation/substitution;
- team calendar and staffing views;
- expiry/forfeiture automation;
- advanced leave settlement/encashment if required;
- employee/manager self-service depth;
- policy eligibility and exception tooling.

A request always needs a terminal or actionable state; "submitted forever" is not a valid lifecycle.

## 5. Employee Finance

### V1 completion boundary

Penalty/reward adjustments are attributable and payroll-ready; advances/loans have balances and installment schedules; settlements/corrections are auditable; payroll deductions are reconcilable.

### Post-V1 operational depth

- richer advance approval/request workflows;
- rescheduling/deferment policies;
- early/full settlement flows;
- balance statements;
- cash-receipt or external-payment reconciliation;
- accounting/ERP posting adapters;
- employee self-service visibility;
- exception/overdue management when operationally relevant.

The HR subledger must always have a path to reconcile or explicitly hand off real cash/accounting movements that occur outside V1.

## 6. Payroll

### V1 completion boundary

Payroll can be prepared, calculated, reviewed, approved, locked, corrected through an explicit post-lock path, issued as payslip/export, and marked with payment status. Actual bank execution and full accounting are explicit external handoffs in V1.

### Post-V1 operational depth

- off-cycle/supplementary payroll if customer demand proves it;
- richer retroactive adjustment handling;
- bank payment-file formats and payment integration;
- payment reconciliation;
- accounting/GL posting adapters;
- statutory filing/export automation;
- year-end/period-end operational procedures;
- termination/final-settlement depth where required by the target operating model;
- payroll approval depth and delegated controls;
- employee payslip/self-service distribution;
- multi-entity consolidated operating views without merging legal payroll authority.

No payroll run may stop at "calculated" with no path to approve, lock, correct, export, or reconcile its status.

## 7. Integrations

### V1 completion boundary

Imports/exports and the selected attendance connectors have explicit validation, mapping, provenance, failure reporting, and retry/correction behavior appropriate to their scope.

### Post-V1 operational depth

- connector health dashboard;
- configurable mapping tools;
- scheduled sync;
- durable retry/dead-letter handling where justified;
- customer-facing API/webhooks;
- ERP/accounting/bank adapters;
- integration audit/diagnostics;
- additional attendance vendors.

An integration failure must become an actionable state, not lost data or an invisible partial process.

## 8. UX and workflow continuity

Across every domain, post-launch polish must focus not only on visual quality but on operational continuity:

- current state is obvious;
- next allowed actions are obvious;
- blocked states explain why and what can happen next;
- cancellation/rejection/correction paths are discoverable where allowed;
- historical/closed states are distinguishable from active work;
- mobile and desktop compositions preserve the same business lifecycle;
- role/entitlement changes do not strand records without an authorized continuation path.

---

# Planning rule for every future capability

Every Product Spec must include a **Workflow Completion Map** covering, as applicable:

1. Entry/creation trigger.
2. Active/intermediate states.
3. Who owns the next action.
4. Success/final state.
5. Reject/cancel/withdraw path.
6. Correction/reversal/reopen path.
7. Reconciliation/settlement path for money or externally completed actions.
8. External handoff when downstream scope is deferred.
9. Permission/entitlement loss behavior for in-flight records.
10. Historical visibility and retention after completion.
11. Post-V1 maturity items deliberately deferred.

A Spec is not implementation-ready when a material state creates operational responsibility but has no defined next action or terminal/handoff outcome.

## Prioritization after launch

Post-launch work should be selected using evidence rather than completing this roadmap mechanically. Prioritize items that:

1. unblock real customer operations;
2. remove recurring manual work or error risk;
3. close lifecycle/reconciliation gaps;
4. improve safety/compliance/supportability;
5. unlock meaningful commercial expansion;
6. are repeated across customers and justify generalization.

This preserves the Complexity Budget while ensuring "simple V1" never becomes "permanently incomplete product."
