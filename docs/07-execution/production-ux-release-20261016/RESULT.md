# Production UX release — 16 October 2026

Owner explicitly authorized production publication after the development goal completed. Published application source: `e8abd14c27965ee8fb0eddd8d060511843ef6867`, branch `codex/operator-company-ux`. No merge into main.

## Live identity

- URL: https://platform.delight-world.com
- Vercel project business-platform-production / prj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa, team_AYQTvxuQJ1EepKxDVhzjX1ew.
- Deployment dpl_8xirHgiQrSNcvLyppz8TaKAfJzm1, business-platform-production-komi3hy2n.vercel.app, production READY, dub1.
- Staged production build used cloud production settings; no local QA build or .env.local uploaded. First --skip-domain, then explicit promote after migrations/checks. Live domain lookup returned the expected deployment and Git/source metadata SHA above.
- Supabase business-platform-production / msryvzefjdqjcfikerne, organization pchajhscmbfswwvgeifl, eu-west-1, PostgreSQL17.11. Project ACTIVE_HEALTHY. No paid-plan change.

## Database safety and migrations

Verified all214historical migration hashes match the existing launch manifest. Saved fresh schema(2,165,092bytes) and data(105,413bytes), with SHA256 manifest, in the protected external release/backups folder outside Git/OneDrive. These are local snapshots, not managed daily backups or restore certification. Data-only dump warns of circular constraints; any restore must be planned on an isolated target, never replayed casually against current production.

CLI setup recovery: old config had only linked-project.json, no legacy project-ref. Recreated an explicit isolated config/link to the verified production ref and its IPv4 pooler. Copied required email-template files and used absolute dump destinations. No database password reset, access weakening or paid IPv4 add-on. Backup completed successfully before applying migrations.

Dry-run listed exactly these four reviewed migrations; apply succeeded preserving original version IDs. Final migration count218:

1. 20261016012154_attendance_source_setup_lookup.sql
2. 20261016020006_payroll_configuration_workspace.sql
3. 20261016030516_leave_settings_entry_context.sql
4. 20261016033425_attendance_month_calendar.sql

New read functions verified STABLE, SECURITY DEFINER with empty search_path, authenticated execution and no anon execution. Existing read authorization remains. Read-only authenticated checks returned one mobile lookup branch, one leave employer and one calendar day. Tenant count1/user count3 unchanged before/after. No invitation, employee, attendance, leave or finance submission made during release checks.

Payroll read smoke correctly rejected the selected company admin with42501/payroll_forbidden. Follow-up confirmed that membership has no payroll.view/payroll.prepare/payroll_config.manage permissions; the live company menu likewise excludes payroll. This is an access boundary, not a passed authorized payroll journey. No permissions were granted for testing.

## Verification

- Remote build completed compilation, TypeScript and static generation; deployment READY.
- Protected stage login fetched using authenticated Vercel CLI; login form present. Global --scope was incorrectly forwarded to curl in the first two attempts; plain project-linked vercel curl succeeded. No security protection disabled.
- Vercel sensitive environment values cannot be retrieved via env pull/decrypt here: returned empty values are not proof actual cloud values are absent. We did not overwrite them. Actual existing authenticated company session loaded the new live screens and current Supabase-backed data after promotion, demonstrating the working connection. Production environment file remains private external; no values entered in report.
- Live HTTPS login, HTML manual, PDF and service worker return200/correct content types. Downloaded guide HTML exactly matches current source. Service worker has no-store/no-cache. HTTP results in http-smoke.json.
- Existing company-admin browser session refreshed the live leave hub: recorded calendar/year/type and opening-balance next step visible. Live month calendar showed October2026, today16October and one approved saved work instance. Screenshot shows this actual production UI; no populated-state fabrication or permission changes.
- Prior UX/local acceptance remains in final-ux-coverage-20261016. Release smoke is representative, not every-route, physicalGPS, account activation, financial/statutory or load certification. User trial remains the next action.

## Recovery

Previous live deployment: dpl_gzeZfTi9jDRpJyHshRjsBg62v9ya / business-platform-production-kz0umdj04.vercel.app. If required, use an explicit Vercel rollback to that deployment and verify the domain. The four migrations are compatible read additions/extended setup response; an app rollback does not require destructive schema reversal. Preserve backups, operation logs and release metadata. No rollback was needed.

## Storage

All CLI output/config/backups outside OneDrive. Existing local preview/QA databases and source are untouched. Retain protected backups and compact release receipts; copied migration intermediates can be removed after exact hash comparison against source. No global caches, Docker reset, unrelated projects or old rejected cleanup targets touched.
