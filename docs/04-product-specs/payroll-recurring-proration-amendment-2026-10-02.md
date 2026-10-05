# Recurring component proration amendment

Status: **Accepted by the owner, 2026-10-02.** Additive amendment to [Payroll §§3–4](employee-finance-payroll-spec.md).

A fixed recurring component is a monthly value. By default (`salary_proration`), join/end and transition portions follow the accepted monthly salary proration policy, including when the Employee's base pay is daily. Dated changes allocate the applicable values across their effective dates. Full ordinary cycles retain the full unchanged monthly value.

The administrator may select the bounded per-component override `paid_full_period`: pay the fixed value in full for the period without join/end or transition proration. If the paid-full value or proration choice changes within the same period, this slice presents an owned blocker: schedule the change at the next ordinary-period boundary, or use the accepted salary-proration dated behavior. It does not invent a mixed override formula. Legacy components lacking the setting use the accepted `salary_proration` default. No arbitrary expressions are added.

A recurring percentage is calculated from the earned base pay, not the unprorated contracted salary. Approved one-time adjustments retain their approved amount. Where daily-rate changes or changing percentage applicability require dated units but only an aggregate approved quantity exists, calculation has an owned blocker instead of an invented allocation.

Classification or calculation-method changes within one period are owned review blockers; the candidate does not silently split/round one logical component twice. Component tax/social flags remain reviewed input metadata, not legal qualification.
