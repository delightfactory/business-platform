# Release verification — 16 October2026

- Application source62f88b71b4b0dc7b8bc7b43ed119a2fb56c2209b, branch codex/operator-company-ux, pushed to origin. No main merge.
- Vercel business-platform-production / prj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa, team_AYQTvxuQJ1EepKxDVhzjX1ew.
- Remote production build passed: compilation, TypeScript, route generation. Staged with --skip-domain; then promoted same build dpl_gzeZfTi9jDRpJyHshRjsBg62v9ya, https://business-platform-production-kz0umdj04.vercel.app. Runtime dub1.
- Actual platform.delight-world.com inspect resolves to that deployment. Live employee/company sessions reloaded and link hrefs verified: employee topics self-attendance,profile,self-leave; company topics company,attendance,people,leave. Actual public guide loaded employee default with6matching headings and correct announced status.
- Live HTML HTTP200,131819bytes,SHA256 0EAB45604044E9BB6F0DEB0B3F83E45696B6BD5659F350A191F6552C90C27468; byte-identical to reviewed candidate.
- Live PDF HTTP200,477222bytes,SHA256 EC543794A7F17A900889E4471864411B6F3F4808FAFB98637C086761F0840CD6; byte-identical to reviewed candidate.34taggedA4pages, no blank pages; page9contains newly documented employee setup sequence.
- Supabase project msryvzefjdqjcfikerne retained Free. No migration, auth configuration, production secret or paid subscription change in this release.

## Actual security follow-up discovered by build

Cloud install audit reported7high advisories including development dependencies. A bounded npm audit --omit=dev check reported2high/0critical entries: next16.3.6(direct; suggested fixed version16.4.2) and source-map-js(transitive; fix available). These dependencies are unchanged from the previously deployed lockfile. No claim of exploitability assessment or security clearance is made. Updating the framework/resolver and qualifying affected behavior is a separate unresolved release-hardening item before real company data; do not run forced blanket upgrades or silently change the Next16runtime contract as part of document filtering. Free backup/restore readiness remains separately unresolved from launch.

## Storage completion boundary

Automatic approval review rejected the exact-file deletion command for7owned obsolete review streams/duplicate guide images, without a detailed reason. No deletion/retry/bypass performed;0bytes reclaimed. Those7files total2355058bytes, retained outside OneDrive in the external production-delight-uat-20261016 run. Compact accepted reviews and representative images are already preserved here. Active user trial dependencies/app, databases, backups, operation journals and unrelated projects were untouched. No new local server or dependency tree was started. This limitation does not change the live guide/journey result.

Review certificates apply to scoped guide delta and first-screen representative views, not whole-product acceptance, physical GPS or all HR edge cases. Source commit above is the deployed application; this release record is a subsequent docs-only commit.
