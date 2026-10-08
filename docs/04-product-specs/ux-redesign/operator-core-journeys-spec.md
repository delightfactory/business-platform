# R3 remaining core: complete operator journeys

Status: **Proposed, source-reviewed preparation; not Frozen or accepted implementation.** Base `14049fe62ea9c56866443bca4fd9f9dbbd316117`. This is the remaining approved R3 work, not a replacement of R3 by DTO checks. Read with the coverage, mandatory journey and design-reference contracts, original plan §7.9, R3 journey map and R2 recipient/outbound invitation contracts.

The preserved official Opus contribution and correction checkpoint are in `../../07-execution/evidence/ux-core-operator-journeys-20261008/`. Corrections below override their proposals. The complete R0–R8 objective, real-role/runtime and visual gates stay open. Payroll A/B is independently pending. D16 and extras remain deferred.

## Actor and task map

An active platform operator works only within independently granted capabilities. Being an operator is not permission to manage another capability or to enter a newly created tenant as its administrator. Every journey is entry → actual task/company/account selection → current state → exact effect with required reason/version/attempt → verified result/current state → useful next task.

| Journey | Actual operations and preserved authority | Outcome and recovery |
|---|---|---|
| Company setup | Existing confirmed administrator, names, initial site, separate seat/site modes and values; onboard grant | Verified scoped snapshot; known invalid/forbidden/admin/limit/conflict states; ambiguous result stays ambiguous |
| Administrator invitations | Create, reissue, revoke; onboarding capability; R2 contracts apply | Provider acceptance, delivery recording and recipient receipt remain distinct; no blind resend |
| Operator grants | Grant/update/revoke; manage-operators grant | Preserve last-manager protection, self-revoke local sign-out and self-downgrade routing |
| Company lifecycle | Source-defined transitions; lifecycle grant; exact company/reason | Re-read actual state after uncertainty; no generic automatic mutation retry |
| Commercial limits | Seats/sites separately, limited/unlimited; commercial grant | Preserve dependencies/current usage and server reasons; current-state read is distinct from mutation success |
| Entitlements | Each of five unit keys, grant/deny/expiry; commercial grant | Preserve independent unit state, source dependency and evaluation; no invented journal |
| Statutory draft | New head or revision, dates, sources, numeric rules, reason, actor and attempt | Saved receipt or retained invalid/stale/unknown state; original same-attempt recovery |
| Comparisons | Existing source-supported comparison domains, current/older revisions, synthetic/official evidence | Matched is not qualified; preserve every persisted row and distinct source domain |
| Issuance | Current revision and evidence stamp, reason and reviewed confirmation | Immutable issued revision; `tax_insurance` receipt and `financially_qualified=false`; new revision requires new evidence |

Eleven public server-action seeds do not equal eleven operations. Capability flags must be strict `data === true` with no error. Active status must be exact `active` with no error. Read-error and denied outcomes are distinct; no optional capability failure may remove a separately authorized task.

## Source-chain corrections

