# Cube 4 Payroll Core additive experience and execution extension

Status: PROPOSED ADDITIVE EXTENSION FOR REVIEW. Prepared 2026-10-01 from repository revision `555c34a568f44eb4b99d99712a699094488f3026`. Suggested repository destination: `docs/07-execution/cube4UXextension.md`. Preserve existing documents and append accepted clarification links through normal governance. This file distinguishes established requirements from proposed operational detail; it does not supersede the Frozen contract, authorize publication, or establish qualification.

## Purpose and current conclusion

Prepare a complete Payroll Core cube without weakening Cube 3 acceptance. Planning can proceed now. Start dependent implementation only after the selected Cube 3 base and its outstanding annual-calculator journey have been qualified. The first implementation slice is payroll setup and period readiness, not completion of Payroll Core.

Remote inspection found Cube 3 at `555c34a568f44eb4b99d99712a699094488f3026`, main at `504f9048f0909d2ea47c7de23b45962ef028e9bf`, and no Cube 4 execution branch. These are observed refs, not instructions to merge. The newer annual GET context failure and isolated unpublished copy fix were reported by the coordinating task, not reproduced by this read-only review. Preserve that distinction in readiness evidence.

## Governing sources

All links pin the inspected revision. Numbered references below identify governing scope, not an independent new hierarchy.

