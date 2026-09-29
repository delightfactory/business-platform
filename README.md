# Business Platform

The platform is domain-oriented and multi-tenant, with HR & Payroll planned as its first commercial domain. This repository contains the local app foundation and a narrow invite-only Operator entry path; it does not implement Tenant onboarding or business workflows.

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

Authentication is invite-only email/password; public signup is disabled. Password recovery uses the Supabase PKCE callback. Local Auth mail is captured by Inbucket at <http://127.0.0.1:55324>. Production password recovery requires configured SMTP and an allowlisted app callback URL. No service-role key is used by the web app.

The `/operator` page verifies the current Auth user and reads only that caller's current grant through `current_platform_operator_status()`. Tenant onboarding and further Operator management workflows are separate future slices.

## Local quality gates

```powershell
npm run lint
npm run typecheck
npm run build
npm run test:db:operator
```

Package versions are exact and `package-lock.json` is committed for reproducible installation. GitHub Actions runs lint, typecheck, and build on pull requests. The focused DB command requires the local Supabase stack and applies migrations first.

Platform Operator maintenance bootstrap/recovery instructions are in [supabase/maintenance/README.md](supabase/maintenance/README.md).

## Governing documentation

The approved product, architecture, security, and execution baseline is indexed in [docs/README.md](docs/README.md). New business behavior must follow those specifications and reach `main` through a reviewed PR.
