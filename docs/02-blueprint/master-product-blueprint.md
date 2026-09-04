# Master Product Blueprint

## Platform shape

```text
Business SaaS Platform
|
+-- Platform Core
|
+-- HR & Payroll Domain        [first commercial domain]
+-- CRM Domain                 [future]
+-- Sales Domain               [future]
+-- Inventory Domain           [future]
+-- Procurement Domain         [future]
+-- Finance Domain             [future]
```

## Platform Core

The Platform Core contains only reusable, business-neutral capabilities required across domains:

- tenant / organization identity;
- organization structure foundation;
- authentication and membership;
- authorization foundation;
- subscriptions and entitlements;
- configuration foundation;
- audit foundation;
- notification foundation;
- files/documents foundation;
- integration/API foundation.

Only the minimum production-grade subset required by active domains should be implemented at any point in time.

## First business domain: HR & Payroll

The initial HR domain is decomposed conceptually into:

- People;
- Time & Attendance;
- Leave;
- Employee Finance;
- Payroll;
- Contracts [optional capability];
- Documents [optional capability];
- Advanced Approvals [optional capability];
- ESS/MSS [progressive capability];
- Talent [later].

### Employee Core versus Contract Management

An employee can exist and participate in attendance and payroll without requiring a digital contract record.

The minimum employment context should be sufficient to establish operational and payroll relationships. Contract document lifecycle, renewals, expiry tracking, and similar functions remain an optional capability.

## HR V1 golden flow

```text
Employee
  -> Work Policy / Shift
  -> Attendance Events
  -> Attendance Interpretation / Exceptions
  -> Leave / Overtime
  -> Penalties / Rewards / Advances
  -> Payroll Run
  -> Review
  -> Approval
  -> Lock / Finalize
  -> Payslip / Export
```

Raw attendance data must not silently become irreversible financial impact. Interpretation, policy application, review, and payroll finalization are separate concerns.

## Attendance source model

Attendance is source-neutral. Inputs may include:

- biometric devices;
- mobile geofence/location punch;
- administrative/manual entry;
- file import;
- external APIs;
- future attendance channels.

Inputs are normalized before attendance policy and payroll logic consume them.

## Product experience model

The primary product surface is a professional web application with an adaptive application experience across screen classes.

- Desktop and laptop should provide a desktop-class business application experience with efficient information density, stable navigation, and productive review/data workflows.
- Mobile should provide a deliberately composed, native-style application experience rather than a compressed desktop layout.
- Tablet/intermediate layouts must be intentional where interaction or information structure materially changes.
- Shared application-shell, design-token, component, form, feedback, navigation, accessibility, and responsive primitives should be centrally governed and reused across domains.
- UX consistency includes workflow behavior and system states, not only styling.

Detailed frontend behavior and quality rules are governed by `docs/05-engineering/frontend-ux-baseline.md`.

## Commercial capability model

Stable capabilities are exposed as entitlements. Commercial package names are compositions of entitlements rather than code paths.

This enables different tenant configurations without separate product forks.

## Architecture direction

Initial architecture direction: **modular monolith with explicit domain boundaries**.

This is a direction, not permission for hidden coupling. Domains must have clear ownership and interfaces so future extraction remains possible if scale or organizational needs justify it.

## Expansion rule

Future business capabilities are introduced as domains that reuse Platform Core. HR entities must not become universal platform entities merely because HR was built first.
