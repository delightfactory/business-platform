# ADR-008 — Authoritative Data Access and Transaction Boundaries

## Status

**Accepted — Phase 0D Platform Foundation freeze review, hardened by pre-merge review 2026-09-05.**

## Context

Using PostgreSQL RLS does not by itself define a safe application access pattern. The platform also requires fail-closed tenant isolation, authoritative Permission and Entitlement enforcement, tenant-lifecycle enforcement, narrowly scoped privilege, and atomic sensitive mutations whose mandatory audit record cannot disappear independently.

The donor-platform audit showed that broad privileged helpers and implicit tenant context are high-risk failure modes.

A further risk exists when the application denies an operation but an exposed Data API path can still perform it because the database policy checks only tenant membership. The Foundation therefore needs one explicit access contract rather than parallel ambiguous authorization paths.

Tenant lifecycle state is also an independent access-control gate. An otherwise valid Membership, Permission, and Entitlement must not allow normal business access when the target Tenant is `suspended` or `archived`.

## Decision

Every supported tenant-owned operation must have one authoritative, testable access path that proves all applicable conditions before success:

1. authenticated principal identity;
2. explicit validated tenant context;
3. active Membership or separately governed Platform Operator authority;
4. **Tenant lifecycle/access state permits the requested operation**;
5. required business Permission;
6. required Capability Entitlement and applicable Limit semantics;
7. row/resource scope and tenant ownership;
8. same-Tenant relationship integrity where tenant-owned references are involved;
9. operation-specific lifecycle preconditions.

UI controls, navigation filters, route guards, and client-side checks are never sufficient authority.

Use the following access hierarchy and explicit allowlist.

### 1. Tenant-scoped direct reads

Direct Supabase/Data API reads are allowed only for deliberately exposed objects where:

- explicit SQL grants permit the required read;
- RLS or equivalent authoritative policy validates tenant/resource scope;
- the Tenant lifecycle state permits that read;
- any required Permission and Entitlement conditions are enforced at the same authoritative access boundary or through an unavoidable protected function/view boundary;
- the object does not expose data that the caller's role is not authorized to observe.

Internal/domain tables that do not require direct access should remain in non-exposed/private schemas or have no usable direct grants.

Normal tenant-user business reads are not allowed when the Tenant is `suspended` or `archived`. A minimal non-sensitive suspension/status/support surface may be separately exposed, but it must not become a path to normal tenant-owned business data.

### 2. Tenant-scoped direct mutations

A direct mutation is allowed only when the database-authoritative policy for that mutation enforces the complete required Tenant state, tenant context, Permission, Entitlement, scope, relationship-integrity, and lifecycle rules.

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
- every privileged operation carries an explicit target Tenant when tenant data is involved;
- Platform Operator authority is validated through its separately governed Platform trust boundary;
- Tenant lifecycle state remains an explicit input to the operation; Operator access may perform only the recovery/support/export action that is separately authorized for that state;
- narrow operation-specific APIs/functions are preferred over generic privileged table access;
- authorization and required audit occur before/with the protected mutation as appropriate;
- privileged access does not waive same-tenant relationship or business lifecycle invariants unless a separately governed recovery operation explicitly defines that exception.

## Tenant-context binding

A tenant identifier supplied by a client may express the requested tenant context, but it is not trusted as authorization truth.

The authoritative layer validates the concrete Tenant against current application-owned Membership or separately governed Platform Operator state before tenant-owned access proceeds. It also evaluates the current Tenant lifecycle state. Authorization must not rely solely on stale JWT/custom claims, client headers, route parameters, remembered UI state, or a stale cached Tenant status.

## Tenant lifecycle access rule

Wave 1 uses these authoritative state semantics:

- `active` — normal tenant-user reads/writes/search/export may proceed subject to all other authority checks;
- `suspended` — no normal tenant-user tenant-owned business read/write/search/export. Only a minimal non-sensitive status/support surface may remain available. Explicit Platform Operator recovery/support/inspection/export operations may run when separately authorized and audited;
- `archived` — no tenant-user tenant-owned operation. Explicit Platform Operator inspect/export/recovery operations may run when separately authorized and audited.

