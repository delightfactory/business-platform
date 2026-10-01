# Cube 3 — half-day mapping engineering contract

This technical contract implements the accepted 0.5-day product quantity without inventing clock time. It changes no statutory entitlement or Payroll amount. The implementation and acceptance tests below remain required; this document is not implementation evidence.

## Fixed schedules

Use the effective, versioned schedule and an explicit scheduled break placement. Existing `break_minutes` alone cannot locate a break. Preserve legacy placement as unknown rather than backfilling a guess.

Represent the shift and break as local operational-date intervals, resolved using the existing Cairo/DST resolver. Remove the break from scheduled working intervals. The first half comprises `floor(net_scheduled_minutes / 2)` working minutes; the second receives the remainder. Save the mapping algorithm version, source policy version, part, intervals and minutes on immutable approval evidence. Where a split lies exactly at a break boundary, the remaining half starts after the break when appropriate.

For a 09:00–17:00 shift with a 13:00–14:00 break: 420 net minutes split into 210 + 210. First-half Leave excuses 09:00–12:30. The remaining working intervals are 12:30–13:00 and 14:00–17:00. The remaining clock bounds are 12:30–17:00, containing a 60-minute break. They are **not** 13:30–17:00.

For a 09:00–17:00 shift with a 12:00–12:45 break: 435 net minutes split into 217 + 218. The split occurs at 13:22. Retain the odd-minute allocation explicitly; do not round both halves upwards.

When interpreting actual work, subtract the overlap of the observed valid work interval and the configured break. For example, actual work 14:00–17:00 after the 13:00–14:00 break has zero break overlap and 180 observed net minutes. Do not subtract the full scheduled 60 minutes again.

## Flexible schedules

Do not request an AM/PM or first/second part. The remaining required net work is `ceil(required_minutes / 2)`. A required duration of 481 minutes produces a 241-minute threshold. The effective policy must explicitly configure half-day break minutes; do not infer half of its full-day aggregate break.

Store actual gross/net observations separately from Leave quantity. A 0.5 Leave approval never manufactures punches or worked minutes.

## Availability and historical conflicts

- Leave without Attendance may approve a permitted 0.5 quantity with a `leave_only` mapping state and no fabricated time policy.
- When Attendance is enabled, missing fixed break placement or flexible half-day configuration is an explicit review prerequisite. Submission may remain pending for its authorized HR queue; approval cannot claim a complete Attendance mapping until configuration is resolved.
- Enabling Attendance later does not reinterpret historical Leave automatically. A reviewed, versioned mapping is required for any new interpretation of that evidence.
- Approved Attendance is never rewritten silently. Leave approval encountering an already-approved incompatible Attendance fact must expose the exact fact/version and require a reasoned correction. A source correction must retain prior evidence and the supersession/reversal relationship.
- Resolve overnight boundaries from the operational date and schedule timezone. DST gaps or ambiguous boundaries prevent automatic mapping; retain a clear review state.

## Quantities and unpaid exposure

Treat Leave-covered quantity and unexcused absence as disjoint fractions of one day. Paid Leave 0.5 plus unexcused absence in the remaining half yields 0.5 unpaid absence. Unpaid Leave 0.5 plus unexcused absence 0.5 yields total unpaid exposure 1.0, attributed separately to their two sources. Unpaid Leave 0.5 plus fulfilled remaining work yields 0.5 unpaid Leave and zero additional absence.

Do not project a full unpaid absence for the half already covered by Leave. Leave never proves that the other half was worked. The exact source IDs, quantities and versions must accompany nonfinancial Payroll facts; money remains Cube 4 responsibility.

## Concurrency and acceptance

Employee identity mutations already serialize on the Employee row. Own mutations lock/recheck the current link. Leave locks Employee, Employment and configuration before work instances and balance accounts. Retain each Time writer's existing lock prefix: manual worked-fact approval already locks the Work Instance without subsequently acquiring Employment or Leave-request locks; absence and materialization paths already lock Employment first. Do not introduce an unnecessary upward lock after a Work Instance. The reciprocal Time guard reads approved Leave evidence without locking Leave rows. Bulk Work Instances use operational date and ID order, matching Leave. Recheck permissions, entitlements, effective relation/policy and the exact current fact after the applicable locks. See `cube-3-leave-time-guard-qualification.md` for the two observed reciprocal races; half-day mapping still requires its own implementation and acceptance.

Required tests: the fixed examples above, odd-minute allocation, observed-break intersection, flexible odd threshold, missing legacy mapping, no Attendance, enabling it later, overnight/DST ambiguity, approved fact conflicts and explicit correction, paid/unpaid half plus worked/absent remainder, no duplicate debit/reversal, and concurrent Leave/Attendance/Employment changes. No hourly Leave, general calendar engine, generic approvals or financial deductions are added by this contract.
