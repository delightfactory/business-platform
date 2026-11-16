# Codex Implementation Brief — Design System v2

## Goal

Rebuild the entire user interface of Business Platform on Design System v2, phase by phase, until the "Done" conditions in the [execution plan](design-system-v2-execution-plan.md) are all true. Do not change business behavior.

Suggested goal statement for the session:

> Implement Design System v2 for Business Platform by completing Phases 0 to 6 of `docs/07-execution/design-system-v2-execution-plan.md` in order. For each phase: implement the deliverables, satisfy every acceptance item, run the verification commands, save rendered evidence, update `docs/07-execution/design-system-v2-progress.md`, and open one pull request. Stop only when every Phase 0 to 6 item in the progress file is checked and the plan's Done conditions hold, or when an Open question blocks all remaining items.

## Authority

1. [ADR-011](../03-architecture/adr/ADR-011-design-system-v2.md) — the decisions. They are closed; do not reopen them.
2. [`docs/08-design-system/`](../08-design-system/README.md) — tokens, component specifications, patterns, screen map, reference.
3. [Execution plan](design-system-v2-execution-plan.md) — phases, acceptance, verification, degraded behaviors.
4. Existing Frozen product specifications and ADR-001 to ADR-010 continue to govern behavior. `docs/06-governance/source-of-truth.md` governs conflicts.

This brief adds to, and does not replace, [`codex-implementation-brief.md`](codex-implementation-brief.md).

## Read first, in this order

1. `docs/03-architecture/adr/ADR-011-design-system-v2.md`
2. `docs/08-design-system/README.md`
3. `docs/08-design-system/foundations.ar.md`
4. `docs/08-design-system/component-specs.md`
5. `docs/08-design-system/experience-patterns.ar.md`
6. `docs/08-design-system/screen-migration-map.md`
7. `docs/07-execution/design-system-v2-execution-plan.md`
8. Open `docs/08-design-system/reference/screens/*.png`, then the matching `reference/previews/*.html` in a browser, in light and dark.

## Non-negotiable constraints

- No change under `supabase/` and no change to RPC calls, arguments, authorization, entitlements, validation or redirect destinations in Phases 0 to 6.
- Every screen is composed from `src/components/ui` and `src/components/patterns`. No page-local CSS, no new global class, no literal color.
- Values come from `docs/08-design-system/tokens.json`. Do not invent a color, size, radius or shadow. If a needed value is missing, record an Open question.
- `reference/components.css` is a measurement reference. Do not import it or recreate its classes globally.
- Arabic-first, RTL, logical properties only. Existing copy stays unless the specifications change it. No English in the interface.
- Navigation, menus and the command palette show only what the current access snapshots allow. Server-side checks are untouched.
- Never put personal data in a flash cookie or in the URL.
- New dependencies are limited to those named in ADR-011 D8, exact-pinned.
- Phase 7 items need an explicit go-ahead recorded in the progress file.

## When something is unclear

Do not guess product behavior. Record the question under "Open questions" in the progress file with the file and line it concerns, skip that item, and continue. A visual detail not covered by the specs is resolved by, in order: `component-specs.md`, `reference/components.css`, the nearest pattern in `reference/previews/`, then `foundations.ar.md`.

## Reporting

Each pull request description states: the phase, the acceptance items with their result, the verification command output, the evidence folder, new dependencies with versions, Backend gaps found, and Open questions.
