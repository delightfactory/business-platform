# Cube 4 ADAM local execution checkpoint

This is an implementation checkpoint, not full Cube 4 acceptance. No publication, production changes, GitHub Actions, or financial gate opening occurred.

The single acceptance reference remains [the existing register](cube-4-decision-acceptance-register.md). This file records the execution handoff and limitations of its latest delta.

## Identity and isolation

- Source HEAD: `bc351e19f1d52129f81a9b2a9f1de97b03516a13`; tree: `c222aced467788c75009d976960bd191960c6b4b`; parent: `1f531a38f4726508d8fac8fd3c17bddc4139342d`.
- Source tracked files were clean; only `AGENTS.md` and `CLAUDE.md` were untracked. Both were read. The source files were not modified or copied as new work.
- Isolated local clone: `C:\Users\DELL\Documents\Codex\2026-10-03\task-5\implementation`; branch `codex/cube4-adam-closure`. It retains the local source history and starts exactly at the agreed SHA. No fetch was needed.
- Node runtime: `v24.16.0`; Next `16.3.6`, React `19.3.0`, TypeScript `5.9.3`, existing locked dependencies. A local `node_modules` junction supplies read-only dependency reuse; install/update commands were not run. Build outputs are in this checkout.
- Existing Codex and Node processes were visible. `Get-CimInstance Win32_Process` was denied; the original writer's activity could not be established. No private sessions were read and no Codex process was interrupted.
- Git ownership was handled by command-scoped exact `safe.directory` entries, without changing global configuration or device rights.
- Quota posture: one local implementer, delta tests only, no Astra, no reviewer fleet, no repeated dispatches. The requested execution lane is GPT-6.1 Medium; this subprocess's provider/model identifier is not exposed by the available tools and is not asserted as independently verified.

## Implemented delta

1. `corrections/page.tsx` restores every ordinary saved proposal from `case.changes[].fields`, its original source identity/hash, reason, reference, target, and responsibility rows. A missing source produces a retry state instead of creating a blank proposal. A saved kind redirects to the correct editor. Editing no longer offers misleading source replacement controls.
2. `CorrectionForms.tsx` restores dated splits, new/existing employee mode and nested input data. It retains untouched sibling changes and responsibility output identities. The pending-request restoration hook still overrides the saved proposal with the original pending form.
3. `actions.ts` carries untouched ordinary sibling changes through preview/save, leaving validation and source authority with the existing RPC. It does not substitute a fresh source hash for the saved hash.
4. Additive migration `20261003030000_cube4_review_contract_repairs.sql` tightens Leave approval to the exact request/approved preview, or an authoritative existing `hr.corrected` replacement event for the bound request on that date. An unrelated cancelled request cannot license new historical Leave. It does not resolve requirements or discard siblings.
5. The same migration gives generated statutory lines a versioned immutable presentation record and independent insurance pack identity. Payslip presentation validates that record against the saved result, pack, amount and classification. Zero tax retains a line. Employer contributions remain employer costs and are excluded from the employee's displayed deductions. Historical output without the new metadata stays blocked; no immutable history is rewritten.

The migration is **not installed or PostgreSQL-qualified**. Full historical Leave additions, including approved additions on dates with no original binding and repeated replacement chains, remain open. The bounded same-date replacement exception is not their completion claim.

## Evidence actually executed

Logs are in the parent task directory:

- `correction-restoration-tests.log`: `node --test scripts/cube4-correction-restoration.test.mjs`, exit 0, 12/12. Executes the actual page, form, server action and recovery hook with synthetic RPC transport and emulated React/browser hooks. Covers all ordinary kinds, dated splits, existing employee restoration, nested input fields, exact saved hash, reason/reference, responsibility targets, ordinary siblings, multi-source restoration, kind redirect and pending-intent refusal. **No authenticated browser or persistence acceptance is inferred.**
- `typecheck.log`: `npm run typecheck`, exit 0.
- `build.log`: `npm run build`, exit 0. Production webpack build completed; cache snapshot warnings did not fail compilation. No application server was started.
- `lint-final.log`: targeted ESLint. The initial run caught a forbidden local `module` variable in the test harness; it was renamed. Read the final log and command status in the external checkpoint manifest.
- `git diff --check`: exit 0. Original source status was rechecked without tracked changes.

