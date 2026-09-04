# ADR-008 — Authoritative Data Access and Transaction Boundaries

## Status

**Proposed**

## Context

Using PostgreSQL RLS does not by itself define a safe application access pattern. The platform also requires fail-closed tenant isolation, narrowly scoped privilege, and atomic sensitive mutations whose mandatory audit record cannot disappear independently.

The donor-platform audit showed that broad privileged helpers and implicit tenant context are high-risk failure modes.

## Decision

Use the following access hierarchy.

### 1. Tenant-scoped normal access

- authenticated user identity is propagated to the data layer;
- PostgreSQL grants and RLS enforce row access;
- tenant context is explicit and validated through application-owned Membership state;
- every exposed tenant-owned table receives positive and negative policy tests.

### 2. Sensitive transactional mutations

When one logical operation requires multiple writes or mandatory success audit, execute it inside one database transaction consistency boundary using a narrowly scoped SQL function/RPC or an equally atomic server-side database transaction.

A protected mutation that requires mandatory success audit must not be acknowledged as committed unless both business mutation and audit persistence commit.

### 3. Privileged platform/background access

Server-only bypass credentials/roles may be used only for explicit platform-operator or system jobs that require them.

Rules:

- never expose privileged keys to browsers;
- never use privileged bypass as the normal tenant-user DAL;
- every privileged operation carries an explicit target tenant when tenant data is involved;
- narrow operation-specific APIs/functions are preferred over generic privileged table access;
- authorization and audit occur before/with the protected mutation as appropriate.

## RLS/grant rule

RLS and SQL grants are configured together. A table is not considered secured merely because an RLS policy exists.

Cross-tenant negative tests are part of the Definition of Done for every new tenant-owned domain capability.

## Consequences

- tenant isolation remains authoritative below the UI;
- simple reads/mutations remain productive through Supabase APIs;
- critical financial/platform operations gain real transaction semantics;
- service-role bypass does not become a hidden alternate architecture;
- SQL/RPC surface must stay small, intentional, and testable.

## Rejected alternatives

### Service-role-only server DAL for all requests

Rejected because it bypasses RLS and shifts the entire isolation burden into application code.

### Browser-direct mutation for every workflow

Rejected because sensitive multi-step state transitions and fail-closed audit often require a stronger transactional application boundary.

### Application filtering without DB isolation

Rejected as incompatible with the Platform Foundation tenant-isolation obligation.
