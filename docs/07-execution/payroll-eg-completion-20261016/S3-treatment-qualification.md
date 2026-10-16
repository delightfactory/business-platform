# S3 — employee tax-treatment choice and explicit insurance validation

16October2026, baseadebfdc, codex/operator-company-ux. Scope: reviewed employee facts entry, not automatic eligibility, legal approval, pack issuance, payroll calculation or payment. No production writes in this slice.

## Implemented and verified

Actual same-form baseline tax field was INPUT with opaque code placeholder. It is now a native SELECT with eight named ETA2026 classifications, blank mandatory choice and on-demand help. Other documented01..99codes remain enterable in explicit manual mode. Selecting custom retains current value; unknown saved99 rehydrates unchanged. Code00 rejected natively, matching the installed private validator. No new default01 or diagnosis/eligibility inference.

Observed missing frontend validation corrected: insurance_status is required like the installed validator. Insured owner-period now has a required explicit blank placeholder, preserving existing unknown-period fallback. It no longer silently displays/submits the first period while controlled state is empty. No backend validation, API, permission, dates/amounts or locked hidden-value logic changed.

Runtime QA: initial blank tax/insurance invalid;01→custom retains01;00invalid;99valid; insured owner-period empty/required/invalid; notinsured hides insured-only inputs. Explicit save of synthetic99/not_insured succeeds with truthful no-payroll/payment message. Persisted head252d0e03-cca0-4022-81e2-bb10a331b2e4 revision1/referenceNONLEGAL-TAX-SELECT-20261016 in demo tenant a21c4ddf-83f8-4851-abc6-2e226c65a661. Fresh saved-record navigation shows manual99, no substitution. Fixture is open-ended from2026-10-01; no financial-ready effect. Retained as owned synthetic QA audit evidence.

Automation limitation resolved without app changes: date fill() changed DOM but did not commit React state; next rerender restored previous date. Native ArrowUp/ArrowDown edit committed2026-11-01 and survived rerender. Original save therefore recorded the actual blank/open-ended submitted state; do not claim a finite date or product data-loss defect. Test edits discarded by reloading owned fixture. No operational data correction attempted.

## Gates and review

Scoped2file ESLint exit0, full Next build exit0. Build REa_t5xkXYmmv8Dj-Xp7f on61193, owned session69142. Root observed matching API/PG save roundtrip. No new test framework or literal-constant tests. Earlier build used before the observed native validation fixes is superseded; no repeated broad tests.

Root inspected phone390 with known01 help and desktop1366 saved99, readable RTL/no overflow. Tablet768 fieldleft384.4/right716/page753 fits768. Guide source/HTML/PDF updated36pages; changed employee explanation visually read on23. The attempted page22 inspection showed preceding unchanged section; actual changed page23 subsequently read, no false page claim.

Official Claude Opus5.5Medium320cebe1-638f-4599-b21d-cd6cbab2a7eb source+actual two-PNG visual PASS, readOnlyViolation=false. Reviewer did not independently verify ETA wording or run gates; root used official FAQv4questions27–34 and actual installed validator. Conditional informational nested-label concern resolved from current Field implementation: div wrapper plus label htmlFor, valid nesting. Arabic-Indic digits remain unsupported like backend; manual help shows01..99. Parent form remount keys preserve known/unknown record initialization. No optional-polish loop.

## Release preflight, read only

Vercel team team_AYQTvxuQJ1EepKxDVhzjX1ew / project prj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa (business-platform-production) returns production READY deploymentdpl_8xirHgiQrSNcvLyppz8TaKAfJzm1, business-platform-production-komi3hy2n.vercel.app, dub1. Custom-host deployment lookup resolves same ID. Source is cli; provider metadata has no GitSHA. Prior receipt binds it to e8abd14, but do not claim live provider GitSHA proof. /release-identity.json returns404 and is not an identity endpoint for this project.

Supabase msryvzefjdqjcfikerne/business-platform-production ACTIVE_HEALTHY/eu-west-1, expected organizationpchajhscmbfswwvgeifl via link_6ab668fc7808819186f4e9b5aed1d71e. Fresh read:218migrations/latest20261016033425; new admin catalog absent; original permission function still explicit-only, ownerpostgres, ACL{postgres=X/postgres}; statutory drafts/packs0. Captured actual original function to external production-original-permission.sql (terminal semicolon added for executable recovery). No migration, grant, deploy, subscription or production data mutation. Initial multi-SELECT API returned only last rows; initial wrapper parsing failed safely; corrected anchored data-block parsing obtained actual rollback source. Do not confuse parser failures with provider failure.

## Remaining full goal

Release qualified changes with exact source metadata/backup/rollback proof; official reviewer results/attestation and Egyptian pack qualification; inspect company's policy-editability requirement, since current payroll_policy_already_set prevents any later policy save despite dated input-version infrastructure. Resolve that actual gap within financial history guards, not by removing all guards. No whole-goal acceptance. External temporary-process/dependency/database/evidence retention remains necessary. Prior duplicate-capture cleanup rejection stands; no deletion/reclamation claim or alternate retry.
