# S4 — Future company policy versions

Owner authorizes dated company defaults; contract: docs/04-product-specs/company-payroll-policy-versions-20261016.md. Base475ae61, same isolated devbranch. No rate/legal authority or payment execution change.

## Behavior

Existing single tenant policy head/partial unique index retained. Save appends a version with a future Cairo date, strictly later than current latest and without a new end date. Any active selected employer under the same tenant can edit; stored head/version employer stays original, selected execution employer remains in audit. Existing authorization/tenant lock/receipt replay/stale/immutable/frozen guards retained. The conservative all-employer frozen-range rule intentionally remains stricter than period-start adoption. Initial-create contract otherwise retained, with nonfinite policy dates rejected.

Producer selects the policy at period start and keeps it for the whole period, even when a newer version begins mid-period. Explicit expiry must still cover the complete period; cancellation/invalid/missing coverage never revives older data. Existing calendar/statutory/correction blockers remain. Installed manifest includes all applicable dated versions across tenant employers. Historical one-head/one-version policy calculations are unchanged; existing engine label retained, source/migration revision identifies the new semantics. Never rewrite historical finalized outputs.

UI exposes edit-upcoming-periods, latest saved version (possibly future), and the policy for a period starting today when the latest is future; this is explicitly not proof of whole-period coverage. New effective date and edit reason start blank. Next date min combines latest+1, tomorrow Cairo, frozen end+1. Required date/reason and existing uncertain-attempt handling remain.

## Gates and evidence

- New dedicated rollback SQL27PASS; includes same/other-employer duplicate create, today's guard independently of monotonic date (initial date2000), date/expiry/permission/foreign employer/stale/replay, original data and composite ownership, audit context, current-vs-future workspace, staggered periods, expired/cancelled policy and tenant-wide frozen guard. No legal pack/finalized payroll fabricated.
- Original cube4_payroll_inputs50PASS. Original review-fixes first28PASS including6expiry/cancellation cases. Full original review-fixes aborts at payroll_approval_blocked on both original and changed producer; recovery evidence outside repo. No weakening of the approval guard. New canonical public monthly Leave/recurring financial journey41PASS under S4; existing explicit NONLEGAL issuer simulation, never official acceptance.
- Final scoped3file ESLint0; full Next build0. BuildJ9fzusI2c1YEcCeEKkNOU, port61193owned session18662;61190preserved.
- Actual built UI: initial rev1->2 saved but React key change hid success. Fixed stable employer/policy key. Final rev3->4 save visibly shows success +view link; next view reload correct. Future record preserved, required date blank, min2026-12-02 atrev3, reason blank. Prior today native underflow true atmin2026-10-17. QA head8ad5e415-3c15-467a-9cb2-f7b734eae84f/demo tenant, versionsOct1/Nov1/Dec1/Jan1, NONLEGAL only. First-create redirect is source-reviewed, not separately runtime-exercised; actual public initial-create covered in SQL. No unsupported runtime claim.
- Root read phone390x1000 success and desktop1366x1400 form images; desktop repeated bottom header is capture artifact. Earlier390x844/768tablet/1366desktop DOM no horizontal overflow. Final images include current-vs-future context, blank form fields/save and success status. Tablet/error/first-create not independently visual-accepted by Claude.
- Source/HTML/PDF guide updated;36pages, root visually read changed23. Source continues onto24. No legal/financial acceptance claimed.

## Independent review

Official Claude Opus5.5Medium844cb76a-d856-4ec6-a149-6488f36dac67 finalPASS, readOnlyViolation=false, source+two actual images. First conditional uniqueness concern resolved from retained actual index + strengthened tests; fresh reason/current policy context implemented; existing date helper verified. Two bounded reviews, no optional-polish loop. Nonblocking limits retained: mode label wording inconsistency, unknown corrupt today-mode fallback (calculation still rejects), initial-create success wording remains accurate, first-create redirect/runtime not independently exercised. Root confirms href preserves employer/return context and policyTab explicitly tests query.kind=policy, so no tab/redirect loop.

## Production and storage boundary

Read-only fresh production preflight:218migrations/latest20261016033425; original3function definitions match QA baseline. Actual rollback source/ACL external S4-production-original-functions.json +S4-production-rollback.sql. S1 original permission source also preserved. Vercel custom host stilldpl_8xirHgiQrSNcvLyppz8TaKAfJzm1. No production write in this receipt; staged source must be committed/pushed on devbranch before bounded qualified release. Human reviewer identity/results still pending, user will appoint. Preserve active caches/previews/databases/official sources/recovery journals. Prior exact obsolete-capture cleanup automatically rejected; no deletion/reclaimed bytes claimed, no alternate retry.
