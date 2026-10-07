# R2 Recipient-Action Specification: nine public server actions

**Status:** Proposed. This spec is not frozen and has not been run or accepted. It is meant for your independent source review.
**Source:** snapshot `3934521f…` — only the five files you pasted. I used no tools, read nothing else, wrote no plan file and changed nothing.
**Out of scope and still open:** issuing, resending, sending and delivering invitations, and the wider R2 work.
**Note:** RPC return values, error strings, idempotency and provider behaviour are not in these files, so nothing below is guaranteed. Concept C affects visuals only.

## 1. Actions and source sequence

### Admin (`/auth/invitations/*`)
1. **`verifyInvitationLinkAction`**
   - Checks the form: `tokenHash`, `type` (`invite` or `email`), a UUID `invitationId`, and `issuance` matching `[1-9]\d{0,8}`. A bad form goes to `callback?state=invalid`.
   - No client goes to `setup`. If `verifyOtp` fails, it goes to `link-expired`. Success goes to `accept?id&issuance`.
2. **`setInvitationPasswordAction`**
   - Checks the form: a UUID id, `issuance` matching `\d+`, and a password of at least 8 characters. Failure goes to `state=password`.
   - Then: `setup`, then `getUser` (none → `no-session`), then the validate RPC. If the RPC errors or doesn't return `password_required`, it goes to `unavailable`.
   - Then `updateUser`. An error goes to `password`.
   - Then the admin client and marker RPC. If either fails, it goes to `password-marker-failed`. Success goes to `password-set`.
3. **`acceptInvitationAction`**
   - Checks the form. A bad form goes to `invalid`. Then `setup`, then `no-session`.
   - Then the accept RPC. Errors are matched by substring, in this order: `issuer-lost`, `identity`, `expired`, `superseded`, `password`, `unverified`, then `accept-failed` for anything else.
   - A malformed result or a non-UUID tenant goes to `accept-failed`. Success goes to `/tenant/{id}`.

### Member (`/auth/membership-invitations/*`)
4. **`verifyMemberInvitationAction`** works like action 1. On expiry it keeps `invitation_id` and `issuance` in the URL.
5. **`setMemberInvitationPasswordAction`** works like action 2, with these differences:
   - It sends every outcome through `go()`, which goes to `/auth/login?state=invalid` when the id isn't a UUID.
   - It ignores the validate RPC's `error`.
   - The marker failure state is called `marker-failed`.
6. **`acceptMemberInvitationAction`**
   - It treats an RPC error and a bad result the same way.
   - Substring order: `limit-full`, `issuer-lost`, `identity`, `unverified`, `target-unavailable`, `password`, `superseded`, `tenant-unavailable`, then `unavailable` for anything else.
   - Success goes to `/tenant/{id}`.

### Employee (`/auth/employee-account-activation*`)
7. **`verifyEmployeeAccountActivationAction`**
   - Checks the form; failure goes to `invalid`. It also accepts the `magiclink` type.
   - Then `setup`. If `verifyOtp` fails, it goes to `expired`.
   - Then the snapshot RPC. An error goes to `identity`, but the user is now signed in. Success goes to the activation page.
8. **`setEmployeeAccountPasswordAction`**
   - A non-UUID intent goes to `?state=invalid` with no intent. A short password or a mismatched confirmation goes to `password`.
   - Then `setup`. No user goes to `identity`.
   - Then the snapshot. It must belong to this intent and have state `user_created` or `activated`; otherwise it goes to `identity`.
   - If the state is `activated` and the password is already ready, it goes to `activated` with no change made.
   - Then `updateUser`, which goes to `password` on error. It reads the user again; a different id goes to `identity`.
   - Then the admin client and readiness RPC, which go to `readiness` on failure.
   - If the intent was already activated, it goes to `password-ready`. Otherwise it calls `activateRecipientAccount`.
9. **`retryEmployeeAccountActivationAction`**
   - Checks the UUID, then `setup`, then calls `activateRecipientAccount`.
   - It does **not** check for a session, a snapshot, or password readiness first.