1. **Onboarding definition:** `20260929025717_first_admin_invitation_intent.sql` replaces the initial `onboard_tenant` function. It validates current actor/grant, stores actor+key+normalized signature, locks duplicate receipts, rejects conflicting intent and returns the original snapshot for identical intent. Its provisioning helper defines the current snapshot fields. The original `tenant_onboarding_result` remains current-actor/grant/key scoped. It does not return a key field; never invent a required JSON key.
2. **Ambiguous onboarding read:** null does not prove universally uncommitted, unchanged grant or another account's outcome. Error or malformed result never becomes a success panel or a new creation form. An error offers current same-key re-read. A successful null read preserves the existing same-key form only with explicit current-account wording, no automatic rekey and no claim about another account. An invalid supplied key must not silently become a fresh request.
3. **Onboarding submission:** a returned `unknown` code alone does not freeze `OperatorActionForm`, preserve exact payload after edits, handle thrown transport uncertainty or bind a changed actor. This remains an explicit recovery design gate. Specify any onboarding-only captured intent/actor contract before code. Do not change the shared form's exceptions/redirect semantics. Persistence across reload, a new URL protocol, new storage, cross-account recovery or fresh-key path from ambiguity requires a scoped amendment/owner decision. No such behavior is authorized by this proposal.
4. **Issued readiness:** `statutory_issuance_readiness` returns `ready = blockers=[]` independently of `issued_pack`. Issued+ready is source-valid, never corruption. Issued state dominates and prevents another issue form. Offer an issue form only for strict true readiness, empty blockers/coverage and no issued pack. Contradictory readiness is an unavailable/unverified state, never a success or silently empty state.
5. **Patched comparison domain:** `20261003048000_cube4_reviewed_wage_deduction_composition.sql` adds `case_data.domain='labour_deductions'`, patches the comparator/current-case identity and extends readiness blockers. The original tax/insurance-shaped history parser is insufficient. Keep source-valid variants and unknown blocker codes. Backend readiness/qualification rules stay authoritative; this work adds no legal values or calculations.
6. **Historical receipts:** draft receipt lookup precedes head CAS, including the numeric overload generated by `20261002225319`. Validate against the original captured attempt's head/expected revision and payload, not subsequently refreshed props/global newest revision. A valid replayed historical receipt must remain acknowledged. Preserve existing `setDirty(false)` and request release on confirmed non-uncertain result.
7. **Numeric shape:** summary/editor consume `tax.columns[].bands[]`, `insurance.branches[]` and their primitive fields, not just top-level objects. Validate consumed structure before rendering/seeding an editor. Tolerate extra fields; do not duplicate arithmetic, legal thresholds or server policy. Never drop malformed history silently.

## Current-state and presentation contract

Selected `?head` mode cannot fall through into list/create mode. Verify requested/head/current head identity case-insensitively, positive integer revisions, current revision agreement, consumed fields, valid rendered dates and pagination shape. A history revision newer than the captured head or disagreement between independently read current revisions is stale: preserve context and offer a current-state reload. PT409 on release read is stale. Missing/malformed list rows are a read failure, not an empty list.

Comparison history is a source-discriminated union. Tax/insurance rows retain their current fields. Existing labour rows retain their name, source, origin, scenario, year, matched result, revision, expected/actual and claim detail without tax-property dereferences. Use human labels reviewed against source; never expose internal codes/IDs or invent legal qualification. Unknown variants remain visibly unavailable rows, not deleted rows or a falsely empty history. Invalid values must not become raw React children or unsafe links. Source URLs are HTTPS links only; other values are safe text.

Release status validates revision, stamp, strict boolean, arrays, counts, nullable pack UUID and exact scope/qualification. Tolerate source-defined later blockers through honest generic wording. No financial computation is replicated. Issue receipt validates pack UUID, original expected revision and exact scope/qualification; an unusable result remains uncertain under the same attempt.

## One dominant next action, complete capability

| State | Default dominant task | Preserved alternative/context |
|---|---|---|
| New draft or no numeric rules | Edit/save draft | All source-required inputs and reason remain available |
| Current rules, not issued | Review comparisons | Explicit secondary edit disclosure: a new revision needs new evidence |
| Dirty/pending/unknown/error edit | Save or recover original attempt | Mounted entered fields remain visible; comparison continuation becomes secondary |
| Stale edit | Existing current-revision comparison path | Keep entered values in existing window; no forced navigation/discard |
| Issued revision | Review issued state | Explicit new-revision task; immutable prior evidence remains accessible |
| Comparisons not ready | Add/review required comparison | Current blockers and source references remain visible |
| Comparisons ready | Review issuance | New comparison is a secondary deliberate task, with no loss of its pending/dirty/unknown state |
| Read failed/stale/unverified | Re-read current state | Preserve selected head/key and legitimate editing/recovery availability where source permits |

Default visible primary count is a state-level goal, not permission to hide operations or discard input. Forms retain stable identity/tree positions where changing props/revalidation could otherwise remount them. Forced-open behavior covers dirty, pending, unknown and errors, including nested numeric changes. A disclosure must not hide a pending outcome or silently close a user's active task. Issue-state read failures must not label a revision unissued or financially qualified. Failed read copy never says no mutation occurred.

## Implementation and qualification milestones

