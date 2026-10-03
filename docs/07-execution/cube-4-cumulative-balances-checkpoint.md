# Cube 4 cumulative balance composition

Partial local implementation, 2026-10-02. Actual candidate source context now contains year-specific prior net income, assessed tax due and tax duration. This is source/arithmetic composition, not legal net qualification or complete Payroll Core.

Opening YTD optionally records reviewed `tax_net_income`, after deductible legal amounts and before the annual personal exemption. Missing remains unknown; historical taxable earnings minus all employee social contributions is never guessed. Existing versions are not backfilled. Both ordinary input and governed correction forms keep this field optional and omit a blank value. Ordinary entry places it inside expandable prior-calculation details.

For prior locked calculations, the balance uses the final cumulative state once: prior net plus that calculation's current taxable earnings minus its deductible current insurance; final cumulative assessed tax; final cumulative duration. Consecutive outputs must agree on carried net/due, advance duration, cover consecutive earning intervals and finish through the day before the current earning anchor. Gaps remain unknown. No absence or wage deduction is inferred from a gap. Opening coverage cannot overlap the frozen earning intervals or conflict with the carried baseline. Unresolved opening ambiguity remains blocking. At January1, the current taxyear has no preceding earning days, so its prior counters reset; current earning attribution remains a separate requirement.

Known cumulative context removes obsolete missing-opening blockers only when every affected year is known. Salary/input/source/legal blockers remain. Candidate engine version changes invalidate earlier reviewed candidates. Actual candidate net remains unavailable and financially_qualified remains false.

Evidence in the isolated run directory:

- `cube4-cumulative-balances-qualification-v3.json`: 29 focused assertions each dedicated fresh/upgrade baseline133 PASS, rolled back; actual authenticated current candidates plus private NONLEGAL historical outputs. Cases include incomplete prior coverage, explicit opening net, cumulative values used once, broken/gapped lineage, ambiguous and overlapping openings, year boundary and immutable snapshot retention.
- `reviews/cube4-cumulative-balances-review.json`: independent read-only PASS against nine exact file hashes, with three review findings and their resolutions retained. Correction form label/optionality/blank normalization were included after the shared field list exposed that dependency.
- `cube4-cumulative-balances-local-install.json`: exact migration installation133→134 in both local QA databases, input history unchanged and no pack activation.
- TypeScript/five-file focused ESLint exited0 in session96404; final TypeScript plus correction-pair ESLint exited0 in session80291. `git diff --check` exited0.
- `cube4-opening-net-actual-ui.json`: one authenticated prospective save of net9950 with taxable earnings10000 and employee social100, reload, optional unknown legacy value, old versions preserved, no candidate/payment/final mutation, no horizontal overflow at390/820/1280. Screenshots retained.

The initial SQL attempt stopped before assertions because a PL/pgSQL loop variable conflicted with a query alias. That error was corrected and its artifact retained; v2 passed27 assertions, then v3 added two concrete review regressions. Earlier unchanged suites were not rerun. No complete governed correction browser journey for the new field, production build of this delta, or full statutory numeric qualification is claimed.

Remaining: current earning/tax-duration attribution, insurance obligation ownership, composed statutory candidate computation with a governed verified applicable pack, official numeric comparison, complete approval/lock/output/payment/correction journeys and final full-scope qualification. No publication or production mutation occurred.
