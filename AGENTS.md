مرحلة التحول البصري (ux/visual-concept-c) تعمل وفق docs/07-execution/ux-visual-concept-c-brief.md وdocs/07-execution/ux-visual-concept-c-plan.md؛ الحوكمة فيهما تتقدم لهذه المرحلة فقط.

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

## UX redesign reference

Before each UX redesign slice, read [the execution reference](docs/05-engineering/ux-redesign-reference.md), its pinned Claude plan, and the compatibility review. Open the corresponding demo view. Treat the demo as a visual reference with simulated data, not business logic or authorization. Record intentional deviations in issue #47 and amend affected specifications before expanding scope. Preserve the original reference files and their hashes.

## Mandatory theme and component reference acceptance

The owner explicitly requires Codex AND official Claude Opus 5.5 Medium to verify theme, components and design against the pinned Concept C reference in issue #47 throughout implementation. Apply [the design reference acceptance gate](docs/04-product-specs/ux-redesign/design-reference-acceptance.md) to every related UI batch. Record separate Codex and Claude verdicts, version-bound rendered evidence and deviations with approval status. Source checks alone never prove visual fidelity. Reuse unchanged evidence and review related changes together in economical mode. Pending amendments are not accepted deviations; preserve the current authoritative contracts while their replacements are undecided.

## Mandatory user journey improvement

Every plan, implementation slice, and review must simplify and improve the complete user's task. This is an explicit owner requirement, applying to Codex and every delegated implementer/reviewer, including Claude. Read [the journey improvement contract](docs/04-product-specs/ux-redesign/journey-improvement-contract.md) and [coverage contract](docs/04-product-specs/ux-redesign/coverage-contract.md) before starting. Include this requirement verbatim or by linked self-contained excerpt in each delegation brief.

State the actor, job, entry, successful outcome, required choices, failure/recovery and next step. Identify unnecessary decisions/navigation/context re-entry and reduce them within approved business/security constraints. Measure a defined before/after baseline; do not present assumptions as measurements. Keep one clear primary action per state, progressive disclosure, readable Arabic/RTL, accessible mobile/keyboard behavior and preserved safe inputs/context.

Reject a slice with a dead end, hidden necessary capability, misleading success, unexplained disabled action, lost entered context, or cosmetic simplification that removes validation/authority/financial safeguards. An unchanged efficient path may be preserved with evidence and rationale. Coverage and simplicity are separate acceptance gates. Proposed maps are not Frozen specs or passed runtime evidence. Do not expand behavioral changes without the relevant accepted specification/amendment.
