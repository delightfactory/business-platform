# Payroll configuration page: design contract and risks

I only read files for this. Nothing was rendered, run or measured. **NOT VISUALLY VERIFIED.**

**Verdict:** Your proposed fix is the simplest version that works: a separate configuration page at `/payroll/setup/configuration`, one new read-only RPC, and the existing `InputForm` and save path. It needs the eight changes below. Without them, the new page still has guaranteed save failures or misleading states.

## Journey contract
- **Actor:** someone holding `payroll_config.manage`. Viewers (`payroll.view/prepare/approve`) get a read-only page. Finance-only users get a denied state that names the company admin as the person to ask.
- **Job:** add or change an employer's pay component, or set the company-wide day-count policy once.
- **Entry:** the setup link, or an old `inputs?mode=config` / `kind=component|policy` link redirected to the new page.
- **Outcome:** the saved component appears in the list with its start date. Next step is "back to payroll setup", or back to the validated period if the user came from one.
- **States to cover:** loading, employer selection, no components, read-only, payroll not enabled, failed load (keep the URL so retry works), saved, conflict.
- **Baseline:** the current path from setup → inputs?mode=config → period redirect → editor still needs to be counted from a rendered run. Nothing here is measured.

## Required changes to the proposal
1. **Editing a component always fails today (date problem).** The server requires a new version's date to be later than the current version's date (`20261002002040_cube4_payroll_inputs.sql:147`). `InputForm.tsx:20` pre-fills the old date, so an unchanged edit always fails with `payroll_effective_conflict`.
   - Show the current start date as a read-only fact.
   - Leave the new date blank and required, with `min` set to the current date plus one day.
   - Keep the old date for display only. Never submit it as the default.
2. **Locked payroll periods block component dates (date problem).** Line 168 blocks any component whose date range overlaps a locked period for that employer. With no end date, that is every locked period ending on or after the start date. The failure message then says "request a correction", which is wrong for a setup task.
   - The new RPC should return `earliest_effective_from` (last locked period end + 1 for this employer).
   - The UI uses it as the input's `min`, with this hint: «أقرب تاريخ متاح بعد آخر فترة مقفلة».
3. **An existing policy shows a save button that can never work.** `InputForm` shows the button for an existing policy. Saving it fails in two ways:
   - Line 146 rejects it with `policy_already_set`.
   - If another employer created the policy, line 135 rejects it with 42501, because it looks up the record by tenant and employer.

   Contract: an existing policy is read-only, with no save. Text: «سياسة الشركة كلها، محددة منذ <date>. تغييرها غير متاح حاليًا.» The new RPC may look the policy up by tenant only, but must never pass that record to the save action.
4. **Two people creating the policy at the same time (race).** A unique index already allows only one policy per tenant (`payroll_policy_once`, line 10). The loser gets a 23505 error, which `rules.ts:25` turns into a message about a duplicate employee or component.
   - Add a policy-specific message: «حُددت سياسة الشركة للتو من مستخدم آخر. اعرضها.»
   - Decide whether to show "create policy" from the RPC's company-wide `policy` field, not by scanning the current page (`page.tsx:62`).
5. **The "draft" badge is wrong for settings.** Components and policies can't be approved, so they are always saved as `draft`. Component choices don't filter by status, so a "draft" component is actually in use. For these two kinds, replace the badge with «محفوظ — يسري من <date>». Keep "active = no" as the only way to retire a component, and keep it visible.
6. **Making the period optional would crash the form.** `InputForm.tsx:18-20` reads `period.ends_on` and `period.starts_on` with no check.
   - Guard both lines when there is no period.
   - Allow a missing period only for `component` and `policy`, enforced in the props type and at runtime.
   - Leave the hidden `period` field empty (it already is, since these kinds don't use periods).
7. **Exactly what the new RPC returns.** Requirements below are as you proposed; additions are marked.
   - Access uses `payroll_input_access`, with the same visibility set as before and finance-only users denied.
   - The employer must be active.
   - Components come in pages ordered by `id`. `has_more` is computed with LIMIT n+1 (*addition*), not "equals 50".
   - Each component returns the latest version (`v.revision = h.revision`), because save checks against that version, not the one in effect on a given date. A future start date should show «يسري من».
   - The policy is returned separately, company-wide, as a single object.
   - Looking up one record by `head`: components by tenant + employer; policy by tenant only.
   - Return only the fields the form needs: no employees, salaries or period.
   - Grant execute to `authenticated` only. REVOKE from PUBLIC, anon and service_role, matching line 222.
8. **Redirects from old links.**
   - Old `inputs` links with `mode=config` or `kind=component|policy` redirect to the new page, keeping `employer`, `head` and `kind` after UUID and allow-list checks.
   - `period` is carried as `return_period`, checked with `validatePayrollPeriod`, and dropped silently if invalid. It is never used as the configuration scope.
   - Delete the `configMode` branches from `inputs/page.tsx` so there aren't two configuration screens.
   - When there's only one employer, use `unique_employer` to skip the employer choice.

## Risks to raise in issue #47 (don't fix in this batch)
- **Policy vs locked periods:** the locked-period check for the policy (line 168) only looks at the employer that creates it. Setting the company-wide policy from employer A ignores employer B's locked periods. Financial correctness needs its own decision; this page shouldn't hide or "fix" it.
- **Shared page cursor:** `page.tsx:70` reuses `records_after` to page the component choices, so both lists move together. This is an operational-page bug for a separate batch.
- **Overlapping settings:** `payroll_input_access` and "payroll not enabled" (`access.enabled`) both apply. With payroll not enabled, show the list and hide editing with an explanation, not a disabled button with no reason.
- **Later migrations:** `20261003048000` already modifies `payroll_save_input` through string replacement. Check this plan against the function's current definition (`pg_get_functiondef`), not only the base migration.

## Arabic copy
| Element | Copy |
|---|---|
| Tab | «بنود رواتب الجهة» |
| Tab | «سياسة احتساب الفترة (للشركة كلها)» |
| Primary action | «حفظ بند الراتب» |
| Primary action | «تحديد سياسة الشركة» |
| Empty state | «لا توجد بنود رواتب لهذه الجهة. أضف أول بند.» |

## Checks before accepting the batch
**Happy path:**
- Create a component, then edit it with a later date, and see the edit listed.
- With a company that has no policy, set the policy once; it then shows as read-only.

**Failure paths:**
- Editing with the same date shows the date message.
- A date inside a locked period shows the minimum-date hint.
- A second session creating the policy gets the policy-specific message.
- A finance-only user is denied.
- An old link with `head` opens the right record even when it isn't on the first page.

**Display:** rendered checks on phone and desktop, in Arabic/RTL, with keyboard only.