# Employee Finance & Payroll Specification

## Status

**Frozen — final documentation alignment approved 2026-09-29.**

This specification governs Wave 4 — Employee Finance & Payroll Core. It freezes the end-to-end financial workflow required for the first commercially coherent HR release while keeping mutable Egyptian statutory values versioned rather than hard-coded into product logic.

## Governing inputs

- Accepted Product Charter, Product Principles, Master Product Blueprint and V1 Capability Decomposition.
- Frozen Platform Foundation and Accepted ADR-001 through ADR-010.
- HR People & Work Context and Attendance & Leave Specifications.
- DEC-004, DEC-012, DEC-015 and DEC-016.
- Financial correctness, Security, Privacy, UX, Definition of Ready and Definition of Done baselines.
- Official Egyptian statutory sources are external authority for legal numeric/rule data; the product stores effective-dated verified rule packs so later legal changes do not rewrite history.

## Outcome

An authorized payroll team can maintain bounded compensation components and employee-finance obligations, prepare a monthly payroll, consume approved inputs from enabled HR domains, calculate Egyptian statutory effects deterministically, review exceptions/variance, approve and lock the result, produce payslips/exports, record payment status and correct mistakes without mutating finalized history.

## Scope

This specification covers:

- HRF-001 penalties/deduction adjustments.
- HRF-002 rewards/bonus adjustments.
- HRF-003 employee advances/loans.
- HRF-004 installment schedules/payroll deductions.
- HRF-005 manual settlement/correction.
- HRPY-001 payroll configuration/salary components.
- HRPY-002 Egypt statutory rule set.
- HRPY-003 payroll run.
- HRPY-004 approved input contract.
- HRPY-005 draft/review/approve/lock.
- HRPY-006 frozen calculation context/reproducibility.
- HRPY-007 post-lock correction.
- HRPY-008 payslip.
- HRPY-009 payroll export.
- HRPY-010 payment status.
- core reconciliation and variance reports.

## Explicit non-goals

V1 does not build:

- full accounting/GL/treasury;
- bank payment execution;
- unrestricted payroll formula scripting;
- multi-country payroll;
- generic workflow/BPM;
- unlimited component dependencies;
- full final-settlement/termination-benefit automation for every legal/employer case;
- off-cycle/supplementary payroll unless separately added;
- a tax-law authoring UI for ordinary tenant users.

## 1. Financial model principles

1. Money uses exact decimal semantics; floating-point arithmetic is prohibited for authoritative calculations.
2. Every financial effect is attributable to an Employee, period, source/reason and actor/system source.
3. Current configuration cannot silently rewrite a locked historical result.
4. Domain inputs are consumed through explicit approved contracts, not ad-hoc reads that make Payroll depend on another module's tables.
5. Financial correction is additive/amending, never hidden mutation of finalized history.
6. The product presents payroll as an operational checklist and exception-review job; internal rule graphs, version IDs and transaction mechanics are not normal UI concepts.

## 2. Payroll period and run boundary

V1 payroll frequency is **monthly**.

A Payroll Period is identified by:

- immutable period identity;
- Tenant and Employer Legal Entity;
- the effective Employer-scoped Payroll Calendar version;
- immutable local start/end dates and a human-readable business label;
- status.

A Payroll Run belongs to exactly one Employer + Payroll Period.

Rules:

- generated periods for one Employer cannot overlap or leave a gap while its Payroll Calendar is active;
- a business label or calendar year/month is not the period's authoritative date boundary;
- one active authoritative run chain per Employer + Period;
- Site/Department may be filters/reporting dimensions, not separate payroll legal authority;
- a run includes Employees whose Employment/payroll eligibility overlaps the period under the effective configuration;
- daily-pay Employees are supported alongside monthly-pay Employees;
- off-cycle runs are deferred; a post-lock correction uses the explicit correction/amendment paths below.

## 3. Salary components

Payroll owns a bounded component catalog.

V1 component families:

- base pay;
- recurring earning/allowance;
- recurring deduction;
- one-time earning;
- one-time deduction;
- attendance-derived earning/deduction;
- employee-finance installment/adjustment;
- employee statutory deduction;
- employer statutory contribution;
- tax.

