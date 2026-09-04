# Decision Log

This log records product and architecture decisions that materially constrain future implementation.

| ID | Date | Decision | Status |
|---|---|---|---|
| DEC-001 | 2026-09-04 | The product is a domain-oriented Business SaaS Platform; HR & Payroll is the first commercial domain, not the platform root. | Accepted |
| DEC-002 | 2026-09-04 | Platform Core must remain business-domain neutral. | Accepted |
| DEC-003 | 2026-09-04 | Initial architecture direction is a modular monolith with explicit domain boundaries; no premature microservices. | Accepted |
| DEC-004 | 2026-09-04 | Payroll is required in the first commercially sellable HR release. | Accepted |
| DEC-005 | 2026-09-04 | Digital contract management is optional; an employee can participate in attendance/payroll without a system-managed contract document. | Accepted |
| DEC-006 | 2026-09-04 | Product complexity is progressive: optional capabilities must not burden tenants that do not use them. | Accepted |
| DEC-007 | 2026-09-04 | Commercial packaging is implemented through capabilities/entitlements rather than hard-coded package-specific product branches. | Accepted |
| DEC-008 | 2026-09-04 | Legacy systems are donor platforms only. Reuse requires an explicit extraction audit and classification before code is adopted. | Accepted |
| DEC-009 | 2026-09-04 | The repository is documentation-first during Phase 0; production feature development begins only after required product and architecture baselines are reviewed. | Accepted |
| DEC-010 | 2026-09-04 | The primary product surface is an adaptive web application: desktop/laptop must deliver a desktop-class business-app experience, mobile must deliver a purpose-designed native-style experience, and recurring UI/interaction behavior must be governed through reusable shared design-system primitives. | Accepted |
| DEC-011 | 2026-09-04 | V1 requires a Tech Edge-operated tenant/subscription control plane with entitlements and limits, while public self-service billing, payment gateways and coupon engines are deferred until commercial volume justifies them. | Accepted |
| DEC-012 | 2026-09-04 | Payroll depends on People/compensation/payroll configuration, not on Attendance, Leave or Employee Finance entitlements; enabled HR domains contribute through explicit approved payroll-input boundaries. | Accepted |
| DEC-013 | 2026-09-04 | V1 Attendance is source-neutral and includes manual entry, spreadsheet import, one prioritized biometric connector, and optional mobile geofence attendance; universal device support and continuous employee location tracking are explicitly outside V1. | Accepted |
| DEC-014 | 2026-09-04 | Full Contracts/Documents, ESS/MSS, advanced approval/workflow, Talent and Expenses are deferred from V1; focused employee/manager surfaces may exist only where required by a V1 workflow such as mobile attendance or bounded review. | Accepted |
| DEC-015 | 2026-09-04 | Removing/suspending an optional entitlement must never automatically delete tenant data or make finalized financial/compliance history unreproducible; entitlement denial is enforced authoritatively and historical-access behavior is capability-specific. | Accepted |

## Decision states

- **Proposed** — under review, not an implementation assumption.
- **Accepted** — approved and may constrain implementation.
- **Superseded** — replaced by a later decision; history remains.
- **Rejected** — considered and explicitly not adopted.

## Rule

Material decisions should later receive a dedicated ADR when they require technical rationale, alternatives, consequences, or migration implications. This log remains the high-level index.
