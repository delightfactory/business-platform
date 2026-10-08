# Official direct Claude Opus5.5 Medium

Session c6ecb1ac-387e-4e75-8724-6dca3a94dd82. Read-only, supplied source/render scope only.

# Source co-design verdict: onboarding captured-intent recovery

**Verdict: Approve the direction, with eight corrections required before implementation.** The state machine is sound and stays within routine reuse: the current actor, the `(actor,key)` RPC and `tenant_onboarding_result`. It needs no new storage, URL protocol, persistence or cross-actor authority. The corrections below come from the final SQL you supplied. None of them adds authority.

As you asked, I used no tools, made no edits, did not write the plan file and did not call ExitPlanMode. This is a source-only review, with no runtime or visual acceptance. Visual status for both Codex and Opus: **NOT VISUALLY VERIFIED**.

## The SQL fact that holds the design together

`onboard_tenant` runs as one transaction. Every `RAISE` rolls back the idempotency insert, so a confirmed exception never commits that `(actor,key)`. The only way to reach the `onboarding_admin_*` checks is `v_rows = 1`, meaning no row existed for this actor and key. `ON CONFLICT` also waits for any concurrent inserter, so these errors are proof of no prior commit.

That gives one invariant: **one key per window, never rekeyed, so at most one tenant per window**, whatever payload is later sent with that key.

## Required corrections

**C1. Exact error table.** Match on `error.code` and an exact `error.message`, not `.includes`:

| Code / name | Before uncertainty | During identical replay after uncertainty |
|---|---|---|
| `42501` `platform_operator_onboarding_forbidden` | frozen; restore access, then retry the identical request | stays frozen (raised before the insert, so it proves nothing) |
| `22023` `onboarding_required_fields_invalid` | editable, same key | editable, same key (the check depends only on the payload, so the original failed too) |
| `22023` `onboarding_invalid_limit` | editable, same key | editable, same key (same reason) |
| `22023` `onboarding_admin_not_found_or_disabled` / `onboarding_admin_email_unverified` | editable, same key | **editable, same key** (proves no prior commit; see C6) |
| `P0001` `onboarding_idempotency_conflict` | frozen | frozen |
| `55000` `onboarding_idempotency_incomplete` | uncertain | uncertain |
| `42501` with any other message, any other code, a thrown error, or an unusable receipt | uncertain | uncertain |

**C2. Pre-dispatch validation parity.** Without this, avoidable server errors land in the "uncertain" state.
- Validate the key with `operatorUuid` instead of the loose `[0-9a-f-]{36}`.
- Cap limits at `2147483647`. The parameters are `int4`, so larger values currently give `22003` and are wrongly treated as uncertain.
- Enforce the 160/160/160/254 length limits by code points (`[...s].length`). Postgres `length` counts characters, not UTF-16 units.
- Reject unknown mode values. Do not default them to `limited`.

**C3. Normalization baseline.** Postgres `btrim(x)` strips only spaces, while JS `trim()` strips all Unicode whitespace. SQL's step is a no-op on values JS has already trimmed. So the comparison baseline must be **the JS-normalized values actually sent**, re-derived deterministically from the captured FormData on every replay. The legal-name fallback (empty, so use the company name) applies after trimming. Do not claim byte-identical SQL semantics.

**C4. Receipt comparison uses only fields the snapshot actually contains.** `onboardingSnapshot` has no admin email. Compare email only if the helper `provision_tenant_with_admin` return value includes it; check this against the helper source. Otherwise, drop email from the receipt check rather than inventing a field. Start the admin continuation from `tenant_id` through the existing `tenant_admin_snapshot` path.

**C5. Typed outcome of `dispatched: false | true`.** These outcomes all happen before the RPC is sent:
- setup failure
- `getUser` error or null
- a mismatch with the captured actor
- invalid input or key

They **never change the current phase**: editable stays editable, uncertain stays uncertain and frozen. This is the precise version of the spec's "setup vs unknown" rule.

**C6. Resolving uncertainty after an identical replay.** An identical replay ends in one of these:
- a valid matching receipt, which means saved;
- a C1 "editable" error, which proves no commit for this key and allows deliberate edits with the **same** key;
- anything else, which keeps the form frozen.

Without this rule, a disabled admin leaves the operator permanently frozen. That is the forced re-entry the spec is trying to remove.

**C7. Null result authority is narrower than the spec implies.**
- `tenant_onboarding_result` already joins the current grant, so null also covers the case where the grant was revoked.
- The only thing null unlocks is an identical replay, and SQL fully re-authorizes that replay.
- So the pre-read capability check is advisory. Reuse an existing capability read if the page already has one; do not add a new RPC for it.
- The `getUser` match against the captured actor is still required before the read.

**C8. Keep the existing path and keep the actor guard-only.**
- If the page currently server-reads `?key=`, that path stays exactly as it is. Removing the redirect only changes this action.
- The captured actor is compared against `getUser().id` and is never passed to SQL as authority. Only `auth.uid()` authorizes.
- Conflict state: show "a different saved request exists for this attempt". Do not acknowledge it. Offer only existing navigation, with no rekey.

## Unchanged and accepted from the spec

- One ref and transition lock across save and read, released only after state is set.
- FormData captured synchronously, before the fieldset is disabled.
- Inputs stay mounted and uncontrolled while frozen, so `router.refresh` props cannot rewrite them.
- The JS-required/disabled SSR and native-POST behavior stays the same.
- Arabic/RTL error copy, `dir="ltr"` on the email input, and the existing 40/44 control sizes.
- `OperatorActionForm` and the shared redirects stay untouched.
- Saved state changes the task only after receipt validation.

## Must be checked in source before implementing

1. The shape of the `provision_tenant_with_admin` return value, for C4.
2. Whether `/operator/onboarding` reads `?key=` today, and where the key is generated, for C8.

Excluded, deferred or needing an owner decision: durable recovery across windows or actors, fresh-key escape, D16 extras, payroll A/B, and any R0–R8 closure, PR or deployment.
