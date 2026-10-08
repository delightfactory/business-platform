# Official direct Opus5.5 Medium source review

Scope: supplied sources only, no image inspection or edits. Session 18f4e1ba-57d9-46d5-afdf-3b8ab31194fa.

I followed your no-tools instruction, so I wrote no plan file and did not call ExitPlanMode. This review covers only the 8 sources you supplied. I could not inspect `operator-access`, `invitation-feedback`, `operator-list-controls`, the actions, `InvitationForm` or `LimitFields`, and the findings below depend on them where noted.

## Verdict

**Source/journey: conditionally acceptable. One onboarding fix is recommended before acceptance, and two items depend on unseen sources.**

What holds up against your stated contracts:
- **Read guard (`operator-read.ts`):** accepts only the consumed fields. It checks list counts and uniqueness without inferring global totals, and it encodes the limit modes correctly (`limited` must be a positive integer, `unlimited` must be null, usage must be nonnegative). It does not check usage against the limit, which is correct because a lowered limit can sit below current usage.
- **Home page:**
  - Each optional capability check handles both returned errors and thrown rejections on its own, so one failure doesn't hide the other tasks.
  - The empty-state text is suppressed when some checks failed, so no fake "no tasks" message.
  - `updated-self`/`revoked-self` only show a neutral notice.
- **Lists (tenants/commercial/entitlements/invitations):** malformed data shows an error, never a fake empty list. The "nothing on this page" case is separated from "no matches".
- **Onboarding:**
  - An invalid key shows a status page with no form and no new key.
  - A read error or malformed result shows an alert and a reread link, with no form and no new key.
  - A null result keeps the same key, with wording scoped to the current account.
- **Invitations:**
  - An invalid id never triggers a read.
  - The selected invitation is identity-checked against the requested id.
  - Unknown lifecycle and delivery states are shown as unknown and get no actions.
  - Success is never inferred from the selected row.

## Critical / material findings

1. **Onboarding: the URL `state` contradicts a confirmed result.** `onboarding/page.tsx` shows `params.state` as `role="alert"` in every branch.
   - With `?key=K&state=failed` and a valid result, the page shows a confirmed success panel plus "لم يكتمل إعداد الشركة. لم يتم حفظ عملية جزئية".
   - That alert is a failure claim inferred from the URL, which conflicts with the stored result.
   - Suggested fix (one line, nothing new added): render the state message only in the form branch, i.e. only when `!resultUnavailable && !result`.

2. **Onboarding: possible conflict loop (depends on the action).** If `onboardTenantAction` redirects `conflict` while keeping `key=K`, the page shows the form again with the same K.
   - The message says "أعد تحميل الصفحة", but reloading keeps K, so the user cannot get out of the conflict.
   - Rekeying here would cut into the recovery work you've marked OPEN, so I am **not** proposing a page change. Check the action's redirect shape and treat this as part of the recovery gate.

3. **Invitations: URL states that claim success, styled as errors (depends on `invitation-feedback`).** In `stateMessage`, `created-sent`, `reissued-sent`, `revoked` and `already-accepted` state outcomes as fact. They render with `form-error`/`role="alert"`, but only when `invitationReviewMessage` returns nothing.
   - If `invitationReviewMessage` covers all of these, they are unreachable and harmless.
   - If it doesn't, they break "no success inferred from URL". Confirm which before accepting.

4. **TypeScript narrowing (confirm via your build).** `rows.filter(row => row.id !== selected.id)` uses the reassigned `let selected` inside a closure. This only type-checks on TS 5.4 or later, because older versions drop the narrowing inside the callback. Your grouped TypeScript build will settle it.

## Non-blocking (note only; no refactor)

- **Invalid invitation id:** the "إعادة قراءة الدعوة" link keeps the invalid `id`, so clicking it repeats the same notice. The clearer next action is a link with no `id`.
- **Unknown tenant lifecycle:** shown as "غير متاحة" on the tenants/commercial/entitlements lists. Invitations use "حالة غير معروفة"; using the same wording would match your "unknown states visible" rule.
- **Missing `<bdi>`:** entitlements wraps tenant names in `<bdi>`, but tenants, commercial and the onboarding result do not. This is a small RTL risk for mixed Latin/Arabic names.
- **Invitation pages and active status:** `invitations` and `invitations/new` check only the onboarding capability, not `current_platform_operator_status`. They are safe only if that capability RPC itself requires an active operator; confirm in SQL.
- **Unverified permission helper:** "no authority from truthiness" depends on `operatorPermission` returning true only for `data === true && !error`. That file wasn't supplied.

## Open gates (not closed by this review)

- **Runtime:** real Auth sessions, roles, SQL/RLS, provider/email delivery, hydration and native runtime are unverified. Your 67 checks use a controlled SDK.
- **Visual:** no images were supplied, so full visual review is **NOT VISUALLY VERIFIED** for both items. The new notices, the statutory section placed outside the grid, and the home page having no topbar/sign-out in its normal render all need visual sign-off.
- **Recovery (OPEN):** full recovery of the captured intent, actor and unknown mutation outcome is not done. This includes onboarding conflict/unknown handling and the fresh `requestKey` that `invitations/new` creates on every render after a failure with an unknown outcome.
- **Build:** the grouped lint and TypeScript build results are still pending (see finding 4).
