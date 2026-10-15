# Company S0: explicit financial authority and stale-safe work access

Implemented B1/B1b from the frozen complete Company specification. Two explicit work bundles expose existing payroll finalization and export permissions, without granting preparation or approval. Neither is assigned by default. The protected company-administrator role, unrelated custom roles, tenant/actor/target checks, transaction lock and before/after audit remain intact.

The maintained three-argument API remains compatible. The interface uses a four-argument overload carrying its observed work-bundle selection; a stale editor cannot overwrite a newer selection. Input limits derive from the authoritative catalog (SQL) and extracted UI catalog (27 entries), with null/blank/duplicate validation. Existing grant implementation is preserved through exact-once migration anchors that fail closed on unexpected definitions. PostgREST schema reload is included.

Validation on the owned synthetic QA project `business-platform-operator-ux-20261015` only:

- New focused pgTAP: 31 assertions PASS, transaction rolled back. Covers exact new permission sets, execution grants/private catalog denial, stale/invalid attempts, cross-tenant and unauthorized actors, inactive target, catalog bounds, unrelated/protected role preservation and legacy compatibility. A finalizer still cannot finalize an unapproved synthetic run; no final financial output was fabricated.
- Existing work-bundle suite: 41 assertions PASS, transaction rolled back.
- Error-level database lint for application schemas `public,platform_private,platform_core`: exit 0. Broad extension lint includes pgTAP temporary-table diagnostics and is not represented as globally clean.
- TypeScript, focused ESLint and one coherent production build: exit 0. Git diff whitespace check: PASS.
- Actual authenticated normal UI grant and revoke on Company05: work count 4 → 6 → 4. Independent real Auth/member snapshot and effective permission reads verified finalization/export on grant, both absent after revoke, preparation/approval absent throughout, original four work bundles and protected administrator preserved. External compact receipts: `qa/s0-role-granted.json`, `qa/s0-role-revoked.json`.
- Representative 1366px authority-editor image retained externally: `evidence/company-s0-financial-authority-1366.png`. This proves capability availability, not final users-page UX acceptance; the full access-sheet redesign remains S3.

No production data, deployment or merge. Full Company scope remains open through S1-S9 and independent Claude acceptance. All work, active dependencies, build output, QA and evidence remain outside OneDrive. Active QA/dependencies/build cache and compact verification evidence are retained for the ongoing goal; no obsolete disposable output identified in this slice, reclaimed bytes 0. Terminal Company-spec streams await receipt compaction before removal.
