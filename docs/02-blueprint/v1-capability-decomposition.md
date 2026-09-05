# V1 Capability Decomposition

## Status

**Accepted — Phase 0C product-scope baseline, amended by accepted Phase 0D Platform Foundation decisions through 2026-09-05.**

This document converts the accepted platform/product blueprint into a bounded first commercial release scope. It does not freeze payroll formulas or vendor-specific integration details. Platform Foundation behavior and technology choices are further constrained by the Frozen Platform Foundation Specification and Accepted ADRs.

Baseline used for this decomposition:

- Business Platform `main`: `7071916e9d294db6d58ca85248b3be25a9d0d3be`
- Accepted Master Product Blueprint
- Accepted Product and Architecture Principles
- Completed `edara-saas` extraction audit
- Accepted Phase 0D Platform Foundation amendments where they explicitly narrow this baseline

## Release objective

V1 must complete one commercially coherent job:

> A company can onboard its workforce, define the minimum work/pay context, capture and review time/leave/employee-finance effects, produce a correct payroll run, review and lock it, then issue payslips/exports — while Tech Edge can operate the tenant, entitlements and access safely.

V1 is not intended to be a full ERP, a full talent suite, a generic workflow platform, or a self-service SaaS billing product.

Every V1 capability must also comply with `DEC-016`: a supported workflow cannot create an operational dead end. Deferred sophistication must end in an explicit safe status, correction/closure path, reconciliation path, operator action, export, or external handoff. Post-launch depth is tracked in `post-v1-operational-completion-roadmap.md`.

## Scope classes

- **Mandatory V1** — required for the first commercially sellable HR & Payroll release.
- **Optional V1** — implemented in V1 but enabled only for tenants that need/purchase it.
- **Deferred** — deliberately outside V1.
- **Foundation-only** — implement only the minimum shared substrate required by active V1 capabilities; do not build a generalized subsystem beyond current need.

## Capability matrix

### Platform Core

| ID | Capability | Scope | Commercial entitlement | Depends on | Authoritative owner | V1 boundary |
|---|---|---|---|---|---|---|
| PLT-001 | Tenant / customer account | Mandatory V1 | Platform Core | — | Platform Core | Tenant is the primary isolation/commercial boundary. Lifecycle state is an authoritative access gate, not a UI flag. |
| PLT-002 | Legal Entity identity/lifecycle foundation | Mandatory V1 | Platform Core | PLT-001 | Platform Core | Domain-neutral legal/business identity inside a Tenant. V1 may create one default Legal Entity for simple customers while allowing more than one. HR/Payroll owns Employer semantics and payroll/statutory attributes that reference it. |
| PLT-003 | Sites / branches | Mandatory V1 | Platform Core; limits may vary | PLT-001, PLT-002 | Platform Core | Domain-neutral physical/operating locations. One-site tenants remain simple. |
| PLT-004 | Authentication | Mandatory V1 | Platform Core | — | Platform Core | Invite-only verified email/password identity in Wave 1. Public self-signup is disabled. Authentication alone never grants Tenant authority; an Employee does not require a User account. |
| PLT-005 | Membership and explicit tenant context | Mandatory V1 | Platform Core | PLT-001, PLT-004 | Platform Core | Users may belong to more than one Tenant. One persistent User+Tenant Membership relationship uses explicit active/inactive access state. No implicit `first tenant` or hidden `LIMIT 1` authority. |
| PLT-006 | Authorization foundation | Mandatory V1 | Platform Core | PLT-005 | Platform Core | Server/data-authoritative permissions. Entitlements, Tenant lifecycle, and permissions remain separate required concerns. |
| PLT-007 | Capability catalog, entitlements and limits | Mandatory V1 | Platform Core | PLT-001 | Platform Core | Stable capability keys + direct effective-dated tenant grants/denials + optional effective-dated limits. Plans/subscriptions may later compose into the same entitlement contract but are not a Wave 1 source-of-truth requirement. |
| PLT-008 | Tech Edge control plane | Mandatory V1 | Internal Platform Ops | PLT-001, PLT-007 | Platform Core | Create/onboard Tenant, manage direct capability grants/limits, inspect status, and perform explicit suspend/reactivate/archive/restore operations. No large self-service billing requirement. |
| PLT-009 | Sensitive-operation audit foundation | Mandatory V1 | Platform Core | PLT-004, PLT-005 | Platform Core | Targeted append-only audit events for sensitive actions. No indiscriminate full-row sensitive snapshots. |
| PLT-010 | Shared temporal/versioning contract | Foundation-only | Platform Core | PLT-001 | Platform Core | Minimum shared effective-date/version-reference conventions where historical correctness requires them. Actual HR/Payroll business rules stay in the owning Domain. Not a generic rule/config engine. |
| PLT-011 | Files/storage foundation | Foundation-only | Platform Core | PLT-001 | Platform Core | Only what V1 imports/exports/payslips/evidence require. No generic document-management suite. |
| PLT-012 | Integration boundary + import/export foundation | Mandatory V1 | Platform Core; advanced API access later | PLT-001 | Platform Core / Integration boundary | Adapters and import/export contracts. Business rules remain in owning domains. |
| PLT-013 | Persistent notification/inbox platform | Deferred | Later | — | Platform Core | Domain feedback/status can exist without building a universal inbox in V1. |
| PLT-014 | Self-service SaaS billing, payment gateway, coupons | Deferred | Later | PLT-007, PLT-008 | Platform Commercial Ops | Commercial agreements can be managed operationally outside a billing subsystem while Wave 1 enforces direct effective-dated grants/limits with bounded commercial references. |
| PLT-015 | Public API/webhook product entitlement | Deferred | `platform.integrations.api` | PLT-012 | Platform Core | Integration seams are designed now; broad customer-facing API product comes after concrete use cases. |

