# R6-CORE-OVERVIEW-01 — employee leave overview

Status: implemented presentation slice; scoped content visual acceptance with preserved source contracts. NOT a Frozen full R6a specification or end-to-end/provider qualification. Baseline `97ed87a899362a123f3c04f197918d634dcbd92c`. Branch `codex/ux-core-leave-overview`.

## Core plan boundary and journey

The approved R0–R8 redesign remains the objective. Per owner's course correction, additional improvements follow the core plan. D16 server recovery implementation/integration is deferred and preserved; no backend work in this batch. D2/D3 navigation and D8 session-return proposals remain pending and unapplied.

Employee enters existing own leave page to read recorded balances, check current requests, open a request, or begin an authorized new request. Existing detail/create forms remain the endpoints, with unchanged inputs and action safeguards. The overview is now two equal panels on desktop, stacked at 1100px and below to retain readable content in the existing rail layout. Balances precede request history in DOM and appear on the RTL start side on desktop. Flat rows avoid nested card borders. Balances use neutral numeric emphasis, including negative balances; no suggestion that all balances are positive/available.

One create action remains in the page heading. Empty-state copy points to it without duplicating it. Each independently paged collection keeps its controls; next-page links are secondary, preserving URLs and the other collection's page. Partial failures retain the readable collection and its existing retry path. Read-only access exposes no create action and retains the explanation. No permission, data parser, RPC, parameter, action, mutation identity, storage, SQL or business rule changed.

## Reference and deliberate differences

Pinned Concept C HTML normalized SHA256 `AF24015383285EAF543E9C95839F55225C2FE9817DD8B1E16D2084F857725508`, Git blob `821a60c5c7e6cfbf8cd8f8da7a3509490fe11879`. Original files unchanged. [Acceptance contract](design-reference-acceptance.md) and compatibility review apply.

Real balances are per type and period; requests include the actual entire paged history. Simulated annual allowance/used amount/progress and current-year filtering are omitted because RPC data does not supply those semantics. Existing Cairo, radius8, 40px desktop/44px mobile controls and authorized navigation remain controlling contracts. No new reference routes, topbar, role switcher or delegated authority added. These are preserved-contract deviations, not approval of pending amendments. Content presentation accepted; production parent shell/navigation and dark mode remain separate open gates.

## Evidence and separate acceptance gates

[Evidence](../../07-execution/evidence/ux-core-leave-overview-20261008/README.md) binds normalized candidate hashes, rendered images and reviewer findings. Actual async page rendered with controlled read-only SDK responses and link/PageFrame adapters; synthetic rail represents current layout space, not production navigation qualification.

- Focused source/fixture checks: 15 cases pass, including all seven request states, finite negative balance, empty/read-only, each partial read failure and independent paging. Same ordered RPC calls/parameters and unique link destinations before/after; no mutation executed.
- Browser DOM measurements at 1366/768/390: no horizontal overflow in sampled states. Mobile controls measured44px, loaded Cairo, keyboard create focus2px. Browser version unavailable; do not infer it from product naming.
- Simplicity: competing primary actions P changes from2 to1 in empty state and3 to1 with both pagers; normal1 and read-only0 remain. These are measured rendered DOM counts, not a user study. N/C/I/B, task completion and backtracking across hydrated detail/form/actions were not measured and are not claimed improved.
- Codex and official Claude Opus5.5 Medium: **MATCH WITH ACCEPTED DEVIATIONS**, scoped to content rendering. Claude first identified narrow full-page capture clipping; those narrow files were rejected as visual evidence. Corrected viewport images were independently inspected, then reviewed in the same session. No code rework or repeated build needed for capture correction. Only visible viewport content was visually reviewed.
- Build, TypeScript and changed page ESLint pass. Whole-repo lint fails on pre-existing CommonJS evidence scripts (30 errors, one warning); this slice does not change/ignore those rules or report lint as globally passed.

Full authorization/provider/SSR hydration/action completion, production shell, dark mode, whole-page narrow content below viewport and full R6a/R6b qualification remain open. Existing unknown-result/session limitations are retained honestly. Inventory/review denominator remains1523, preserving manual statuses without promoting semantic/runtime coverage from these checks. Next core batch: coherent detail/new-request presentation and measured authorized journey; then continue the remaining approved phases. No additional recovery backend scope before core completion.
