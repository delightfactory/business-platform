# D8 self-service auth return review resolution

PROPOSED, NOT OWNER-APPROVED OR APPLIED. Base97449deb302ad47075a2b549293146f7077df8db. Exact patch modifies only safe-next.ts after approval. No application source changed while preparing this decision; no heavy build/SQL/Auth/device loop or sensitive access/service.

One official Opus5.5 Medium read-only checkpoint7e37974a-f34b-4d14-a1db-102de730c80c; completed/touchedFiles0/readOnlyViolation=false. Original conditional review preserved with trailing whitespace normalization. Codex resolved source conditions:

1. Shared uuid source has no top-level alternation; new grammar derives only hex case support without changing version/variant requirements.
2. Only LoginPage and signInAction call safeAuthNext under src. No callback/logout/invitation caller uses this helper; existing policy behaviour remains preserved for those route classes.
3. Reviewer case issue fixed: no i flag on fixed route segments; UUID hex alone allows upper/lower case. Added uppercase route rejection and uppercase tenant/request UUID cases. Final classifier60 cases passed after this correction. This is the required reviewer correction, not an unreviewed new scope.
4. Exactly five existing self-service page folders matched: me, attendance, leave, leave/new, leave/[requestId]. No me/profile or me/pay addition.
5. Correct reviewer statement about JavaScript $: without m, it CAN match before a final line terminator. New branch explicitly rejects controls/spaces, and tests trailing/embedded newline. Do not cite $ alone as the safety proof. Existing unrelated legacy policy remains outside this approval and is not newly qualified.

Final evidence:60 classifier cases (7 valid examples/5 shapes,32 denied classes,21 existing behaviour comparisons);20 actual signInAction cases with fake SDK/provider (success/invalid-form/setup/provider failure across5 routes);5 actual LoginPage static React cases with Link/SubmitButton/action stubs. Patch applicability checked with git apply --check --unidiff-zero only. These85 focused cases do not prove real authentication, same-tab browser storage, destination role/RLS/privacy or all D8 paths. Tests for cross-tenant/revoked/different-user request/no attendance.self.capture and login round-trip receipt preservation remain OPEN; execute under the approved bounded environment when qualifying implementation. No fixture passwords/credentials or raw runtime logs committed; harnesses remain local.

Scope for owner decision: accept the five exact routes as allowed post-login destinations, with no queries/fragments/arbitrary descendants/external URLs. Redirect grants no authority. Branding layout can return children and is NOT a blanket authorization boundary; destination RPC/page guards remain authoritative. No change to storage keys/logout/corrupt receipt/automatic replay or /me integration is included. Explicit mid-action session outcome/link is a subsequent reviewed batch; this patch alone does not fix that journey.

After approval: apply exact reviewed patch with its related bounded session recovery, one aggregate lint/build+TS and applicable focused/bounded acceptance; reuse unchanged evidence. Until approval: keep application untouched and progress independent R6/HR review where possible. Do not mark whole R5/R6/D8/R0-R8 complete.
