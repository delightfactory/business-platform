# HR Leave balance read qualification

The existing HR balance list cannot support an auditable balance workflow: it excludes adjust-only members, omits Employer/account identity and ledger sources, and cannot distinguish an Employee without an account from an invalid selection. Five bounded RPCs provide the read prerequisites for an HR balance interface without granting People-directory access or requiring an Employee User account.

## Scoped read contracts

- `leave_balance_employee_options`: literal code/name search of 2–80 characters, one deduplicated Employee/Employer pair per result, 1–50 items and a complete `(employee_code, employee_id, employer_entity_id)` keyset. Employment history or an existing scoped account establishes the pair; ended Employment and inactive Employers remain inspectable.
- `leave_balance_accounts`: an explicit Employee/Employer pair, account/type/period identities, dates, full server ledger balance, opening/grant occupancy and historical status. A valid pair without accounts returns an explicit empty list.
- `leave_balance_ledger`: a selected account checked against Tenant, Employee and Employer together, descending immutable `(created_at, entry_id)` pagination, signed days, actor UUID, reason, source/type-version provenance, exact request consumption/reversal links and scoped correction lineage. It does not parse arbitrary source text into resource identities.
- `leave_balance_posting_periods` and `leave_balance_posting_types`: configured periods and effective tracked type versions for audited manual posting. Opening provenance uses period start; grant/adjustment provenance uses current Cairo date, matching the existing command. Expired periods are retained. Existing opening/grant occupancy is explicit.

Account, ledger and posting pages require limits of 1–100 and complete keyset cursors. Each page reads `limit + 1` and returns explicit continuation keys. Balance totals include the whole account ledger, independently of the displayed page. Pagination provides ordinary statement visibility, not a frozen snapshot across concurrent writes or renames.

Balance reads accept `leave.view OR leave_balance.adjust` through a private balance-specific authorization helper. Posting selectors require `leave_balance.adjust`. All still verify the active Tenant, Membership and confirmed non-banned User. Historical reads remain available after People/Leave entitlement closure; selectors report `can_post=false` with a concrete reason when current Employment, Employer or new-work availability prevents posting. General People/configuration authorization is unchanged; contact, compensation and User-profile data are not exposed. Public RPC execution is authenticated-only and both private helpers remain revoked.

## Preserved command boundaries

These RPCs only read. Existing `leave_post_balance` remains authoritative for active current Employment, Employer/type/period scope, finite two-decimal amounts, exact retry/conflict behavior, serialized underflow checks and disabled-new-work denial. Both retained one-opening and one-annual-grant indexes use account identity; a policy-version change creates neither another account nor another grant. No expiry, annual amount calculation or statutory entitlement recommendation is added.

The current posting command permits an inactive configured Type if its tracked policy version is otherwise eligible. The selector exposes its active status and mirrors that existing behavior; this slice does not establish or fix an inactive-Type posting policy.

## Executed local evidence

The migration was applied through the normal CLI chain to the isolated fresh and source-clone upgrade databases. The fresh application schemas and migration ledger were then rebuilt and all 104 migrations replayed normally, with no manual function repair.

The focused file contains 62 assertions covering adjust-only/view-only access, optional Employee User accounts and absent balance accounts, bounded paging and literal search, cross-Tenant/pair/account denial, full ledger sums, actual approved consumption and cancellation/correction provenance, policy-version/grant uniqueness, underflow, historical/disabled reads and command denial, and authenticated/anonymous/service-role execution grants. The complete 37-file Cube 3, Attendance and People group contains 1,526 assertions per database.

External evidence is saved under the isolated run directory: `slice18-fresh-full-chain.log`, `slice18-fresh-clean-gate.log`, `slice18-business_platform_cube3_approval_upgrade_qa-gate.log`, per-database test summaries and `slice18-function-data-comparison.json`. The comparison checks exact function definitions/ACLs and the source-clone's original 5 Employees, 4 Employments and 2 User links.

The SQL/test draft had an independent read-only reviewer; root ran the local gates and added execution-permission assertions. This is backend support for the next HR balance interface. No browser/UI qualification, complete Cube 3 closure, remote migration, deployment or main merge is claimed here.
