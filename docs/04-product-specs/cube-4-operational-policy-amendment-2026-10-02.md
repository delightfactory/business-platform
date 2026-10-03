# Cube 4 operational policy amendment

Status: **Accepted by the product owner in the implementation conversation, 2026-10-02.** Local documentation only; no publication or production qualification implied.

The owner explicitly approved all eight recommendations presented for the pending Payroll decisions and instructed implementation to resume. This amendment records those recommendations before dependent code. It amends the named sections of the Frozen [Employee Finance and Payroll specification](employee-finance-payroll-spec.md) and accepted [Payroll calendar amendment](payroll-calendar-and-cutoff-amendment.md); all other governing requirements remain in force. It does not approve legal rates.

The owner subsequently directed the team to stop investigating/repairing Cube 3 now and focus on Cube 4. This supersedes the extension's requirement to hold all Cube 4 development on locating the original annual GET failure/copy fix. Proceed on the selected locally revalidated base with the recorded limitation; do not claim the old failure repaired or alter Cube 3. Source consumption, People guards, financial freshness and later qualification remain mandatory for the affected slices.

## 1. Shorter-month cutoff — calendar amendment, cutoff model

Numbered cutoff days 1–31 are supported. When the configured day exceeds the number of days in the target month, the effective cutoff is that month's final local civil date. Last-day-of-month remains an explicit configuration choice. The next period begins the day after the previous period ends; display actual dates in preview. A 25–24 cycle uses cutoff 24, distinct from cutoff 25's 26–25 cycle. Preserve historical generated periods and explicit reviewed transitions when configuration changes.

## 2. Payment schedule — Payroll specification §13 and calendar payment rule

The administrator chooses a numbered payment day 1–31 in the period-ending month or following month. Apply the same shorter-month treatment. The resulting scheduled payment date must be on or after the period end. Invalid dates/rule combinations are refused with retained input and an actionable preview. Do not automatically shift dates for weekends or holidays without a separately approved calendar/rule. This is an operational scheduled date, not bank execution or a legal due-date qualification.

## 3. Timezone — calendar timezone context

Default to `Africa/Cairo` for the initial Egypt product. Store an explicit Employer payroll timezone with each effective calendar version and generated period. Timezone changes apply prospectively and cannot reinterpret existing generated civil-date boundaries. Preview and validate boundaries in that timezone. DST does not justify treating UTC midnight as the Employer's civil-date boundary.

## 4. Ordinary monetary rounding — Payroll specification §19

Use exact decimal arithmetic. Sum unrounded dated parts of an ordinary component before rounding that component once to two EGP fractional digits. Use decimal half-up rounding; an exact half rounds away from zero. Compute displayed reconciled totals from the rounded ordinary components. Statutory components follow their verified pack's mandated semantics. This decision does not override S3 transition arithmetic, invent full-period proration or authorize guessed taxes/insurance rates.

## 5. Payment allocation — Payroll specification §13

Record partial payments against identified Employees and their exact paid amounts. Do not allocate an arbitrary whole-run partial amount automatically. A whole-run full payment may be recorded in one action with explicit full remaining Employee allocations. Employer-wide paid/remaining totals must reconcile to those allocations and the locked obligation. Recording remains an attribution of payment made externally.

## 6. Excess payments — Payroll specification §13

Refuse non-positive new payment entries and entries exceeding the applicable outstanding payable/Employee remaining allocation. Expose an owned documented reconciliation/settlement route for an actual excess payment; do not invent automatic refunds, deductions or write-offs. A rejected entry has no financial/audit-success effect.

## 7. Mistaken payment record — Payroll specification §§12–13

Use a linked attributable compensating record with explicit reason and correction authority; retain the original payment and audit history. Correction records do not execute a bank reversal. Once any payment has been recorded, later compensation that reduces recorded net paid to zero does not restore amendment-replacement eligibility. Correction remains linked to the immutable original run and its payment history.

## 8. Insufficient deduction capacity — Payroll specification §§7–8,12,18

Keep unapplied installments/deductions as visible outstanding obligations and carry them forward under the approved disposition. Do not silently waive them or add automatic interest. Do not create a negative payout by exceeding verified deduction constraints. If employment ends or no usable next period exists, provide an attributable reviewed settlement path rather than losing the obligation. Statutory priority/ceiling requires independent verified legal evidence.

## Decision and qualification boundary

These accepted operational choices resolve the presented calendar, rounding and payment/insufficient-capacity policy recommendations. Technical source-consumption authority, compatible locks, entitlement-loss command enforcement and workload strategy remain engineering/security work within the Frozen contract. Actual statutory applicability/rates, pack verification and legal golden tests remain a separate release gate. The original reported annual GET scenario/copy-fix provenance remains an engineering prerequisite to qualify; approval of these choices does not assert that defect was repaired.

Acceptance evidence must include short-month/leap-year transitions, a 25–24 cycle, rejected pre-end scheduled payment, prospective timezone changes, rounding boundaries, per-Employee partial/full reconciliation, excess refusal, compensating-payment history and insufficient-capacity closure. Existing 64-row acceptance coverage remains binding. No Cube 4 completion is claimed.
