# Qualified payroll UX/foundation release — 2026-10-16

## Identity and authorization

Owner authorized development-branch push and production updates in this conversation; no main merge, subscription change, real payment execution, legal-pack issuance or statutory privilege grant. Source commit **ab2c48f03791b66ae34d63a2c1346b7f68086005** on codex/operator-company-ux pushed before release. Contains qualified S1–S4 plus earlier docs-only release receipt; git log from previous app e8abd14 confirms bounded scope. Later report-only commits do not change published source.

Vercel expected teamteam_AYQTvxuQJ1EepKxDVhzjX1ew/projectprj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa. New **dpl_7oT6JcqGvYZ8imYwKRLPDSbvEShC**, business-platform-production-ayheoouo9.vercel.app, production. Created --prod --skip-domain with --meta sourceCommit=ab2c48f03791b66ae34d63a2c1346b7f68086005. CLI initial message misleadingly says ready while INITIALIZING; waited for actual READY before proceeding. Source metadata independently read through authenticated VercelAPI because inspect/MCP projections omit custom metadata. Current https://platform.delight-world.com resolves this READY deployment after explicit promote, exit0. Old rollback deployment **dpl_8xirHgiQrSNcvLyppz8TaKAfJzm1** /business-platform-production-komi3hy2n.vercel.app preserved.

## Database

Supabase **msryvzefjdqjcfikerne**, business-platform-production, eu-west-1, Free retained. Applied via migration connector:
- 20261016111014 company_admin_service_authority_20261016
- 20261016111024 company_payroll_policy_versions_20261016

Ledger218→220. Original3S4functions matched QA baseline BEFORE DDL. Actual originaldefinitions+ACL captured outside repo in S4-production-original-functions.json and executable S4-production-rollback.sql; S1original permissionfunction in production-original-permission.sql. No historical/data rewrite. S1catalog28entries, protected administration/service dependencies preserved; no saved role copies.

Before/after counts identical: tenants2, memberships3, member_roles21, entitlements5, policy_heads0, input_versions0, final_contexts0, statutory_packs0. Current employee data/financial facts were not populated as part of a release. Function source hashes match qualified owned QA:
- save core57ce8aeadb0d176822f631c767f7e990;postgres-onlyEXECUTE
- producer9e4ad74e1b88076ff4943aef464311fa;postgres-onlyEXECUTE
- configuration554296e35e7a6362bebe43476631cc8f;postgres+authenticatedEXECUTE

Rollback if required: promote old deployment using Vercel, restore original permission predicate and3policyfunctions via a new documented inverse migration from captured actual source, preserving ledger/history and data. The unused private catalog can remain private; never delete operational rows to roll back. No rollback was executed or destructively rehearsed on production.

## Live acceptance and guide

Actual existing Delight company-admin browser session opened Payroll →choose Delight→setup, with editable dates/payday/timezone/reason and enabled 'معاينة التواريخ'. No 'needs another role'; no role/permission edits made through UI. No company form submitted, no period/policy/payment created. Evidence production-payroll-admin-access.png. This proves runtime inheritance/discovery, not complete company setup or legal financial readiness. Actual operator statutory UI was qualified in QA; production owner login/authority grant was not exercised or silently added.

Live published guide hashes exactly equal committed source artifacts:
- HTML143431bytes SHA256541F6F687A5E943BB29D81BEDD5A7596FDA8E321CCC4AC6DD4EB0066B7895BAA
- PDF501031bytes SHA256BA43DFDC52D571D60DA8D0A6984C3D1C86BC83A59CF35BFD0ACBEAD6A1AA4FC2

Additional bounded QA while cloud build ran: protected-base admin with0additionalroles created first company policy from actual UI in synthetic tenant9417bc11-9dc3-435e-bf08-edd40460e93b/employerc0b50fb3-1677-4be0-b3dd-1ce66b0fdb64. Initial redirect reached kind=policy and visible success/viewlink persisted after revalidation. Original start2026-10-01, reasonNONLEGAL S4first-create; local only. This closes the earlier root-runtime first-create limitation; it was NOT independently rerender-reviewed by Claude. Login initially landed on company chooser rather than assumed workspace button; corrected by reading visible state and selecting known owned tenant, no auth bypass.

## Remaining boundary

User will appoint the human payroll reviewer; no name, independent official expected outputs or signed attestation supplied. Prepared10case packet remains proposed inputs with blank expected outputs. Legal financial qualification/issuance remains blocked by actual existing rules, not marked complete. Next step requires the reviewer's results/provenance; no new broad UX redesign or repeated tests while awaiting them. Goal is not marked achieved. Preserve exact source/release/DB backups and unresolved recovery journals. Automatic rejection of prior obsolete-capture cleanup remains in force; no alternate deletion or disk/cloud reclamation claim. Active QA dependencies/previews retained for reviewer work; no blanket cache/database cleanup.
