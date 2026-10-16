# Attendance calendar: design and interaction contract

This is a proposal for review. I have not implemented or rendered anything. The numbers come from your QA measurement (built 283a73b) and the baseline image; no "after" figures exist until the batch runs.

## 1. Recommendation: route, flow and navigation

- **Add a new read-only page** at `/tenant/[tenantId]/attendance/calendar?month=YYYY-MM`. The folder name `calendar` takes precedence over the existing `attendance/[instanceId]` route, so nothing there changes.
- **Leave `/attendance` as the main "الحضور" destination. Don't make the calendar the default.** The most common job is still "work on today". A calendar landing page would add one click before that work. That click would trigger the same `attendance_open_day` GET as today, so it gains nothing.
  - If the calendar becomes a nav destination, `matchesDestination` (`navigation-model.ts:67`) would stop marking `/attendance` and `/attendance/[id]` as active. You would then need a second link anyway.
- **Exact nav changes:**
  - `src/components/context-navigation.tsx:105`: inside the same `attendanceAccess` guard, push `{ href: \`/tenant/${tenantId}/attendance/calendar\`, label: 'تقويم الحضور' }` right after the existing link. Give it no `mobilePriority`, so it doesn't crowd the phone bar.
  - `src/components/shell/navigation-model.ts:9`: change `timeOrder` to `['attendance', 'attendance/calendar', 'attendance/review', …]`.
  - Nothing else changes. Longest-prefix matching (`:73-78`) already highlights the calendar link on `/attendance/calendar` and "الحضور" on `/attendance` and `/attendance/[id]`. `isSetup` and `hasTeamWorkspace` are unaffected.
- **Day page (`attendance/page.tsx`), small additions with the GET and RPCs unchanged:**
  - **Previous/next day links:** ghost links "اليوم السابق" and "اليوم التالي" next to the date form, linking to `?date=±1`. This is the measured change: moving to an adjacent day goes from 2 actions to 1.
  - **Month link:** a secondary "عرض الشهر" link to `/attendance/calendar?month=${day.slice(0,7)}#day-${day}`. Returning keeps the month and the hash scrolls to that day.
  - Keep "عرض اليوم" as the only solid button. Keep all four permission-gated tools.

## 2. Data contract (additive migration)

The function would be `attendance_month_calendar(p_tenant_id uuid, p_month date) returns jsonb`.

- **Function type:** `STABLE`, `SECURITY DEFINER`, fixed `search_path`. Revoke from `public`/`anon` and grant to `authenticated`.
- **Guard:** reuse exactly the guard `attendance_day_list` uses (`supabase/migrations/20260930111500_attendance_history_after_entitlement.sql`). That keeps the same roles and still allows historical reads when the entitlement is off.
- **Input:** reject `p_month` unless it is the first day of a month between 2000 and 2100 (`22023`).
- **Query:** one `GROUP BY operational_date, status` over `[p_month, p_month + 1 month)` on the existing `(tenant, operational_date, employee_id)` index.
- **Output:** a sparse result `{month, days:[{date, open, ready, needs_review, approved}]}`.
- **Excluded:** no employee data, no leave or location fields, no inserts or preparation, no derived absence/weekend/future states. It never loops over `attendance_day_list`.

## 3. Layout (desktop, RTL)

```
تقويم الحضور                                        [فتح يوم اليوم]  ← only solid button
يعرض السجلات المحفوظة فقط ولا يجهّز أيامًا. اليوم بلا سجلات لا يعني غيابًا.
┌──────────────────────────────────────────────────────────────────┐
│ [› الشهر السابق]  أكتوبر 2026  [الشهر التالي ‹]  [شهر: ____ ][عرض] │
└──────────────────────────────────────────────────────────────────┘
Legend: ! يحتاج مراجعة · ◐ جاهز للمراجعة · ○ قيد المتابعة · ✓ معتمد   (shape + text + tone)
Month totals (records, not employees): يحتاج مراجعة 13 · جاهز 6 · معتمد 3 · قيد المتابعة 0
┌السبت┬الأحد┬الاثنين┬الثلاثاء┬الأربعاء┬الخميس┬الجمعة┐
│     │     │      │   1    │  …     │      │      │
│ 14 اليوم? │ ! 2 مراجعة  ◐ 6 جاهز  ✓ 3 معتمد │ …  │
│ 15  │ ! 11 مراجعة │ …                          │
└─────┴─────┴──────┴────────┴────────┴──────┴──────┘
```

(Counts are illustrative, based on your QA dates 14 and 15.)

- **Grid:** a semantic `<table>` with a `<caption>` ("سجلات الحضور المحفوظة — أكتوبر 2026") and `th scope="col"` headers. Weeks start on Saturday. Day 1 sits in the column for its weekday. Leading and trailing cells stay empty with no links, and no column is styled as a rest day.
- **Each in-month cell is one `<a prefetch={false}>`** linking to `/tenant/${t}/attendance?date=ISO` with `id="day-ISO"`.
  - **Why `prefetch={false}`:** opening a day runs `attendance_open_day` for managers. The default link behaviour (per the `link.md` docs) partially prefetches dynamic routes, so disabling it guarantees that just viewing months never prepares anything.
  - **Visible text:** day number, then only the non-zero status lines in this order: needs review → ready → open → approved.
  - **Accessible name:** for example `aria-label="الثلاثاء 14 أكتوبر 2026: 11 سجلًا — 2 يحتاج مراجعة، 6 جاهز، 3 معتمد"`.
  - **Empty day:** the number plus muted text "لا سجلات". It is still a link.
  - **Today:** `aria-current="date"` plus the visible word "اليوم".
  - **Returning from the day page:** the `:target` cell gets an outline ring.
