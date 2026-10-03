# Cube4 Source11 expected-Time coverage — source checkpoint, 2026-10-02

Frozen observational source candidate. No SQL execution/application, test execution, build/browser, commit or remote action performed by this writer. Main changes are limited to the new migration, new rollback suite and this checkpoint.

## Scope and exact integration

CLI created migration20261002132650_cube4_payroll_time_expected_coverage.sql. It introduces four private invoker helpers with empty search_path and EXECUTE revoked from PUBLIC/anon/authenticated/service_role. Current Payroll authority and scoped Employer identity use existing optional_capture_authorized; Attendance disabled returns explicit disabled empty coverage before schedule reads.

capture_optional_sources now includes optional_sources.time.coverage. Existing optional_sources whole-object freshness compares this canonical snapshot, so a missing-instance insertion, override cancellation, current interpretation or other relevant context change becomes optional_sources_changed. No engine identity or financial arithmetic is changed.

The known base build_review, or build_review_before_advances when present, adds source_summary.time_coverage and source_coverage_days. The current public workspace list strips source_coverage_days; existing protected employee detail preserves the safe date/state projection. Final-output authority/auditing and source10 calculations are untouched. This supports explicit known composition, not full ordered financial-chain runtime qualification.

## Observational contract

Each31-day inclusive window exhaustively resolves eligible Employer Employment dates. Employment start/end are inclusive; Assignment and override ranges are exclusive at until. Exactly one Assignment and at most one active override are required. Resolution uses their pinned policy template/version, never current catalog head. Site Tenant and legal Employer must match. Canonical weekday is extract(dow)+1 in policy.work_days. Historical policy versions remain immutable.

Expected fixed/flexible windows use existing time.resolve_local, including timezone/DST ambiguity refusal. Dates are generated through integer date offsets, not timezone-dependent civil-day timestamp iteration. Fixed cross-midnight attribution remains on its operational start date. elapsed is derived from the applicable attribution-end instant; no raw refreshed now is serialized. UTC epochs canonicalize private bounds. Bounds are cached per window/date/exact policy version.

Existing Work Instances are retained even on derived nonworking days and produce off_schedule_materialized. Missing, pending, policy mismatch, ambiguous schedule/window, future/not elapsed, noncurrent approved facts and classification reconciliation remain explicit owned states. Latest approved fact must bind the latest interpretation identity. Worked sources require ready interpretation; classified absence/leave_covered may retain needs_review observations only with exact classification evidence, matching kind and approval_eligible=true. NULL/unknown outcomes fail closed.

The helper does not open/approve a Work Instance, infer absence, treat an unknown schedule as nonworking, query independent disabled Leave sources, or manufacture zero units. The existing scoped transitive Time classification boolean remains as previously accepted.

Window capacity preflight counts clipped eligible dates before generating the grid, max20000 rows/window. Period tiling is inclusive, max366days, max200000 captured rows; overflow refuses a whole snapshot. Common500-Employment31-day grid fits the window bound, but no performance benchmark is claimed.

No persisted coverage-close/period approval certificate was found or invented. A status of observationally_complete proves only the scoped elapsed expected rows have current approved evidence; payroll_ready remainsfalse. Source10 captured_parts_only, source_time_coverage_unqualified, Time/Leave integrationpending and statutory gates all remain. There is no legal net or G4/financial consumption acceptance claim.

## Human projection ABI

source_summary.time_coverage:
enabled, status (disabled/unavailable/needs_source_review/observationally_complete), day_count, expected_days, approved_days, missing_days, pending_days, future_days, other_review_days, payroll_ready=false.

source_coverage_days (detail only):
date, expected (nullable), elapsed (nullable), state.
No Employee names, reasons, raw facts/observations, clinical types, source bindings or private provenance IDs enter either projection.

Private coverage stores stable scoped Assignment/override/policy/bounds/Work Instance/latest fact/latest interpretation identities and current classification boolean. It contains no source reasons/raw facts. It is retained only inside the protected manifest boundary.

## Authored evidence and actual checks

