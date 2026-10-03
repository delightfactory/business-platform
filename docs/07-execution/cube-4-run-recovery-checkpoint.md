# Cube 4 run response-loss recovery

Partial local implementation, 2026-10-03. Calculate/cancel request identity is saved in browser storage before transport, scoped to authenticated actor, tenant, employer and period. While unresolved, new run requests are blocked. Reload preserves the original request and revision. Recovery returns its existing receipt or durably closes an absent receipt under the same writer scope lock; it never calculates. The original late writer checks the immutable closure before any new run/candidate mutation.

Cross-tab requests and recovery hold one Web Lock for the full asynchronous operation. Cleanup verifies the stored attempt identity. Browsers without the required lock/storage fail before dispatch with an actionable message. Pending recovery remains available when new actions are disabled by service/final state, subject to current access. Restored older receipts do not imply a new calculation or overwrite current review.

Evidence in the isolated run directory:

- `cube4-run-recovery-qualification.json`:15 assertions each baseline136 fresh/upgrade PASS rollback, actual authenticated public candidate receipt, exact intent, durable absence fence, idempotent closure, late original writer rejection, foreign period/access/private-table and immutable-history checks.
- `reviews/cube4-run-recovery-review.json`:initial FAIL RR01 cross-tab overwrite/cleanup race. `reviews/cube4-run-recovery-review-v2.json`:independent six-file PASS with exact hashes after Web Lock and identity-checked cleanup. Initial report retained.
- `cube4-run-recovery-local-install.json`:exact guarded installation136→137 both dedicated local QA databases; input history unchanged.
- TypeScript/focused four-file ESLint final session31293 exit0. Earlier session84028 also passed before concurrency repair; first session86248 had an overly broad page replacement that added actor to ApprovalActions, corrected before qualification.
- `cube4-run-recovery-ui.json`:actual committed calculate response deliberately discarded, reload retains original identity, second tab cannot overwrite/dispatch or recover during the held request, original receipt recovery yields no additional candidate. One new candidate only; original output digests and input/payment/final counts preserved. Before-transport interruption simulated with a fresh identity and actual current run revision closes through authenticated recovery without calculation. Responsive390/820/1280, final phone and desktop screenshots inspected.

Cancel-specific response loss, permission revocation races and disabled/final-state browser recovery are not dynamically qualified in this delta. Generic backend/client paths were reviewed; no broader qualification is claimed. No production build/publication or legal pack activation. Full payroll approval/net/payslip completion remains open.


## Cancellation response loss qualification

2026-10-03 additive local evidence on QA ledger139. One real authenticated cancellation was committed in the synthetic upgrade-QA browser fixture; its server response was held and then deliberately aborted. Reload retained the exact original operation, reason, run revision and attempt. Recovery fetched the original cancellation receipt, cleared the pending request and offered preparation of a new run without calculating one. The cancelled fixture is intentionally retained; no replacement was emitted.

`cube4-run-cancel-recovery-ui.json` records PASS. Candidate output and source-manifest digests, input-version digests, payment records and final contexts were unchanged. Cancellation audit increased exactly once and run revision increased exactly once; neither receipt recovery nor a later reload repeated cancellation. Visible feedback and no horizontal overflow were checked at390/820/1280; phone and desktop screenshots were inspected.

Six Arabic recovery messages now refer to the original request rather than only calculation, and remove the internal identity-closure explanation. Changed-file ESLint passed. No action, storage, authorization or database behavior changed. This closes the previously untested cancel-specific response-loss journey; permission revocation and disabled/final-state browser journeys remain untested. The original calculation response-loss evidence remains separate and was not rerun. No statutory qualification, full-cube closure, new migration, commit, publication or production mutation.

Independent read-only review `reviews/cube4-run-cancel-recovery-review.json`:PASS, no material findings. Root mechanically verified all three reviewed hashes against final source, browser evidence and harness. Separation was a Codex reviewer rather than a different provider.