Allowed transitions are:

- `active -> suspended`;
- `suspended -> active`;
- `active -> archived`;
- `suspended -> archived`;
- `archived -> suspended` through an explicit restore/recovery operation.

V1 does not allow a direct `archived -> active` transition. Restore first moves the Tenant to `suspended`, then a separate reactivation moves it to `active`. Archive/restore/reactivate are sensitive mandatory-audited operations.

## RLS/grant and exposed-schema rule

RLS and SQL grants are configured together. A table is not considered secured merely because an RLS policy exists.

Application database objects are revoke-by-default unless exposure is deliberately required.

Privileged functions must use least privilege, explicit execution grants, safe `search_path` behavior, and schema-qualified references where applicable. Exposed views must preserve the caller's effective authorization context rather than silently executing with broader authority.

Cross-tenant negative tests are part of the Definition of Done for every new tenant-owned domain capability, including tests for cross-tenant foreign references as required by ADR-002. Tenant-state negative tests are also required for direct and command paths that would otherwise be valid under Membership/Permission/Entitlement.

## Authoritative Access Matrix

The following matrix is the Wave 1 default. A governing Product Spec may narrow an operation further but may not weaken the authority requirements without changing this ADR through governance.

| Operation family | Allowed access path | Authoritative checks required |
| --- | --- | --- |
| Public/non-tenant data intentionally exposed by product | Deliberately exposed read only | Object grant + product-specific visibility rule |
| Minimal suspended-tenant status/support surface | Deliberately exposed bounded read only | Authenticated principal + validated Tenant + current Membership + Tenant state is `suspended` + explicitly non-sensitive bounded projection; no normal business data |
| Tenant-scoped normal read | Direct read only where explicitly allowlisted; otherwise protected query boundary | Authenticated principal + validated Tenant + active Membership/Operator authority + **Tenant state permits operation** + row/resource scope + required Permission/Entitlement |
| Simple tenant-scoped mutation | Direct mutation only where complete DB-authoritative policy is feasible; otherwise command/RPC | Authenticated principal + validated Tenant + Membership + **Tenant state permits operation** + Permission + Entitlement/Limit + row/resource ownership + same-tenant relationship invariants + lifecycle preconditions |
| Membership / role / permission / entitlement / limit / tenant-lifecycle mutation | Narrow application command / transactional RPC | Explicit authority for protected action + target Tenant + current Tenant state + transition/lifecycle invariants + mandatory audit where classified |
| Multi-write or mandatory-audit transition | Transactional command/RPC or equally atomic server-side DB transaction | Full operation authority + Tenant state permits operation + all business invariants + atomic mandatory success audit |
| Platform Operator action against tenant data | Server-only operator command | Valid Platform Operator authority + explicit target Tenant + current Tenant state + state-specific operator capability + audit + preserved tenant/business invariants |
| Background/system processing of tenant data | Narrow server-only job/command | Explicit target Tenant + current Tenant state + system job authority + state-specific permission to process + idempotency/retry contract where needed + same-tenant/business invariants |

Implementation documentation must identify the concrete access category for each Wave 1 operation family. If an operation does not clearly fit an allowed category, it is not implementation-ready.

## Consequences

- tenant isolation remains authoritative below the UI;
- Tenant suspension/archive cannot be bypassed by otherwise-valid Membership/Permission/Entitlement or a more permissive Data API path;
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

### Treat Tenant status as UI-only state

Rejected because a suspended/archived Tenant would remain readable or mutable through alternate authoritative paths.

### Browser-direct mutation for every workflow

Rejected because sensitive multi-step state transitions and fail-closed audit often require a stronger transactional operation boundary.

### RLS that checks only tenant membership for every operation

Rejected because same-tenant membership does not imply business Permission, Entitlement, valid Tenant lifecycle state, or authority for every action/resource.

### Application filtering without DB isolation

Rejected as incompatible with the Platform Foundation tenant-isolation obligation.
