# D1 shared shell and real access checkpoint

Scope: Operator only. Full Operator and company workspace acceptance remain OPEN.

Implemented:
- Removed20 duplicated topbars across11 existing page modules. Account/theme/sign-out remain in AppShell; the account menu retains the workspace entry. Detail pages retain a company-list return.
- Three old company-list routes redirect through one canonical helper preserving normalized search/page/state. Their reads use the existing authorized unified directory.
- Existing page authority reads share the same six request-local reads as the navigation/home. Active Operator status gates task reads. Existing guards, RPC arguments, same-company checks, actions, required lifecycle/team/legal reasons and backend definitions are retained.
- Corrected the commercial task name to services AND limits, and added the existing lifecycle stale outcome's missing message.
- Simplified the new directory's hierarchy. Each company row now really fills its clickable surface; mobile measured link356.8px within row358.4px (borders account for the difference), instead of the previously observed120.45px link in1164.8px desktop row. No numerical cross-viewport improvement claim.

Verification:
- Four focused authority behavior cases PASS after shared-read change; real workspace/server wrappers and external SDK boundary substitution.
- Focused ESLint PASS; TypeScript PASS; final coherent candidate build PASS after correcting an unknown-type status guard. No financial database suite run for presentation changes.
- Fresh isolated local Supabase through migration20261010003333,8 synthetic Auth users/26 companies. Real login/RPC permitted and denied list reads PASS for manager, commercial-only, lifecycle-only, onboard-only and outsider. No production or real-user data used.
- Browser: manager login → home search → one result → company services. Old commercial list with search and page2 → canonical directory,26 results, selected page retained. Only the shared shell is present.
- Browser: logout manager → commercial-only login. Navigation contains home/companies only, service page omits lifecycle link but retains limits. Direct lifecycle URL returns the denial page. This tests different sessions rather than reusing manager authority.
- Desktop1366 and phone390 renders inspected; phone document/content widths both390, five navigation entries fit. Representative version-bound images remain in the external evidence/d1-shell directory.

Codex: inspected directory and shell usability PASS for the cases above. Pinned-reference fidelity and independent Claude visual acceptance remain NOT VISUALLY VERIFIED/NOT RUN until the coherent Operator review. No complete D0 before/after metric set or D2 service mutation is claimed.

QA safety: six new containers only, actual published ports127.0.0.1 after correcting CLI's explicit wildcard binding; retired three stopped shells removed without volumes. Existing151-container baseline preserved before QA provisioning. Temporary Docker recovery is working; official4.95 update still awaits owner UAC. Do not label the maintenance issue permanently fixed.

Remaining: D0 comparable journey baselines; D2 service/limit contracts; D3 full company context, switches/dependency plans/durations/recovery; D4 unified creation/invitations; D5 team workflows; D6 statutory/comparisons/issuance; D7 independent acceptance. Saved search return across all detail tasks is still part of D3. Company-workspace redesign waits for full Operator acceptance.

Storage: external worktree/dependencies/caches reused; no sync-root execution. Essential source and gate results retained. QA retirement removed three unused container shells with all volumes retained; verified host reclaimed bytes0, no disk/cloud quota claim. Keep active QA, private recovery journals and previews for the ongoing goal.
