# Cube 3 HR request recording UI

HR users with `leave.manage` can discover `/leave/new` from the review queue, search employees against an explicit date range, and record a request for an active Employment without requiring an employee user account. Submission remains separate from approval and does not reserve balance.

The Server Action checks the authenticated actor, Tenant access, syntactic input, and new-work availability before calling `leave_record_hr_request`. The command remains authoritative for Employee/Employment scope, type/calendar policy, half-day mapping, and replay. UI type choices require continuous version coverage across the selected interval.

## Retry and result behavior

- Each submitted intent gets a random operation UUID. Editing normalized payload changes the key; returning to the same payload within an unresolved form reuses its key.
- The browser tab saves type, half-day/part, reason, and operation key in `sessionStorage`, scoped to actor, Tenant, Employment, and dates. Hydration disables submission until restoration finishes. Unresolved drafts have no silent time expiry.
- A confirmed action result clears that draft and displays the returned request link. URL parameters alone cannot produce this action receipt. The existing submitted-detail view verifies the current request source/state before describing it.
- After an action error, controlled fields are remounted from the retained state to counter native form reset. Pending submission disables inputs and the form Cancel link.
- If storage fails, the page explains that reload restoration is unavailable. Closing the tab can also discard session storage. If new work is disabled after an earlier attempt, the user is directed to inspect the queue for its result.

## Qualification on 2026-10-01

Local QA only: `business_platform_cube3_upgrade_qa`, application `127.0.0.1:3304`, authenticated synthetic Tenant `5cb9cb76-c0b5-428f-983d-adca6f3639ad`. No deployment or remote database operation.

Verified through the browser and then read back from the local database:

1. Queue discovery, date/name search, selected Employment, type/reason submission, and factual request detail with source `hr`.
2. Reload restored the selected type and reason. Half-day reload also restored the checkbox and reason.
3. Full-day request `919c6d27-4a5e-4c09-8496-94ae5d507ee1` was rejected. Identical subsequent payload created independent request `149b049b-2729-4f49-be65-b12a98cb5fa5` with state `submitted`.
4. Accountless synthetic employee `f96f136f-bc1c-4e6f-9bf7-5104238b3fe5` successfully recorded request `af1df875-b93d-4ad8-9428-d8feffc5d019`. A local query confirmed no employee user link.
5. Half-day request `a2085dc4-24da-4a7b-bef3-39842a41df6a` showed `0.5` day, source `hr`, state `submitted`, and leave-only mapping. Attendance was disabled in this fixture; this does not qualify an Attendance fact.
6. Dates outside the fixture year period produced the specific calendar/period error. Selected type, half-day checkbox, and reason remained visible after the error.
7. Read-only access and disabled People/Leave entitlements each removed the recording form and showed their respective explanation. Original membership role rows and both entitlement rows were restored exactly by the guarded QA helper.
8. RTL DOM checks at widths 390, 820, and 1280 found no horizontal overflow. The actual mobile viewport screenshot was visually inspected. Full-page stitched screenshots were unsuitable for layout proof because fixed navigation was offset between segments.

TypeScript, Tenant ESLint, and production build passed after the changes. Independent source review covered action receipt, names, draft scope/hydration, no silent expiry, pending Cancel, error mapping, and controlled-field remount.

External evidence under the isolated run's `runroot/`: `qa-hr-record-mobile-viewport.png`, `qa-hr-record-halfday-success.png`, and `qa-hr-record-access-browser-fixture.json`. The last file contains the before/after role and entitlement qualification snapshots and is not committed.

## Remaining goal work

This slice does not complete Cube 3. Fixed/flexible Attendance half-day qualification, actual lost-response fault injection, HR balance posting/read UI, linked correction UI, the explicit Leave/Time fact correction seam, fractional absence/report closure, and the annual availability policy gate remain in the goal. Existing database regression results belong to the balance/backend qualification; no new database migration is included here.
