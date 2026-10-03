# Cube4 source reconciliation and DAILY source checkpoint — 2026-10-02

Source frozen for independent review. No SQL execution, database application, build, browser qualification, commit or remote action was performed by this writer.

## Implemented contract

The additive migration requires the qualified Adam v3 engine and source9 optional capture. It patches the explicit known base functions when Slice7 before_advances wrappers exist, otherwise the current base functions. Existing financial guards, private ACLs, exact fraction rounding and statutory/Time/Leave pending blockers remain. Engine identity becomes cube4-review-v4-daily-sources; prior candidates therefore require recalculation.

Private reconciliation validates eligible Employment/Employee/Employer/date scope, canonical Time reconciliation, exact Leave request/approved-preview/date/quantity bindings, and halfday mapping versions. Classified absence_units remain exclusive of Leave. Duplicate, overlapping, unknown and stale sources have owned issues; no arbitrary winner, sensitive reasons, clinical data or raw binding projection is exposed.

Daily known parts use approved captured worked units (1 minus factual Leave units), plus current paid Leave only when independently enabled and reconciled. Absence/leave-covered facts create no work units; observed minutes remain visible separately. Dated compensation and percentages use the existing exact rational rounding path before component aggregation. Missing civil dates are never inferred to be worked, unpaid, or expected workdays: Time-derived output remains captured_parts_only and carries source_time_coverage_unqualified. Existing global time_integration_pending and leave_integration_pending remain. No authoritative gross/net, source consumption or legal qualification is claimed.

Current manual_units choice ABI:
- source=manual requires basis=approved_payable_total and units>0. This total already includes payable Leave; it is never added twice.
- source=time requires units=0 and no basis; actual dated units are derived from approved captured facts.
- Legacy source/basis absence remains usable without Time facts; competing Time requires cancellation of the old input and approval of a new explicit choice.
- Current pending choices hold; cancelled current heads do not resurrect earlier versions.
- Save/Approve of a new Time choice requires current Attendance capability after current authority/locks and canonical receipt lookup. Historical read and Cancel stay available; no approved-to-draft bypass is added.
- payroll_input_access adds time_enabled. There is no payroll_input_overview RPC in the current source.

## Public review ABI

Paged employees carry source_summary only. Safe source_days appear through review_employee_detail; workspace list strips them. No request/fact/type/mapping IDs or source reasons are included in either human projection.

source_summary includes status, time_enabled, leave_enabled, day_count, source_count, worked_minutes, absence_units, time_leave_units, paid_leave_units, unpaid_leave_units, issue_count, payroll_ready=false. Daily records additionally include selected_source (time/manual/legacy_manual), approved_units and coverage (captured_parts_only/approved_manual_total).
source_days includes date, time_fact_count, leave_source_count, outcome, worked_minutes, absence_units, time_leave_units, work_units, paid_leave_units, unpaid_leave_units and status.

Time entitlement loss with factual Leave units creates source_leave_treatment_unknown rather than silently treating Leave as unpaid. The owned alternative is an approved manual payable total; no Leave entitlement is made mandatory.

## Authored evidence and remaining gates

58 new rollback assertions cover reconciliation, halfdays paid/unpaid, absence exclusivity, exact mapping/preview/cancellation, privacy, scope, duplicate/unknown sources, legacy/current choice, actual authenticated Save/Approve/Cancel capability behavior, dated compensation and percentages, half-cent rounding, canonical receipt/audit cardinality, and no People consumption.

Checks actually executed once: affected rules ESLint PASS; tsc --noEmit PASS; scoped rules git diff --check PASS. A whole-worktree diff check reported pre-existing unrelated trailing blank lines in root-owned operator files; no unrelated file was changed.

The SQL suite is authored, not runtime PASS. No prior49 source9 suite or older financial suite was repeated. Root must independently review then compile/run source9 + this migration and the new suite inside rollback on retained QA115. Known before_advances composition is source-supported, ordered financial chain runtime remains unqualified. Root owns InputForm/actions and source-summary UI after this freeze. Monthly unpaid/late/overtime effects, expected-workday coverage, source consumption/final locks, qualified legal net and full G4 closure remain explicit gates.

## Root qualification addendum

The preceding paragraph records the original source freeze. Subsequent actual source review cycle1 failed the Slice7 candidate identity anchor; cycle2 passed after supporting both exact known insertion forms and adding four assertions (58 total).

The first rollback run stopped on upgrade QA115: 53 passed, five failed because two unparenthesized JSONB appends extracted `issues` after concatenation and erased blocker arrays. Three targeted diagnostic transactions established the shared null-array cause; no unchanged full suite was repeated. The exact two-parenthesis correction independently passed a delta review, with reverse edits recovering the prior migration hash.

