# Cube5 attendance channel backend checkpoint

Status: **backend finite checkpoint only; Cube5 closure and UI/startup acceptance remain unqualified.**

The worktree starts from accepted Cube4 `ed26e49a9b1b577952a484bc55083bb6c41fb25e`. Eight forward migrations implement the generic Attendance gateway; accepted/installed Cube4 migrations were unchanged. Database checks used only `business_platform_cube5_adam_channels_qa` in `supabase_db_business-platform`. No production, existing Cube4 runtime, deployment or vendor device was used.

## Finite acceptance register

| Actor and journey | Backend result | Evidence and remaining boundary |
| --- | --- | --- |
| Linked employee starts work, receives authoritative receipt, sees checkout next, finishes work | PASS | Public mobile punch → existing canonical punch → existing Time interpretation; distinct nearby in/out events; next action out/in. UI discoverability and browser journey pending. |
| Employee retries after response loss | PASS | Same attempt returns duplicate, canonical count unchanged; own receipt reconciliation confirms acceptance. Draft UI requires review against final cancellation response. |
| Employee reloads while submission is delayed | PASS | Real second session waits; reconciliation claims an immutable cancellation under the same actor lock; delayed request rejects; zero canonical events. |
| Wrong tenant, missing identity/permission, revoked member or changed pending scope | PASS for tested API boundaries | Public scope/permission denials and real queued operator capture versus membership revocation. Missing-link handoff and role configuration UI remain pending. |
| Employee punches with inside/outside/poor accuracy/unavailable/stale location | PASS | Public punch tests for all five outcomes; missing and JSON-null accuracy fail closed. Every required geofence configuration key is validated through public source save. |
| Tenant changes geofence policy or purges expired location | PASS for tested database contract | Original validation and source version retained; actual trusted purge removes precise evidence. Automatic maintenance scheduling is an explicit deployment prerequisite, unconfigured/unqualified here. |
| Non-valid location is accepted for review | PASS | Canonical evidence invokes Time review exception; unresolved review blocks approved fact insertion; explicit reviewer acceptance reinterprets through Time. Review endpoint denies mutation after Attendance entitlement loss. |
| Operator receives unmapped evidence, maps it, reprocesses once | PASS | Retained original evidence → tenant/source mapping → existing Time flow; identical and conflicting replay observations do not erase responsibility or poison reprocessing. Operator UI pending. |
| Operator applies dated mappings and resolves ambiguity | PASS | Historical mapping intervals retain old/new employee and Site context; overlapping active intervals are explicit mapping exceptions; same-transaction deactivation uses monotonic mapping revision. |
| Source delivers overnight attendance in UTC policy | PASS | Two cross-midnight canonical punches share the existing Work Instance and starting operational date. |
| Reviewer replaces a canonical punch | PASS | Mobile next action uses the existing latest replacement direction/instant and exclusions rather than raw source direction. |
| Operator disables source while capture is queued | PASS | Real second session queues behind existing tenant lock; disabled source denies new event. Prior evidence remains readable. |
| Repeated malformed captures | PASS | Public endpoint enforces 4 KiB payload bound and maximum 20 authenticated capture calls per actor/tenant/minute, including rejected calls. |
| Employee/operator phone, tablet, keyboard and desktop UI | BLOCKED / NOT PASS | Draft employee files preserved. Owner-required exact Claude Opus 5.5 consultation returned provider 403; no substitute used. No navigation integration, complete operator UI or browser/runtime qualification. |
| Selected biometric vendor / physical device | BLOCKED / NOT PASS | No selected reviewed protocol/topology/authentication/time/identity/replay/test/privacy record; no vendor adapter implemented or supported. |

The final finite public suite contains **109 passing pgTAP assertions** and ends with `ROLLBACK`. The real concurrency runner verifies **3 passing two-session scenarios**, confirms actual lock waits through `pg_stat_activity`, and intentionally retains its synthetic fixture/receipt history. Exact executed source hashes and raw final log are in task-owned `cube5-qa/implementation-final-source-manifest.json` and `cube5-qa/implementation-finite-api.log` outside the worktree. Concurrency evidence is `cube5-qa/implementation-concurrency.json`.

An earlier 90-assertion run failed assertion 57 (same-transaction mapping deactivation chose random UUID order). Its raw log was overwritten by the final run; the recovered exact excerpt and that limitation are recorded in `cube5-qa/implementation-prior-90-failure.md`. No failing historical source was rerun to fabricate evidence. The fix is forward migration `20261004145438_cube5_mapping_order.sql`.

The first concurrency fixture used an inverted source-before-tenant test lock sequence and produced a deadlock in the membership scenario. That fixture is preserved. The corrected runner uses the existing tenant-before-source mutation lock order and a separate fresh fixture; the finding is recorded in `cube5-qa/implementation-concurrency-first-finding.txt`.

## Reused boundary

