# Cube 3 — annual entitlement calculation evidence

Verified 2026-10-01. Applies to the initial Egypt private-sector policy research; not a legal opinion or production statutory qualification. DEC-023 remains in force.

## Primary evidence

[Law 14/2025, official Gazette copy hosted by the Egyptian Tax Authority](https://portal.eta.gov.eg/sites/default/files/2026-03/law.no_.14.of_.2025.pdf): Article 2 on zero-based PDF page 9, Article 6 on page 10, Article 124 on page 52 and Article 125 on page 53. Page references identify the PDF page index, not the printed Gazette number.

| Subject | Verified rule | Implementation consequence |
|---|---|---|
| Time units, Article 2 | Default year 365 days, month 30 days, unless otherwise agreed | Relevant to an explicit calculation policy; distinct from the configured balance year |
| Annual entitlement, Article 124 | 15/21 days by service year, 30 after qualifying service or age over 50, 45 for covered categories; covered work may add seven days | Effective eligibility evidence is required; no classification inferred from a branch name |
| Short service, Article 124 | Proportional entitlement below one year after at least six months | Exact fractional rounding and mid-period category treatment are not specified here |
| Requested days, Article 124 | Official holidays and weekly rest excluded | Annual type uses working-day counting; other legal types need their own configured rule |
| Preservation/use, Article 125 | Scheduling/use and periodic settlement obligations, with protected-category restrictions | No automatic balance deletion; preservation does not remove the employer's obligations |
| Worker protection, Article 6 | Statutory minima and more favourable benefits protected | Technical rounding must not silently reduce rights |

The complete coverage schedules for implementing decrees must be qualified before automatic job/site classification. A Ministry announcement proving issuance alone does not qualify every category.

## Accepted V1 employer calculation policy

The official text establishes entitlement and time-unit rules, but does not supply a complete numerical fractional-accrual algorithm. On 2026-10-01 the user accepted the following employer-policy calculation and authorized bounded per-company settings when they do not introduce a rules engine. This is an **accepted employer policy, not a statutory formula inferred from the law**:

- Keep the company's explicitly configured balance year separate from service-year eligibility. Recommend January–December as an understandable administrative default, configurable before account periods are created; do not impose it as law.
- Segment service by dated, HR-verified entitlement changes. Calculate each segment using actual covered service days / 365 and its applicable annual rate. Under the default Article 2 convention, the six-month threshold corresponds to 180 days; a contrary applicable agreement requires qualification.
- Sum the exact segment numerators before dividing once by the common year basis. Round cumulative entitlement upwards to 0.01 day, then subtract the previously granted cumulative amount. Request increments remain independent: a permitted half-day consumes 0.5 day.
- One base grant per Employer + Employee + Type + period. Subsequent changes append an attributable difference against that same account; they cannot create another base grant or erase earlier consumption.
- Carry the remaining balance with its source account and evidence. Do not expire it automatically or claim that settlement obligations have been discharged.

Qualified arithmetic targets: `15 × 180 / 365 = 7.397260… → 7.40`; `21 × 90 / 365 = 5.178082… → 5.18`. Calculations accrue actual calendar service days, including the first qualifying service segment when the threshold is reached; requested annual leave still excludes rest/holidays. Future service is never granted. Employee eligibility/source must be verified by HR.

Company settings are scoped to Tenant + Employer + Leave Type, append immutable versions and default to 15/21 days, 180-day eligibility and a 365-day basis. Bounds allow more favourable company benefits: rates at least 15/21, eligibility no later than 180 days, and a 360–365-day basis. Cumulative rounding remains upwards to 0.01 day. Special-category changes use dated HR-verified rates and documentary references; no age/disability/job classification is inferred or added to People.

Each reviewed calculation records its service dates, policy version, rates and sources. One base annual grant is followed by cumulative differences, without erasing consumption or earlier grants. An account with a manual opening/annual grant remains in manual mode for that period; automatic accrual starts in a period without those legacy entries, preventing accidental double grants. The calculator links directly to manual adjustment. A reduced recalculation also requires HR review rather than an automatic deduction. V1 current-active-employment limits remain; multiple Employment records within one period require review rather than inferred service continuity.

## Execution boundary

Calendar, explicit periods, types, manual verified opening/grant/adjustment, requests, approval and cancellation may proceed independently. Manual amounts require HR permission, reason and provenance; the UI must describe them as HR-entered amounts, not an automatically qualified legal entitlement.

The employer-policy acceptance and local implementation gates are resolved. Automatic annual calculations passed fresh/upgrade, permission, arithmetic, idempotency, concurrency and browser qualification; see [final V1 qualification](cube-3-v1-final-qualification.md). Half-day clock mapping has its separate qualified engineering contract and is not established by a 0.5 balance quantity. This local qualification does not discharge DEC-023 production statutory qualification.
