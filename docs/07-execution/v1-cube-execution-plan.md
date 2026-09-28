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

Cube 0 completion means a new organization can exist independently, have its own identity, users, permissions and operate through the application experience safely across devices.

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
- Effective work-policy assignment.
- Compensation foundation.

People owns employee context. It does not calculate attendance.

## Cube 2 — Attendance Engine

Goal:
Convert attendance evidence into trusted work facts.

Includes:

- Work policies.
- Shift definitions.
- Attendance events.
- Interpretation engine.
- Overnight shifts.
- Missing punch handling.
- Exceptions.
- Corrections.

Attendance owns time interpretation and calculations.

## Cube 3 — Leave Management

Goal:
Manage leave lifecycle with clear downstream effects.

Includes:

- Leave types.
- Balances.
- Leave records.
- Approval path.
- Payroll input effects.

## Cube 4 — Payroll Core

Goal:
Produce reliable payroll results.

Includes:

- Payroll calendar.
- Cutoff configuration.
- Payroll periods.
- Salary components.
- Adjustments.
- Advances.
- Calculation.
- Review.
- Approval.
- Lock.
- Payslips.
- Exports.
- Payment status.
- Correction/amendment paths.

## Cube 5 — Attendance Channels

Goal:
Connect attendance sources safely.

Includes:

- Import channels.
- Mobile attendance.
- Vendor-neutral biometric boundary.
- Device adapters only after approved vendor specification.

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