# Cube4 Reports — current local qualification

Reviewed source migration20261002074500 SHA31983daa08564f3583af1d2f71d2a3a6d834b8098e261b5c344c406eab672f48 remains unchanged from actual independent cycle2 PASS. All15 report files were checked against that review.

First actual ordered SQL qualification: payslip17 + reports24 PASS on both dedicated QA databases, with reportDDL/fixtures rolled back and source6/7+namespace fix baseline118 preserved. `cube4-reports-ordered-rollback-qualification-v2.json`. First harness guard rejected leading comments before running a suite; it was corrected to allow comments while requiring BEGIN/ROLLBACK. No successful suite was repeated.

Exact qualified migration then installed locally only, both ledgers118→119: `cube4-reports-qualified-local-install.json`. No production, commit, push, merge or deploy.

Actual authenticated browser: all seven report kinds loaded with existing synthetic saved outputs or advance ledger. One advance CSV request returned200/attachment UTF8 bytes329 and was retained; it was not re-exported. Payslip/statutory/variance blockers hide export and keep print authorization false. Payment report390/820/1280 has no horizontal page overflow. `cube4-reports-actual-ui-read-continuation.json`, buildUT1GBR238M-wR24QN57Za. Exact copied report source hashes match independent review.

Retained harness failures: first export URL was relative to an API context without base URL, before any export request. Absolute URL corrected it. Whole-document alert assertion then included an unrelated global alert; verification was scoped to the actual report region and continued read-only, reusing the successful CSV result.

Open: actual qualified payslip print/export authorization races, large paging/filter browser journeys, legal statutory pack reconciliation and complete payroll acceptance. Synthetic NONLEGAL outputs and blocker-safe renderings do not prove lawful salary/net calculations or public finalization readiness.
