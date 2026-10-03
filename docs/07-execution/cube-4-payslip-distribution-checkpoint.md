# Cube 4 payslip distribution and paper presentation

Partial local implementation, 2026-10-03. Frozen payslips and payroll sheets now report absent/unverified saved pack references and refuse distribution through the existing export path. Historical review remains available. This matches the existing statutory report boundary; it does not certify official rules from a verified-state label alone or activate any pack.

Print layout is scoped to the report route. It removes application navigation, filters, footer, repeated aggregate totals and screen chrome. Arabic header, employee detail and saved lines use A4 paper. Unqualified/direct browser printing retains review notices and guidance while hiding financial detail. Screen height/background no longer create an extra blank print page.

Evidence in the isolated run directory:

- `cube4-distribution-readiness-qualification.json`:five actual authenticated frozen sheet/payslip review/export assertions per fresh/upgrade baseline137 PASS rollback. Synthetic frozen fixture contains no legally qualified pack.
- `reviews/cube4-distribution-readiness-review.json` initial three-file PASS and `reviews/cube4-distribution-readiness-review-v2.json` final exact three-file PASS after the scoped paper-height repair. Final hashes mechanically checked.
- `cube4-distribution-readiness-local-install.json`:guarded exact migration137→138 in both dedicated QA databases, input history unchanged.
- `cube4-payslip-print-presentation-v2.json`:actual frozen payslip readable but no print/export action; direct print hides employee detail and navigation. Controlled DOM-only authorized presentation uses a visible NONLEGAL local-test watermark and never changes server admission or frozen records. Existing final history digest unchanged. Next development runtime3545 compiled and served modified CSS.
- `cube4-payslip-print-pdf-inspection-v2.json`:both PDF artifacts one A4 page, rendered with bundled PDFium and visually inspected. Initial blocked print produced a second blank page; the observed body100vh/root-background cause was repaired. FitZ was unavailable and Poppler wrappers referenced a missing path; PDFium was used without installation.

The allowed-layout PDF is a controlled visual simulation, not a successful legally qualified print authorization journey. Official financial qualification and public calculate→approve→lock→payslip/payment closure remain open. No production build/publication or real statutory pack activation. Full goal remains active and incomplete.
