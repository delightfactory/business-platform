# Final Implementation Readiness Amendment — Business Platform V1

## Status

Accepted amendment before Cube 0 execution. Final documentation alignment approved 2026-09-29.

## Purpose

This amendment converts architecture review findings into implementation-governing decisions. It does not change the platform vision or modular architecture. It removes ambiguity between specifications, execution cubes and acceptance criteria.

## Amended documents

This amendment governs the following scoped clarifications. The referenced specifications are aligned in the same final documentation revision; their other rules remain in force:

- `docs/07-execution/v1-cube-execution-plan.md`
  - Cube scope and completion contract.
- `docs/04-product-specs/tenant-branding-capability-spec.md`
  - Domain usage and official-document identity boundary.
- `docs/04-product-specs/authorization-access-control-v1-spec.md`
  - V1 scope, Platform Operator separation, and custom-role boundary.
- `docs/04-product-specs/employee-finance-payroll-spec.md`
  - Payroll period identity and post-lock correction after a recorded payment.
- `docs/04-product-specs/payroll-calendar-and-cutoff-amendment.md`
  - Employer scope and non-overlapping calendar transitions. The earlier illustrative change from `01 Jan–31 Jan` straight to `26 Jan–25 Feb` overlapped six dates; it is replaced by an explicit `01 Feb–25 Feb` transition before `26 Feb–25 Mar`.
- `docs/03-architecture/adr/ADR-008-authoritative-data-access-and-transaction-boundaries.md`
  - Authoritative Access Matrix, tenant-scoped normal read: the prior shorthand included Operator authority in the ordinary direct-read row; Operator reads/actions are clarified as server-only Operator commands under their dedicated row. This closes an alternate-path ambiguity without widening access.
- `docs/05-engineering/frontend-ux-baseline.md` and `docs/02-blueprint/v1-implementation-waves.md`
  - V1 Arabic-first/RTL acceptance, replacing conditional language-readiness wording for the initial Egypt release.
- `docs/04-product-specs/hr-people-work-context-spec.md`, `attendance-leave-spec.md`, `employee-finance-payroll-spec.md`, and `attendance-channel-spec.md`
  - Lifecycle status only, after the final freeze review; business behavior changes only where separately named above.

## Source of truth rule

Use the scoped authority order and conflict-resolution process in `docs/06-governance/source-of-truth.md`. This amendment does not create a second hierarchy. An explanatory document does not modify behavior unless it explicitly names the governing baseline and affected section, and is accepted through the normal review process.

## Cube 0 — Platform Foundation & Experience Layer (complete scope)

Cube 0 is complete only when the following capabilities are implemented together:

### Tenant foundation

- Tenant lifecycle.
- Tenant isolation.
- Legal Entity foundation.
- Sites.
- Tenant settings foundation.
- Tenant branding foundation.

### Identity and access foundation

- Users.
- Memberships.
- Invitations.
- Roles.
- Permissions.
- Authorization enforcement.
- Audit of sensitive access changes.
- Platform Operator separation.

### Platform operations

- Entitlements.
- Limits.
- Operator control flows.
- Effective dating/versioning primitives.
- Recovery-safe administrative operations.

### Experience foundation

- Application shell.
- Design system primitives.
- Responsive navigation.
- Mobile/tablet/desktop layouts.
- Shared states and feedback patterns.

For the initial Egypt V1 release, primary user-facing workflows use Arabic and RTL. Cube 0 proves the shell and representative administration, invitation, Tenant-switch, and denial/recovery states across mobile, tablet, and desktop. Date, number, and EGP formatting are checked in those flows. This does not require a generic localization engine or a language switcher in Cube 0.

## Authorization V1 boundary

V1 authorization is based on:

- Tenant membership.
- Roles.
- Permissions.
- Tenant custom-role capability where a confirmed V1 workflow needs it; an advanced self-service role editor is not a default Cube 0 deliverable.
- Audited role/permission changes.

Deferred:

- Attribute based access control.
- Generic policy engines.
- Enterprise IAM workflows.
- Complex permission inheritance.

Platform Operator authority remains separate from Tenant roles according to ADR-004.

## Branding and identity boundary

Tenant branding controls experience identity.

Legal Entity identity controls official business documents where a legal employer identity is required.

An official document that requires an Employer Legal Entity must resolve that entity's required legal identity before generation; missing legal identity blocks the document with an actionable setup error. Tenant branding may provide visual defaults, but neither Tenant display name nor Platform identity substitutes for the legal Employer. Platform identity remains a fallback for application chrome and non-official surfaces. Historical documents preserve the resolved legal and visual identity context used when generated.

## People and Attendance boundary

People owns:

- Employee identity.
- Employment relationship.
- Assignment context.
- Effective work-policy assignment.

Attendance owns:

- Shift interpretation.
- Attendance calculation.
- Exceptions.
- Corrections.

People assigns context; Attendance interprets time.

Cube 1 establishes the bounded named Work Policy and Shift templates needed for an effective assignment when Attendance is enabled. Time owns their definitions; People owns the Employee assignment. An Employee and Payroll can operate without Attendance entitlement. Cube 2 adds attendance interpretation and correction behavior.

## Payroll Calendar rule

Payroll periods are not assumed to be calendar months.

Each Employer Legal Entity within a Tenant has one active effective Payroll Calendar defining:

- Frequency.
- Cutoff rule.
- Generated period boundaries.
- Payment cycle.

Rules:

- periods cannot overlap.
- periods cannot contain gaps in an active calendar.
- locked periods cannot be rewritten.
- cutoff changes are effective-dated.
- a cutoff change starts after the last generated period and creates an explicit reviewed transition period when needed;
- any recorded payment prevents replacement of the locked payable run; corrections use a linked adjustment or approved external settlement that reconciles paid and remaining amounts.

## Cube completion contract

A cube is complete only when:

### Functional

- Full business workflows.
- Validation.
- Error handling.
- Empty/loading states.
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

## Anti-overengineering boundary

Do not introduce without a proven V1 requirement:

- Microservices.
- Generic workflow engines.
- Generic rules engines.
- Dynamic builders.
- Speculative integrations.

The goal is maximum product quality with minimum unnecessary complexity.

## Release readiness

Completing Cubes 0-5 is not automatically production readiness. A final qualification gate remains required for:

- operational recovery.
- customer onboarding.
- security verification.
- legal/statutory validation.
- pilot acceptance.

## Decision intent

After acceptance of this amendment and alignment of referenced specifications, Cube 0 can begin implementation with a single consistent execution contract.