50 new rollback assertions passed on each protected fresh/upgrade baseline115, with all DDL and fixtures rolled back. Focus: disabled/scoped/current authority and private ACLs; nonworking versus expected missing; pending/current approved/latest unapproved; effective Assignment/override inclusive/exclusive boundaries; exact head avoidance; off-schedule rows; future and DST unknown windows; stable repeated capture/manifest; exact nonempty32-day period tiling with no gaps; insertion/cancellation snapshot staleness; public privacy/counts; finite dates; capacity refusal with rollback; unchanged known money and retained financial gates/no source/financial/audit writes.

Seed contracts were inspected against current source: separate non-default sites, Tenant-unique policy codes, exact policy/Assignment/Work Instance FKs and dated snapshots, current-role definer test bridges only. No production helper/authority override or weakened source guard is authored.

Executed static check: new SQL files whitespace check PASS. No TS changes, so no unchanged ESLint/typecheck was repeated. Actual SQL qualification is now PASS; see current qualification below.

Prerequisites: immutable qualified source9 capture and source10 daily reconciliation plus Adam v3/base identity chain; actual baselineQA remains root-owned. Source6 recovery work has owner authorization; unrelated financial gates remain. Root owns reviewed rollback9+10+11 qualification and subsequent coverage UI.

Prior independent UI evidence is separate: [root-owned keyboard/reflow evidence](C:/Users/DELL/AppData/Local/ai-dev-workflow/runs/20261002-cube4-payroll/cube4-daily-source-ui-keyboard-reflow-evidence.json) reports five scoped passes and unchanged read-only financial counts. It is not Source11 runtime evidence, actual browser zoom proof, or full accessibility qualification.


## Historical bounded cycle2 test correction (superseded hashes)

Independent source cycle1 FAIL established one P2 integration-test gap, not a migration defect. The migration remains exactly SHA256 b16ec889b67a1b63195486543ba45859ee3a229f235253f5566fa3d968bc5854.

Eight focused assertions now directly inspect actual build_review source_summary.time_coverage and exact source_coverage_days, then call the actual public.payroll_run_workspace ABI as the existing current authenticated Payroll actor. They prove list rows omit both daily arrays but preserve compact summary; selected detail retains the exact safe dates/states; full public reader payloads omit raw coverage provenance/sensitive canaries; an out-of-Employer Employment detail is denied.

A single strictly synthetic NONLEGAL review candidate is inserted AFTER the observational no-write assertion, using the actual builder output. It is a reader fixture only: no fabricated legal qualification, final append, financial lock, source consumption or payment evidence. The fixture explicitly asserts absence of final contexts/People frozen contexts/payment events. Its candidate-only setup is separate from the earlier observational read-only counts.

Total authored assertions50. Original42 assertions remain; no SQL/test/build/browser execution or unchanged lint/typecheck was performed for this delta. Source9/10/S7 and all UI files remain untouched. Cycle1 FAIL history is retained; this is cycle2 source ready for independent review.

## Current authorized qualification

Owner approved the minimal reader-fixture revision increment. Independent delta review passed. First actual SQL execution exposed an unassigned PL/pgSQL record shadowing a SQL alias; a narrowly reviewed variable rename fixed it. The alias delta also normalized line endings, explicitly disclosed in review. Current migration SHA256: 816ecb1ecafed52de9eca265fd28aaf2b765b9e9b733d1fbb2cbb9c07701152a; test: d3512d91d65ee01fd05b25ae9447ecf7fd59e9fc86e8fa091a497be9e1decf63.

`cube4-time-expected-coverage-qualification.json` records actual 50/50 PASS on each protected baseline115 with identities preserved. Prior failure evidence is retained. Source9/10 and Adam successful suites were not repeated.

The migration was subsequently installed only into the separate partial Source9/10 UI fixture without changing its migration ledger. One authenticated new-candidate journey passed: 31 captured days, 21 expected future days, zero missing or pending days, no inferred absence, net withheld and financial approval held. Actual Arabic RTL screenshots at390/820/1280 passed overflow checks. Root inspected the phone viewport and desktop screenshots. No payment, financial final context, Time Work Instance or fact was created. This is bounded source/UI evidence, not ordered full financial-chain or statutory qualification.
