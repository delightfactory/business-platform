# Cube 4 Slice 3 — focused local qualification

Status: **Calculate/review/cancel focused qualification passed. Full Cube 4 and financial/statutory qualification remain incomplete.** Evidence recorded 2026-10-02 on isolated branch `codex/cube4-payroll-core`, base `555c34a568f44eb4b99d99712a699094488f3026`. No commit, remote migration or publication.

## Exact candidate and independent gates

- Migration `20261002010419_cube4_payroll_candidates.sql`: SHA256 `349b137134123ab8dff204fe2d42994491f458e735e614a7100bba27c039c357`.
- Rollback suite `cube4_payroll_candidates.test.sql`: SHA256 `932db4a2970d2f6b53b74844da863a74b60bb0882dc95d89a42dcd4a5655d8d2`.
- Independent read-only review: initial FAIL with three concrete findings, bounded correction PASS. External provider was unavailable earlier; separate built-in reviewer provides weaker provider separation. Daily input selection now resolves current revisions per head rather than comparing unrelated head revisions; cancelled inputs cannot override approved replacements. Regression coverage includes replacement, non-resurrection and ambiguity. Calendar return preserves Employer/period/Employee search through separate `review_q`; availability copy matches the implemented boundary.
- Guarded atomic migration application to **`business_platform_cube4_upgrade_qa` only**, ledger 111 → 112. Existing source/shared databases retained.
- Root independently executed the new rollback suite: **57 assertions PASS**, exit 0. Previous passing suites were not repeated. Scope includes accepted arithmetic, current authority/replay, CAS, immutable candidate/audit rollback, cancellation/new run identity and explicit incomplete-source/legal blockers. This is not live-session final-consumption concurrency evidence.
- Root final webpack build after review PASS: exit 0, Build ID **`c-J-HqM8-IlUYknssi14K`**. Writer changed-code lint/typecheck and four money formatter assertions passed; root build independently ran TypeScript. Root `git diff --check` passed. No build was repeated after this candidate.

## Authenticated runtime journey

Loopback app `127.0.0.1:3335`, dedicated QA REST/Auth behind `127.0.0.1:3333`, separate synthetic Tenant/Employer with two Employees and complete work/compensation context. No production or customer records used.

1. Actual login → main Payroll navigation → calculate: full monthly cycle 25 January–24 February 2026, monthly base 9,000, fixed recurring allowance 200 and approved daily units 20.5 × 300. **Known operational gross 15,350.00; authoritative net null**, visible unqualified statutory blocker. Exactly one run/candidate/calculation audit; no consumed inputs or frozen People context.
2. Review → calendar → return preserves Employer, selected period and Employee search. Employee detail opens and returns through the actual interface.
3. One explicitly synthetic QA source edit creates a salary change to 11,000 effective 10 February. Reload identifies the specific compensation stale reason; the original candidate remains 15,350.00. Actual UI recalculation creates a second immutable candidate: monthly base `(9000 × 16 + 11000 × 15) / 31`, rounded once to **9,967.74**, total **16,317.74**. This source edit was QA SQL, not a People UI qualification.
4. Actual cancel with reason → reload preserves cancellation and history without consumption. Explicit calculation then creates a distinct run: two runs, one cancelled, one active, three immutable candidates, four run audits, zero consumed input versions and zero frozen People contexts.
5. Widths **390/820/1280** had no horizontal overflow. Root inspected actual phone and desktop review captures and desktop Employee detail. Review totals/blockers precede optional repetitive actions; exact raw decimal manifests remain private. Dated component explanations are disclosed on demand. Final polish and whole-module UX acceptance remain later gates.

The browser harness paused twice for observed interaction mismatches: the corrected return-link name and cancellation nested inside optional actions after refresh. It resumed from asserted durable states, retaining previous evidence; initial calculation, source edit and recalculation were not repeated. These were harness corrections, with no app rebuild or source mutation.

## Evidence and limitations

Outside-Git run directory `C:\Users\DELL\AppData\Local\ai-dev-workflow\runs\20261002-cube4-payroll` contains review-cycle JSON, migration apply evidence, focused SQL logs, build evidence, authenticated browser evidence and actual review/detail screenshots. Private fixture credentials remain outside Git and are not included in this document.

This qualifies only the observed calculation/review/cancellation boundary. G3 final People/source consumption and insertion races, G4 enabled Time/Leave adapters and reconciliation, statutory pack/engine/official golden models, exact-candidate fresh-chain parity, financial approval/lock, protected final outputs, payments/corrections/employee-finance and the full acceptance matrix remain open. Enabled unintegrated Time/Leave explicitly block rather than silently disappear. Aggregate daily units with changed dated rates remain a visible allocation blocker. No final payable or legal/net result is claimed.

Next ordered work: compatible source/People guard closure and private approval/finalization/output foundations. Irreversible public lock stays gated until statutory/source qualification and payment/correction closure.


## Later focused rounding evidence — 2026-10-02

The original 57 assertions and observed UI journeys remain actual passing evidence. A later independent root rollback probe of 12 exact half-cent percentage cases found five failures caused by division truncation before component summation; a separate partial base/fixed-component tie also failed. Therefore those original observations do not establish general accepted half-away rounding. Slice4 adds an exact rational arithmetic correction under a new engine identity and invalidates earlier candidates. Delta SQL qualification remains pending; historical evidence is preserved.
