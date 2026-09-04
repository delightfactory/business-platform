# ADR-002 — Explicit Tenant Context and Authoritative Isolation

## Status

**Proposed**

## Context

Users may belong to more than one tenant. Prior SaaS implementation history demonstrated that implicit tenant selection such as first-membership/`LIMIT 1` assumptions creates ambiguity and can become a security defect when multi-tenant membership expands.

## Decision

Every tenant-scoped operation uses an explicit tenant context that is validated at an authoritative server/data-access layer.

A remembered or auto-selected tenant may improve UX, but it is never authorization evidence.

When tenant context is missing, invalid, inactive, or unauthorized, the operation fails closed. The system must not guess a tenant.

Tenant isolation applies to reads, writes, exports, reports, search, file access, background work, and privileged helpers.

## Consequences

- multi-tenant users can switch safely;
- authorization/audit/entitlement evaluation receives one unambiguous tenant scope;
- cross-tenant negative tests become a reusable platform invariant;
- caches/client contexts must reset tenant-scoped state on switch.

## Privileged operations

Tech Edge platform-operator actions must identify the target tenant explicitly and remain auditable. Privileged helpers must be narrow rather than generic bypass functions.

## Rejected alternatives

### Infer tenant from the user's first membership

Rejected because ordering is not authority and breaks multi-tenant correctness.

### Trust client-side selected tenant without server membership validation

Rejected because UI/client state is not an authorization boundary.

### Rely on application filtering only

Rejected because tenant isolation must exist at the authoritative enforcement layer appropriate to the selected stack.
