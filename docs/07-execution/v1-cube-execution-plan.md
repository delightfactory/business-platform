# V1 Cube Execution Plan — Business Platform HR SaaS

## Purpose

This document converts the V1 implementation roadmap into execution cubes. A cube is considered complete only when its capability, UX, security, tests, documentation and operational flow are complete.

The objective is not the fastest feature delivery. The objective is a strong foundation with minimum unnecessary complexity.

## Cube execution rules

Every cube must:

- follow Frozen Product Specs and Accepted ADRs;
- complete its full business workflow, not isolated screens;
- avoid dead-end states;
- avoid speculative abstractions and over-engineering;
- hide technical complexity from users;
- provide responsive experiences for mobile, tablet and desktop;
- include acceptance evidence before moving to the next cube.

A cube is not complete because the code compiles or a happy path works.

## Cube 0 — Platform Foundation & Experience Layer

Goal:
Create the reusable SaaS foundation.

Includes:

- Tenant model.
- Tenant isolation.
- Tenant branding foundation.
- Users and memberships.
- Roles and permissions.
- Audit foundation.
- Effective dating/versioning primitives.
- Application shell.
- Design system.
- Responsive navigation and layouts.

Completion:

A new organization can exist independently, have its own identity, users and permissions, and the application experience works correctly across devices.

## Cube 1 — People Foundation

Goal:
Manage workforce identity and employment context.

Includes:

- Employee core.
- Employment relationship.
- Departments.
- Jobs.
- Sites.
- Reporting context.
- Work assignments.
- Compensation foundation.

Completion:

A company can onboard employees, update their employment context, transfer them, end employment and preserve history.

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

Completion:

Normal attendance flows automatically, while exceptional cases have clear review and correction paths.

## Cube 3 — Leave Management

Goal:
Manage employee leave without unnecessary complexity.

Includes:

- Leave types.
- Balances.
- Leave records.
- Approval flow.
- Payroll impact inputs.

Completion:

Leave has complete lifecycle handling from creation to approval/cancellation and downstream impact.

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

Completion:

Payroll can be prepared, reviewed, finalized and corrected without rewriting history.

## Cube 5 — Attendance Channels

Goal:
Connect attendance sources safely.

Includes:

- Import channels.
- Mobile attendance.
- Vendor-neutral biometric boundary.
- Device adapters only after approved vendor specification.

Completion:

Attendance sources feed the same trusted attendance model without coupling the product to a specific vendor.

## Quality gates for every cube

### Functional

- Complete workflow.
- Validations.
- Error handling.
- Empty/loading states.
- Correction paths.

### Security

- Tenant isolation tests.
- Authorization tests.
- Sensitive action audit.

### Data integrity

- Migration reproducibility.
- Historical correctness.
- Version/effective-date behavior.

### UX

- Mobile acceptance.
- Tablet acceptance.
- Desktop acceptance.
- Shared design system compliance.
- No unnecessary complexity exposed to users.

### Engineering

- Domain boundaries respected.
- No business logic hidden inside UI.
- No unnecessary generic frameworks.
- No premature abstraction.

## Anti-overengineering rules

Do not introduce unless a real V1 requirement exists:

- generic workflow engines;
- generic rules engines;
- microservices;
- broad configuration builders;
- dynamic forms everywhere;
- speculative integrations;
- enterprise complexity unsupported by actual workflows.

## Completion principle

Build each cube completely, validate it, then move forward. Do not create future functionality by weakening current quality.