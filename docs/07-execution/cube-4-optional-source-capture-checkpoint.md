# Cube4 optional-source capture — source checkpoint

2026-10-02. Bounded G4 foundation, frozen for independent review. This is not financial source-consumption or full G4 qualification.

## Delivered boundary

`20261002103813_cube4_payroll_optional_source_capture.sql` adds five private SECURITY INVOKER helpers. Current `auth.uid()` is checked through the existing active membership/role authority and `payroll.authorized`; only current Payroll prepare/review/approve/lock/view authority is accepted. Active Employer identity, Tenant, Employee identity, eligible Employment and inclusive Employment dates are joined at each source. No new public endpoint, role, grant, write, trigger, source lock or consumption is introduced. PUBLIC, anon, authenticated and service_role EXECUTE are revoked on every helper.

Attendance captures latest approved immutable fact/interpretation/classification identities, allowlisted quantities, bounded Leave binding identifiers/units, current classification reconciliation boolean and overtime candidate/review/latest classification provenance. Leave captures only ever-approved current approved-preview days, request/version/status, opaque calendar/year/type-version provenance, quantities, mapping state/policy/algorithm/allowlisted minute quantities, correction version links and consumption/reversal identities/units. No source reasons, employee names, clinical type names/IDs, holiday titles, observations, raw fact, raw mapping snapshot or raw leave_sources array is exposed by this capture.

Each enabled domain is exhausted internally through consecutive inclusive windows of at most31 local dates. Ordering is date, Employment ID, source ID. Limits are366 period dates,20,000 matching rows per domain/window and200,000 total matching rows; overflow raises payroll_capacity_review_required rather than returning a partial successful capture. The ordinary supported500 Employment ×31 day case fits the per-window boundary. Additional work instances can still require capacity review.

Both disabled domains return explicit empty snapshots without source helper invocation. Disabled Leave prevents independent Leave capture/effects and never requires Leave authority. When Attendance is enabled, its existing canonical reconciliation helper has a transitive internal Leave provenance read. Root accepted this technical clarification: keep existing Time semantics and optional-module independence, no Cube3 changes or blanket blocker. Actual approved_leave_classification_context joins the selected WorkInstance's Tenant, Employee, Employment, Employer and operational date. Only the resulting reconciliation boolean and strict Time provenance allowlist are retained; the rich current context is not serialized.

The actual private run_manifest receives optional_sources and stale_reasons detects canonical changes using optional_sources_changed. Existing time_integration_pending/leave_integration_pending financial blockers remain. Exact rounding, engine cube4-review-v3-source-safe, financial ACLs and source-writing functions are untouched. Old candidates require recalculation because they lack the capture. The existing run status list receives one Arabic stale label.

Ordered composition supports exactly two known paths: current base functions at qualified ledger115, or renamed run_manifest_before_advances/stale_reasons_before_advances under Slice7 delegating wrappers. It patches the known base with asserted anchors and fails on an incomplete/unknown composition. It does not replace wrappers or certify unqualified Slice6/7/8. A rollback-only model checks delegated field/diff preservation; actual full-chain runtime remains unrun.

## Authored verification

New suite cube4_payroll_optional_source_capture.test.sql contains49 new assertions, NOT RUN. Coverage: invoker/private ACL, Payroll-only actor retaining denial at public Leave API, current Tenant/Employer/membership/permission/user-access denial, both-disabled and independently enabled domains,31/32/93-day exhaustion without gaps, cross-Employer/Tenant exclusion, privacy canaries, deterministic ordering, retained financial blockers, canonical Time context, new fact version/new matching source/cancellation/projection removal and eligibility staleness, append-only deletion refusal, no capture source/financial/audit writes and known wrapper composition.

Fixtures use scoped non-default sites because Legal Entity creation may create a default site. Actual request current-preview FK is deferred; approved-preview FK is immediate: fixtures insert submitted request → preview/day rows → valid approval transition. Cancellation retains preview and increments request version. Membership inactive uses the actual inactive enum. Financial counts target actual final_contexts/payment_events. Synthetic worked fact/version fixtures avoid the classified-absence evidence writer guard; no existing source guard is disabled. Current authority has no expiring role-grant field: removed role/current inactive membership and current user restriction exercise loss of authority; no fictional expiry ABI is introduced.

Read-only actual local QA identity115 and pg_get_functiondef were inspected. Current Attendance projection MD5 b5f9a64685490d7612f6d108c3ff1112; Leave projection MD5 b69a191ca0dcd995486bb6e55df3536c. Latest classified Attendance and approved-replacement Leave definitions/late patches were used, together with actual source constraints/triggers and current Payroll authority/manifest/stale definitions.

Executed source checks only: affected rules.ts ESLint PASS; npm run typecheck PASS. No migration SQL/preflight/tests, DB application, build, browser, commit, push or prior suite repeats were executed by the writer. Independent source review and root rollback-only qualification in both dedicated QA115 databases remain required. No out-of-order migration ledger change is authorized.

## Root qualification evidence

2026-10-02: actual bounded independent source review cycle1 PASS at `cube4-optional-source-capture-independent-review-cycle1.json`. Initial runner assembly stopped before SQL because JavaScript replacement collapsed dollar quoting; replacement callback fixed the harness. The subsequent rollback DDL compiled but fixture setup stopped before assertions on the actual policy UNIQUE(tenant_id,code). A one-line fixture-only code change was independently reviewed PASS, with reverse-hash proof, at `cube4-optional-source-capture-fixture-delta-review.json`. No production SQL or assertion was weakened.

Final migration SHA256 remains `883a62dd8d30b0488d44325b214c221b9cb281713b15d4394b8e67d2c31d31e5`; qualified suite SHA256 is `80bb878e9c7739e928cd28ce3fe84aad11d1ebc61175b9970a13a76e30954d98`. Actual new suite passed49/49 assertions on EACH dedicated fresh/upgrade QA115 database. New DDL and synthetic fixtures were in the same transaction and rolled back; baseline ledger and compiled manifest/stale definitions remained identical. Actual evidence is outside the worktree in `cube4-optional-source-capture-qualification.json`; failed attempt evidence/logs are retained. No migration ledger application, browser qualification, financial integration, commit or push followed this result.

Full-capacity overflow/density execution and the actual ordered Slice6/7/8 chain remain unqualified. This result does not close G4 or G6.

## Remaining gates

Financial reconciliation, compatible final source participation/consumption, optional-domain joint coordination, statutory packs/caps/goldens, source write races, end-to-end G4 and full Cube4 qualification remain open. Capture is a necessary freshness/privacy foundation, not a waiver of those gates.
