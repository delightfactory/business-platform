# Official direct Opus5.5 Medium source review

Scope: supplied sources only, no image inspection or edits. Session 18f4e1ba-57d9-46d5-afdf-3b8ab31194fa.

## Delta verdict

**Both fixes are accepted at source level, with no critical findings.** This covers only the two final pages you supplied; it does not close B1, B2, R3 or R0–R8.

**Fix 1 (`onboarding/page.tsx`)**
- The URL alert now renders only when `params.state && !resultUnavailable && !result`. A confirmed result, or an unavailable/malformed one, therefore suppresses it.
- `stateMessage()` ignores the value of `state`, so unknown or made-up values get the same neutral text. Nothing is inferred from the URL.
- These paths are unchanged: success heading only from a validated snapshot; invalid key, read error or malformed data gives no form and no rekey; a null result keeps the key with current-account wording.

**Fix 3 (`invitations/page.tsx`)**
- URL states not covered by `invitationReviewMessage` now share one neutral message, so no stored outcome is asserted from the URL.
- The selected-row identity check is unchanged. Row actions are unchanged: only a known `pending` lifecycle gets actions, unknown delivery under `pending` keeps reissue/revoke, and unknown lifecycle gets none. This matches your corrected statement.
- The `selected` narrowing code is unchanged since the passing grouped TypeScript build.

**`operatorPermission`:** `error === null && data === true` meets "no authority from truthiness". The capability SQL you described covers the active-status concern I raised for the invitation pages.

## Non-blocking (wording/semantics only; no change required for this delta)

- **Neutral notices carry error semantics.** The neutral text renders with `role="alert"` on onboarding, and with `form-error` plus `role="alert"` on invitations. A screen reader announces it as urgent and the styling reads as an error. Switching to `form-message` with `role="status"` (as `reviewMessage` already uses) would fix this with no new CSS; it's a two-attribute change if you want it.
- **Onboarding notice asks for something the page can't show.** The neutral text says "راجع بيانات المحاولة", but the page has no captured attempt data to review. This belongs to the recovery gate; I'm not asking for a wording change now.
- **Invalid invitation id link still repeats the notice.** The "إعادة قراءة الدعوة" link keeps the invalid `id`, so clicking it shows the same notice again. This carries over from the prior review.

## Remaining gates (explicit, open)

1. **Captured-intent recovery (OPEN).** These action-returned messages still need resolving:
   - `onboardingErrors.conflict` says "أعد تحميل الصفحة". If the URL has no `?key`, reloading creates a new `randomUUID`, which is a rekey path after an ambiguous earlier submit. If the URL has `?key=K`, reloading reuses the conflicting K.
   - `failed` asserts "لم يتم حفظ عملية جزئية".
   - Thrown transport ambiguity is unhandled.
   - On invitations, the unknown-delivery "يمكنك إعادة الإرسال" advice is still shown.
   - All of this stays with the existing action and shared form; nothing changed here.
2. **Lint and TypeScript.** The affected lint/TypeScript run is still in progress, and there was no second full build after the two-page copy change. Neither delta is confirmed until that finishes.
3. **Runtime (unverified).** Real Auth, roles, SQL/RLS, provider/email delivery, hydration and native runtime are unverified. The 76 checks use a controlled SDK and pure parsers.
4. **Visual: NOT VISUALLY VERIFIED** for both Codex and Claude. The browser refused `file://` access and the operation stopped without a workaround. No visual metrics are claimed, and the new notices are not visually accepted.
5. **Program closure.** This delta does not close B1, B2, R3 or R0–R8. D16 extras remain deferred.
