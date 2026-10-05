# V1 Cube Execution Plan — Business Platform HR SaaS

## Purpose

This document converts the V1 roadmap into implementation cubes. A cube is complete only when its capability, UX, security, tests, documentation and operational workflow are complete.

The objective is maximum product quality with minimum unnecessary complexity.

## Cube execution rules

Every cube must:

- follow Accepted ADRs and Frozen Product Specifications;
- complete business workflows, not isolated screens;
- avoid dead-end states;
- hide technical complexity from users;
- support mobile, tablet and desktop experiences;
- provide acceptance evidence before moving forward.

## Cube 0 — Platform Foundation & Experience Layer

Goal:
Create the complete reusable SaaS foundation.

### Tenant foundation

Includes:

- Tenant lifecycle.
- Tenant isolation.
- Legal Entity foundation.
- Sites.
- Tenant settings foundation.
- Tenant branding foundation.

### Identity and access foundation

Includes:

- Users.
- Memberships.
- Invitations.
- Roles.
- Permissions.
- Authorization enforcement.
- Platform Operator separation.
- Sensitive access audit.

### Platform operations

Includes:

- Entitlements.
- Limits.
- Operator control flows.
- Effective dating/versioning primitives.
- Recovery-safe administrative operations.

### Experience foundation

Includes:

- Application shell.
- Design system primitives.
- Responsive navigation.
- Mobile/tablet/desktop layouts.
- Shared feedback states.
- Arabic-first RTL behavior and consistent date/number/EGP presentation for the initial Egypt release.

Cube 0 completion means a new organization can be onboarded with Legal Entity/Site, a recoverable protected administrator, bounded commercial access and branding; invited users can operate only in their authorized Tenant, while Tech Edge can manage lifecycle/recovery through audited Operator flows. The representative admin and Operator journeys work across mobile, tablet and desktop, and the Platform Foundation qualification matrix passes on a clean environment.

## Cube 1 — People Foundation

Goal:
Manage workforce identity and employment context.

Includes:

- Employee core.
- Employment relationship.
- Departments.
- Jobs.
- Sites context.
- Reporting context.
- Work assignments.
- Bounded named Work Policy and Shift template definitions owned by Time, sufficient for assignment when Attendance is enabled.
- Effective work-policy assignment where Attendance is enabled; People and Payroll onboarding do not require that entitlement.
- Compensation foundation.
- Workforce bulk import with validation and reject reporting.

People owns employee context and effective assignments; Time owns the named policy/shift definitions. Cube 1 does not interpret attendance.

Completion: A company can create or import employees, update employment and assignments, transfer them, change compensation, end employment and rehire while preserving history and a visible manual-review handoff for possible locked-payroll effects.

Payroll boundary: Cube 1 has no Payroll runs or locks. People preserves dated versions and audit context and warns HR when a manual Payroll review may be needed; it does not detect locked periods or create correction requests. A same-transaction guard against affected locked runs and explicit correction routing is a hard gate before Payroll consumes People changes. This is a downstream prerequisite, not a capability implemented in Cube 1.

## Cube 2 — Attendance Engine

Goal:
Convert attendance evidence into trusted work facts.

Includes:

- Effective Work Policy/Shift interpretation parameters.
- Attendance events.
- Manual/admin event entry.
- Validated spreadsheet attendance import.
- Interpretation engine.
- Overnight shifts.
- Missing punch handling.
- Exceptions.
- Corrections.
- Approved, versioned non-financial Payroll input facts.

Attendance owns time interpretation and calculations.

Completion: Manual and spreadsheet sources produce trusted attendance facts. Clean days follow the configured approval path, while missing or ambiguous evidence remains in an owned review queue with correction and downstream handoff.

## Cube 3 — Leave Management

Goal:
Manage leave lifecycle with clear downstream effects.

Includes:

- Leave types.
- Balances.
- Leave records.
- Approval path.
- Payroll input effects.
- Bounded own-Leave view, request, and pre-approval withdrawal for a linked Employee; full ESS/MSS remains deferred.
- Separate Leave Calendar and configured Leave-Year account periods.