### Shared helper: `activateRecipientAccount`
- On an RPC error or bad result, it maps the error to a code and calls the defer RPC. **The defer RPC's error is ignored.**
- It then goes to `limit-full`, `employee-unavailable`, or `retry` for everything else.
- On success it calls `removeProvisioningMarker`, which **fails silently on every path**, and then always goes to `activated`.

## 2. Outcome groups and the next safe user action

"Context" means the invitation or intent id and issuance in the URL. "Lost" means it is dropped.

| Outcome | Admin | Member | Employee | Next safe user action |
|---|---|---|---|---|
| **invalid** | 1: `invalid` (context lost). 2: `password` (bad id is reported as a password problem). 3: `invalid` (context lost). | 4: `invalid`. 5/6: `invalid` or `/auth/login?state=invalid` | 7: `invalid` (keeps the intent). 8/9: `invalid` (intent lost) | Reopen the original email link. Don't offer to resend the form. |
| **setup** | 1, 2, 3 (2 and 3 lose context) | 4, 5, 6 | 7, 8, 9 | Nothing was changed yet, so "Try again later" is safe. |
| **no-session** | 2, 3: `no-session` (context lost) | 5, 6: `no-session` | 8: shown as `identity`. 9: not checked, so it surfaces as an RPC failure and then `retry` | Reopen the invitation link to verify again. Don't offer the password form. |
| **identity** | 3: `identity`, `unverified` | 6: `identity`, `unverified` | 7: snapshot error, while signed in. 8: `identity` (mixes no user, RPC failure and wrong state) | Use the invited account. A sign-out action isn't in these files (**gap**). |
| **expiry** | 1: `link-expired`. 3: `expired` (substring risk, see 3c) | 4: `expired`. 6: **no mapping**, falls to `unavailable` | 7: `expired` (any `verifyOtp` error) | Ask the issuer for a new invitation. Resend is out of scope. |
| **stale** | 3: `superseded`. 2: `unavailable` (mixed with other cases) | 6: `superseded`. 5: `unavailable` | No explicit state | Use the newest email. |
| **revoked** | No explicit code. `issuer-lost` is the closest. | `issuer-lost`, `target-`/`tenant-unavailable` | `employee-unavailable`. `tenant_unavailable` goes to `retry` (**wrong**) | Contact the organisation. Don't offer retry. |
| **capacity** | Not mapped | 6: `limit-full` | `limit-full`. `limit_unavailable` goes to `retry` | Ask an admin to free a seat, then accept again or retry. |
| **partial** | 2: `password-marker-failed` (password already changed) | 5: `marker-failed` | 8: `readiness`. 7: signed in but identity failed. The silent marker cleanup and defer failures | Don't ask for the password again. No action exists to retry only the marker or readiness step (**gap**). |
| **unknown** | 3: `accept-failed` (malformed result loses context). `updateUser` errors go to `password` | 6: `unavailable`. 5: validate RPC error goes to `unavailable` | `retry`, which covers `activation_pending`, network errors, conflicts and `null` data | Don't claim failure or success. Reload or check status before mutating again. A read-only status check is **not proven** to exist. |
| **success** | 1: accept page. 2: `password-set`. 3: `/tenant/{id}` | Same as admin | 7: page. 8: `activated` or `password-ready`. 9: `activated` | One primary "Continue" action. |
| **duplicate** | Behaviour of a second accept isn't proven. Reusing a token probably goes to expired (provider-dependent). | Same as admin | 8: already activated and ready goes to `activated` with no change (proven) | Offer "Continue" only where the source proves it. |

## 3. Key mismatches between what the source proves and what the UI might claim

**a) Success can be overstated**
- `activated` is shown even if the RPC's `result.state !== 'activated'`.
- It is also shown when the marker cleanup fails.
- The UI must not claim the provisioning was cleaned up.

**b) Retry is shown for cases retrying won't fix**
- `retry` covers `employee_already_linked`, `membership_conflict` and `tenant_unavailable`.
- If the UI says "retry", the user may resubmit with no chance of success.

