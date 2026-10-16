**ACCEPTED.** The Medium issue from review c1306a72 is fixed. I only read the code: I didn't run the tests or eslint, and I made no edits.

What I checked, in `currentWorkspaceLocation` (`src/components/shell/navigation-model.ts:73-85`) and where it's used:

- **Home matches exactly.** A link whose path equals `homeHref` now only matches that exact path (`:75-76`), so the workspace root no longer catches every page. This works for both the `/tenant/<id>` home and the `/operator` home. When the employee's home is `/me`, the "يومي" link points to the same address and is also exact-only, while `/me/leave` and `/me/attendance` still resolve to their own links.
- **Nested setup has no wrong daily area.** On a page like `people/organization/new`, the deepest match wins (`people/organization` beats `people`). Because it is a settings link, `isSetting` sets the area to `undefined` (`:78-79`), so no daily-work section opens and no bottom tab is highlighted. The settings group still opens because its `open` condition includes `activeHref` (`workspace-navigation.tsx:54`). The test covers this (`navigation-model.test.mjs:22-24`).
- **Operator aliases need a granted companies area.** The fallback only runs when nothing else matched and the mode is operator (`:80`). It looks up the `companies` area that `workspaceAreas` builds only from granted admin links. Without that grant it returns `{active: undefined, area: undefined}`, so no destination is invented and nothing is shown as current.
- **Unknown pages show a neutral header.** The header uses `active?.label ?? 'مساحة العمل'` (`workspace-navigation.tsx:123`). Tree items and bottom tabs compare against `active?.href` and `activeArea?.key`, so an unknown route highlights nothing. The test covers `/unlisted` and `/operator/unknown`.
- **Payroll links with context still match.** Links that carry employer/period context use the same objects in the tree and in `currentWorkspaceLocation`, and every path comparison strips the `?query` and `#hash` first.

Two small observations; neither blocks acceptance:
1. No test covers an operator visiting `/operator/tenants/...` without a companies grant. By reading, it returns `undefined` safely.
2. If a tenant employee with no team access has the root as home but also has a `/me` link, the "يومي" link replaces the root link, so visiting the root shows the neutral header. That follows from the existing self-service grouping, not from this fix, and nothing is lost or exposed.

Visual check: not visually verified, since this review had no rendered images.