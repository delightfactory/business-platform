# Manual and finishing UX pass — 2026-10-16

Owner scope: update the user guide to the accepted EDARA transformation and recommend instructions by actual tasks/permissions; inventory remaining routes/components and implement small coherent UX improvements. No business rules, financial calculations, access grants, schema changes or paid upgrades.

## Delivered behavior

- Help opens `/guide` only on request. Authenticated server access snapshots determine granular public training topics. No names, records, credentials or financial values are sent into the public guide URL. Reading help never calculates a run or opens audited employee payroll history.
- Independent employee/team/attendance/leave/payroll setup/preparation/approval/closing/payment/correction/report/advance/operator tasks combine for multi-role accounts. Existing dynamic migrations expose `can_approve` and `can_lock`; these are used independently. Only successful explicit boolean grants recommend management tasks. Denied reads add nothing; other read failures display a partial-verification message. This is guidance, never authorization or confidential-document protection.
- Empty personal recommendations show start/help, never silently switch to all roles. A complete public training option, legacy topic bookmarks, current-view printing and full downloadable PDF remain available.
- 34 chapters / 62 task blocks; current labels and routes, Arabic-normalized local search, synchronized table of contents/results, clear/no-result behavior. Search excludes task-hidden text and removes the long introduction until cleared.
- Payroll collection at <=640px uses the same table/data/actions as complete labelled records, all eight columns retained. Desktop comparison table remains; tablet scroll is confined to the table.
- Calendar review link retains payroll return scope; employee activity/period dates use existing human display format; captions remain available to assistive technology; required markers use a non-breaking space.
- Employer switching guidance reflects editable vs read-only work. Report examples name the correct input. Advances distinguish first use, no search matches and later empty pages, with recovery. Incomplete activation links explain recovery. Login returns preserve employee/payroll and member-invite context. Payment empty instructions refer to approval/closing rather than an unsupported mandatory legal-review gate.

## Coverage and verification

Baseline source inventory: 87 page routes, including legacy aliases. The new guide route brings the source total to 88. ROUTE-COVERAGE documents the bounded source inspection level for each baseline route; this is not execution of 88 full journeys. Shared fields/help/tabs/tables/navigation reviewed. No unnecessary change to leave tab authorization or UTC interpretation.

25 focused tests PASS: 10 navigation, 7 recommendation flags, 8 filtering/search/anchor integrity. No duplicated whole financial qualification run, because money/security business logic was not edited.

Rendered local checks: actual company-admin guide includes independent close topic with no partial warning; reader hides approval and closing steps; payment-only search returns its one chapter; unrelated hidden payment content yields no hits; clear restores introduction. Payroll collection 390px no page overflow and complete record, 1366px eight-column comparison; 768px confined table scroll. Calendar review href retains supplied payroll context. Employee activity empty state remains clear. Screenshots held outside sync roots. These are scoped browser checks, not physical-device or screen-reader acceptance.

PDF regenerated in all-training mode with all 34 chapters and zero hidden task blocks. A4 / tagged / 37 pages; representative first and payroll pages rendered and visually reviewed. PDF is the complete training manual, not an individual's recommended sections.

## Independent review

Official Claude Opus 5.5 Medium, first-party session e5114873-1591-4ae3-b14e-98afdd2d01ce: source PASS, no P1. Initial 16-turn read budget ended; one tools-disabled finalization returned its findings. It did not execute tests or read the complete manual/PDF. Its hypothetical advance-report gap is ruled out by `payroll_navigation_access`: finance simultaneously sets advances/report access. Date risk ruled out by `employee_activity_workspace`: all four kinds emit civil dates, advances explicitly cast in Cairo. Later exact close-flag mapping independently reviewed by the manual reviewer; two small coverage/copy findings fixed. Parent reviewed code, manual claims, tests and rendered output. No claim of universal accessibility/user acceptance.

## Release and cleanup

Development branch only; preserve prior production deployment for rollback. Verify exact project/team/source and domain after any promotion. No Supabase migration or data mutation is part of this pass. Temporary outputs/dependencies remain outside OneDrive; retain source, final guide, review summaries and representative evidence. Cleanup only validated owned unused build/dependency output after stopping owned preview processes; never global caches, Docker/DB, user files or old rejected cleanup targets.

Final gates: production build PASS, TypeScript PASS, changed TS/TSX ESLint PASS, diff whitespace PASS; PDF37 pages490745 bytes; route count88 verified. No production database changes.

Delivered: see RELEASE.md for exact live source/deployment and cleanup. Parent resolved the final review findings: separate can_lock grant and shared chapter25 reader handoff; published guide/PDF and authenticated Delight help/search verified. Cleanup removed1055492595 bytes with source unchanged.
