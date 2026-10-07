# R6a — own profile and complete employee leave journey

Proposed, not Frozen. Source baseline `f2a50a8692d7dd97ec758c7bce34cbc8f17e8370`; original Cube5 ancestor retained. This contract expands the R6a employee path; R6b HR decisions/settings/balance administration and the R0–R8 goal remain required, not excluded from the overall redesign.

## Denominator and review scope

18 source files,48 inventory items,10 distinct literal RPC names and10 coarse RPC operation seeds; not a count of every supported user task. `employee-leave-scenarios.json` binds file hashes and inventory IDs and lists160 DRAFT partition labels. File-level association is automated; item-level semantic expansion, exact parameters, expected feedback, SQL internal dependency analysis and independent acceptance remain incomplete.160 is NOT a test count or complete scenario coverage. The global registry stays1523 pending semantic items with existing manual states preserved.

| Operation | Existing service | User-facing task |
|---|---|---|
| PROFILE | tenant_my_employee_snapshot | Read own linked employment profile |
| ACCESS | leave_access_snapshot | Determine read/create/cancellation availability; do not grant permissions |
| BALANCES | leave_my_balances | Read recorded balances with independent paging |
| REQUESTS | leave_my_requests | Read current own requests and open one |
| DETAIL | leave_my_request_detail | Read immutable status, reason, units, day breakdown and correction links |
| HISTORY | leave_my_cancellation_history | Read current cancellation and paged events |
| OPTIONS | leave_my_request_options | Load eligible types for selected dates, read-only |
| SUBMIT | leave_submit_own_request | Send a reasoned version-aware idempotent request, not approve it |
| WITHDRAW | leave_withdraw_own_request | Terminally withdraw a submitted unapproved request |
| CANCEL | leave_my_request_cancellation | Ask HR to cancel approved leave; await its decision |

## Complete journey and handoffs

Current presentation gate matrix (not one universal ACCESS gate):

| Surface | Actual source gate |
|---|---|
| Own list visibility | SDK/user then self_access=true |
| List create link | self_can_request=true AND new_work_enabled=true, after list access |
| New request page | self_access AND self_can_request AND new_work_enabled |
| Request detail | own-detail RPC result; current request state decides read presentation |
| Withdraw form | request.state=submitted only; RPC rechecks own link and leave.self.request |
| Cancellation form | approved + readable history without latest pending + self_can_request; no separate new_work_enabled UI condition |

The UI blocks a new cancellation when its latest authoritative event is pending and hides it when history fails. SQL request_cancellation_internal also rejects pending cancellation; its public wrapper passes employee-mode=true. A new-work-disabled presentation can still expose cancellation; do not add a new gate by analogy to create. Missing/unlinked/ended employee and multi-role employee+HR/owner cases must use actual self-service authorization and routes, never elevate to HR commands.

Employee enters existing `/me` profile or `/me/leave` directly or through the current workspace. Profile is read-only; requests and balances are independently paged. Opening one request provides current server state, authorized original/replacement links and optional day detail (30 items/page). Cancellation history is separate (50 events/page); `latest_event` drives pending status independently of the page being viewed. Do not treat the actor label or tenant branding layout as an authorization boundary.

New request: access and capability gates -> choose dates -> load actual eligible types -> choose type/eligible half-day -> reason3–500 -> send once -> current own detail. Calendar span up to732 inclusive is not charged units. Versioned employment/calendar/type/year-period/queue eligibility, day basis and units remain server-authoritative. Safe fields/key remain only in the mounted component; no new browser storage. Retain an efficient existing step only with evidence; do not invent click/input reductions from the plan.

Submitted request: inspect current state -> supply withdrawal reason -> expected-version/key-bound withdrawal -> read current withdrawn state/audit. Approved request: inspect latest cancellation/history/access -> reveal cancellation reason form -> send cancellation request -> remain approved while HR decides. Existing pending cancellation blocks another request; rejected cancellation may allow a new request subject to RPC authority. HR acceptance/rejection/direct cancellation and attendance/time-reconciliation effects are R6b handoffs needing their own authority/financial/runtime evidence.

Failures: preserve safe inputs/key on returned action errors; manual options retry is read-only. Unknown mutation result must be reconciled before changing input/key or assuming success; a same-key unchanged retry is not proof that nothing committed. Session recovery D8 remains pending/unapplied. Reloading generates new page keys and may lose drafts; do not endorse reload as universally safe after unknown writes. Domain permission/link/tenant/queue changes require RPC checks at action time even if the entry page was allowed.

## Current findings and grouped work

