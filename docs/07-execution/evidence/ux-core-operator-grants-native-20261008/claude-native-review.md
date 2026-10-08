# Official direct Claude Opus5.5 Medium

Read-only supplied source/images; session df1dfee6-d344-4464-9d39-30fb1488a841.

# R3 grants: native and visual checkpoint

I read only the five JPEGs listed at the end, with the Read tool. I made no edits, ran no shell commands and opened no other files.

## 1. Row form key fix

**Verdict: correct for the bug you found, but one case is untested.**

- **Why it works:** `key={grant.is_active ? 'update' : 'grant'}` makes React rebuild the row form whenever the operation changes. The checkbox defaults and the reason field are uncontrolled, and the capability fields are passed in as children. Rebuilding the form therefore drops the old checked boxes and reason, and the fresh defaults from the server are used.
- **What it keeps:** nothing is saved, the shared form, SQL and storage are untouched, and there is no new protocol.
- **Unknown results still keep the user's input:** after an unknown result nothing is revalidated, so the key doesn't change and the reason and choices stay. This matches what you observed in the browser.
- **Revoke then regrant:** the revoke form is removed when the grant becomes inactive and created fresh when it is active again, so it also starts clean.

**Untested case (must check before preserving):** a confirmed **update followed by another update** on the same row.
- The operation stays `update`, so the key doesn't change and the form is not rebuilt.
- The checkboxes will already match the new server state, because the receipt only accepts an exact match, so they are harmless.
- The old **reason text stays in the box**, and the panel may still be open. That makes it easy to submit the next change with the previous reason, which would put the wrong reason in the audit record.
- You tested grant→update and revoke→regrant, but not this.
- **If the reason is retained,** add the five capability flags to the key, for example `${op}:${flags}`. The flags only change after a confirmed change or a re-read, never after an unknown result. A real change always changes them, because "unchanged" is a no-op. So this still resets after a confirmed change and still keeps input after an unknown one.
- There is also a narrow overlap: a confirmed change with an unknown follow-up in the same mounted session. That belongs to the separate open gate for mounted uncertainty.

## 2. Scoped design verdict

**CHANGES REQUIRED.** The required change is narrow and was already present before this work.

**Must-fix: the page's cards have no side padding.**
- In `grants-before-390`, `grants-candidate-390` and `grants-candidate-1366`, the overview and list sections place their content right against the card's inline-start (right-hand) edge.
- Affected content: the eyebrow, h1, the "المشغّلون" heading, "إضافة مشغّل", "إعادة قراءة المنح" and the notice box, which spans the full card width.
- At 1366 the card's right edge is at about x=1050 and the h1 ends at about x=1048. At 390 the card edge and the heading are both at about x=345.
- The rows inside the list do have padding (the email sits about 22px inside the card).
- The public reference's cards have generous padding all round.
- This is a real hierarchy defect. It is not one of the accepted deviations (Cairo font, radius 8, control heights 40/44).
- I can't see the cause from images alone. It may be a page-level class overriding the shared `work-card` padding. The fix should restore the existing shared padding, not add new tokens.

**Title and notice spacing: not a legibility failure.**
- In both 390 images, the notice box's top border sits directly on the bottom of the h1 with no gap, and the same is true at 1366.
- No glyphs are clipped, and the h1 and the notice text are fully readable.
- It looks cramped only because of the missing card padding above. It is identical before and after this work, so no separate polish change is needed.

**Accepted from the images:**
- **New re-read control:** the "إعادة قراءة المنح" button and its hint render cleanly at 390 and 1366, and the clearer wording "وتُفقد أي إدخالات لم تُرسل" is visible.
- **Rows:** each row shows only the actions its state allows. The `disabled@` row (withdrawn and not recoverable) shows "الحساب غير جاهز لتسجيل الدخول" and "لا توجد مهام حاليًا" and offers no actions.
- **Context label:** the mobile topbar label now reads "المشغّلون", matching the active desktop sidebar item.
- **No other regression:** the candidate looks the same as before apart from the re-read block.
- **Regrant panel after reset:** the reason box is empty and the statutory checkbox is unchecked. The keyboard focus ring (blue, about 2px) is visible on "تأكيد إعادة المنح".

**Should-check:**
- **Focused confirm button:** in `grants-regrant-final-mobile`, the focused button shows a grey fill rather than the white outlined style used elsewhere. From one image I can't tell whether that is the shared focus style or something that looks disabled. Confirm against the pending/disabled state so the two can't be confused.
- **No visual primary in the open regrant task:** "إضافة مشغّل" is off-screen, and the confirm button is secondary-styled. This is existing page code, so I'm noting it, not blocking on it.
- **Dev overlay:** the Next.js dev "N" badge covers the "المزيد" tab in that image. The capture is from a dev server, not production-equivalent.

## 3. Limits of what I could see

- Only one of the five checkboxes is visible in the final regrant image. That "all five unchecked" relies on your DOM check, not on the image.
- The accessible-name change (4 summaries missing their visible label → 0) is not visible in images. It rests on your accessibility-tree inspection. There was no voice-control run.
- Not shown: the `aria-describedby` on the re-read hint and the primary/secondary split on the error page, both must-fixes from my last review.

## 4. Unresolved gates

- **Lint and TypeScript:** the post-change run must finish with exit code 0 before this is preserved. The earlier build was reused, with no second build.
- **Update→update reset:** the native check in section 1, plus the flag-key change if needed.
- **Card padding:** the must-fix above.
- **Shared-form recovery when the action throws:** still open.
- **Mounted state and account switching:** mounted uncertainty, losing authority and switching accounts are still open.
- **Historical intent recovery:** still open; there is no per-attempt receipt.
- **Not checked by me:** the 768 render, error/status screens, dark mode, brand themes, the pending state, real roles, Auth, provider and SQL, and N/C/P/I/B speed. Your evidence is from the controlled synthetic SDK only.
- **Full visual:** both verdicts remain **NOT VISUALLY VERIFIED** beyond the limited states I inspected.
- **Closure:** no R3, B1/B2 or journey closure; no PR, merge or deploy.

**Images read:**
1. `grants-before-390.jpg`
2. `grants-candidate-390.jpg`
3. `grants-candidate-1366.jpg`
4. `grants-regrant-final-mobile.jpg`
5. `onboarding-public-reference.jpg`
