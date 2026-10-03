# Cube 4 entry checkpoint — 2026-10-02

Status: **partial preparation; Cube 4 implementation and qualification remain open**. This checkpoint records observations, not acceptance of proposed financial policy. Read the [execution contract](cube-4-execution-contract.md), [decision/acceptance register](cube-4-decision-acceptance-register.md), [source lock review](cube-4-lock-graph-review.md) and [attached proposed extension](cube4UXextension.md).

## Selected boundary

- Working branch: `codex/cube4-payroll-core`, base `555c34a568f44eb4b99d99712a699094488f3026`. The original checkout and other worktrees were preserved. Changes are uncommitted documentation additions plus the execution-plan links; no application or migration change.
- Remote read on this date: Cube 3 branch `555c34a568f44eb4b99d99712a699094488f3026`, main `504f9048f0909d2ea47c7de23b45962ef028e9bf`. These refs do not establish a production deployment.
- User reaffirmed configurable non-calendar cycles, specifically **25 August–24 September**, through simple company setup. This is already within the accepted Employer-scoped calendar amendment. It is distinct from its **26 August–25 September** example. Payment date is a separate setting; early salary payment does not implicitly define its rule.

## Current verification

| Check | Result and limit |
|---|---|
| Selected candidate static checks | `npm run typecheck`, `npm run lint`, `npm run build -- --webpack`: exit 0. No new Payroll application behavior exists to qualify. |
| Selected candidate annual browser | Freshly built selected checkout, build ID `nzgqHyNRibasCFHDCzQX8`, served locally on port 3320. Real local Auth, annual GET context and preview passed for all three synthetic demonstration Employees. At 390/820/1280 no horizontal overflow was detected; desktop screenshot inspected. Full accessibility acceptance was not exercised. |
| New isolated annual posting/recovery journey | A new synthetic QA Tenant and two Employees passed actual Auth → UI → RPC → database grant, changed-input confirmation invalidation, exact-attempt replay, reload with persisted source/zero delta, and committed HTTP response intentionally dropped followed by replay/reload without duplication. Final persisted counts independently reread by the coordinator: two calculations, two ledger entries, 28.40 entitlement days, four unchanged configuration-audit events. These configuration-audit counts are not a claim to have independently checked every audit table. |
| Local database identity | Selected server uses the loopback QA gateway on port 3313 for `business_platform_cube3_calc_upgrade_qa`; the launcher asserts this target and the selected Git base. Only the two public connection values are supplied, without copying an environment file or using an administrative key. |
| Annual regression | Existing annual SQL suite: 35 assertions passed on each of `business_platform_cube3_annual_fresh_qa` and `business_platform_cube3_calc_upgrade_qa`. This is focused regression on existing independent QA databases. |
| Annual current schema parity | Function definitions/ACLs and annual tables/constraints/indexes/triggers match; 109 recorded migrations per database. SHA256 `3911c9420462062d138cb9297439b156bb8f0a789257a709d9b0ac5785143b55`. No new full migration replay, retained-data digest check or full database regression was run. |
| Existing demonstration runtime | Context and preview also passed on existing port 3315. This is separate from the new selected-candidate observation. |

Evidence is retained outside Git under the isolated `20261002-cube4-payroll` run directory: `entry-annual.json`, `entry-annual-0.png` through `entry-annual-2.png`, both database annual test logs, `slice30-schema-parity.json`, `static-gates.json`, and `typecheck.log`/`lint.log`/`build.log`. The reused parity harness keeps its historical filename; this does not imply a new Cube 3 slice was delivered.

One candidate login attempt failed because the local launcher initially supplied the wrong public-key environment variable name. Its failure is retained as `entry-candidate-setup-failure.json`; correcting the launcher to the repository's `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` produced the successful selected-candidate result above. This harness error is not asserted to be the previously reported annual GET defect. The initial whole-file environment-copy command was rejected by automatic policy review (`blocked by policy`, no further reason supplied); the allowed alternative supplies only the validated public values. No permission bypass was used.

## Open gates and next work

The original annual failure scenario and the location/publication status of the separately reported copy fix remain unidentified. Current successful contexts and the new posting/reload/recovery journey do not establish that original cause was repaired. G1/R01 therefore remains partial; identifying and resolving or explicitly explaining the original scenario remains required before dependent implementation.

The user has been asked about proposed shorter-month cutoff handling and payment-date semantics; no answer is recorded at this checkpoint. Neither the request to support a 25–24 cycle nor elapsed waiting accepts those separate proposals. The attached extension requires a decision before affected Slice 1 generation/save. Other financial/consumption decisions remain in the register and block only their affected slices.

Safe independent work completed: eight ordered slice contracts, Arabic setup/recovery/role journeys, capability closure map, all 64 original acceptance IDs with planned evidence, and concrete current source lock inventory including dynamic migration patches. All Cube 4 application acceptance rows remain **NOT RUN**. No monetary calculation, approval, irreversible lock, payment/correction/advance workflow, exports or Payroll UI has been delivered.

Additional preparation evidence: [calendar acceptance examples](cube-4-calendar-acceptance-examples.json) contain five reviewed unambiguous date fixtures, while unresolved cutoff/payment/timezone expectations remain null. Fixture contiguity, document links, original 64 acceptance IDs and `git diff --check` passed; a narrow independent review found no material issue. These are design checks, not Payroll application acceptance. The new annual journey is recorded outside Git as `annual-journey-pass.json`, `annual-journey-manifest.json`, `annual-journey-artifacts.json` and two screenshots. Existing fixtures and failed evidence were retained.

Next dependent action: resolve the original annual journey evidence and record the required calendar decisions, then implement and qualify Slice 1 setup/period readiness without exposing financial lock. The full Cube 4 goal is blocked pending the original annual-scenario evidence and required calendar decisions. The same entry blockers persisted across three consecutive goal turns; all available bounded independent preparation and selected annual-journey verification was completed. This status stops automatic continuations without claiming Cube 4 completion. Technical closure, statutory acceptance and production release remain separate. No commit, push, merge, deployment, remote migration or production mutation occurred.