A component defines only bounded behavior needed by V1:

- stable key/name;
- earning/deduction/employer-cost classification;
- taxable treatment;
- social-insurance treatment where applicable;
- fixed amount or percentage of a defined supported base;
- recurring or period-input behavior;
- display/order/payslip visibility;
- active/effective dates.

No arbitrary user-authored expression language is permitted in V1.

### Recurring employee compensation

Recurring components assigned to an Employee are effective-dated.

A change effective in the future supersedes prior configuration prospectively. A change that reaches a locked period creates a correction requirement and does not rewrite the locked calculation.

## 4. Monthly and daily pay

### Monthly pay

Monthly base compensation is the effective monthly salary.

For join/end or unpaid portions of a month, the Tenant Payroll Policy chooses one bounded proration mode:

- `fixed_30_day`;
- `calendar_days`.

The selected mode is configured once in Payroll setup and is not re-asked on each run.

### Daily pay

Daily base compensation uses the effective daily rate multiplied by approved payable work/leave units available to Payroll.

When Attendance is not entitled/enabled, authorized Payroll input/manual approved work units provide the quantity.

No Payroll implementation may make Attendance a mandatory dependency.

## 5. Attendance/Leave/Finance approved input contract

An approved Payroll Input contains:

- Tenant;
- Employee/Employment;
- target Payroll Period;
- input kind;
- quantity and unit or money amount as applicable;
- source domain;
- stable source reference;
- source version;
- approval/finalization metadata;
- effective policy/configuration reference;
- correction/supersession link where applicable.

Examples:

- approved overtime minutes with daytime/nighttime/weekly-rest/official-holiday category where applicable;
- unpaid absence days;
- late minutes;
- unpaid leave units;
- bonus/deduction adjustment;
- due advance installment.

Rules:

- source references are idempotent;
- Payroll snapshots consumed input versions at calculation/lock;
- a source correction before lock marks the run stale/recalculation-required;
- a source correction after lock creates a Payroll correction requirement and cannot mutate the locked run.

## 6. Employee financial adjustments

### Penalty/deduction and reward/bonus

A one-time financial adjustment contains:

- Employee;
- type/component;
- amount;
- target effective Payroll Period;
- reason;
- optional supporting reference;
- status;
- actor/approval evidence.

Lifecycle:

`draft -> approved -> applied | cancelled`

Once applied to a locked Payroll, the original adjustment is immutable. Correction is a compensating adjustment linked to the original.

Attendance may provide evidence/quantity, but it may not silently create an irreversible cash deduction without the configured approved input/financial rule boundary.

## 7. Advances / loans

V1 supports a bounded employee advance/loan subledger.

Required facts:

- Employee;
- principal;
- start/effective date;
- external disbursement reference/status;
- installment amount or installment count;
- first deduction period;
- outstanding balance;
- status.

Supported lifecycle:

`draft -> active -> settled`

with `cancelled` allowed before activation/disbursement responsibility exists.

Rules:

- actual cash disbursement may occur outside the platform and is recorded as an explicit external handoff/reference;
- installment schedule is deterministic;
- each payroll deduction creates/references a ledger movement;
- outstanding balance is derived/reconcilable, not an editable naked number;
- early/manual settlement creates a settlement ledger entry;
- corrections create reversing/compensating entries;
- an Employee cannot be “settled” while a non-zero unexplained balance remains.

## 8. Egypt employment-law deduction safeguards

Employee Finance and Payroll must not treat tenant configuration as permission to violate an applicable statutory deduction floor/ceiling.

For the initial standard private-sector Egypt compliance pack, Labour Law No. 14 of 2025 is a governing source:
https://portal.eta.gov.eg/sites/default/files/2026-03/law.no_.14.of_.2025.pdf

The rule pack must model, where applicable to the Employee/case:

- Article 113 employer-loan recovery limit: no more than 10% of the worker's wage may be deducted to repay money lent by the employer during the employment contract, and the employer may not charge interest on that loan;
- Article 114 general wage assignment/attachment/deduction ceiling: ordinarily no more than 25% of the relevant wage base, with the statutory higher ceiling for alimony and the statutory precedence/calculation basis;
- Article 115 requirement that the employer provide a statement of wage details, which the Payroll payslip/output must be capable of satisfying operationally;
- overtime/rest-day/official-holiday valuation must consume the approved Time classification and the active verified Labour-Law rule pack; a tenant policy may be more favorable where permitted but may not silently configure a lower mandatory statutory value.

