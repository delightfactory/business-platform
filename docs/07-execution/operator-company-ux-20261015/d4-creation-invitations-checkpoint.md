# D4 company creation and invitations checkpoint

One canonical company setup offers invitation (default) or existing confirmed account, retaining shared input when switching. Company name and administrator email are the two primary manual fields. The actual first-site default and initial user/site limits remain visible in collapsed detail summaries and can be changed. Mandatory invalid fields reveal their containing disclosure. Legacy entry links preserve mode and request identity.

Confirmed-account onboarding retains the original captured-payload, actor, idempotency and read/retry contract. Its receipt gives direct services continuation when C is present and an honest handoff otherwise. Reviewing a stored legacy request returned the original receipt for the same company without a second creation.

Invitation creation returns a confirmed invitation receipt, distinguishes company-not-created from creation, and separates provider acceptance, mail failure and unknown delivery. Existing invitation receipts do not resend mail. Rejected input, authority, conflict and unknown outcomes have distinct treatment. Unknown submission locks both mode and mutation controls; it does not issue another request key. Follow-up shows Cairo expiry and a two-step cancellation. Accepted rows can link to their company only with section permission.

## Actual runtime evidence

- Mode switches preserved entered company/email/limit17 without mutation.
- OPJ1 directory discovery: 2 navigations, 2 activations, 1 search field (before3/3/1).
- OPJ6 confirmed-account creation: 2 navigations, 3 activations, 2 manual fields, no search (before5/6/3 plus search). Real synthetic company created, authoritative receipt then direct services continuation.
- OPJ7 invitation follow-up: 2 navigations, 3 activations, 2 fields (before1/2/2). The extra acknowledgement is intentional: a truthful receipt before follow-up. Real invitation was pending with no tenant, then remained pending on opening cancellation; only the second confirmation revoked it. Mail was accepted by the isolated provider; actual recipient delivery is not claimed.
- One scoped blocked invitation POST produced one failure and no automatic resend. Mode and submit locked; follow-up remained available after removing instrumentation. The synthetic target had no invitation row because this particular fault happened before dispatch; absence is not promised for every unknown outcome.
- Legacy onboarding request review returned the already-created company's receipt; legacy invitation URL redirected to the canonical chooser.
- Desktop1366, tablet768 and phone390 inspected; tablet document width768 and phone width390, no horizontal overflow. Three representative images retained externally. Viewport override reset.

## Measurement fidelity and remaining coverage

OPJ1 and OPJ6 were actually measured at1280x720, not the spec's1366. D3 early OPJ2/3 viewport was not separately recorded and may also have been1280; D3 separate responsive captures were explicitly1366/768/390. Counts are actual observations, not certified same-viewport comparisons. Final independent review must retain this qualification or request one bounded comparable measurement; synthetic creation was not repeated just to change pixel width.

Accepted-invitation company continuation and O-only/no-C creation receipt are source-covered but were not manually exercised in this slice. D5-D7 and full independent Operator acceptance remain open. Company-user workspace work has not started.

Four focused action tests passed (rejections/authority/conflict/unknown, existing receipt without resend, mail receipt truth, interrupted mail retaining confirmed identity). Final TypeScript, focused lint and coherent build results are retained in the external gate journal. No backend contract changed, so D2 SQL suites were not repeated.

All active output/dependencies remain outside OneDrive and are needed by the continuing goal. No cleanup or cloud-quota savings are claimed for this slice.