### HR — People

| ID | Capability | Scope | Entitlement | Depends on | Authoritative owner | V1 boundary |
|---|---|---|---|---|---|---|
| HRP-001 | Employee Core | Mandatory V1 | `hr.people` | PLT-001, PLT-002 | HR / People | Employee/workforce identity and lifecycle. Employment/Employer semantics are owned by HR and reference the shared Legal Entity. No login requirement. |
| HRP-002 | Departments / jobs / reporting context | Mandatory V1 | `hr.people` | HRP-001, PLT-003 | HR / People | Bounded organization context required for HR operations; not a universal organization-graph engine. |
| HRP-003 | Employment and compensation facts | Mandatory V1 | `hr.people` | HRP-001 | HR / People | Employment relationship, legal Employer reference, start/end status, pay basis, base compensation and payroll-relevant employment facts. Exact supported pay bases are frozen later in Payroll Specs. |
| HRP-004 | Employee ↔ user account link | Foundation-only | Platform Core / target feature | HRP-001, PLT-004 | HR / People + Platform identity link | Optional per employee. Required only for user-facing employee channels such as mobile attendance. |
| HRP-005 | Workforce bulk import | Mandatory V1 | `hr.people` | HRP-001 | HR / People | Safe onboarding import with validation/reject reporting. No hidden direct DB load. |

### HR — Work Policy, Time & Attendance

