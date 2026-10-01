# Half-day Leave preview evidence — local qualification

## Delivered contract

Submission keeps the original selected `first`/`second` part on the request. Immutable preview/day rows store the reviewed part, mapping state, complete interval/calculator evidence, effective Time policy identity/version and algorithm version. Refresh writes a new preview; it does not change original intent or older evidence.

An existing Work Instance's frozen schedule identity wins. Otherwise resolve the effective work assignment and dated override. Leave-only half-days retain 0.5 units without clock inference. Attendance-enabled fixed shifts require an explicit part; flexible shifts use their configured remaining-work threshold without AM/PM. Unknown break placement or invalid timezone/workday remains review-required.

Existing public submission/refresh/approval signatures remain intact. Distinct own and HR mapping-options/part-refresh RPCs preserve narrow employee identity even for a mixed HR/self role. Own new-work options require People and Leave entitlements. HR options require `leave.manage`; HR refresh requires `leave.approve`, matching the existing reviewed-preview step. New fields appear in request summaries/details.

Approval compares current full mapping evidence with the reviewed preview before and after Work Instance locks. Changed policy/capability/effective mapping requires explicit refresh. Existing whole-date overlap and authoritative-Time-fact guards remain conservative. A mapped half-day does not yet permit compatible worked facts on that day; the following integration slice must qualify those rules together. Historical approved Leave-only rows are never rewritten when Attendance is enabled.

Migration-only source-replacement helpers are dropped after their fail-closed patches. Internal runtime helpers remain revoked from client roles. No payroll money, period lock or generic workflow is added.

## Executed evidence

Node 24.16.0, Supabase CLI 2.106.0, PostgreSQL 17.6; normal migration chain on three isolated loopback QA databases only.

- Authoring QA: 139 focused assertions passed.
- Fresh application-chain QA and preserved baseline-source-clone upgrade QA: each passed 379 assertions in six files: half-day request mapping (139), approval/consumption (47), request/scope (84), cancellation (51), reciprocal Time guard (18), Leave payroll-source projection (40).
- Focused cases use actual own/HR submission, options, refresh, approval and current-link changes. They include Attendance-off evidence, fixed split at 12:30, flexible 481→241 threshold, immutable refined-part previews, stale capability refresh, legacy unknown-break denial, and disabled new-work options for a linked mixed-role user.
- Both target chains reached 100 migrations. Function definitions and ACLs match. The untouched source's full-row digests for 5 employees, 4 employments and 2 links remain preserved.
- Commands: `qa-upgrade-cli.mjs`, `qa-fresh-cli.mjs`, `qa-approval-upgrade-cli.mjs`; focused `qa-tests.mjs`; both target `qa-approval-tests.mjs`; `qa-approval-preservation-compare.mjs slice13`. Logs/comparison are retained in the local run. Tests precede commit; only a header comment and this qualification document changed after passing tests.

The first target regression run found two test issues: a copied fixture assumed a specific random UUID order for requests sharing one transaction timestamp, and an older whole-day/clock-part assertion expected the superseded pre-mapping error. The former now checks membership; the latter still rejects an invalid whole-day part using the current validation contract. Production behavior was unchanged by these test corrections.

Remaining gates: part-selection UI, compatible Time interpretation/facts, explicit reconciliation of already-approved Attendance, complementary-half overlap, fractional absence, correction/replacement and automatic annual entitlement policy. This evidence does not close Cube 3 or qualify Cube 4.
