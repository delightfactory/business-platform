# Batch 3c review: **ACCEPTED**, with no blockers

The acceptance is tied to the source I read now. The final rebuild still has to run, and the reviewed files must stay unchanged until it does. Three small fixes are listed further down; none blocks acceptance.

## What I checked myself
I read the source files, the migration, both tests and the three images. I didn't run anything, so test, build and runtime results below are your claims, not my checks.

**Leave settings entry (`settings/page.tsx`, `rules.ts`, migration `…030516`)**
- **Uniqueness check:** it counts at most 2 entities, active and stopped, within the tenant only. It runs after the existing permission and input checks and ignores search and page cursor. The signature, `REVOKE`/`GRANT` and paging are unchanged.
- **Redirect (`page.tsx:85`):** it runs only after login, access, `canView`, the parameter checks and a successful, strictly parsed response. It needs no flag, no search and no cursor.
- **The list stays a list once chosen:** the search form, clear search, next page and first page all carry `choose_employer=1`.
- **Settings page links back with the flag:** the top link and all three error-screen back paths go to `?choose_employer=1` and say "عرض كل الجهات". The settings page never redirects back, so there's no loop.
- **Adapter:** a missing hint means none, `null` or a UUID is accepted, anything else is rejected. The tests cover this, plus that one visible row alone is not treated as "unique".
- **Database tests** cover:
  - one filtered row and a last page are not treated as unique;
  - zero entities;
  - a sole stopped entity;
  - other tenants are not counted;
  - search and cursor don't affect the result;
  - one active plus one stopped still shows the list;
  - an unauthorized user gets `42501`.
- **The false "available to edit" line is fixed.** Active cards show only the badge. Stopped cards say they are view-only and their button reads "عرض السجل".
- **Empty states:** with no search there's no "clear search" advice; with a search the message is correct.
- **Main action:** search and next page are now secondary buttons, so choosing an entity is the main action.

**Settings page progress steps (`[employerId]/page.tsx`)**
- Each step shows only whether a calendar, year or type is saved ("مسجل"). The balances panel stays optional and doesn't claim employees are ready.
- With no calendar, the "add year" button is replaced by a prerequisite note.
- The steps are an `ol` with `aria-current="step"` on the current one. They collapse to one column at 600px or narrower.

**Payroll policy**
- **The new policy form** (`InputForm.tsx:53`) shows only the start date and sends an empty hidden end date. Payroll item forms and operational inputs are untouched.
- **New-policy copy (lines 43 and 55)** says the policy continues with no end and can't be edited from this form. It makes no claim that there's no way to change it anywhere.
- **A saved policy end date (`configuration/page.tsx:77`)** is still shown, with a truthful warning that payroll review won't complete after that date. The page says the policy can't be changed "من هذه الصفحة". This matches the `policy_coverage_gap` behaviour you confirmed on the database.

**Images**
- **`desktop-hub.png`:** RTL layout, the "عرض كل الجهات" link is narrow, the three steps are done, there's one clear call to action, and no overflow.
- **`phone-hub-dark.png`:** the steps stack vertically and dark mode is readable.
- **`phone-chooser-light.png`:** a single entity shown in the explicit list view, the active badge with no false claim, a secondary search button, and the bottom navigation is intact.

## Non-blocking fixes (cheap, recommended)
1. **Some list links still drop the flag.** "Retry" and the login `next` on the list's error screens use the plain `/leave/settings` path. In a single-entity tenant, retrying from a list the user opened on purpose lands on the entity's settings page instead. That's not a loop or a lost capability, since "عرض كل الجهات" is right there. Fix: pass `chooserPath` whenever `chooseEmployer` is set.
2. **View-only users see a "next step" they can't act on.** The steps still label the current step "الخطوة التالية" even when `!canEdit`, and those users have no next-step panel. Show "لم يُسجل بعد" when `!canEdit`.
3. **Doc and source disagree on the calendar link.** `BATCH-3C.md` says "link to calendar". The source shows only the text "يتطلب إضافة تقويم أولًا." while the "إضافة تقويم" button sits in the panel directly above. Either add the link or fix the doc.

## Not run (don't count as accepted)
- These evidence gaps are already noted in your README:
  - creating a new policy and saving it in the browser;
  - a saved policy with an end date, viewed in the browser;
  - stopped, multiple, zero and denied users in the browser;
  - payroll calculation and payment;
  - screen reader and real touch.
- **Image versions:** the two settings-page images are from the dev server, and `phone-chooser-light.png` is from the build before the back-link fix. Attach the final rebuild's identifier when recording this verdict.