# Cube 4 — Adam review fixes source checkpoint

2026-10-02. Candidate frozen for independent review in `review-worktree`, branch `codex/cube4-review-ready`, HEAD `a1709b00e0ebb8408c630b32e1ebe52f1b15b517`. No commit/push/apply/build/browser. Main/reports worktrees untouched.

## Five additive corrections

1. Calendar preview derives changed earning boundary from the cutoff of the actual latest generated period. Payment-date/month/timezone changes with unchanged cutoff keep an ordinary period. Existing sequential/future/CAS/preview-confirmation checks remain. Ordinary monthly3000 stays3000; explicit changed cutoff keeps transition per-local-month calculation.
2. New recurring saves bind immutable component interpretation (method/base/classification/behavior/proration) internally after existing validation/receipt resolution. Caller intent and validators remain unchanged. Legacy immutable assignments use the component dated at their effective start and available when saved. Calculation compares against the actual applicable dated component, without resurrecting superseded versions; changed interpretation requires an explicit renewed assignment and an Arabic owned blocker. Money is never silently converted between fixed and percentage.
3. Latest dated Tenant policy must cover all inclusive period dates. Expiry/cancellation/missing dates or a changed policy mode block the candidate; expired newer policy never revives older policy. The coverage error names the setup owner.
4. Private append consumes only the exact currently approved adjustment version evidenced by candidate Employee/Employment, line component, input_version and exact amount. Excluded/noncontributing adjustments remain approved. Existing source-lock order/current authority/receipt/atomic audit rollback are preserved.
5. Payment RPC rejects nonfinite, BC and dates outside ISO years0001–9999 before financial mutation. Existing future-date refusal remains. Valid historical civil evidence is stored unchanged, never clamped.

The migration uses asserted scoped `pg_get_functiondef` patches, preserves exact GCD/fraction rounding and existing private ACLs/grants, and adds three narrow private helpers with explicit revokes. Engine identity is coherently versioned to `cube4-review-v3-source-safe` in calculation/manifest/public calculate candidate creation; v2 candidates become stale through the existing engine_changed check.

## Authored regression evidence

`supabase/tests/cube4_payroll_review_fixes.test.sql`: 52 authored assertions, NOT executed (initial37 plus bounded cycle2 delta). Borrowed seed shapes/helpers only; no previous qualification assertions copied or repeated. New cases include actual preview/save and baseline-forced vs corrected ordinary/transition money; fixed→percentage and inverse with/without renewal and prior-period semantics; policy start/mid/end expiry/cancellation/no resurrection; actual save binding; eligible/excluded adjustment contribution, mandatory final-audit rollback, exact append replay and changed-intent refusal; public invalid-date no-effects across ledger/revision/audit/receipts and earliest valid historical evidence. Synthetic private qualification is explicitly NONLEGAL and only exercises append transaction boundaries; it does not establish a lawful net or statutory formula.

## Checks actually run

- Affected single-file ESLint (`payroll/runs/rules.ts`): PASS.
- TypeScript `tsc --noEmit`: PASS.
- No SQL compile/application/tests/build/browser/old suite reruns. No runtime PASS claim.
- Historical migrations untouched; finalization SHA `0f6c33d8b503358a6738255aba134dd4d68bdb85976a7ec44191544c743d788e`, payments SHA `ad93cee3b8e724fd446ae7b4bf0c9dcb5a7268db09ce7026ef467317ffdc4498`.

## Qualification/integration boundary

Current QA chains remain114. This reviewed additive migration would become115 after independent PASS and guarded local application; do not silently rewrite existing ledger guards. Later frozen Slice6/7 assertions/engine substitutions/source-fingerprint integration need deliberate rebasing AFTER this fix is qualified; they are unchanged here. Statutory packs/goldens/legal integration/public G6 remain unqualified. No main navigation/overview or reports edits.

