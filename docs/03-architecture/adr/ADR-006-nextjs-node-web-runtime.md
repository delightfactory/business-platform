# ADR-006 — Next.js / Node Web Runtime

## Status

**Proposed**

## Context

The product requires one adaptive web application, server-side business operations, strong TypeScript support, efficient PR previews, and a modular-monolith structure without introducing a second backend stack prematurely.

The runtime must also remain portable enough that hosting provider choice does not become a permanent architecture constraint.

## Decision

Use:

- TypeScript as the application language;
- Next.js 16 **Active-LTS major line**, pinned to the latest patched 16.x release at implementation time;
- App Router;
- Node.js 24 LTS as the default server runtime;
- React version supported by the selected Next.js release;
- Node runtime by default rather than Edge runtime unless a concrete use case proves an Edge benefit.

Use a modular-monolith code structure. Business/domain logic must live outside route/page components so that Next.js is a delivery/runtime framework rather than the domain architecture.

Server Components are preferred where browser-side interactivity is unnecessary; Client Components are introduced only where required.

## Consequences

- one language/runtime covers frontend and application-server code;
- strong SSR/application-shell support for desktop/mobile experience;
- lower operational complexity than a separate API service in V1;
- domain boundaries can later be extracted without treating route structure as domain ownership;
- framework security patching becomes an explicit maintenance obligation.

## Security/maintenance rule

The repository must pin exact package versions through the lockfile and stay on a supported, patched Active-LTS/Maintenance-LTS line. Experimental Next.js features must not become architecture dependencies without a separate decision.

## Rejected alternatives

### Separate backend framework from day one

Rejected because it creates a second deployment/runtime boundary before there is a demonstrated need.

### Edge runtime as universal default

Rejected because not every database/transaction/library workload benefits from Edge constraints; use it only for a concrete validated case.

### Current/EOL Node release

Rejected for production stability and security maintenance reasons.
