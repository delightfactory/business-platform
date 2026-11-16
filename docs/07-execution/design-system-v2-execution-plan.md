# Design System v2 — Execution Plan

Governing decision: [ADR-011](../03-architecture/adr/ADR-011-design-system-v2.md). Specifications: [`docs/08-design-system/`](../08-design-system/README.md). Assignment: [Codex brief](codex-design-system-v2-brief.md).

## Goal

Rebuild the entire user interface of Business Platform on Design System v2 so that every screen is composed only from the owned component layer, in eight phases, without changing business behavior.

**Done means all of the following are true on one revision:**

1. Every route in the [screen migration map](../08-design-system/screen-migration-map.md) matches its target.
2. `src/app/globals.css` contains only the Tailwind import, the theme mapping and a base reset; `src/app/workspace.css` does not exist; no legacy class from the audit remains.
3. `npm run lint`, `npm run typecheck`, `npm run build`, `npm run lint:design` and the existing test scripts pass.
4. `git diff 504f904 -- supabase/` is empty for Phases 0 to 6.
5. Evidence screenshots for every phase exist under `docs/07-execution/evidence/ds-v2/`.
6. [`design-system-v2-progress.md`](design-system-v2-progress.md) shows every item checked.

## Standing rules

**Scope**

- Presentation and interaction only. Do not change RPC calls, their arguments, authorization checks, entitlement logic, validation rules, redirects' destinations, or any file under `supabase/` in Phases 0 to 6.
- A Server Action may change what it returns to the UI (`ActionResult`, flash message instead of `?state=`). It may not change what it validates or writes.
- Keep route paths. Keep existing Arabic copy unless the specifications change it.
- If a screen needs data that no RPC returns, apply the degraded behavior written in this plan and log the gap in the progress file under "Backend gaps". Do not add a query, RPC or migration outside Phase 7.
- If a specification is silent or contradicts a Frozen product spec, stop that item, record the question in the progress file under "Open questions", and continue with other items.

**Workflow**

- One branch and one pull request per phase, branched from the previous phase. Name: `codex/ds-v2-phase-<n>-<slug>`.
- Each phase leaves the application working with old and new screens side by side.
- Update `design-system-v2-progress.md` in the same pull request.
- Exact-pin every new dependency.

**Verification for every phase**

```bash
npm run lint
npm run typecheck
npm run build
npm run lint:design          # from Phase 0 onward
node --test src/lib/*.test.mjs
```

Rendered evidence, saved to `docs/07-execution/evidence/ds-v2/phase-<n>/`:

- viewports 390 × 844, 820 × 1180, 1440 × 900;
- light and dark;
- Phase 0: the `/dev/ui` gallery;
- Phases 1 to 6: each changed screen with realistic data, using the same local Supabase procedure and seed used for the Cube 0 to Cube 2 qualification evidence, signed in as a tenant admin, as a member with partial access, and as an operator where relevant.

Compare each screen against `docs/08-design-system/reference/screens/` and the matching `reference/previews/*.html`.

**Screen definition of done** (also added to `docs/06-governance/definition-of-done.md`)

- composed only from `src/components/ui` and `src/components/patterns`; no page-local styling;
- loading, first-use empty, no-results, error, unavailable and read-only states exist;
- full keyboard operation; visible focus; focus returns after overlays close;
- correct in RTL, in both themes, at the three viewports; no horizontal page scroll;
- checked as admin, as partial-access member, as no-access user;
- copy follows `foundations.ar.md`: no English, no raw ISO dates or minute counts, Latin digits;
- every action ends with a visible result and a next step.

## Phase 0 — Foundation

**Goal:** the system exists in code and is verifiable without touching any screen.

**Deliverables**

