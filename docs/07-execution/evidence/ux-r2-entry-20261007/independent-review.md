**PASS: no blockers in R2-ENTRY-01.** I reviewed only the diff and evidence you included and used no tools.

**Capability and simplicity**
- **Tenant error:** retry is the main action, sign-out stays separate, and the support guidance is clear. The plain GET form to `/tenant/select` does a fresh document load without automatic retries or session changes.
- **Setup failure:** support guidance and the login link only lead back out. Nothing new is unlocked.
- **Employee activation:** each state has one main action. Arabic, RTL and the `dir="ltr"` password fields are unchanged.

**Failure and recovery**
- `Object.hasOwn` makes unknown and prototype keys show the generic message, and the evidence shows the baseline `__proto__` crash is gone. Known messages are unchanged, and no token or query value is echoed.
- The forged `password-ready` case is fixed: when the account is activated but not ready, the form always shows. In that branch the inner `state === 'password-ready' && intent.password_ready === true` check can now never be true. It's harmless dead code you could clean up later.

**Authority**
- The workspace link only appears when the server snapshot says activated and ready. `/tenant/select` still decides access through `current_tenant_spaces` and the layouts. No RPC, action, allowlist or reference validation changed.

**Not a blocker, already there before this diff:** when the account is genuinely ready, a `?state=password-ready` URL still shows "تم تحديث كلمة المرور" ("the password was updated"), even if nothing was updated. Track it with the open R2 work.

The wider R2, provider and UAT acceptance is still open.