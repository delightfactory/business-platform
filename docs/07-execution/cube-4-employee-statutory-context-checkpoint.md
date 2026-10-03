# Cube 4 employee statutory context checkpoint

## Implemented facts and workflow

`statutory_context` is an employee/employer-scoped reviewed input with immutable dated versions, provenance reference and reason. It records the source tax-treatment code, explicitly reviewed insured/non-insured status, and, for insured employees, the source category, insured wage and insurance commencement/termination dates. No value is inferred from operational gross, employment pay basis, or a missing attendance record.

This records employee facts under `payroll.prepare`; it does not authorize employees or tenant payroll staff to configure legal rates, exemptions or statutory packs. Tax-treatment identifiers retain their source string identity. A syntactically valid identifier or category is not a qualified supported legal category. The future dated adapter must verify applicability before calculating net or allowing lock.

The existing command preserves authority checks, employment/employer scope, lock order, CAS, exact-intent receipts and audit. One context head is permitted per employment/employer; prospective versions require increasing effective dates, including resumption after a validity gap. Ordinary changes overlapping a frozen payroll period are rejected. Governed input revision uses the shared validator and immutable source-change compiler. Insurance dates are separate from effective dates and employment dates.

The existing source manifest captures complete context versions. The composed stale chain reports `statutory_context_changed`, so a previous review cannot silently remain current after context changes. Employee monetary/statutory calculation is still unqualified; this does not activate a legal pack or produce a legal net.

## Focused evidence

`cube4-employee-statutory-context-qualification.json` in the isolated run directory records33 assertions on each dedicated QA database at baseline125, rolled back. Coverage includes required insured data, explicit non-insured facts without a fictitious wage, invalid amounts/dates/source data, private helper ACL, authenticated save/replay, single head, dated versioning, reader denial, source/stale capture, immutable history, private correction compilation, synthetic frozen-period rejection and future updates/resumption after expiry. Synthetic freeze/compiler checks do not prove full finalization or correction application.

Migration SHA256: `535d686253b27f4ad838bd907e73deef757defde0bea1a31d69b87d307ef6599`.
Test SHA256: `e75c244354164694935b61d28ac6c487f4abddc46d4381896955484f9147712c`.

Incremental TypeScript passed. ESLint passed on six changed TS files; the final two corrected files passed again after review fixes. The independent read-only Codex review found and prompted correction of retained insurance data during insured→non-insured correction proposals, and the inability to resume an expired context head. Final review verdict PASS with exact hashes for8 scoped files is kept in `reviews/cube4-employee-statutory-context-review.json` outside the worktree. Separation is a fresh reviewer on the same provider.

Exact reviewed/tested migration was installed atomically on each dedicated local QA database,125→126, with unchanged full input-history digests. Evidence: `cube4-employee-statutory-context-local-install.json`. This is local input support only; no statutory pack or public final approval was activated.

## Remaining qualification

The new UI includes a distinct Arabic section and conditional insurance fields, plus a clear effective-date conflict message. A separate runtime3541 was built successfully with exact reviewed source hashes: build `qFpJmPbbrRe7Una5FpU6y` (`cube4-employee-statutory-actual-ui.json`). Earlier runtimes remain preserved.

Actual authenticated browser journey saved insured facts with explicit wage/category/dates/reference, reloaded them, then saved a prospective non-insured version that omitted all four contradictory insurance details. The first immutable insured version stayed unchanged. Reload preserved non-insured status; returning the form to insured required fresh facts and did not save another version. Arabic RTL390/820/1280 had no page overflow. The390 screenshot was visually inspected. Final/payment counts did not change.

One rejected same-date save verified the new Arabic effective-date message without changing head revision, input versions, receipts, payments or finals (`cube4-employee-statutory-date-conflict-ui.json`). Ordinary field lifecycle is verified; the full governed correction browser/application journey remains open. These ordinary form checks do not prove legal insurance applicability or tax calculation.

Complete cumulative YTD duration/coverage, dated supported category mapping, statutory adapters and representative current official comparisons. Then qualify full governed correction/application and finalization/source consumption/authority before exposing approval. No production change, publication, commit/push/merge or unchanged old suite rerun occurred.
