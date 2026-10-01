# Reviewed Attendance coverage classifier

This private seam supplies nominal-day classification for the forthcoming immutable fact review/commit and atomic joint Leave/Time coordinator. It does not introduce a public approval command or persist fractional/covered facts.

## Contract

`time.classify_attendance_values(instance jsonb, policy jsonb, effective_punches jsonb, context jsonb, employer uuid, as_of timestamptz)` consumes server-built frozen inputs. The reader must supply the exact scoped Work Instance/policy, canonical sticky-exclusion/latest-replacement punches, Employer from its scoped Employment, and current approved or explicitly reviewed prospective Leave sources. It performs no application reads, writes, clock/auth reads or ledger effects. It reuses the qualified observation calculator and half-day mapping constructor.

Results expose `version`, `kind`, `absence_units`, `leave_units`, `leave_sources`, `context_hash`, independent base `observations`, `evaluated_observations`, `diagnostics` and `approval_eligible`. Kinds are `absence`, `leave_covered`, `worked` and `review_required`. Eligibility is classification only; future command authorization/CAS/reason remain mandatory. The standalone fact writer will accept only absence/covered outcomes; worked remains a seam for the subsequent joint coordinator.

- Settled no punches: no Leave means absence1; one valid mapped half means absence0.5; exact whole coverage means absence0. Work metrics remain NULL when no observations exist.
- Full coverage with valid real work retains every actual metric, late/early and short-workday diagnostic, adding `observed_work_during_excused`. No wages or overtime are inferred.
- Duplicate/missing/reversed/outside-window/DST/break evidence retains independent recovery diagnostics. Half-day overlap cannot fabricate residual absence from minutes.
- Every source must match Tenant/Employee/Employment/Employer/date and frozen approval/type/calendar/pay-effect identities. Full coverage requires exactly1, never a coarse sum at least1. Two halves require distinct request identities, opposite fixed parts and exact stored mapping agreement with the existing constructor, which proves complementary disjoint work spans. Flexible double halves, altered/missing mappings and duplicate sources require review.
- No-punch classification before or exactly at attribution end remains `awaiting_observation_window`; strict after end permits settlement. This preserves Time lifecycle and is not a statutory entitlement formula.

The richer `platform_private.approved_leave_classification_context` reads Employer/pay effect from approved request-day snapshots, not today's Type. Existing `approved_leave_context` removes the four new fields so current Attendance snapshots, worked facts and APIs retain their established visibility. The fingerprint now includes the richer private source through one checked function-source anchor. Existing immutable evidence is untouched and becomes explicitly stale when appropriate. A future contract2 API must still apply explicit Leave visibility to expanded fields; private helpers alone do not protect public serialization.

`.gitattributes` pins SQL migrations to LF. Windows CRLF checkouts broke an existing historical function-source anchor during full rebuild. Normalizing checkout bytes fixed the rebuild without changing historical migration content; the attribute prevents recurrence.

## Local qualification

Base `1a6d61226e21e370b00cac643e0b38241c094483`; only isolated loopback QA targets were changed.

- Normal fresh application chain0→107 and untouched-source clone82→107 completed. Fresh/upgrade function definitions and ACLs match. Baseline five employees, four employments and two account links retain their original full-row digests.
- Each scoped Attendance/Leave/People run passed40 files /1828 assertions. Final focused tests passed44 assertions on both targets after consolidating flexible variants. These cover paid/unpaid/whole/mixed half coverage, strict settlement, retained genuine observations, invalid evidence, scope/mapping conflicts, flexible odd requirements, DST, zero preview effects and private EXECUTE ACLs.
- Four actual blocked approval/punch/fact and cancellation/fact race orders passed. `pg_blocking_pids` established each blocking edge; relevant function hashes remained unchanged, fingerprints and immutable historical facts remained correct.
- Actual authenticated Attendance-only detail reads across four synthetic race instances hid `pay_effect`. The limited source exactly matched the previous shape; richer source matched approved request-day/Employment metadata. A genuine approved half with actual punches classified as worked through this helper. Permission-test role links were changed only inside a rolled-back synthetic transaction.
- Independent read-only review found and then accepted the fix for the richer-source visibility leak. Clean-code/test guard checks passed. Scoped diff check passed; historical SQL content remains unchanged.

Evidence is retained in the local run: `slice24-*-full-tests-summary.json`, final focused logs, `slice24-function-data-comparison.json`, `slice24-source-privacy.json`, and race result `a1edcf15-6b86-4f4a-b20c-471bfab91cb0`. The broader fresh suite also passed56 files before the last three focused additions. Broader operator tests on the upgrade clone encountered existing operator-grant baseline assumptions; this is scoped qualification, not an all-repository green claim.

Remaining work: immutable contract2 facts, explicit public review/commit with CAS/idempotency and permissions, legacy compatibility guards, current projections/overtime, atomic multi-date Leave approval/replacement/reconciliation, usable HR/Attendance interfaces, annual entitlement policy and full Cube3 qualification. No main merge, deployment, remote migration or Cube3 completion is claimed.
