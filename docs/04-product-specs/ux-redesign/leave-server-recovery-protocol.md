# D16 local server recovery protocol review candidate

Status: Proposed technical contract; owner approved scope on 2026-10-08. No migration, server table, new RPC or production operation implemented. Source d9efa4ea1598d672b90800de20b107732763df80; application source unchanged from 1057d492324031a760d7fed2979f9fc4dab8b87e. This supplements leave-unknown-recovery-spec.md, not a substitute for its complete acceptance matrix.

## Complete journey

Employee deliberately sends one immutable leave intent. After response loss, refresh, tab loss or reauthentication, read-only discovery offers the original attempt, then an explicit retry or authoritative closure. It never automatically resends, recreates a request, grants HR scope or infers no commit from absence/time. All three operations are covered: submit, withdraw, request cancellation of approved leave. Current records and historic receipts remain separate; approved cancellation is pending a decision, not financially reversed by preparation/recovery.

## Identity and transactional boundary

Preparation binds authoritative auth.uid(), tenant, employee and, for submit, employment and employer; actor/employee observations from existing options/detail are expectations, never authority. A changed account or same-user employee relink rejects execution without exposing the old payload. Recheck current operation entitlement/permission and current own-view authority for disclosure. Knowing an opaque UUID confers no access.

Existing submit locks employee before link and employment/employer before the legacy key lock. Do not add link-before-employee locking. Candidate execution obtains one per-attempt transaction mutex before original domain locks; close obtains that same mutex and no reversed domain locks. Every callable route that can execute this prepared intent must obey the fence. Deadlock/serialisation abort is not proof about an earlier uncertain attempt.

Expected identity must be enforced within the writing transaction. Candidate choices require source and SQL verification: either insert the check at the already-locked original identity point, or validate the original returned request's employee/employment in the same transaction and raise to roll back mismatch. The latter is safe only if every side effect is transactional and complete result identity is available for all three operations. A preflight-only comparison is insufficient. Do not accept a partial result check as atomic binding proof.

## Fence and legacy compatibility candidate

Use a server-only reserved operation-key namespace such as leave-attempt:<uuid>, distinct from existing nonreserved legacy keys. Clients use an opaque attempt UUID with new functions, never pass prepared payload to a legacy mutation. Public legacy request/event mutators reject every key in the reserved namespace. Execution may invoke a revoked private implementation under the attempt mutex; it must not call the rejecting public wrapper. Existing nonreserved keys retain existing semantics, grants and signatures. No namespace name or wrapping technique is Frozen yet.

Before implementation inventory public request creation, withdrawal, rejection, preview refresh (including own halfday preview), approval, cancellation request/decision/approved cancellation, correction, and any cross-stream replay path. Confirm helpers are not callable by PUBLIC/anon/authenticated/service_role. Source-built dynamic halfday rewrites and later replacements must be preserved, not recreated from an older function body. A blanket rewrite of unrelated configuration/balance APIs is not authorized merely for convenience.

Unknown or retired reserved IDs always refuse execution; they must never fall back to a legacy request. This makes deletion of temporary registry payload possible without allowing a delayed original call to bypass a closed fence. A missing/retired reference alone cannot be described as closed-without-commit: a prior committed receipt may have been retired. No forced refresh, new key or restart on that inference.

## States and calls

Prepare POST validates/canonicalizes fields and saves immutable intent; it does not create a leave request. Preparation itself must be idempotent under the original form operation identity, including response loss before the browser obtains the server reference. Retries must not create competing intents from edited fields. Discover GET is authenticated, own-scoped, paginated and strictly read-only; no cleanup or closure side effects. Return minimal safe metadata for a deliberate choice and preserve authority checks before returning any HR detail.

Execute POST locks attempt, validates identity and current authority, rejects closed/retired attempts, reuses its canonical payload and existing business operation, then atomically records committed minimal receipt. Rollback must leave no partially committed intent/leave changes. A later denial does not release previous uncertainty. Committed retries return historic evidence only under current disclosure authority; current detail is a separate read.

Close POST locks attempt; return committed receipt if already committed, otherwise atomically set closed_without_commit before reporting it. A waiting original execution must subsequently reject closure. Distinguish canceling a prepared attempt from withdrawing a submitted leave request. Owner-approved capability does not approve a new financial transition.

## Privacy and retention review required before code

Private schema/table, RLS and revoked direct grants, authenticated least-privilege SECURITY DEFINER RPCs with empty search_path and fully qualified objects. No service-role browser path. Existing leave reason/dates are Confidential; temporary unsubmitted intent introduces a different retention purpose, not permission to retain indefinitely. No HR fields, payload/hash, auth/session values in browser persistence, logs, telemetry, issue evidence or public repository. HTTP/UI caching must not create a secondary payload store.