**c) Expiry can be misreported**
- `includes('expired')` in action 3 would also match a message like "JWT expired". That is a session problem, not an expired invitation.
- Member accept has no expiry mapping at all.

**d) The unknown outcome looks like a definite failure**
- `accept-failed` and `unavailable` include transport failures where the change may already have been committed.
- The UI must not claim it failed or invite the user to retry blindly.

**e) Password re-entry repeats a completed change**
- In the partial cases (`marker-failed` and `readiness`), and after `retry` for an intent still in `user_created`, resubmitting the password form calls `updateUser` again.

**f) Context is dropped**
- Admin set, accept, setup, no-session and unavailable all drop id and issuance.
- So does the employee `invalid` state.
- "Return to invitation" can't be offered on those pages.

**g) Rules differ between flows**
- Issuance is checked with `[1-9]\d{0,8}` at verify but `\d+` at set and accept.
- Only the employee flow asks for password confirmation.
- The same outcome uses different state names: `no-session` vs `identity`, and `password-marker-failed` vs `marker-failed` vs `readiness`.

**h) Retry has no preconditions**
- `retry` (action 9) runs with no session or password-readiness check. Whether the RPC enforces these is **not proven**.

**i) Defer can fail silently**
- If the defer RPC fails, the stored error code may not match the state shown to the user.

**j) Metadata write**
- The marker cleanup copies the user's `app_metadata` from the session and writes it back over the stored version. It could overwrite a concurrent change. This is a risk to note, not something to fix in R2.

**Sensitive data:** None of the redirects put the password or token hash in the URL (verified). Action 7's callback URL includes the raw intent id before it is validated. It is encoded, which is acceptable.

## 4. Decisions needed before freezing

1. **Scope:** limit R2 to page copy and the primary action for each state, or also allow changes to action branches (for example, keeping context, or splitting `retry` and `unavailable`)?
2. **Unknown outcomes:** adopt one "outcome unknown — check status" pattern for all nine actions. This needs a read-only status source for each flow. Which pages already have one has to be confirmed in source.
3. **Partial outcomes:** add a retry action for the readiness or marker step only, or accept repeating the password change? Either way, record the decision.
4. **Sign-out for identity mismatch:** is there an existing route for it? This is unverified.
5. **Expiry:** fix the `expired` substring-order problem, or freeze it as known behaviour?
6. **State names:** align them, or keep the current URL contract unchanged?
7. **Revoked:** treat `revoked` as covered only where a code exists. Elsewhere, record the gap.
8. **Out of scope:** issue, resend, send and delivery. Resend links used in the "next action" column are placeholders until resend is specified.

## 5. Test strategy shared across all nine actions

1. **One shared harness**
   - `redirect` throws a sentinel carrying the URL.
   - The server and admin client factories can be configured to return `null`, the client, or a failure.
   - Each RPC and `auth` call is a stub that records every call made.
2. **One test table per action, one row per branch from section 1.** Each row asserts:
   - the exact redirect URL;
   - whether context is kept;
   - which calls ran and which did not (for example, no `updateUser` after `unavailable`, and no second change on employee `activated` with password ready);
   - that the URL contains no `password`, `tokenHash` or `confirmation` value.
3. **Error-mapping order:** tests for messages that contain several tokens, plus `"JWT expired"`. These pin the current substring order.
4. **Unknown and partial:** inject a successful change followed by a failure. Assert that no success redirect happens and record what the redirect is. Assert that the marker and defer failures stay silent (this documents current behaviour).
5. **Page states (later, in the page layer):** each `state` value shows exactly one primary action that matches section 2, and the unknown and partial states show no retry action.
6. Don't assert idempotency or duplicate behaviour of RPCs or the provider. Stub them and label them as assumptions.

**Not covered:** this is not a claim of full coverage for the nine actions. The remaining gaps are:
- how the pages render each state;
- what the RPCs and the provider actually return (idempotency, duplicate submissions, revoked);
- whether a read-only status check exists;
- whether a sign-out route exists.