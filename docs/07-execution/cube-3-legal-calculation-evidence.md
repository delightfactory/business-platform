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

## Technical recommendation awaiting policy acceptance

The official text establishes the entitlement and time-unit rules, but does not supply a complete numerical fractional-accrual algorithm. The following is an employer-policy recommendation, **not an accepted statutory formula**:

- Keep the company's explicitly configured balance year separate from service-year eligibility. Recommend January–December as an understandable administrative default, configurable before account periods are created; do not impose it as law.
- Segment service by dated, HR-verified entitlement changes. Calculate each segment using actual covered service days / 365 and its applicable annual rate. Under the default Article 2 convention, the six-month threshold corresponds to 180 days; a contrary applicable agreement requires qualification.
- Keep the unrounded cumulative amount, then round the final difference upwards to 0.01 day as a worker-favourable technical policy. Request increments remain independent: a permitted half-day consumes 0.5 day.
- One base grant per Employer + Employee + Type + period. Subsequent changes append an attributable difference against that same account; they cannot create another base grant or erase earlier consumption.
- Carry the remaining balance with its source account and evidence. Do not expire it automatically or claim that settlement obligations have been discharged.

Illustrative technical test vectors: `15 × 180 / 365 = 7.397260… → 7.40`; `21 × 90 / 365 = 5.178082… → 5.18`. These examples describe the proposed arithmetic only. They do not prove that a particular Employee is eligible, or that granting future service entitlement is permitted.

## Execution boundary

Calendar, explicit periods, types, manual verified opening/grant/adjustment, requests, approval and cancellation may proceed independently. Manual amounts require HR permission, reason and provenance; the UI must describe them as HR-entered amounts, not an automatically qualified legal entitlement.

Automatic annual calculations dependent on the recommendation above remain unqualified until the exact accrual timing, threshold convention, category transitions and rounding policy are accepted. Record this as a bounded prerequisite; continue independent slices. Do not claim full Cube 3 closure with mandatory automated annual entitlement unresolved. Half-day clock mapping has a separate engineering qualification contract and is not established by a 0.5 balance quantity.