| ID | Capability | Scope | Entitlement | Depends on | Authoritative owner | V1 boundary |
|---|---|---|---|---|---|---|
| HRT-001 | Work policies and shifts | Mandatory V1 | `hr.attendance` | HRP-001 | HR / Time | Controlled configuration only. Supported schedule variants are specified before implementation. |
| HRT-002 | Canonical attendance events | Mandatory V1 | `hr.attendance` | HRP-001 | HR / Time | Source-neutral normalized events with source metadata and immutable provenance where required. |
| HRT-003 | Manual/admin attendance entry | Mandatory V1 | `hr.attendance` | HRT-002 | HR / Time | Audited corrections/entries; no silent overwrite of authoritative source history. |
| HRT-004 | Spreadsheet attendance import | Mandatory V1 | `hr.attendance` | HRT-002, PLT-012 | HR / Time | Validated import path for fast customer onboarding and fallback integration. |
| HRT-005 | Attendance interpretation and exceptions | Mandatory V1 | `hr.attendance` | HRT-001, HRT-002 | HR / Time | Late/absence/early/missing-punch/etc. are interpreted facts, not immediate irreversible money movements. |
| HRT-006 | Overtime determination | Mandatory V1 | `hr.attendance` | HRT-001, HRT-005 | HR / Time | Produces reviewable approved payroll input; exact formulas/policy boundaries are specified later. |
| HRT-007 | Exception review and correction | Mandatory V1 | `hr.attendance` | HRT-005 | HR / Time | HR/authorized reviewer can resolve incomplete or incorrect interpretations with audit trail. |
| HRT-008 | Biometric/device connector | Optional V1 | `hr.attendance.biometric` | HRT-002, PLT-012 | Integration adapter + HR / Time | V1 supports one prioritized practical connector path; no claim of universal device support. |
| HRT-009 | Mobile geofence attendance | Optional V1 | `hr.attendance.mobile` | HRT-002, HRP-004, PLT-003 | HR / Time | Location captured only as needed for punch validation/evidence. No continuous employee tracking by default. |

### HR — Leave

| ID | Capability | Scope | Entitlement | Depends on | Authoritative owner | V1 boundary |
|---|---|---|---|---|---|---|
| HRL-001 | Leave types and bounded leave policy | Mandatory V1 | `hr.leave` | HRP-001 | HR / Leave | Configurable policy without generic scripting. |
| HRL-002 | Leave balances / entries | Mandatory V1 | `hr.leave` | HRL-001 | HR / Leave | Opening balances and auditable adjustments supported; detailed accrual policy frozen in Leave Specs. |
| HRL-003 | Leave request/record + simple approval | Mandatory V1 | `hr.leave` | HRL-001, HRL-002 | HR / Leave | Bounded one-stage/role-based review sufficient for V1. No general approval engine. |
| HRL-004 | Advanced multi-level approvals | Deferred | `hr.advanced_approvals` | HRL-003 | HR / Leave or later shared approval capability | Added only when concrete multi-step cases justify it. |

### HR — Employee Finance

| ID | Capability | Scope | Entitlement | Depends on | Authoritative owner | V1 boundary |
|---|---|---|---|---|---|---|
| HRF-001 | Penalties/deductions adjustments | Mandatory V1 | `hr.employee_finance` | HRP-001 | HR / Employee Finance | Explicit authorized financial adjustment with reason/effective payroll period. Attendance may propose context but may not silently create irreversible deduction. |
| HRF-002 | Rewards/bonuses/allowance adjustments | Mandatory V1 | `hr.employee_finance` | HRP-001 | HR / Employee Finance | Explicit payroll-impact record; recurring salary components are handled by Payroll/compensation configuration. |
| HRF-003 | Employee advances/loans | Mandatory V1 | `hr.employee_finance` | HRP-001 | HR / Employee Finance | Principal, outstanding balance and lifecycle. Not a full accounting ledger. |
| HRF-004 | Installment schedule / payroll deductions | Mandatory V1 | `hr.employee_finance` | HRF-003 | HR / Employee Finance | Produces due payroll input while preserving outstanding balance history. |
| HRF-005 | Manual settlement / correction | Mandatory V1 | `hr.employee_finance` | HRF-003 | HR / Employee Finance | Audited adjustment/settlement path; no hidden balance mutation. |

### HR — Payroll

