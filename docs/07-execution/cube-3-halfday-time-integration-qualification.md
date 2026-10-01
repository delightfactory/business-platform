# Half-day Leave and remaining worked Attendance qualification

An approved mapped half-day previously blocked worked Attendance for the whole WorkInstance. A2.1 permits a fact only when a current interpretation proves that the observed work satisfies the remaining half. It preserves the existing independent Attendance exceptions and leaves already-approved facts immutable.

## Qualified behavior

The interpretation records the exact approved request, approved preview and frozen mapping. The shared input fingerprint includes that approved context. Fixed schedules use the mapped excused clock interval and actual break overlap; flexible schedules require the rounded-up half of configured required minutes and the explicit half-day break. The qualified fixed example observes 270 gross minutes, 60 break minutes and 210 net minutes. A 481-minute flexible requirement needs 241 net minutes; 240 remains review-required.

Duplicate punches, invalid attribution windows and other independent Time diagnostics retain their recovery owner. Full coverage, incompatible mapping and insufficient remaining work cannot become a worked fact through manual, automatic or bulk approval. Complementary fixed halves require the same frozen policy and disjoint excused intervals; same-part and incompatible overlap stay blocked. Linked Leave replacement follows the same rule.

Manual approval retains the existing dedicated current-Leave conflict (`23514`, `leave_conflict_review_required`) before checking stale interpretation evidence. When cancellation removes the last approved source, the shared fingerprint gate returns `PT409`, `attendance_interpretation_stale`. Bulk approval retains the dedicated Leave-conflict reason and catches a stale item as `not_clean_or_stale` without aborting the batch. Source replacement patches assert exactly one expected anchor and retain existing signatures and execution grants.

New facts carry exact approved Leave provenance and gross/net/break metrics. Cancellation after fact approval preserves the complete fact JSON and reports reconciliation required. This slice provides neither silent reinterpretation nor an automatic fact rewrite.

## Local execution evidence

The migration was applied through the normal CLI chain to isolated fresh and source-clone upgrade databases, with all 105 migrations. Fresh application schemas were rebuilt and replayed; the final upgrade target was copied from the untouched local source database and replayed normally. No ad hoc function repair was used. Exact function definitions and ACLs match across both targets. The source clone's original 5 Employees, 4 Employments and 2 User links match the untouched source.

The focused integration file has 208 assertions, including enabled automatic-approval negative coverage, an actual outside-window punch correction, a genuinely ready interpretation made stale by cancellation, and the bulk stale catch. The retained baseline fact-guard file adds 18 assertions. The complete 38-file Cube 3, Attendance and People group passed all 1,734 assertions on each final database, with zero failing files. Gate transcripts are `slice21-business_platform_cube3_fresh_qa-gate.log` and `slice21-business_platform_cube3_a2_upgrade_qa-gate.log`.

Four controlled concurrent RPC cases passed on the final normal-chain upgrade target. Each observed the exact PostgreSQL blocking edge before releasing the first transaction:

| First transaction | Competitor and final result |
|---|---|
| Half-day Leave approval | An actual OUT punch refreshes the interpretation; compatible worked fact succeeds |
| OUT punch and worked fact approval | Leave approval returns `23514`, `leave_attendance_fact_conflict`; no consumption is appended |
| Half-day cancellation | Worked fact returns `PT409`, `attendance_interpretation_stale`; no fact is appended |
| Compatible worked fact approval | Cancellation succeeds; full immutable fact snapshot is unchanged and reconciliation is required |

The race helper asserts exact ledger amounts, request/event/consumption/reversal counts, fact metrics, approved-preview provenance and unchanged live RPC definition fingerprints. Evidence is retained outside the repository under the isolated run directory: `runroot/a2-controlled-races/result-9ba7fb86-ca2d-4c87-be01-801610b9fdfb.json`, its helper and handoff; `slice20-final-fresh-full-chain.log`, `slice20-final-upgrade-full-chain.log`, and `slice21-function-data-comparison.json`. Earlier failed gates are retained: they exposed the manual/bulk conflict precedence regression and then the disappeared-source cancellation regression, both corrected before final qualification.

## Remaining boundaries

This is A2.1 backend qualification. Attendance browser/UI recovery, explicit joint Leave/Time approved-fact correction (A2.2), fractional paid/unpaid absence and report attribution (A2.3), and the annual availability decision remain open. This document does not claim complete half-day or Cube 3 closure. No remote migration, deployment or main merge was performed.
