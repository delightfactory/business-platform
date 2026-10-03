# Cube 4 governed current earning attribution

Partial local implementation, 2026-10-03. The private composed worker now derives its taxable earning amount from actual earning lines and an explicitly versioned pack treatment. Callers cannot supply or override `current_taxable_earnings` on this path. Other tax-duration, prior and insurance facts still require source integration; the public review pipeline is not financially qualified.

Statutory packs gain `earning_rules`, initially an empty object. No taxability or rounding rule is inferred for existing packs. The supported schema records explicit base taxability, use of reviewed dated component declarations, and taxable-share half-up cent rounding with the complementary amount retained as nontaxable. Admission requires the existing verified-pack adapter/evidence boundary and coverage of the earning interval. A verified-state label alone is not official legal proof.

Uniform source declarations preserve the whole already-rounded line. For mixed declarations, exact rational parts must reconcile with the saved amount. The taxable parts are added exactly and rounded once under the explicit pack rule; the other share is the original total minus that result. Missing declarations/unknown exact allocation refuse calculation. Source versions and dated parts are preserved in the composed explanation. Total taxable+nontaxable equals operational gross. No history is rewritten or new candidate emitted by these private functions.

Evidence in the isolated run directory:

- `cube4-governed-earning-attribution-qualification.json`:19 assertions each baseline138 fresh/upgrade PASS rollback, first run. Actual authenticated component save and public recalculation feed uniform and changed-inside-period sources into private composed arithmetic. NONLEGAL fixture base500, bonus40, recurring300 with24/31 taxable parts yields taxable772.26+nontaxable67.74=gross840 and composed NONLEGAL net609. Exact half-cent tie, integer zero padding, complementary-cent conservation, source mismatch, missing rules/unqualified pack, caller override and private access covered.
- `reviews/cube4-governed-earning-attribution-review.json`:independent exact two-file PASS, no material findings; installer mechanically verified hashes.
- `cube4-governed-earning-attribution-local-install.json`:guarded exact migration138→139 both dedicated local QA databases, input history unchanged. No pack activated.

No unchanged prior suites rerun. Cross-year earning assignment, daily actual legal duration, full-period component transition exceptions and insurance month ownership are not fully qualified here. No UI change, public net activation, legal pack issuance, current official numeric comparison or full financial journey is claimed. Full goal remains active and incomplete.
