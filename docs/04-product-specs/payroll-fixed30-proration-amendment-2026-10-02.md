# Fixed-30 ordinary period proration amendment

Status: **Accepted by the owner, 2026-10-02.** Additive amendment to [Payroll §4](employee-finance-payroll-spec.md), following [the earlier actual-days/default decision](payroll-ordinary-period-proration-amendment-2026-10-02.md). The earlier record is retained as decision history.

For `fixed_30_day`, a full ordinary cycle receives the full unchanged monthly salary. A partial join/end portion receives salary ÷ 30 × actual eligible days, capped at a full salary. A salary change within a full ordinary cycle allocates the dated salary values by their actual effective-day fractions of that cycle, avoiding a 31-day overpayment.

For a partial portion containing salary changes, use the average of the dated effective salaries over its eligible dates, multiplied by `min(eligible_days / 30, 1)`. This applies the same cap without choosing an arbitrary first/last/highest salary. The full-cycle case is the dated weighted average over the cycle.

Transition periods retain the existing accepted calendar amendment's per-covered-local-date formula (monthly salary ÷ 30 for fixed-30, or monthly salary ÷ that date's calendar-month day count for actual-days). No business-cycle proration is a statutory tax/social-insurance formula. Net pay requires an independently verified statutory pack and qualified adapter.
