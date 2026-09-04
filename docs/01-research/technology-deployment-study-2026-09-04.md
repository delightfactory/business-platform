# Technology & Deployment Architecture Study — 2026-09-04

## Status

**Proposed recommendation — Phase 0D.**

This study evaluates a practical implementation stack for the Business Platform against the accepted architecture, security, UX, workflow-completion, and Complexity Budget principles.

It does not authorize Product Code. The selected stack becomes implementation authority only after the supporting ADRs are Accepted and the Platform Foundation Specification is Frozen.

## Decision criteria

The stack must support, without architectural workarounds:

1. explicit multi-tenant isolation and authoritative authorization;
2. relational integrity for HR/payroll/employee-finance data;
3. deterministic transactions for sensitive state changes and audit consistency;
4. versioned/effective-dated configuration and reproducible payroll history;
5. application-owned Tenant / Membership / RBAC / Entitlement models;
6. reproducible migrations and clean-environment testing;
7. safe local, preview/staging, and production environments;
8. an adaptive professional web application across desktop, tablet, and mobile;
9. reusable accessible design-system primitives;
10. a simple initial operating model without blocking future SSO, integrations, background work, or domain expansion.

## Candidates considered

### Candidate A — Next.js + Supabase + Vercel

- Next.js App Router / TypeScript / Node runtime.
- Supabase managed Postgres, Auth, Storage, local CLI/migrations, RLS.
- Vercel deployment and Preview environments.
- Tailwind CSS + internally owned design system, using open-code/headless accessible primitives.

### Candidate B — Next.js + Neon + Clerk/Auth0 + Vercel

- Next.js / TypeScript.
- Neon Postgres.
- Clerk or Auth0 for authentication and B2B organizations.
- Vercel deployment.

### Candidate C — Firebase / Firestore-centered stack

- React/Next.js frontend.
- Firebase Auth + Firestore + Security Rules.

### Candidate D — Custom/self-managed Postgres + custom backend from day one

- Dedicated API/backend service.
- Self-managed or lower-level managed Postgres.
- Separate Auth provider.
- Separate storage/hosting/operations.

## Evaluation

| Criterion | A: Next + Supabase + Vercel | B: Next + Neon + Clerk/Auth0 | C: Firebase-centered | D: Custom backend/Postgres |
|---|---|---|---|---|
| Relational/payroll fit | Excellent | Excellent | Weak/awkward | Excellent |
| DB-level tenant isolation | Excellent via Postgres RLS | Excellent via Postgres RLS | Rules-based, non-relational | Excellent if built correctly |
| Auth ↔ DB security integration | Strong | More integration work | Strong in Firebase ecosystem | Custom integration work |
| App-owned tenancy/RBAC | Strong fit | Risk of duplicating external Organization model | Possible but custom | Strong fit |
| Transaction/audit consistency | Strong | Strong | Less natural for relational workflows | Strong |
| Migration reproducibility | Strong integrated CLI | Strong DB tooling, more assembly | Different model | Strong but custom ops |
| Local full-stack reproducibility | Strong | Moderate | Strong-ish but different semantics | Highest setup cost |
| Preview/staging path | Strong | Strong | Strong | Must assemble |
| Initial operational complexity | Low/medium | Medium/high | Low | High |
| Future enterprise SSO | Available | Excellent | Available with product choices | Provider-dependent |
| Vendor count | Low | Higher | Low | Higher/operationally fragmented |
| Portability | Good for DB/app; moderate Auth/Storage coupling | Good but more vendors | Lower data-model portability | Highest |
| Fit with current governance | **Best** | Good but duplicates concepts | Poorer domain/data fit | Overbuilt for current stage |

## Recommendation

Adopt **Candidate A** as the Phase 1 implementation direction:

```text
GitHub
  -> Next.js 16 Active-LTS line / React / TypeScript
       -> Node.js 24 LTS runtime
       -> internal modular-monolith application/domain modules
       -> internal Design System

  -> Supabase
       -> PostgreSQL = authoritative persistent data
       -> RLS + SQL grants = authoritative tenant data boundary
       -> Auth = authenticated human identity only
       -> Storage = bounded file/evidence/export needs
       -> migrations + seeds + DB tests in repository

  -> Vercel
       -> Preview web deployments
       -> Staging web deployment
       -> Production web deployment
```

