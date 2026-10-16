# Final delta review of automatic element codes: **ACCEPTED for the bounded scope, B1 closed**

This was read-only: three reads, no edits, no shell.

## B1: closed
`src/lib/element-code.ts:8` now returns `pay_` plus 12 lowercase characters for payroll keys, 16 characters in total. Every character in the suffix is a digit from 2 to 9 or a lowercase letter. That satisfies `^[a-z][a-z0-9_]{1,39}$` from `cube4_payroll_inputs.sql:103`. Your isolated QA saved the unedited `pay_93xrtths5mvq` as a draft, and the read-only database check confirmed the same key at revision 1. That is direct evidence, so B1 is closed. Departments, jobs, employees, leave types, calendars and work policies keep the uppercase `PREFIX-XXXXXXXXXXXX` form. All are 14–16 characters, within the limits you report (≤40, ≤60, ≤32 uppercased).

## Code safety
**Safe within scope.**
- The generator is server-side and uses `crypto.randomInt`.
- Each value is created once when the page renders and passed to the form as a starting value. Typed codes, existing record codes, saved revisions and proposals, and requests with an unknown outcome are never regenerated or overwritten.
- No schema, RPC, permission, financial or privacy changes are in the delta. The database uniqueness constraints and the payroll scope lock still decide the outcome.
- Restoring `dir="auto"` removes the earlier optional concern about how existing Arabic codes display.
- **Optional:** add `import 'server-only'` to `element-code.ts` so a future client import would fail at build time rather than at runtime.

## Coverage
**Proportionally accepted.** All 8 create flows from the inventory have a default.
- **Saved with the unedited suggestion:** payroll component, leave type and calendar.
- **Department:** the default is visually confirmed. Your earlier QA confirmed job saves and duplicate rejection.
- **Unchanged generators, prefix only:** employee and work policy.
- **Correction "new employee":** only gains a default prop, and the existing database check (1–40 characters, unique per tenant regardless of case) is unchanged. Accepting it without a financial correction run is reasonable.

**Not run (stated explicitly):**
- The full correction workflow.
- Complete end-to-end saves for all 8 flows. These are not claimed, and they are not blockers for a default-value change that leaves the save contract alone.

## Simplicity
**Improved.** The user types a name and keeps or edits a code that is already filled in, instead of inventing one. Focus now opens on the name field, which is the one real decision. Help shows only on new records, behind the "?" icon. Each state still has one primary action, «إضافة السجل».

## Failure and recovery
**Adequate.**
- **Duplicate department, job or payroll key:** a specific error, with entered values kept.
- **Existing mobile source:** a clear message plus a link to the sources list.
- **Unknown outcome:** still shown as a warning and never auto-regenerated.
- **Optional:** the recovery link opens the sources list, not the conflicting source itself. That's acceptable, but a deep link would save one step.

## Rendered check (department form only, 1366 desktop and 390 mobile)
**Clear and responsive.**
- The code `DEP-FHJNSTPJYD8V` is fully visible in both captures. Help is closed and the name field has a visible focus ring.
- Mobile has no horizontal overflow, readable Arabic labels, large enough touch targets, and the bottom nav doesn't cover the form actions.
- The Latin code sits left-aligned inside the right-to-left form. That is expected for `dir="auto"` and reads fine.
- The "N" badge overlapping «المزيد» in the bottom nav is the Next.js dev indicator, not a product defect.
- This covers only the department create form. It is not a whole-app design approval.

## Blockers
**None remaining.**

## Optional or wider-journey gaps (not blocking)
1. A deep link to the conflicting attendance source instead of the list.
2. The `server-only` guard in `element-code.ts`.
3. A later end-to-end run of the correction "new employee" flow, when that workflow is exercised for its own sake.

## Next step
None is required for this slice beyond normal owner approval. No merge was performed or authorized.