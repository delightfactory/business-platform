# Cube 4 opening assessed tax checkpoint

Opening YTD now preserves `tax_due` independently from `tax_withheld`. This supports the official template's distinction between prior calculated tax and withheld money. No tax formula, legal rate, annualization duration, or statutory pack was activated.

The additive validator change accepts a reviewed nonnegative amount in cents, with the existing monetary ceiling. Missing values remain absent. Blank form values are omitted in both ordinary input saves and governed correction proposals. Existing records remain unchanged; no withheld amount is copied into the new field. The employee input and correction forms use Arabic labels and explain why the two amounts can differ.

Focused qualification: 19 assertions passed on each dedicated local QA database at baseline124, inside rolled-back migration/fixture transactions. The tests cover legacy absence, explicit zero, independent amounts, invalid values, privacy, actual authenticated save/replay, and the exact input version and both amounts in the run source manifest. They do not prove a final locked statutory calculation or a complete correction application.

Evidence in the isolated run directory: `cube4-opening-tax-due-qualification.json` and per-database logs. Qualified exact migration SHA256 `30cea62e0e653651eb57f085b5130779feb5f84d4539bf24428c6cee324c2dd4` was installed locally on both dedicated QA databases, advancing124→125 and preserving the full input-history digest (`cube4-opening-tax-due-local-install.json`).

Affected-file ESLint passed. Incremental TypeScript passed after adding the explicit string-map type to the form payload. A new separate runtime was built successfully using the exact affected source files: build `5j3IYzdE13Af-oSuag7rg`, loopback port3539. Earlier runtime3535 remains preserved.

Actual authenticated browser evidence: `cube4-opening-tax-actual-ui-continuation.json`. The first save left `tax_due` absent while retaining withheld100. A later prospective version persisted assessed125.50 separately from withheld100; reload displayed both. Version1 remained unchanged. Arabic RTL at390/820/1280 had no page overflow; payment/final counts remained unchanged. The820 screenshot was visually inspected.

The first harness tried editing with the same effective date and was correctly rejected by the existing dated-version guard. Its evidence is retained in `cube4-opening-tax-actual-ui.json`. Continuation used a later effective date and did not repeat the first mutation. This proves prospective input versioning, not retroactive governed correction. The generic effective-date conflict message is a remaining UX improvement; it currently resembles a concurrency conflict. The correction form field was built but its complete browser proposal/application journey remains unverified.

Next: effective employee tax/insurance context and cumulative duration/coverage, dated legal adapter qualification, then finalization and the remaining financial journeys. Existing qualifying evidence remains reusable; no commit, push, merge, deployment, production change, or full old suite rerun occurred.
