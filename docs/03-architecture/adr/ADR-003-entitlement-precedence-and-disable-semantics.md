# ADR-003 — Entitlement Precedence, Limits, and Non-Destructive Disable Semantics

## Status

**Accepted — Phase 0D Platform Foundation freeze review, hardened by pre-merge review 2026-09-05.**

## Context

Commercial packages will change faster than product architecture. The donor SaaS entitlement system showed strong value in evaluating effective access from plan features plus subscription-specific overrides, but the new platform must keep those semantics independent from package names and avoid destructive behavior when access changes.

Wave 1 also needs one unambiguous commercial-access source of truth without rebuilding a billing/subscription product before it is required.

## Decision

Capabilities use stable product keys.

### Wave 1 commercial-access source of truth

Wave 1 uses **direct effective-dated tenant Capability grants/denials and Capability Limits** as the authoritative commercial-access representation.

Conceptually these may be stored as `TenantCapabilityGrant` / `TenantCapabilityLimit` records or an equivalent small model. Exact physical names are implementation detail.

A direct grant/denial supports, where applicable:

- Tenant;
- Capability key;
- enable/deny effect;
- `valid_from`;
- optional `valid_until`;
- bounded commercial/source reference or reason metadata;
- actor/provenance/audit metadata.

A Capability Limit supports the same effective-time/source semantics where useful plus the typed limit value.

Rules:

- direct grants/denials and limits are the Wave 1 authoritative source of truth for customer product access;
- when `valid_until` has passed, the grant is no longer effective at authoritative evaluation time; no hidden manual Tenant-status mutation is required;
- Tenant lifecycle state remains separate from commercial entitlement state;
- negotiated/manual contract information may be recorded as a bounded reference/reason without building a Subscription/Contract state machine;
- Wave 1 does **not** require a Subscription entity, Billing entity, Invoice lifecycle, payment gateway, or generic Commercial Agreement subsystem.

### Effective-entitlement precedence

For Wave 1, direct tenant grants/denials are authoritative.

The long-term conceptual precedence remains:

1. explicit tenant/contract/commercial override;
2. assigned plan/bundle entitlement when a plan/bundle model is later introduced;
3. deliberate capability default only for capabilities explicitly classified by the product as included Platform Core behavior.

A future plan/bundle layer may feed the same effective-entitlement contract without changing Domain capability keys or historical meaning. Until such a layer exists, missing plan/subscription data is not an implementation gap because direct effective grants/denials are the accepted Wave 1 source of truth.

Commercial/optional capabilities are **deny-by-default** when no effective grant exists. Absence of entitlement data must not fail open.

An explicit deny can override a future plan enable. An explicit enable can extend a future plan where commercially authorized.

Commercial resource limits are explicit values tied to capabilities. Unlimited has explicit semantics.

Removing/suspending an entitlement or allowing a time-bounded grant to expire blocks new prohibited operations but never automatically deletes customer data or mutates finalized financial/compliance history.

If a lowered limit is below current usage, existing data remains; new growth is blocked by default until the tenant returns within the limit or the commercial setting changes.

## Consequences

- Wave 1 has one concrete commercial-access source of truth rather than an implied Subscription subsystem;
- package names/prices can change without domain-code branches;
- negotiated customers can receive controlled direct effective-dated grants and overrides;
- expiry can be evaluated authoritatively without an operational job being the sole correctness mechanism;
- missing/corrupt optional entitlement state does not accidentally grant a paid capability;
- historical payroll/compliance remains reproducible after commercial changes;
- UI can structurally hide disabled capabilities while the server remains authoritative;
- plans/subscriptions/billing can be added later without changing capability identity or Domain logic.

## Rejected alternatives

### Build a full Subscription/Billing subsystem in Wave 1

Rejected because direct effective-dated grants/limits satisfy the current operational selling model and a larger commercial subsystem would exceed the Complexity Budget.

### Leave the commercial source of truth undefined between direct grants and subscription state

Rejected because PLT-007/PLT-008 implementation would otherwise invent a material product model.

### Hard-code Starter/Pro/Enterprise branches

Rejected because pricing/packaging evolution would force code changes and tenant-specific exceptions.

### Treat missing entitlement state as enabled

Rejected because commercial/security enforcement would fail open.

### Delete data when entitlement ends

Rejected as unsafe, commercially hostile, and incompatible with historical/compliance requirements.

### Use magic numeric values for unlimited

Rejected because semantics become ambiguous across capabilities and implementations.
