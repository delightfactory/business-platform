# Employee cancellation interface — local qualification

## Delivered workflow

An employee can open their approved Leave request, disclose a focused reason form, submit a cancellation request and see its pending state and HR ownership. The Leave stays approved until HR accepts cancellation. Rejection leaves Leave approved and permits a new cancellation request. Acceptance displays the cancelled parent and retained decision history, with no new cancellation form.

The action calls the existing own-only `leave_my_request_cancellation` RPC with authenticated identity, expected request version, reason and an operation key. The page reads current cancellation status through `latest_event` independently of history paging. UI submission is gated by the existing `leave_access_snapshot.self_can_request`; failed access verification hides submission and offers recovery. Historical cancellation does not depend on `new_work_enabled`. History/pending status remain readable without request permission. Server-side ownership, membership and authorization remain authoritative.

Inputs and the operation key survive a failed submission; changing the reason creates a new intent key. Controls disable while the action is pending. Approval and cancellation remain separate. Feedback from URL parameters is shown only when it matches the actual request/latest-event state, so an old success URL cannot claim pending cancellation after HR decides it. Balance wording says any consumed balance is returned, without falsely claiming consumption for untracked types.

Files: the own-request detail `page.tsx`, `CancellationHistory.tsx`, `RequestCancellationForm.tsx`, `cancellation-actions.ts` and `cancellation-rules.ts` under `src/app/tenant/[tenantId]/me/leave/[requestId]`.

## Verification executed on the final UI source

Using the real app at loopback port 3304 and isolated `business_platform_cube3_upgrade_qa`:

- Authenticated browser submission created a pending cancellation while the parent remained approved. Pending feedback identifies HR as the next actor and hides duplicate submission.
- A stale version returned the Arabic conflict message, preserving the reason and unchanged operation key. The deliberate hidden-input test change was removed by reloading afterwards.
- HR rejection through the actual authenticated cancellation RPC restored the new-request path. A second browser submission succeeded; accepting it through the actual HR RPC changed the parent to cancelled, retained all four history events and hid submission. This is employee UI qualification; HR UI decision controls remain a separate unfinished slice.
- An empty later history page (`h=50`) still showed current pending status; it offered previous/first-page recovery instead of treating empty history as permission to resubmit.
- An actual synthetic view-only role could read approved detail/history but saw no cancellation form. The original membership-role assignment, including its creation timestamp, was restored and checked byte-for-byte by the guarded fixture helper.
- Changing the Tenant context to a second synthetic company while retaining the first company's request ID returned the unavailable screen without revealing the request.
- Arabic RTL at widths 390, 820 and 1280 had document scroll widths 375, 805 and 1265 respectively: no horizontal overflow. Browser screenshots include mobile validation/pending, tablet paged status, desktop accepted state and view-only permission state. Viewport override was reset afterwards.
- `npm run build`, TypeScript during build, `npx eslint src/app/tenant`, and `git diff --check` passed. Independent read-only source review passed, including permission gating and live-state success feedback.

The related backend conflict fix passed 386 pgTAP assertions on each fresh/source-clone qualification database and real HTTP conflict/replay checks; see `cube-3-http-conflict-qualification.md`. Historical tracked-balance reversal and own-only permission checks remain covered by those executed DB suites. The browser fixture type is untracked and does not prove a tracked balance refund by itself.

External run evidence: `qa-own-cancellation-browser.mjs`, `qa-cancellation-view-only.mjs`, their guarded fixture JSON files, `qa-cancellation-http-conflict.mjs`, and `runroot/qa-cancellation-*.png`. The view-only fixture is restored. Synthetic Leave history is retained. No credentials are committed, no remote database was mutated, and no deployment or main merge occurred.

Cube 3 remains open: HR interfaces, approved replacement correction, half-day Time reconciliation, annual entitlement calculation qualification, reports and final full regression are separate required work.
