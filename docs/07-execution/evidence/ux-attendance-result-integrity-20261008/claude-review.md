# Verdict: Conditional PASS, with 4 required corrections

I reviewed only the diff and your stated facts, with no tools. Each correction below depends on a fact I couldn't see. If the check confirms the candidate, the item closes with no code change.

## Required corrections

1. **TS narrowing in `readPunchResult`.** `states.includes(result.state)` doesn't narrow `result.state` past `string`. So `state: result.state` will likely fail `tsc` against the `PunchResult['state']` union. Use a typed `as const` array with a type guard, or an explicit cast after validation. The same applies to `reason as string | null` if `PunchResult.reason` is a union of reason codes rather than `string`.

2. **`unconfirmed`/`invalid_input` must already be in `PunchResult` at ac64adc.** Check the type in `@/lib/attendance-channel`. If either value is missing, the candidate needs a change to a global helper, which this scope forbids. In that case, keep the marker local to the action (for example, a discriminated local return type).

3. **Null tolerance could turn real outcomes into "unconfirmed".** `review` and `next_direction` are rejected when they are `null`, but `reason` accepts `null`. If any SQL branch builds its result with `jsonb_build_object(... 'review', NULL ...)`, the parser throws. Rejected/blocked/received outcomes from the server would then show as connection uncertainty. Either show source-matched SQL proving these keys are omitted or boolean in every branch, or accept `null` for non-accepted states.

4. **Field stripping.** The rebuilt object keeps only `state`, `reason`, `review` and `next_direction`. Confirm that `MobilePunch` and `refreshSnapshot` don't read any other `PunchResult` field (for example an id or timestamp). If they do, it's a silent regression.

## Confirmed safe, if your stated facts hold

- **Invalid input:** both actions return before any SDK, auth or RPC call. `finish` returns before `release()`, so the receipt is kept. The old false authoritative `rejected/time` and `blocked/scope_changed` results are gone.
- **Malformed responses:** a bad server response throws after `revalidatePath`. The existing catch blocks keep the receipt, and resend uses the exact payload.
- **Accepted/duplicate:** requiring a boolean `review` matches the SQL behaviour you described, as long as that evidence is source-matched to ac64adc.
- **Unresolved states:** `received`, `unmapped`, `retry_failed` and `retrying` still go to the non-releasing `else` branch and are never claimed as success.
- **Heading:** this fixes the contradictory "ready" heading. Ordering busy before pending is correct.
- **Page:** the missing-client return link and dropping the forbidden-state reload are correct. The footer return link is still there.
- **Unchanged:** GPS policy, flight locks, the separation between terminal prepare and capture, and review not counting as approval.

## Minor (doesn't block)

- "لم نرسل طلبًا إلى الخادم" ("we didn't send a request to the server") isn't literally true, because a server action did run. "لم نرسل المحاولة إلى خدمة الحضور" ("we didn't send the attempt to the attendance service") is more accurate.
- The heading for a pending attempt with no id ("تعذر قراءة المحاولة السابقة", "couldn't read the previous attempt") is only correct if a pending record without an id is always corrupt. Confirm that ids are generated on the client before persisting.
- If reconcile hits `invalid_input`, the only primary action loops back to the same message. That is the open A1/A2 corrupt-record recovery. Record it as open, not closed.

## Still open (not closed by this candidate)

- A1/A2 recovery for corrupt records, sessions and privacy.
- Malformed snapshot handling: `data as MobileSnapshot` in `page.tsx` is still unvalidated.
- SDK/RPC errors and session expiry.

## Tests for the grouped batch

- **Action tests:** invalid tenant, id or scope in both actions returns `unconfirmed/invalid_input` with zero SDK calls. Each of the 8 states parses. Malformed responses throw: non-object, array, unknown state, accepted without `review`, rejected without `reason`, and `null` `review` (whichever behaviour item 3 settles on).
- **Handler tests:** `invalid_input` keeps sessionStorage. A malformed reconcile response keeps the receipt and shows the uncertainty copy. Rejected `scope_changed` releases the receipt and shows the new copy. Blocked `scope_changed` copy is unchanged.
- **Build:** one lint/build plus `tsc` run, which also confirms item 1.

No N/C/P/I/B gains are claimed, because none were measured.