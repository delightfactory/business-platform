The review is done: **ACCEPTED** for Batch 8. Nothing blocks it.

I read the code without running anything, and I looked at only the two screenshots you named. I didn't edit any files, and I couldn't write a plan file because this session has no write tool.

## Security: `src/app/auth/safe-next.ts`
- **Only known tenant pages pass (`safe-next.ts:10-17`).** The pattern lists people, attendance, leave, the payroll configuration page, the self-service pages, users, branding, sites and `/tenant/select`. It contains no `%`, `.` or wildcard segments, so encoded traversal (`%2e%2e`, `%2f`) and unknown segments can't match.
- **No API or export routes are reachable.** The repo has three route handlers under tenant paths: `payroll/output/export`, `payroll/reports/export` and `people/[employeeId]/preview`. None of them matches the new pattern or the existing payroll one. Only the reports export has a test.
- **Checks on length, characters and origin (`safe-next.ts:21-25`).** It rejects anything over 8192 characters, raw control characters, spaces, `#` and `\`, and encoded control characters. Every accepted path starts with `/tenant/`, so `//host` and absolute URLs fail. The decoded check on query values repeats an earlier check but does no harm.
- **The return address grants nothing.** A query key is not a permission. Each page still runs its own authorization (for example `leave_access_snapshot` in `leave/settings/page.tsx:54`). The operator-company query allowlist and the old payroll, self-service, invitation and operator patterns are unchanged.
- **Tests.** The new route test checks every `page.tsx` actually in the repo, which keeps it from going stale. The negative cases cover external URLs, `//` URLs, `..`, `%2f`, `api`, `export`, `%0a`, `%1f`, `%7f`, spaces, `#` and over-length input. That matches your report that no malicious negative case was removed.

## UX by scope item
- **Leave employer chooser (`leave/settings/page.tsx:27-52`).**
  - The choose flag, search and page cursor are checked and carried into retry links and the login return address.
  - Invalid input resets to the chooser and keeps the flag (`:41`).
  - The page only redirects to a single employer when no flag, search or cursor is present (`:94`).
  - The desktop screenshot confirms "التدريب" stays in the search box, "مسح البحث" is shown, and the result list appears with no redirect.
  - Failure states keep a retry link. Read-only and service-paused notices remain.
- **Read-only setup steps (`[employerId]/page.tsx:107`).** "الخطوة التالية" (next step) only appears when the user can edit. Read-only users see "لم يُسجل بعد" (not recorded yet), which tells them the status without suggesting an action they can't take.
- **`SettingsLink.tsx`.**
  - It now matches whole class names, so a class like `module_primary-button_custom` stays a plain link.
  - Custom classes, the large size, variants and `aria-label` are kept, and the loading indicator still shows.
- **Attendance calendar.**
  - The phone screenshot (390 wide, dark) shows the 16th underlined, labelled "اليوم" and highlighted, with no overflow.
  - The header button "عرض حضور اليوم" keeps the link to today. The bottom link "قائمة مراجعة اليوم" goes to a different page (the review list), so it isn't a duplicate.
  - The cell symbols are hidden from screen readers. Each day link reads out the full status, including "اليوم".
  - The legend only shows on narrow screens (`calendar.module.css:25,55`).
- **Login.** Invalid and setup errors now use the error style with `role="alert"`. Other messages stay informational.
- **Other actions, RPC calls and authorization:** I found no changes in the files in scope.

## Optional notes (none block)
1. `calendar/page.tsx:76`: `aria-label` on a plain `<p>` is ignored by most screen readers and isn't allowed on that element. The visible text already says the same thing, so you could remove the label or make the legend a list.
2. `safe-next.ts:17`: the `i` flag means uppercase paths like `/TENANT/...` are accepted. That's harmless (the link is still internal and the page just 404s), but it's looser than the self-service pattern.
3. Chooser screenshot: the HelpNote chevron sits at the far edge of the row, away from its "ما الجهات التي تظهر هنا؟" label. This comes from the existing HelpNote component, not this batch.

## Not verified
- **Legend:** I didn't see it rendered. It sits below the fold in the phone screenshot, and you told me not to use the cropped captures. Its placement rests on the source code and your DOM measurement.
- **Not covered:** authorization testing of all 54 pages, all six theme and size combinations, a screen reader pass, and the pending built smoke test.
- **Not re-run:** I didn't run the tests, lint or build. The pass results are your reports.
- **Guide:** I didn't review the guide or PDF.
- **Goal still open:** phase 9 coverage of the 14 representative user families isn't done.