# ADR-008 — Authoritative Data Access and Transaction Boundaries

## Status

**Proposed**

## Context

Using PostgreSQL RLS does not by itself define a safe application access pattern. The platform also requires fail-closed tenant isolation, authoritative Permission and Entitlement enforcement, narrowly scoped privilege, and atomic sensitive mutations whose mandatory audit record cannot disappear independently.

The donor-platform audit showed that broad privileged helpers and implicit tenant context are high-risk failure modes.

A further risk exists when the application denies an operation but an exposed Data API path can still perform it because the database policy checks only tenant membership. The Foundation therefore needs one explicit access contract rather than parallel ambiguous authorization paths.

## Decision

Every supported tenant-owned operation must have one authoritative, testable access path that proves all applicable conditions before success:

1. authenticated principal identity;
2. explicit validated tenant context;
3. active Membership or separately governed Platform Operator authority;
4. required business Permission;
5. required Capability Entitlement and applicable Limit semantics;
6. row/resource scope and tenant ownership;
7. operation-specific lifecycle preconditions.

UI controls, navigation filters, route guards, and client-side checks are never sufficient authority.

Use the following access hierarchy and explicit allowlist.

### 1. Tenant-scoped direct reads

Direct Supabase/Data API reads are allowed only for deliberately exposed objects where:

- explicit SQL grants permit the required read;
- RLS or equivalent authoritative policy validates tenant/resource scope;
- any required Permission and Entitlement conditions are enforced at the same authoritative access boundary or through an unavoidable protected function/view boundary;
- the object does not expose data that the caller's role is not authorized to observe.

Internal/domain tables that do not require direct access should remain in non-exposed/private schemas or have no usable direct grants.

### 2. Tenant-scoped direct mutations

A direct mutation is allowed only when the database-authoritative policy for that mutation enforces the complete required tenant, Permission, Entitlement, scope, relationship-integrity, and lifecycle rules.

If any required business rule cannot be expressed safely and clearly at that boundary, direct mutation is not exposed and the operation must use a narrow application command / transactional RPC / equivalent authoritative operation.

A mutation must never be considered safe merely because the UI hides the action or an application route usually checks permission first.

### 3. Sensitive transactional mutations

When one logical operation requires multiple writes, mandatory success audit, protected lifecycle transitions, or invariants that span records, execute it inside one database transaction consistency boundary using a narrowly scoped SQL function/RPC or an equally atomic server-side database transaction.

A protected mutation that requires mandatory success audit must not be acknowledged as committed unless both business mutation and audit persistence commit.

Constituent writes must not remain available through an alternate supported path that can bypass the operation-level invariant.

### 4. Privileged Platform Operator/background access

Server-only bypass credentials/roles may be used only for explicit Platform Operator or system jobs that require them.

Rules:

- never expose privileged keys to browsers;
- never use privileged bypass as the normal tenant-user DAL;
- infrastructure bypass credentials such as `service_role` are not a product-level Platform Operator identity;
- every privileged operation carries an explicit target tenant when tenant data is involved;
- Platform Operator authority is validated through its separately governed Platform trust boundary;
- narrow operation-specific APIs/functions are preferred over generic privileged table access;
- authorization and required audit occur before/with the protected mutation as appropriate;
- privileged access does not waive same-tenant relationship or business lifecycle invariants unless a separately governed recovery operation explicitly defines that exception.

## Tenant-context binding

A tenant identifier supplied by a client may express the requested tenant context, but it is not trusted as authorization truth.

The authoritative layer validates the concrete tenant against current application-owned Membership or separately governed Platform Operator state before tenant-owned access proceeds. Authorization must not rely solely on stale JWT/custom claims, client headers, route parameters, or remembered UI state.

## RLS/grant and exposed-schema rule

RLS and SQL grants are configured together. A table is not considered secured merely because an RLS policy exists.

Application database objects are revoke-by-default unless exposure is deliberately required.

Privileged functions must use least privilege, explicit execution grants, safe `search_path` behavior, and schema-qualified references where applicable. Exposed views must preserve the caller's effective authorization context rather than silently executing with broader authority.

Cross-tenant negative tests are part of the Definition of Done for every new tenant-owned domain capability, including tests for cross-tenant foreign references as required by ADR-002.

## Authoritative Access Matrix

The following matrix is the Wave 1 default. A governing Product Spec may narrow an operation further but may not weaken the authority requirements without changing this ADR through governance.

| Operation family | Allowed access path | Authoritative checks required |
| --- | --- | --- |
| Public/non-tenant data intentionally exposed by product | Deliberately exposed read only | Object grant + product-specific visibility rule |
| Tenant-scoped normal read | Direct read only where explicitly allowlisted; otherwise protected query boundary | Authenticated principal + validated Tenant + active Membership/Operator authority + row/resource scope + required Permission/Entitlement |
| Simple tenant-scoped mutation | Direct mutation only where complete DB-authoritative policy is feasible; otherwise command/RPC | Authenticated principal + validated Tenant + Membership + Permission + Entitlement/Limit + row/resource ownership + same-tenant relationship invariants + lifecycle preconditions |
| Membership / role / permission / entitlement / limit / tenant-lifecycle mutation | Narrow application command / transactional RPC | Explicit authority for the protected action + target Tenant + lifecycle invariants + mandatory audit where classified |
| Multi-write or mandatory-audit transition | Transactional command/RPC or equally atomic server-side DB transaction | Full operation authority + all business invariants + atomic mandatory success audit |
| Platform Operator action against tenant data | Server-only operator command | Valid Platform Operator authority + explicit target Tenant + operation capability + audit + preserved tenant/business invariants |
| Background/system processing of tenant data | Narrow server-only job/command | Explicit target Tenant + system job authority + idempotency/retry contract where needed + same tenant/business invariants |

Implementation documentation must identify the concrete access category for each Wave 1 operation family. If an operation does not clearly fit an allowed category, it is not implementation-ready.

## Consequences

- tenant isolation remains authoritative below the UI;
- Permission and Entitlement checks cannot be bypassed through a more permissive alternate Data API path;
- simple reads and genuinely simple mutations can remain productive through Supabase APIs where the database policy is complete;
- critical financial/platform operations gain real transaction semantics;
- service-role bypass does not become a hidden alternate architecture;
- exposed database surface becomes deliberate rather than accidental;
- SQL/RPC surface stays small, intentional, and testable.

## Rejected alternatives

### Service-role-only server DAL for all requests

Rejected because it bypasses RLS and shifts the entire isolation burden into application code.

### Assume application guards make a permissive direct Data API safe

Rejected because a caller can bypass presentation/application routing and reach the more permissive authoritative data surface directly.

### Browser-direct mutation for every workflow

Rejected because sensitive multi-step state transitions and fail-closed audit often require a stronger transactional operation boundary.

### RLS that checks only tenant membership for every operation

Rejected because same-tenant membership does not imply business Permission, Entitlement, or authority for every action/resource.

### Application filtering without DB isolation

Rejected as incompatible with the Platform Foundation tenant-isolation obligation.
