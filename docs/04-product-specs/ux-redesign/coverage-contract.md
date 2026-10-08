# Coverage contract and reviewed corrections

Status: **Proposed**. This record controls interpretation of the preserved Claude contribution. Both original proposal and code are references; current source contracts govern behavior until an amendment is accepted.

## Denominators and traceability

Current reconciled structural candidate: 281 files under `src`, 75 page routes, 4 endpoints, 8 layout/loading boundaries, 107 server action functions including inline attach, 349 RPC sites (217 distinct literal names, 6 dynamic sites), and 1172 form/control source slots including native elements and known SubmitButton/Tabs.Trigger/Next Form/Dialog.Close/native summary/PolicyTask usages. **Controls include forms/buttons, not just editable fields.** Two request-boundary files outside `src` are separately fingerprinted: `proxy.ts`, `next.config.ts`. Do not add them to the source-file denominator without changing its definition. Source slots include shared control implementations and individual known composite usages; counts do not equal rendered control instances. The earlier 254/985 figures are historical. The profile checkpoint migrated five replaced native buttons to their corresponding SubmitButton uses and added 69 previously omitted/new usage slots as pending; all previous review statuses were retained. Current register denominator1717 is structural and not semantic/runtime acceptance.

Every inventory ID must have phase ownership and, before freezing its slice, operation-level scenarios or a justified not-applicable entry. Imported enums, conditional RPC choices, external-provider services, scope/navigation and browser storage must be reviewed manually; AST counts do not prove semantics. Expand all six dynamic RPC sites and valid input-kind/command combinations, including read/prepare/submit/reconcile paths. Do not infer that 107 functions means 107 operations or that 5 input kinds × 3 commands means 15 valid operations.

Each scenario must record: stable ID; inventory/source IDs and source SHA; actor and permission/entitlement; tenant/employer/period/record scope; initial state; entry path; user intent; operation/parameters; expected authoritative outcome; visible feedback; retained values/context; recovery/return path; test evidence; reviewer/status; justified exclusions.

Applicable result partitions: success, duplicate/unchanged, invalid values, unauthenticated/forbidden/actor changed, disabled entitlement/new work, stale/version/preview, contention, unknown result, confirmed closed-without-commit, external provider failure, missing setup. Add domain-specific partitions, boundary values, lifecycle states, expired/revoked/superseded identities, pagination and cross-scope attempts. Financial/security guarantees require exhaustive relevant branch coverage; pairwise sampling cannot replace those cases.

Three separate levels: (1) structural assignment, currently complete; (2) reviewed semantic cases for every applicable item/operation/state/actor; (3) executed cases on the exact implementation SHA with evidence. The latter two remain incomplete. “100%” means all items in a versioned, reviewed denominator and their applicable partitions; it cannot mean every possible input string. A source change invalidates affected inventory/scenarios and requires re-review.

Source fingerprints normalize UTF-8 CRLF to LF, making the inventory usable on Windows and cloud checkouts. Original demo/ZIP byte hashes remain separate and unchanged. Review-register IDs include source positions for same-line RPC calls; regeneration must explicitly reconcile existing review entries instead of resetting them.

## Corrections to Claude's draft

