# Review: employee activation page correction (proposed spec, source af8cbe75)

This is not frozen and not acceptance. I didn't run any tests or tools. N/C/P/I/B are source hypotheses, not measurements. The only things observed are the baseline password-field and false "saved" findings.

## Adequacy and amendments

1. **`user_created` + ready=true → retry form: accept, with limits.** SQL `activate` re-checks identity, readiness, tenant, employee, seat and role, so a retry can't bypass authorization. Readiness only shows that the provider update and the same-user recheck succeeded. It doesn't prove the outcome. The page should say "finish activation", never "password saved". Show no password fields and don't auto-submit. HR contact is the only secondary action.
   - **Owner decision:** whether to offer re-entering the password as a secondary path. The action would accept it, because `user_created` + ready goes to a provider update.
2. **Strict snapshot: amend.** For `user_created`, require an exact `intent_id` match, a valid `state` and a boolean `password_ready`. Otherwise show the unavailable recovery screen with no form. For `activated`, keep the current `=== true` branching exactly, even if readiness is null or malformed. Otherwise "preserve activated" conflicts with the strict rule. Flag this so it gets fixed later.
3. **Query hints become text only.** `limit-full` and `employee-unavailable` can no longer hide forms or claim anything. Use neutral copy: "A previous attempt couldn't be completed." A genuine "employee unavailable" can turn into a loop of manual retries. The fix is to make HR contact prominent when that hint is present, not to suppress the form.
   - **Owner decision:** whether that hint should demote retry to a secondary action.
4. The helper treats any returned record as success, but the page re-reads the snapshot after redirect. So if the state is still `user_created`, the user correctly sees retry again.

## Minimal case matrix

| Group | Cases | Expected |
|---|---|---|
| A. Access | Invalid UUID, no session, denied/error snapshot, `intent_id` mismatch, changed auth actor | Unavailable + HR, no form |
| B. Malformed | Missing or unknown state, non-boolean readiness on `user_created` | Unavailable, no form |
| C. `user_created`/ready=false | × hints {none, retry, readiness, limit-full, employee-unavailable, garbage} | Password form, neutral text, no "saved" or capacity claim |
| D. `user_created`/ready=true | × same hints | Retry form only, 0 password fields, no auto-submit |
| E. `activated` | true / false / null × forged hints | Continuation / password form (unchanged); hints ignored |
| F. Expired, deleted, unconfirmed | Snapshot rejects | Unavailable + HR |
| G. Actions (unchanged, regression only) | Provider failure, readiness error, SQL rejection, helper throw, deferred error ignored | Current redirects |
| H. Privacy | — | No password or token in URL, storage or DOM; only the safe `intentId`; display names come from the snapshot only |

## Classification

- **Class C (safe presentation fix):** strict validation and the unavailable fallback; hints become text only; readiness-driven form selection; removing the false "saved" claims.
- **Needs owner/security sign-off:** the activated-readiness inconsistency; the secondary password path; whether the employee-unavailable hint demotes retry. Also the action behaviour that stays unchanged:
  - The helper treats any returned record as success.
  - Deferred and marker-cleanup errors are ignored, and throws escape.

## Open gap

There's still no way to find out or reconcile a result that comes back as unknown. If the RPC times out or returns something malformed, nobody knows whether membership was committed. The snapshot may lag, and the page can only show retry or HR. Fixing this needs a separately reviewed reconciliation contract, not a UI loop.