The recommendation is based on fit, not historical familiarity.

## Why PostgreSQL is the right center

The platform's hardest data problems are relational and transactional:

- tenant → legal entity → site → employee relationships;
- effective-dated employment and compensation facts;
- attendance/leave/finance inputs feeding payroll;
- payroll run state transitions;
- installment balances and reconciliation;
- immutable/frozen historical references;
- audit records that must commit consistently with sensitive mutations.

A relational Postgres model provides constraints, transactions, indexing, SQL reporting, and RLS without inventing application-level substitutes.

## Why Supabase rather than Neon + Clerk/Auth0 for V1

Neon is a strong Postgres platform and Clerk/Auth0 are mature identity/B2B products. The issue is not technical quality; it is architectural overlap and operational cost for this product stage.

The Business Platform has already decided that Tenant, Membership, Roles/Permissions, Entitlements, and Platform Operator authority are application-owned concepts. A B2B identity provider's Organization / Active Organization / role system would either become a second authority or require continuous mapping to the platform authority.

Supabase Auth can remain deliberately narrow: it answers **who authenticated**, while application tables and RLS answer **which tenant and what authority**.

This preserves DEC-001/002/007 and the Platform Foundation model with fewer moving parts.

If future enterprise requirements demand external identity federation, Supabase Auth supports SAML-based enterprise SSO; application membership/authorization still remains authoritative.

## Supabase security constraints

Supabase is recommended only with these non-negotiable rules:

1. Every exposed tenant-owned table uses explicit grants plus RLS.
2. RLS policy tests include positive and negative tenant cases.
3. `service_role` is never exposed to browser/client code.
4. `service_role` is not the normal path for tenant-user requests.
5. Auth JWT identity does not by itself establish Tenant/Membership/Role authority.
6. Sensitive multi-step mutations that require mandatory audit consistency execute through one transactional consistency boundary.
7. Privileged database functions/RPCs are narrowly scoped and explicitly tested.
8. Dashboard-only schema edits are not an accepted deployment workflow; repository migrations are authoritative.

## Application/backend shape

Use **one Next.js modular monolith** initially.

- App Router for routing/layout/server rendering.
- Node runtime by default for server-side application code.
- Server Components by default where no client interaction is required.
- Client Components only for interactive state/browser capabilities.
- Business logic lives in domain/application modules, not inside page components or route files.
- Route Handlers/Server Actions are delivery adapters into application services, not domain owners.
- No microservices, message bus, second backend framework, or separate GraphQL layer in V1 without a demonstrated requirement.

This preserves future extraction because domain boundaries are code/ownership boundaries before they are deployment boundaries.

## Data-access model

Use a deliberately mixed strategy rather than forcing every use case through one mechanism:

### Normal tenant-scoped reads and simple mutations

- Supabase APIs/clients operate under authenticated user context.
- Postgres grants + RLS remain authoritative.

### Sensitive/transactional domain mutations

Examples: platform entitlement changes with mandatory audit, future payroll lock/finalize, employee-finance settlements.

Use one database transaction boundary through a narrowly-scoped SQL function/RPC or an equally atomic server-side database transaction implementation.

The protected mutation and mandatory success audit must either both commit or neither commit.

### Platform-operator/background privileged work

Use a dedicated server-only privileged path with explicit target tenant, narrow purpose, audit, and tests. Do not convert `service_role` into a universal bypass DAL.

## Auth recommendation

Use **Supabase Auth as identity provider for V1**.

Auth owns:

- login/session identity;
- password/OTP/social authentication methods selected by Product Spec;
- future MFA/SSO provider integration when justified.

Auth does **not** own:

- tenant identity;
- tenant membership business state;
- tenant role assignments;
- capability entitlements;
- Tech Edge platform authority;
- employee identity.

The application links authenticated `user_id` to application-owned Membership records.

## Web runtime versions

At study date:

