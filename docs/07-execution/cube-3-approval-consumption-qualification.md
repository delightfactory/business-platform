# Cube 3 — approval and consumption checkpoint

## Delivered

Approval is a separate, authorized command. It checks request and preview versions, revalidates Employment and effective configuration, rejects overlapping approved Leave, and commits the decision and tracked consumption atomically. Existing balances are allocated per eligible date in period-start order; a future account period cannot fund an earlier date. Pending requests still reserve nothing. Untracked paid/unpaid types create no debit. A permitted approver can approve their own request, with distinct submission and approval events and identities.

Effective configuration changes return `refresh_required`. Explicit preview refresh appends a new immutable calculation version and advances request CAS; it does not overwrite the submitted evidence. Approved requests pin the reviewed version. Consumption allocations and ledger entries are append-only. Replay returns the original decision without another debit, under current authority.

The own-access snapshot now exposes `self_can_request` separately from `self_access`. Own history permission does not grant request permission, HR visibility, or an employer list. The interface must also check `new_work_enabled`; the RPC remains authoritative.

## Local verification

- Applied the finalized approval function and additive access snapshot on both isolated QA paths, at 92 migrations. A separate new clone, `business_platform_cube3_approval_upgrade_qa`, was copied from the untouched 82-migration Cube 1/2 source and upgraded with the normal CLI migration chain.
- Seven focused Leave suites passed on that source-clone upgrade and the application-fresh QA path: 214 assertions each. Three additional personal-approval assertions were then added; the full approval file passed again with 47 assertions on each path. No entire application regression or browser acceptance is claimed here.
- Final function definitions and ACLs matched between both paths. Row hashes for the original five Employees, four Employments and two links matched their source clone.
- A real two-session, authenticated approval race used two requests on different dates and one final balance unit. PostgreSQL lock waits were observed at the balance-account barrier and the Employee serialization point. Exactly one request approved, one stayed submitted with `leave_balance_insufficient`, and only one debit/allocation/approval event persisted. Same-key retry produced no additional debit or event. The observer could not see the approval query text; the harness invokes the RPC itself and records session PIDs and blockers.
- Draft defects were repaired before this checkpoint: an incorrect constraint name (failed transaction rolled back), PL/pgSQL record names shadowing SQL aliases, and a test querying own history with the wrong actor. The authoring QA RPC was repaired locally during development. The independent source clone then received the corrected definition through the normal migration chain. A duplicate index covered by the consumption primary key was removed from the draft and aligned on QA.

Evidence lives outside the repository under `C:\Users\DELL\AppData\Local\ai-dev-workflow\runs\20261001-cube3-leave`: the QA TAP logs, source-clone migration log, `slice4-function-data-comparison.json`, and `runroot/qa-leave-approval-concurrency-c4781044-4c9e-4522-9ec8-fb79b4c9cd1b.json`. A checkpoint manifest records the committed source identity and hashes. Existing populated QA targets contain separately identified synthetic fixtures; the source clone remains untouched.

## Remaining acceptance

This checkpoint is not Cube 3 closure. Cancellation/reversal, correction, complete employee/HR journeys and configuration interfaces, qualified annual calculation, mapped half-day Attendance obligations, explicit Attendance reconciliation and Payroll projection remain outstanding.

Historical approved Time facts block Leave even after Attendance entitlement ends. Half-day approval with Attendance enabled currently returns a mapping-required decision. Time fact writers still need the reciprocal Leave check and two-session cross-domain verification; the balance race above does not qualify that boundary. The complete clean-install/upgrade, application regression and responsive browser gates remain required for the final Cube 3 candidate. No remote migration, merge or deployment was performed.
