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

## Design System and Application Shell Gate

Before implementing domain screens, establish the shared application experience foundation.

Required first-class foundations:

- responsive application shell;
- navigation patterns appropriate to desktop, tablet and mobile;
- shared design tokens;
- typography, spacing and semantic color system;
- reusable form, table, card, dialog, sheet, drawer and feedback primitives;
- loading, empty, validation, error and success state patterns;
- accessibility and interaction behavior in shared components.

Domain screens must compose approved primitives and must not create isolated visual systems.

## Device experience requirements

The application must not behave as a desktop website squeezed into smaller screens.

Every material workflow must be designed for:

- mobile: native-style touch workflow, compact forms, reachable primary actions, no unnecessary horizontal scrolling;
- tablet: intentional intermediate composition, not accidental breakpoint behavior;
- laptop/desktop: productive business application experience with appropriate density, tables, comparison and keyboard/pointer efficiency;
- large desktop where relevant: avoid excessive stretching and preserve hierarchy.

Responsive behavior is part of feature completeness, not post-release polish.

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
- desktop, tablet and mobile UX acceptance;
- visual/interaction evidence for material user-facing workflows;
- exact revision qualification before merge.
