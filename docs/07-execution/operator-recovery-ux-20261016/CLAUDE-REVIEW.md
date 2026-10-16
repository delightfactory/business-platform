**Verdict: ACCEPTED.** I found no blocking problems. This covers Batch 7 only, not the whole goal: the remaining coverage work and the shared-component pass are still open.

**What this review is based on.** I read the source and the two dev-runtime phone screenshots (390px, dark theme) that you had already looked at. I did not run anything: no tests, lint, build, SSR, login round-trip or the partial-fault check. Those results are yours. Nothing has been checked on the final build yet. The unit test's UI stubs prove which branch renders, not how it looks. I did not inspect the hidden key value. I read the enterprise-workflow-ux, frontend-design and clean-code-guard skill files. I didn't open test-guard, because the test file was small enough to review directly.

**Task and capability**
- An operator who hits a partial-authority, uncertain-session or read-failure state gets a titled warning. They can retry the same URL and context (mode and key, or q and page), which only reads, or go back to a page they're allowed to see.
- **Back links:**
  - Not an operator: `/tenant/select`.
  - Operator with company-list access (commercial or lifecycle): `/operator/companies` with q and page kept.
  - Operator with onboarding access only: `/operator/invitations`.
  - Any other operator: `/operator`.
- This matches the actual company-list guard (`src/app/operator/companies/page.tsx:22`).
- When authority is unknown or not configured, the new-company page shows "تعذر التحقق من صلاحية الإنشاء" and offers a retry. It doesn't claim the account is denied (`new/page.tsx:17,20`).
- A denied user gets no retry and the page makes no RPC call. A read failure calls only the one read-only snapshot RPC for that page. `CompanySetup` and the original result read are unchanged. No create or resend runs on its own, and an invalid reference offers no "start new" button (`new/page.tsx:22`).

**Sign-in return safety (`safe-next.ts:9-25`)**
- The path is checked against a strict pattern before URL parsing, so `..`, `%2f` and other encoded traversal can't get through.
- Raw spaces, control characters, `#`, `\`, `%00`, `%0a` and `%0d` are rejected. q is also checked for control characters after decoding.
- Unknown or duplicate parameters are rejected, as is any change of origin.
- `/new` accepts only `mode` = invite or existing and a UUID `key`. Other company pages accept only q (up to 120 characters) and page, matching the limits `operatorListQuery` already uses.
- The login action checks `next` again on the server (`auth/actions.ts:11`), so it doesn't trust the hidden field.
- Tenant isolation, finance, privacy and audit paths are untouched, and no action, RPC or business state changed.

**Simplicity, failure and recovery, layout.** Each state has one main action (solid retry, ghost back). I found no dead end and no misleading success message. The screenshots show readable RTL text, a full-width card and two clear buttons. Touch-target size and keyboard focus can't be confirmed from source or a static image.

**Leave page.** The empty state now points to «طلب إجازة», matching the button label at `me/leave/page.tsx:88,138`. I'm not asking for anything else there.

**Optional notes (not blocking)**
1. On the services, limits and status pages, a malformed tenant ID in a full-authority session shows "غير متاحة لهذا الحساب" (`services/page.tsx:24`, `limits:18`, `status:18`). That suggests a permission problem when the link is actually bad. The back link is still correct, and the state only happens with a hand-edited URL.
2. A signed-out user on `/new` with an invalid key loses both the key and the mode at sign-in, because the allowlist rejects the URL. After signing in they land on the default page instead of the "invalid reference" message. This is safe, just a little less clear.
3. `OperatorRecovery.tsx:12` works out the back label by matching the href string. That's fragile if more back targets are added; passing the label in explicitly would be sturdier.
4. Test gaps (from reading `operator-recovery.test.cjs`):
   - No page-level sign-out redirect test for the services, limits and status pages; only the allowlist is tested.
   - The failure-path test doesn't check that the back link keeps q.
   - No case for an operator with onboarding access but no company-list access.
5. In the denied-employee screenshot, the shell header reads "تشغيل المنصة" (platform operations) to a non-operator. That's a shell-level layout issue, so it belongs in the shared-component pass rather than this batch.