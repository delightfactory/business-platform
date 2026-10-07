# R5a draft review: blockers, corrections and proposed batch sequence

I reviewed this from the draft and source you pasted, and opened no files. Nothing was edited, run or certified. Plan mode wanted a plan file and an approval step, but those tools aren't available to me here and you said no tools, so the plan is in this reply.

## Verdict on direction

The direction is sound: it is conservative, keeps server authority, admits verification can write data, and keeps unproven claims out. Coverage, recovery and privacy are each still missing at least one case. The blockers below must be settled before the presentation batch, and the draft must stay **Proposed**.

## Blockers (owner decision or contract amendment needed)

1. **Unreadable storage is a dead end.** `setPending({id:'',scope:''})` disables "Verify", hides "Resend" and blocks capture. The message tells the employee to wait for an administrator, but no administrator tool can clear tab `sessionStorage`. A new tab gets past it anyway, so the block is not real protection either. The spec must define a real way out. Recommendation: show server history as the source of truth, plus an explicit "discard local record" action with a warning. Discarding sends nothing.
2. **An expired session mid-action has no way back.** Both actions return `blocked/permission` when `getUser()` is null. The pending attempt is kept, the label says "sign in with the authorized account", but no link is offered. Verifying again just returns the same permission result, so it loops. Recommendation: offer a login link with `next=` set to the current route. `sessionStorage` survives same-tab navigation, so the attempt can still be verified after login. Payload resend is correctly lost.
3. **A local validation failure is shown as a server fact.**
   - `reconcileMobilePunch` returns `blocked/scope_changed` when it rejects the input itself (for example, scope over 300 characters). The client then releases the receipt and says the attempt belongs to another employee link. That is a false authoritative claim and loses safe context.
   - `submitMobilePunch` returns `rejected/time` for any local `validAttempt` failure. This is safe because nothing was sent, but the label is wrong: a non-integer `policy_version` gets reported as a clock problem.
   - Fix: a reviewed amendment adds a distinct non-authoritative result. Until then, the copy must not claim server facts.
4. **Reason text contradicts the state.** When `rejected/scope_changed` comes back from the same-link context-change branch, the label says "verify the previous attempt first". The pending attempt has already been released, so there is nothing to verify. `rate` has the same problem if it ever arrives as `rejected`. Reason copy must depend on the state (rejected vs blocked). Make that change in the component, not in the shared `channelReasonLabel`, which is R5b territory.
5. **A blocked result can loop forever.** "Other blocked keeps the pending attempt" is accurate to the source. The spec must still map each blocked reason (`permission`, `conflict`, `rate`, `policy_changed`, `direction`) to a recovery that can actually end. Verification that can never resolve is a dead end.

## Corrections to the draft

- **Hydration copy.** "جارٍ التحقق من المحاولة السابقة…" is shown to every user, even with no pending attempt, and no server check is happening at that point. Use neutral preparation copy instead.
- **Missing state row.** The table needs a row for normal accepted/duplicate results. After success, `refreshSnapshot` immediately turns the next movement into the enabled primary button, which invites an accidental second punch. Decide whether the result or the next movement is dominant right after success.
- **Busy label.** "جارٍ الإرسال…" is shown while the location is still being obtained. Name the actual operation: locating, sending, verifying or refreshing.
- **Permission-denied page.** The 42501 branch offers "Reload page" as its action, but reloading cannot fix a permission problem. Its main action should be returning to the workspace. Keep reload only for the RPC-error/null branch.
- **Flowchart.**
  - Blocked `scope_changed` goes to T, not V.
  - Add a path from S back to H for the next movement.
  - The F node's "supported retry" doesn't fit the permission case.
