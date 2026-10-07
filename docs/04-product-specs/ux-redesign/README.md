# UX redesign: coverage and journey specification

Status: **Proposed; not Frozen; no full-coverage acceptance claim**. Source snapshot: `6bfd604e4015de13db922b1d17466222fda8672e`; accepted Cube5 commit `3a310d25c91a84eda52a47cf0491c5a235933a31` is an ancestor, not this branch's current tree.

Read these together, in order:

1. [Binding review corrections and coverage gates](coverage-contract.md).
2. [Claude Opus 5.5's preserved contribution](claude-opus-contribution.md): R0–R8 stage scopes, acceptance scenarios and initial maps. This is an immutable review input; the corrections take precedence.
3. [Codex journey maps](journey-maps.md): tasks, roles, decisions, service effects, recovery and cross-domain paths.
4. [Codex source review](codex-source-review.md), [machine inventory](inventory.json), and [review register](review-register.json).
5. [Original reference guide](../../../05-engineering/ux-redesign-reference.md), [issue #47](https://github.com/delightfactory/business-platform/issues/47), and [live Concept C demo](https://business-platform-ux-concept-c.delight2025.chatgpt.site/).

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

Run `node scripts/build-ux-inventory.cjs` after installing the repository dependencies to regenerate source inventory. Do not overwrite manual reviews to hide drift. Run `node scripts/verify-ux-coverage.cjs` to audit fingerprints/assignment, and add `--require-reviewed` for the fail-closed semantic freeze gate; `--phase R2` limits that gate to a stage including its shared request boundaries. The current register deliberately marks every item pending: targeted review of a finding is not complete review of its entire source item. This source-level gate cannot independently prove valid operation/state expansion or executed scenarios; those require the contract's separate reviewed evidence.
