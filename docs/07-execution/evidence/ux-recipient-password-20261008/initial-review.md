**Verdict: changes requested.** These are blocking copy issues. I reviewed only the diff; I opened no files and ran no tests.

**What's correct**
- Both pages now choose the password form or the accept form from the RPC validation result, not from the URL hint. No path claims the password was saved, the tenant was created, or a role was granted.
- `role="status"` is a reasonable fit for these neutral messages.
- The hidden id and issuance fields, sign-out, the forms and the role text are unchanged. Each page uses its own correct marker key.

**Blocking**
1. **Marker text in the unavailable fallback.** The new wording says "اتبع الخطوة الظاهرة الآن" ("follow the step shown now"). In the fallback, only `Status` renders, so no step is shown. Replace it with: "تعذر تأكيد حالة الحساب أو الدعوة الآن. اطلب من مشغّل المنصة / مسؤول الشركة مراجعتها."
2. **`password` in the fallback.** In both `stateMessage` and `validationMessage`, it still says the password could not be saved and to try again, but there's no password field there. Under your spec it should get the same neutral wording.

**Non-blocking**
3. On the member page, `validationMessage` checks `state` before `validation`. So the hints `password` and `marker-failed` replace the identity, denied and malformed reasons. This was already true before this diff and needs a separate decision.
4. With `password_required` plus `password`, the user no longer sees that their last try failed. That follows from not trusting the URL hint, so it's acceptable.

**Not verifiable from the diff:** what `password-set` shows in either fallback.