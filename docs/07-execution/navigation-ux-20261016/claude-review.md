Review is complete. I read both skills, the full diff, the CSS module, the tests and the 4 screenshots. Here is the verdict.

# Independent review: sidebar/drawer navigation and inline field help

**Scope:** I reviewed the diff, the CSS module and the tests, and looked at 4 screenshots you rendered from the real build. I ran nothing myself and did not open the tablet image. Build, lint, node tests and browser measurements are your evidence, not mine.

## 1. Code and permission coverage — **Pass**
- `workspaceMenu` (`navigation-model.ts`) only filters and reclassifies the links it is given. Every area link that is a setup link moves to `settings`. Any link not grouped elsewhere ends up in `settings` (admin links) or `personal` (business links). Areas left empty are dropped instead of being shown empty.
  - The exact-set test covers team, employee, settings-only, operator with an unknown path, and an account with no grants. That is the right invariant.
- Operator `statutory` is pulled out of its area and moved to settings, as intended.
- The `can_manage_org === true` check (`context-navigation.tsx:503`) reads the existing server snapshot. It adds no new authority.
- `payrollDestination` and the employer/period context are unchanged and covered by a test.
- Sign-out form, offline banner and dialog lock/close logic are unchanged in the diff.
- `/me` now shows under "خدماتي وروابطي" as well as the account menu. It's a duplicate, not a loss.

## 2. Task success and simplicity — **Pass (scoped)**
- Desktop: every authorized destination is reachable from one persistent tree. People → Organization took 2 clicks.
- The active settings item opens its group, and the drawer opens settings by default.
- The "Daily work" and "Settings and workspace management" labels match the order people actually work in.
- The before/after click count was not measured, which you state correctly.

## 3. Failure and recovery — **Pass with one wayfinding issue**
In your evidence, a draft survived Escape, theme change and drawer navigation. Offline and unknown-outcome paths were not touched.

**Medium (should fix): the wrong item can be marked as the current page.**
- In `workspace-navigation.tsx`, `active` is the longest prefix match over `allLinks`, and that list includes `homeHref`.
- `/tenant/<id>` (or `/operator`) is a prefix of every page. So on any page that matches no other link, "اليوم" gets `aria-current="page"` and the header breadcrumb shows the home label.
- The old operator fallback for `/operator/(tenants|commercial|entitlements)` was also removed. If the operator's admin links include only `/operator/companies`, a company detail page now falsely marks Home and highlights no bottom tab. Before, it activated "الشركات". I did not check which operator links exist.
- **Fix:** count home as active only when `pathname === homeHref`, and restore the operator companies alias in `activeArea`.

**Low:**
- Bottom tabs use the area's prefix match. So `/people/organization` highlights "الموظفون", and `/attendance/sources` highlights "الوقت" and opens the time group, while the sidebar marks the item under settings.
- This doesn't mislead anyone, but the two current-page indicators disagree.

## 4. Accessibility and responsiveness — **Pass (screenshots and your measurements)**
- Menu buttons, bottom tabs and the help button on touch screens are 44px. Focus outlines are visible.
- `details/summary` groups work with the keyboard natively. The dialog closes with Escape and returns focus.
- `FieldHelp` puts the real `<label htmlFor>` and an `aria-expanded`/`aria-controls` button in one row. The help content uses `hidden` and sits in the normal flow, so nothing overlaps (your measurement: 332.65 ≤ 342.65).
- Errors and hints are still separate elements with `role="alert"`.
- Removing the old area sub-tabs means that on phones, moving within an area (e.g. payroll runs → inputs) now takes Menu + link, 2 taps, where it used to take 1. This is a trade-off, not a blocker. Check it in the next batch if pages lack their own local links.
- **Not verified:** screen-reader announcements, 200% zoom, a real touch device, and the 1100–1365px desktop range other than 1366.

## 5. Visual quality — **Pass, verified from 4 screenshots only**
- The light and dark desktop views are calm and readable, with clear hierarchy.
- The active item uses a soft brand fill. The sidebar indents child items with a hairline and puts the guide link at the bottom.
- The form is capped at 760px from the RTL start, and with the extra border gone the panel looks cleaner.
- The help sits in a quiet band with a start border between the label and the input. It is legible and nothing overlaps.
- The phone bottom bar has 5 controls with clear labels. The drawer is a single full-width tree.
- Minor polish:
  - At 1366px a lot of empty space is left beyond the form's end. This is acceptable for a capped form.
  - The drawer's company name in the 16px heading wraps to 2 lines.
  - In the drawer, "هوية الشركة" is partly cut off at the bottom edge. It does scroll, but the cut is visually abrupt.

## Blockers
**None.** The one item to fix before you call navigation accepted is the Medium issue: the home or wrong area being marked as the current page.

## Optional improvements
- Make the bottom-tab and sidebar current-page logic agree for setup routes.
- Add a fade or bottom padding to the drawer list so the last item doesn't look clipped.
- Consider clamping the drawer heading to one line with the full name available elsewhere.
- The `ui-panel > form.auth-form` reset applies across the whole workspace. Spot-check a few other panel forms in the next batch.

## Not run / out of scope
- No PG tests (the DB is unchanged), no financial requalification, and not the 83-route matrix.
- I did not review the tablet image, operator screenshots, an employee-only rendered view, or the PDF/HTML guide.
- The "الناس"/"الموظفون" name mismatch is deferred, as you noted.