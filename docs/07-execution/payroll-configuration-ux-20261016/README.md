# Payroll configuration — accepted scope3b

The employer's component catalog and the tenant-wide day-count policy now have a dedicated settings page, independent of a payroll period. Existing configuration links redirect there. Operational employee inputs remain period-scoped. Base78ddc2d; final QA build`vi2r7EzDBcxaxG5VF4f_v`, localhost61193 with exact owned local DB56322. No production deployment, migration or payroll calculation/payment performed.

## User journey

Setup → configuration → add component remains two clicks; it removes the automatic period redirect and unnecessary period control. Baseline selected January2027 and defaulted a new component's start to2027-01-01 without an explicit date decision. New settings require an explicit date. Current component versions are shown as saved settings with activation and effective dates, rather than an approval draft that this kind cannot approve.

Editing creates a later version. The prior version/date remains visible, new start is blank with a localized minimum-date explanation. Open-ended date guidance accounts for frozen history; finite supported historical ranges are preserved and checked by the unchanged write API. One-time company policy is returned independently of component pagination and displayed read only after setting, including when viewed through another employer.

Actual save testing exposed a React remount issue: including revision in the editable form key erased the success state during server revalidation. The editable key is now stable. Successful save offers an exact saved-record view; its read-only key includes revision so values refresh. Existing attempt/signature, authorization, concurrency and unknown-result handling remain unchanged. Native configuration date inputs and functional field updates retain values across sibling edits and failed saves.

## Evidence and gates

- Actual QA component0279ab09-fbca-4d64-a136-015e8686074e has three preserved versions: Oct20/value125, Nov1/value150, Dec1/value160; inactive throughout. The third save result remained visible after revalidation. Its saved-record link showed actual Dec1, disabled visible date and no save button.
- Same-date validation produced a clear Arabic date message. Duplicate keydemo_bonus was rejected with date2027-01-01, key, value and reason retained; no extra revision was written. Saved versions and recovery snapshot included.
- Company policy was set once in QA and immediately rendered read only. Old mode=config/head link opened the scoped record. Validated original period, search and review return context were preserved; the return link reached the operational period.
- PostgreSQL pgTAP22PASS, all test fixtures rolled back: no-period read, original payroll reader/preparer access, finance-only/outsider/tenant/employer denial, direct head beyond first page, true has_more, literal search, global policy across employers, frozen minima per employer vs tenant and supported finite historical range.
- Date helper2PASS (civil date/year/leap boundaries, finite-range preservation); scoped lint PASS; Next build/TypeScript PASS. Write action is unchanged in Git. The actual loaded save wrapper/delegate was inspected: policy frozen-history protection already covers all tenant employers. This corrects the advisory plan's stale base-migration concern.
- Built UI inspected at1366desktop,390phone and768tablet; light/dark representative images. No horizontal overflow. Keyboard Tab reached search button and Enter returned the one matching component. Full keyboard/screen-reader or real-touch qualification was not run.
- Official Claude Opus5.5Medium99130682 independently returned ACCEPTED with no blockers after reading scoped code and viewing all three final images. Its report explicitly states tests/guide/CSS source were not run/read by it; those are parent evidence, not invented independent results.
- Guide HTML/PDF35A4pages updated; changed payroll section/page21 rendered/read. Inventory84page files=84rows, no missing/extra/duplicates. This is structural inventory, not acceptance of all84routes.

## Boundary and remaining work

The additive read migration20261016020006 was applied only to owned QA. Target deployment must apply the relevant3a/3b migrations before this frontend. Save RPC/action, financial locks/period validation, idempotency, grants and Free subscription were not changed.

Not run: live multi-user race; real browser accounts with reader/finance-only grants; live frozen-history UI; screen reader/real touch; payroll calculation/finalization/payment. Corresponding role/frozen read contracts have DB partition evidence, not full rendered-actor proof.

Optional next component/copy batch: direct list link from success summary; singular editor heading; stronger policy label/value spacing; simpler wording for open-ended dates/frozen payroll; remove redundant single-link header bar; alphabetical component ordering with a matching cursor. No need to rerun successful financial contracts to make unrelated cosmetic changes.

Next required workflow: leave settings unique-employer entry and preserved choice/history path; broader company/operator/self-service/day/calendar and remaining page families continue. Full goal is active.

Storage: work/deps/build/evidence outside OneDrive; active caches reused. Removed only one hash-identical owned duplicate brief after exact path/reparse/Git checks,5329verified local bytes. Kept its archived copy. Source, DB, backups, active processes/deps and previous rejected cleanup paths preserved; no cloud quota claim.