| ID | Capability | Scope | Entitlement | Depends on | Authoritative owner | V1 boundary |
|---|---|---|---|---|---|---|
| HRPY-001 | Payroll configuration / salary components | Mandatory V1 | `hr.payroll` | HRP-003, PLT-010 | HR / Payroll | Controlled components and calculation configuration; exact component catalog frozen in Payroll Specs. |
| HRPY-002 | Egypt statutory rule set | Mandatory V1 | `hr.payroll` | HRPY-001, PLT-010 | HR / Payroll compliance | Effective-dated/versioned statutory rules. No tax/insurance values hard-coded into historical results. |
| HRPY-003 | Payroll run | Mandatory V1 | `hr.payroll` | HRP-001, HRP-003, HRPY-001 | HR / Payroll | Payroll does **not** strictly depend on Attendance/Leave/Employee Finance being entitled. Those domains are optional approved input providers when enabled. |
| HRPY-004 | Approved input contract | Mandatory V1 | `hr.payroll` | HRPY-003 | HR / Payroll boundary | Attendance, Leave and Employee Finance contribute only through explicit approved inputs/snapshots; no ad-hoc table coupling as business authority. |
| HRPY-005 | Draft → review → approve → lock | Mandatory V1 | `hr.payroll` | HRPY-003 | HR / Payroll | Locked/finalized runs cannot be silently recalculated by current configuration. |
| HRPY-006 | Frozen calculation context / reproducibility | Mandatory V1 | `hr.payroll` | HRPY-002, HRPY-005 | HR / Payroll | Finalized run retains sufficient inputs/rule versions to reproduce/explain outcome. |
| HRPY-007 | Post-lock correction/adjustment path | Mandatory V1 | `hr.payroll` | HRPY-005 | HR / Payroll | Corrections are explicit adjustments/reversals/amendments, never hidden mutation of finalized history. |
| HRPY-008 | Payslip | Mandatory V1 | `hr.payroll` | HRPY-005, PLT-011 | HR / Payroll | Reviewable employee payroll output. Distribution channel can remain operational/manual in V1. |
| HRPY-009 | Payroll export | Mandatory V1 | `hr.payroll` | HRPY-005, PLT-012 | HR / Payroll | CSV/Excel/accounting-friendly export contract; vendor-specific ERP posting is later adapter work. |
| HRPY-010 | Payroll payment status | Mandatory V1 | `hr.payroll` | HRPY-005 | HR / Payroll | Mark approved payroll as unpaid/paid with audit/reference. V1 does not execute bank payments. |

### Reporting and optional HR capabilities

| ID | Capability | Scope | Entitlement | Depends on | Authoritative owner | V1 boundary |
|---|---|---|---|---|---|---|
| HRR-001 | Core operational reports | Mandatory V1 | Included with owning HR capabilities | Relevant domain | Owning HR domains | Attendance/leave/payroll summaries and exports needed to operate/reconcile V1. |
| HRC-001 | Contract management | Deferred | `hr.contracts` | HRP-001, PLT-011 | HR / Contracts | Contract documents, dates, renewals and expiry alerts remain optional post-V1 capability. |
| HRD-001 | Employee document management | Deferred | `hr.documents` | HRP-001, PLT-011 | HR / Documents | General employee DMS is not required for payroll/attendance V1. |
| HRS-001 | Full Employee Self-Service | Deferred | `hr.ess` | HRP-004 + target HR capabilities | HR UX boundary | Mobile attendance may have a focused employee punch surface without building full ESS. |
| HRS-002 | Full Manager Self-Service | Deferred | `hr.mss` | PLT-006 + target HR capabilities | HR UX boundary | Managers may receive the minimal V1 review surfaces needed for attendance/leave without a broad MSS product. |
| HRA-001 | Advanced approval engine | Deferred | `hr.advanced_approvals` | Concrete domain cases | Not assigned yet | No generic workflow engine in V1. |
| HRTAL-001 | Recruitment / performance / training | Deferred | Future HR entitlements | HRP-001 | Future HR/Talent domains | Explicitly outside first commercial release. |
| HREXP-001 | Employee expense management | Deferred | Future | HRP-001 | Future HR/Expense capability | Not part of advances/payroll subledger. |
| HRAN-001 | Advanced workforce analytics / AI | Deferred | Future | Mature domain data | Future analytics | Core reports first; no speculative analytics platform. |