Because legal applicability can vary by worker/category and later amendments, these are effective-dated compliance rules with source/version metadata, not UI constants. Where a statutory classification exception applies, it must be explicit and authorized.

## 9. Payroll run state machine

Business-facing states:

1. `draft` — setup/inputs may still change; recalculation allowed.
2. `review` — calculation candidate exists; exceptions/variance are reviewed.
3. `approved` — an authorized approver accepts the reviewed candidate; configuration/input mutations that would change the result require returning to draft through an explicit action before lock.
4. `locked` — finalized immutable payroll result.
5. `superseded` — a locked-but-unpaid run replaced through a controlled Amendment Run; history retained.

A draft/review run may be `cancelled` explicitly.

### Lock invariant

Lock persists a frozen calculation context sufficient to explain/reproduce:

- Employee/Employment/compensation version;
- recurring component versions;
- approved Payroll Input versions;
- statutory rule-pack version;
- Payroll Policy version;
- calculation engine/version identifier where material;
- line-item results and totals;
- actor/time/approval evidence.

A locked run is never reopened and rewritten in place.

## 10. Calculation lifecycle

Normal user flow:

`Prepare payroll -> Calculate -> Review issues & variance -> Approve -> Lock -> Payslips/Export -> Record payment status`

The UI need not expose technical labels where simpler business wording communicates the same state.

### Stale run detection

If an input/configuration that affects an unlocked calculated run changes:

- the system marks the run as requiring recalculation;
- approval/lock is blocked until recalculated;
- the user sees the specific affected reason, not an opaque “version conflict”.

## 11. Review and variance

The review surface must prioritize what needs human attention.

At minimum it shows:

- employee count;
- gross/net totals;
- statutory deductions/contributions;
- new/changed employees;
- unusually large changes from prior comparable period;
- missing required payroll setup;
- unresolved source/correction issues;
- negative/net anomalies;
- employee-finance balance conflicts.

A configurable materiality threshold may reduce noise, but it must not hide blocking errors.

The system must not require the user to open every Employee when the run is clean.

## 12. Post-lock correction

Locked history is immutable.

### Locked but not paid

If a material error is discovered before payment is recorded:

- an authorized user creates an **Amendment Run** referencing the locked original;
- the original remains immutable and becomes `superseded` only after the replacement Amendment Run is approved+locked;
- the amendment contains the changed inputs/context and complete new payable result;
- audit clearly links original and replacement.

### Any payment recorded or externally settled

If any payment amount has been recorded, including a `partially_paid` run:

- correction becomes a linked positive/negative Payroll Adjustment targeted to the next open Payroll Period by default;
- the original locked payable and its payment ledger remain unchanged; a replacement Amendment Run is not used after payment starts;
- a separately approved external settlement may be recorded when next-period carry-forward is not appropriate.
- the correction record reconciles the amount already paid, the remaining original obligation, and the compensating amount or external settlement. No paid amount is silently paid again or erased.

No “unlock payroll” button exists in V1.

## 13. Payment status and external handoff

V1 does not execute bank payment.

After lock, payment tracking supports:

- `unpaid`;
- `partially_paid`;
- `paid`.

Payment recording may include:

- paid amount;
- payment date;
- external bank/cash/reference note;
- actor.

The payment ledger/status must reconcile to the locked payable amount. Corrections after any recorded payment, including partial payment, follow the correction rules above.

Accounting/GL posting remains an explicit export/external handoff.

## 14. Payslip

Payslip is generated from a locked authoritative run/amendment only.

It must show in understandable employee terms:

- period;
- base/earnings;
- deductions;
- statutory deductions;
- net pay;
- relevant approved adjustments;
- employer/display identity.

Technical rule IDs and internal database identifiers are not shown.

If a run is superseded before payment, the old payslip is visibly superseded/invalidated for ordinary distribution while remaining historically retained under authorized access.

## 15. Payroll export and reporting

