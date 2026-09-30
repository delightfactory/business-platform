# Cube 1 — People Foundation execution record

Status: in progress. Base: `main` at `a4676218d6a3537fd45a45d54e494079d580f323` after Cube 0 closure.

## Outcome and slices

Deliver complete, usable People journeys in bounded slices: (1) employee onboarding and directory with authoritative access; (2) organization context and assignment changes; (3) effective compensation and employment lifecycle; (4) optional employee/user linking and direct account creation; (5) named Time work-policy context where Attendance is enabled; (6) workforce import with preview, confirmation and reject report. Each slice closes its UI, database, permission, failure, audit and focused test path before the next one.

## Directory search and pagination — implementation slice, 2026-09-30

The directory uses the authenticated `people_directory_page` RPC. Search matches employee name or code; each request returns at most 25 rows, and page numbers are bounded to 1–1000. The response includes directory fields and organization context, with no compensation data. The Arabic page uses GET search and pagination controls, validates query/page bounds, and shows separate empty and load-error states. Focused pgTAP coverage checks search, page size/continuation, page cap, Tenant denial and compensation-field exclusion. Evidence: the migration was applied to local Supabase; `supabase test db --local supabase/tests/people_directory_search.test.sql` passed (8 assertions); `npm run typecheck` and targeted ESLint passed. No production or remote database was changed. Search currently uses lowercase substring matching without a dedicated search index, so database work can still grow with the Tenant's employee count even though returned pages and offsets are capped.

## Departments and Jobs catalog — implementation slice, 2026-09-30

The Tenant-owned catalog now supports bounded search and page reads, create/edit, active/inactive status, optional department parent and optional job department. The People screen links to catalog management for users with `org_context.manage`; mutations enforce that permission plus the existing `hr.people` entitlement, and table grants remain revoked. Parent references are composite Tenant-scoped FKs; department changes serialize per Tenant and reject cycles. An append-only organization audit stream records the actor, Tenant, subject, event and before/after values for each committed change. Disabling a department/job leaves work assignments intact; a trigger and the employee onboarding options prevent inactive records or records under inactive parents from being selected for future assignments. Primary reporting-manager selection remains for the work-assignment slice.

Evidence: migrations `20260930003348_people_departments_jobs_catalog.sql`, `20260930005546_people_work_assignment_catalog_history_guard.sql`, and `20260930010156_people_job_history_guard_and_onboarding_audit.sql` applied to local Supabase; focused pgTAP test passed (34 assertions), including the second catalog page, 1000/1001 option boundary, invalid/null kind, cross-Tenant access/reference denial, cycle rejection, active/inactive assignment eligibility, audit actor/action/Tenant, initial Department/Job audit values, historical assignment preservation, closing an existing assignment after its Job is disabled, and blocking Department changes for Jobs with assignment history while permitting a rename. The Job history trigger uses invoker rights. `npm run typecheck`, `npm run lint` and `npm run build` passed. No production or remote database was changed. Browser viewport and assistive-technology acceptance remain outstanding; Next build confirms both catalog routes are registered and dynamically rendered.

## Work assignment transfer and history — implementation slice, 2026-09-30

Employee detail now shows a bounded history of the latest 100 work assignments and a focused transfer form for users with `org_context.manage`. Older records are retained but not pageable in this UI yet. Read history uses `people.view`; transfer choices and schedule/cancel RPCs enforce `org_context.manage`. Site, Department, Job and optional manager are validated in the authoritative transaction for Tenant, active status, Employment Employer, Job/Department match and manager self-reference. A manager must be a same-Tenant active Employee whose Employment is active by the assignment's effective date; reporting remains a simple assignment reference, not an org graph. Transfer option lists are capped at 1000 choices each and report truncation to the UI.

Transfers may start today or later. `valid_until` is exclusive, so the prior interval ends exactly on the new assignment's effective date. The exclusion constraint remains the overlap guard. Cancel is available only before a future assignment takes effect; it removes that future row, restores the prior interval and records both contexts in an append-only actor/Tenant audit event. A change effective today is already active and cannot be cancelled through the future-transfer action. The current V1 limit is one pending future assignment per Employment; HR must cancel it before scheduling another. Backdated transfers and effective dates not later than the current assignment's own start are rejected. Finalized downstream context is outside this mutation path. The physical-device gate remains deferred for this People workflow.

An audited `تصحيح بيانات العمل اليوم` action handles an initial assignment created on the Employment start date: only that day's open initial row can be corrected, its assignment ID is preserved, and site/department/job/manager are revalidated. Future-start managers are shown with their start date and accepted only when active by the transfer effective date; a manager who starts after that date is rejected. This correction is a Cube 1 boundary while Attendance/Payroll consumers are absent. Cube 2 and Payroll must block this correction once downstream facts consume the work context, and must preserve the context consumed by finalized facts.

Evidence: migrations `20260930011017_people_work_assignment_transfers.sql` and `20260930013832_people_initial_assignment_correction_and_dated_managers.sql` applied to local Supabase. Focused test `supabase/tests/people_work_assignment_transfers.test.sql` passed all 44 assertions, covering same-day initial correction and stable assignment ID, dated future-manager eligibility, today/future scheduling, exclusive interval boundaries, history/options, cancellation and restoration, repeated schedule and overlap rejection, cross-Tenant/inactive/mismatched references, self/inactive/too-late managers, permission gates and actor/context audit. `npm run typecheck`, `npm run lint`, `npm run build`, and `git diff --check` passed. No production/remote database mutation or commit.

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
