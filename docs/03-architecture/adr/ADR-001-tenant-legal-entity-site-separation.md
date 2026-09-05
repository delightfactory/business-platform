# ADR-001 — Separate Tenant, Legal Entity, and Site

## Status

**Proposed**

## Context

The platform must serve very small customers simply while preserving the ability to support multiple legal entities and sites without re-platforming. The donor SaaS experience showed the risk of letting a single operational concept become the universal owner of unrelated data.

Because HR & Payroll is only the first Business Domain, Platform Core must not define Legal Entity primarily through employment/payroll semantics. Future Finance, Sales, Procurement, Inventory, Tax, and other domains may also reference the same legal identity for their own purposes.

## Decision

Model three distinct concepts:

- **Tenant** — customer isolation/commercial-access boundary.
- **Legal Entity** — domain-neutral legal/business identity owned within the tenant.
- **Site** — domain-neutral operating/physical location.

A Business Domain may assign additional meaning to a Legal Entity without changing Platform ownership. For example, HR/Payroll may treat a Legal Entity as the legal **Employer** for an Employment/Payroll relationship, while a future Finance domain may use the same Legal Entity as an accounting/reporting boundary.

Platform Core owns only the minimum shared Legal Entity identity/lifecycle facts needed across domains. HR/payroll statutory facts, employer registrations, payroll compliance attributes, and other domain-specific legal facts remain owned by the relevant Business Domain.

V1 UX may create one default Legal Entity and one default Site during simple onboarding, but the persistent model and contracts must not assume one-to-one identity permanently.

## Consequences

- Tenant isolation remains stable even if a customer later adds entities/sites.
- HR/Payroll can attach employment and payroll to the correct legal employer without making payroll semantics part of Platform Core.
- future domains can reuse the same Legal Entity and Site identities without adopting HR as platform root.
- simple customers are not forced through complex multi-entity setup.
- domain-specific legal attributes stay within the domain that understands and validates them.

## Rejected alternatives

### Tenant equals Legal Entity

Rejected because multi-entity customers would require structural migration and commercial/isolation concepts would become mixed with legal/business identity.

### Platform Legal Entity is defined as an HR Employer object

Rejected because HR is the first domain consumer, not the architectural root of the Business Platform.

### Branch is the universal organization object

Rejected because future domains may need sites/locations without adopting service-center or HR semantics.

## Constraints

- deactivation is preferred over destructive deletion once historical references exist;
- Site does not own a separate role/permission system;
- tenant-owned business records remain tenant-scoped even when they also reference Legal Entity/Site;
- relationships between tenant-owned records must preserve the same-tenant referential-integrity invariant defined by ADR-002;
- whether a Legal Entity is an Employer, accounting entity, tax-registration subject, seller, buyer, or another domain role is determined by the owning Business Domain rather than Platform Core.
