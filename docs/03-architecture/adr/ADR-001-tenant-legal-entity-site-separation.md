# ADR-001 — Separate Tenant, Legal Entity, and Site

## Status

**Proposed**

## Context

The platform must serve very small customers simply while preserving the ability to support multiple employers/entities and sites without re-platforming. The donor SaaS experience showed the risk of letting a single operational concept become the universal owner of unrelated data.

## Decision

Model three distinct concepts:

- **Tenant** — customer isolation/commercial boundary.
- **Legal Entity / Employer** — employment/payroll legal boundary inside the tenant.
- **Site** — domain-neutral operating/physical location.

V1 UX may create one default Legal Entity and one default Site during simple onboarding, but the persistent model and contracts must not assume one-to-one identity permanently.

## Consequences

- Tenant isolation remains stable even if a customer later adds entities/sites.
- Payroll can attach to the correct legal employer.
- HR and future domains can share Site identity without adopting HR as platform root.
- Simple customers are not forced through complex multi-entity setup.

## Rejected alternatives

### Tenant equals Legal Entity

Rejected because multi-entity customers would require structural migration and commercial/isolation concepts would become mixed with employment law concepts.

### Branch is the universal organization object

Rejected because future domains may need sites/locations without adopting service-center or HR semantics.

## Constraints

- deactivation is preferred over destructive deletion once historical references exist;
- Site does not own a separate role/permission system;
- tenant-owned business records remain tenant-scoped even when they also reference legal entity/site.
