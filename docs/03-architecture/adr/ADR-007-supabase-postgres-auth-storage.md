# ADR-007 — Supabase PostgreSQL, Auth, and Bounded Storage

## Status

**Accepted — Phase 0D Platform Foundation freeze review, 2026-09-05.**

## Context

The platform needs relational integrity, transactional financial workflows, DB-level tenant isolation, reproducible migrations, authentication, and bounded file storage while avoiding unnecessary infrastructure assembly in V1.

Tenant, Membership, Authorization, and Entitlement are application-owned concepts and must not be delegated to an identity-provider Organization model.

## Decision

Use Supabase as the initial managed data platform:

- PostgreSQL is the authoritative persistent business database;
- Supabase Auth provides authenticated human identity/session services;
- Supabase Storage is used only where active V1 capabilities require files/evidence/exports;
- Supabase CLI migrations, configuration, seeds, and database tests are committed to the repository;
- PostgreSQL grants and Row Level Security provide the authoritative tenant-owned row boundary for exposed data.

Supabase Auth does **not** own tenant membership, tenant roles, entitlements, Tech Edge platform authority, or Employee identity. These remain application-domain records.

Realtime, Edge Functions, generic queues, and other Supabase products are not automatically adopted merely because they are available. Each requires a concrete workflow need.

## Consequences

- fewer providers and integration seams in the first release;
- Auth JWT identity integrates naturally with PostgreSQL RLS;
- local full-stack reproduction and migration testing are straightforward;
- core database remains standard PostgreSQL and is comparatively portable;
- Auth/Storage provider-specific behavior creates some coupling and should stay behind application boundaries where practical.

## Future enterprise identity

Enterprise SAML/SSO may be added when commercially required without moving business tenancy/RBAC authority out of the application.

If the identity provider changes later, authenticated user identity may be remapped to application Membership records without redefining Tenant or HR data ownership.

## Rejected alternatives

### Clerk/Auth0 Organizations as Tenant authority

Rejected for V1 because it would duplicate the accepted application-owned Tenant/Membership/Role model and risk creating two sources of truth.

### Neon + separate identity/storage providers now

Technically valid but deferred because the additional provider boundaries do not solve a current problem that Supabase PostgreSQL cannot satisfy.

### Firestore as primary business database

Rejected because the platform's payroll, financial, reconciliation, effective-dated, and reporting invariants are fundamentally relational/transactional.
