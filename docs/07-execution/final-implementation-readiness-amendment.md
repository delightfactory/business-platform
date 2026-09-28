# Final Implementation Readiness Amendment — Business Platform V1

## Status

Accepted amendment before Cube 0 execution.

## Purpose

This amendment converts architecture review findings into implementation-governing decisions. It does not change the platform vision or modular architecture. It removes ambiguity between specifications, execution cubes and acceptance criteria.

## Amended documents

This amendment governs clarification updates to:

- `docs/07-execution/v1-cube-execution-plan.md`
  - Cube scope and completion contract.
- `docs/04-product-specs/tenant-branding-capability-spec.md`
  - Tenant branding versus legal identity boundary.
- `docs/04-product-specs/authorization-access-control-v1-spec.md`
  - Authorization V1 boundaries.
- `docs/04-product-specs/employee-finance-payroll-spec.md`
  - Payroll calendar behavior.
- HR domain specifications where lifecycle status requires alignment.

## Source of truth rule

The implementation authority order is:

1. Accepted ADRs.
2. Frozen Product Specifications.
3. Accepted execution plans.
4. Implementation tasks generated from those artifacts.

An explanatory document does not modify behavior unless it explicitly declares the documents and sections it amends and is accepted through the normal review process.

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

## Authorization V1 boundary

V1 authorization is based on:

- Tenant membership.
- Roles.
- Permissions.
- Custom Tenant roles where required.
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

Document identity precedence:

1. Employer Legal Entity identity.
2. Tenant branding fallback.
3. Platform identity fallback.

Historical documents preserve the identity context used when generated.

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

## Payroll Calendar rule

Payroll periods are not assumed to be calendar months.

Each Tenant Payroll Calendar defines:

- Frequency.
- Cutoff rule.
- Generated period boundaries.
- Payment cycle.

Rules:

- periods cannot overlap.
- periods cannot contain gaps in an active calendar.
- locked periods cannot be rewritten.
- cutoff changes are effective-dated.
- partial payment corrections follow amendment/adjustment paths.

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