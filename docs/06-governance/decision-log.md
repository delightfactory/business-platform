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
| DEC-008 | 2026-09-04 | Legacy systems are donor platforms only. Reuse requires explicit extraction audit and classification before code adoption. | Accepted |
| DEC-009 | 2026-09-04 | Repository is documentation-first during Phase 0; feature development begins only after required baselines are reviewed. | Accepted |
| DEC-010 | 2026-09-04 | Adaptive web application experience with shared design-system primitives is required. | Accepted |
| DEC-011 | 2026-09-04 | V1 uses Tech Edge-operated Tenant/commercial-access control with effective-dated capability grants/limits; full billing subsystem deferred. | Accepted |
| DEC-012 | 2026-09-04 | Payroll consumes explicit approved inputs and does not technically depend on Attendance/Leave/Employee Finance entitlements. | Accepted |
| DEC-013 | 2026-09-04 | V1 Attendance is source-neutral with manual/import paths, one prioritized biometric connector, and optional mobile geofence. | Accepted |
| DEC-014 | 2026-09-04 | Full Contracts/Documents, ESS/MSS, advanced workflows and Talent are deferred from V1. | Accepted |
| DEC-015 | 2026-09-04 | Entitlement removal must never destroy data or make finalized history unreproducible. | Accepted |
| DEC-016 | 2026-09-04 | Every material workflow requires a supported end state or explicit handoff; no dead-end workflows. | Accepted |
| DEC-017 | 2026-09-05 | ADR-001 through ADR-010 are the architecture baseline and Foundation freeze gate. | Accepted |
| DEC-018 | 2026-09-05 | Platform lifecycle, Operator authority, invitation lifecycle and effective access rules are hardened baseline constraints. | Accepted |
| DEC-019 | 2026-09-05 | Operator bootstrap and deterministic entitlement semantics require protected consistency and fail-closed ambiguity handling. | Accepted |
| DEC-020 | 2026-09-28 | Complexity shielding is a product-wide constraint. | Accepted |
| DEC-021 | 2026-09-28 | Attendance channels remain vendor-neutral until a reviewed adapter specification exists. | Accepted |
| DEC-022 | 2026-09-28 | Final Implementation Readiness Amendment is accepted as a governing clarification. It expands Cube 0 scope, clarifies authorization boundaries, branding identity ownership, People/Attendance ownership, Payroll Calendar behavior and cube completion contracts. | Accepted |

## Decision states

- Proposed — under review.
- Accepted — approved and constraining implementation.
- Superseded — replaced by later decision.
- Rejected — considered and not adopted.

## Rule

Material decisions should receive dedicated ADRs when they require technical rationale, alternatives, consequences or migration implications.