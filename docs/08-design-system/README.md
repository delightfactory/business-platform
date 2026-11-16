# Design System v2

The visual language, component layer and experience contract for Business Platform. Adopted by [ADR-011](../03-architecture/adr/ADR-011-design-system-v2.md) (DEC-025).

## Authority

| Document | Role | Language |
| --- | --- | --- |
| [ADR-011](../03-architecture/adr/ADR-011-design-system-v2.md) | The decisions | English |
| [`tokens.json`](tokens.json) | Source of truth for every color, type style, spacing, radius, shadow and size value | data |
| [`brand-palettes.json`](brand-palettes.json) | Tenant brand color sets per `primary_color_key` | data |
| [`foundations.ar.md`](foundations.ar.md) | Usage rules: principles, UI voice, color, type, layout, icons, motion, states, accessibility | Arabic |
| [`component-specs.md`](component-specs.md) | Component inventory: file, primitive, props, states, acceptance | English |
| [`experience-patterns.ar.md`](experience-patterns.ar.md) | Page archetypes, action loop, screen states, desktop vs. phone | Arabic |
| [`screen-migration-map.md`](screen-migration-map.md) | Every existing route: target archetype, components, phase | English |
| [`current-interface-audit-2026-11.ar.md`](current-interface-audit-2026-11.ar.md) | Evidence: 34 findings in the interface at `504f904` | Arabic |
| [`reference/`](reference/) | Visual reference: rendered screens, HTML previews, per-component usage guidelines | mixed |
| [Execution plan](../07-execution/design-system-v2-execution-plan.md) | Phases, acceptance criteria, verification | English |
| [Codex brief](../07-execution/codex-design-system-v2-brief.md) | The implementation assignment | English |

The three `.ar.md` documents are in Arabic because they define the Arabic interface voice and are reviewed by the product owner in Arabic. They carry the same authority as the English documents.

On conflict: ADR-011, then `tokens.json` and `brand-palettes.json`, then `component-specs.md`, then the Arabic documents, then `reference/`.

## How to use the reference

`reference/` shows what the result looks like. It is not production code.

- `reference/screens/*.png`: ten rendered screens (home, employee list, employee record, phone, dark mode, operator workspace, form, confirm dialog, tenant colors).
- `reference/previews/*.html`: open in a browser. Each file renders one component or screen from `tokens.css` and `components.css`. Add `data-theme="dark"` to `<html>` to see the dark theme.
- `reference/components.css`: the exact measurements for every component (heights, paddings, radii, colors per state). Reproduce these values with Tailwind utilities inside React components. Do not import this file into the application and do not recreate its `bp-*` classes as global CSS.
- `reference/icons.js`: stand-in icons drawn for the previews. Production uses `lucide-react`.
- `reference/guidelines/*.md`: per-component usage rules in Arabic (when to use, what the consumer provides, do and do not).

## What does not change

Business rules, Server Action semantics, RPC calls, authorization, entitlements, tenancy and the database. The workspace and navigation hierarchy in [`platform-experience-architecture.md`](../05-engineering/platform-experience-architecture.md) stays; this system implements it.
