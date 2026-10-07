@AGENTS.md

# Claude execution instructions

**Mandatory theme/component requirement:** co-review every related UI batch with Codex against the pinned Concept C in issue #47 using `docs/04-product-specs/ux-redesign/design-reference-acceptance.md`. Return an explicit independent visual verdict with exact evidence scope and deviations; without rendered images, state NOT VISUALLY VERIFIED. Keep reviews focused and reuse unchanged evidence.

Read `AGENTS.md` and `docs/05-engineering/ux-redesign-reference.md` before working on this project. Their repository constraints and the owner's explicit task govern this session.

**Mandatory owner requirement:** every phase, implementation and review must simplify and improve the complete user's task while preserving every actual supported function, permission, business invariant, privacy and financial safeguard. Apply `docs/04-product-specs/ux-redesign/journey-improvement-contract.md` and `coverage-contract.md`. Write the journey and failure/recovery paths before code. Provide measured before/after evidence and an explicit UX verdict; never treat fewer buttons or a finished backend as sufficient acceptance.

Use the original Concept C reference consistently; simulated demo logic is not application logic. Record justified deviations and amendments in issue #47. Respect Proposed/Frozen/acceptance distinctions. Do not commit, push, merge, deploy, alter provider settings or access production unless the current user's authorization explicitly permits the action. Delegated review sessions remain read-only and return exact unresolved gaps.
