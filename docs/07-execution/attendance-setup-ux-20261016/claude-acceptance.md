**ACCEPTED.** This covers batch 3a evidence closure only.

**Screenshots (390px mobile, build Sv7n9G5mVSi_R0yhoTgEu)**
- **`final-existing-mobile.png`:** None of the Arabic labels on the right are cut off. That includes "طريقة التسجيل والفرع", "طريقة تسجيل الحضور", "ابحث عن الفرع" and "فرع العمل". The notice about the existing source is fully readable. Its single primary button, "فتح إعداد الوسيلة", is fully visible and clear of the bottom navigation. Nothing overflows sideways.
- **`final-retention-mobile.png`:** The right-hand labels "اسم وسيلة تسجيل الحضور", "الموقع والخصوصية", "هل يلزم وجود الموظف قرب المقر؟", "مدة حفظ دليل الموقع" and "التشغيل وسبب القرار" are complete. Their help icons sit beside them. The help panel for the retention period is readable. The number field ("اكتب المدة المعتمدة") and the unit dropdown ("يوم") both fit across the width.
- The cut-off blocker is cleared in both states. This matches your metrics: innerWidth 390, scrollWidth 375, scrollX 0. I accept your explanation that this was a capture problem, not a product overflow.

**One-line change (`ChannelForms.tsx:23`)**
`hidden={ready&&!message}` plus `display:none` hides the message only when the form is ready and there is no message. The loading text before hydration still shows because `!ready` keeps it visible. Any error, uncertain, warning or success message is non-empty, so it still shows. The outcome element is still focused when a message appears (`status.current.focus` exists once in the file), so a screen reader still reaches the newly shown result. The change is safe. It does not affect permissions, validation or submit logic.

**Minor, non-blocking:** in the retention screenshot, the "وحدة المدة" label sits very close to the bottom edge of the help panel above it. Nothing is cut off; it's just tight spacing you may want to loosen later.

**Not verified:** I didn't check the live permission-revocation interface, and no such test was run. I did not re-check anything outside these two screenshots and that one line.