**Verdict: not accepted yet. The code changes are accepted, but one rendered-evidence blocker remains.**

**Code changes: all accepted.** I only read the files you listed.
- **Denied-access handling (`SourceSetupFields.tsx:20-30`):** a successful search result calls `onAccess(false)`, which clears an old denied state. `onAccess(true)` runs only when the server says access was denied. Errors and thrown exceptions show a message and leave the results, chosen branch and draft as they were. Out-of-date responses are ignored, and the busy state is cleared correctly.
- **`SourceForm` (`ChannelForms.tsx:32,44,48,52`):** the denied state blocks both the submit button and the details fieldset. The branch picker stays usable, so the user can retry the search and recover. The save path still goes through `mutateChannel`, and the client-side block is not the only check.
- **Existing source:** `hideSubmit={Boolean(existing)}` removes the create button. The only primary action left is "فتح إعداد الوسيلة", which links to the existing source. `blocked` also stays true there, so the form can't be submitted another way.
- **External sources:** the branch field is labelled optional and is not required.
- **Repeated `q` in `new/page.tsx:7`:** an array becomes `''`, and the search text is capped at 100 characters before the lookup.
- **Retention:** `displayRetention(undefined)` returns an empty amount with the unit set to days, so a new source has no pre-filled value. `.sourceRetention` uses `align-items:end`. The duplicate `align-items:end` in the 480px media query is redundant but harmless.

**Screenshots:**
- In `delta-retention-mobile.png` the amount field is empty with its placeholder showing, and the amount and unit controls line up on the same baseline. That claim is confirmed.
- In `delta-existing-mobile.png` the notice about the existing source appears, and there is no create button in the visible area. However, the image stops partway through the notice, so the "فتح إعداد الوسيلة" button is not visible. "Exactly one primary action" therefore rests on your 390px run and the source code, not on this image.

**Remaining blocker: the right edge of the page content is cut off in both screenshots.** The top bar renders fully. Everything below it loses about 20–30px on the right:
- the page title "…ضافة وسيلة تسجيل حضور"
- the field labels "…ريقة تسجيل الحضور", "…حث عن الفرع", "…ع العمل", "…سيلة تسجيل الحضور" and "…دة حفظ دليل الموقع"
- the start of the existing-source notice text
- the start of the retention help popover lines

In right-to-left Arabic the start of each line is on the right, so this hits the beginning of every label and message. Because the top bar is unaffected, the cause is either:
- (a) real horizontal overflow in the page frame, form panel or fieldsets at 390px, or
- (b) a capture artifact, such as the page being scrolled sideways when the screenshot was taken.

The images alone can't tell these apart. It counts as a blocker because cut-off Arabic labels at 390px fail the readable Arabic/mobile requirement.

To clear it, either:
- show at the same build that `document.documentElement.scrollWidth <= 390` and `scrollX === 0` on `/attendance/sources/new` in both states, then recapture both images from horizontal scroll 0; or
- fix whatever element is overflowing.

If the recaptured images render cleanly and show the existing-source button, I would accept without needing further code review.

**Limits, as you asked:** I did not see a live revoke-and-restore of permissions in the UI. The recovery after a denied response is checked from source only, and the permission boundaries are covered only by your database tests. No visual check covered a denied state.