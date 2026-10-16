# Release verification — Delight payroll UAT

Verified 2026-10-16 after the completed production journey.

- Published source: `5ba8397a10e38aaa2e347d48653284f0695c8dea` on `codex/operator-company-ux`, pushed to origin; no main merge.
- Vercel production deployment: `dpl_Hwk1YKoTwGqRFpGXyxXKhAzj7APq`, `business-platform-production-2cp6299rk.vercel.app`.
- Project `prj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa`, team `team_AYQTvxuQJ1EepKxDVhzjX1ew`.
- Remote optimized production build READY. Raw deployment API verified `meta.sourceCommit` exactly matches the source above. CLI promotion completed successfully, and resolving `platform.delight-world.com` through the deployment API returned this deployment.
- Live login HTTP 200. Authenticated company-manager UI displayed the new missing-name notice and exact entity link for the original Delight employer. It also reopened the completed synthetic payment page after publication and retained full-paid status.
- Local qualification build used the owned QA environment. It was not uploaded as prebuilt production output: the remote build used existing Vercel production environment settings, and `.env*`, `.git`, local `.next`, dependencies, tests and docs were excluded by the existing `.vercelignore`.
- New notice checked at phone CSS width 390 and desktop CSS width 1351 (1366 viewport with scrollbar), with no document horizontal overflow. Representative captures are `employer-guidance-phone.png` and `employer-guidance-desktop.png`. Browser zoom caused early screenshot clipping; representative captures use the actual layout dimensions. Temporary metrics overrides were cleared and the browser returned to its normal sizing.
- Final synthetic payment screenshot: `paid-production.png`. It shows recorded 311.58, remaining 0.00 and an explicit no-real-money test description. Full-page capture includes the browser's sticky navigation position; it is evidence, not a redesigned reference.
- Actual source permissions were exercised through the company-manager account. The operator's statutory configuration permission was separately enabled using the owner's explicit approval. No ordinary employee gained payroll administration.

Production migration ledger:

| Live ledger version | Name | Source file |
|---|---|---|
| 20261016123646 | employee_payroll_inclusion_20261016 | 20261016121927_employee_payroll_inclusion.sql |
| 20261016125427 | payroll_worked_day_reconciliation_20261016 | 20261016130000_payroll_worked_day_reconciliation.sql |
| 20261016125945 | payroll_draft_statutory_revision_20261016 | 20261016170000_payroll_draft_statutory_revision.sql |

QA and production function-body hashes matched:

| Function | MD5 of body |
|---|---|
| payroll.daily_source_parts | 57b8745d2820241afbd9b2885a9f2acc |
| payroll.reconcile_employee_sources | 85755e65adcc9c2192916cb13b015a2d |
| payroll.run_review_workspace | 15d52c0cede51a0e68de6da0f72876e2 |
| payroll.review_issue_list | 3108bb6e32c91e432d4fa69f06986c40 |
| public.payroll_save_input_before_recurring_debts | 5a48cabd4aa5f59afbe82311ad9b514c |

Each listed private/internal function retains `{postgres=X/postgres}` ACL. Existing public authorized entry points remain the only application write path.

No new temporary dependencies or preview servers were started by the final UI slice. A pre-existing node process was retained because ownership/use was not established as disposable. Databases, active dependencies and recovery/audit evidence remain protected. No cleanup-policy rejection was retried, and no reclaimed-byte claim is made.

Rollback boundary: the preceding app deployment is `dpl_4uhYYpRdDCifEepofwHw8LWokzZu` (source a4d1d14). A frontend rollback does not undo applied database fixes or erase the completed test ledger. Do not delete/rewrite frozen payroll or payment history to undo a test.
