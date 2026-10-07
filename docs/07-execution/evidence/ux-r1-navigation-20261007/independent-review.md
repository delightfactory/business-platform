**PASS**

**Correctness:** The patch is correct.
- The `matchMedia('(max-width: 900px)')` query uses the same breakpoint as the CSS rule that hides the dialog, so they switch at the same width, including fractional widths.
- `dialog.close()` fires the native `close` event, so the existing `onClose` path does all the cleanup: it restores the body overflow it saved and sets `menuOpen` to false. There's no second cleanup path to keep in sync.
- The `.open` guard keeps the handler idempotent. The listener is added once and removed on unmount. `matchMedia` runs inside an effect, so the server render is unaffected.
- `useId` gives the same id on server and client, so there's no hydration mismatch. Pointing both launchers at one dialog with `aria-controls` is valid and makes the relationship clear to assistive tech.
- Focus: when the dialog closes, the browser tries to return focus to the launcher, which is hidden at desktop width, so focus probably ends up on the page body. That fits your "focus outside dialog" evidence and is acceptable for a resize edge case.

**Vision:** This removes a stuck hidden modal that needed a manual Escape, and it leaves routes, permissions, operations, Arabic/RTL and keyboard recovery unchanged. It adds no new navigation authority, so it fits Class C.

**Notes (not blockers):**
- `vercel.json` shows as modified in the working tree but isn't in this patch. Confirm it's out of scope before committing.
- This is evidence of the native dialog lifecycle only. Real provider, router and role UAT is still open, as you said.
