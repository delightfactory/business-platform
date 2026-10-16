# Verdict: NEEDS_FIXES

There is one material blocker. It is a small, systemic RTL direction defect that shows clearly in the current captures. Everything else is either acceptably evidenced or an optional note.

## Material finding

**M1. Arrow icons point the wrong way in RTL, including the cue on the employee's main clock-in action.**

- **Source of the problem:**
  - `src/components/ui/ui.css:1` flips every directional icon in RTL (`.ui-icon-directional:dir(rtl){transform:scaleX(-1)}`).
  - `src/components/ui/icon.tsx:9` marks `arrowLeft` and `arrowRight` as directional.
  - But the call sites already use the arrow names as screen directions in RTL: `arrowLeft` for "forward" and `arrowRight` for "back". So each arrow gets flipped a second time and ends up reversed.
- **Where it shows in the captures:**
  - `entry-dark-390.png`: the "افتح مساحة العمل" button shows → (`src/app/page.tsx:10`).
  - `employee-home-dark-390.png`: the swipe prompt "اسحب لتأكيد الحضور" shows → (`SlideToConfirm.tsx:19`). The handle starts on the right and must be dragged left (`origin - clientX`, line 26), and the hint text says "من اليمين". The arrow contradicts the gesture on the employee's most frequent action.
  - `employee-work-unavailable-light-390.png` ("← العودة إلى يومي", `me/attendance/page.tsx:24`) and `employee-request-dark-390.png` ("← إجازاتي", `me/leave/new/page.tsx:52`): back buttons point forward.
  - The sidebar guide link shows → in every desktop capture (`workspace-navigation.tsx:119`).
- **A correct counter-example:** `src/app/operator/page.tsx:46` uses a literal ←, and `operator-home-dark-390.png` renders it correctly. So the same "forward" meaning appears in both directions across the app.
- **Same pattern elsewhere:** `task-card/index.tsx:15`, `tenant/select/page.tsx:36`, `today.tsx:153`, `me/page.tsx:62`, `me/leave/page.tsx:150`, and the back links in the `attendance/import`, `attendance/[instanceId]` and `attendance/unassigned` pages.
- **Minimal fix:** in `icon.tsx:9`, keep only `chevronLeft` and `chevronRight` as directional. Then recapture these four frames: entry, employee home, employee work-unavailable, employee request.
  - The month calendar's previous/next chevrons currently look correct (`month-light-1366.png`), so don't touch the chevrons unless you re-verify them.
  - No business, authorization or data impact.

## Evidence assessment (no blockers)

- **Coverage:** `families.csv` covers all 14 families. The 80 captures are correctly described in `RESULT.md` as theme/geometry evidence only, not proof of all 84 routes, accessibility, GPS or payroll. The limits are stated honestly: empty employee history, missing work site, admin denied, and a nonexistent-tenant negative. There are no fabricated grants.
- **Guide:** the role receipt shows the employee sees exactly their three topics, and the full guide stays selectable. That's acceptable.
- **Disabled states and errors are explained:**
  - The attendance-source form's disabled create button has a hint ("اختر طريقة تسجيل الحضور للمتابعة").
  - The login error says what happened and what to check.
  - The finance screen shows its real stale-data blocker with one primary recovery action.
  - The import page states its limits before the check.
  - Leave review explains what "مقدّم" means.
  - The work-unavailable screen gives a cause and who to follow up with.
- **Navigation and settings:** the setup readiness steps, editable payroll items, and the month calendar's honest legend and today marker all look sound. The calendar layout is correct: 1 Oct 2026 is a Thursday.

## Optional notes (not blockers)

1. On the employee home, the mobile header says "ملفي" while the bottom nav and page heading say "يومي". The cause is the `/me` link label at `context-navigation.tsx:112`.
2. On the daily attendance page at 390 width, six stacked controls push the records below the fold. "عرض الشهر", "فتح قائمة المراجعة" and "أدوات الحضور" could be grouped.
3. The work-unavailable card's "سجلي" button goes to the history already shown below it on the same page, which adds little.
4. The payroll item code `pay_hed2z3pat5m2` reads as technical. It's fine if it's a fixture value, but readable defaults for new codes would help.
5. Lone status badges ("نشط"/"نشطة") float far from their titles on the record and operator-services screens. The month picker's native input shows "October 2026" in English. Both are cosmetic.

## What I inspected

- **Skills (read explicitly, not auto-invoked):** frontend-design, enterprise-workflow-ux and arabic-ux-writing `SKILL.md`.
- **Documents:** `RESULT.md`, `families.csv`, `guide-role-receipt.json`, `BATCH-9.md`, and the first 40 lines of `frames.json`.
- **Source files read:** `icon.tsx` and `SlideToConfirm.tsx`.
- **Searches:** the CSS mirror rule, arrow icon call sites, "ملفي" and "شركة جديدة".
- **Images (all 17 requested):** entry-dark-390, auth-dark-390, directory-light-1366, record-light-1366, task-form-dark-390, setup-light-1366, finance-dark-390, review-light-1366, daily-dark-390, month-light-1366, payroll-config-dark-390, import-light-1366, operator-home-dark-390, employee-home-dark-390, operator-services-light-1366, employee-request-dark-390, employee-work-unavailable-light-390.

## What I did not inspect or run

- **Not inspected:**
  - The other retained images: employee-request-detail, employee-leave, employee-history, self-permission-denied.
  - The full `frames.json`, `capture-manifest.json` and `source-hashes.json`.
  - The per-batch result and acceptance files.
- **Not run:** no tests, builds, browser, Git or hash checks. No keyboard, screen-reader, GPS, payroll or mutation tests.

I made no source changes. I also didn't write the plan file, because no write tool was available in this session.