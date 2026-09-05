# ADR-003 — Entitlement Precedence, Limits, and Non-Destructive Disable Semantics

## Status

**Accepted — Phase 0D Platform Foundation freeze review, 2026-09-05.**

## Context

Commercial packages will change faster than product architecture. The donor SaaS entitlement system showed strong value in evaluating effective access from plan features plus subscription-specific overrides, but the new platform must keep those semantics independent from package names and avoid destructive behavior when access changes.

## Decision

Capabilities use stable product keys. Effective tenant access follows this conceptual precedence:

1. explicit tenant/contract/subscription override;
2. assigned plan/bundle entitlement when used;
3. deliberate capability default only for capabilities explicitly classified by the product as included Platform Core behavior.

Commercial/optional capabilities are **deny-by-default** when no effective grant exists. Absence of entitlement data must not fail open.

An explicit deny can override a plan enable. An explicit enable can extend a plan where commercially authorized.

Commercial resource limits are explicit values tied to capabilities. Unlimited has explicit semantics.

Removing/suspending an entitlement blocks new prohibited operations but never automatically deletes customer data or mutates finalized financial/compliance history.

If a lowered limit is below current usage, existing data remains; new growth is blocked by default until the tenant returns within the limit or the commercial setting changes.

## Consequences

- package names/prices can change without domain-code branches;
- negotiated customers can receive controlled overrides;
- missing/corrupt optional entitlement state does not accidentally grant a paid capability;
- historical payroll/compliance remains reproducible after commercial changes;
- UI can structurally hide disabled capabilities while the server remains authoritative.

## Rejected alternatives

### Hard-code Starter/Pro/Enterprise branches

Rejected because pricing/packaging evolution would force code changes and tenant-specific exceptions.

### Treat missing entitlement state as enabled

Rejected because commercial/security enforcement would fail open.

### Delete data when entitlement ends

Rejected as unsafe, commercially hostile, and incompatible with historical/compliance requirements.

### Use magic numeric values for unlimited

Rejected because semantics become ambiguous across capabilities and implementations.
