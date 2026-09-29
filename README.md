# Business Platform

The platform is domain-oriented and multi-tenant, with HR & Payroll planned as its first commercial domain. This repository contains a narrow invite-only Operator path for onboarding a Tenant's first Admin; broader Tenant workflows and business operations remain future slices.

## Local setup

Requirements: Node.js 24, npm, Supabase CLI, and Docker Desktop.

```powershell
npm ci
Copy-Item .env.example .env.local
```

Start Supabase locally, copy the local publishable key from its status output into `.env.local`, then run the app:

```powershell
supabase start
npm run dev
```

Open <http://localhost:3000>. The local API uses port `55321` to avoid collisions with another local Supabase project. Keep local/preview configuration separate from production as required by ADR-009. With missing environment values, the login and Operator pages show setup states without needing live Supabase during build.

Authentication is invite-only email/password; public signup is disabled. Password recovery uses its own Supabase PKCE callback. First-Admin invitations use a distinct callback and are accepted only when the verified Auth email matches the pending intent. Local Auth mail is captured by Mailpit at <http://127.0.0.1:55324>. The server-side invitation sender requires `SUPABASE_SECRET_KEY`; never prefix it with `NEXT_PUBLIC_` or expose it to browser code. Templates under `supabase/templates` configure local Supabase only and do not automatically update hosted Supabase. Production requires an allowlisted app origin, the matching hosted invitation templates, and configured SMTP before sending real invitations.

The `/operator` flow verifies the current Auth user and reads current Operator authority from the database. A pending first-Admin invitation creates no Tenant or seat; acceptance atomically creates the Tenant, default Legal Entity/Site, protected Admin membership, capability limits, and audit records. An invitation remains recoverable through explicit reissue or revocation; each newer issuance invalidates older links.

## Local quality gates

```powershell
npm run lint
npm run typecheck
npm run build
npm run test:db:operator
npm run test:db:invitations
```

Package versions are exact and `package-lock.json` is committed for reproducible installation. GitHub Actions runs lint, typecheck, and build on pull requests. The focused DB command requires the local Supabase stack and applies migrations first.

Platform Operator maintenance bootstrap/recovery instructions are in [supabase/maintenance/README.md](supabase/maintenance/README.md). Invitation database checks are in `supabase/tests/tenant_admin_invitations.test.sql`.

## Governing documentation

The approved product, architecture, security, and execution baseline is indexed in [docs/README.md](docs/README.md). New business behavior must follow those specifications and reach `main` through a reviewed PR.
