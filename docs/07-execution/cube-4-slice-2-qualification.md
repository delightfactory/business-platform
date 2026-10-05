# Cube 4 Slice 2 focused local qualification

Status: **Focused local candidate qualified; full Cube 4 remains unqualified.** Base `555c34a568f44eb4b99d99712a699094488f3026`, branch `codex/cube4-payroll-core`, dedicated database `business_platform_cube4_upgrade_qa`. No commit, push, remote migration or deployment.

## Implemented scope and accepted policy

The Arabic Payroll inputs route provides bounded components, dated recurring assignments, once-per-Tenant proration setup, approved manual daily units, attributed adjustment draft/approval/cancellation, complete opening YTD, preparatory Employment readiness, and owned correction requests. Private source-context registration protects dated People evidence; it is not a public financial lock. The [owner-approved ordinary proration amendment](../04-product-specs/payroll-ordinary-period-proration-amendment-2026-10-02.md) makes actual inclusive cycle days the default and preserves a full monthly salary for a full ordinary cycle. Fixed30 monetary semantics remain an explicit calculation gate.

## Evidence

- Independent read-only review: first pass found Finance-only component discovery failure, historical recurring overlap gap, finite component renewal block and malformed test quotes. One rework resolved them; bounded delta review **PASS**. External providers were unavailable earlier, so a fresh built-in reviewer supplied weaker provider separation.
- Migration `20261002002040_cube4_payroll_inputs.sql`, SHA256 `2809c39b24cdfc825d517043baec610a7b004f6dc09adcb52ef26541bba1d020`, applied atomically to owned upgrade QA only; ledger now 111 migrations.
- New rollback suite: **50 assertions PASS**, including scope/privilege denial, exact replay/changed intent, no arbitrary expressions, Tenant-wide policy uniqueness, Finance-only narrow discovery and creation, historical/future recurring duplicates, active effective component resolution, finite renewal, daily capacity, approval/cancellation, YTD completeness, protected history, audit failure rollback and current entitlement before replay.
- Two real PostgreSQL sessions: registration first made the source writer wait and refuse with `23514/payroll_people_correction_required`; source writer first made registration wait and refuse `PT409/payroll_source_stale`. Source amounts/context counts matched the winning transaction. This qualifies the private foundation only, not G3 or final consumption.
- Final build **PASS**, build ID `vriI94zTkAts5oQKxFiAC`; TypeScript completed. Writer typecheck and changed-code lint passed; root `git diff --check` exit 0.
- Genuine authenticated UI: actual-days default/save, component save, reward draft → approved → cancelled, capacity rejection preserving entered values, then daily-unit save/approval and durable reload. Four attributable input heads remained after reload.
- Protected-context correction request was submitted through the actual UI, then reloaded and observed as an owned request. Exactly one request/one frozen context remained and source compensation stayed 9000. The initial harness waited for a transient form status that revalidation removes; the follow-up observed the durable requested state without submitting another request.
- Widths 390/820/1280: no horizontal overflow. Phone and desktop screenshots visually inspected; RTL navigation, lists before optional forms and task actions remained usable. The first browser attempt stopped on an exact-label selector for a wrapped select; the harness selector was corrected without application changes, and the focused journey then passed.

Machine-readable logs and screenshots are outside Git under `%LOCALAPPDATA%\ai-dev-workflow\runs\20261002-cube4-payroll`: `cube4-inputs-migration-apply.json`, `cube4-inputs-test-evidence.json`, `cube4-inputs-test.log`, `cube4-inputs-race-evidence.json`, `cube4-inputs-browser-evidence.json`, `cube4-inputs-{390,820,1280}.png`. Private fixtures and credentials remain outside Git and are not evidence for production readiness.

## Remaining boundary

No calculation, applied financial input, public approval/lock, payment, advance, payslip or executable replacement correction is exposed. Optional Time/Leave sources are not consumed. Verified statutory packs/goldens, actual source-consumer integration, full fresh/upgrade qualification and later financial slices remain open. The existing Cube3 defect remains deferred by explicit owner instruction. Previous passing Slice1 suites were not repeated.
