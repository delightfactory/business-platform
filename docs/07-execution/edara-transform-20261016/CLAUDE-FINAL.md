# Independent final review

Provider: official first-party Claude OAuth. Model: claude-opus-5-5, effort medium. Session: 9b0c5f11-798e-4d0e-93d6-1560b3d4e771. is_error=false; permission denials0. Read-only inspection, not an independent execution of the parent's tests.

**Verdict: PASS.** I found no blocking defect in the four P2 fixes. The EDARA direction is followed for these flows.

## What I read
I only used Read, Glob and Grep, and ran nothing.
- **Code:** `usePaymentRecovery.ts`, `PaymentForm.tsx`, `runs/RunPayments.tsx`, `create-run-actions.ts` and `CreateRunForm.tsx`, all in full. A targeted search of `payments/page.tsx`. `EmployeeProfileTabs.tsx` in full. Part of `people/[employeeId]/page.tsx` (lines 140–169 plus searches). In full: `attendance/page.tsx`, `AttendanceWorkspaceTabs.tsx`, `SourceSetupFields.tsx`, `LeaveWorkspaceTabs.tsx`, `leave/requests/[requestId]/page.tsx`, `payroll/advances/page.tsx` and `shell/workspace-navigation.tsx`.
- **Screenshots:** 06, 07 and 08.
- **Not read:** SQL migrations, test files, the guide HTML or PDF, `actions.ts`, `navigation-model.ts`. I take your reported results for the 75/75 regression, the 24 wrapper checks, the 9 action error cases and the database counts as given; I did not check them.

## P2 checks
1. **Payment recovery: PASS.**
   - **No lost journal:** the hook lives in `PaymentForm`, which stays mounted. During a request only the form it shows is swapped for the busy message, so the request, the typed values and the journal survive.
   - **No stuck busy flag:** `activeRequests` is only set after the cross-tab lock is acquired, and the `finally` block (`usePaymentRecovery.ts:37`) clears it on every early return and on network failure.
   - **One owner, one busy message:** the main form and the recovery form are mutually exclusive in both `RunPayments.tsx:30-31` and `payments/page.tsx:38/42`. Correction forms show nothing while busy (`PaymentForm.tsx:21`). The journal key leaves out `original`, so corrections share the same lock and journal.
   - The cross-tab lock (`ifAvailable`) still decides; the busy flag is display only.
2. **Create run: PASS.** The settled check is the exact code-and-message match at `create-run-actions.ts:31-32`. The journal is cleared only when the result is settled or a period comes back (`CreateRunForm.tsx:34,37`). Permission (42501), identity mismatch and thrown network errors keep the journal.
3. **Employee payroll tab: PASS.**
   - The payroll lookup only runs when `tab=payroll` (`page.tsx:152`).
   - Clicking the unloaded tab navigates in one step (`EmployeeProfileTabs.tsx:30`), and the page remounts because of `key={initialTab}`.
   - `forceMount` is kept, with hidden panels. The noscript links are kept, and so is a real fallback link (`page.tsx:328`).
4. **Amendment run mix:** I accept your evidence. I did not reread the SQL and I'm not asking for a UI change.

## Other UI files
I found no defects, and none of these change a backend contract. The attendance and leave tabs, the leave request detail page, the advances page and the shell navigation all follow the pattern: record list first, actions based on the record's state, rare tools behind disclosures, and a working Settings route (`settings/page.tsx` exists).

## Optional polish (not blocking)
- **06, phone payroll list:** the table scrolls sideways, so the gross and net columns are off-screen. Payroll is also not one of the four bottom tabs; it is only reachable through the menu. The "N" badge over the menu button is the Next.js dev indicator.
- **07, saved employee data:** the screenshot does not show the saved message. I'm relying on your root UI check that it appears.
  - The period dropdown shows ISO dates `2026-10-01 — 2026-10-31`, while the text below says `16 أكتوبر — 31 أكتوبر`. Both the format and the range differ.
  - The required `*` sits alone on a line under the insurance label.
- **08, employee payroll history:** the date is in ISO format, and the heading "مسيرات الرواتب المحفوظة" appears twice.
- **Saved message trusts the URL:** `page.tsx:149` only checks that `payrollSaved` and `payrollPeriod` look like valid IDs. A hand-edited URL could show the saved message even though nothing was saved. This only affects the person who edits the URL.
- **Success message after full payment:** when a payment clears the full remaining amount, the main form is replaced by the recovery-only one and the short success message disappears. The "تم تسجيل كامل الصرف" heading and the totals still show the result.
- **Misleading error in `CreateRunForm.tsx`:** if saving to browser storage fails in `persist`, the user sees "لم تصل النتيجة" even though nothing was sent.
- **Advances page wording:** the link at `advances/page.tsx:51` says "تغيير الشركة" while the rest of the page says "جهة العمل" (employer). The bare "الرواتب" link at line 72 is vague.

The screenshots are synthetic test data marked NONLEGAL. Nothing here is a legal or financial certification, and no real bank transfer happened.