Completion: HR can record Leave for Employees with or without User accounts; a linked Employee can view only their own profile, Leave, and balance and submit/withdraw their own pending request. Registration/submission and approval are separate audited actions; approved cancellation is requested by the Employee and decided by HR. Leave transitions are bounded and owned, annual grants are unique per Employer + Employee + Leave Type + configured account period independent of policy version, pending requests do not reserve balance, and approval plus consumption is atomic. Historical Leave remains available for authorized closure when `hr.people` or `hr.leave` is disabled, without new records or balance growth. Approved Leave facts are exposed only at the unconsumed Payroll projection boundary; Cube 3 does not calculate money, lock Payroll, or silently alter approved Attendance facts. Full Cube 3 closure requires implemented calculations for any enabled mandatory V1 annual-entitlement and half-day behavior. Working-day counting/holiday exclusion and the permitted `0.5` balance unit are fixed; proration/rounding, category changes, and half-day timing remain gated on legal/compliance verification. Independent request/review/ledger slices may proceed while dependent cases are held. See the [Cube 3 Leave execution contract](cube-3-leave-execution-contract.md).

## Cube 4 — Payroll Core

Goal:
Produce reliable payroll results.

Includes:

- Payroll calendar.
- Cutoff configuration.
- Payroll periods.
- Salary components.
- Penalty/reward adjustments and approved inputs.
- Advances, installments, settlement and balance reconciliation.
- Versioned Egypt statutory rule packs and opening YTD values.
- Calculation.
- Review.
- Approval.
- Lock.
- Payslips.
- Exports.
- Payment status.
- Correction/amendment paths.
- Core payroll variance, statutory, outstanding-balance and payment reports.

Completion: Payroll runs with People and compensation even when Attendance/Leave/Employee Finance are not entitled; enabled domains contribute approved inputs. An authorized team can calculate, review, approve, lock, issue payslips/exports, record and reconcile payment, and correct results without rewriting locked history. Production statutory qualification remains part of the release gate.

## Cube 5 — Attendance Channels

Goal:
Connect attendance sources safely.

Includes:

- One prioritized biometric/device connector behind the approved vendor sub-gate.
- Mobile attendance.
- Vendor-neutral biometric boundary.
- Source mapping, replay/idempotency and visible connector health/failure states.

Spreadsheet attendance import belongs to Cube 2. A vendor-specific adapter starts only after its reviewed hardware/protocol sub-spec.

Completion: Enabled mobile and qualified device channels submit to the same canonical Attendance model without source-specific time or payroll rules; a failed, unmapped or offline event has a visible retry/recovery outcome. Support is claimed only after real device/mobile acceptance evidence for the chosen channel.

## Quality gates for every cube

### Functional

- Complete workflow.
- Validation.
- Error handling.
- Loading/empty states.
- Correction paths.

### Security

- Tenant isolation tests.
- Authorization negative tests.
- Sensitive action audit.

### Data integrity

- Migration reproducibility.
- Historical correctness.
- Effective-date behavior.

### UX

- Mobile acceptance.
- Tablet acceptance.
- Desktop acceptance.
- Design system compliance.
- No unnecessary technical complexity exposed.

### Engineering

- Domain boundaries respected.
- Business logic not hidden inside UI.
- No premature abstraction.
- No unnecessary generic frameworks.

## Release qualification gate

Completing Cubes 0-5 does not automatically mean production release readiness. Final qualification includes:

- operational recovery verification;
- customer onboarding validation;
- security verification;
- statutory/legal validation;
- pilot acceptance.

## Completion principle

Build each cube completely, validate it, then move forward. Never weaken current quality to create future functionality.

## Proposed Cube 4 execution detail (2026-10-02)

The [proposed additive UX extension](cube4UXextension.md), [proposed execution contract](cube-4-execution-contract.md), [decision and acceptance register](cube-4-decision-acceptance-register.md), and [current source lock review](cube-4-lock-graph-review.md) provide reviewable planning detail. They do not declare policy acceptance, Cube 3 gate closure, Cube 4 completion, or production readiness. Their affected decisions and implementation gates must close under the existing source-of-truth process.
