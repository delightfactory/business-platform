# Attendance file import — 2026-10-19

## Scope and user journey

Owner rejected the 100-event file limit as unsuitable for companies. Attendance manager starts at Attendance → tools → import, chooses one CSV, reviews inferred column mapping, previews, and saves selected records. The application handles sequential batches and shows cumulative outcomes. Next step remains attendance-day review/approval. No employee-import capacity change, hardware auto-connection, payroll approval, new permissions, background job or paid subscription.

Before, the local production build rejected a 125-record file during header detection. After, browser parsing accepts up to100,000 data records/20MiB, while each authoritative server/RPC operation remains bounded to100 records. Only50 rows render per result page. UTF-8, physical source lines, explicit ambiguous-date choice, tenant/service/permission checks and source-key deduplication remain. Arabic and legacy English headers auto-map; mapping changes invalidate the preview.

Completed batches remain visible after pause/failure. A lost write response marks that batch uncertain; explicit verification re-previews identical keys before further writes and labels verified existing records separately from newly confirmed saves. Nothing auto-retries on reconnect. Progress lives in the current page only; after closing it the operator selects the original file again. No browser persistence of HR records and no claim of a durable resumable background job.

## Performance defect and bounded correction

An actual100-row browser preview exceeded the authenticated8-second database timeout. Local EXPLAIN measured about41.9ms merely enumerating pg_timezone_names for Cairo; the resolver repeated this for shift boundaries. The old pathological1,000-event same-employee/day transaction was canceled after about7minutes; a bounded200-event repeat timed out at120seconds. Both rolled back. Neither is reported as passed.

Migration20261018235309 skips only the redundant catalog membership scan for exact canonical Africa/Cairo using a nested PL/pgSQL IF. Every other/null zone retains the original catalog path; conversion, roundtrip gap rejection and the complete±180minute overlap check remain byte-equivalent. No cache, GUC trust, timing-window expansion, evidence interpretation shortcut or index changes. Production Cairo availability and the old function definition were read-only verified before release. Missing/corrupt canonical Cairo tzdata is outside the supported deployment prerequisite.

Independent critical Codex reviewer accepted this narrow correction and required nested IF plus timezone/ACL regressions. Other historical scan costs can still matter at high volume; no universal throughput or100,000-row end-to-end benchmark claim.

## Verification

- 20 focused Node tests passed: strict UTF-8/size,100,000-record parsing, legacy employee default100, Arabic/English mapping, cross-batch duplicate/conflicting keys, selection/date preservation across pages, sequential pause/offline/stale response handling, uncertain-response verification, malformed result stop and safe reject CSV.
- Existing56 attendance DB regressions passed after the resolver correction;9 new timezone/ACL tests passed (normal Cairo, spring gap, autumn overlap, other/invalid/null zones, no direct anonymous/authenticated execution).
- Real local authenticated RPC fixture:1,000 newly accepted events in10 bounded batches, repeat final100 all duplicates/no new events,101-row RPC rejected, privileged persisted count exactly1,000. Total14,588ms on this laptop, including pathological1,000 punches on one employee/day; transaction rolled back. A200-event trial took1,793ms. These measurements do not predict production throughput.
- Real browser/local optimized build:125 ready; save requested; pause settled after100 confirmed;25 remained; resume confirmed125 total. Re-open/reselect/re-preview same CSV:125 duplicates, no save action. Database count125 and distinct source keys125. Synthetic tenant444dbbab-b569-47ca-beae-2bacbce266c6 only; no production operational test rows.
- 390px responsive review exposed an inherited52rem table minimum and stale six-column labels. Scoped CSS now removes the mobile minimum and uses actual data-label values. Browser reports innerWidth390/document scrollWidth390; result cards/labels and keyboard focus inspected. Representative desktop/mobile captures retained externally. No physical-device or exhaustive theme claim.
- Focused ESLint, TypeScript and optimized Next build passed. No dependency/lockfile/global Next body limit changes.
- Guide section15 updated for file capacity, inferred columns, page/filter review, pause and explicit verification/re-open recovery. HTML regenerated;44-page PDF regenerated and inspected. All pages have text; no extracted characters outside page bounds; representative page18 visually inspected. Employee-import section still states its independent100-row limit.

## Review and release boundary

Codex independently reviewed Claude-authored implementation and applied clean-code/test guards. Official Claude Pro Opus5.5 Medium final source/rendered review is recorded separately when complete. Initial implementation relay reached its10-minute bound without a final report; its changed files were reviewed and qualified rather than treated as an accepted verdict.

Source/release identity and production verification are recorded in RELEASE.md after completion. All active outputs/dependencies remain in the existing external worktree and this task's LOCALAPPDATA run, outside OneDrive. Preserve recovery journals, failed/performance evidence and representative screenshots; never delete databases, volumes, source, assets or unrelated caches. Previously rejected cleanup paths are excluded from retry.
