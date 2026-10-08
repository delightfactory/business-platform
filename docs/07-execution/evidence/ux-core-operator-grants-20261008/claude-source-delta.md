# Official direct Opus5.5 Medium source review

Read-only supplied sources/SQL, no images inspected. Session df1dfee6-d344-4464-9d39-30fb1488a841.

# R3 operator grants: final source delta review

I used no tools and made no edits. This review covers only the supplied `page.tsx` delta, the status SQL, and the earlier files and SQL.

## Verdict

**Delta conditionally accepted, with 2 small must-fixes.** Both are copy or markup only and need no authority, storage, RPC, SQL or protocol change. This is not R3, B1/B2 or journey closure.

## Accepted

- **Re-read the grant list**
  - `<form method="get" action="/operator/operators">` uses a string action, so the browser does a full native navigation instead of a soft client transition. That gives a fresh server render through the full guarded route.
  - It drops any `?state=…` value from the URL.
  - Nothing revalidates automatically on failure, so values retained in failed forms are not silently replaced.
- **Status read guard**
  - The status SQL always returns exactly one row with `active`, `revoked` or `not_operator`, because `FROM (SELECT auth.uid())` always produces one row.
  - The page treats anything else, or a non-boolean `canManage.data`, as a read failure ("تعذر التحقق من الصلاحية"), not as a denial.
  - Denial is now reached only from a valid status value plus a boolean capability. The remaining `operatorPermission(canManage)` check is redundant but harmless.
- **Accessible names** now start with the exact visible label: `تعديل المهام: …`, `إعادة منح المهام: …`, `سحب الصلاحية: …`.
- **Error page** now has a native GET re-read plus a return link to `/operator`. Confirmed denial is no longer a dead loop.
- **Correction accepted:** a *thrown* RPC or transport rejection is not mapped by this action. Only a *returned* `error` maps to `failed`. Recovery from a throw in the shared form remains **OPEN**. No new catch, redirect or attempt protocol was added, which is correct for this scope.

## Must-fix

**1. The re-read warning is ambiguous about losing input, and screen readers won't announce it.**
- "وتترك أي تعديلات غير مرسلة" can be read as "keeps your unsent edits", which is the opposite of what happens.
- Use unambiguous wording, for example: "إعادة القراءة تجلب الحالة الحالية وتُفقد أي إدخالات لم تُرسل. لا تؤكد وحدها نتيجة تغيير سابق غير مؤكدة."
- Give the hint an `id` and point to it from the button with `aria-describedby`. As placed now, a keyboard or screen-reader user reaching the button does not hear the warning.

**2. The error page has no single primary action, which breaks the owner rule of one clear primary per state.**
- `Status` now shows two equal `secondary-button` controls.
- For read failures (setup, account check, permission check, list load), "إعادة قراءة الصفحة" should be the primary.
- For confirmed denial ("إدارة المشغّلين غير متاحة"), "العودة لمهام المنصة" should be the primary and re-read secondary or absent.
- Implement this with a small per-call variant prop using the existing `primary-button` and `secondary-button` classes. No token or hierarchy change is needed.

## Still should-fix (not blocking)

- Self-revoke and self-downgrade routing still compares emails. `result.user_id === user.id` is the exact identity check, and the receipt already includes the validated UUID.
- The lifecycle capability is labelled "إدارة حالة الشركات" in the list but "تعليق الشركات واستعادتها وأرشفتها" on the checkbox.

## Limitations (do not claim)

- **Verification:** the 46 source-controlled DTO, action, page SSR and controlled-SDK cases cover source logic only.
  - You described lint/build-TS as "running/completed compilation". Do not record that as passed unless the run actually finished with exit 0.
- **Not proven:** real SQL, roles, Auth and provider behaviour; native browser form behaviour; mounted uncertainty; authority loss or account switching; thrown-RPC recovery; historical intent recovery (there is no per-attempt receipt); measured N/C/P/I/B.
- **Visual:** both full-visual verdicts remain **NOT VISUALLY VERIFIED**. ConceptC has no grants screen.
- **Out of scope:** no closure of B1/B2/R3/R0–R8; no PR, merge or deploy; no financial or D16 change; no payroll A/B decision.