- **All in-month days are links, including future dates.** Shift timezones can start a day before Cairo does, and the day page already explains preparation rules. Showing "future" as a state would be invented.
- **Keyboard:** native tab order through the links with a visible focus ring. No roving grid focus (that would be over-engineering).
- **Secondary actions:** "قائمة مراجعة اليوم" (`/attendance/review?date=today`, shown when `can_view`). The day page stays the hub for sources, import and unassigned records. The nav also keeps them one click away, so the calendar is never a dead end.

## 4. Mobile and medium widths

- **Up to 640px:** the grid keeps 7 columns with `minmax(0,1fr)`, a 2px gap and reduced panel padding, so it fits 390px with no horizontal overflow.
  - Each cell is at least 44px tall and shows the day number plus one glyph: `!` if anything needs review, `✓` if everything is approved, `•` for other records, nothing if empty.
  - The legend is visible above the grid. Full counts stay in the `aria-label`.
  - Below the grid, a short "أيام تحتاج مراجعة" list (days where `needs_review > 0`) gives full-text rows with 48px links, so phone users aren't decoding glyphs.
- **Month controls on phone:** previous/next become 44px icon buttons with `aria-label`s, and the month heading sits between them. The jump form wraps onto its own full-width row.
- **640–900px:** the full status lines collapse to "N سجلات" plus the priority glyph.

## 5. Month and date validation

- `month` must match `^\d{4}-(0[1-9]|1[0-2])$` and fall within 2000–2100.
- Missing → current month in Cairo time (reuse `cairoToday()`, which is currently duplicated in `page.tsx:87` and `review/page.tsx`).
- Invalid → `Message tone="info"` reading "تعذر قراءة الشهر المطلوب؛ يُعرض الشهر الحالي." with the current month shown.
- The jump control is `<input type="month" name="month" pattern="\d{4}-\d{2}" placeholder="2026-10">` in a GET form. Safari and Firefox fall back to a plain text box, which the server-side regex covers.
- Previous/next are plain links built on the server with UTC month arithmetic.

## 6. Role, error, empty and recovery cases

| Case | Behaviour |
|---|---|
| No client | Same `Status` as the day page, with retry pointing to the same month |
| Not signed in | Redirect to login with `next=/tenant/${t}/attendance/calendar?month=…` |
| Access snapshot error or no access | Same text as the day page, "الحضور غير متاح…" |
| Entitlement disabled | Same info message as the day page; historical counts still shown |
| Month RPC error | "تعذر تحميل ملخص الشهر. لم يتغير أي سجل." in place of the grid; month controls and "فتح يوم اليوم" stay visible; retry link to the same month |
| Month with no records | Grid still renders; message "لا توجد سجلات محفوظة لهذا الشهر." No absence wording |
| Viewer without open permission | Day links lead to the read-only `attendance_day_list` path, which is unchanged |

There is also an honesty note for users who can open days: show "فتح يوم قد يجهّز سجلاته، فقد تتغير أعداد التقويم بعد العودة." This is true, because `attendance_open_day` prepares records.

## 7. Files

- **New:**
  - `src/app/tenant/[tenantId]/attendance/calendar/page.tsx`
  - `src/app/tenant/[tenantId]/attendance/calendar/calendar.module.css` (reuse the `.toolbar`/`.dateForm` patterns rather than importing them)
  - `supabase/migrations/<ts>_attendance_month_calendar.sql` plus its pgTAP test
- **Edited:**
  - `src/app/tenant/[tenantId]/attendance/page.tsx` (previous/next/month links only)
  - `src/components/context-navigation.tsx:105`
  - `src/components/shell/navigation-model.ts:9`
  - The attendance guide topic, if it lists routes

## 8. Proportional verification

1. **pgTAP:**
   - each role allowed and an unrelated member denied
   - cross-tenant reads denied
   - entitlement-off historical reads allowed
   - non-first-of-month and out-of-range input rejected
   - October 2026 QA counts: 14th = 3 approved, 6 ready, 2 needs review; 15th = 11 needs review
   - function is `STABLE` and `work_instances` row counts are unchanged after calls
2. **Lint, type check and build.**
3. **Owned QA runtime checks:**
   - Month navigation creates no requests to the `/attendance?date=` route and the instance count stays unchanged.
   - Clicking the 14th opens the existing day page with the same results as before.
   - The "عرض الشهر" round trip lands on October with the 14th highlighted.
   - An invalid `?month=` value and an RPC failure both show the recovery screen.
4. **Renders:** 1366, 768 and 390 in light and dark; no horizontal overflow at 390; cells at least 44px; keyboard pass; screen-reader names spot-checked.
5. **Before/after to record:**

| Measure | Before | After target |
|---|---|---|
| Adjacent day from the day page | 2 actions | 1 |
| Month overview | none | 1 page |
| Reaching a day from the overview | — | 1 click |
| Clicks to reach today's work from "الحضور" | — | unchanged |

Rendered evidence still needs a separate visual verdict. Until those images exist, this contract is **NOT VISUALLY VERIFIED**.