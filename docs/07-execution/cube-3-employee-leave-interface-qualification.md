# Cube 3 — employee Leave interface checkpoint

## Scope

The bounded own-Leave surface adds balances and paginated history, a focused request form, and request details with withdrawal before approval. The shell exposes «إجازاتي» from the narrow access snapshot. Nested navigation selects the most specific section, so «ملفي» and «إجازاتي» do not both appear active.

Request details use `leave_my_request_detail`, which resolves the authenticated current Employee link in the database and requires `leave.self.view`. HR permissions do not widen this own-only route. The existing HR detail RPC retains its separately authorized scope. No browser-supplied Employee identifier is trusted; neither reader exposes salary fields. History remains available when Leave entitlement ends, under active Tenant/Membership and current-link authority. Request controls additionally require `self_can_request` and enabled new work.

The form preserves inputs and operation keys on unchanged retries/options reloads. It freezes editable controls while submitting, guards stale option responses and distinguishes calendar duration from Leave quantity. Ambiguous failures do not claim that nothing committed. Day breakdown is paginated at 30 rows, so the complete permitted 732-date evidence is reachable without a long rendered list. Approved and cancelled state labels are supported; cancellation actions follow in the next slice.

## Verification performed

- Root reran `npm run typecheck`, scoped ESLint over all owned TS/TSX files and both navigation components, and `npm run build`: successful. The external OpenCode author reported cost zero; its claims were independently checked.
- The focused request suite passed with **84 assertions** on application-fresh QA and the independent source-clone upgrade QA, each at 93 migrations. New cases prove own detail with an additional HR role, another Employee, another Tenant, unlink, relink and inactive Membership. One fixture initially used an unsupported membership state; it was corrected to the documented `inactive` value before the passing runs.
- Browser verification used the production QA build at loopback port 3300: options loading, server validation with retained input, unchanged options reload with the same operation key, submission/detail redirect, withdrawal/detail redirect, mobile navigation dialog open/close, and a successful Toast close click before automatic dismissal. The submitted synthetic request is `3beed260-5641-42f7-9f5a-70a7b6677c5e`, now withdrawn.
- RTL and absence of horizontal overflow were checked at 390, 820 and 1280 pixels. Mobile and desktop screenshots were inspected. Native date filling in the browser driver did not retain values; date input/change events were used on the UI controls. One attempted off-screen reload click was covered by the sticky header; scrolling back and repeating the real click successfully proved unchanged reload behavior. Neither failed attempt is counted as success.

Evidence is in `C:\Users\DELL\AppData\Local\ai-dev-workflow\runs\20261001-cube3-leave`, including `slice5-browser-verification.json`, `slice5-employee-leave-form-{390,820,1280}.png` and the QA TAP logs. The final manifest binds the checkpoint to its commit/tree and file/evidence hashes.

## Remaining Cube 3 work

This is an employee request/withdrawal checkpoint. HR configuration/review interfaces, cancellation and reversal, corrections, annual calculation qualification, half-day clock mapping, Attendance reconciliation, Payroll projection and complete final regression remain within Cube 3. Browser viewports do not substitute for physical device acceptance, which the owner deferred until deployment. No remote database migration, main merge or deployment was performed.
