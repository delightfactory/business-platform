# Batch 3A review: attendance source setup

**Verdict: accept once one small fix is made.** Everything else is acceptable as shipped. I only read files and looked at your three screenshots. I didn't run, build, test or edit anything.

## What I checked
- **Code read:** all ten in-scope files listed in your request, plus the existing `channel_mobile_site_idx` index and guide section 12.
- **Screenshots looked at:** the three rendered images from build YnOLB7LlnkBiv52XSdFVm. I checked the phone existing-source state, the phone dark policy form and the desktop light policy form.
- **Not run by me:** lint, build, the retention tests, pgTAP, the server harness and the live journeys. I'm relying on your report for those. Touch, screen reader, keyboard order, tablet layout and multiple clients at once are also not verified.

## Verdicts by area
- **Task (pass):** The actor, job, start, success and next step all match the contract. An existing branch source, active or stopped, now leads straight to its edit page. A new source goes to its detail page after it's created.
- **Capability (pass):** Nothing was removed. Name, type and branch can't change after saving. Policy and on/off status can still be edited. External sources and the older stop form still work, and the stop form keeps the exact seconds.
- **Simplicity (pass):** Searching no longer wipes the draft. Existing sources show up before the user fills the form, not only after the database rejects a save. No GPS or privacy value is filled in for the user. The duration amount and the on/off status start empty. The unit list starts at "days", but the amount must still be typed.
- **Recovery (pass, except the blocker):**
  - A newer search response replaces an older one.
  - A failed search keeps the last good results and lets the user retry.
  - A duplicate source caught by the database links to the existing source.
  - A save with an unknown outcome stays unknown and is never retried automatically.
  - Entered values are kept after every failure.
- **Phone and desktop layout (pass with one visual issue):** You report no sideways scrolling at 390 and 768. The screenshots match that. The visual issue is described under should-fix below.
- **Security, privacy and audit (pass):**
  - The new database function checks the same permission as the existing setup functions, and every join stays within the company.
  - Only signed-in users can call it. Anonymous and service roles can't.
  - It only reads data. Search text and result count are capped, and search characters like `%` and `_` are treated literally.
  - Duration is checked on the server.
  - The existing save function, its lock, the uniqueness rule, version history and recorded reasons are unchanged.

## Blocker: the form can stay locked with no explanation
After a session expiry or a permission error, the form stays disabled even when a later search succeeds.

- `SourceSetupFields.tsx:27` calls `onDenied()`. That sets `denied=true` in `ChannelForms.tsx:32`, and nothing ever sets it back.
- `actions.ts:13` marks an expired session as `denied:true`.
- Guide section 12 (`docs/user-guide/ar.md:318`) tells the user to log in again.
- If they log in in another tab and search again, the search works. But line 23 clears the error message, and the fields and the "create" button stay disabled (`ChannelForms.tsx:44,52`). The user sees a disabled action with no reason. That's a rejection condition in the contract. A reload would unlock it but lose the draft.

**Fix:**
1. Change the prop to `onAccess(denied:boolean)`.
2. In `SourceSetupFields.tsx:26`, when results come back, call `setResults(result.data);onAccess(false);`.
3. In the error branch, call `onAccess(true)` only when `result.denied` is set.
4. In `ChannelForms.tsx:48`, pass `onAccess={setDenied}`.

The real permission check at save time stays in place (`actions.ts:20-22` plus the database). So this fix doesn't weaken authorization.

## Should-fix (not blocking)
1. **The duration unit looks detached from its amount when the help text is open.** In both screenshots, the unit list ("يوم" / "ثانية") sits level with the label, while the amount box sits below the help text. On the phone, the help is also squeezed into the narrow column. Fix in `attendance-channels.module.css:25`: add `align-items:end` to `.sourceRetention`. Optionally, on phones (`max-width:480px`), stack the help text full-width under both fields.
2. **Two solid buttons when a source already exists.** Below the solid "فتح إعداد الوسيلة" button, the disabled solid "create" button still renders. It's explained by the message above it, but hiding it would leave one clear primary action. Option: give `MutationForm` a `hideSubmit` flag and set it when `existing` is true.

## Notes for the next batch
- For external sources, the branch field doesn't say whether it's optional.
- `new/page.tsx:7` assumes `q` is text. If the URL repeats `?q=`, the user gets the "unavailable" page. Normalising with `typeof q==='string'?q:''` would avoid that.
- There's no rendered or keyboard evidence yet for the search-failure message or the "first 20 results" message.