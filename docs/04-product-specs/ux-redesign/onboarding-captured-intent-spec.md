# R3 onboarding: current-window captured intent

Status: proposed bounded recovery contract, pending official source co-review and implementation evidence. Base `92d48800dd0294c0e6b2367ccc239c00331efb17`. Part of remaining R3 B1/B2, not an extra backend project or phase closure.

## Task and authority

An independently granted active platform operator creates a company for an existing confirmed administrator, using the original company/legal/site/email/seat/site fields. Entry remains `/operator/onboarding`; success is the validated stored snapshot and the existing administrator continuation. The operator is never granted tenant-administrator authority by that link.

Existing SQL owns active/current-user/grant checks, normalized signature, `(actor,key)` replay lock, conflicting intent and atomic provisioning. Inspect the final `onboard_tenant` replacement in `20260929025717_first_admin_invitation_intent.sql:204–273`, its helper snapshot, and the original actor/grant/key-scoped `tenant_onboarding_result`. No SQL, new database RPC, grants, provider, storage or session policy changes.

## Scope and excluded expansion

- Onboarding-only client form and typed server outcomes; shared OperatorActionForm and other mutation contracts unchanged.
- Client captures its initial actor/key, then the exact original FormData in memory immediately before a mutation. No local/session storage, URL payload, new query protocol, account/session copying, reload persistence or automatic fresh key.
- Both save and explicit read recovery verify current identity against the captured actor with authenticated `getUser`, then existing SQL authority. The actor is a guard only, never sent as SQL authority. A changed actor never reads or submits the original attempt as another account.
- Preserve current JavaScript-required/disabled SSR/native POST contract. No progressive native mutation is newly disabled by this change.
- Reload/loss of the window does not preserve original intent. Existing key-based result read remains scoped to the account and is not universal commit proof. Cross-window/actor durable recovery or fresh-key escape requires separate owner amendment; do not claim it implemented here.

## State transitions and one next action

| State | Visible fields and dominant action | Safe continuation |
|---|---|---|
| Editable | Existing required fields, create company | Capture actor/key/original payload once at dispatch |
| Pending | Mounted fields disabled, progress status | In-flight lock prevents second submission |
| Confirmed source-named invalid/admin/limit exception | Retained editable fields with exact actionable error | Same key, deliberate corrected payload. An identical replay's source-named exception can also resolve uncertainty: admin checks are after the actor/key insert-or-replay, and rejection rolls back this transaction |
| Saved | Validated snapshot outside form; original admin continuation | No repeat write; existing separate new-company navigation only after saved receipt |
| Unknown/malformed/transport failure | Original fields mounted and frozen; read original attempt | No automatic write, new key or edited payload |
| Recovery read error/malformed | Still unknown/frozen, explicit read retry | Never treat as absent or enable editing |
| Same-actor, current-grant read returned null | Still original frozen payload; deliberately retry original attempt | Null does NOT prove universal no-commit. Only original identical actor/key/payload SQL replay is allowed, never editable/new request |
| Forbidden/actor changed | Original form remains frozen; re-read after original account/grant restored | No cross-account new authority or mutation |
| Intent conflict | Frozen, read original result only | No reload/rekey advice; mismatched snapshot cannot acknowledge this intent |

Read recovery is triggered only by the user. A null result is called “no saved result returned for this account now”, not failed/uncommitted: grant loss also yields null. The exact captured payload remains frozen through null/read errors; replay fully reauthorizes in SQL and never rebuilds from DOM or updated props. Actor mismatch is checked at render and in server actions. Ref/transition lock covers mutation and read; double clicks cannot issue two requests. The form is never conditionally removed on uncertainty; successful receipt changes task only after validation. Pre-RPC failures carry `mutationDispatched=false`: a previously editable attempt remains editable, a frozen attempt stays frozen, and identity/permission messages block submission until original identity/access is recovered.

## Result and error integrity

Use a pure consumed-shape contract shared by server actions and component. Comparison baseline is the JS-trimmed values actually sent (JS trim has wider whitespace semantics than PostgreSQL btrim), legal-name fallback, lowercase administrator email and strict limited/unlimited values. Validate source limits by code points and int4 max2147483647 before dispatch, with no new business defaults. The current provisioning helper explicitly returns `admin_email`, so receipt matching includes it, company/legal/site and modes/limits; usage remains server-authoritative, never recomputed or required below lowered limits. Accept the historically stored replay snapshot; never compare current globals or fabricate a returned request key. Preserve the existing administrator login/tenant continuation; no invented new snapshot route.

Known editable errors require their actual SQLSTATE plus explicit source-backed error name. All generic/unmapped RPC errors, unusable receipt, thrown transport failure are uncertain. Permission error and intent conflict are frozen, not safe editing/rekey permission. Auth/read errors never acknowledge success or absent; null needs confirmed current actor and current capability before the read. Setup/validation errors occurring before dispatch are distinguished from an RPC whose outcome is unknown. Never catch a Next redirect and reclassify it: this onboarding-only save returns a typed receipt instead of redirecting; shared redirects remain untouched.

