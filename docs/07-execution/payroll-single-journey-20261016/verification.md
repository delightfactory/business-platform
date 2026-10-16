# Payroll single-task journey — qualification

Base: b1cab57, branch codex/operator-company-ux, external worktree. Owner requested one understandable completion path rather than a decorative step diagram. Official Claude Opus 5.5 Medium supplied a separate bounded source opinion; payroll_journey_audit implemented and payroll_journey_review independently reviewed.

## Executed checks

- Local UI, ordinary synthetic company-admin: opened payroll entry, previewed and created December 2026 period `52268fde-5356-42fc-bf14-63e15dd5516f`, followed the actual returned period to its run, calculated and observed one included employee (two excluded employees remained excluded).
- Opened policy repair from the run, saved the synthetic company policy, returned to exactly the same employer and period, observed stale source state, recalculated. Actual issues dropped from 10 to 7; remaining financial setup and future coverage were not fabricated away.
- Missing financial context is grouped with related opening issues into one task; original issue details/count remain available. Future coverage explicitly explains why future attendance cannot yet be approved.
- Independent source review initially found partial-page record selection, missing focused kinds, dropped payment period, legal-name return, split-role guidance and duplicate navigation defects. Fixed in one bounded review delta. Final source and rendered verdict PASS for this slice.
- Responsive rendered checks at 390, 768, 1366 requested widths: document/viewport widths 390/390, 753/753, 1351/1351. No horizontal document overflow; the direct next task remained visible. Full-page captures have sticky-navigation capture artifacts; final delivery uses a viewport capture.
- Full public financial regression in isolated rollback-only QA: 68/68 assertions passed. No SQL or financial authority changed in this release; original journal, idempotency and reconciliation logic retained.
- Independent final production build including TypeScript PASS; scoped ESLint PASS; whitespace check PASS.
- Arabic source guide, HTML and PDF updated together. PDF 38 pages; updated payroll page 26 rendered and visually inspected.

## Boundaries

This slice does not transfer money, auto-approve/finalize, invent company legal names, reset opening balances, or treat unknown attendance as absence. Calendar creation follows the existing connected cycle rather than accepting unsupported arbitrary dates. Attendance repair opens the correct day review queue; filtering that queue to just the employee remains a future improvement.

Current UI finalization/payment were not repeated in the local fixture; existing authoritative financial lifecycle passed the 68 regression checks and the previously completed production synthetic payment remains the live terminal-state example. Unknown-result journal and split-role behavior were reviewed in source rather than claiming a new exhaustive runtime execution.

Storage: existing shared dependencies and essential prior evidence retained outside OneDrive. Temporary local dev server stopped after verification. No blanket cache, Docker or database cleanup.