## Strict dependency rules

Dependencies are deliberately minimal. Commercial bundles can combine capabilities, but architecture must not manufacture dependencies that are not logically required.

### Mandatory dependency graph

```text
Platform Tenant
  -> Authentication / Membership / Explicit Tenant Context
  -> Tenant Isolation / Authorization
  -> Entitlements

Tenant
  -> Legal Entity
  -> Sites

HR People
  -> Employment / Employer relationship referencing Legal Entity
  -> Attendance
  -> Leave
  -> Employee Finance
  -> Payroll
  -> Contracts [later]

Payroll
  -> People + Employment/Compensation + Payroll Configuration
  <- approved inputs from Attendance [when enabled]
  <- approved inputs from Leave [when enabled]
  <- approved inputs from Employee Finance [when enabled]
```

### Important non-dependencies

- Payroll must not require digital Contract Management.
- Payroll must not require Attendance to be commercially enabled.
- Leave must not require Attendance.
- Employee Finance must not require Attendance.
- Biometric attendance must not require Mobile Attendance.
- Mobile Attendance must not require Biometric attendance.
- An Employee must not require a User account.
- A disabled optional capability must not make historical finalized payroll unreproducible.
- Platform Legal Entity identity must not depend on HR/Payroll being enabled.
- Wave 1 commercial entitlement truth must not depend on a Subscription/Billing subsystem.

## Entitlement behavior

V1 entitlement evaluation must follow these principles:

1. Entitlement is enforced at an authoritative server/data boundary, not only in navigation.
2. Tenant lifecycle/access state is checked independently; a valid Entitlement cannot reopen a suspended/archived Tenant.
3. UI for a disabled optional capability should disappear or become structurally unavailable; do not show dead controls as the default UX.
4. Capability dependency validation prevents impossible configurations.
5. Capability removal/suspension/expiry must never automatically delete customer data.
6. Historical financial/compliance records remain preserved. Read/export behavior after entitlement loss is specified per sensitive capability rather than handled by destructive deletion.
7. Limits are explicit values such as employee/site/device limits, not package-name conditionals.
8. **Direct effective-dated Tenant Capability grants/denials and Limits are the Wave 1 commercial-access source of truth.** Plans/bundles/subscriptions may later compose into the same evaluation contract but are not required to make Wave 1 coherent.
9. An optional `valid_until` ends a grant authoritatively at evaluation time without requiring Tenant suspension.
10. In-flight records affected by entitlement/limit changes require an explicit continuation, read-only, correction, export, or closure rule; they must not become hidden stranded state.

## V1 commercial-control boundary

V1 needs a **Control Plane**, not a full billing company inside the product.

Tech Edge must be able to:

- onboard a Tenant;
- establish its initial Legal Entity and Sites;
- assign effective-dated Capability grants/denials and Limits;
- record a bounded commercial/source reference and reason where needed;
- inspect effective Entitlement state and validity;
- suspend/reactivate Tenant access safely;
- archive and explicitly restore a Tenant through governed recovery;
- inspect core Tenant status;
- preserve an audit trail of sensitive Platform operations.

V1 deliberately does **not** require a Subscription/Commercial Agreement entity as product authority. Manual selling/contract administration may occur operationally outside the product while the Platform stores the direct effective-dated grants/limits that determine product access.

V1 also does **not** require:

- public self-signup;
- automatic card charging;
- coupons/promotions engine;
- complex invoicing/payment reconciliation portal;
- automated revenue recognition;
- partner commission accounting;
- a general commercial CRM.

These can be added when real volume justifies them without changing the entitlement architecture. Until then, the Tech Edge control plane and direct grants/limits are the explicit operational boundary for commercial product access.

## Personas for V1 acceptance

