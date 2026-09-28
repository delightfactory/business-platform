# Codex Implementation Brief — Business Platform HR Domain

## Authority

Implementation must follow the Frozen Product Specifications and Accepted ADRs in this repository.

Do not invent material product behavior inside code. If a missing decision affects domain behavior, stop at that boundary and raise a specification amendment.

## Build sequence

1. Wave 1 — Platform Spine
   - Tenant
   - Legal Entity
   - Sites
   - Authentication
   - Membership
   - Authorization
   - Entitlements
   - Audit
   - Temporal/versioning foundation

2. Wave 2 — People & Work Context
   - Employee Core
   - Employment
   - Compensation facts
   - Work assignments
   - Workforce import

3. Wave 3 — Attendance & Leave
   - Canonical attendance events
   - Interpretation
   - Exceptions
   - Corrections
   - Overtime inputs
   - Leave

4. Wave 4 — Employee Finance & Payroll
   - Payroll configuration
   - Inputs boundary
   - Calculation
   - Review
   - Approval
   - Lock
   - Payslip/export/payment status

5. Wave 5 — Attendance Channels
   - Vendor-neutral channel contracts
   - Mobile attendance
   - Biometric adapter only after approved vendor adapter specification

## Non-negotiable engineering rules

- Domain logic must not live inside UI pages.
- Tenant isolation is authoritative below the UI.
- Employee is not User.
- Payroll history is immutable after lock.
- Corrections use explicit amendment/adjustment paths.
- Attendance events are evidence, not direct money mutations.
- No generic workflow engine, rules engine or speculative abstraction.

## UX quality rule

The system must hide implementation complexity from users.

Every workflow should:

- start from the user's business goal;
- minimize required input through defaults and derived values;
- reveal advanced options progressively;
- focus users on exceptions requiring action;
- explain failures in business language;
- preserve clarity of financial/security/compliance consequences.

A technically working feature that exposes backend complexity is not complete.

## Required verification

Every wave requires:

- migration reproducibility;
- tenant isolation tests;
- authorization negative tests;
- lifecycle completion tests;
- correction/reversal tests where applicable;
- desktop and mobile UX acceptance;
- exact revision qualification before merge.