- Next.js 16 is the Active-LTS major line; official security guidance on 2026-08-25 identified 16.3.3 as the patched Active-LTS release.
- Node.js 24 is LTS; Node.js 26 remains Current until its later LTS promotion.

Bootstrap policy:

- use the current fully patched Next.js 16.x Active-LTS release available when implementation begins;
- pin exact package versions in lockfile;
- use Node.js 24 LTS, not Current/EOL runtime;
- treat framework security patches as release-blocking maintenance.

Do not pin a stale patch version in a permanent architecture decision.

## Frontend / Design System recommendation

Use:

- Tailwind CSS 4.x for styling and design-token implementation;
- CSS variables/theme tokens as the central visual contract;
- an **internally owned component layer** as the only normal feature-level UI import surface;
- shadcn/ui as an open-code component starting/distribution model;
- Radix Primitives where appropriate for accessible behavior such as Dialog, Menu, Select, Popover, Tabs, Tooltip, etc.

Rules:

1. Feature screens must not repeatedly recreate Button/Input/Dialog/Table shells.
2. Third-party primitive imports should normally be contained inside the internal Design System layer.
3. A visual/interaction improvement to a base component should propagate from one owned source.
4. Design tokens must support responsive composition and future RTL/LTR without per-screen hacks.
5. Desktop and mobile may use different composition while sharing semantic components/data flows.
6. shadcn source is adopted selectively; the project does not bulk-install a catalogue of unused components.
7. Accessibility remains an application responsibility even when primitives provide strong defaults.

## Deployment/environment recommendation

### Local

- Supabase CLI + Docker-compatible local stack.
- Migrations and seed data from repository.
- Local app points only to local/dev services by default.
- Clean reset is a standard qualification action.

### Staging

Maintain a persistent non-production environment with independent Auth/DB/Storage/secrets.

Staging must never use production data by default. Synthetic/seeded data is preferred.

### Pull Request preview

Vercel provides a unique Preview deployment for non-production branches.

For database-changing PRs:

- preferred when commercially justified: use Supabase isolated Preview Branching mapped to the corresponding Vercel preview;
- if preview branching is not enabled, qualify migrations locally and against staging through a controlled process; **never point an unqualified preview at production DB**;
- UI-only previews may use a compatible shared staging backend when that does not create schema/config race conditions.

Preview branching is an operational enhancement, not a foundation dependency; Supabase currently makes PR preview branches a paid-plan capability.

### Production

- `main`/release workflow deploys only qualified revisions.
- production DB/Auth/Storage are isolated from staging.
- secrets are environment-scoped.
- database migrations come from repository and controlled CI/CD, not undocumented dashboard edits.
- exact candidate SHA and migration state form part of release qualification.

## Vercel recommendation

Use Vercel for the Next.js web application because it offers:

- first-class Next.js deployment;
- PR/branch Preview deployments;
- environment-scoped variables;
- simple production promotion/rollback workflow.

This is not intended to create irreversible hosting lock-in. Current Next.js provides a stable Adapter API and can run as a standard Node server, preserving a future migration path if commercial or operational requirements change.

## Background jobs and integrations

Do **not** select/build a generic queue/worker platform in Wave 1.

The architecture must permit background execution, but select the mechanism only when a concrete workflow requires it.

Likely later patterns:

- database-triggered/scheduled tasks for bounded DB-centric jobs;
- a managed queue/job facility for retryable asynchronous work;
- a separately deployable on-prem/device connector for LAN biometric devices;
- HTTP APIs from connectors into the application/integration boundary.

The biometric connector must never make device-vendor transport logic part of Payroll or Attendance business rules.

## Alternatives rejected/deferred

### Clerk/Organizations as the tenant authority

Deferred/rejected for V1 because it duplicates application-owned Tenant/Membership/RBAC and introduces external Active Organization semantics into an area we require to be explicitly controlled by the platform.

Clerk remains a technically viable future identity-provider alternative if requirements change, because Supabase supports third-party auth JWT integrations; replacing identity must not require replacing application tenancy.

### Auth0 Organizations from day one

Strong enterprise/B2B identity product, but unnecessary vendor/operational complexity before enterprise federation requirements are proven. Organization membership must not become the product's business membership authority merely because Auth0 can model it.

