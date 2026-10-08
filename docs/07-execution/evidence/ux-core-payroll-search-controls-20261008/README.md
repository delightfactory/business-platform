# R7 native payroll search controls

Baseline: d50576c3cb0c9e819346067bf4a23e241b68f47f. Approved core accessibility scope; no new functionality. Eight existing native GET search buttons across advances, runs and inputs receive the existing secondary-button class. The missing-employee recovery form also receives its existing filters class, completing input accessibility in that same journey. The reports chooser already has the existing 40/44px contract and is unchanged. Recovery precedence A/B remains an owner decision; no option was implemented implicitly.

## Evidence and economy

- source-results.json: eight controlled actual-page branches, exact whole-source equivalence excluding the eight button classes and one specific form class, with original fields, methods, destinations, RPC calls and financial child contracts retained. After the final form-class delta only the affected fallback case was rerun. An external normalizer assertion was repaired to accept the original method=get form; no production behavior was changed to satisfy the harness.
- screen-metrics.json and metric-validation.json: 24 before/after pairs at 390, 768 and 1366px; search buttons increase from about 21px to 44px on mobile and 40px on desktop, Cairo loaded and no overflow. The explicit viewportWidth records the original pageWidth; buttonWidth records the target width.
- final-fallback-metrics.json: the final fallback field is about 52px tall at all three widths, with the same GET fields/method and no overflow. Unprefixed inputMissing images are final; initial-prefixed images preserve the intermediate button-only checkpoint.
- final-focus.json and focus-inputMissing-390.png: native Tab reaches the fallback input then button, a 2px focus-visible ring appears and TEST is retained. No financial or GET submission was performed. This is not a claim of keyboard testing all eight forms.
- validation.json: scoped lint passes. Grouped build and TypeScript evidence from 2411d45 is reused because only literal class attributes changed; unchanged SQL, Auth and financial evidence is reused. No repeated heavy suites.
- Three independent official Claude Opus 5.5 Medium read-only reviews cover co-design, candidate and final fallback. The final review reports no must-fix. Full Concept C matching remains NOT VISUALLY VERIFIED; the reference has no corresponding complete chooser/search screen.

Mocked SDK, financial widgets and shell delimit the rendered evidence. Real Next hydration, roles/providers, finance, full parent journeys, stage facts/owner routes and full R7/R0–R8 acceptance remain open. No semantic registry acceptance was promoted: 273 source files, 1171 controls, 344 RPC sites, 1711 structural items and the prior 19 source-reviewed states are retained. Structural inventory is not a semantic completion denominator.

Owned GET-only loopback preview on port 3604 and the two temporary browser tabs were retired, and the viewport override reset. No raw authentication/session files, secrets, employee data or private database dumps are included.
