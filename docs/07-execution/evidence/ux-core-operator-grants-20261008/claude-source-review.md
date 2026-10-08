# Official direct Opus5.5 Medium source review

Read-only supplied sources/SQL, no images inspected. Session df1dfee6-d344-4464-9d39-30fb1488a841.

# R3 operator grants: source contract review

I did not use any tools, write a plan file or open other files, as you asked. This verdict covers only the supplied spec, the three source files and the quoted SQL.

## Verdict

**Source contract: conditionally conformant, with 2 must-fixes.** The list guard, error-first mutation handling, no-op shapes, receipt matching and receipt-gated self routing all match the quoted SQL. Two recovery and accessibility gaps remain. This is not R3 closure or acceptance. Full transport, mounted-state, real roles, Auth, provider, SQL and journey visual acceptance stay open, and both full-visual verdicts remain **NOT VISUALLY VERIFIED**.

## Confirmed correct against the SQL

- **List read** (`operatorGrantList`)
  - It requires a UUID `user_id`, a non-empty `email`, strict boolean `is_active`, `recoverable` and all five flags, and it rejects duplicate IDs.
  - It does not require `updated_at`.
  - Any malformed row returns `null`, which shows the "تعذر تحميل المنح" status. No row actions render from guessed state, and a bad list is never shown as empty.
- **Error priority:** `if (error) return mapError(...)` runs before any data is inspected.
- **Unknown errors:** transport errors and unrecognized messages map to `failed`, which says the outcome is unconfirmed. It does not claim nothing was saved.
- **Definite errors:** forbidden, target-unavailable, last-manager, reason, capability and invalid are all raised before any write, so the SQL rolls them back.
- **No-op handling** (`operatorGrantNoop`)
  - It requires only `user_id` (UUID) and `state`.
  - It accepts only the pairs the SQL can return: grant→already-active, update→not-active or unchanged, revoke→already-revoked. `unchanged` really can only come from update.
  - A mismatched pair, a missing ID or null data falls through to the receipt check and returns `failed`.
- **Receipt** (`operatorGrantReceipt`)
  - It checks the UUID, `state === action`, the email in lowercase, `is_active === (action !== 'revoke')`, and each of the five flags against the submitted values (all false for revoke).
  - This matches the SQL's success payload. The SQL also COALESCEs flags to false, which matches the form's `=== 'on'` booleans.
- **RPC arguments:** the 8 arguments are unchanged.
- **Pre-RPC failures:** `setup` and `unavailable` are returned before the RPC, so "before sending" in the copy is true.
- **No catching or replay:** there is no `try/catch` around `redirect`, and nothing replays automatically.
- **Self routing**
  - Self-revoke (local sign-out, then `/` if sign-out errors or `/auth/login?state=operator-revoked` if it succeeds) and self-downgrade both run only after the receipt is validated.
  - The "no remaining capabilities" branch of the downgrade is unreachable for `update`, because the SQL requires at least one capability. It is harmless and keeps the existing semantics.
- **Success state:** `?state=granted|updated|revoked` shows only the hedged text "الرابط وحده لا يؤكد حفظ تغيير", not the stronger "saved" copy.

## Must-fix (actual bugs or omissions)

**1. The recovery path tells the user to review current grants, but the page shows stale grants and has no way to re-read them.**
- When the action returns `failed`, a no-op (`not-active`, `already-active`, `already-revoked`, `unchanged`) or a definite error (`forbidden`, `last-manager`, `target-unavailable`), it does not revalidate. A returned server-action value does not refresh the RSC tree.
- So the list under the form is still the pre-attempt list. In exactly the cases where the server state differed from what the user saw (for example `not-active`, `already-active`, or `forbidden` after losing permission), the copy says "راجع المنح الحالية" but the screen shows old data. The only way to refresh is a browser reload.
- The success layout has no re-read control at all. Only `Status` has "إعادة قراءة الصفحة".
- **Fix:** add one secondary `Link` to `/operator/operators`, labelled "إعادة قراءة المنح", in the list header. It drops the query state and re-reads through the existing guarded path.
- Do not auto-`revalidatePath` on failure. The list is ordered by `is_active` and email, so a refresh can move or unmount the row's form and lose the retained safe values.
- This adds no new authority, storage or protocol.

**2. Accessible names do not contain the visible label (WCAG 2.5.3, label in name).**

| Visible label | Current `aria-label` |
|---|---|
| "سحب الصلاحية" | "سحب صلاحية {email}" |
| "تعديل المهام" | "تعديل مهام {email}" |
| "إعادة منح المهام" | "إعادة منح مهام {email}" |

- In each case the visible string does not appear inside the accessible name, so Arabic voice-control users cannot activate these buttons by saying what they see.
- **Fix:** use the visible label followed by the email, for example ``aria-label={`سحب الصلاحية: ${grant.email}`}``, or a visually hidden `<bdi>` suffix inside the summary.

## Unsupported claims (not shown to be bugs)

- **"Distinguish status/capability read failure from confirmed denial"** is only partly provable from what was supplied.
  - Errors are separated correctly.
  - But a malformed `status.data` value (null or an unexpected string) is shown as a *denial*, because of `status.data !== 'active'`.
  - Whether that can happen depends on `current_platform_operator_status` and `operatorPermission`, neither of which was supplied. This needs those sources before the claim is accepted.
- **A list RPC `42501`** (permission lost between the capability check and the list call) shows "تعذر تحميل المنح" rather than denial. That is conservative and honest, not a bug.
- **The verification group** lists tests, but no test source or results were supplied. Nothing in it can be treated as executed.

## Should-fix (hardening, not blocking)

- **Self-routing compares by email (`result.email` vs `user.email`).** The validated receipt has `user_id`, so `result.user_id === user.id` is the exact identity check. The SQL target lookup (`lower(email)=…` without STRICT) could in theory resolve to a different row than the actor.
- **The confirmed-denial `Status` offers only "إعادة قراءة الصفحة".** For a denial, the primary should be returning to `/operator`. Re-reading loops back to the same screen.
- **Lifecycle naming differs.** The list shows "إدارة حالة الشركات" but the checkbox says "تعليق الشركات واستعادتها وأرشفتها".
- **The revoke form posts two unused hidden `off` inputs.** They are harmless. Leave them, since the shared form must stay unchanged.
- **Spec typos:** "is20261002220504", "Base5349649…" and "original8RPC" are each missing a space.

## Explicitly still open (do not claim)

- Real SQL, roles, Auth and provider behaviour.
- Mounted uncertainty, authority loss and account switching.
- Historical intent recovery. There is no per-attempt receipt, so rereading alone cannot confirm an unknown change.
- Measured N/C/P/I/B.
- Full visual and runtime acceptance.
- B1/B2/R3/R0–R8 closure, PR, merge or deploy, and payroll A/B.
