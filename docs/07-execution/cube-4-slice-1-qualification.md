# Cube 4 Slice 1 — implementation qualification checkpoint

Status: **Implemented local candidate; qualification in progress. Not Cube 4 complete.**

Base: `555c34a568f44eb4b99d99712a699094488f3026`. Branch: `codex/cube4-payroll-core`. Governing operational choices are recorded in the accepted 2026-10-02 amendment. No Cube 3 repair or financial/source-consumption implementation is included.

## Delivered candidate

Payroll privately owns Employer calendar heads, effective versions, generated civil-date periods, attributable mandatory audit and canonical command receipts. Supported public RPCs are bounded Employer discovery, access/workspace reads, actual date preview, calendar save with first-period generation, and next-period generation. Direct table/schema access and public/anonymous/service-role execution are revoked; tables have RLS. Ordinary views show Employer names, actual dates, business actions and configuration history without internal keys.

The Arabic RTL route `/tenant/[tenantId]/payroll` supports discovery, unique-Employer default only when unambiguous, setup, actual preview, reviewed save, future configuration changes, retained validation/transport errors, cancellation and period history/readiness. Tenant business navigation and the existing role-management screen expose the supported Payroll reader/preparer/calendar-manager bundles. Existing bundle snapshots are preserved.

Calendar and generation commands share the existing Tenant authority advisory key before locking Tenant/user/membership/Employer and the Payroll head. They recheck current authority/entitlement under these locks and before return. CAS, attempt-key intent and receipts protect repeated/concurrent requests. Calendar revision begins after the last generated boundary; historical periods are append-only. There are no financial runs or irreversible financial locks in this slice; later slices must add their explicit same-transaction guards before exposing them.

Numbered cutoff/payment days support 1–31 with shorter-month clamping, plus explicit month-end cutoff. Ending-month payment rules must remain valid in longer months: payment day cannot precede the configured cutoff (month-end requires day31). A 25→24 cycle uses cutoff24, distinct from cutoff25's 26→25. Payment dates never shift automatically for holidays. Versions/periods retain explicit timezones, defaulting to Africa/Cairo.

Readiness does not assert financial readiness or legal qualification. People, Time, Leave and Finance checks remain explicitly not checked; optional-service absence is not described as an error. Calculation is visibly unavailable. This slice does not consume source facts, disclose Leave reasons, infer statutory rules or change Cube 3.

## Evidence recorded by implementer

- `npm run typecheck`: exit0 after source changes and after the bounded reviewer state-key/conflict correction.
- `npx eslint 'src/app/tenant/[tenantId]/payroll' 'src/app/tenant/[tenantId]/users/actions.ts' 'src/app/tenant/[tenantId]/users/page.tsx' src/components/context-navigation.tsx`: exit0 on the final UI delta.
- `git diff --check`: exit0 after correcting trailing blank lines. Existing root-owned documentation changes are preserved.
- Migration created using installed `supabase migration new cube4_payroll_calendars` (CLI2.106.0); no migration application performed by implementer.
- Root reported initial selected dedicated upgrade migration application at110 migrations and date assertions16/16 PASS, transaction ROLLBACK. The subsequently accepted payment-rule invariant changes the date suite to17; final helper application and changed-suite evidence remain root-owned qualification work.

## Focused tests and remaining qualification

`supabase/tests/cube4_payroll_calendar_dates.test.sql` covers distinct cutoff cycles, month-end, cutoff29–31 in February/leap years, payment clamping, rejected pre-end/future-invalid payment rules, year boundaries and reviewed transition dates.

`supabase/tests/cube4_payroll_calendar_commands.test.sql` uses new Payroll-only synthetic actors/Tenants/Employers, asserts either dedicated Cube4 QA database identity, and rolls back every fixture/write. It covers Tenant/Employer scope, ambiguous Employer default, exact receipt replay, different intent key conflict, CAS refusal, generated/history continuity, atomic audit failure, current entitlement/membership loss before replay, reader denial, direct private access and Tenant suspension. This suite was authored but not executed by the implementer.

Root must finish independent command/race assertions on the dedicated databases, the final helper/migration hash, fresh replay/parity where possible, and actual authenticated browser setup→preview→save→readiness/revision/error journey at390/820/1280. Cross-session calendar-versus-generation and authority changes need observed serialization evidence. Typecheck/lint and readable dates alone do not close those gates. Any unavailable fresh replay or source-consumption work must remain explicitly unqualified.

No commit, push, merge, deployment, remote migration, production mutation, reset or old-fixture deletion was performed.

## Independent local checkpoint

The dedicated upgrade database `business_platform_cube4_upgrade_qa` has 110 migrations. Final source migration SHA256 is `d1e3efb010ae5f3123335dca7af87c4a815f6e3cb8dc081ebf187c83cca82a82`; the initial migration was applied atomically, then only the changed date helper was replaced for local iterative qualification. A final fresh replay must still prove the exact whole source file.

- Dates: 16 assertions passed before the bounded ending-month invariant correction; the one newly added February-invalid-rule assertion passed after it. Passing unchanged date cases were not rerun.
- Command/security suite: 30 assertions passed and all synthetic writes rolled back. The later helper correction affects ending-month rules; this suite uses following-month rules, so it was not repeated.
- Two independent authenticated sessions: generation before calendar change and calendar change before generation both showed an advisory-lock wait; after the first commit, the second stale command returned PT409. Three lawful periods, three audits and three receipts remained, with no duplicate effects.
- Review found scope-state retention and definitive-error confirmation issues; these were corrected. The browser then exposed uncontrolled select reset after preview, which was corrected using controlled fields. Earlier failing synthetic history is preserved; browser qualification resumes on a separate synthetic Employer.
- Fresh database engine restoration completed, but baseline application halted on PostgreSQL authority over `auth.users`. Fresh qualification is incomplete and has not been retried during feature implementation. This gap does not close acceptance or justify Cube 3 repair.

Actual final browser evidence and responsive checks remain pending until recorded below. Full Cube 4 matrix rows are not promoted to PASS by these narrower results.

Final local browser checkpoint: **PASS**, build `rY9unyRD-fbqg9E9drBWX`, application `http://127.0.0.1:3335`, dedicated gateway `http://127.0.0.1:3333`, dedicated upgrade database above. Actual authenticated UI saved `2027-01-25..2027-02-24` with payment `2027-02-25`, generated `2027-02-25..2027-03-24`, then reviewed/saved a future month-end transition `2027-03-25..2027-03-31` with payment `2027-04-01`. Reload retained three periods, two calendar versions, three audits and three receipts. Changed fields invalidated confirmation, and persisted dates matched selected form values. Widths 390/820/1280 passed horizontal overflow checks; the mobile screenshot was visually inspected. The uncontrolled-reset defect required cancelling the native reset event in addition to controlling fields; measured pre/post-preview values and final saved dates confirm that correction. Final webpack build and its TypeScript stage exited0. Earlier failing synthetic history was retained.

Evidence is outside Git under the local run root: `cube4-browser-evidence.json`, `cube4-calendar-{390,820,1280}.png`, `cube4-race-evidence.json`, `cube4-calendar-commands-test.log`, `cube4-date-delta-evidence.json` and build logs. The native reset behavior was checked against [the React form documentation](https://react.dev/reference/react-dom/components/form); the qualification conclusions above rely on observed local behavior.

Slice 1 remains a scoped implemented/verified local candidate, not final full qualification: fresh replay/parity, additional authority-loss races and full release acceptance remain open. Proceed to Slice 2 without reopening Cube 3 repair or repeating unchanged passing suites.
