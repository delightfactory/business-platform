# Design direction for the Arabic RTL workspace: navigation, design system and first three batches

This is design advice only. I changed nothing and haven't seen any rendered screens, so nothing here is visually verified.

## 1. Skills read and the rules I applied
I read all four SKILL.md files: frontend-design, enterprise-workflow-ux, product-flow-ux and arabic-ux-writing. I also read `navigation-model.ts` and `workspace-navigation.tsx`. I skipped the optional screenshot.

The rules I applied:
- Put the bold design choice in one place and keep everything else quiet. Avoid the default "pile of identical cards" look.
- Each page has one job and one main action, named by its business result.
- Show the same authorized destinations on every screen size, just arranged differently.
- Errors appear next to the field and keep what the user typed.
- Arabic copy uses a verb plus its result, and help text is optional and placed next to the decision it explains.

## 2. Navigation layout (chosen)
I considered keeping the top bar and splitting its tabs into "daily" and "setup". I rejected it because there are too many destinations for a top bar, and setup would stay hidden. **Decision: a fixed sidebar on the right (the leading side in RTL) that separates daily work from setup.**

```
┌──────────────────────────────────────────────┬───────────────┐
│ [شريط السياق: الشركة ▾ | الفترة ▾ (للمسير فقط)] [؟][حسابي]│ ▣ منصة الأعمال │
├──────────────────────────────────────────────┤ <bdi>الشركة</bdi>│
│ عنوان الصفحة                 [الإجراء الرئيسي]│ اليوم          │
│ ──────────────────────────────────────────── │ ─ العمل اليومي │
│ عرض: [اليوم] [القائمة]                        │  الموظفون      │
│                                              │  الحضور        │
│  النموذج بعمود واحد (≤640px) على يمين المحتوى │  الإجازات      │
│  التسمية  [؟]                                 │  الرواتب       │
│  [ مثال: المبيعات            ]               │ ─ الإعداد ▾    │
│  ⚠ الخطأ تحت الحقل                            │  الهيكل التنظيمي│
│                                              │  سياسات العمل  │
│                                              │  مصادر الحضور  │
│                                              │  إعدادات الإجازات│
│                                              │  إعداد الرواتب │
│                                              │  الشركة والصلاحيات│
│                                              │ ─ خدماتي       │
└──────────────────────────────────────────────┴───────────────┘
```

**Groups:**
- **اليوم** (Today).
- **العمل اليومي** (daily work):
  - الموظفون (employees): `/people`
  - الحضور (attendance): `attendance`, `attendance/review`
  - الإجازات (leave): `leave`, `leave/balances`
  - الرواتب (payroll): `payroll`, `runs`, `inputs`, `advances`, `reports`
- **الإعداد** (setup): `people/organization`, `work-policies`, `attendance/sources`, `leave/settings`, `payroll/setup`, plus all of today's admin links ("الشركة والصلاحيات").
- **خدماتي** (my services): the user's own links.
- **Operator mode:** نظرة عامة (overview), then الشركات (companies), الدعوات (invitations), فريق التشغيل (operations team), then a separate إدارة المنصة (platform admin) group containing قواعد الرواتب (payroll rules).

**How it's built:**
- Keep the existing filter on server-authorized links. Add a single setup pattern, `/(organization|work-policies|sources|settings|setup)/`, plus the admin list. Any link that matches nothing falls back to its area, so no link is dropped.
- Children show only under the active area, so the horizontal local tabs go away.
- Self-service users with no HR access keep their current يومي / إجازاتي / سجلي (my day / my leave / my record) areas.

**By screen size:**
- **Desktop (≥1200px):** a 248px sidebar.
- **Tablet (768–1199px):** a 72px icon rail. Pressing a group opens its labelled children in a panel.
- **Mobile:** a compact top bar plus up to 4 bottom tabs (اليوم and the first areas) and a "القائمة" (menu) tab, replacing "المزيد" (more). The menu opens a full-screen sheet with the same tree, and الإعداد is always visible in it.

**What stays the same:** the skip link, the offline banner, the account menu and `payrollDestination` carrying the selected company.

One change: stop adding `period` to `/payroll/setup` links. Setup will show only the selected company. I don't know whether any setup screen needs a period. If one does, keep the parameter there and label it "الفترة" (period) instead of hiding it.

## 3. Design system
**Palette (light / dark):**

