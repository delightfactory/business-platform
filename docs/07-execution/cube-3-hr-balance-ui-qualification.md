# Cube 3 — HR balance UI qualification

Qualified locally on 2026-10-01 against the balance-read backend introduced in
`b0cbaa1`; implementation base `d957333`. This qualifies the bounded HR balance
interface, not full Cube 3, annual entitlement calculation, or Payroll.

## Delivered workflow

- Authorized HR searches Employee code/name and chooses the Employer without
  requiring a linked User or access to the People interface.
- Accounts show the server's complete balance; ledger pagination does not
  recompute it from the visible entries. The ledger exposes signed quantities,
  reason, source, frozen policy provenance, and consumption/reversal references.
- Manual opening, annual grant and adjustment select a stored account period
  and Leave type. No annual grant or opening amount is calculated from hire date.
- `postBalanceAction` checks current authentication, `leave_balance.adjust` and
  new-work availability before calling authoritative `leave_post_balance`.
- The form retains its policy version, operation key and entered values in a
  session draft scoped to actor/Tenant/Employee/Employer/kind/period/type.
  A submitted attempt can retry unchanged after eligibility changes. A malformed
  saved draft remains preserved and blocks submission until explicitly discarded.
- Numeric-equivalent edits retain the same intent; meaningful payload changes
  receive a different key. Unknown outcomes keep neutral feedback and the saved
  attempt. Only the server action's returned account/entry IDs create a receipt.
- Starting a new attempt is explicit and asks the user to inspect the ledger
  before discarding an unresolved attempt. Successful posting offers the exact
  ledger link and an action to refresh the account list.

## Runtime evidence

The browser ran on loopback port 3304 against isolated
`business_platform_cube3_upgrade_qa` (104 migrations). No remote database or
deployment was changed. Synthetic records and fault helpers are outside Git.

| Journey | Observed result |
| --- | --- |
| Adjust-only role | Balance reads and posting choices available without People access. |
| View-only role | Balance visible, posting unavailable. |
| Ordinary adjustment | 0.25-day input survived reload; posting moved full balance from 4 to 4.25 and exposed the ledger receipt. |
| Lost response after committed annual grant | Scoped one-shot gateway forwarded a real successful RPC, then returned HTTP 502. The browser retained the 0.50-day attempt. Editing to equivalent 0.5 and reloading preserved retry despite the grant now being occupied. Retry returned the existing receipt; SQL proved exactly one 0.50-day grant and full balance 4.75. |
| Search pagination | 51 matching Employees: first page 50, second page Employee 051. |
| Account pagination | 51 accounts: first page 50, second page one. |
| Ledger pagination | Account contained 51 entries totaling 1.50 days; browser showed 50 latest entries and one older entry, retaining the full 1.5-day balance. |
| Period/type pagination | 51 periods and 51 types. Selected period 2050 and type 051 from second pages; the final form retained both names. Period cursors now survive type next/first pages, selection and cancel. |
| No User account | Employee 051 initially had no balance. HR posted opening 0.5 through the actual form; browser ledger showed it, SQL proved one 0.50-day entry and zero Employee↔User links. |
| Disabled People + Leave | Historical accounts and 50 ledger entries remained readable. Fresh posting was disabled. Both original entitlements and all seven role assignments were restored exactly. |

Responsive checks at 390, 820 and 1280 pixels found no horizontal overflow on
the ledger. Phone screenshots were visually inspected for the ledger, opening
form and successful receipt. Prior responsive receipt checks covered the same
three widths. Controls and RTL content remained readable.

## Engineering verification and limits

- Final source passed `npm run typecheck`, `npm run lint`, and `npm run build`.
- Whitespace checks passed; Git reports the existing Windows line-ending warning.
- An independent read-only reviewer found no remaining source blocker after the
  type-retry links were corrected to preserve the selected period/type/cursors.
  Browser and gate execution were performed by the coordinating agent.
- This UI-only slice adds no migrations. Earlier backend fresh/upgrade regression
  evidence remains in `cube-3-hr-balance-read-qualification.md`; it was not rerun
  as a full database suite for this interface slice.
- Opening-specific lost-response injection, vanished-policy replay and corrupt
  draft recovery were source-reviewed, not exercised as separate browser cases.
  The committed annual-grant replay is the actual after-commit runtime proof.
- Automatic legal annual entitlement, joint Leave/Time correction, fractional
  absence attribution, reports and full Cube 3 qualification remain open.