The first restoration test draft passed 6/10: four fixtures incorrectly reused compensation fields for other source kinds or omitted a required component reason. Their fixture shapes were corrected; the production assertions were not weakened. Test-guard then removed the internal recovery-hook mock and exercised the actual hook against browser/library boundary emulation. The final 12 tests passed after that change.

Prepared, **NOT RUN**, PostgreSQL deltas:

- `cube4_statutory_payslip_contract.test.sql`: actual private numeric worker to report projection; independent synthetic packs, metadata completeness, employer-cost exclusion, zero tax, missing schema, wrong pack/amount/employee. NONLEGAL schedules are not official comparisons.
- `cube4_leave_request_identity.test.sql`: actual public approval/binding/cancellation fixture followed by a different request on the same day, with Leave on and Time off; expects authoritative refusal and preservation of binding/responsibility. Closure of the old financial responsibility through the real workflow still requires a connected QA journey.

Both tests refuse every database except `business_platform_cube4_adam_closure_qa`, which has **not been created**. Existing writer QA databases and data were not touched. Existing source-binding replacement tests also need a delta replay in that owned database.

## Blockers and ordered continuation

**P0 execution environment:** `docker ps` failed with access denied to Docker configuration and `npipe:////./pipe/docker_engine`. No sandbox escalation, credential access, permission change or alternate connection to another QA database was attempted. ADAM needs to resume in an already-authorized local QA runner, without changing device permissions or using the writer's database. First create the owned database, replay all 160 candidate migrations, and run only the affected SQL deltas and replacement/lineage regressions. Then perform actual authenticated restoration, stale-source and lost-response browser journeys at 390/820/1280, before integrated final qualification.

**P1 historical Leave closure:** implement and qualify the authorized addition/observation path for a genuinely new historical request and dates without original bindings, preserving all sibling obligations. Current new-request refusal closes the unsafe bypass only. The approved → cancelled → financially closed → different same-day request scenario still needs actual end-to-end proof, not a privileged completed marker.

**P1 financial integration:** the public `payroll.finalize_run` still raises `payroll_release_gate`. Independent statutory workers are not wired into a complete public candidate/YTD/consumption/approval/finalization contract. The statutory source helper still returns NULL legal duration and insurance obligation months. Cross-year segmentation, independent effective packs, cumulative prior assessed tax versus withheld tax, insurance month ownership, advance consumption and verified deduction capacity require explicit implementation and connected acceptance. A flag or synthetic verified pack must not open the gate.

**P1 remaining lifecycle acceptance:** exact-candidate paid/unpaid correction and amendment, replacement succession atomicity, external settlements, advance termination settlement, export/distribution authorization races and paging, changing permissions/context, and full fresh/upgrade parity remain open. Existing bounded reports/payment/advances evidence retains its original SHA and limits.

**Single external legal handoff:** obtain one formally reviewed statutory qualification package defining the applicable 2026 tax treatment/category/year and legal duration, insurance obligation-month ownership and rates, deduction ceilings/priorities, and official expected numerical cases with provenance. Ahmad's previously stated lack of official results/access is retained; this checkpoint does not ask him again or manufacture comparisons. Code integration and synthetic tests can progress while public release remains closed; official acceptance is conditional on that package.

Final qualification must bind one local SHA/tree, build/runtime/database identity and the full connected journey. Baseline157 evidence, current159 scoped proofs and the prior 244-file manifest are historical component evidence, not PASS for this new 160-migration candidate.

clean-code-guard: the changed code retains the established service/authority boundary and introduces no dependency, release flag or synthetic production result. PostgreSQL and connected UX qualification are flagged as blockers. test-guard: the recovery helper runs unmocked; React/browser/RPC boundaries are emulated and those limits are explicit.