Terminal commit/closure should erase temporary canonical HR fields atomically and keep only the minimum operation/identity/result references needed for recovery; do not duplicate full legacy result JSON containing HR data in a second permanent store. Existing immutable leave audit remains untouched. Discovery after erasure must still provide a safe useful continuation, not expose stale detailed payload.

Pending exact decisions: purpose-bound lifetime of unexecuted intent and terminal metadata, bounded expired-attempt fencing/cleanup ownership and schedule, old-but-authorized receipt discovery after registry retirement, denied/relinked-user handoff, concurrent preparation deduplication and caps. No arbitrary TTL, speculative cron job or automatic global retention policy is adopted. Review these against data-classification-and-privacy.md and security-baseline.md before freezing SQL implementation.

## Qualification

One consolidated synthetic local SQL suite must cover actual transaction/concurrency paths: prepare response loss/deduplication, original execution racing close, replay after state changes, rollback on identity/link change, wrong actor/tenant/disclosure denial, direct reserved legacy bypass, retired references, retention erasure, and halfday/cancellation semantics. Mock/static tests do not prove those properties. One related action/client/build batch after SQL contracts settle; reuse unchanged prior evidence. Then fresh-page/browser recovery and reference-aligned rendered controls at scoped viewports. Codex and official Claude Opus 5.5 Medium separately review journey, coverage, security and Concept C. Currently both NOT VISUALLY VERIFIED; no numeric simplicity gains or full R6/R0–R8 closure claimed.

Official documentation checked 2026-10-08: https://supabase.com/docs/guides/database/functions (definer search_path and explicit execution grants), https://supabase.com/changelog.md (fetched via HTTP after browser markdown content-type limitation). Recent platform/framework releases do not authorize dependency changes; PostgreSQL minor-upgrade notices require qualification against the actual local engine when SQL testing starts. No dependency/database upgrade performed.

## Independent review and Codex corrections

Official Claude Code 2.1.292, claude-opus-5-5 Medium, session c55e4191-b2e2-417d-b18c-c2c1342bee60 returned conditionally sound, NOT READY FOR SQL. Read-only verification found no change relative to the pre-existing two-file dirty baseline; touchedFiles reports those baseline paths, not two edits by Claude. Selected evidence and original brief are archived; account/configuration/raw events are not.

Accepted technical directions: unique tenant+actor+original form UUID preparation identity with immutable canonical-payload conflict; expected identity checked explicitly at the original locked identity point rather than relying on transaction-local settings or incomplete returned JSON; enumerated wrapper/helper/caller/overload grants; current execution/disclosure authority; final-key namespace checks on transformed paths; real SQL concurrency/retention qualification. Private functions must explicitly revoke default PUBLIC execution in the same migration. Do not change global default privileges or introduce a session-setting bypass.

Codex corrections to the reviewer, required before implementation:

- A read-only open state is not proof of no commit and cannot settle an in-flight original execution. Read discovery truthfully reports unresolved; only the same-lock close transaction can return fenced no-commit. An expected SQL abort proves only that invocation rolled back, never the outcome of an earlier uncertain invocation.
- Reserve an exact internal key syntax and validate/reject final keys consistently. Unicode/case normalization or registry lookups do not replace final-key fencing, and adding a registry check after existing domain locks can create a reverse lock order. No broad legacy-key normalization change is adopted. Existing keys are case-sensitive under existing replay semantics.
- A fresh nonreserved legacy key is a separate operation. This protocol fences the same prepared attempt, not all similar business intentions. Do not silently retire old own RPCs or claim universal duplicate prevention. Newly redesigned forms must discover/recover unresolved prepared attempts before offering a fresh write, with backend source-authoritative rules for competing prepared intents; direct legacy callers retain their existing guarantees. Any legacy retirement is a separate amendment.
- Erasing terminal temporary payload does not prevent recovery of a committed request: its minimal receipt links to existing authorized detail. A closed uncommitted attempt may require deliberate re-entry after tab loss; choose a bounded safe reconstruction policy before claiming context preservation, never extend confidential retention until acknowledgement indefinitely.
- Denied state must offer a useful authorized handoff/return path with prior uncertainty visible; an empty primary action is not an accepted dead end. No expanded receipt permission after employment/role changes is adopted by this review; retain current authority and explain denied recovery.

Codex verdict: CHANGES REQUIRED before Frozen SQL contract, matching Claude's not-ready status with these corrected limits. D16 scope approval remains effective. Remaining technical decisions are exact lifetime/cleanup and receipt policy, conflicting-preparation handling, locked identity injection, complete final-key/caller inventory and lock-order proof. This review is not application code, concurrency evidence or visual acceptance.
