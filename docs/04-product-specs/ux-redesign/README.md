# UX redesign: coverage and journey specification

Status: **Proposed; not Frozen; no full-coverage acceptance claim**. Source snapshot: `6bfd604e4015de13db922b1d17466222fda8672e`; accepted Cube5 commit `3a310d25c91a84eda52a47cf0491c5a235933a31` is an ancestor, not this branch's current tree.

Read these together, in order:

1. [Binding review corrections and coverage gates](coverage-contract.md).
2. [Claude Opus 5.5's preserved contribution](claude-opus-contribution.md): R0–R8 stage scopes, acceptance scenarios and initial maps. This is an immutable review input; the corrections take precedence.
3. [Codex journey maps](journey-maps.md): tasks, roles, decisions, service effects, recovery and cross-domain paths.
4. [Codex source review](codex-source-review.md), [machine inventory](inventory.json), and [review register](review-register.json).
5. [Original reference guide](../../05-engineering/ux-redesign-reference.md), [issue #47](https://github.com/delightfactory/business-platform/issues/47), and [live Concept C demo](https://business-platform-ux-concept-c.delight2025.chatgpt.site/).

The owner's [mandatory journey improvement contract](journey-improvement-contract.md) applies to every stage and delegated review; it is imported by both `AGENTS.md` and `CLAUDE.md`.

## Stage scope and ownership

| Stage | Scope | Original wave | Exit requirement |
|---|---|---|---|
| R0 | Inventory, operations, scenarios, amendments, measured baseline | W0 | No unexplained coverage gaps for the slice |
| R1 | Tokens, shell, navigation, shared controls and boundaries | W1 | Preserve permissions and behavior; accessible responsive proof |
| R2 | Login, recovery, invitation/activation, tenant selection, users, entities and branding | W6 | Explicit identity, expiry, permissions and provider/record outcomes |
| R3 | Operator lifecycle, grants, commercial limits, entitlements and statutory | W6 | Authority and version/dependency cases preserved |
| R4 | People lifecycle/import, dated pay, assignment/policy, accounts | W6 | Date/version checks and separate creation/account/delivery/activation |
| R5a/b | Employee attendance; HR attendance, imports, classification and channels | W2/W4 | Unknown attempts reconciled; review-required is not approved |
| R6a/b | Employee profile/leave; HR decisions, cancellation, balances/settings | W2/W4 | Reason, preview and historical/payroll constraints preserved |
| R7 | Payroll setup, inputs, runs, candidate, deductions, advances, corrections, payments, exports/print | W5 | Every financial operation and recovery path independently reviewed |
| R8a/b/z | Gated Today/decisions; cross-domain journeys; final closure | W3/W7 | Amendments resolved; closure also enforced in every earlier stage |

Suggested order: R0 → R1 → R2 → R5a/R6a → R4 → R5b → R6b → R7 → R3 → R8. Stage IDs remain stable. An author cannot be the sole acceptance reviewer. Codex verifies source contracts and Claude co-designs/reviews the journey; independent review and owner freeze precede the affected implementation slice.

## Actual collaboration evidence

Official Claude Code 2.1.292, direct Claude Pro OAuth (`claude.ai` / `firstParty`), actual model `claude-opus-5-5`, effort `medium`. A tiny no-tools connection test returned `OK`. Claude's read-only session `33d9d8e5-a9a8-48f2-a8f1-139ad493302e` produced the contribution; the first turn limit was resumed successfully. Read-only change detection passed, no permission denials. Codex independently checked critical source findings and corrected the interpretation below. No credentials or account identifiers belong in this reference.

Global CLI/provider configuration was preserved. Invoke the isolated official runtime with `--setting-sources "" --safe-mode --model claude-opus-5-5 --effort medium`, after removing provider overrides only from the child process environment. Never silently substitute a model or route through a provider intermediary.

Current completeness: source assignment complete; semantic scenario review incomplete; execution coverage incomplete. A map is a review artifact, not proof of a passed journey. No new application implementation is accepted by this documentation.

[Financial recovery subjourneys](payroll-recovery-maps.md) extend R7. [Claude's second review](claude-joint-review.md) is preserved with its original blockers; [resolution record](joint-review-resolution.md) explains the applied corrections. These documents must be read together.

Run `node scripts/build-ux-inventory.cjs` after installing the repository dependencies to regenerate source inventory. Do not overwrite manual reviews to hide drift. Run `node scripts/verify-ux-coverage.cjs` to audit fingerprints/assignment, and add `--require-reviewed` for the fail-closed semantic freeze gate; `--phase R2` limits that gate to a stage including its shared request boundaries. Source-reviewed items are distinguished from fully reviewed cases and executed acceptance; source review alone does not release this gate. This source-level gate cannot independently prove valid operation/state expansion or executed scenarios; those require the contract's separate reviewed evidence.

## Bounded scenario expansion

[R2-AUTH-CORE specification](auth-core-spec.md) expands login/reset/password update/logout and the recovery callback into [61 source-review records](auth-core-scenarios.json), including 12 allowlist classes and 8 explicit thrown-failure paths. The [preserved Claude contribution](claude-auth-core-contribution.md) is interpreted through the reviewed corrections. 19 inventory items now have targeted source review; runtime acceptance remains not-run. The bounded source characterization script has 60 passing checks with provider SDK stubs, not live Auth or browser evidence.

## Implementation progress

[R1-LIGHT-01 shared visual foundation](r1-light-foundation.md) now implements the bounded reviewed W1.a palette on the Auth recovery branch lineage. Source inventory255 includes the new CSS token file; routes/operations/control IDs remain unchanged. Full phase qualification remains open. See the [execution ledger](../../07-execution/ux-redesign-progress.md) for completed slices and next gates.

## Recipient action preparation

Read recipient-actions-spec.md with recipient-action-scenarios.json and claude-recipient-actions-contribution.md. Nine public actions and94 draft source partitions are mapped; interpretation corrections take precedence. This is Proposed preparation, not Frozen/accepted or executed coverage. Existing manual review-register states are preserved.

Bounded maintenance contracts: [admin invitation context](admin-invitation-context-slice.md) and [member validation](member-validation-slice.md). Source-only/runtime boundaries are recorded in the execution ledger; these do not freeze the broader recipient/R2 contracts.

Outbound journey contract: [source-authoritative specification](outbound-invitations-spec.md), [90 draft source partitions](outbound-invitation-scenarios.json), and [immutable Claude contribution](claude-outbound-invitations-contribution.md). Seven actions/two helpers; full semantic/runtime acceptance stays open.