V1 supports:

- payroll sheet export;
- employee payslip;
- component/totals summary;
- tax/social-insurance calculation/reconciliation data required for operation;
- employee-finance outstanding balances;
- period variance report;
- payment-status report.

Exports are Tenant/Employer scoped, permission-protected and generated from authoritative run versions.

## 16. Egyptian statutory rule packs

### Architecture

Egyptian tax/social-insurance rules are implemented as **effective-dated, versioned statutory rule packs owned by Payroll/Compliance**.

A rule pack records:

- jurisdiction = Egypt;
- rule family/version;
- effective period;
- authoritative source references;
- verified numeric tables/constants;
- deterministic rounding rules;
- provenance/review metadata.

Numeric legal constants are data/versioned configuration, not scattered application constants.

Finalized Payroll stores the exact rule-pack version used.

### Initial production qualification source

Before production payroll is claimed for a period, the active rule pack must be verified against the official source valid for that period.

For the 2026 private-sector baseline, official current sources reviewed on 2026-09-28 include:

- Egyptian Tax Authority 2026 private-sector monthly payroll calculation model and payroll guidance: https://eta.gov.eg/ar/payroll-forms
- Egyptian Tax Authority current payroll FAQ/calculation guidance: https://eta.gov.eg/ar/alasylt-alshayt
- National Organization for Social Insurance 2026 contributory-wage limits notice: https://www.nosi.gov.eg/ar/News/Pages/2025-11-30.aspx
- Social Insurance and Pensions Law No. 148 of 2019 and its implementing rules: https://www.nosi.gov.eg/ar/Lists/NOSILibrary/2-12-2019%20%D9%83%D8%AA%D8%A7%D8%A8%20%D8%A7%D9%84%D9%82%D8%A7%D9%86%D9%88%D9%86%20%D8%A7%D9%84%D8%AC%D8%AF%D9%8A%D8%AF.pdf
- Labour Law No. 14 of 2025, effective 2025-09-01, for applicable employment/work-time statutory constraints.

Current official ETA guidance states a 20,000 EGP annual personal exemption and a 40,000 EGP zero-rate annual bracket before the subsequent rates. The 2026 NOSI notice states contributory-wage limits of 2,700 EGP minimum and 16,700 EGP maximum effective 2026-01-01.

These numbers are **verification anchors, not immortal code constants**. A later official change creates a new effective rule-pack version.

### Golden statutory tests

Production qualification requires representative golden scenarios compared to the official calculation source/model for the applicable year, including:

- low/medium/high taxable income;
- mid-year join;
- cumulative/YTD calculation;
- social-insurance min/max boundaries;
- taxable/non-taxable component combinations;
- correction after prior-period withholding;
- rounding boundaries.

If the official source and a product rule pack disagree, Payroll fails qualification; the test is not weakened.

## 17. YTD and mid-year onboarding

Payroll must support opening year-to-date values when a Tenant starts using the system after the tax year has begun.

Opening balances may include, as required by the active statutory pack:

- prior taxable earnings;
- prior payroll tax withheld;
- prior statutory bases/contributions;
- other cumulative values required for correct annualized/cumulative calculation.

Opening YTD values:

- require permission;
- are validated;
- are audit-attributable;
- are frozen into downstream run context once consumed.

This avoids producing incorrect tax merely because the SaaS was adopted mid-year.

## 18. Termination/final-period boundary

Ending Employment must not create a dead end.

V1 supports:

- normal partial-period pay according to Payroll Policy;
- outstanding approved earnings/deductions;
- due employee-finance balances/settlement action;
- final-period marking/reporting;
- explicit manual approved component/adjustment for a termination amount that is legally/contractually required but outside automated V1 coverage.

Specialized termination-benefit formulas not yet supported must be an explicit governed external/manual handoff, never a hidden omission.

## 19. Rounding and determinism

- ordinary monetary components use the application's defined decimal rounding contract;
- statutory calculations follow the active official rule-pack rounding semantics;
- no binary floating-point arithmetic is used for authoritative money;
- repeated calculation from identical frozen inputs/rules yields identical results;
- the calculation output includes enough line-level explanation to trace net pay.

## 20. Operational simplicity / UX contract

