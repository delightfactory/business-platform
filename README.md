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

The `/operator` hub verifies the current Auth user and shows only tasks granted by current database authority. `/operator/operators` lets an active `can_manage_operators` manager grant, update, or revoke the implemented capabilities `can_manage_operators`, `can_onboard_tenants`, `can_manage_tenant_lifecycle`, and `can_manage_commercial_access` for an existing verified Auth account with a usable login credential. Every change requires a reason and records before/after state atomically in the append-only Operator audit. A grant must contain at least one implemented capability; revocation has a separate confirmation action. `/operator/onboarding` and `/operator/invitations` remain limited to `can_onboard_tenants`; `/operator/tenants` is limited to `can_manage_tenant_lifecycle`.

An Operator with `can_manage_commercial_access` can review active user-seat and Site usage at `/operator/commercial` and set each effective limit to a positive number or explicit unlimited. Each change requires a reason and creates an effective-dated, audited limit record. Lowering below current usage keeps existing memberships and Sites active; creating or reactivating resources remains blocked until usage becomes lower than the limit or the limit is raised. Missing limits can be initialized when no conflicting future interval exists. Plans, billing, and future scheduling are not part of this control.

Tenant lifecycle changes are reason-required audited transitions: active→suspended or archived, suspended→active or archived, and archived→suspended. The archived restore path requires a separate later reactivation. Active-member routing uses a bounded active/suspended Tenant projection; suspended pages expose status and support guidance without business snapshots, while archived Tenant names remain hidden from members.

A pending first-Admin invitation creates no Tenant or seat; acceptance atomically creates the Tenant, default Legal Entity/Site, protected Admin membership, capability limits, and audit records. An invitation remains recoverable through explicit reissue or revocation; each newer issuance invalidates older links. Maintenance bootstrap and recovery require an existing verified account with a usable password credential; invited accounts must first record password readiness.

A Tenant administrator can invite a Member from `/tenant/<tenant-id>/users`. Pending invitations grant no access and consume no seat. Acceptance, disablement, and reactivation enforce the current Tenant state, permission, and effective user limit in the database. A Member invitation assigns the fixed Member role; an authorized Tenant Admin can then promote an active Member or demote an Admin from the same page. Each role change is audited atomically, preserves Domain role assignments, and leaves seat usage unchanged. The final recoverable Admin cannot be demoted.

Authorized Tenant users can manage shared Legal Entities and Sites from `/tenant/<tenant-id>/entities-sites`. Entity display name and optional legal name are separate values; Site identity stays attached to its Legal Entity. Site creation/reactivation uses the effective `max_sites` limit across all Entities and checks it under the Tenant lock. Records are deactivated rather than deleted, and each change writes an append-only audit event with a reason. A Tenant can temporarily have no active default while setup or recovery is needed.

When the user limit is `1`, replacing its only Admin uses the Operator limit control: raise the limit from `1` to `2`, invite and accept the replacement as a Member, promote the replacement, demote the former Admin, deactivate the former Admin's membership to free the second seat, then lower the limit from `2` to `1`. Demotion alone does not free a seat because the membership remains active.

## Local quality gates

```powershell
npm run lint
npm run typecheck
npm run build
npm run test:db:operator
npm run test:db:invitations
npm run test:db:members
npm run test:db:admin-roles
npm run test:db:operator-management
npm run test:db:entities-sites
npm run test:db:commercial
```

Package versions are exact and `package-lock.json` is committed for reproducible installation. GitHub Actions runs lint, typecheck, and build on pull requests. Database tests require the local Supabase stack with current migrations applied (`supabase migration up --local`, or `supabase db reset --local` for a disposable clean database).

Platform Operator maintenance bootstrap/recovery instructions are in [supabase/maintenance/README.md](supabase/maintenance/README.md). Operator authority checks are in `supabase/tests/platform_operator_authority.test.sql` and `supabase/tests/platform_operator_management.test.sql`. Invitation database checks are in `supabase/tests/tenant_admin_invitations.test.sql` and `supabase/tests/tenant_member_invitations.test.sql`; Admin role governance checks are in `supabase/tests/tenant_admin_role_governance.test.sql`; Legal Entity and Site checks are in `supabase/tests/tenant_legal_entities_sites.test.sql`.

## Governing documentation

The approved product, architecture, security, and execution baseline is indexed in [docs/README.md](docs/README.md). New business behavior must follow those specifications and reach `main` through a reviewed PR.