- Dependencies: Radix primitives used by the specs, `lucide-react`, `class-variance-authority`, `clsx`, `tailwind-merge`, `cmdk`, `react-day-picker`, `sonner`, `@fontsource/ibm-plex-sans-arabic`, `@fontsource/ibm-plex-mono`.
- `scripts/design-tokens-build.mjs` and `npm run tokens:build`: reads `docs/08-design-system/tokens.json` and `brand-palettes.json`, writes `src/styles/tokens.css` (base tokens for both themes plus one `[data-brand]` block per palette, light and dark).
- `scripts/check-design-system.mjs` and `npm run lint:design`. It fails on: a hex, `rgb(` or `hsl(` literal in `src/` outside `src/styles/tokens.css`; an import of `@radix-ui/*`, `cmdk`, `react-day-picker` or `sonner` outside `src/components/ui`; `tokens.css` differing from a fresh build. It reads a baseline file `scripts/design-system-baseline.json` listing legacy files still allowed to violate; Phase 0 fills the baseline with the current legacy files, each later phase removes entries, Phase 6 leaves it empty.
- `src/lib/cn.ts`, `src/lib/format.ts`, `src/lib/status.ts`, `src/lib/product.ts`, `src/lib/flash.ts`.
- Fonts loaded in the root layout; theme cookie read in the root layout to set `data-theme` on `<html>`.
- Primitives from [`component-specs.md`](../08-design-system/component-specs.md): Button, SubmitButton, Field family, Choice family, Badge, StatusBadge, Tag, Avatar, Alert, Toaster, FlashToast, Dialog, ConfirmDialog, Drawer, DropdownMenu, TabsNav, Segmented, Breadcrumbs, Card, StatCard, Meter, DescriptionList, SensitiveValue, Timeline, EmptyState, Skeleton set, Steps.
- `/dev/ui` gallery covering every variant and state, with theme and brand switches; `notFound()` in production.
- Legacy CSS stays loaded. New tokens must not collide with the legacy `--color-*` variables.

**Acceptance**

- [ ] Gallery renders every component in light and dark, for all four brand keys, matching `reference/previews/`.
- [ ] `format.ts`: `formatDate('2026-12-01')` → `1 ديسمبر 2026`; `formatTime` → `9:25 ص`; `formatDuration(457)` → `7 س 37 د`; `formatMoney(12500)` → `12,500.00 ج.م`; all digits Latin. Covered by a `node --test` file.
- [ ] Keyboard: Dialog, Drawer, DropdownMenu, Combobox, DateField operable without a pointer; Escape closes and restores focus.
- [ ] `npm run lint:design` passes with the baseline.
- [ ] No existing screen changed visually.

**Out of scope:** any change under `src/app` other than the root layout and `/dev/ui`.

## Phase 1 — Shell and navigation

**Goal:** every existing page sits inside the new frame.

**Deliverables**

- `AppShell` (tenant and operator), navigation descriptions, workspace switcher, account menu with sign out, breadcrumbs slot, phone app bar and bottom navigation, tablet drawer.
- Tenant layout sets `data-brand`; inline brand color removed.
- «الأقسام والوظائف» and «سياسات الدوام» appear in the sidebar under «الموارد البشرية» with the labels in the specs, visible under the same conditions as their current header links.
- `not-found.tsx`, `error.tsx`, and `loading.tsx` files per the migration map.
- Per-page text footers removed. `PageFrame` reduced to a content wrapper.
- `src/components/context-navigation.tsx` and `context-navigation-client.tsx` deleted.

**Acceptance**

- [ ] With zero, one and several visible domain entries the sidebar renders correctly; an empty group is not rendered.
- [ ] A user with one tenant sees no tenant list in the switcher; a user with several can switch and lands on the new tenant's home.
- [ ] Operator frame is dark with the context bar; tenant frame is light with the tenant color on the active item.
- [ ] Navigation visibility is identical to before for admin, partial-access member and operator (compare before and after for each role).
- [ ] Phone: bottom navigation with icons; «المزيد» opens all destinations; the page title appears once.
- [ ] Navigating between pages shows the skeleton, not a blank page.

**Out of scope:** page content.

## Phase 2 — Lists

**Goal:** every collection is a `DataTable`.

**Deliverables:** `PageHeader`, `DataTable` with toolbar, `FilterChip`, pagination, selection and bulk bar; all rows marked Phase 2 in the migration map.

**Degraded behavior where data is missing**

- No total from the RPC: footer shows the range without a total, previous and next only.
- No server-side filter for a field: do not render that filter.
- No per-status counts: tabs without counters, or no tabs if the RPC cannot filter by status.

**Acceptance**

- [ ] No `record-card`, `member-card` or `invitation-row` markup remains in the converted pages.
- [ ] Search updates results without a submit button and is preserved in the URL; reload and shared link reproduce the same view.
- [ ] Each list shows first-use empty, no-results and error states with the texts the page already has.
- [ ] Row click opens the record; row actions are in a menu; no per-row «عرض» button.
- [ ] At 390 px each list renders as rows with title, subtitle and badge; no horizontal page scroll.
- [ ] Attendance bulk approval works through table selection with the existing action.
- [ ] Dates, times and durations use `format.ts`; statuses use `StatusBadge`.

## Phase 3 — Records and actions

**Goal:** record pages are structured, and every action runs through a menu, dialog or drawer.

**Deliverables:** `RecordHeader`; all rows marked Phase 3; every `<details>` in `src/` replaced; every `?state=` result replaced by `ActionResult` or a flash message for the converted actions.

