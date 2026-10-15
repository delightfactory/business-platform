# Atomic service contract checkpoint

`20261015012611_operator_service_switch.sql` implements the approved five-service desired-state contract. Inputs and the five expected revisions are bounded and validated. The authenticated commercial Operator is checked before and after the existing tenant advisory lock90427. Tenant existence, affected current/future conflicts, exact desired-state reconciliation and stale expectations precede writing. Attendance remains outside the People dependencies.

Payroll, Leave and Employee Finance are closed over People in a single approval plan. Added prerequisites, dependent denials and shortened dependent deadlines require a fresh user approval. Every affected sibling and People is checked. A corrupt descendant cannot be used to derive a parent plan. No generic plan engine or attempt ledger is introduced.

Ordinary switches use automatic provenance with a NULL reason; notes are optional and separate. One plan ID links all changed rows/audit events. Unchanged members of an approved plan do not receive redundant rows. Original RPCs retain mandatory reasons and the honest legacy provenance default. Historical audit entries remain immutable. Lifecycle/team/statutory safeguards are unaffected.

Denials capture the allocation before the grant row is closed. A resume preserves the exact deadline, including microseconds; elapsed allocations and legacy ambiguity require a duration choice. Temporary denials remain supported. Inclusive dates use Cairo server time. Exact deadline echoes are validated against current/resumable/parent-derived instants, including explicit NULL handling; they cannot manufacture a new deadline.

## Plan serialization for D3

Returned plan entries include `duration`, `valid_until`, inclusive display `last_day`, and `derived`. Preserve the original explicit duration input when that entry is unchanged by closure. Derived entries use `exact`. When confirming, submit `last_day` only for duration `last_day`, and `valid_until` only for duration `exact`; presentation dates are not second duration inputs. This lets an original user-selected date survive approval without inventing a signed-plan framework. Submit the current expected snapshot only after the user approves the displayed plan. A changed plan replaces the sheet and needs approval again. Transport failure must never trigger an automatic resend.

## Evidence

- New service pgTAP suite:33 assertions PASS, rolled back. Covers initial dependency approval, all three dependent deadlines, ordinary OFF/ON, exact timestamp rejection including NULL widening, stale state, denied authority before unchanged, legacy uncertainty, expired grants/temporary denials, today/yesterday boundaries, sibling future/conflicting rows and whole-plan rollback on the second audit insertion.
- Existing entitlement suite:29 assertions PASS after the final schema changes; legacy required reasons, evaluator denial and audit rollback remain intact.
- Real Auth/HTTP RPC on the explicit owned API:commercial manager received a two-service plan; outsider received42501. No service mutation was applied by this HTTP probe.
- Security advisors at error level:exit0/no issues found. Source whitespace check PASS.

The first development test exposed an ambiguous PL/pgSQL column and was corrected with a qualified column reference. A subsequent fixture accidentally selected closed historical intervals using transaction-time `now()`; its current-row selector now uses `clock_timestamp()`. These were distinct identified corrections, followed by a coherent final passing run. No production data or unrelated stack was used.

Migration was applied only to owned synthetic QA and recorded after validation. D2 backend contracts are implemented; D3-D7 UI, complete runtime/visual journeys and independent Claude acceptance remain open. Company-workspace redesign has not started. Keep active external dependencies/QA, concise gate results and unresolved maintenance evidence. No cleanup bytes are claimed in this slice.
