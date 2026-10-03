# Ordinary payroll period salary and proration amendment

Status: **Accepted by the product owner, 2026-10-02.** Additive amendment to [Frozen Payroll §4](employee-finance-payroll-spec.md). No monetary engine or statutory qualification is asserted.

An unchanged monthly salary covering a full ordinary Payroll Period is paid in full, including a configured 25th → 24th cycle, irrespective of its actual day count. The default Tenant proration policy is `calendar_days`. Ordinary join/end and dated salary-change portions use the actual inclusive civil-day count of that Payroll Period as the denominator. The Tenant selects the policy once in setup.

`fixed_30_day` remains an available setup choice. Its ordinary monetary semantics require explicit definition before the affected calculation is implemented; selecting it does not authorize an inferred full-period or partial-period formula.

Transition periods retain the accepted calendar amendment's per-covered-local-date treatment, using the calendar-month denominator or 30 as applicable to the selected policy. Do not apply the ordinary-period denominator to a transition or infer a new transition formula.

Exact decimal rounding follows the [accepted operational amendment](cube-4-operational-policy-amendment-2026-10-02.md). The first implementation slice stores the choice and approved inputs only. Calculation acceptance must later distinguish full ordinary, join/end, salary-change and transition cases and show the dated explanation.
