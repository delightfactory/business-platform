# Business Platform

The platform is domain-oriented and multi-tenant, with HR & Payroll planned as its first commercial domain. Cube 0 currently covers invite-only Operator onboarding and Tenant Member invitations; the remaining Platform workflows and business domains are future slices.

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

Authentication is invite-only email/password; public signup is disabled. Password recovery, first-Admin invitations, and Tenant Member invitations have separate callbacks. Invitation acceptance requires the verified Auth email to match the pending invitation. Local Auth mail is captured by Mailpit at <http://127.0.0.1:55324>. The server-side invitation sender requires `SUPABASE_SECRET_KEY`; never prefix it with `NEXT_PUBLIC_` or expose it to browser code. Templates under `supabase/templates` configure local Supabase only; restart the local stack after changing them. Production requires an allowlisted app origin, matching hosted invitation templates, and configured SMTP before sending real invitations.

The `/operator` flow verifies the current Auth user and reads current Operator authority from the database. A pending first-Admin invitation creates no Tenant or seat; acceptance atomically creates the Tenant, default Legal Entity/Site, protected Admin membership, capability limits, and audit records. An invitation remains recoverable through explicit reissue or revocation; each newer issuance invalidates older links.

A Tenant administrator can invite a Member from `/tenant/<tenant-id>/users`. Pending invitations grant no access and consume no seat. Acceptance, disablement, and reactivation enforce the current Tenant state, permission, and effective user limit in the database. A Member invitation assigns the fixed Member role; administrator replacement requires a separate governed flow. Users with multiple active Tenant memberships choose a company at `/tenant/select`.

## Local quality gates

```powershell
npm run lint
npm run typecheck
npm run build
npm run test:db:operator
npm run test:db:invitations
npm run test:db:members
```

Package versions are exact and `package-lock.json` is committed for reproducible installation. GitHub Actions runs lint, typecheck, and build on pull requests. Database tests require the local Supabase stack with current migrations applied (`supabase migration up --local`, or `supabase db reset --local` for a disposable clean database).

Platform Operator maintenance bootstrap/recovery instructions are in [supabase/maintenance/README.md](supabase/maintenance/README.md). Invitation database checks are in `supabase/tests/tenant_admin_invitations.test.sql` and `supabase/tests/tenant_member_invitations.test.sql`.

## Governing documentation

The approved product, architecture, security, and execution baseline is indexed in [docs/README.md](docs/README.md). New business behavior must follow those specifications and reach `main` through a reviewed PR.
