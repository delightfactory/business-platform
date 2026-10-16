# Owner-authorized test reset and Arabic workforce import

## Scope and result

- Owner requested a single production test-data reset before their own operational test, retaining only the original operator. The later final launch reset is a separate future action.
- Verified target: `business-platform-production`, Supabase `msryvzefjdqjcfikerne`, Europe `eu-west-1`; application `platform.delight-world.com`, Vercel project `prj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa`.
- A guarded, transactionally rehearsed maintenance script cleared 130 explicitly catalogued application operational tables with `TRUNCATE RESTRICT`. No schema, RLS, grants, migrations, Auth configuration, mail integration, or database reset was changed. Exact owner and inventory guards ran after locks. This is not an automatic migration or reusable production reset feature.
- Removed the single backed-up company logo through Storage API and the two identified test accounts through Auth Admin API. Revoked those accounts' sessions and removed company memberships. Retained the original operator account, password and full existing operator permissions.
- Verified final production counts: companies 0, memberships 0, employees 0, payroll runs 0, payment events 0, Auth accounts 1, Storage objects 0, Egyptian statutory pack 1, original active full operator grant 1. The reset script additionally verified all 130 operational tables empty and preserved statutory pack/version hashes.
- Free plan retained; no subscription change.

## Recoverability

Protected local exports live outside OneDrive in `C:/Users/DELL/AppData/Local/ai-dev-workflow/runs/20261016-production-reset/backups/`. Preserve this folder and its restricted ACL. It includes schema (public API functions and application/Auth/Storage/migration schemas), data and the logo. Data table headers, dump completion, sizes and SHA-256 were checked; a full isolated restore has not been rehearsed. These local exports do not provide managed daily backups or protection against loss of this disk.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| schema.sql | 2370286 | 159334735EA73991DB07AB8D690F6167C2A87B1F59F438ACAD0A61002A28B548 |
| data.sql | 3674224 | F19213A1D3A376AE4FEFC85DF0B56C78B23941EAF41228323FEA3574059B2BB6 |
| company-logo.webp | 32632 | 40A2C09EAFFADDB339D88EFFEC4D4F4E30D59B9A87F1CF83D67B99486606DACA |

## User-facing changes

- New-company setup defaults to 1 branch and 10 users in both invitation and existing-user flows. These remain editable commercial limits, not ten pre-created user accounts.
- Employee CSV download uses clear Arabic headers and a UTF-8 BOM for Excel. The server maps Arabic and legacy English names to the same canonical backend fields; mixed/reordered headers are supported. Unknown, missing, additional and duplicate columns (including aliases of the same field) are rejected before RPC.
- Rejection report headers are Arabic with the existing formula-injection defense. The report remains diagnostic, not an upload template. Data values such as `monthly`, `daily`, `true` and `false` retain their existing documented contract.
- Updated the Arabic manual, generated HTML and 37-page PDF. Rendered and inspected the import chapter. No employee import permissions, confirmation, tenant scope or database functions changed.

## Verification

- Focused parser/guide suite: 17 passed, 0 failed.
- TypeScript and production build: passed.
- ESLint on all changed code files: passed. Whole-repository lint remains blocked by pre-existing CommonJS require errors in two documentation/test scripts and existing warnings; no unrelated lint cleanup was attempted.
- Independent read-only review: PASS for reset scope/owner protection (after locking correction), Arabic mapping, compatibility, canonical payload, rejection and defaults.
- Production was deliberately left empty for the owner's next manual operational test; no new company was created during qualification.

Deployment identity and final storage cleanup are recorded in the companion delivery note after release.