Payroll must hide backend complexity without hiding material consequences.

Required experience:

- first screen answers: “Is payroll ready?”, “What needs attention?”, “What changed?”, “What is the next action?”;
- ordinary run uses a short guided sequence: Prepare → Review → Approve → Lock;
- policy/component setup is separate from the monthly run;
- sensible defaults and prior-period continuity prevent repetitive setup;
- advanced tax/rule versions are visible to authorized experts under details, not forced on every operator;
- errors use employee/business language and point to the fix;
- calculations are explainable on demand, but raw rule-engine internals are not the default view;
- approval/lock confirmations show totals and irreversible consequence clearly;
- bulk resolution is offered where one safe action applies to many records;
- filters/search are compact, collapsible and fast.

Simplicity may never weaken approval, authorization, audit or historical correctness.

## 21. Permissions and separation of duties

Permission families include at least:

- payroll.view;
- payroll.prepare;
- payroll.review;
- payroll.approve;
- payroll.lock;
- payroll.correct;
- payroll.export;
- payroll.payment_record;
- payroll_config.manage;
- employee_finance.view;
- employee_finance.manage;
- employee_finance.approve;
- statutory_rules.manage (Platform/authorized compliance role only by default).

A Tenant may allow one person to hold multiple permissions in a small organization; the architecture must not require enterprise segregation. Sensitive actions remain explicit and audited.

## 22. Workflow Completion Maps

### Normal payroll

`open period -> draft/prepare -> calculate -> review -> approve -> lock -> payslip/export -> payment status`

### Pre-lock issue

`draft/review -> blocking issue -> fix source/config -> recalculate -> review`

### Locked unpaid correction

`locked unpaid -> amendment -> review/approve/lock amendment -> original superseded -> payment`

### Paid correction

`paid locked run -> linked correction -> next open period adjustment OR explicit external settlement -> reconciled`

### Advance

`draft -> active/disbursed external reference -> scheduled deductions/settlements -> zero balance -> settled`

### Entitlement loss

Payroll entitlement loss never deletes locked results. New run operations are blocked, while historical view/export and required correction/closure behavior follows the governed capability policy.

## 23. Acceptance criteria

The Spec is satisfied only when:

- Payroll runs without Attendance/Leave/Employee Finance entitlements;
- monthly and daily Employees calculate under the defined bounded models;
- approved inputs are versioned/idempotent;
- locked history is immutable and reproducible;
- source/config changes mark unlocked runs stale;
- post-lock amendment/correction paths are complete;
- a partial payment prevents replacement of the locked payable, and its linked correction reconciles paid and remaining amounts;
- advances/installments reconcile to zero or an explicit outstanding balance;
- payment status has an explicit external handoff;
- YTD opening values support mid-year onboarding;
- current Egypt rule pack is qualified against official sources with golden tests;
- cross-Tenant/permission negative tests pass;
- payroll workflow satisfies the operational-simplicity contract on representative desktop/mobile views.

## 24. Deferred maturity

Later specifications may add:

- off-cycle/supplementary payroll;
- richer retroactive recalculation;
- bank payment files/integration;
- accounting/GL adapters;
- deeper statutory filing automation;
- richer termination/final-settlement automation;
- delegated/multi-level payroll approvals;
- multi-country rule packs.

## Accepted operational clarification — 2026-10-02

The [Cube 4 operational policy amendment](cube-4-operational-policy-amendment-2026-10-02.md) governs the named ordinary rounding, payment allocation/error/excess, insufficient-capacity and calendar details. Statutory qualification and all other Frozen requirements remain binding.

The owner accepted [ordinary Payroll Period salary and proration semantics](payroll-ordinary-period-proration-amendment-2026-10-02.md) on 2026-10-02 as an additive amendment to §4. The Frozen body above is retained; unresolved `fixed_30_day` ordinary calculation semantics remain an explicit calculation gate.

The owner accepted [fixed-30 ordinary proration](payroll-fixed30-proration-amendment-2026-10-02.md) and [recurring component proration](payroll-recurring-proration-amendment-2026-10-02.md) on 2026-10-02. These additive amendments resolve the stated operational formula gates and preserve the Frozen body and statutory verification boundary.
