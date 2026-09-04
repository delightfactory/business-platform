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

- `ADR-001-tenant-legal-entity-site-separation.md`
- `ADR-002-explicit-tenant-context-and-isolation.md`
- `ADR-003-entitlement-precedence-and-disable-semantics.md`
- `ADR-004-authorization-permissions-and-role-templates.md`
- `ADR-005-sensitive-audit-consistency.md`

### Technology / deployment

- `ADR-006-nextjs-node-web-runtime.md`
- `ADR-007-supabase-postgres-auth-storage.md`
- `ADR-008-authoritative-data-access-and-transaction-boundaries.md`
- `ADR-009-vercel-supabase-environments-and-preview-isolation.md`
- `ADR-010-frontend-design-system-foundation.md`

All ADRs above remain Proposed until the Phase 0D acceptance/freeze review explicitly accepts them.

## Rule

An ADR documents a real decision. It must not be created merely to make the project look architecturally mature. Small local implementation choices do not require ADRs.
