**Verdict: ACCEPTED.** The journey works end to end: find the employee, open the file in one click, see the first unresolved setup step, and go back to the same filtered results. Business rules, permissions, privacy and recovery are unchanged. I found no blocking issues, but one small accessibility fix should go in before commit.

## What I checked

- **Return links can't be abused.** The new helpers in `src/lib/profile-return.ts:34-47` use the existing `safeReturn` and `profileReturnUrl` checks without loosening them. External addresses, other tenants, and searches containing an encoded `/` or `\` all fall back to the plain directory. The test at `company-profile-context.test.cjs:63` covers these.
- **Preview still works with the return query.** It fetches from its own fixed address with no query string (`EmployeePreview.tsx:28`). The eye icon still opens the file without JavaScript or with modifier-key clicks. Request cancelling, data filtering and focus return to the eye icon are unchanged. The icon is 44px (`employee-preview.module.css:108`).
- **Directory rows** (`people/page.tsx:63-72`): the return is carried only when there's a search or a page above 1. There's one text action, «فتح الملف», plus the eye icon. No permission checks or data calls changed.
- **Readiness** (`EmployeeReadiness.tsx`):
  - The code that builds each step's state, text, owner and action is unchanged; it's only split into 5 core and 3 review items.
  - The next step shown is the first core item that isn't done, including unverified and waiting items (`readiness-focus.ts:6`).
  - `manual_review` stays a manager task with its warning; `pending` and `user_created` stay waiting, so services are never suggested before activation.
  - Only a "todo" step gets the filled button.
  - The "all recorded" text doesn't claim the employee can actually record attendance or be paid.
  - The review group opens by default when the wage is missing or unverified.
  - The label «خطوتك التالية» no longer appears anywhere, and the shared `ReadinessList` used by the company home page is untouched.
- **Return context** survives tabs, saves and login, because the existing hidden return fields and action redirects are untouched.
- **User guide** (`docs/user-guide/ar.md:207-209`) matches the new behaviour and says plainly that recorded settings don't mean attendance or payroll is ready.

## Screenshots (dev runtime)

- **Desktop directory, dark:** clear hierarchy. The row reads name and code, then employer and site, then status, then «فتح الملف» and the eye icon. The RTL layout is correct.
- **Phone directory, light:** a long name wraps cleanly. Actions sit on their own row, «فتح الملف» full width and the eye icon fixed, with no horizontal scroll.
- **Phone profile, dark:** «العودة إلى نتائج البحث» sits at the start edge. The card «الخطوة التالية: حساب الدخول» has one filled button, followed by «3 من 5 إعدادات أساسية مسجلة.» and a collapsed details section. The layout is dense but readable.

## Fix before commit

1. **`people/page.tsx:70`: the button's spoken name doesn't contain its visible text.** It shows «فتح الملف» but its `aria-label` is «فتح ملف {name}» (no «الملف»). People using voice control who say what they see may not activate it (WCAG 2.5.3). Change it to ``aria-label={`فتح الملف: ${employee.name}`}``.

## Optional follow-ups

2. **`[employeeId]/page.tsx:302`:** «عرض جميع الموظفين» is still always shown. When you came from a search it competes with the back link and leads to the unfiltered list. Showing it only when `backLink.fromTask` matches the agreed design and also puts the otherwise unused `fromTask` field to use. Low risk, since it's clearly labelled and sits at the bottom of the page.
3. **`EmployeeReadiness.tsx:80`:** the review group decides whether to open by checking `reviews[0]`, which only works while the wage stays first. A named `wage` constant would make that safe.
4. **Phone profile:** the profile tabs wrap onto three rows. This was already the case before this batch and is outside its scope.

## What this evidence doesn't cover

- I read the code and viewed 3 images only. I didn't rerun tests, lint or the build. The 9 passing tests, the lint result and `build.log` are your reports.
- I didn't view the tablet, desktop profile or preview-dialog screenshots. Escape-key focus return and the round trip from the account tab back to the same results are from your devQA, not something I verified.
- Restricted roles are only tested in component tests; no live signed-in role UAT has been done. The built-app smoke test is still pending.
- No account, wage or service writes were made. This doesn't cover acceptance of the whole platform.