- [S1 Cube execution plan](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/07-execution/v1-cube-execution-plan.md)
- [S2 Frozen Employee Finance and Payroll specification](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/04-product-specs/employee-finance-payroll-spec.md)
- [S3 Payroll calendar and cutoff amendment](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/04-product-specs/payroll-calendar-and-cutoff-amendment.md)
- [S4 Accepted final implementation readiness amendment](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/07-execution/final-implementation-readiness-amendment.md)
- [S5 Cube 3 final local qualification](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/07-execution/cube-3-v1-final-qualification.md)
- [S6 Leave projection and consumer gate](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/07-execution/cube-3-payroll-facts-projection-qualification.md)
- [S7 Reviewed Attendance classification](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/07-execution/cube-3-classified-attendance-facts.md)
- [S8 Frozen People and work context](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/04-product-specs/hr-people-work-context-spec.md)
- [S9 ADR 008 authoritative transactions and access](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/03-architecture/adr/ADR-008-authoritative-data-access-and-transaction-boundaries.md)
- [S10 Definition of Ready](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/06-governance/definition-of-ready.md)
- [S11 Definition of Done](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/06-governance/definition-of-done.md)
- [S13 Frontend and UX baseline](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/05-engineering/frontend-ux-baseline.md)
- [S12 Source of truth and conflict resolution](https://github.com/delightfactory/business-platform/blob/555c34a568f44eb4b99d99712a699094488f3026/docs/06-governance/source-of-truth.md)

Accepted amendments govern their named scope, Accepted ADRs technical decisions, and Frozen specifications product behavior. Code and later engineering notes are evidence, not automatic overrides [S12]. S5 explicitly excludes the broader joint Leave/Time coordinator from bounded V1; do not resurrect the older S7 remaining-work language as a new Cube 4 dependency.

## Review coverage and real improvement opportunities

This is a source-grounded specification review, not an audit of a running Cube 4 interface. The inspected tree contains no dedicated Cube 4 implementation/qualification contract. Source coverage includes the full Frozen Payroll spec, calendar amendment, execution roadmap, accepted readiness amendment, People specification, access ADR, governance readiness/done/source hierarchy, Cube 3 closure and Time/Leave projection contracts. A historical Attendance projection migration was inspected for boundary shape; later migration qualification takes precedence for current behavior. Existing source functions must be reread at the selected implementation base before changing their lock or permission contract.

### Established requirements to preserve

The approved baseline already requires optional-domain independence, effective calendars, bounded components, versioned statutory packs, exact money, complete payment/correction/advance lifecycles, Arabic responsive interfaces, task-oriented UX, progressive disclosure and owned recovery. Repeating those is traceability, not a claimed new improvement [S1–S4].

### Concrete missing operational detail

- **Run versus setup separation:** the spec says to separate them but does not define the default page composition. Proposed screen map below makes the next task visible and keeps expert setup out of monthly work.
- **Readiness as actionable issues:** required missing setup, stale inputs and anomalies need a consistent owner and next action, not disconnected red banners. Proposed readiness list below connects each issue to a scoped source fix and return path.
- **Failed reads versus empty data:** an API failure must never render “no employees” or “no payroll”. Preserve existing view/input and offer a scoped retry; avoid repeating Cube 3-style confusing load states.
- **Payment corrections and remaining obligations:** the Frozen contract defines payment tracking and payroll correction but does not fully specify an erroneous payment record, excess amount or insufficient deduction capacity. These are material decisions; interface wording cannot resolve them silently.
- **Calendar edge semantics:** month-end numeric cutoff, payment date and timezone effects need explicit examples and tests before code.
- **Consumption permissions and races:** a payroll preparer does not automatically hold current Time/Leave read permissions. Define a narrow supported command and compatible source locking rather than add broad permissions or trust paginated reads.
- **Post-interruption recovery:** receipt-based retry, obsolete-preview invalidation and return-to-review behavior turn correct backend invariants into usable financial work. The proposed flows make those testable.

None of these findings claims an observed defect in a nonexistent/untested Cube 4 screen. The only current runtime concern referenced is the separately reported Cube 3 annual-loading issue.

## Proposed task screen map

The following is additive UX detail within the approved scope. Reuse existing patterns before adding components. Keep one page role and one dominant action, with quiet secondary actions.

| Screen | Normal task and essential content | Primary next action | Advanced or exception detail |
|---|---|---|---|
| Payroll overview | Employer, actual current period, readiness, employee count, total only when calculated, issues, recent runs | Start preparation or continue current stage | Earlier periods and filters collapsed; no grid of setup cards |
| Payroll setup | Calendar dates preview, payment rule, proration policy, minimum required components and statutory readiness | Save reviewed setup | Policy versions, pack provenance and expert settings under details |
| Prepare period | Eligible Employees and succinct included inputs; list of owned blockers | Calculate payroll when ready | Source manifests/technical provenance only for authorized detail; absent optional domains do not appear as errors |
| Review payroll | Gross/net/statutory totals, comparable-period changes, actionable issue list, clean Employee rows | Approve reviewed payroll | Employee line explanation, variance detail and safe bulk resolution |
| Employee calculation detail | Human-readable earnings, deductions and net with date-sensitive explanation | Return to review or fix permitted source | Source lineage and exact formula explanation expandable; never editable locked totals |
| Lock confirmation | Employer, actual dates, employee count, totals and irreversibility | Lock payroll | No new policy setup or hidden changes in confirmation |
| Locked run | Frozen totals, remaining payable, clear output and correction options | Record payment or view remaining obligation | Exports, payslips and audit/history secondary; permission-aware |
| Record payment | Remaining amount, entered paid amount/date/reference; “recorded externally” explanation | Record this payment | Error correction only via the reviewed governed route |
| Correct payroll | Show current payment state and allowed correction path chosen by system | Review amendment or prepare linked adjustment | No choice of an illegal amendment route after any payment |
| Employee advance | Principal, externally disbursed status, next installment, outstanding balance, movement history | Contextual activation, settlement or review | Schedule details and compensation links expandable |
| Reports | Selected Employer/period, report purpose, reconciled summary | View or export selected report | Optional filters collapsed; export scope and authoritative version clear |

### Readiness and return navigation

Each blocker carries: affected Employee or setting; business reason; blocking versus informational state; responsible capability/role; and one useful destination. Examples: missing salary → compensation setup; stale source → renewed payroll review; unverified legal pack → authorized compliance owner; unreconciled half-day → Time/Leave review. Return from a source fix to the originating period and preserve review filters. Recheck readiness rather than claim the fix succeeded merely because the user returned.

When the user lacks permission, show who can resolve the issue in business-role language and retain the safe view. Do not offer a dead link or require the operator to understand permission keys. For a Payroll-only actor, show the permitted blocker and responsible role without revealing Leave type, reason or other source-private evidence. Do not make an inaccessible HR page the only resolution path. Do not automatically send notifications to another person without an approved product workflow.

### Contextual Arabic copy examples

These are proposed examples, to be aligned with established product terminology and actual behavior. UI copy uses professional understandable Arabic; the separate Codex goal uses the owner’s conversational voice.

| Context | Suggested copy and action |
|---|---|
| New Payroll setup | “جهّز إعدادات الرواتب لبدء أول مسير” / “إعداد الرواتب” |
| Failed read | “تعذّر تحميل بيانات الرواتب. حاول مرة أخرى.” / “إعادة المحاولة” — retain existing content and do not show an empty-state message |
| Missing salary | “لم يُحدد راتب أحمد لهذه الفترة” / “مراجعة بيانات الراتب” — replace name with actual authorized fixture/context |
| Changed inputs | “تغيّرت بيانات تؤثر على الرواتب. أعد الحساب قبل الاعتماد.” / “إعادة حساب الرواتب” |
| Preview failure | “تعذّرت مراجعة الحساب. بياناتك محفوظة، ويمكنك المحاولة مرة أخرى.” — say data is preserved only when it is |
| Approved awaiting lock | “تم اعتماد الرواتب وهي جاهزة للتثبيت” / “مراجعة وتثبيت المسير” |
| Lock confirmation | “بعد التثبيت، لن يمكن تعديل هذا المسير مباشرة. أي تصحيح سيُسجّل بشكل مستقل مع الاحتفاظ بالمسير الأصلي.” |
| Payment entry | “سجّل الدفعة التي تم صرفها خارج النظام. لن يتم تحويل أموال من هنا.” |
| Partial payment | “تم تسجيل دفعة بقيمة … ج.م. المتبقي … ج.م.” / “عرض الدفعات” |
| Correction after payment | “تم تسجيل دفعة لهذا المسير. سيُسجّل التصحيح كتسوية مرتبطة، مع الاحتفاظ بالدفعات السابقة.” — show the exact permitted route |
| No authority | “تحتاج هذه الخطوة إلى مسؤول لديه صلاحية اعتماد الرواتب” — no technical enum or UUID |

Do not collapse “اعتماد”, “تثبيت”, “صرف/تسجيل دفعة”, “إلغاء” and “تصحيح” into one ambiguous “تم”. Reserve destructive styling for the genuinely consequential action; normal save, cancel-form and back navigation are distinct.

### Review refinements for operational acceptance

- Readiness has distinct ready, blocked, not checked and source unavailable states. Failed loading and disabled capability never masquerade as zero issues, zero salary or verified readiness. Already-approved obligations/history from a subsequently disabled module follow governed closure rather than disappearing.
- Blocking issues and review-only warnings are distinct. Show the business financial consequence, permitted next action and responsible role. Preserve the exact Employer/period/filter when returning from correction. Unknown opening YTD must not silently become zero.
- On first payroll or no comparable period, state “لا توجد فترة سابقة قابلة للمقارنة”. Never invent a zero-percent improvement. Explain unequal transition-period comparisons rather than presenting misleading variance.
- Bulk actions state selected count, scope and consequences. Distinguish visible-page selection from all matching records, expose excluded ineligible rows, and report partial outcomes with retry only for failed entries. A bulk action cannot waive source/legal blockers.
- Site/Department filters never change Employer-wide authority. Approval and lock confirmations retain whole-run totals and scope even when the list is filtered.
- Loss of session/authority invalidates confirmation and redacts cached sensitive content. Switching Tenant/Employer clears old sensitive drafts, selection and data with no cross-scope flash. Retain drafts only in authorized, appropriately protected storage; never put payroll payloads in logs, URLs or unsecured browser storage.
- Authorize file retrieval as well as export creation. Identify unissued/superseded output and prevent an old export being presented as current. Do not create public payroll links.
- The system may select only a verified applicable effective statutory pack. The operator sees compliance readiness and required facts; legal rates and pack IDs are not ordinary editable setup fields.
- Preserve distinct approved, locked and paid meanings. Use consequential confirmation for lock; avoid repeated confirmations for low-risk filtering/search/draft operations.
- Mobile tests include virtual keyboard and safe-area overlap on amounts/confirmation, long Arabic names, large and negative EGP values, mixed-direction references and dialog Back/reload/focus behavior.

## Complete cube outcome and boundaries

An authorized payroll team can configure an Employer, prepare payroll for eligible monthly/daily Employees, consume approved inputs from enabled domains, calculate deterministic EGP results with a verified effective statutory pack, review exceptions/variance, approve and lock, issue authoritative payslips/exports, record external payments, and reconcile/correct every resulting obligation [S1–S2].

Include salary-component catalog and effective recurring assignments; approved penalties/rewards; employee advances, installment schedules, settlements and compensating entries; YTD onboarding; final-period handling; payroll, variance, statutory, outstanding-balance and payment reporting. People plus compensation and Payroll configuration are sufficient dependencies. Attendance, Leave and Employee Finance are optional entitlements; daily pay without Attendance uses approved manual work units [S2].

Exclude bank-payment execution, bank integration, accounting posting, off-cycle runs, generic rules/workflow engines, arbitrary formulas, multi-country rules, full ESS/MSS and specialized termination formulas. Unsupported termination amounts have an explicit authorized manual-component/external handoff, not a silent omission. Actual bank/cash payment and advance disbursement occur externally and are recorded/reconciled [S2].

## Entry gates and dependencies

G1 Select and record a qualified exact base. Close/reproduce the reported annual GET failure in the actual browser environment, verify copy-fix publication status, and run the affected regression after any fix. Cube 3's committed technical report alone does not resolve a later failure. No main merge/deployment is implied [S5, S11].

G2 Establish per-slice readiness: close and review the decisions, inputs, invariants, failures, permissions and UI end states required for the affected slice before implementation. Keep later unresolved decisions explicit; continue safe independent work rather than block every slice on future financial choices [S10].

G3 Before Payroll consumes People, implement same-transaction guards for employment, compensation and other material source changes reaching locked periods, with explicit correction routing. Existing dated People history/manual warning is not a lock detector [S1, S8].

G4 Before emitting money from enabled Time/Leave, implement authoritative current-source validation, idempotent consumption and cancellation/successor reconciliation. The Leave endpoint is read-only, approved-history projection: cancelled sources retain identity with zero current effective units. Its flag `projection_only` does not confer a consumption guarantee [S6].

G5 Confirm actor/permission and entitlement-loss behavior, approved-input ownership, legal pack scope and reviewed financial rounding. No guessed statutory rates or unverified legal applicability enter live payroll [S2, S9].

## Ordered complete vertical slices

Each slice includes authoritative data commands, business-facing UI, failure/recovery, negative access tests, reproducible migrations and documentation. Qualify each completed workflow before expanding. Later capabilities stay clearly unavailable rather than pretending to work.

### Slice 1 Payroll setup and period readiness

Payroll administrator selects an Employer (safe default only when unique), configures monthly cutoff, effective date, payment rule and timezone, previews actual date boundaries, and saves a versioned calendar. Operator sees the next period, concrete blockers and next action. Provide read/change/preview/cancel flows and retained input on failure. Superseding a calendar preserves every generated period; open affected runs must complete or be explicitly cancelled before transition. A reviewed short/long transition begins the day after the last generated period. It is not approved for monetary use until the transition-pay explanation is implemented [S3].

End state: valid Employer calendar and reviewable period readiness; no claim of calculated payroll. Gate: resolve numbered cutoff and payment-rule proposals below. Test two Employers, leap years, timezone/local dates, consecutive periods, history preservation, concurrent saves and transitions. Warn explicitly when pending Attendance inputs exist, alongside open runs and locked history [S3].

### Slice 2 Compensation and approved input readiness

Payroll operator configures bounded components and effective recurring assignments, chooses the payroll proration policy, enters validated opening YTD, and prepares eligible Employees plus approved manual daily units or one-time adjustments. Finance author can draft, approve or cancel an adjustment with clear ownership. Separate compensation visibility from ordinary People directory access. Input errors identify the Employee and correction destination; changing a prepared input invalidates the affected reviewed candidate.

Include G3 and the approved-input version contract here, before any real calculation consumes People. End state: complete, reviewable input set, or owned blockers. A configured component alone is not slice completion. Statutory classifications remain tied to a verified pack rather than arbitrary free-text formulas [S2 §§3–6,17, S8].

### Slice 3 Calculate review and cancel a candidate

Operator opens a period, prepares and calculates; reviewer sees totals, changes from a comparable period, missing setup, negative/net anomalies, stale sources and explainable lines. Resolve issues at their source, recalculate and review. Monthly and daily pay, mid-period compensation changes, join/end, configured proration, transition periods and YTD are covered. Enabled Attendance/Leave inputs pass G4; disabled domains add no dependency. A draft/review candidate can be cancelled without hidden consumption or stranded obligations.

End state: a current reviewable calculation candidate or explicit cancelled candidate. No locked output or payment claim yet. Use synthetic packs only in isolated tests; real calculations require a verified applicable pack and golden cases [S2 §§4–5,9–11,16–19].

### Slice 4 Approve lock and issue authoritative output

Approver accepts the exact reviewed candidate; locker sees Employer, period, employee count, totals and irreversible consequence. Recheck all authority, versions and blockers atomically. Persist immutable calculation context, result, approved consumption and success audit. Generate payslip/export only from the authoritative locked run with resolved legal Employer identity. View/retry/export recovery must work after a dropped response, without double lock or duplicated consumption.

End state: authoritative locked payable and distributable output. Before enabling this slice, supply the payment recording and full correction routes in Slices 5–6 behind the same release gate; do not expose a production irreversible lock that strands the user [S2 §§9,12–15, S4, S11].

### Slice 5 Record and reconcile external payments

Authorized operator records amount/date/external reference against the locked payable, sees remaining obligation and transitions unpaid → partially paid → paid. Show that the platform records a payment already made externally. Duplicate submission/retry must not increase paid value twice. Invalid amounts and excess payment require a defined refusal/recovery rule, never an unexplained negative balance. Errors in recorded payment require a reviewed attributable correction/compensation path; decide its exact V1 semantics before implementation.

End state: paid and reconciled or visible owned remaining obligation. No bank execution [S2 §§12–13].

### Slice 6 Correct payroll and close final periods

Before payment, create linked Amendment Run, calculate/review/approve/lock replacement; original becomes superseded only with successful replacement lock. Retain history and invalidate ordinary distribution of its old payslip. Once any payment exists, including partial, prohibit replacement. Create linked next-open-period positive/negative adjustment or specifically approved external settlement; reconcile original paid amount, remaining obligation and compensation without double payment. Support ending employment and final-period marking with explicit settlement/manual handoff.

End state: linked correction reconciled, or a clearly owned adjustment in its target period/external settlement; original locked data untouched. Test concurrent payment versus amendment lock [S2 §§12–14,18].

### Slice 7 Advances installments and settlement

Finance operator creates draft principal/schedule, records external disbursement and activates, reviews due deductions, consumes each approved installment once through payroll, and settles/reconciles. Cancellation before activation/disbursement responsibility, early/manual settlement and compensating corrections are supported. Outstanding balance is ledger-derived; settled requires zero explained balance. Statutory deduction constraints are verified for the applicable case; unresolved/excess deductions stay visible for a reviewed disposition rather than silently disappearing.

End state: attributable outstanding balance or reconciled settlement. Integrate locked consumption and post-payment correction from prior slices; test optional-finance-disabled payroll [S2 §§6–8].

### Slice 8 Reporting and complete cube qualification

Provide authoritative payroll sheet/payslip, components/totals, statutory reconciliation, variance, outstanding advances and payment reports with Employer/period filters, permissions and bounded navigation/export. Run all normal/correction/entitlement-loss journeys with representative desktop/tablet/phone evidence. Replay full migrations and retained-data upgrade; verify exact-revision totals, history, permissions and race suites. Complete legal/operational/security/pilot release gates separately; an implemented cube is not automatically production-ready [S1, S2 §§15,23, S11].

## Authority and permission contract

All normal operations validate authenticated actor, explicit Tenant, current active Membership, Tenant lifecycle, resource/Employer scope, permission, entitlement and lifecycle preconditions at the authoritative data boundary [S9]. Private tables have no accidental direct writes/reads; UI hiding and server-route checks are insufficient. Normal tenant access is denied for suspended/archived Tenants; historical optional-entitlement behavior never bypasses this rule.

Map commands to `payroll.view`, `prepare`, `review`, `approve`, `lock`, `correct`, `export`, `payment_record`, `payroll_config.manage`, `employee_finance.view/manage/approve` and `statutory_rules.manage`. Several permissions may be held by one person; do not invent mandatory enterprise separation. Sensitive actions remain separate and audited [S2 §21].

Payroll entitlement loss blocks new runs; retained view/export and necessary correction/closure use an explicit reviewed command matrix. Source-domain historical projection authority must not be broadened automatically to every payroll preparer. Proposed solution: a narrow Payroll consumption command with defined approved-fact visibility, retaining domain-private access limits; review this authorization contract before implementation.

## Financial and transactional invariants

1. One active authoritative run chain per Tenant + Employer + Period; Site/Department are filters, not payroll legal authorities.
2. Use exact decimal money with explicit EGP currency. Specify ordinary rounding point/mode and effective pack-specific statutory rounding; no authoritative binary floats.
3. Store exact Employee/Employment/compensation, recurring component, input source/version, policy, calendar, statutory pack, engine version, line totals and actor/approval provenance at lock. Recompute frozen fixtures identically.
4. Approved inputs have stable source identity, current version/hash, date/units, Employment/Employer, provenance, policy and supersession link. Leave day identity is request + approved preview version + date. Cancellation keeps that identity and reversal evidence.
5. A preview/candidate is not a reservation or proof of freshness. Source/config changes make affected unlocked calculation stale; approve/lock must refuse until recalculation. After approval, material edits require explicit return to draft before lock.
6. Consume/reverse in Payroll's own immutable ledger, exactly once for the defined authoritative target. Never treat read projection as consumed. A source successor or cancellation cannot rewrite locked financial results.
7. Reconcile Time and Leave per affected Employment/date and original source identity. Preserve independent observed work, full/half-day units and exact Leave references. Unresolved overlap or Time reconciliation blocks the affected monetary exposure. Do not infer a second absence deduction from two projections.
8. Mutation plus required audit and idempotent receipt must commit atomically. No partial lock, orphaned consumption, hidden finance movement or acknowledged success without audit.
9. Any recorded payment changes the correction route. Paid and remaining obligations must survive corrections; no unlock/rewrite operation.
10. Legal Employer identity and generated document identity are snapshotted; application branding is not a substitute for missing official identity [S4].

## Lock order freshness and retry design

This is a proposed protocol requiring code-level lock-graph review, not an invented already-implemented guarantee.

Before writing financial commands, inventory all relevant People, Time and Leave mutation functions and their lock edges at the final base. Known evidence: Time classification locks Employment before Work Instance, and must not acquire Leave locks beneath Work Instance [S7]. People/Attendance already share Employment serialization. Do not add a reverse edge via Payroll.

Proposed design for review: serialize the Employer/Period run-chain decision with a dedicated transaction-scoped key; take affected Employment locks in stable identifier order before domain source rows; acquire source sets in an audited deterministic order; acquire/revalidate candidate/run/consumption rows consistently. Every competing source mutation that changes monetary eligibility must participate in a compatible lock/invalidator discipline. The exact position of period serialization versus Employment locks remains a design decision: prove no existing writer acquires them in reverse order. A lock held only by Payroll cannot protect against a source writer that ignores it.

Discover the full affected Employment/date/source set, including reversals and superseded inputs; lock; reread authoritative versions and approval state; recheck actor/entitlements; compare candidate fingerprints and expected versions; then append result/ledger/audit/receipt atomically. If discovery changes under lock, reject and request a fresh review instead of silently including an unreviewed source. No monetary result may be emitted before the required period/source protection and validation [S6].

Read projections in bounded date windows and exhaust stable cursors. Leave permits at most 31 inclusive dates and page size 1–100. Do not assume a transition period fits one request. Multi-page preview is advisory; commit reconstructs/revalidates its manifest to detect concurrent insertion, disappearance, cancellation and version change, not just values on already-seen rows.

Proposed idempotency envelope: Tenant + command family + authorized scope + caller-supplied attempt key, with canonical intent fingerprint and immutable receipt. Same key/same intent replays its recorded outcome after current authority validation; same key/changed intent conflicts. A dropped response is recovered by retry/receipt lookup; do not mint a new payment/lock key until the previous outcome is known. Expected-version conflicts preserve entered fields and point to refreshed review. Bound lock wait/retry and expose a safe retry state; never silently loop financial mutations.

## Calendar edge proposals requiring acceptance

P1 Numbered cutoff: preserve configurable cutoffs. Proposed explicit behavior is to map a numbered cutoff beyond the month length to that month’s final date, with the next period starting the following day. Show January/February/leap-year examples in setup preview. This clamp behavior is a proposal requiring acceptance; do not silently invent it or restrict support to days 1–28 as if already Frozen.

P2 Payment rule: propose one bounded rule family, a numbered day in the period-ending month or following month, with explicit shorter-month behavior. Show resulting date during preview. No automatic bank-holiday shift without an approved payment-calendar source and rule. Product owner must choose supported variants and operational date constraints.

P3 Timezone: use an explicit Employer payroll timezone; derive local date boundaries consistently. Propose preventing effective timezone changes from reinterpreting generated periods, like cutoff changes. Specify DST/local-date cases without treating UTC midnight as the business boundary.

P4 Transition pay follows S3: sum covered local dates using each date's effective monthly salary divided by 30 (`fixed_30_day`) or days in that date's calendar month (`calendar_days`), then round under the defined monetary contract. Ordinary full-period semantics and component treatment must be explicit; do not reuse a transition formula by inference.

## Responsive Arabic journeys and recovery

Use the existing shell and shared primitives [S13], including Cairo 600 / 14 px action labels, shared 8 px radius and minimum button heights 40 px desktop / 44 px at widths up to 900 px. Do not create a separate Payroll visual system or change shared tokens without shared-architecture review. Overview answers readiness, blockers, changes and next action. Primary labels can be “إعداد مسير الرواتب”, “مراجعة الرواتب”, “اعتماد الرواتب”, “تثبيت مسير الرواتب”, “تسجيل دفعة”, “تصحيح مسير الرواتب”; review exact wording against existing product language. Always show Employer and actual period dates, while keeping IDs/hash/version tokens out of ordinary views.

Setup is separate from recurring payroll. Inherit safe prior-period choices; progressively disclose tax/configuration details. Review prioritizes exceptions and supports safe bulk resolution, without requiring every clean Employee to be opened. Confirmation of lock shows totals and irreversible meaning; payment confirmation clearly records externally completed payment.

Desktop uses a compact collection/review workspace; phone uses readable summaries and focused Employee/task detail rather than a compressed wide financial table; tablet must retain reachable primary actions. Dates, EGP and Latin references need correct bidi handling. Keyboard order follows the task; focus returns after cancel/dialog dismissal; labels/error descriptions are programmatic; status is not color-only; touch targets and reflow are checked with actual content.

For each journey test loading, empty setup, no Employees, no permission, disabled entitlement, validation, stale review, failure, success, retry, cancellation and history. Preserve inputs on failures, clear obsolete confirmations after a failed/new preview, prevent repeat clicks from duplicating commands, and verify Back/Forward/reload/dropped-response recovery. Test 390/820/1280 widths as representative inherited classes, plus keyboard and zoom/reflow. Screenshots complement real journey interaction; neither screenshots nor a passing build establish acceptance alone.

## Statutory qualification gate

This draft makes no current legal-rate claim. Before period-qualified live use, Payroll/Compliance must identify applicable jurisdiction, worker/category, tax year and effective period; fetch official tax, social-insurance and employment-law sources; record exact document/version/date/provenance; verify numeric tables, classifications, ceilings, precedence, tax treatment, YTD and rounding; and compare golden scenarios to the official model or reviewed authoritative computation [S2 §§8,16–17].

Also qualify a non-calendar period crossing a tax year or statutory effective boundary (for example 26 December–25 January). Determine applicable year/rule and any date-splitting or payment-date treatment from verified authority, never the human run label. Reconcile opening/cumulative YTD under that verified treatment.

Include low/medium/high income, mid-year join/YTD, min/max insurance boundaries, taxable/non-taxable components, loan/deduction ceilings, overtime/rest/holiday categories, corrections after withholding and rounding boundaries. Do not import rates from this repository's older anchor text as proof. A disagreement blocks statutory qualification, not the test. Missing/expired/unverified pack blocks real calculation/approval/lock with a clear authorized remediation path. Record legal review limits separately from technical determinism.

## Unresolved decisions and stop conditions

- Qualified base and reproduction/closure of annual GET failure: dependent implementation gate, not an invitation to close Cube 3 from prose alone.
- Calendar edge proposals P1–P3: decide before Slice 1 affected behavior.
- Exact decimal rounding and legal pack applicability: decide/verify before monetary calculation.
- Payroll-only approved-source authority, entitlement-loss closure matrix, and cross-domain lock graph: decide before protected input consumption.
- Payment allocation granularity (whole-run versus employee-level partial payment and identifying who remains unpaid), invalid/excess payment, payment-entry error correction, insufficient deduction capacity and carry-forward disposition: define before corresponding financial workflow; do not invent silent write-offs, refunds, net-negative payout or reordered statutory priorities.
- Run-size transaction/processing strategy and measurable latency budget: choose from representative workload evidence before scale acceptance, without creating a generic job framework prematurely.

All cases in the acceptance matrix below start NOT RUN. Completion requires evidence attached to the final candidate SHA: fresh/upgrade schema parity and retained-data checks; full applicable SQL tests, type/lint/build; genuine authenticated HTTP and race tests; responsive user journeys; exact statutory golden evidence for production claims; and independent review. Record failures and not-run gates honestly. Deployment, remote migration, merge and production release need separate authorization.

## Acceptance matrix


Status: DRAFT. Every case is NOT RUN. Planning baseline `555c34a568f44eb4b99d99712a699094488f3026`; execution evidence must name the actual final candidate SHA, environment, fixture, actor, command and result. Source identifiers refer to the linked governing references above. Suggested roles below are capability holders, not mandatory separate people.

## Evidence contract

For each ID preserve: preconditions and fixture IDs; expected result; actual result; pass/fail/not-run; exact SHA and migration chain; authenticated role/permissions/entitlements; test or browser trace; database assertions; screenshots where layout matters; and remaining limits. Synthetic financial/identity data only. Never include credentials, tokens or real payroll data in repository evidence.

Use unit/property tests for deterministic arithmetic; SQL tests for invariants and permissions; actual authenticated HTTP for transport behavior; independently connected database sessions with observed blocking for races; browser interaction for end-to-end behavior. Source-text tests or fake concurrency alone do not prove financial safety.

## Readiness and calendar

| ID | Scenario | Required observable outcome | Evidence | Gate/source |
|---|---|---|---|---|
| R01 | Cube 3 annual screen loads and completes after selected fixes | GET context succeeds; relevant grant/preview/reload and recovery paths pass on named base; unpublished fix status resolved | Browser + HTTP + regression + SHA | Before dependent build; S5,S11 |
| R02 | Governed execution contract | Accepted decisions identify calendar edges, rounding, source authority, correction and lock graph; no unresolved material assumption hidden in code | Reviewed decision record | Before affected slice; S10,S12 |
| C01 | Unique Employer safe default; two Employers with different cutoffs | Correct Employer scope; no cross-Employer periods; one active calendar per Employer instant | SQL + browser | Slice 1; S3 |
| C02 | Calendar month and 25th cutoff | Expected explicit local dates including 26th previous month to 25th current month; label not used as boundary | Deterministic fixtures + UI | Slice 1; S3 |
| C03 | February, leap year, 30/31-day months and cutoff edge | Follows accepted numbered-cutoff/last-day rule; no implicit/clandestine clamp | Date fixtures + validation UI | Slice 1 decision; S3 |
| C04 | Cutoff change after generated period | Exact old boundaries retained; new sequence contiguous and non-overlapping; explicit transition preview | SQL + browser | Slice 1; S3 |
| C05 | Calendar change with pending Attendance, open run or locked history | Pending Attendance warning shown; open run must complete/cancel; locked history never regenerated; clear recovery action | SQL + HTTP + UI | S3 |
| C06 | Simultaneous calendar saves or period generation | At most one authorized active version/period chain; losing stale intent gets conflict; no gaps/overlap | Two sessions + constraints | Slice 1; S3,S9 |
| C07 | Timezone/payment-rule boundaries | Correct reviewed local dates under accepted rule, including DST if applicable; generated periods unchanged by later configuration | Fixtures + UI | Slice 1 decision; S3 |

## Inputs calculation and statutory verification

| ID | Scenario | Required observable outcome | Evidence | Gate/source |
|---|---|---|---|---|
| I01 | Monthly/daily Payroll with all optional source domains disabled | Payroll can prepare using People/compensation; approved manual daily units work; optional configuration not required | SQL + complete browser path | S2 §§4,23 |
| I02 | Effective compensation, join/end, rehire, overlap eligibility | Correct dated versions/Employees; no duplicate active same-Employer employment; historical context retained | SQL + dated golden fixtures | S2,S8 |
| I03 | People backdate versus locked run | Same-transaction guard/correction requirement; locked result unchanged; user sees owned route | SQL + concurrent HTTP | S1,S8 |
| I04 | Recurring/one-time components and adjustments | Bounded component behavior; draft/approve/applied/cancel semantics; no unsupported expression language; applied item immutable | SQL + UI | S2 §§3,6 |
| I05 | Opening YTD mid-year onboarding | Validated permissioned attributable opening; consumed version frozen; invalid/missing values block actionable calculation | SQL + UI + golden | S2 §17 |
| I06 | Multi-page Time/Leave projections and longer transition | All bounded windows/pages exhausted with no duplicates; exact period/Employment/Employer mapping; no omitted tail | SQL + manifest fixtures | S3,S6 |
| I07 | Approved/pending/cancelled Leave | Pending absent; cancelled approved history keeps stable identity/reversal provenance and zero current units | SQL + source fixtures | S6 |
| I08 | Full Leave, mapped half-day plus absence, observed work | Single coherent monetary exposure; no Time/Leave double deduction; independent work retained; ambiguous reconciliation blocks | SQL + monetary goldens + UI | S6,S7 |
| I09 | Source mutation between pages/preview and calculation/lock | Insert/delete/successor/cancellation detected through current manifest/version validation; stale candidate refused | Coordinated sessions + HTTP | S6,S9 |
| I10 | Source-domain permission versus payroll permission | Only reviewed narrow source-consumption authority succeeds; no general People/Leave disclosure; history reads remain bounded | Negative SQL + raw API | S6,S9 |
| M01 | Monthly fixed-30 and calendar-days proration | Exact accepted denominator and effective compensation semantics; deterministic totals | Golden fixtures + line explanation | S2 §4 |
| M02 | Short/long transition across months and salary changes | Per-covered-local-date S3 amounts summed then rounded as defined; explicit approved adjustment visible | Golden fixtures + UI | S3 |
| M03 | Identical frozen inputs and money rounding edges | Bitwise/canonical identical monetary output; no binary float drift; component/net totals reconcile | Unit/property + SQL | S2 §19 |
| M04 | Missing/unverified statutory pack | Real calculation/approval/lock blocked; clear compliance/setup handoff; test fixtures not called live qualification | SQL + UI | S2 §16 |
| M05 | Statutory official-source golden set | Applicable effective pack matches official/reviewed model for income bands, YTD, insurance boundaries, taxability, ceilings, overtime/rest/holiday, correction, rounding | Versioned source records + independent reviewed calculations | Production statutory gate; S2 §§8,16–17 |
| M07 | Non-calendar period crossing tax-year or rule-effective boundary | Applicable year, pack and YTD follow verified legal treatment, not period label or guessed date split | Official-source golden + line explanation | S2 §§16–17,S3 |
| M06 | Exception/variance review | Clean bulk review possible; blockers never hidden by thresholds; affected Employee and corrective action visible | Browser + fixtures | S2 §11 |

## Lifecycle concurrency and ledger closure

| ID | Scenario | Required observable outcome | Evidence | Gate/source |
|---|---|---|---|---|
| L01 | Draft → calculate → review → approve → lock | Separate explicit actions and permissions; exact approved fingerprint locked with full context and audit | SQL + real Auth/HTTP + UI | S2 §§9–10 |
| L02 | Change source/config after calculation or approval | Candidate stale; approve/lock denied; approved requires explicit return to draft; recalc creates reviewable new candidate | SQL + HTTP + UI | S2 §§9–10 |
| L03 | Cancel draft/review and retry request | Terminal cancelled state with retained history; no stranded consumption/finance movement | SQL + UI | S2 §9 |
| L04 | Simultaneous locks or authoritative runs | One authoritative run chain, one consumption per source target; no duplicate money/audit/receipt | Two sessions with blocking evidence | S2,S6,S9 |
| L05 | People/source writer versus Payroll writer | Both lock acquisition orders exercised; stale case fails/reviews, fresh case commits; no deadlock from reversed domain edges | Actual concurrent sessions, pg lock evidence | G3/G4; S6–S9 |
| L06 | Same attempt and altered attempt payload | Same key/same intent replays authorized outcome; changed intent conflicts; no extra ledger | HTTP + SQL counts | Proposed receipt protocol; S9 |
| L07 | Response lost after committed lock/payment | Reload/retry finds durable outcome; no second lock, installment or payment | Fault injection + browser + SQL counts | S11 |
| L08 | Mandatory audit insertion fails | All related financial mutation/consumption rolls back; no acknowledged success | SQL fault fixture + HTTP | S9 |
| L09 | Concurrent authority or entitlement loss | Authority rechecked under protected commit; stale UI cannot succeed; no normal access for suspended/archived tenant | SQL + raw API + race | S9 |
| L10 | Lock then input/compensation/policy changes | Locked values/version evidence unchanged; linked correction responsibility visible | SQL snapshots + UI | S2,S8 |
| P01 | Record partial then full external payment | Paid + remaining reconcile to locked obligation; correct statuses and refs; no bank transfer implied | SQL + UI | S2 §13 |
| P02 | Duplicate/invalid/excess/error payment entry | Duplicate replay safe; accepted invalid/excess policy enforced; error correction attributable without erasing history | SQL + UI + retry | Decision before Slice 5; S2 §§12–13 |
| X01 | Locked unpaid amendment | Original remains authoritative until replacement approves/locks; then superseded; historical output retained, distribution clearly invalidated | SQL + full UI | S2 §§12,14 |
| X02 | Partial/paid correction | Amendment replacement denied; next-open adjustment or approved external settlement reconciles paid, remaining and compensation | SQL + full UI | S2 §12 |
| X03 | Payment versus amendment lock race | Exactly one lawful route wins; no replacement once payment recorded; no payment twice | Two sessions in both orders | S2 §12 |
| X04 | Correction targeted to missing/closed period | Visible owned blocker or explicit permitted settlement; no orphan/vanished correction | SQL + UI | S2 §§12,22 |
| X05 | End employment/final period | Partial pay, due adjustments/finance, final marking and unsupported termination manual handoff have reachable outcomes | SQL + full UI | S2 §18 |
| F01 | Advance draft → active → deductions → settled | Disbursement explicitly external; deterministic schedule; exactly-once movement; settled only at reconciled zero | SQL + UI | S2 §7 |
| F02 | Advance cancel/manual early settlement/correction | Cancellation only before responsibility; compensating/reversal entries; balances reconcile, no naked editable balance | SQL + UI | S2 §7 |
| F03 | Insufficient pay/deduction statutory ceiling | Accepted verified legal priority/ceiling enforced; unapplied obligation visible under approved carry-forward/disposition rule | Golden + SQL + UI | Decision/statutory gate; S2 §8 |

## Security outputs experience and release

| ID | Scenario | Required observable outcome | Evidence | Gate/source |
|---|---|---|---|---|
| A01 | Other Tenant/Employer, anonymous, inactive membership, each missing permission | Denied without leaking payroll/compensation; no alternate direct table/API bypass | SQL grants/RLS + actual API | S9 |
| A02 | Payroll entitlement loss with history and obligations | New work blocked; reviewed historical export/correction/closure matrix works only with active tenant/actor authority | SQL + UI | S2 §22,S9 |
| O01 | Payslip/export before lock or missing legal identity | Blocked with actionable next step; locked output uses snapshotted Employer identity and values | SQL + file assertions + UI | S2 §§14–15,S4 |
| O02 | Reports across Employer, period, amendment and payment status | Totals equal authoritative ledger/run; superseded records identifiable; filters/export remain scoped | Report reconciliation + permissions | S2 §15 |
| U01 | Normal Arabic setup/run/payment/correction at 390/820/1280 | Complete task, readable dates/EGP/bidi, no clipped primary action or horizontal overflow; phone task layout usable | Actual browser journey + screenshots | S1,S10–11 |
| U02 | Keyboard, focus, touch, zoom/reflow, status/error labels | Logical focus, return after dismissal, programmatic labels/errors, non-color-only state, reachable actions | Browser accessibility review | S10–11 |
| U03 | Loading/empty/validation/stale/failure/success/denial | Clear next action, inputs retained, old preview confirmation cleared, no unexplained dead end or technical IDs | Browser state matrix | S10–11 |
| U04 | Back/Forward, cancel, repeated clicks, reload, response drop | Correct screen/history and durable state; no unintended command or duplicate money | Browser fault/retry journey + SQL | S11 |
| Q01 | Fresh migrations and retained-data upgrade | Same final schema/function ACLs; retained source data intact; full applicable regression passes | Independent databases + parity artifacts | S11 |
| Q02 | Final code static checks and build | Typecheck/lint/production build/full tests pass on exact final candidate; later edits rerun affected evidence | Command logs + SHA | S11 |
| Q03 | Representative payroll volume and concurrent activity | Reviewed latency/capacity budget satisfied; bounded pages and no giant unbounded UI payload; no false fleet-scale claim | Measured workload + concurrency logs | Scale decision; S11 |
| Q04 | Independent review and release gates | Product/security/financial review complete; legal/operational/pilot gaps explicit; no automatic production readiness from cube label | Review record + gate register | S1,S11 |

## Additional experience acceptance cases

| ID | Scenario | Required observable outcome | Evidence | Gate/source |
|---|---|---|---|---|
| U05 | First run, no comparable period, unequal transition | Honest comparison unavailable/explained; no fabricated zero variance | Browser + fixtures | S2 §11 |
| U06 | Bulk selection, filtered approval, partial action failure | Visible/all-matching scope explicit; whole Employer totals retained; exclusions and failed-only retry clear | Browser + SQL | S2 §§11,20 |
| U07 | Source unavailable or not checked; unknown YTD | No false ready/zero values; retry or responsible-role route; review-only warnings separate from blockers | Browser + HTTP faults | S2 §§11,17 |
| U08 | Session/permission loss and Tenant/Employer switch | Confirmation invalidated; sensitive cache/draft/selection cleared or protected; no cross-scope flash | Browser + authorization faults | S9 |
| U09 | Protected file retrieval and stale output | Access revalidated; superseded output marked; no public payroll URLs or sensitive log payloads | API + export inspection | S2 §§14–15,S9 |
| U10 | Phone keyboard, long Arabic and extreme values | Amount/confirmation not obscured; readable reflow/bidi and focus; no lost task state | Real browser viewport/keyboard checks | S10–11 |

## Prioritized race fixtures

Run with two independent authenticated actors/connections and observe real blocking. Cover source-first and payroll-first orders for employment end, backdated compensation, Time fact successor, Leave cancellation/replacement, a new approved input appearing after a paginated preview, configuration change, second payroll lock, entitlement revocation, and payment versus amendment. After each, assert exact run, ledger, audit and receipt counts and unchanged historical snapshots. Deadlock retry must never duplicate financial effects.

## Completion reporting

Report passed, failed and not-run separately. Link exact evidence for each critical ID; do not turn this checklist into a claim that tests exist. Slice 1 completion means usable setup/period readiness only. Full Cube 4 completion requires the entire applicable matrix, complete correction/payment/finance/reporting flows, and reviewable responsive evidence. Production statutory, operational, security and pilot qualification remain separately named release gates.
