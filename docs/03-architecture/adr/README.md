# Architecture Decision Records (ADRs)

ADRs capture material technical decisions that constrain future implementation.

## Required sections

Each ADR should include:

- title and status;
- context/problem;
- decision;
- alternatives considered;
- consequences/trade-offs;
- migration or compatibility implications where relevant;
- security, tenancy, data, and operational impact where relevant.

## Status values

- Proposed
- Accepted
- Superseded
- Rejected

## Naming

Use sequential identifiers such as:

`ADR-001-short-decision-name.md`

## Current Phase 0D Platform Foundation ADRs

### Behavioral / platform model

- `ADR-001-tenant-legal-entity-site-separation.md` — **Accepted**
- `ADR-002-explicit-tenant-context-and-isolation.md` — **Accepted**
- `ADR-003-entitlement-precedence-and-disable-semantics.md` — **Accepted**
- `ADR-004-authorization-permissions-and-role-templates.md` — **Accepted**
- `ADR-005-sensitive-audit-consistency.md` — **Accepted**

### Technology / deployment

- `ADR-006-nextjs-node-web-runtime.md` — **Accepted**
- `ADR-007-supabase-postgres-auth-storage.md` — **Accepted**
- `ADR-008-authoritative-data-access-and-transaction-boundaries.md` — **Accepted**
- `ADR-009-vercel-supabase-environments-and-preview-isolation.md` — **Accepted**
- `ADR-010-frontend-design-system-foundation.md` — **Accepted**

ADR-001 through ADR-010 were accepted together in the **2026-09-05 Phase 0D Platform Foundation freeze review** after the corrective constraints in `docs/04-product-specs/platform-foundation-freeze-review-amendment-2026-09-05.md` were incorporated into the governing Foundation set.

The accepted ADR set and the Frozen Platform Foundation Specification jointly govern Wave 1 — Platform Spine. The Technology & Deployment Architecture Study remains supporting research/evidence; the Accepted ADRs are the implementation authority.

Later Business Domain implementation remains blocked until each Domain's own governing Product Spec is Frozen under the staged Phase 0D gate.

## Rule

An ADR documents a real decision. It must not be created merely to make the project look architecturally mature. Small local implementation choices do not require ADRs.