- `people.employee_user_links`, active membership/Auth status, Employee employment and dated work assignments derive mobile identity and Site server-side.
- Existing `hr.people` and `hr.attendance` entitlement evaluation plus explicit enabled mobile source and `attendance.self.capture` permission govern capture. There is no separate mobile commercial capability key in the current Platform. Linking an Employee alone does not grant capture.
- `employee.attendance.self.v1` is appended to the existing role bundle catalog. The existing member bundle writer can assign it; exposing it in the member UI is pending.
- `time.manual_punches` remains the canonical evidence store. New source types are `mobile` and `external`; existing manual/import paths remain intact.
- `time.attendance_import_resolve_row` owns workday attribution/materialization and `time.interpret_work_instance` owns interpretation. No channel salary, deduction, lateness or Payroll engine was added.
- Existing correction functions remain authoritative. Channel location review appends its decision and delegates to Time interpretation or the existing punch exclusion function.

## Generic server consumer

`public.attendance_channel_submit(p_tenant, p_source, p_event_key, p_external_key, p_happened_at, p_direction, p_device_key)` is an authenticated, tenant-authorized RPC. Only a current Attendance manager/Tenant administrator may submit to an explicitly configured external source. It has no `anon` or `service_role` execution grant and requires no browser connector secret. A future qualified adapter must use an authorized bounded server consumer; this checkpoint does not implement adapter credentials, topology or transport.

The consumer supplies a stable source event key, source-scoped external identity, explicit timestamp with offset, declared direction, and optional bounded device key. One call processes one event. Responses distinguish accepted, duplicate, unmapped, rejected/conflict, retry failure and blocked capture. Source event identity is tenant/source scoped; replay diagnostics are retained separately from processing responsibility. Unknown direction is retained as an actionable interpretation failure rather than silently guessed; no vendor support is claimed for such events.

`public.attendance_channel_map` appends an active/inactive decision for an explicit effective interval. The latest monotonic revision for that exact interval governs it; distinct eligible overlapping intervals remain ambiguous. `public.attendance_channel_reprocess` processes one retained event, preserving its original key/time/direction and idempotent canonical binding. No bulk or general queue was introduced.

Operator reads use `attendance_channel_access`, `attendance_channel_sources`, `attendance_channel_events`, `attendance_channel_source_detail`, `attendance_channel_event_detail`, `attendance_channel_mappings` and `attendance_channel_options`. Lists validate bounded page sizes; options cap search results at 20, and focused details cap versions/results/replays. Normal operator APIs omit precise coordinates; events retain source version, validation and canonical links.

## Mobile and privacy configuration

`attendance_mobile_snapshot(p_tenant)` returns own trusted scope, eligibility/handoff reason, Site, effective policy timezone, next direction and the last 20 attempts. `attendance_mobile_punch(p_tenant, p_attempt)` accepts attempt identity/direction/capture instant/scope/policy version and optional bounded location. It accepts no Employee or Site override. `attendance_mobile_attempt(p_tenant, p_attempt_id, p_scope)` reconciles an own receipt or claims a terminal cancellation when no receipt exists; callers may then release the unresolved attempt safely.

A mobile source requires its explicitly selected Site and versioned configuration. Geofence off still requires explicit `geofence: false` and `retention_seconds`. Geofence on additionally requires `latitude`, `longitude`, `radius_m`, `tolerance_m`, `max_accuracy_m`, `max_age_seconds` and `failure_action` (`reject` or `review`). Supported geometry is one circle. Bounds: latitude −90..90, longitude −180..180, radius 10..10000 m, tolerance 0..500 m, accuracy threshold 1..500 m, evidence age 5..600 seconds, precise-evidence retention 60..2592000 seconds. These are validation limits, not production default values. An unconfigured mobile Site blocks capture.

Location evidence is a whitelisted bounded shape. Malformed/extra-field evidence is not stored as precise evidence. Capturing while geofence is off stores no location. The draft browser uses one `getCurrentPosition` call per new geofenced attempt and stores only attempt ID/scope in tab storage; precise coordinates remain in memory until authoritative completion. Its UX and cleanup remain unqualified until the paused UI work resumes.

`time.purge_expired_channel_location(p_at)` is private trusted maintenance, with no public/client execution grant. It physically deletes expired precise evidence and preserves immutable event/version/validation/Time history. Production must run this cleanup within the selected privacy policy; merely applying these migrations does not install a scheduler. No production retention claim is made by this checkpoint.

## Validation and remaining gates

The finite SQL runner reads `supabase/tests/cube5_attendance_channels.test.sql`, inlines the literal `\ir ../../scripts/cube5-qa-fixture.sql`, and pipes the result to `docker exec -i supabase_db_business-platform psql -X -U postgres -d business_platform_cube5_adam_channels_qa -v ON_ERROR_STOP=1`. Both source files are hashed in the evidence manifest. The concurrency command was `node scripts/cube5-channel-concurrency.mjs f7`; its retained synthetic actors use empty passwords and no sign-in transport. `node --check scripts/cube5-channel-concurrency.mjs` and `git diff --check` passed. No build or browser/runtime was started.

