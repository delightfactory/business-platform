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

## Decision states

- **Proposed** — under review, not an implementation assumption.
- **Accepted** — approved and may constrain implementation.
- **Superseded** — replaced by a later decision; history remains.
- **Rejected** — considered and explicitly not adopted.

## Rule

Material decisions should later receive a dedicated ADR when they require technical rationale, alternatives, consequences, or migration implications. This log remains the high-level index.
