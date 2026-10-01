# Slice A0 — Versioned half-day Time policy mapping

**Status:** locally qualified configuration/calculator slice; Leave/Time workflow integration remains pending. This slice adds only Time policy configuration and an internal preview calculator. It does not make Leave consume Attendance or create clock/absence facts.

## Source seams and compatibility

- The current `public.save_time_work_policy` has a 20-argument full signature, last defined in `supabase/migrations/20260930140506_attendance_clean_auto_approval.sql`. It validates via `time.has_policy_permission`, locks/advances the template head, inserts one immutable policy version and appends a Time audit event in the same transaction.
- `time.work_policy_versions` is protected by `work_policy_versions_immutable` from `20260930090259_attendance_work_policy_integrity.sql`. New mapping values are inserted with the new policy version. Existing rows receive NULL mapping values; no historical placement is inferred.
- The old public RPC retains its exact signature and routes to the shared private writer with NULL mapping fields. A distinct `save_time_work_policy_with_leave_mapping` adds fixed break start/end and flexible half-day break minutes without overload/default ambiguity. Fixed positive breaks require an explicit interval matching the aggregate break and fitting the shift; flexible saves require explicit half-day break minutes.
- The current permission checks and response keys in `time_work_policy_catalog` and `people_work_policy_panel` are retained. These surfaces expose the new fields for configuring the immutable version.

## Stored policy and pure preview result

Each policy version adds `fixed_break_start`, `fixed_break_end`, and `flexible_halfday_break_minutes`. Fixed versions cannot carry the flexible value; flexible versions cannot carry fixed placement. Placement endpoints are nullable only as a legacy unknown state; new mapped fixed positive-break versions require both. Flexible half-day break must be configured explicitly from 0 to 360 minutes. The aggregate full-day break is never blindly prorated.

Private `time.leave_halfday_mapping(policy_snapshot, operational_date, part)` returns a preview, not a persisted fact. It requires source policy template and version identity. The result carries algorithm version, that source identity, configured input fields, timezone/date, both complementary interval sets (`excused_intervals` is the selected Leave part; `remaining_intervals` is its work complement), the resolved break interval, and UTC instants plus local labels for every interval. The helper is revoked from client roles. Fixed policies need `first` or `second`; flexible policies reject a part.

For fixed schedules, resolve the operational shift and configured break to UTC using `time.resolve_local(timestamp,text)` from `20260930102608_cube2_manual_attendance_v1.sql`. Split the actual resolved work intervals by UTC elapsed net minutes: first receives floor(net/2), second receives the remainder. Exclude the break from both returned work interval sets. Resolve and validate shift endpoints, break endpoints, split endpoint, and every endpoint in both parts. If any local endpoint is a DST gap/overlap, return review-required. If an explicit break's resolved UTC duration differs from its configured minute count across a timezone transition, return `timezone_transition_review_required`; do not return a misleading mapping. This keeps overnight/DST split arithmetic aligned with Time's UTC observations.

Examples on ordinary Cairo days: 09:00–17:00 with 13:00–14:00 break gives 420 net minutes, 210/210, split 12:30; second intervals are 12:30–13:00 and 14:00–17:00. With a 12:00–12:45 break, net is 435 and the split is 13:22 (217/218). For an overnight shift crossing a DST transition, derive the net and split from resolved UTC instants; never assume wall-clock duration equals elapsed duration.

Flexible policies require a valid timezone and required minutes in the existing 60–960 policy range. They return `ceil(required_minutes/2)` as the remaining net-work threshold: 481 produces 241, with explicit configured half-day break minutes. They do not return AM/PM or first/second intervals.

## Scope boundary and follow-on work

A0 does not change Leave submission, approval, quantity, balances, Attendance facts, WorkInstance snapshots, punch interpretation, or Payroll. A later integration slice must use reviewed effective policy provenance, preserve 0.5 quantity without fabricating clock minutes, compare current Attendance facts after locks, and require explicit correction for conflicts with approved Attendance. Until then these fields and calculator are configuration/preview only.

## Focused qualification expected

The companion pgTAP draft covers legacy signature and grants, new RPC permissions, same-version persistence, invalid mapping rejection, immutable versions, legacy positive-break review and zero-break mapping, both fixed examples, complementary intervals and break provenance, flexible threshold/timezone/bounds, overnight operational dates, a valid UTC-duration DST overnight, and invalid boundaries in both halves. Executed locally after independent review; see qualification evidence below.

## Executed local qualification

Supabase CLI 2.106.0 applied migration 20261001031000 normally to loopback authoring QA, fresh application-chain QA and preserved source-clone upgrade QA. No remote database was changed.

- Focused mapping pgTAP: 33 assertions passed on authoring QA.
- Fresh and source-clone upgrade each passed 226 assertions across mapping (33), manual Attendance (110), overtime review (41), clean auto-approval (31), and policy-transfer inheritance (11).
- Both target chains contain 97 migrations. Function definitions and ACLs match. Baseline full-row digests for 5 employees, 4 employments and 2 account links remain unchanged.
- External evidence: `slice9-function-data-comparison.json`, per-database test logs/summaries, and slice9 manifest. Tests precede the commit; only header and qualification prose changed after testing.

Independent review corrected wall-clock splitting to resolved UTC elapsed intervals, checked the complementary half as well as the selected half, retained break and source-policy provenance, guarded malformed snapshot casts and JSON null identity, and corrected the expected valid spring-DST result. This qualification does not claim half-day Leave approval, Time interpretation or any payroll calculation is complete.