Current qualified migration SHA256: `bf11f823ef3a928430f7ecd938d09977ab9291f29ccdf8172343e09bbe82067d`. Test SHA256 remains `3b31b7c63d6fba4b36564ec2aa434daba5c9e72c6bfabbb5478a118f62af515b`.

Actual result: 58/58 PASS on each of `business_platform_cube4_upgrade_qa` and `business_platform_cube4_fresh_qa`, source9 + source10 DDL and synthetic fixtures inside a single rolled-back transaction. Both retained baseline identities/compiled fingerprints stayed unchanged at ledger115. Outside evidence: `cube4-source-reconciliation-qualification.json`; prior failure inputs/logs retained by hash.

The owner-approved definition is recorded in [the daily source amendment](../04-product-specs/payroll-daily-source-definition-amendment-2026-10-02.md). Inputs UI and safe day explanation received independent source cycle2 PASS. Six helper tests, five initial React SSR tests and four focused review-delta regressions passed; typecheck and affected ESLint passed. These do not establish a browser journey or ordered financial-chain qualification. Runtime UI, expected-workday coverage, full G4, legal net, public finalization and governed correction recovery remain open.

## Actual bounded UI runtime qualification

The daily-source browser journey subsequently passed 12 checks on a retained derived database `business_platform_cube4_daily_source_ui_qa`: original fresh QA115 copied with qualified source9/10 definitions only. The derived ledger remains115 and deliberately omits pending6/7/8; this is not an ordered financial-chain migration or full Cube acceptance. Original fresh QA identity was preserved.

Build `IUPeu19aMXItRlcBz5eEu` exercised real authenticated UI: an employee outside the first30 fails explicitly and is selected correctly after code search; manual1.5 total saves/approves; unsaved quantity approval has no effects; one candidate displays1.5 days and known150 EGP with both optional services off; cancellation/replacement preserves employment and period; switching to Time hides the marker quantity and retains the typed manual value when switching back; Time save/approve records source=time with server-derived zero marker and no manual basis; losing Attendance does not prevent current-authority cancellation. Both review and form passed390/820/1280 widths. Two manual heads, six successful manual command receipts, zero final outputs. Assertion-observation failures and their successful-step checkpoints were retained; successful save/approve/calculate transitions were not replayed.

Direct screenshot inspection identified an unnecessarily distant form behind30 employee cards. Four JSX changes collapse employee/saved-input lists only during an explicit form task. Independent delta review, affected typecheck/ESLint and build passed. Current build `NZCLBp6v85qkYK3g2ld27` passed five read-only layout checks: default lists stay expanded, form lists collapse with accessible native disclosures, no horizontal overflow at390/820/1280, and payroll counts remain exactly `7|9|1|0` before/after (input versions, all command receipts, candidates, final contexts). Desktop form heading moved to595px; mobile900px. No prior monetary journey was repeated for this layout-only delta.

Outside authoritative summary: `cube4-daily-source-ui-qualification.json`; functional journey `cube4-daily-source-ui-browser-evidence.json`; final layout `cube4-daily-source-ui-layout-browser-evidence.json`; final source hashes `cube4-daily-source-ui-source-hashes.json`. Runtime processes/config/fixtures are isolated on loopback3430/3431/3433/3435 and retained for inspection. No new publication or production changes.

Expected-workday coverage, monthly unpaid/late/overtime effects, source consumption and final locking, current qualified statutory net, governed correction recovery, ordered financial-chain/runtime gates and full Cube4 completion still require their own evidence.


## Bounded review correction — cycle2 source freeze

Independent cycle1 FAIL identified only the candidate engine composition guard: Slice7 replaces the literal candidate engine with manifest-derived identity. The new private immutable invoker helper daily_source_command_definition accepts exactly one v3 literal candidate insertion and upgrades it to v4, or exactly one manifest-derived insertion only when the known before_advances wrapper exists. Unknown/duplicate/mixed anchors fail closed. Its EXECUTE privileges are revoked from PUBLIC, anon, authenticated and service_role.

Four additional authored assertions use the real current command definition to distinguish literal upgrade, known wrapped preservation, unwrapped dynamic refusal and unknown shape refusal. The total is58. These are structural helper checks, not full Slice7 runtime qualification.

Cycle1 failure remains historical evidence. Cycle2 source is ready for independent review; no SQL execution or additional unchanged lint/typecheck/build/browser checks occurred. UI, runs rules, source9 and Slice7 files were untouched by this correction.