Correction to the previous paragraph: current capability is enforced by the existing read's grant join, not a new advisory capability call that would race the read. A null read never certifies the grant remained active. Exact editable pairs are22023/onboarding_required_fields_invalid,22023/onboarding_invalid_limit,22023/onboarding_admin_not_found_or_disabled and22023/onboarding_admin_email_unverified. Frozen pairs are42501/platform_operator_onboarding_forbidden andP0001/onboarding_idempotency_conflict. Every other pair, including55000/onboarding_idempotency_incomplete and other42501messages, is unknown. These are source-authoritative distinctions, not proof of the applied runtime migration identity.

Official Opus5.5Medium co-design session `c6ecb1ac-387e-4e75-8724-6dca3a94dd82` supplied eight corrections. Codex verified helper email, current key read path and original continuation, and incorporated C1–C8 above. This is a source-reviewed current-window implementation contract; required mounted/runtime/visual acceptance remains open.

## Grouped verification and acceptance

One coherent batch: actual source action checks for identity/grant/input/error/receipt/null/replay, pure signature/shape cases and mounted form checks for double submit, pending/unknown/error/null recovery, unchanged captured payload, props/account change and visible saved acknowledgement. Reuse unchanged SQL/financial evidence; verify relevant replay/read source definitions, not rerun unrelated migration suites. One affected lint/appbuild/TS group, then only necessary deltas.

Record before/after same-actor/data/viewport recovery: no forced data re-entry or speculative duplicate creation. Source/controlled tests do not prove actual Auth/provider/SQL runtime or numeric improvement. Real-role journeys, mounted successful states, account restoration, full parent/reference and accessibility remain distinct gates.

Concept C has no operator onboarding screen. Preserve shared semantic light palette, Cairo, radius8 and existing desktop40/mobile44 controls. Both Codex and official Opus must review version-bound actual renders before visual acceptance. Prior browser `file://` refusal is a stop signal: do not attempt that operation or an indirect local-file workaround. Current full visual verdict for both: **NOT VISUALLY VERIFIED**. Public reference access or existing valid reference evidence is separate from claiming a new affected render accepted.

No R3/R0–R8 closure, deployment, PR/main merge, production change, D16 integration or payroll A/B decision is included.

## Candidate corrections and lifetime boundary

The actual boundary is the **mounted form**, not guaranteed survival of the browser window. If auth cookie updates, a parent permission/status branch, hard reload or navigation unmounts it, its in-memory intent is lost. Preserve server authority and do not keep an unauthorized form mounted to evade that branch. Native account-restoration qualification is still open; the fixture observed fresh GETs/state loss and does not prove the cause. Durable restoration needs the scoped owner amendment already excluded above; whole R3 cannot be accepted from the mounted boundary alone.

Official candidate review found two necessary fixes: malformed read snapshots now remain unavailable, and only well-formed nonmatching snapshots produce conflict copy. After a confirmed saved receipt, the existing “another company” route uses a native empty GET form to force a fresh server-rendered key even at the same URL; no private input is included. The fresh task is deliberate and unavailable during uncertainty. Clicking it must be qualified, not inferred from source.

## Implemented checkpoint

R3-CORE-ONBOARDING-01 SOURCE WIP from92d4880: Original actor/key/payload captured before dispatch; pending/unknown/read-error remain frozen. Explicit read of original attempt; null never proves no commit, only identical original replay available. Source-named SQL exceptions distinguish safe editing, generic errors stay unknown. Exact validated receipt controls success. Confirmed another-company native empty GET creates a fresh task without private query data. No new authority, SQL, storage, dependencies or global settings. 46focused source checks, ONEgroupedlint/buildTS and final2filelintTS PASS. Native synthetic unknown/null/identicalretry/saved,doubleclick1write,freshGETdifferentkeys PASS; realaccount restoration INCONCLUSIVE. OfficialdirectOpus5.5Medium finalsource accepted after B1/M1 fixes; BOTHfullvisual NOTVISUALLYVERIFIED.287files/351RPCsites/1179controls/1727items/prior19source-reviewed preserved/no semanticpromotion. Owned3611/tabs retired/resetviewport/syntheticcookie cleared. Evidence ux-core-onboarding-20261008. Full B1/B2/R3/R0–R8 remain OPEN. In-memory intent survives only while mounted; reload/navigation/auth or authority parent unmount may lose it. Durable restoration requires a scoped amendment. Actual account restoration native test INCONCLUSIVE; real SQL/Auth/roles/provider/full no-JS/full-reference/matched before-after/tablet/other states not accepted. Payroll A/B independent; D16 extras deferred until core complete.
