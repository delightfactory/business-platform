**Verdict: PASS with conditions.** As you asked, I used no tools, so I haven't checked any of this against the repo. The conditions below are what I couldn't confirm from the patch alone.

**Spec adequacy:** The spec meets the contract. It removes the false-success path (URL state → "sent/reissued/revoked" toast) and leaves actions, RPCs, permissions, queries, pagination and selected context alone. It doesn't claim a speed gain, and it doesn't add a new trust mechanism. The fallback branches keep the same logic: `!reviewMessage` replaces `!success` for the operator error branch, and the member branch adds the guard. The member page still shows its membership/role toast for the remaining states.

**Conditions:**
1. **Member anchor:** `#pending-title` must be on the page the redirect lands on for all three states. If it only appears under a non-default tab, the link goes nowhere. Test this.
2. **Member revoked copy:** If the member list only shows pending invitations, a revoked one simply disappears. "راجع الحالة الحالية للدعوة أدناه للتأكد من الإلغاء" then points to a row that doesn't exist, and a real revoke looks the same as a forged URL. Either confirm the page shows revoked/history rows, or reword it, e.g. "إن لم تظهر الدعوة ضمن المعلّقة فهي غير قابلة للاستخدام حاليًا؛ تحقّق من السجل."
3. **Operator:** After removing the `FeedbackToast` import, check nothing else in that file uses it (lint/TS will catch this).
4. **`Object.hasOwn`:** Needs the ES2022 lib in tsconfig. The combined TS/build run should confirm it.
5. **Accessibility:** Screen readers may not announce a `role=status` that is already on the page when it first renders. Only claim "announced" if a soft-navigation test shows it. Otherwise, say it's persistent visible text only.
6. **Test coverage:** Tests must include an unknown state and a prototype key (`state=constructor`) falling through to the existing error branch, plus the existing failure/unknown keys staying unchanged.

**Still open:** real provider/mail delivery, an applied database, real roles, hydration, and full-phase acceptance are all outside this review. I'm reviewing this patch only, not accepting the whole phase.