Review done. One required fix found; everything else passes.

# Review: dynamic training guide changes (Opus 5.5, read-only)

## Required fix

**R1. The guide's first instruction points to a section the filter hides.**
- `scripts/build-user-guide.cjs:8` tags section 1 «رحلتك حسب دورك» as `overview`. No role or personal selection includes `overview`, so section 1 only appears in «الدليل الكامل».
- But «كيف تستخدم الدليل؟» is tagged `common`, so it shows in every view. Its first line (`docs/user-guide/ar.md:10`) says «ابدأ بصفحة «رحلتك حسب دورك»».
- In the employee view I inspected, the table of contents goes straight from «كيف تستخدم الدليل؟» to «2.». So the first step sends users to a page they can't see.
- This also hides the role summary and the quick routing table (`ar.md:63-96`), including «تسجيل حضورك ← اليوم أو حضوري» and «تقديم إجازة لنفسك ← إجازاتي». That content is the most useful starting point for each role.
- **Fix:** in `topicFor`, return `common` for `number===1`. Keep `overview` only for «الفهرس», whose static list names all 32 sections. The employee view then has 7 headings, so update the measured "6" to 7. Alternatively, reword `ar.md:10` for filtered views, but that is weaker because it removes the routing table.

## Non-blocking notes (no fix required)
- **Pending accounts:** they get `?topics=profile`, which shows section 14 (attendance) because the «ملفي» paragraph lives there (`ar.md:360`). That's acceptable: its recovery paragraph «إذا لم تظهر البطاقة» (`ar.md:375`) is the right next step for an account with no services yet.
- **Printed subset:** print CSS hides `.guide-tools`, so a printed role-specific copy doesn't say which sections were selected. Adding a print-only line with the status text would help. Optional.
- **Without JavaScript:** all sections show, which is safe, but the selector does nothing. Acceptable for a static document.

## Source, privacy and authorization: PASS
- **No identifiers in the link:** `guide-navigation.ts:8` strips `/tenant/<id>` plus any query string or `#` fragment. The link carries only fixed topic names, never tenant or account IDs.
- **Untrusted input is handled safely:** `user-guide-filter.js:14` only accepts topic names from a fixed list, and the status line is written as plain text.
- **Topics match real permissions.** Each route the helper reads matches a server-authorized link in `context-navigation.tsx:81-122`: `users`, `entities-sites`, `branding`, `people`, `people/work-policies`, `attendance`, `attendance/sources`, `leave`, `leave/settings`, `leave/balances`, `payroll/*` (including the reports `?report=` link), `me`, `me/attendance` and `me/leave`.
- **Mixed roles:** they get the union of topics, because `workspace-navigation.tsx:124` passes both link lists.
- **Operators:** operator mode is scoped to `operator` only.
- **Defaults:** a direct public visit falls back to the full guide, and the "my sections" option is disabled when there are no topics (`filter.js:18-19`).
- **No access control:** the guide only filters what is shown, and it says so to the user.
- **Labels in the changed text exist in the app:** «حضوري اليوم», «مساحتك جاهزة», «سجلي», «تم تسجيل الحركة», «أنت في العمل», «حساب الدخول», «الصلاحية مضافة», «حفظ سياسة الدوام», «العمل والتعيينات», «إنشاء الحساب وإرسال رابط التفعيل», «إرسال طلب الإجازة» and «بانتظار القرار».
- **Leave example:** the "5 → 4, pending doesn't deduct" example is labeled as teaching numbers only (`ar.md:251`).
- **Print and PDF:** the print button prints only the visible sections. The PDF download is labeled «تنزيل الدليل الكامل PDF».

## Coverage: PASS once R1 is fixed
Nothing is lost: «الدليل الكامل للتدريب» is always one choice away, and the PDF is the complete guide. Today the role summary (section 1) is unreachable in filtered views. That is the only coverage gap.

## Journey and simplicity: PASS once R1 is fixed
- **Actor and job:** a company user opens the guide from «حسابي ← دليل الاستخدام والتدريب» to learn their own tasks.
- **Outcome:** the guide opens on their sections. For the employee example, the table of contents goes from 35 headings to 6 (7 after R1). That is a real reduction in navigation, measured from the rendered page.
- **Choices and recovery:** one selector, with a status line naming the selected sections and pointing to the full guide.
- **Accessibility:** the selector has a label, controls are at least 44px tall, the status is announced to screen readers, and the layout is RTL.
- Comprehension and timing were not studied, and I don't claim they were.

## Visual verdict
**Desktop: MATCH WITH ACCEPTED DEVIATIONS. Mobile: NOT VISUALLY VERIFIED.**
- **Images inspected:**
  - `guide-employee-desktop.jpg`
  - `guide-employee-mobile.jpg`
  - the prior accepted `docs/07-execution/field-help-training-20261015/images/guide.jpg`
- **Desktop:** it keeps the accepted document styling: same header colour, white cards, sidebar table of contents, and typography.
- **Deviations:** the new white «الدليل المناسب لمهمتك» panel and the renamed buttons. They fit the accepted document style, and the shell layout and theme are untouched.
- **Mobile:** the 390px image was too low-resolution to read. I could only see a single column and a full-width selector.
- **Not inspected:** `guide-pdf-first.jpg` and `guide-pdf-last.jpg`. I can't certify the PDF visually.

This certification covers only the changed guide files and the shell's guide link.