| Role | Light | Dark |
|---|---|---|
| Text (ink) | `#1B2430` | `#E6E9EE` |
| Page background | `#F5F6F8` | `#12161C` |
| Surface | `#FFFFFF` | `#1A2028` |
| Borders | `#D8DDE4` | `#2C3440` |
| Brand (each of the 4 tenant variants overrides this token) | `#1F5F8B` | `#6FA8D6` |
| Status | success `#2F7A4F`, warning `#8F5B00`, danger `#B3261E` | lighten each to reach ≥4.5:1 contrast |

**Typography:** Alexandria 600 for titles, IBM Plex Sans Arabic 400/500 for body text.
- Sizes: 26 / 20 / 17 / 15 (body) / 13 (meta).
- Line height 1.7 for body text.
- Numbers use `tabular-nums`, and IDs are wrapped in `<bdi dir="ltr">`.

**Layout and density:**
- Content area is at most 1200px wide. Forms are a single column, at most 640px, aligned to the right edge of the content (the start side in RTL), never centered.
- Form sections are separated by a heading and a thin line, not by stacking cards.
- Cards are only for records in a list. Only menus and dialogs get shadows.
- Spacing steps: 4, 8, 12, 16, 24, 32.

**Corners:** 6px for fields and buttons, 10px for panels, fully rounded only for status pills.

**The one bold element:** a pinned bar at the top of the page showing the company and period. It turns brand-colored when a payroll run is open. Everything else stays restrained.

**Fields:**
- The label sits above the field.
- Height is 40px, 44px on touch screens.
- Placeholders are short examples only, for example "مثال: المبيعات" ("e.g. Sales").

**? help:** the button sits next to the label and opens an inline section *under the label* that pushes the field down instead of covering it. It uses `aria-expanded` and `aria-describedby`, and Esc closes it.

**Errors:**
- Each error appears under its field with an icon and text.
- With two or more errors, a summary at the top links to each field.
- Entered values are always kept after an error.

**Buttons:** one filled primary button per state, outlined secondary buttons, and text-only tertiary buttons. Destructive actions are red outlined buttons, and the confirmation states the consequence. A disabled button explains why it's disabled.

**Tabs** are only for views of the same data (for example يومي / قائمة, daily / list). They are never used for navigation.

**Statuses** combine an icon, text and a tint so they're distinct without relying on color: مسودة (draft), قيد المراجعة (under review), معتمد (approved), مدفوع (paid), مرفوض (rejected), ملغى (cancelled).

**Empty and error states:**
- An empty state shows a title and one action.
- A load error is a separate red banner with a retry button, so it never looks like an empty list.

**Focus:** a 2px brand-colored outline with a 2px offset, in both themes.

## 4. Three batches (Codex is the only writer; no backend changes)
**Batch 1: navigation shell.**
- Outcome: an authorized user reaches the org catalog or company settings in two clicks or fewer from any page, on every screen size.
- Acceptance:
  - A role-fixture test proves the links in the navigation tree are exactly the server-authorized links, with nothing added or lost.
  - The active link highlights correctly.
  - Keyboard navigation and the mobile menu sheet work.
  - The selected company carries over into payroll links.
  - Setup links carry no period.

**Batch 2: tokens and form building blocks.**
- Applies the tokens, field, help, error and status components to:
  - OrgCatalogForm
  - people/new
  - leave types and calendars
  - work-policies
  - inputs and corrections
- Fixes the "search clears my edits" problem in long settings: searching within settings filters on the page without reloading it. If a real search request is needed, the page first asks before leaving unsaved changes.
- Acceptance: help never covers a field, entered values survive a failed submit, and both themes pass the contrast checks.

**Batch 3: list and calendar pages.**
- Adds a shared page header, list and detail layouts, and empty and error states.
- The attendance and leave calendar ships with daily and list views only.
- The monthly view waits for an explicit batch-read data contract. Until then: no 31-calls-per-month loops and no fake absence totals.

## 5. Acceptance is three separate checks
**Done:**
- Task and capability coverage: every route and permission is still reachable.
- Simpler journeys, measured before and after: the number of clicks to reach setup, and whether values survive.
- Rendered visual review in both themes at mobile, tablet and desktop sizes.

Each check needs its own evidence after implementation, and the full user journey must be walked through, including what happens when something fails.

I couldn't create a plan file or formally close planning mode because those tools weren't available in this session, so this message is the whole proposal.