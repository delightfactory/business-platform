**M1 verdict: ACCEPTED**

The RTL arrow defect is closed. Arrows now keep their physical direction, and in every M1 view I checked, left means forward or swipe and right means back.

**Source: `src/components/ui/icon.tsx:9-12`**
- Only `chevronLeft` and `chevronRight` get the `ui-icon-directional` class now. `arrowLeft` and `arrowRight` render as drawn. The flip rule is still `.ui-icon-directional:dir(rtl){transform:scaleX(-1)}` in `src/components/ui/ui.css:1`, so chevron behaviour is unchanged in source.
- I grepped every `arrowLeft`/`arrowRight` call site under `src`, and their meaning is consistent:
  - **`arrowLeft` (forward):** the entry CTA, the task-card action, today shortcuts, tenant select, leave "التفاصيل", the guide link, and the swipe hint.
  - **`arrowRight` (back):** the "إجازاتي" back links on the new-leave and leave-detail pages.
- The swipe arrow matches the gesture. `SlideToConfirm.tsx:26` measures travel as `origin.current - event.clientX`, so the drag goes right to left. That matches the left-pointing arrow, the thumb sitting on the right, and the hint "اسحب المقبض من اليمين". Keyboard confirm (Enter/Space) and the alternative confirm button are unchanged.

**Rendered evidence (the 4 images at 390 px, plus `rtl-delta.json`)**
- **`entry-rtl-fixed-390.png`:** the "افتح مساحة العمل" button arrow points left (forward). The page renders cleanly with no tiling.
- **`employee-home-rtl-fixed-390.png`:** the swipe track has the thumb on the right and the "اسحب لتأكيد الحضور" arrow pointing left. It shows the ready state only, with no submission.
- **`employee-request-rtl-fixed-390.png`:** the "إجازاتي" back button arrow points right (back).
- **`employee-work-unavailable-rtl-fixed-390.png`:** the "العودة إلى يومي" arrow points right (back). The "unavailable" state has an explanation and a "سجلي" exit, so it isn't a dead end.
- **`rtl-delta.json`:** all four entries are tagged build `gCUZl_HX4-Mpre7RH2uba`, and every arrow there shows `transform: none` with no `ui-icon-directional` class.

**Limits**
- I ran no tests, builds, lint or browser sessions. The lint and build PASS results, the QA61193 build and the capture process are your claims, and I didn't reproduce them.
- I can't independently confirm that the PNGs came from that build beyond the labels in `rtl-delta.json`.
- I only checked RTL at 390 px. I didn't check LTR, desktop, other themes, or chevron rendering in any image.
- I didn't inspect the DB boundary evidence (`calendar-boundary.sql`/`.log`) beyond seeing the files exist, so the foreign-tenant `42501` rejection result is outside this verdict.

**Optional notes (not required to close M1)**
- `rtl-delta.json` lists `entry` twice. That looks like the rejected first capture plus the retake; if so, labelling or removing the first one would make the evidence clearer.