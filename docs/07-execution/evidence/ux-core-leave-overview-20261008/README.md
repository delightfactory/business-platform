# Core employee leave overview evidence

Baseline: `97ed87a899362a123f3c04f197918d634dcbd92c`. Candidate page/CSS hashes and archived file hashes: `manifest.json`. Corresponding commit contains that source; identity is independent of CRLF checkout conversion.

Use `reference-1366.jpg`, `before-normal-1366.jpg`, `after-normal-1366.jpg` for desktop, and `viewport-reference-*` / `viewport-normal-*` for390/768. Other `viewport-*` images cover mobile empty/paging/partial/negative/read-only/focus. Narrow `fullPage:true` captures produced RTL clipping and were rejected; only corrected viewport images qualify the narrow visual review. Screenshots do not qualify content beyond their viewport.

`focused-results.json`:15 actual async-page checks with controlled read-only SDK/React static render. `browser-measures.json`: sampled DOM geometry/counts/focus/fonts, browser version unavailable. `fixture-source.txt` and `runtime-source.txt` preserve the external fixture code for inspection; paths refer to the local writer and external before/candidate snapshots, not a portable project test command. Baseline page is available from the named Git commit; dependencies use the actual source contracts. No fixture/runtime scripts are added to application execution.

`claude-initial.txt` records the independent capture finding, `claude-final.txt` records the corrected responsive visual verdict. Briefs retained; raw Claude events/profile/account metadata remain local. Official CLI2.1.292, `claude-opus-5-5`, Medium, read-only violationfalse in both completed reviews. Touched-file lists were pre-existing writer changes, not reviewer edits; source candidate unchanged during review. Codex independently inspected corrected images and diff; content verdict MATCH WITH ACCEPTED DEVIATIONS.

Build/typecheck/scoped ESLint passed once for the batch. Global lint failed on unchanged historical evidence CommonJS scripts; no weakening of the linter. No backend/provider/action/production/dark qualification claimed. No project or employee data served: loopback127.0.0.1:3577, synthetic GET-only fixture. Both owned fixture processes terminated; listener absence checked. No shared task/service stopped.

See [slice specification](../../../04-product-specs/ux-redesign/employee-leave-overview-slice.md). Full redesign goal remains active, D16 integration deferred, no merge/deployment/PR/Actions.
