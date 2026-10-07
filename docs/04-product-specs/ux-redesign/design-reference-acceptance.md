# Mandatory design reference acceptance gate

Owner requirement, 2026-10-08: Codex and official Claude Opus 5.5 Medium must verify theme, components and design against the Concept C reference pinned in issue #47 throughout implementation, alongside complete capability coverage and simpler journeys.

## Per related UI batch

1. Identify the reference screen/state and immutable source/version/hash using the execution reference guide. Capture reference renders from the pinned HTML; it takes precedence if the live site changes. Read the compatibility review and applicable specification before implementation.
2. Compare semantic colors/surfaces, typography, spacing, hierarchy, component geometry/states, responsive Arabic/RTL, keyboard/focus and accessibility. Check only theme modes actually in scope; never imply dark-mode acceptance from light-mode evidence. Tenant branding remains authoritative.
3. Record exact candidate hashes and representative before/after renders for affected states at mobile and desktop widths. Include tablet when layout changes there. Cover affected pending, disabled, hover, focus-visible and error states with matching viewport, RTL, loaded fonts and synthetic data; record browser/version. Reuse unchanged, version-bound shared evidence rather than repeat whole-app checks.
4. Record deviations in issue #47 and the slice specification: reason, controlling contract, approval status and any required amendment. Pending decisions never count as accepted deviations. Preserve actual business rules, permissions, privacy, financial safeguards and recovery; simulated demo data/logic are not authority.
5. Obtain an explicit independent Claude verdict: MATCH; MATCH WITH ACCEPTED DEVIATIONS; CHANGES REQUIRED; or NOT VISUALLY VERIFIED. Record a separate Codex verdict using the same labels. State which rendered evidence each reviewer could actually inspect; an embedded source/diff description cannot prove visual fidelity. Codex independently verifies findings and exact applied candidate.
6. A slice needs separate coverage, journey simplicity and visual acceptance results. Source tests/build success alone cannot close the visual gate, and screenshots alone cannot close behavior/authority gates. A source-only repair may be preserved as unqualified work; it cannot be reported as visually accepted.

## Economical review

Use one focused Claude checkpoint per related batch, with a short delta only when needed to resolve changed candidates or concrete findings. Do not repeat unchanged whole-app reviews, SQL/Auth tests or builds for each small edit. Group the necessary checks by impact before accepting and preserving the batch.

## Current baseline and open differences

The original HTML SHA256 is `AF24015383285EAF543E9C95839F55225C2FE9817DD8B1E16D2084F857725508`. Current R1 light palette adopts Concept C canvas/base/subtle/inset/brand. Cairo, existing 40px desktop/44px mobile control minimum and radius8 remain governed by the existing accepted frontend contract; replacement fonts and radius10 need amendment. The stronger field border is the documented accessibility deviation in R1-LIGHT-01. This is a bounded foundation, not a whole-platform visual match; remaining legacy colors, tenant-brand contrast, dark theme and wider layout remain open.

R6-INPUT-RECOVERY-01 applies a scoped leave-module disabled state and read-only options recovery. Source gates pass and synthetic component samples show the repaired state. Same-state reference/full parent and all affected control-state evidence remain open; both reviewers classify design matching as NOT VISUALLY VERIFIED. This is preserved source-qualified work, not full R6 or visual acceptance. D8 auth-return proposal remains unapplied pending the separate owner decision.
