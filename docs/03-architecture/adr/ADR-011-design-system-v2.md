# ADR-011 — Design System v2: Visual Language, Component Layer and Experience Contract

## Status

**Accepted — Product Owner directive, 2026-11-16.**

Implements ADR-010. Supersedes the "Cube 0 control and surface contract" section of `docs/05-engineering/frontend-ux-baseline.md`. Does not change ADR-001 to ADR-009, any Frozen product specification's behavior, the authorization model, or any database object.

## Context

ADR-010 decided on design tokens, an internally owned component layer, and Radix primitives. The implementation that followed did not build that layer. An audit of the frontend at revision `504f904` ([current-interface-audit-2026-11.ar.md](../../08-design-system/current-interface-audit-2026-11.ar.md)) found:

- 4 files in `src/components`; every screen composes 246 global CSS classes from two files (1,154 lines);
- 70 distinct literal hex colors in 142 places, 31 font sizes, 22 radius values;
- no icons, 2 `<table>` elements, 25 `<details>` elements acting as menus and confirmations;
- no `loading`, `error` or `not-found` route files;
- 99 places that pass an action result through a `?state=` query parameter;
- no Radix dependency.

The product owner judged the result unprofessional for a multi-tenant business platform and asked for a complete redesign. The owner delegated the open design decisions to the architect on 2026-11-16.

## Decision

Adopt Design System v2 as defined in [`docs/08-design-system/`](../../08-design-system/README.md). The decisions below are final for V1.

### D1. Typeface

IBM Plex Sans Arabic (400, 500, 600, 700) for all UI text. IBM Plex Mono (400, 500) for codes and identifiers only. Both self-hosted through `@fontsource`. Cairo is removed.

Rationale: Plex Sans Arabic was drawn as a UI face with matching Latin and tabular numerals; it holds up at 12 to 14 px in dense tables, where Cairo's wide proportions and heavy weights reduce density and look promotional.

### D2. Application frame

- Tenant workspace: light sidebar on the `canvas` color, the tenant's brand color marks the active item.
- Operator workspace: dark sidebar (`operator-bg`) plus a persistent context bar. The authority context is visible from the frame itself, not from a label.
- Sub-destinations of a domain live in the sidebar group of that domain, never as buttons in a page header.

### D3. Numerals, dates, amounts

Latin digits (0–9) everywhere. Format with the `ar-EG-u-nu-latn` locale. Dates render as `1 ديسمبر 2026`, times as `9:25 ص`, durations in hours and minutes, amounts with thousands separators and the currency after the number. ISO dates and raw minute counts never reach the UI.

### D4. Product name and mark

Ship V1 with the working name «منصة الأعمال» set as a typographic wordmark (weight 700) and a one-letter monogram tile on `brand`. The name and mark are read from one constant (`src/lib/product.ts`) so a later brand decision is a one-file change. Naming and trademark clearance are a business decision outside this ADR and do not block implementation.

### D5. Themes

Light and dark are both first-class. Every color token has two values. The default follows the operating system; the user can pin a theme from the account menu; the choice is stored in a cookie and applied on the server to avoid a flash. Dark mode is built from Phase 0 and exposed to users in Phase 5.

### D6. Density

Table rows are 52 px by default with a 40 px compact option the user can choose per browser. Controls are 36 px on desktop, 32 px inside tables and toolbars, 44 px on phones.

### D7. Tenant brand color

A tenant chooses one of the existing `primary_color_key` values (`teal`, `blue`, `violet`, `emerald`). Each key maps to a complete, pre-verified set of seven tokens for both themes in [`brand-palettes.json`](../../08-design-system/brand-palettes.json). The layout sets `data-brand="<key>"`; it no longer injects a hex value through an inline style. Colors are never derived at runtime with `color-mix`. Status colors, the focus ring and neutral surfaces never follow the tenant color. No database change: the stored keys are unchanged.

### D8. Technology

| Concern | Choice |
| --- | --- |
| Tokens | `docs/08-design-system/tokens.json` is the source. A script generates `src/styles/tokens.css`. Tailwind 4 maps them through `@theme`. |
| Primitives | Radix Primitives, wrapped in `src/components/ui`. Feature code never imports Radix directly. |
| Variants | `class-variance-authority`, `clsx`, `tailwind-merge`. |
| Icons | `lucide-react`, stroke 1.75. |
| Command palette, combobox | `cmdk` inside a Radix Popover/Dialog. |
| Calendar | `react-day-picker` inside a Radix Popover. |
| Toasts | `sonner`. |
| Composed patterns | `src/components/patterns`. |

All dependencies are pinned to exact versions, as the repository already does.

### D9. Interaction contract

- One primary action per region.
- Confirmations use a dialog that lists the real impact. Reversible actions execute immediately and offer undo. `<details>` is never used as a confirmation or a menu.
- Action results return to the component through `useActionState`; after a redirect, through a one-time flash cookie. Results are never carried in the URL.
- Errors appear at the field. Failures never appear in a toast that disappears.
- Every route segment has loading, error and not-found states.
- List state (search, filters, sort, page, tab) lives in the URL.

Forms keep submitting through Server Actions. Overlays (dialog, drawer, menu, combobox) require JavaScript; this is accepted.

## Alternatives considered

- **Restyle the existing global CSS.** Rejected: it leaves the page-by-page structure that caused the drift, which ADR-010 already rejected.
- **Adopt a pre-styled enterprise suite.** Rejected in ADR-010; still rejected. RTL-first composition and tenant theming need owned components.
- **Keep Cairo with a corrected scale.** Workable, but it does not solve density in tables. Kept as a fallback only if a licensing or rendering problem appears with Plex.
- **Dark sidebar in both workspaces.** Rejected: tenant logos are designed for light grounds, and it removes the frame-level distinction between operator and tenant authority.
- **Per-tenant numeral system.** Deferred. One system now; a tenant option can be added later without changing components because formatting is centralized.

## Consequences

- New runtime dependencies (Radix, lucide, cva, cmdk, day-picker, sonner, Plex fonts).
- `globals.css` and `workspace.css` are deleted at the end of the migration.
- Screens are rebuilt on shared components in phases; each phase merges on its own and leaves the application working.
- Several designed features need data that current RPCs do not return (list totals, server-side filters, status counts, a home attention feed, record search). The UI ships with defined degraded behavior first; the data work is governed separately. See the [execution plan](../../07-execution/design-system-v2-execution-plan.md), Phase 7.
- A design-system lint check becomes part of the quality gates.

## Scope boundary

This ADR governs presentation and interaction. It must not be used to change business rules, RPC semantics, permissions, entitlement behavior or stored data. Any such change needs its own specification amendment under `docs/06-governance/change-control.md`.
