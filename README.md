# Business Platform

The platform is domain-oriented and multi-tenant, with HR & Payroll planned as its first commercial domain. The repository is moving from the Phase 0 documentation baseline into Cube 0 implementation. This commit provides a locally runnable application foundation only; it does not contain business workflows or connect to a database.

## Local setup

Requirements: Node.js 24 and npm. Install the Supabase CLI and Docker Desktop to run the local Supabase stack.

```powershell
npm ci
Copy-Item .env.example .env.local
npm run dev
```

Open <http://localhost:3000>. The Arabic RTL page is explicitly labeled as a development foundation. Tenant setup and authentication workflows are the next implementation slices.

To initialize and run Supabase locally:

```powershell
supabase start
```

The repository contains the CLI-generated `supabase/config.toml`; no product schema, migrations, seed data, or Auth flow is included yet. Keep local/preview configuration separate from production as required by ADR-009.

The local Auth configuration disables public sign-up and requires email confirmation in preparation for the approved invite-only workflow. No application login path is connected yet.

## Local quality gates

```powershell
npm run lint
npm run typecheck
npm run build
```

Package versions are exact and `package-lock.json` is committed for reproducible installation. GitHub Actions runs these gates on pull requests.

## Governing documentation

The approved product, architecture, security, and execution baseline is indexed in [docs/README.md](docs/README.md). New business behavior must follow those specifications and reach `main` through a reviewed PR.