1. F7: no-store applies to matched application requests; `proxy.ts` excludes static/image/favicon/extensions. The three configured no-referrer invitation/member/employee callback pages are distinct from `/auth/callback`, which is separately inventoried. Do not infer identical no-referrer configuration on that endpoint.
2. F9/D12: `payroll/output/page.tsx:22` already labels export **“تنزيل كشف هذه الصفحة حسب صلاحية التصدير”** and retains the cursor. Preserve and test first/subsequent page semantics. This is not a missing-label owner decision. Full reports retain revision/completeness checks and 409/413 rejection.
3. B3: leave RPC fields are `can_manage`, `can_approve`, `new_work_enabled`; the adapter exposes `canManage`, `canApprove`, `newWorkEnabled`. Keep transport and adapter contracts distinct.
4. N/C/P/I/B numbers in the contribution are hypotheses, not measured baselines. Multiple navigation links do not prove repeated context selection. Measure before/after from the same start and goal, actor/data/device, including failure/recovery journeys. Do not suppress required fields, confirmations, denied states or reconciliation to improve metrics.
5. Location constraint concerns **client** persistence: MobilePunch keeps location evidence in memory and stores only attempt ID/scope. The server's bounded evidence retention follows existing policy; do not prohibit all server location storage by implication.
6. F6: zero memberships and failed/unusable membership responses can fall back to `/operator`; that redirect grants no authority. Preserve server/layout access checks and distinguish the cause in scenarios.
7. F8/D11: provider send acceptance, durable delivery recording and recipient receipt are three different outcomes. A record error does not prove email was unsent. Do not blindly resend on unknown recording state.
8. D15 is now source-verified: `AdvanceForm.tsx` uses scoped `localStorage`, `navigator.locks`, actor/tenant/employer validation, malformed-record blocking, and explicit reconciliation. Committed attempts remove the record; `closed_without_commit` retains values for deliberate new submission. There is no observed time-based expiry. Retention/privacy policy review remains open; never clear the journal as cosmetic simplification.
9. Diagram arrows back to finalize/payment mean **explicit user choice after authoritative resolution**, never automatic resubmission. Unknown attempts remain blocked and reuse their existing identity for reconciliation. `closed_uncommitted` and advance `closed_without_commit` are distinct source values.
10. New error boundaries, React.cache changes, contextual return links, drawers and Today/inbox are proposed behavior/structure changes, not already accepted CSS work. Specify their exact slice before implementation; cosmetic and behavioral gates must be kept separate.

F1/F2/F3/F4/F5/F10/F11/F12/F13/F14 were confirmed in targeted source review. Attendance currently opens the day during GET for authorized roles. Leave approval requires a reason of 3–500 characters (also enforced in SQL). Historical leave approval redirects to payroll correction; self cancellation uses its separate RPC. Deep-link allowlist expansion requires security review. Preserve 900px control breakpoint and server-authoritative payroll gates.

## Simplification acceptance

Measure N navigations, C repeated context selections, P competing primary actions **per state**, I required user inputs, B recovery steps. Include task completion, wrong-turn/backtracking and retained context; collect a defined rendered baseline before claiming improvement. One primary action is a state-level design goal, not permission to hide necessary operations. Preserve existing links/authority, source-required reasons, private data, financial atomicity and access-loss recovery.

Review normal and interrupted journeys at 390, 768 and 1366px; RTL, keyboard/focus, readable labels/errors, touch targets, loading/empty/error states and provider/reconciliation states. Cross-domain journeys X1–X7 retain explicit ownership, safe return context and terminal outcomes; revalidation is not proof the downstream business task finished.

## Freeze and acceptance gate

Before each slice: reconcile live source fingerprints; finish valid operation expansion; review every applicable scenario/control; resolve or explicitly exclude relevant amendments; measure baseline and define improvement target; review diagrams jointly with Claude; independently review security/financial decisions; owner freezes scope. After implementation: rerun applicable cases on the exact SHA, attach evidence, record deviations against Concept C, and independently accept the slice.

D7 (GET opening), D8 (deep links), D9 (inbox), D10 (breakpoint), D11 (delivery recording), D13 (fallback), D14 (font/radius), and D15 policy review remain proposed. D12 becomes preservation/testing. Original D1–D6 and backend gaps G1–G9 remain governed by their original references. Physical devices, privacy/biometrics, statutory qualification, capacity and field/vendor pilots remain separate open acceptance gates.

No full semantic review of 985 controls or full journey execution has been completed. This documentation establishes the work and the gates, not a closure certificate.

Management candidate reconciliation preserves all earlier review states and exactly migrates the work-policy activeflag submit. Native summary and PolicyTask usages are now explicitly inventoried; newly discovered source slots remain pending. More complete structural counting is not more executed coverage.
