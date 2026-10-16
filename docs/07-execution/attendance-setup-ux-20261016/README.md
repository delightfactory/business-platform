# Attendance setup — scoped acceptance

Base87df860; development branch codex/operator-company-ux. Final production-mode QA build `Sv7n9G5mVSi_R0yhoTgEu` on localhost61193. No production changes or main merge. The additive lookup migration has been applied only to the owned local QA DB; deployment of this code requires applying that migration to the intended target first.

## User outcome

- Choose method and branch first. An existing active **or stopped** phone source appears immediately with one primary action to its settings, before completing an unnecessary new-source form. Required policy controls remain available for a genuinely new branch.
- Branch search happens inline. It preserves the selected branch (even outside the search results), custom name, reason and duration. Newer responses win; errors retain last verified choices. Successful authorized retry clears a stale denied state. Writes still authorize independently.
- Retention uses an amount plus days/hours/minutes/seconds. New amount is blank; no privacy duration or GPS policy is inferred. Server conversion is exact and bounded. Existing values choose the largest exact unit; 3601seconds stays3601seconds. Legacy stop payloads retain canonical seconds.
- Editable suggested name never replaces custom typing; saved source identity remains immutable. Required audit reasons, GPS validation, write lock, DB uniqueness, version history, offline guards and unknown outcomes remain.
- Outcome messages are hidden only when truly empty; real loading, errors, uncertainty and success still appear.

## Evidence

Before (built87df860): GET branch search cleared name, kind, branch and reason. After: actual final-build inline search retained all those fields and amount/unit, no route change. These snapshots are evidence of that task, not of every possible form interaction.

Actual local UI saved Alexandria source `c959a7e3-ef82-470a-a0e1-aeeb9148d3f6`: version1 stopped86400seconds from1day, version2 active5400seconds from90minutes, version3 stopped5400seconds using the legacy stop form. Separate synthetic geofence source `a085ae52-ebd8-447c-9ab9-f4b95fdababc` saved explicit synthetic map values and3601seconds; edit showed exact duration. Direct existing-source link was followed to correct detail. These are training records, not real company changes.

Checks: scoped lint PASS; Next build/TypeScript PASS; retention node tests2PASS; server boundary harness PASS (conversion, legacy stop, validation, duplicate recovery, permission, unknown outcome); exact owned QA pgTAP16PASS (role grants, tenant guard, escaped search, stopped sources,20+has_more, exact site and invalid arguments). Migration and tests are tracked. No financial regression suite was needed because financial code is unchanged.

Important runner correction: repo config points CLI --local at legacy55322, while this run uses operator-ux56322. Two initial CLI tests aborted and rolled back on legacy local before persistent changes. Authoritative passing results ran via explicit docker exec into `supabase_db_business-platform-operator-ux-20261015`. Never use --linked for these tests.

Rendered: real390phone,768tablet and1366desktop sampled; light/dark views inspected. Final mobile metrics375scrollWidth≤390,scrollX0. Initial screenshots were rejected due IAB125percent capture artifacts, not accepted as product evidence. Explicit viewport reset+set before rawCDP resolved them. Final two phone files are the accepted build; desktop image is from the previous build before baseline alignment/hide-empty changes and supports the unchanged desktop shell only.

Independent official Claude Opus5.5Medium: design1fddd5b9; review983e84c0 required stale-denied fix; delta7a6e3d26 accepted code but rejected malformed captures; visual closuree6cb88d0 **ACCEPTED** the corrected screenshots and final empty-message change. Read-only verdicts distinguish code/image inspection from parent runtime tests.

Guide Arabic HTML/PDF updated to new route, inline search, existing-source recovery and human duration units. PDF35A4pages; section12 page12 rendered/read.

## Limits and next work

No actual live permission revoke/restore rendered test, real touch/screen reader, or simultaneous-browser creation race was run. Guard/role boundaries are DB-tested, denied retry is source-reviewed, and duplicate recovery is harness-tested; existing unique index/transaction lock are unchanged. Not every83route or role is visually certified. This batch is not whole-platform completion.

Next: separate payroll company configuration from period context (inputs configMode currently selects periods[0]); investigate authoritative unique-employer entry for leave settings; then broader list/calendar and other screen families. GPS form still contains explicit technical policy choices; further simplification must preserve privacy intent rather than fabricate defaults.

Storage: all raw output/deps/builds external to OneDrive. Deleted one owned unused intermediate image after exact path/reparse/Git checks, verified53165local bytes reclaimed; no cloud quota claim. Active dependencies, DBs, builds, source, accepted/unresolved evidence and previously rejected cleanup targets preserved.