**B1 — one related implementation batch:** strict remaining entry/list capability checks; onboarding receipt/read integrity and scoped recovery design; workspace/history/release/receipt consumed-shape contracts; dominant draft/comparison/issuance steps; readable persisted comparison variants; truthful invitation list/selected-result failures. Prior company links, original financial/business SQL, invitation delivery and independent grants remain intact. Subparts are not full-R3 closure.

Before coding the history union, review complete current source variants and formulate human presentation labels. Before claiming onboarding replay, capture same actor, key, normalized intent and authoritative result. Any source-preserving routine implementation may proceed within existing authorization once its specification is ready; material persistence/authority/legal changes remain separate decisions.

**B2 — complete grouped journeys:** actual entry/read/change/result/continuation for each operation/role/state, using exact source-backed synthetic data in an isolated authorized environment. Include denied, account/session changes, stale, unknown, replay, expired/revoked, pagination and issued/history cases. SDK-stub/component observations do not prove real-role/Auth/SQL/provider acceptance. Never turn first-page data into global counts.

Focused groups: pure parser partitions; the twelve baseline page findings plus labour-variant failure; captured-action receipts and known-error mappings; dirty/pending/unknown mounted client behavior; capability/error matrix. Run one affected lint/build/TypeScript group at the coherent B1 milestone, then only affected deltas. Reuse unchanged financial/Auth/SQL/provider evidence; no heavy repeats for documentation or tiny text changes.

Record matched before/after N/C/P/I/B, task completion, wrong turns and safe value retention. Current observations establish defects, not improvements. No numerical claim before supported matched rendered runs.

## Reference and release gates

Concept C has no operator screen: shared semantic palette, cards, hierarchy, readable RTL and secondary controls guide the work, with actual authority taking precedence. Both Codex and official Opus must inspect actual version-bound affected renders and state their separate verdicts. Neither source review nor inherited cropped tablet/desktop captures proves visual acceptance. Current verdict for this preparation: **NOT VISUALLY VERIFIED** for both.

No application changes or tests are accepted by this document. Structural registry remains 281 files/1717 items with earlier statuses preserved; no semantic promotion. Full R3/R8 and complete real-role/cross-domain/visual/semantic acceptance remain open. No migration, production change, deployment, PR or main merge is included.

## Statutory implementation checkpoint

The statutory subpart of B1 is now implemented as source WIP, with69bounded source checks and focused synthetic browser observations. See [candidate evidence](../../07-execution/evidence/ux-core-statutory-20261008/README.md). Final C1 keeps existing forms mounted across no-rules/rules continuation changes and shows the saved acknowledgement outside disclosure. This does not freeze full B1/B2 or claim phase/runtime/visual acceptance; remaining onboarding, flags, invitations, wording and full journeys are unchanged gates.

## Entry/read implementation checkpoint

Source-preserving B1 subpart implemented in eight sources,76bounded source checks and one groupedbuild. See [candidate evidence](../../07-execution/evidence/ux-core-operator-entry-20261008/README.md). The confirmed snapshot controls success, selected identity is preserved, partial capability failure retains other granted tasks, unknown reads never imply empty/uncommitted/success. No new authority/storage/action protocol. Captured intent/actor/unknown mutation recovery and conflict/failed action copy remain OPEN; no shared form/action/SQL/storage protocol change. Pending unknown-delivery resend advice and invalid-id same-link retry carried. Complete B2 real role/Auth/SQL/provider/native/hydration/matched simplicity/fullvisual gates OPEN; no full B1/R3/R0-R8 closure. Payroll A/B independent; D16 extras deferred.

## Statutory completed-batch continuation

The existing statutory checkpoint is superseded for implementation corrections by the completed batch in ux-core-statutory-20261008/README.md and continuation-acceptance.json. Keep active issuance and new-draft results visible, capture fields before transition instead of automatic reset, clear audit reason only on known save, and promote receipt review after confirmation. Preserve all original actors/attempts/versions/RPCs/financial scope. Known denied/stale/unknown reads stay distinct and saved list rows never imply unissued. No new persistence/authority/SQL scope. Scoped source/reference frames accepted; B2 and full-phase gates remain explicitly open.
