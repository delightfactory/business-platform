# Cube 3 HR Leave review interface qualification

Local qualification on 2026-10-01; no deployment or remote database changes.

## Delivered flow

The permission-gated workspace navigation opens `/tenant/[tenantId]/leave`. HR sees bounded, server-paged submitted requests and pending cancellation requests (50/page), then opens an individual request to inspect the saved daily preview. Refreshing a preview is a separate command from approval. Approval, rejection, cancellation request and cancellation decisions require a reason and their exact request/preview/cancellation versions. Recording for another Employee and balance administration are separate, unfinished slices.

Queue summaries have a distinct parser from full request details. Each intent keeps its UUID key and reason on an unsuccessful retry; a changed request, preview or cancellation version remounts the intent form with a new key. Unknown results instruct the reviewer to inspect/retry rather than assume rollback. Success notices match the persisted state; refresh notices additionally require the resulting request and preview versions. Historical consumption is labelled as historical consumption, including after balance restoration.

## Observed browser evidence

All actions used the running application on loopback port 3304 against the guarded synthetic `business_platform_cube3_upgrade_qa` database.

- Discovered a submitted request from the queue, refreshed its preview twice, and explicitly approved it afterward. Refresh did not approve or consume balance. A second submitted request was rejected from the interface.
- An Employee requested cancellation. HR rejected it and the parent remained approved. A second Employee cancellation was accepted through HR; the parent became cancelled and decision controls disappeared. SQL confirmed exactly 1.00 historical consumption and 1.00 linked cancellation reversal.
- A real concurrent RPC refreshed another request while its old approval form remained open. Submitting that old form returned a version conflict and preserved both the reason and a fingerprint of the intent key.
- A synthetic `leave.view`-only role showed the detail and history with zero mutation forms. Invalid history paging exposed a first-page recovery link. All seven original QA membership-role rows, including their timestamps, were restored exactly.
- A request belonging to one Tenant was unavailable under another Tenant's authenticated context; no detail or mutation form appeared.
- Disabling both People and Leave hid new approval/refresh controls, while existing-request rejection and pending-cancellation acceptance succeeded. Both original entitlement rows were restored exactly.
- An empty history page 50 retained the latest pending decision and provided previous/first-page links. Empty later queue pages provided first-page recovery independently for each queue.
- RTL at viewport widths 390, 820 and 1280 had document widths 375, 805 and 1265 respectively, with no horizontal overflow. Phone queue and review screenshots were inspected; temporary viewport overrides were reset.

External local evidence lives under the run directory `20261001-cube3-leave`: guarded `qa-hr-review-browser.mjs`, `qa-hr-access-browser.mjs`, fixture snapshots and screenshots in `runroot/qa-hr-*`. These contain synthetic QA evidence, not production acceptance.

## Gates and review

Final `npm run build` (including TypeScript), `npx eslint src/app/tenant src/components/context-navigation.tsx`, and diff whitespace checks passed. The free OpenCode implementation ran in a separate worktree; root imported only its ten owned files and repaired independently identified issues. A separate read-only reviewer passed the final source and recovery changes. Browser and gates were executed by root independently of the implementation report.

## Remaining Cube 3 work

This qualifies the HR review/decision surface only. HR recording for Employees without accounts, balance administration, inspectable correction journeys, paired half-day/Time reconciliation, annual statutory calculation and final Cube-wide closure remain required. No silent Attendance correction, Payroll consumption, production statutory qualification, merge or deployment is claimed.