Rejected, withdrawn and cancelled records remain read-only: inspect reason/history/current status then return to own list; starting another request is a distinct currently authorized operation. After HR accepts cancellation, detail follows cancelled state and displays cancellation history/time-reconciliation information; it does not auto-create a replacement or assert attendance reconciliation finished. Historical original/replacement destinations can be missing/forbidden/cross-scope; target RPC authority must deny safely and provide own-list return, never leak another employee/tenant's record.

All three current mutation actions locally require a trimmed reason3–500; this is checked in source for each action, not copied from the submit demo. Selected SQL source confirms withdraw state=submitted/version check -> state=withdrawn event/result and same-key replay path; cancellation approved/version/pending checks -> pending event/result; latest snapshot exposes the three distinct flags. These are source facts only. Their helper dependencies, applied database behavior, concurrency/financial/runtime acceptance remain open; "immutable" means displayed server-owned snapshot, not a claim that the database row never changes.

Arabic/RTL acceptance explicitly includes bidi-isolated dates/units/identifiers, mixed Arabic/Latin reasons, period ranges, Arabic labels/status text and pager meaning. Keyboard paths cover entering disclosures, reaching the reason form, disabled controls, returning to list and post-redirect feedback/focus. Withdrawal currently has a reason form, not an assumed extra confirmation dialog; changing confirmation behavior requires its own reviewed contract. In-memory retention alone does not imply a complete safe session/unknown-write recovery path.

- **R6A-F1, priority:** list success toast trusts URL `state` alone. Detail correlates `submitted/withdrawn` to current state and cancellation to current latest pending event, but URL correlation still cannot prove this visit caused the action. Group truthful current-state notices, forged/stale hints and authoritative row/history readings; no URL-only celebration.
- **R6A-F2, priority:** history failure says nothing changed, which cannot exclude a concurrent HR decision. Read failure must describe inability to refresh/currently verify state, preserve available details without calling them fresh, and expose a safe read-only retry. Review list failure copy for the same inference.
- **R6A-F3:** withdraw accepts any object response before redirect; submit validates UUID, cancellation validates state=pending. Review latest SQL return/replay signatures before guarding exact results; false/malformed responses must not become trusted success.
- **R6A-F4:** thrown detail/history/access/list reads can escape Promise.all and suppress otherwise available sections; returned failures are partly handled. Define read-only partial availability and current-status trust before adding broad catches; never catch redirect/notFound control flow.
- **R6A-F5:** profile casts a general object to EmployeeSnapshot; weak detail/number/state/date guards may display malformed/unknown data. Do not interpret unknown state as an existing inactive or approved state. Review per-contract type/range/finite/domain guards and consumers as a related batch.
- **R6A-F6:** one clear primary task per state, no redundant empty-state create action, preserve both pagers/context, same-state visual reference comparisons and actual-parent layout. Full layout/modal rewrite still requires the corresponding specification. Existing action alignment offset is inherited, not introduced by input repair.
- **R6A-F7:** mid-action session expiration, partial/unknown submission, keyboard status announcements, input retention across safe recovery and scope changes need explicit paths. No privacy-sensitive draft/session/access changes without their amendments and authorization.

Order: F1/F2 truthful state+read feedback with grouped source/page characterizations; F3 result integrity after SQL contract review; F4/F5 partial availability/guards; coherent F6/F7 journey and matching-state visual qualification. Carry each finding into applicable exact scenarios before accepting the change. Do not let bounded fixes replace coherent full R6a or R6b execution.

## Evidence and acceptance

Reuse source-qualified R6-INPUT-RECOVERY-01 15 controlled cases and unchanged historical Cube evidence only within their actual scope. Existing build/TypeScript pertains to that exact source snapshot; this documentation batch needs structural integrity checks, not another build or SQL/Auth suite. No new services, sensitive access or production changes.

Concept C pinned HTML hash `AF24015383285EAF543E9C95839F55225C2FE9817DD8B1E16D2084F857725508`; original plan and compatibility guide govern. Simulated optional note, balance arithmetic and modal are not business authority. Existing accepted Cairo/40desktop/44mobile/radius8 and stronger control border are recorded compatibility differences; replacements require amendment. Current same-state visual match is NOT VISUALLY VERIFIED. Light samples do not qualify dark mode.

Before phase acceptance: expand item-specific source/SQL dependencies and actor/scope/result partitions; independently review/freeze material changes; implement the coherent journeys; measure defined before/after N/C/P/I/B on valid realistic tasks, including failure/recovery; independently qualify exact-version UI/keyboard/roles/business/financial/security outcomes; verify preserved source and remote identity. Screenshots/mocks/docs never close these runtime gates alone. Missing environment/owner decisions remain named gates rather than assumed success.