These are acceptance personas, not a frozen universal role enum.

- **Tech Edge Platform Operator** — operates Tenants, direct commercial access grants/limits, lifecycle/recovery, and Platform authority according to separately governed Operator permissions.
- **Tenant Owner / Admin** — administers company access and core settings within the Tenant authority boundary.
- **HR Officer** — manages people, attendance, leave and employee-finance records where entitled/permitted.
- **Payroll Officer** — prepares/reviews payroll and payroll outputs where entitled/permitted.
- **Manager / Supervisor** — performs only the bounded review/approval actions granted to that User.
- **Employee** — no account required by default; account is required only for enabled employee-facing channels such as mobile attendance.

Platform Operator bootstrap/root-of-trust and Platform role-template semantics are frozen by ADR-004 and the Platform Foundation amendments. Domain-specific HR permission/role behavior is frozen in the owning Domain Specs before those waves begin.

## Data authority map

| Data / outcome | Authoritative owner |
|---|---|
| Tenant, Membership, entitlement grants/limits, permission assignment | Platform Core |
| Platform Operator grants / operator-management authority | Platform Core, separate Platform trust boundary |
| Legal Entity and Site identity/lifecycle | Platform Core |
| Employee/employment/Employer-reference/compensation facts | HR / People |
| Raw and normalized attendance events | HR / Time |
| Attendance interpretation/exceptions/overtime facts | HR / Time |
| Leave records/balances | HR / Leave |
| Penalty/reward/advance balances and schedules | HR / Employee Finance |
| Payroll run, frozen inputs, calculation result, lock/payment state | HR / Payroll |
| External device/vendor mapping and transport state | Integration adapter layer |

An integration adapter never becomes the authority for HR or Payroll business rules.

## Explicit V1 exclusions

The following are deliberately out of scope for V1 even if technically useful later:

- microservices/service mesh/event-bus infrastructure;
- generic BPM/workflow engine;
- arbitrary tenant scripting/rule language;
- generic dynamic-form builder;
- tenant-specific code forks;
- full contract/document lifecycle;
- recruitment, performance, training and broad talent suite;
- full ESS/MSS portals;
- employee expense management;
- full accounting/GL/treasury;
- multi-country payroll localization;
- universal biometric-device support;
- continuous employee location tracking;
- native iOS/Android applications;
- broad customer-facing API/webhook platform;
- self-service SaaS billing/payment/coupon engine;
- **full Subscription/Billing/Commercial Agreement product subsystem**;
- advanced BI/AI workforce analytics.

An exclusion is not permission to leave an active V1 workflow unfinished. When an excluded capability would normally continue the process, the owning V1 Spec must define the explicit handoff/terminal boundary.

## Decisions intentionally left for formal capability Specs

Phase 0C defines product capability boundaries, amended by the Frozen Phase 0D Platform Foundation. The following domain-specific decisions must be frozen before their implementation begins:

- exact supported pay bases and payroll component formulas;
- Egypt statutory calculation details and effective-date mechanics;
- exact work-schedule variants and attendance rounding/grace rules;
- leave accrual and carry-forward rules;
- overtime policy variants;
- penalty/reward semantics and approval requirements;
- advance installment edge cases;
- HR-domain permission mappings/default role templates beyond the accepted Platform Foundation roles;
- exact biometric vendor/protocol selected for first adapter;
- mobile geofence radius, spoofing/risk handling, offline behavior and privacy UX.

Platform Foundation implementation details that remain intentionally non-material include physical table/schema names, exact indexes, and the concrete choice among implementation mechanisms expressly allowed by the Accepted ADRs. They are not permission for Codex to invent product behavior.

Every formal capability Spec must also include its Workflow Completion Map: entry, intermediate state ownership, final states, rejection/cancellation where relevant, correction/reversal/reopen paths, reconciliation/external handoff, behavior when entitlement/permission changes affect in-flight work, historical visibility, and post-V1 operational depth deliberately deferred.
