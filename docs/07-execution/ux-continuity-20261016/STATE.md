# Business Platform UX — current resumption state

Latest owner direction16Oct2026: finish current tasks then proactively improve the full design system, screens, components, main/sub navigation and complete journeys across company, operator and self service. No binding old design or ConceptC fidelity. Preserve business/security/tenant/financial/privacy/audit/recovery rules. Work directly in bounded economical batches, no speculative loops.

## Authority and identity

- Goal remains active; whole-platform work is incomplete. Heartbeat configured every30minutes as automation. Do not create a duplicate goal/automation or concurrent writer. Application/device must be available.
- Single writing worktree: C:/Users/DELL/AppData/Local/ai-dev-workflow/runs/20261015-operator-company-ux/worktree, outside OneDrive. Branch codex/operator-company-ux, origin delightfactory/business-platform. Commits/push approved for development branch only; no main merge or expanded production deployment authority. Supabase Free.
- Inspect Git head/status first. Latest completed commits before current3a:1c2315a automatic codes/recovery;87df860 navigation/help. Current3a acceptance is complete; inspect head for its final commit rather than repeat implementation.
- Local runtime Supabase56321/56322, exact container supabase_db_business-platform-operator-ux-20261015. Repo CLI config instead points legacy55322; **do not use default --local or --linked blindly**. Current new read migration manually applied only to owned56322. Production CLI link exists and must not be used for QA.
-61190 previous built QA preserved.61192 owned dev reused.61193 owned final3a candidate built in .next/qualification, buildSv7n9G5mVSi_R0yhoTgEu, exec session92130. Stop it before rewriting that directory. All env/secrets remain outside reports/briefs.

## Completed, do not repeat

1. Eight editable generated-code flows, SQL uniqueness preserved; payroll key format fixed to pay_lowercase. Actual save and duplicate recovery qualified. Attendance duplicate-source message/known-vs-unknown outcomes fixed. Independent Claude accepted. Evidence automatic-element-codes-20261016.
2. RTL desktop sidebar, daily/setup grouping, complete drawer, bottom navigation, authorized destination closure, quiet inline help, current-page resolution. Eight model tests, built/runtime proof and independent acceptance. Evidence navigation-ux-20261016.
3a. Attendance setup: method/branch first, existing active/stopped source direct link, inline search retaining draft/site, editable suggested name, human exact duration units, legacy stop preserved, server validation and additive tenant-scoped lookup. Actual create/edit/stop + geofence save proved. DB16PASS, unit2PASS, boundary harnessPASS, lint/buildPASS. Claude review983e84c0/delta7a6e3d26/visualclosuree6cb88d0 ACCEPTED after correcting stale-denied recovery and screenshot capture. Final images and limits in docs/07-execution/attendance-setup-ux-20261016. GuideHTML/PDF35pages updated. No production mutations.

Claude skills installed/validated in C:/Users/DELL/AppData/Local/ClaudeCode-Official-Pro/skills, actual reads verified. Use official claude-opus-5-5 --effort medium with bounded read-only design/review; brief instructs Read relevant installed SKILL.md (relay intentionally disables slashskills). Do not reinstall. No Claude process active after3a closure.

## Next exact actions

- Batch3b payroll: inputs/page.tsx configMode still uses period=query.period||periods[0]?.id and payroll_input_workspace(p_period), then filters mixed records client-side. Setup links mode=config with possibly empty period. Study RPC authorization, effective-date and version semantics; separate employer config from period execution with a narrow reviewed contract. Do not pick current month arbitrarily or drop period context from operational payroll.
- Leave: settings/page.tsx always lists legal employers before hub. Any single-employer shortcut requires authoritative global uniqueness, never one page/filtered result. Review balance/policy context and employee readiness journey.
- Complete remaining screen families and routes: people terminology (page H1 still الناس, nav الموظفون), operator controls, company administration, self service, attendance day/list/calendar, leave, payroll.83page-file matrix exists but not all pages have been visually assessed. Monthly calendar needs authorized batched data, no31dailyRPCloops or invented absence/totals.
- Keep guide role-sensitive and synchronized with actual verified UI. Representative desktop/tablet/phone and light/dark checks, bounded independent review, commit/push each accepted batch. Do not close goal until full scope and honest remaining-gap audit passes.

## Storage and testing rules

Use external run and active caches/dependencies.3a removed only an unused run-owned image,53165verified local bytes. No cloud quota claim. Preserve projects/source/assets/secrets/DB/backups/journals/active deps and prior rejected cleanup paths. Never global cache wipe or Docker reset. At final completion stop unused owned processes and prune validated owned obsolete output.

No arbitrary repeated tests: run relevant changed contracts and real success/recovery paths; broaden only for actual new concern. Keep unknown outcomes unknown and no automatic resend. At most two concrete source-fix cycles before reassessing; extra3a visual check cleared an identified capture artifact, not speculative code review.

Screenshot host issue: Playwright UI operations may reset host scaling while same-value viewport.set is cached. After UI actions, viewport.reset then set target width, readDOM geometry, rawPage.captureScreenshot(captureBeyondViewport:false); inspect actual image before sending review. tab.screenshot in this IAB produced distorted images. Reset viewport/theme afterward. Current tab18 retained for continuation; handles may expire after turn.