- **Malformed snapshot.** A null `next_direction` currently shows as departure, a false action label, and a missing `history` crashes the page. List both as concrete fail-closed cases in the amendment.
- **"Last 20 attempts".** This claim comes from SQL, not from the snapshot fields. Cite the SQL or drop it.
- **Unused retention.** `retention_seconds` is never used, and a pending receipt has no expiry.
- **Unexpected location error.** Location code `location_unknown` also rethrows and sends nothing. Name it alongside serialization failure.
- **Stale HR view after verification.** Verification revalidates only `/me/attendance`. If its inserted cancellation appears in HR channel views, those views will be stale. Record this as an R5b impact note, not an R5a change.
- **Unavailable state with nothing pending.** The source has no "responsible contact" feature. Define this state as: mapped cause, plus history, plus workspace return. Add a refresh action only for reasons that are actually temporary. Do not invent a contact channel.

## Coverage gaps (add as draft, not-run partitions)

| Area | Missing case |
|---|---|
| Concurrency | Two tabs: storage is per tab, so "no duplication" relies on server direction/idempotency checks. Also a late response arriving after the 20s timeout, and resending while the first request is still in flight. |
| Retention | Verifying a receipt older than the retention period. |
| Local validation | Both local-validation outcomes from blocker 3. |
| Session | Session expiry during submit and during verify. |
| Shared device | Logout then a different user's login in the same tab. The key is `attendance-pending:${tenantId}` with no user in it. |
| After success | The state immediately after success (the accidental-second-punch risk). |

## Privacy

- **Location is handled well.** It is held only in memory, never in storage, and is fetched only when the employee acts.
- **Open: the receipt is not tied to a user.** Logout should clear it, or the key should be bound to the user. The `scope` string must be confirmed as opaque.
- **Open: wording leaks an attempt's existence.** "This attempt doesn't belong to the current link" tells the second user that someone else's attempt exists.
- **Owner confirmation needed: reviewer identity.** History shows the reviewer's name (`actor_label`) and reason to the employee. Confirm this is allowed; don't change it silently.

## Economical testing

The plan is sound, with these additions:
- **Measure the baseline first.** Capture N/C/P/I/B on commit `233a616` before changing anything, using the same states and harness. Otherwise there is nothing measured to compare against.
- **Make state derivation a pure function.** Drive the view from one function of `(ready, pending, terminal, operation, available, next)`. A single table test then proves exactly one primary action per state cheaply.
- **Component harness needs fakes** for timers, animation frames, storage, geolocation and `crypto`.
- **Focus on the live region.** The status element is both `role=status` and focused, which may announce twice. Check this in a real browser.
- **Real-browser evidence** at 390/768/1366 needs an authorized synthetic account. If none exists under "no new access", that evidence stays open and is not replaced by stubs.
- **No new SQL runs** unless the blocker-3 amendment changes the action contract.

## Proposed sequence for one coherent presentation batch

1. **Owner decisions:** blockers 1, 2 and 5, which comes first after success (correction 2), and confirming reviewer identity in history. Blocker 3 goes to amendment review and stays deferred. Until then, only its copy changes.
2. **Baseline:** record the N/C/P/I/B metrics and scenario labels on `233a616`.
3. **`MobilePunch` (presentation only):**
   - Pure state derivation driving heading, one primary action and an optional secondary.
   - Neutral hydration copy and an operation-specific busy label.
   - State-aware reason copy kept local to the component.
   - Order: site, cause, status, action.
   - Login-with-return link for the permission-blocked result.
   - The way out of unreadable storage the owner chooses in step 1.
   - Unchanged: in-flight and disabled logic, storage write order, exact resend payload, GPS policy.
4. **`page.tsx`:** add workspace return to the missing-client branch. Make the permission branch lead with workspace return. Keep reload only for real load failures. No shape guards until the amendment is reviewed.
5. **Evidence:**
   - State table test, component harness and page fixtures.
   - One lint/type/build pass.
   - Real-browser keyboard/focus/RTL checks at three widths, if authorized.
   - Measured after-metrics against the baseline.
6. **Independent review:** a package covering task completion, coverage, simplicity metrics, recovery, responsive/accessibility and preserved behaviour. Freeze stays with the owner. The shared helper, `/me` integration, slider and hooks stay deferred, and R5b/R6a/R0–R8 stay open.