The original Cube4 residual official legal, U02 touch/zoom, U10 physical phone and Q03 pilot volume gates remain NOT PASS and were not reopened. Cube5 still needs the required design consultation decision, completed/discoverable employee and operator UI, independent security/backend review, browser checks, physical-phone evidence, approved actual Site/privacy values and scheduled retention operations. Vendor adapter qualification remains a separate blocked sub-gate.

## Root checkpoint verification

Root verified the final109 raw plan, zero failing assertions, rollback, and matching concurrency runner/fixture hashes. The affected existing Time regression suites ran once after the source-type and interpretation/fact trigger changes: manual110 plus CSV56, all166 assertions PASS with rollback. Exact source/log hashes are in `cube5-qa/root-affected-time-regression.json`. This is finite backend evidence, not whole-Cube5 acceptance or frontend startup.

The isolated branch is `codex/cube5-adam-channels-mobile`, based on Cube4 SHA `ed26e49a9b1b577952a484bc55083bb6c41fb25e`, Tree `f6825f35b9f938e26b831edda42178e475047b1d`. Root owns the local checkpoint commit; code/test source hashes are unchanged from the executor final109 manifest.

Owner-requested consultation used the local claude-delegate read-only relay, Claude Code2.1.239 and the existing configured AgentRouter api_key_helper authentication, exact model `claude-opus-5-5` and requested effort `medium`. Provider returned HTTP403: token not authorized for that model, request `20261004223712104651870vknvfXXnSX3B9`; zero tokens and zero recorded cost. Model execution/effort acceptance was not verified; no substitute, credential/subscription change or retry after provider denial occurred. Exact result is `cube5-opus-design/authenticated-run/result.json` and `cube5-opus-design/availability-decision.json` outside this worktree. Employee drafts remain untracked/paused; broad platform UX review was not launched.

Checkpoint health at15:04:30UTC: four preserved synthetic Auth actors with empty unusable passwords, no sessions/refresh tokens, no Cube5 transport roles, two synthetic employees and zero retained source/canonical punch events. Terminal cancellation and source-version history are retained. No Auth/REST/Next/browser services were created, so runtime retirement is unnecessary at this checkpoint. Source/QA/evidence and the accepted Cube4 branch are preserved.

## P1 pending capture context delta

Forward migration `20261004151828_cube5_mobile_context_binding.sql` binds a new pending attempt to the trusted Employee, employment, assignment, Site, mobile source and effective Time policy identity/version. Source configuration version remains separate, preserving `policy_changed` for a same-source configuration update. The receipt freezes this context. Capture follows the existing tenant/People row-lock protocol and recomputes its selected context after blocking locks before writing evidence.

A persisted receipt is looked up before rejecting a stale current context. Exact original payload/scope replay and receipt reconciliation remain available to the same currently authorized actor and active EmployeeUser link after an assignment/source change. A different current link cannot access that prior receipt. An unsaved old-context attempt is rejected without silently changing its Site/source.

The focused public API suite `supabase/tests/cube5_mobile_context_binding.test.sql` passed **30/30** assertions with rollback. It exercises an actual public People A-to-B effective transfer where both mobile sources are version one, same-assignment Time policy changes, source configuration changes, legitimate prior receipt replay/reconciliation, exact event/punch cardinalities and frozen provenance. The prior-day A receipt fixture uses the real canonical gateway and respects the existing guard against transferring a materialized current workday.

`scripts/cube5-context-binding-concurrency.mjs` passed **2/2** actual two-session races, with lock waits observed in `pg_stat_activity`: queued A capture versus the public People transfer rejects `scope_changed`; queued B capture versus a source policy update rejects `policy_changed`. The retained fresh f9 fixture has two empty-password synthetic actors and zero source events/canonical punches. Run01 used an inverted fixture lock order and deadlocked; run02 rolled back setup on a retained synthetic email collision. Their raw logs and exact executed runner copies/hashes are preserved. Both were fixture failures; production SQL remained unchanged. Run03 uses the existing tenant-before-employment/source order and unique f9 emails.

Evidence: `cube5-qa/p1-context-api-run-01.log`, `cube5-qa/p1-context-concurrency-run-03.json` and `cube5-qa/p1-context-source-manifest.json`. The manifest binds the forward migration, focused SQL, reused fixture, final concurrency runner, this register and distinct raw logs; the API runner uses the same literal fixture-inlining method described above. `node --check` and `git diff --check` passed. Prior109/166/3 suites were not repeated for this narrow delta.

Frontend remains paused and startup/browser acceptance remains unqualified. Root's owner-requested official local Claude Code preflight found no existing first-party CLI authentication when excluding the AgentRouter user configuration; no model request, login, provider/configuration change or fallback occurred. This backend delta does not close Cube5 or its outstanding UI/vendor/privacy/physical-device gates.
