# Batch 4 attendance calendar review: ACCEPTED, no blocking corrections

## What this verdict rests on
- **My own checks:** source reading plus 4 images. I read `BATCH-4.md`, the calendar `README.md`, `calendar/page.tsx`, `calendar.module.css`, `attendance-calendar.ts`, the migration and its pgTAP test, the edited day page, the nav additions, the shell prefetch line, and the 4 named screenshots.
- **The parent session's evidence, which I did not re-run or open:** 25 database tests, 3 parser tests, 9 nav tests, lint and build; the no-request and 99-instances-unchanged captures; ACL failure injection; the keyboard journey. Those results are cited from `README.md` only.

## Data layer and safeguards (source-verified)
- **Same roles as the day page.** The function's permission list matches the `v` roles in `time_attendance_access_snapshot` exactly, so the page's `can_view` gate lines up with the function. It is read-only (`STABLE`), uses an empty `search_path`, and grants execute only to `authenticated`.
- **One bounded query, no personal data.** A single `GROUP BY` covers one month. It returns only date and status counts: no employee, leave or location fields, and no absence or rest-day inference.
- **Month bounds are enforced.** Only the first day of a month between 2000 and 2100 is accepted; `infinity` and `NULL` are rejected.
- **Errors never show as empty.** `readMonthCalendar` rejects a wrong month, duplicate dates, more than 31 days, negative or unsafe numbers, and zero-total days. A failed read shows an alert with no table and a retry for the same month, not fake zeros.
- **Viewing months prepares nothing.**
  - Every day link on the calendar and the agenda, and the day page's previous/next links, set `prefetch={false}`.
  - The shell's "الحضور" nav link (`workspace-navigation.tsx:38`) disables prefetch for the bare `/attendance` path. It doesn't need to cover query strings because no nav item carries one.
- **Existing day behaviour is untouched.** The day page's data calls are unchanged.
- **No capability was removed.**
  - The review link stays visible.
  - Sources, import and unassigned keep their original permission checks, now inside «أدوات الحضور».
  - The nav keeps "الحضور" as the main destination, adds "تقويم الحضور" after it under the same access check, and leaves the settings classification alone. The nav test covers deepest-match highlighting and the unchanged default.

## Task completion
- **Before** (built 283a73b): moving to the next day took 2 actions, and there was no month view.
- **After:**
  - **Adjacent day:** previous/next links make it 1 click.
  - **Month and back:** month → day is 1 click, and the return link `?month=…#day-…` comes back highlighting the same day.
  - **Today:** reaching today's work is unchanged, still via the default "الحضور" destination.
- **Real data:** the desktop image shows 14 Oct as 2 needs review / 6 ready / 3 approved and 15 Oct as 11 needs review, matching the QA data. 1 Oct sits correctly under الخميس in the Saturday-first layout.
- **Stale inputs fixed:** keying the date and month forms resolves the observed stale-field bug.

## Simplicity and honesty
- **One clear main action per page:** "عرض حضور اليوم" on the calendar, "عرض اليوم" on the day page.
- **Wording is honest:** the copy says counts are work records, not employees or proof of presence. Empty days read "لا سجلات", not absent. Users who can open days are told that opening one may prepare its records.

## Recovery
- Invalid month → visible notice and the current month.
- Read error → alert and retry for the same month.
- Entitlement off → history stays readable.
- Not signed in → login with the month kept in the return link.
- No access → a plain explanation.

## Responsive, RTL and keyboard (source and images)
- **Phone (390px):** 7 columns with no overflow; the parent measured cells at about 45.6×61px.
- **Phone glyphs:** the `!` number is the needs-review count, and the agenda gives full-text rows at least 48px tall.
- **Weekday headers:** each has the full name as its accessible label, and short visible names on phone.
- **Month arrows:** they mirror correctly in RTL.
- **Keyboard:** day cells are plain links with a focus ring, and the return target is outlined.
- **Day toolbar:** it no longer stacks into a tall narrow column.
- **Limits:** screen reader and real touch were not run (the parent states this), and I only saw images at 1366 and 390.

## Optional polish (non-blocking, can be grouped later)
1. **Phone glyphs aren't all in the visible legend.** Phone cells use `•` and `—`, but the totals strip shows `◐` and `○`. The full key is only inside the collapsed «كيف أقرأ التقويم؟» note. Add `•` and `—` to the visible notes line, or reuse the same symbols.
2. **Today is hard to spot on phone.** The «اليوم» label is hidden there, so today relies on fill colour alone (it does keep `aria-current`). A thicker border or a small dot would fix it.
3. **Duplicate link.** «عرض اليوم وأدوات الحضور» at the bottom of the calendar goes to the same place as the header's main button. Drop it, or keep only «قائمة مراجعة اليوم».
4. **Overstated sentence in `BATCH-4.md`.** It says "every link that opens day" disables prefetch. The older back links in review, `[instanceId]`, import and unassigned don't, but they are not a risk: the default prefetch stops at `tenant/[tenantId]/loading.tsx` and never renders the day page. Either soften the sentence or add `prefetch={false}` to those 4 links.
5. **Test coverage:** the cross-tenant test uses a tenant ID that doesn't exist. A second real tenant that has saved records would prove isolation more strongly.
6. **Month picker language:** in Chromium the month picker shows "October 2026" in the browser's own language. That's acceptable; the server-side check covers the fallback in other browsers.

This acceptance covers Batch 4 attendance only. It is not acceptance of the whole platform or of all routes.