Final four-file hashes are recorded outside Git at the run root: `cube4-adam-review-fixes-source-hashes.json` (migration, test, Arabic issue mapping, this checkpoint). Source edits stopped for bounded independent review.
## Bounded source review cycle2

Cycle1 source review FAIL preserved at `C:\Users\DELL\AppData\Local\ai-dev-workflow\reviews\cube4-adam-fixes-independent-review-cycle1.json`: one retained-history P1 and one incorrect blocked-gross test expectation P2. Other four fixes were coherent in that review. No runtime failure/success is implied by source review.

Private `payroll.calendar_period_semantics` now projects earning classification from actual consecutive predecessor period and scoped immutable calendar versions, validating cutoff availability, version effective dates and actual period end days. Proven same-cutoff wrong TRUE flags are normalized ONLY in an unfrozen candidate projection; stored periods are untouched. Genuine changed-cutoff periods retain transition weighting. Missing/inconsistent predecessor/calendar evidence has an owned `calendar_history_unverified` blocker and no authoritative calculated money. An existing frozen TRUE financial snapshot on proven ordinary boundaries remains immutable and yields `calendar_historical_correction_required`; this is an explicit reviewed correction handoff, not a silent financial rewrite or general correction implementation. Actual run_manifest and run-workspace displayed classification use the projection; semantic provenance participates in staleness. All existing final access authority/auditing remains unchanged.

The recurring test now asserts incomplete gross NULL/gross_complete=false and known base-only3000 for the blocked assignment, including inverse direction, rather than falsely expecting a complete gross. Narrow retained fixtures seed the original wrong persisted TRUE payment-only shape, distinguish genuine changed cutoff, refuse missing predecessor inference, and preserve a synthetic immutable old final result/period snapshot while blocking a new authoritative replacement. These privileged retained-final shapes are explicitly NONLEGAL, not a claim that current public approval accepts them.

Total52 authored assertions, NOT run. Cycle2 affected rules ESLint PASS and TypeScript noEmit PASS. No SQL compile/apply/tests/build/browser/commit or old suite rerun. Source frozen again for cycle2; no third review loop. Four-file hashes refreshed in the outside run manifest.
## Root local qualification after source review

Independent financial source cycle2 PASS; two separately reviewed fixture-only deltas corrected default-site duplication and RPC argument/state setup without changing financial production source or any of the52 assertions. Original stopped-run evidence remains outside Git; these were fixture setup failures, not assertion passes.

- Root TypeScript/affected ESLint/diff-check: exit0 on final financial source.
- Exact reviewed additive migration rollback preflight: PASS, no retained preflight mutation.
- Applied only to business_platform_cube4_upgrade_qa and business_platform_cube4_fresh_qa; both local ledgers115. Production/Cube3 database untouched.
- New focused suite:52/52 PASS on each database, rollback-only;104 assertion executions. No previous suites repeated.
- Final test SHA256:a757fba809e187e8010b8d35a7d6fea6741519bf160d23fef7b08014de1e1ae2. Financial migration SHA256:e14797b3584ea489c6d069cb6bb238b51426a5a2ca67b18034111676e514dc77.
- Runtime evidence includes retained payment-only period ordinary3000; genuine cutoff transition2364.06; unverified/frozen history blockers; both component interpretation directions; policy coverage; actual contributed/excluded adjustment append with audit rollback/replay; invalid civil payment dates with no ledger/audit/receipt effects; exact earliest historical date retained.
- No browser/fullNextbuild/CI/public legalG6/statutory qualification/commit/push/merge/deploy claim. The independently reviewed synthetic append is NONLEGAL transaction qualification. Later unapplied Slice6/7 engine anchors and QA ledger guards require deliberate integration rebasing; their existing source review is not runtime acceptance.

External evidence: cube4-adam-fixes-preflight-evidence.json, cube4-adam-fixes-apply-evidence.json, cube4-adam-fixes-tests-evidence.json; independent source review cube4-adam-fixes-independent-review-cycle2.json and fixture delta reviews.
