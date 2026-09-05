# ADR-009 — Vercel + Supabase Environment and Preview Isolation

## Status

**Accepted — Phase 0D Platform Foundation freeze review, 2026-09-05.**

## Context

The repository governance requires exact-revision qualification, reproducible migrations, and a safe place to test UI/database changes without risking production. Preview deployments are useful only if their backend/data target is equally safe.

## Decision

Use Vercel for the Next.js web application and maintain logically isolated application/data environments.

### Local development

- local Next.js process;
- local Supabase CLI stack in Docker-compatible runtime;
- repository migrations + seed data;
- routine clean reset/rebuild as a qualification tool.

### Staging

Maintain a persistent non-production Supabase environment and matching Vercel deployment/branch configuration.

- independent DB/Auth/Storage/secrets from production;
- synthetic/seeded data by default;
- used for hosted integration and acceptance tests.

### Pull-request preview

Every web PR may receive a Vercel Preview deployment.

For schema/data-config-changing PRs:

- preferred when enabled: map the Git branch to an isolated Supabase Preview Branch and corresponding Vercel Preview variables;
- otherwise: migrations are qualified locally and through controlled staging; an unqualified Preview must never point at production DB;
- a UI-only preview may use a compatible shared staging backend only when doing so cannot create schema/config race conditions.

Supabase Preview Branching is an optional operational enhancement, not an architectural prerequisite.

### Production

- isolated production Supabase project/environment;
- Vercel Production deployment from the governed production branch/release process;
- environment-scoped secrets;
- migrations applied only through repository-controlled deployment/CI process;
- exact release SHA and migration state are recorded in qualification.

## Safety rules

- no feature/preview branch may mutate production schema or seed production data;
- no production credentials in Preview/Development variables;
- dashboard schema edits are not an accepted source of truth;
- production data is not cloned into preview environments by default;
- secret/config differences between environments must be explicit and reviewable.

## Consequences

- PR review can include real hosted UI behavior;
- DB changes have an isolated validation path;
- staging remains useful even without paid preview branching;
- environment setup stays simple enough for the current stage while preserving stronger preview isolation later.

## Portability

Vercel is the initial hosting provider, not an irreversible runtime contract. Next.js must remain deployable as a standard supported Node application if later economics/compliance/operations justify migration.

## Rejected alternatives

### One Supabase project for dev/staging/production

Rejected because environment isolation and migration safety are inadequate for a multi-tenant payroll product.

### Every preview points to production

Rejected categorically.

### Kubernetes/custom hosting from first release

Rejected by the Complexity Budget; there is no current operational need.
