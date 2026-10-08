# R7 overtime source integration — bounded source checkpoint

Baseline:440ff43b1a72301dfbf12459d1506bdb65b728d0, codex/ux-core-payroll-workspace. Original plan7.5 requires this nonblocking source notice. New protected read migration is LOCAL ONLY, not deployed. D16/extras and owner A/B recovery choice remain separate.

## Implementation and actual journey

The payroll root streams a supplementary component after its unchanged primary/issues. No-run/cancelled/candidate periods can show the notice; locked/superseded history cannot. A confirmed nonzero source uses existing blue tokens and progressive disclosure, with direct links to existing attendance records and triple pagination. More than20 records on the same date remain accessible. Scope/context is resolved employer/period, with q/review_q retained; native employer/period selectors clear warning cursors. Source-empty is neutral and refers only to approved attendance. Denial, malformed/unavailable source and invalid/changed-code cursors never imply zero or disable payroll; generic restart preserves context. No automatic classification/recalculation or financial-write changes.

The new read intersects existing payroll_run_access with the original five attendance permissions, binds employment to employer and saved period, and reads only latest approved facts with existing currentness/eligibility/classification rules. It returns fixed minimal records, full source totals and bounded20 pages. Exact denial/scope/cursor guards remain server-authoritative. No grants to anon/service_role or source tables. The actual existing record RPC uses the same attendance read permission set, while classification writes remain independently gated. No new right to classify is implied by the link.

Privacy: employee_code now appears in internal pagination URLs and browser history, as specified by the triple source cursor. No names, reasons, location, leave payload, credentials or financial amounts are placed there. This is not a new retention policy for financial journals.

## Verification without repeated suites

- Original38 actual SQL read/security cases passed on PostgreSQL17.10 with202 domain migrations and synthetic Auth/Storage boundary. The original successful psql output was observed; sql-results.json explicitly derives from that output, not a fabricated saved raw execution log. No rerun merely to obtain a log.
- Five additional actual SQL cases passed: catalog UNIQUE(tenant_id,candidate_id),304 eligible source records/3105minutes/20-page bound, same-date continuation, exact changed-code cursor rejection and first-page recovery. First532.016ms,next519.129ms local measurements, not production capacity. These synthetic fixtures bypass domain-write triggers for insertion only and ROLLBACK; they qualify reads, not write workflows or real accounts. Docker had network none and no published ports.
- 31 actual parser/async component controlled SDK cases passed. Final compact empty delta rechecked in the same inexpensive group. One grouped production build including TypeScript exit0; scoped lint passed. Final presentation-only empty delta scoped lint/TypeScript exit0, build reused. Unaffected financial/Auth/global suites reused.
- Root change is additive Suspense/imports only; original primary, RPC calls, financial actions/journals, fields and recovery remain unchanged. Source inventory276files/345RPCsites/1172control slots/1713structural items; previous19source-reviewed statuses retained and2new pending. No semantic or execution closure promotion.

SQL fixtures must only run through run-isolated-sql.cjs against the recorded guarded synthetic container. It is stopped now, so the runner fails closed. Do not paste the fixtures into a hosted/production SQL editor or silently substitute another database. A new qualification requires a separately verified synthetic boundary. The UI fixture is a source-controlled SDK test, executable from repository root with Node24 and installed dependencies; it does not contact Supabase.

## Visual/reference scope and simplicity

Codex opened the corresponding payroll scene in the live original demo. The pinned local HTML is unchanged; normalized LF and Git blob both hash AF24015383285EAF543E9C95839F55225C2FE9817DD8B1E16D2084F857725508. Windows worktree CRLF raw bytes differ; they are not asserted to be the original byte download.

Valid frames: nonzero-390.png (expanded real component, summary44px/record action44px/scroll390), more-1366.png (initial one-item pagination presentation only, no20-item claim), final-more20-390.png (corrected20-item closed disclosure/DOM20/scroll390/summary44), final-empty-390.png (neutral empty height221.275px), reference-notice-768.png (reference blue row). Other intermediate cropped or unconfirmed-dimension screenshots remain excluded locally. These are actual component CSS/Cairo renders in a synthetic shell, not the full authorized parent.

Native Space expanded the disclosure and exposed the exact existing record link. Source inspection proves direct entry and pagination; no end-to-end task-speed or complete classification result is claimed. Codex accepts scoped token/nonblocking/progressive-disclosure direction. Official direct Claude Opus5.5 Medium independently accepted source and the scoped direction, with final empty-noise and20-item evidence concerns resolved. Both full-parent/reference verdicts remain NOT VISUALLY VERIFIED: the candidate is a separate, heavier card; the demo has a compact row inside blockers. The additional scope/currentness/pagination explanations preserve actual capabilities and truthful source boundaries, not full visual equivalence. Review JSON includes only sanitized results, not raw CLI sessions or auth.

## Remaining core gates

Full-parent streaming/native navigation, provider/session/real-role read access, source classification and return/recalculation, broader financial qualification and complete matching-state visual acceptance remain open. Stage completion/payment facts, owner A/B decision, R3/R8 and whole R0–R8 semantic/runtime coverage remain open. No full R7 or goal closure. Temporary services are retired; see cleanup.json. No main merge, PR, deployment, production migration or Actions authorized.