### Neon as primary database now

Technically strong and remains a viable portability destination. It requires assembling separate Auth/Storage/local-stack concerns and does not create enough current benefit to justify increasing system boundaries.

### Firestore as primary business database

Rejected for the core platform because payroll, finance, historical versioning, reconciliation, and cross-entity business reporting are naturally relational/transactional. Avoid redesigning relational business invariants around a document database.

### Custom API backend / Kubernetes / microservices now

Rejected by the Complexity Budget. There is no current scale, team-size, isolation, or deployment requirement that justifies the operational cost.

## Risks and mitigations

### Risk: RLS complexity

**Mitigation:** explicit tenant context, small policy helpers, grants + RLS together, negative DB tests, no implicit tenant selection, and periodic security review.

### Risk: service-role bypass abuse

**Mitigation:** narrow server-only privileged clients/functions; prohibit general tenant request handling through bypass credentials.

### Risk: Supabase platform coupling

**Mitigation:** keep business logic in application/domain modules and SQL/Postgres semantics; app owns tenancy/RBAC/entitlements; isolate Storage/Auth adapters where practical.

### Risk: Next.js framework churn/security

**Mitigation:** use Active-LTS major, pin lockfile, maintain security patch discipline, avoid experimental features as architecture dependencies.

### Risk: Vercel serverless limitations for long jobs

**Mitigation:** do not place long-running device/background workflows in request handlers; introduce an appropriate queue/worker/connector when a concrete workflow reaches that requirement.

### Risk: Design System drift

**Mitigation:** feature code imports internal components, not raw primitives; component acceptance includes desktop/mobile/accessibility behavior; maintain a component showcase/visual regression path as UI volume grows.

## Final recommendation

Proceed with the following Phase 1 baseline, subject to ADR acceptance:

```text
Language:            TypeScript
Web/App:             Next.js 16 Active-LTS line, App Router
Runtime:             Node.js 24 LTS
Architecture:        Modular monolith
Primary database:    Supabase PostgreSQL
Authentication:      Supabase Auth (identity only)
Tenant enforcement:  application membership + Postgres grants/RLS
Files:               Supabase Storage where V1 requires it
Atomic workflows:    transactional Postgres/RPC/application boundary
Hosting:              Vercel
Local DB/Auth:        Supabase CLI local stack
Staging:              isolated persistent non-production environment
PR previews:          Vercel Preview + isolated Supabase preview branch when enabled; safe staging fallback otherwise
Styling:              Tailwind CSS 4.x
UI foundation:        internally owned Design System, shadcn open-code model + Radix accessible primitives
```

This is the smallest stack that satisfies the Foundation Obligations while preserving a credible path to enterprise SSO, new business domains, external integrations, local biometric connectors, dedicated workers, or alternative hosting later.

## Primary official references reviewed

- Next.js App Router and installation/security release documentation — `https://nextjs.org/docs/app`, `https://nextjs.org/blog`
- Next.js cross-platform Adapter API — `https://nextjs.org/blog/nextjs-across-platforms`
- Node.js release/LTS schedule — `https://nodejs.org/en/about/previous-releases`
- Supabase RLS — `https://supabase.com/docs/guides/database/postgres/row-level-security`
- Supabase Auth — `https://supabase.com/docs/guides/auth`
- Supabase local development/migrations — `https://supabase.com/docs/guides/local-development`
- Supabase branching/environments — `https://supabase.com/docs/guides/deployment/branching`
- Supabase enterprise SSO — `https://supabase.com/docs/guides/auth/enterprise-sso`
- Vercel environments — `https://vercel.com/docs/deployments/environments`
- Tailwind CSS — `https://tailwindcss.com/docs`
- shadcn/ui — `https://ui.shadcn.com/docs`
- Radix Primitives accessibility — `https://www.radix-ui.com/primitives/docs/overview/accessibility`
- Clerk Organizations — `https://clerk.com/docs/guides/organizations/overview`
- Auth0 Organizations — `https://auth0.com/docs/manage-users/organizations`
- Neon RLS/connection documentation — `https://neon.com/docs`
