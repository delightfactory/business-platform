# Official direct Claude Opus5.5 Medium

Session c6ecb1ac-387e-4e75-8724-6dca3a94dd82. Read-only, supplied source/render scope only.

# Onboarding candidate review: source/journey verdict and separate visual verdict

**Source/journey: not accepted yet. One fix blocks acceptance and one small fix is needed.** The safety design is correct: SQL is the only authority, an attempt is never rekeyed, and replays are always identical. The blocking problem is the "set up another company" journey, which most likely dead-ends.

**Visual: NOT VISUALLY VERIFIED** for both Codex and Opus.

**What I inspected:** only the 5 source files you supplied and the 3 JPGs. I used no other tools or files and didn't run anything. Nothing here is runtime acceptance.

## Source/journey findings

### B1 (blocks acceptance): "إعداد شركة أخرى" probably can't start a new company
1. After a save, the URL stays `/operator/onboarding`, because the redirect was removed.
2. `OnboardingResult` links to that same `/operator/onboarding` URL.
3. In the Next App Router, a soft navigation to an identical URL keeps the same page segment. React then keeps the mounted `OnboardingForm` state, so `phase` stays `'saved'` and the receipt stays on screen.
4. The new `requestKey` prop from the server's `crypto.randomUUID()` is ignored, because `scope` is frozen in `useState`. That freeze is correct for recovery.

The old flow worked because the redirect added `?key=`. Leaving that query string changed the page segment, so the form mounted fresh. Even if the phase were reset somehow, the form would reuse the committed key, and a new payload would hit `onboarding_idempotency_conflict`.

**Minimal fix:** render the in-form saved receipt's "another company" link as a plain `<a href="/operator/onboarding">`. That forces a full page load and a fresh server-generated key.
- This adds no new key logic, storage or URL protocol.
- The saved state has nothing left to protect, so reloading is safe.
- Don't remount the form on `key={requestKey}`. That would wipe the captured intent on every server-action cookie refresh.

**Must be verified by actually clicking it** after a save. Your evidence doesn't cover this click.

### M1 (small fix): a malformed read result is labelled as a conflict
In `readOnboardingAttemptAction`, any result that fails `matchingOnboardingSnapshot` returns `'conflict'`, and that includes a malformed snapshot. The spec says a malformed result means "unknown/frozen, explicit read retry". The UI behaves the same either way (frozen, read button stays the primary action), but the message tells the operator the reference is "linked to different data", which isn't proven. Fix: return `'unavailable'` when `!onboardingSnapshot(result.data)`, and `'conflict'` only when the snapshot is valid but doesn't match.

### Boundary to state, not fix: the server page can unmount the frozen form
Two things can make the page re-render while an attempt is frozen: Supabase setting cookies inside the action, or a manual refresh. If the current account has then lost operator status or the onboarding capability, `page.tsx` renders `<Status>` instead of the form. The form unmounts and the captured intent is gone.

So the spec's promise that the form "remains frozen" for forbidden or actor-changed states only holds while the page still renders the form. This is a likely explanation for your inconclusive cross-account harness, where the old state vanished after fresh GETs, but that's unproven.

Rendering the form for an account that has lost the grant would be new authority, so don't change the code. Record it in the spec as a limit of the current-window boundary and keep "original actor restoration" OPEN.

### Checked and correct
- **Error mapping:** exact `code`+`message` pairs; everything unmapped is `unknown`.
- **Validation before the RPC:** UUID key, int4 cap, code-point lengths, strict modes, and the legal-name fallback after trimming.
- **Dispatch tracking:** `mutationDispatched` is set only after `getUser` matches the captured actor, and a throw after dispatch is `unknown`.
- **Edits after replay (C6):** editing is unlocked again only for `invalid`/`admin` with the same key.
- **Null read result:** it only enables an identical replay. `scope.actorId` is a guard only.
- **Retry payload:** retry copies the captured FormData and never rebuilds it from the DOM or props.
- **Locking:** the ref lock is set synchronously, which covers double clicks.
- **One primary action per state:** submit, read, retry+read, or admin login+another company.

**Optional, not blocking:** a pre-dispatch `actor-changed` while editing freezes the form, even though nothing was sent. It's safe but adds a step.

## Visual findings

| Image | What it shows | Limit |
|---|---|---|
| Public reference (mobile) | The light card direction, the green primary, Cairo, rounded cards | It's a tenant "today" screen; there's no onboarding screen to compare against |
| Null state, mobile, scaled to 375 | The tinted status box (not error red), retry as the only primary with read as secondary, the retention hint, RTL fields, no clipped text | The Next dev indicator covers a bottom-nav item; scrolled view only |
| Saved state, desktop 1366 | The receipt card, a full-width primary for the admin login, a secondary for another company, LTR names isolated correctly | Doesn't show the admin email (see below) |

**Non-blocking suggestion:** the saved receipt says "send the link to the assigned account" but never shows which email that is. Showing the validated `admin_email` (with `<bdi dir="ltr">`) would make that step simpler.

**Still open:**
- tablet/768 (that measurement wasn't valid)
- the editing, unknown, read-error, conflict, forbidden and actor-changed states
- a matched same-screen comparison against the reference
- real Auth, roles, SQL and provider; no-JS and native runtime; accessibility

## Bottom line
Fix B1 and M1, verify B1 with a real click, and record the unmount boundary in the spec. After that, the source/journey can be accepted as a bounded current-window candidate. This doesn't close R3 or R0–R8, and it doesn't cover D16, payroll A/B, a PR, a merge or deployment.
