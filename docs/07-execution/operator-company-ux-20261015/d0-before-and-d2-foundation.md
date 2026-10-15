# Original journeys and duration foundation

The eight before journeys were observed once on `9a98ed8f1f7a1471efe60620182cf9d92d931b77`, using the owned isolated QA project and a synthetic Operator with all five tasks. Development restored `codex/operator-company-ux` before any product edit. These are before measurements, not acceptance of the redesigned Operator.

| Journey | User navigations | UI activations | Required manual fields |
|---|---:|---:|---:|
| Find company from home | 3 | 3 | 1 search entry |
| Enable payroll with People absent | 0 | 6 | 2 reasons |
| Disable ordinary enabled service | 0 | 3 | 1 reason |
| Reduce users limit below usage | 0 | 2 | numeric value + reason |
| Suspend and restore company | 0 | 4 | 2 reasons |
| Create confirmed-account company and reach services | 5 | 6 | 3 creation fields + separate search |
| Invite first administrator and follow status | 1 | 2 | company + email |
| Edit Operator tasks | 0 | 3 | 1 reason |

Search entry is measured separately from required business data. Navigations count user-initiated links and GET search submissions; automatic mutation result navigation/revalidation is excluded. Activations count links, disclosures, choices and submission buttons, with typing counted as fields. No timing benchmark or repeated measurement rounds were run. The machine/app restart did not repeat completed journey mutations.

Creation completed with default limits, but its result had no Operator service continuation. Reaching services required returning home and searching the new company. Invitation state was pending acceptance and recorded sent; that does not establish inbox delivery or create a company. Team permissions were restored to their original commercial-only state with a normal audited update after measurement. Lifecycle finished active. Company02 retains People enabled, Payroll denied through the legacy path, users usage2/limit1. Histories remain intact. After comparisons must use equivalent visible state and disclose any fresh-fixture mapping needed to avoid legacy-duration uncertainty.

The original duplicate page topbars were CSS-hidden. Their removal is DOM cleanup; it is not evidence of a visible before/after improvement.

## D2 first verified source slice

Migration `20261015011928_operator_entitlement_resume_metadata.sql` adds denial allocation metadata, a private resume helper and additive snapshot fields. Legacy values remain unknown; historical decisions/audits are not rewritten. The constraint explicitly rejects NULL kind with a non-NULL deadline. The helper cannot be executed by PUBLIC, anon, authenticated or service_role; the authorized snapshot remains the sole public read boundary.

Exact timestamps and inclusive Cairo dates are produced on the server. Existing evaluator behavior and all five services are preserved. The existing reason-required mutation RPC is unchanged. The new atomic mutation/plan contract, audit provenance changes and commercial limit editor contract remain open D2 work; the UI does not yet use duration metadata.

Applied only to the named owned QA database, then recorded once with the CLI migration repair command after verification. Current owned QA revision is `20261015011928`. No production migration or data mutation occurred.

Verification:

- New pgTAP resume/metadata/snapshot suite: 16 assertions PASS, transaction rolled back.
- Existing entitlement regression suite: 29 assertions PASS, transaction rolled back, including forbidden access and atomic audit failure rollback.
- Supabase security advisors at error level against the explicit QA workdir: exit0, no issues found. This is not a claim about warning/info-level pre-existing findings.
- Source whitespace check PASS. No application build rerun for this SQL-only slice.

Active dependencies and database containers remain needed by D2/D3. Retain concise SQL logs and representative before screenshots externally; no cleanup bytes are claimed for this slice. Full Operator visual/runtime acceptance and Claude acceptance remain open.
