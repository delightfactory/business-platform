# ADR-002 — Explicit Tenant Context and Authoritative Isolation

## Status

**Proposed**

## Context

Users may belong to more than one tenant. Prior SaaS implementation history demonstrated that implicit tenant selection such as first-membership/`LIMIT 1` assumptions creates ambiguity and can become a security defect when multi-tenant membership expands.

A second class of failure exists even when row-level tenant filtering is correct: a tenant-owned row can still become corrupted if it persists a foreign reference to a tenant-owned record belonging to another tenant. Tenant isolation therefore covers both **access** and **relationship integrity**.

## Decision

Every tenant-scoped operation uses an explicit tenant context that is validated at an authoritative server/data-access layer.

A remembered or auto-selected tenant may improve UX, but it is never authorization evidence.

A tenant identifier supplied by a client may express the tenant the user intends to operate in, but it is not trusted as authorization truth. The authoritative layer validates the concrete tenant against current application-owned Membership state or separately governed Platform Operator authority before tenant-owned access proceeds. Authorization must not rely solely on stale client claims, route parameters, headers, or remembered tenant state.

When tenant context is missing, invalid, inactive, or unauthorized, the operation fails closed. The system must not guess a tenant.

Tenant isolation applies to reads, writes, exports, reports, search, file access, background work, and privileged helpers.

## Same-tenant referential-integrity invariant

Every persistent relationship from one tenant-owned record to another tenant-owned record must guarantee that both records belong to the same Tenant, unless a separately specified cross-tenant Platform relationship explicitly permits otherwise.

A row owned by Tenant A must not be able to persist a foreign reference to a Tenant B record merely because the referenced identifier exists globally.

This invariant is enforced authoritatively through schema/constraint/transactional-command design. Acceptable physical patterns include composite references such as `(tenant_id, resource_id)`, equivalent database constraints, or narrow atomic commands that cannot be bypassed by another supported write path.

UI filtering or application convention alone is not sufficient enforcement.

Every new tenant-owned relationship requires a negative test proving that a valid identifier from another Tenant cannot be linked, written, imported, or processed.

## Consequences

- multi-tenant users can switch safely;
- authorization/audit/entitlement evaluation receives one unambiguous tenant scope;
- cross-tenant negative tests become a reusable platform invariant for both data access and relational graph integrity;
- caches/client contexts must reset tenant-scoped state on switch;
- schema and command design must prevent cross-tenant foreign-reference corruption rather than relying only on RLS row visibility.

## Privileged operations

Tech Edge Platform Operator actions must identify the target tenant explicitly and remain auditable. Privileged helpers must be narrow rather than generic bypass functions.

Infrastructure bypass credentials are not a substitute for product-level tenant context or Platform Operator identity.

## Rejected alternatives

### Infer tenant from the user's first membership

Rejected because ordering is not authority and breaks multi-tenant correctness.

### Trust client-side selected tenant without server membership validation

Rejected because UI/client state is not an authorization boundary.

### Treat RLS row visibility as sufficient relationship integrity

Rejected because a tenant-owned row can still reference a cross-tenant identifier unless the relationship itself is constrained.

### Rely on application filtering only

Rejected because tenant isolation must exist at the authoritative enforcement layer appropriate to the selected stack.
