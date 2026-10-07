# R5a employee attendance journey contract

Status: Proposed, not Frozen; implementation and stage acceptance remain open. Source: 233a616439820f13b6c22187172af37767cc302a. Read with coverage-contract.md, journey-improvement-contract.md and employee-attendance-scenarios.json. The 46 partitions are source preparation, not 46 passed tests or exhaustive SQL/state/role coverage.

## Job and end-to-end map

Actor: authenticated employee with tenant-bound attendance.self.capture and current employee link. Job: deliberately record the server-selected next movement, understand its result, or resolve a previous unknown attempt without duplication. Entry remains /tenant/[tenantId]/me/attendance. Profile/leave permissions do not imply attendance permission.

~~~mermaid
flowchart TD
 E[Existing attendance route] --> A{Session and snapshot}
 A -->|missing session| L[Login; safe return gate D8]
 A -->|denied or failed| F[Explain cause; supported retry or responsible contact]
 A -->|valid| H[Read tab pending receipt after hydration]
 H -->|invalid storage| X[Block new capture; responsible contact]
 H -->|pending id and scope| V[Verify previous attempt]
 H -->|none and available| P[Deliberate attendance or departure]
 H -->|none and unavailable| U[Explain why new capture unavailable]
 P --> G[Location if required; store receipt before sending]
 G --> R{Authoritative response}
 R -->|accepted or duplicate| S[Honest result; refresh current snapshot and history]
 R -->|rejected| T[Explain result; explicit prepare new]
 R -->|unknown or other blocked| V
 V --> R
S --> A
 V -->|missing same-scope attempt| C[Server confirms cancellation under existing contract]
 C --> T
 T --> A
~~~

Important: verification invokes attendance_mobile_attempt, which can insert a durable cancellation for a missing same-scope attempt. It is not a read-only polling promise. Refresh and preparation are not new capture. The map omits detailed reason branches only for readability; scenario records and source contract control them.

## Source authority and visual interpretation

Three RPC sites: attendance_mobile_snapshot, attendance_mobile_punch, attendance_mobile_attempt; two public server actions; four conditional button controls in MobilePunch. The shared attendance-channel helper also serves HR/channel journeys: no helper change without R5b impact review. Tenant layout/navigation and request boundaries remain independently inventoried, not accepted by this contract.

Concept C employee view was opened on 2026-10-08. Adopt its clear dominant attendance task, contextual result and secondary history. Preserve existing routes and deliberate accessible button. Defer slider/hook extraction/release exposure and /me home integration as required by the compatibility review. Do not display simulated shift times, inside-radius claim, accuracy, elapsed duration, annual21-day balance, pay slip, or notifications from fields this snapshot does not supply. No new RPC, role inference, GET mutation, GPS prefetch, service worker, queue, persistent location or automatic retry.

## State presentation for the future implementation batch

| State | Dominant task | Truthful heading/feedback |
|---|---|---|
| Hydrating | Wait; capture disabled | جارٍ التحقق من المحاولة السابقة… |
| Busy / refreshing | Wait; no concurrent action | Use actual announced operation; do not call it ready |
| Pending valid | Verify | محاولة سابقة لم تتأكد نتيجتها; exact memory resend secondary only |
| Pending unreadable | Responsible contact | تعذر قراءة المحاولة السابقة; no enabled new capture |
| Terminal | Explicitly prepare new | Review terminal reason; preparation does not send |
| Unavailable without pending | Responsible path | التسجيل غير متاح الآن; existing mapped cause |
| Ready and available | Server-selected in/out | تسجيل الحضور / تسجيل الانصراف; no inferred shift claim |
| Accepted needing review | Review outcome in history | سُجلت الحركة وتحتاج مراجعة المسؤول; never approved |

Existing heading says ready to record attendance even during hydration, pending or unavailability. Correct this state contradiction and group site/cause/status/action before history in a single related presentation batch. Preserve disabled/flight logic, storage order, unchanged exact retry payload, terminal controls and GPS policy. Provide a workspace return for the existing missing-client early branch. Do not turn missing snapshot data into ready defaults; shape validation requires a reviewed fail-closed amendment, including preserved unknown result.

## Supported source outcomes and recovery

Accepted/duplicate release local receipt and refresh; review=true takes precedence over normal success. Rejected releases and permits separate preparation. blocked scope_changed releases and explains inaccessible previous link; other blocked outcomes retain pending. Unknown transport or 20s response timeout retains the same pending and complete memory payload. Reload restores only id/scope and permits verification, never payload resend. Storage write failure prevents submit. Location denied/unavailable/timeout sends null evidence under current server reject/review policy; unexpected serialization failure sends nothing. Reason text does not prove payroll processing or shift closure.

Action-side36-character ID checks are permissive, not strict UUID validation. RPC data is cast without full shape guards in both actions and page. Malformed snapshot/result, SQL role/date/concurrency, missing-link reason, policy/assignment changes and historical corrections must be explicitly covered before freeze. Read source migration20261004151828_cube5_mobile_context_binding.sql with later snapshot extensions; inspection alone is not database qualification.

## Economical evidence and acceptance plan

Before/after metrics not yet measured. Same actor/synthetic data, entry and goal at390/768/1466: measure N navigation, C repeated context selection, P competing primary actions per state, I manual inputs, B recovery; include pending after reload and terminal preparation. Target: remove contradictory ready headings and make one next action understandable while retaining every required operation; do not claim fewer inputs when unchanged or replace server authority with client estimates.

One focused real component/state harness for hydration/storage, capture/location, response/timeout/reconcile and terminal transitions; one related page fixture batch for snapshot/history/failure states; one lint/type/build after the complete presentation batch. Stub component cases are not real permission/GPS/provider/DB acceptance. Reuse fingerprint-matched Cube5 SQL evidence after inspecting its actual scope; do not re-run broad SQL suites for unchanged presentation. Add targeted DB/device tests only for invalidated or uncovered contracts, with required access authorization. Real browser keyboard/focus/RTL and390/768/1466 evidence remains necessary where UI changes.

Each review returns task completion, capability/state coverage, simplicity measurements, recovery, responsive/a11y, preserved invariants and next action. Author cannot solely accept the stage. Owner freeze is required for material integration or control-contract changes. Full R5a/R5b and R0–R8 closure remain open.

## Cross-stage continuation

R6a profile is read-only; leave uses independent access, balances and requests. NewLeaveRequestForm's displayed calendar span is explicitly not chargeable units; current options RPC returns types/versions, not a live remaining-balance preview. Do not invent one while copying the demo bottom sheet. Continue R6a options/submit/withdraw/cancellation/detail/history partition review before its UI batch; these observations are not a completed R6a source/acceptance review. D2/D3 navigation decision remains pending; this R5a contract does not infer approval.

## Joint review corrections and readiness

Read employee-attendance-claude-review.md and employee-attendance-review-resolution.md together. Review identifies genuine recovery/privacy and action-result gaps. This contract is preparation, not an approved implementation batch. No receipt-discard control, logout/storage-policy change, new login destination, malformed-response normalization, slider or /me integration is authorized by the review alone. The next implementation package must resolve its applicable amendments before acceptance; cosmetic state copy must not be mistaken for closed recovery.