**Acceptance**

- [ ] `grep -r "<details" src` returns nothing.
- [ ] Each destructive or authority-changing action opens a `ConfirmDialog` whose title names the action and the record and whose body lists the real impact, using the explanatory text the page already shows.
- [ ] After each action: success toast, the record reflects the change, focus is restored. On failure: an `Alert` or field error that says whether anything changed.
- [ ] Reloading the page after an action does not replay the message.
- [ ] Employee record: tabs by `?tab=`, each tab linkable; compensation amount hidden until revealed and absent for users without the existing view permission.
- [ ] Every existing message key in the pages' `stateMessage` tables still has a reachable, correctly worded outcome.

## Phase 4 — Forms and imports

**Goal:** every create, edit and settings flow uses `FormLayout` with field-level errors.

**Deliverables:** `FormLayout`, `UnsavedChangesGuard`; all rows marked Phase 4.

**Acceptance**

- [ ] Each form posts the same field names and formats as before (verify by submitting each form successfully and with each known validation failure).
- [ ] Validation errors appear at the field; entered values are preserved; focus moves to the first invalid field.
- [ ] Lists longer than 7 options use `Combobox`; dates use `DateField`; amounts use `MoneyInput`.
- [ ] Add-employee runs as four steps with a review step and one final submit.
- [ ] Branding: choosing a color updates the preview and, after save, the shell.
- [ ] Leaving a dirty form asks for confirmation.

## Phase 5 — Home, entry screens, phone pass, theme

**Deliverables:** tenant and operator home per the migration map; `AuthLayout` and all authentication screens; `/` redirect; `CommandPalette` (destinations and actions); theme choice in the account menu; a full pass of every screen at 390 px.

**Acceptance**

- [ ] Tenant home shows only data from existing snapshots; no link duplicates the sidebar; no tile for an unavailable domain.
- [ ] Every authentication branch (expired, revoked, invalid link, setup incomplete) has a designed state with a recovery path.
- [ ] Ctrl K opens the palette; it lists only destinations and actions the user can access.
- [ ] Theme choice persists across reloads with no flash of the wrong theme.
- [ ] Every screen meets the screen definition of done at all three viewports.

## Phase 6 — Removal and governance

**Deliverables:** delete `src/app/workspace.css`; reduce `globals.css`; remove Cairo; remove unused legacy helpers; empty the lint baseline; add `lint:design` to the documented quality gates.

**Acceptance**

- [ ] `scripts/design-system-baseline.json` is empty and `npm run lint:design` passes.
- [ ] `grep -rE "auth-form|auth-card|work-card|record-card|entity-status|primary-button|secondary-button|danger-button" src` returns nothing.
- [ ] `@fontsource/cairo` is not in `package.json`.
- [ ] Full evidence set regenerated on the final revision.

## Phase 7 — Data enablement (separately governed)

Phases 0 to 6 complete the redesign. Phase 7 removes the degraded behaviors. Each item changes the database or adds an RPC, so each one is its own work item under `docs/06-governance/change-control.md` with the database, tenant-isolation and authorization gates in `docs/05-engineering/quality-gates.md`, a reviewed migration and `supabase test db` coverage. Do not start an item without the product owner's go-ahead recorded in the progress file.

| Item | Enables | Shape |
| --- | --- | --- |
| B1 | Totals, status tabs with counters, and site/department/status filters in the employee directory | Extend the directory read to accept filters and return `total` and per-status counts, under the same access rules |
| B2 | «يحتاج إجراءً منك» on the tenant home | One read returning counts of items awaiting the current user per domain, each domain contributing only what that user may act on |
| B3 | Record search in the command palette | A tenant-scoped, permission-filtered search over employees by name and code |
| B4 | Change history on the employee record | A read over existing effective-dated and audit data; no new writes |
| B5 | Totals for cursor-paginated attendance lists and status filtering | Count and status filter on the day list |

## Risks

| Risk | Control |
| --- | --- |
| Behavior changes hidden inside UI rewrites | `supabase/` diff must stay empty; forms verified to post identical fields; role-by-role comparison of navigation |
| Old and new styles collide during migration | New tokens use different variable names; new components use only Tailwind utilities; legacy CSS removed only in Phase 6 |
| Access leaks through new UI (palette, menus) | Every destination and action list is built from the same access snapshots; server checks unchanged |
| Flash cookie carries personal data | Flash messages are generic by rule; reviewed in Phase 3 acceptance |
| Tailwind 4 / React 19 API details | Verify against the installed versions' documentation before writing theme mapping and Radix wrappers |
