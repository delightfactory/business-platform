# Cube 1 — People Foundation execution record

Status: in progress. Base: `main` at `a4676218d6a3537fd45a45d54e494079d580f323` after Cube 0 closure.

## Outcome and slices

Deliver complete, usable People journeys in bounded slices: (1) employee onboarding and directory with authoritative access; (2) organization context and assignment changes; (3) effective compensation and employment lifecycle; (4) optional employee/user linking and direct account creation; (5) named Time work-policy context where Attendance is enabled; (6) workforce import with preview, confirmation and reject report. Each slice closes its UI, database, permission, failure, audit and focused test path before the next one.

## Employee and user choices — owner addition, 2026-09-30

The employee record and authenticated user remain separate identities. The People experience supports four ordinary paths:

1. An administrator invites a user through the existing membership flow, then creates or finds the employee record and links them.
2. An authorized HR administrator creates an employee, provisions a user account directly, and links them in one guided task, without requiring the membership invitation acceptance flow.
3. HR creates an employee record only, with no user account.
4. HR creates an employee and links an existing active user in the same Tenant.

Account provisioning never asks HR to know or choose the employee's private password. The account is provisioned directly, and the employee receives a single-use password-setup path before first login. This is an account-activation step, not a Tenant membership invitation. The form defaults to employee-only; the other options appear when needed.

Direct account creation requires both People management and Tenant user-management authority, respects the active-user limit and protected administrator rules, and records who created and linked the account. The email cannot silently attach to an unrelated existing account. Existing-user linking requires an active Membership in the same Tenant and never changes the user's permissions. One active employee/user link per Tenant is enforced. Auth creation and People writes span separate systems, so the implementation must expose a recoverable pending/failed state and idempotent retry rather than reporting a partial result as success.

## Release boundary

The owner deferred physical-phone and actual assistive-technology acceptance until an integrated Vercel build with a live database and several complete cubes. Browser-based mobile/tablet/desktop checks remain part of each development slice. The deferred checks are release gates, not completed evidence.
