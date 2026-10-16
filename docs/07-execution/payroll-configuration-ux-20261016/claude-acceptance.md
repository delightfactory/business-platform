# Batch 3b review: payroll configuration (independent, read-only)

**Verdict: ACCEPTED for this slice. I found no blockers.**

## What I did and did not do
- **Did:** read the four skills, `BATCH-3B.md`, the new configuration `page.tsx` and `navigation.ts`, migration `20261016020006`, the `InputForm.tsx` changes (lines 18–57), the `inputs/page.tsx` redirect (lines 25–28), `rules.ts` lines 9–23, the date helper, and the setup entry (I only found the import and call; I didn't read their surroundings). I viewed all three images.
- **Did not:** run the build, lint, pgTAP, the date tests or a browser. I didn't read `payroll.module.css`, the test files, the guide or `current-config-save-source.sql`. I accepted your correction about the save wrapper guard. I checked no unrelated financial flows, and I'm not claiming the full platform is accepted.

## Verdicts

**Task — PASS.** The manager now edits configuration in its own place, with no hidden period choice. Dates must be picked on purpose (`InputForm.tsx:28` leaves "from" blank when saving is allowed). The page shows the saved version and its dates (`page.tsx:72`). After saving, the user sees an honest message: nothing was calculated or paid (`InputForm.tsx:39`). Click count stays at 2. You didn't claim a reduction, and that is correct.

**Capability — PASS.** Viewers, preparers, approvers and managers can still read (migration lines 10–13). Only managers with the service enabled can edit (`page.tsx:60`). Readers get a clear "view only" or "service paused" message (`page.tsx:68–69`). The save action and RPC are reused unchanged. Operational inputs still require a real period: the type union is at `InputForm.tsx:20–21` and the runtime check at line 36. Old `mode=config` and `kind=component|policy` links redirect, and only allowlisted, validated parameters are carried over (`navigation.ts`). The old configuration screen is gone, so there is no duplicate.

**Simplicity — PASS.** The page has two tabs, one main action per state, a focused editor and a read-only record view. An existing company policy is shown read-only with no save button that can't work (`page.tsx:77`). The images match this: desktop list, phone policy, phone editor (dark).

**Recovery — PASS.**
- The edit form's stable key keeps the success message after refresh. The read-only key includes the revision (`page.tsx:74`).
- Date fields use `defaultValue`, `onInput` and functional updates, plus `onReset` with `preventDefault`. So a failed save keeps the entered values, which matches your duplicate-code test.
- A same-time policy save gets its own message pointing back to the saved policy (`rules.ts:10`).
- The page's failure states keep the URL and offer "retry" and "start over" (`page.tsx:26`).
- The return-to-period context is validated before use and never used as the configuration scope (`page.tsx:45–54`).

**Responsive — PASS on the three images only.** At 390 px nothing is cut off or crowded, and dark contrast is readable. You measured tablet; I didn't see a tablet image. Keyboard use, screen readers and real touch were not checked.

**Security — PASS.**
- The read RPC is `SECURITY DEFINER` with `search_path=''`. It reuses `payroll_input_access`, requires an active employer in the same tenant, and is granted only to `authenticated`.
- Head lookup is scoped by tenant, plus employer for components; policy is tenant-wide (line 39).
- `ILIKE` input is escaped and length-limited. Pagination asks for one extra row, so `has_more` is true only when more rows exist.
- The frozen-date minimums are advisory only: per employer for components, whole tenant for policy. Finite date ranges are left to the unchanged server check. That keeps valid historical ranges and doesn't weaken anything.

## Optional notes (not blockers)
1. **Success has no way back to the list** (`InputForm.tsx:39`). The tabs are hidden in the editor, so returning takes two steps: saved record, then "back". Fix: add a ghost `ButtonLink href={back}` labelled "العودة إلى بنود الراتب".
2. **Form heading is plural** for a single item: "بنود الراتب" (`InputForm.tsx:50`, from `kindNames`). Fix: in configuration mode, show "بند الراتب" for components.
3. **Policy facts look flat on phone.** The `dt` and `dd` items have the same weight, and the reason text runs straight into the following paragraph. Fix: give the `dl` a label/value style (weaker labels) and add space before that paragraph.
4. **Date help text uses technical words** at `InputForm.tsx:43`: "النطاق المفتوح" (open range) and "السجل المقفل" (locked record). Suggested wording: "إن لم تحدد نهاية، يبدأ من {date} أو بعده؛ إن حددت نهاية يتحقق النظام من عدم تداخلها مع رواتب مقفلة عند الحفظ."
5. **The bar under the header holds one button** ("إعداد رواتب الجهة", `page.tsx:67`), which repeats the breadcrumb and sidebar. Consider showing it only when it has the return or change-employer links too.
6. **Change employer drops the return context** (`page.tsx:67`, `?choose_employer=1`). That's acceptable, since a different employer makes the period invalid. Just noting it.
7. **List order is by internal ID, not name** (migration line 27). It is stable but looks random to users. Ordering by name would need a matching keyset cursor; leave it for a later batch.

## Remaining limits (as you reported; not run by me either)
- A real multi-user race.
- Browser runs as read-only and finance-only users.
- A live frozen-history UI.
- Screen reader and real touch.

The database role and frozen-date tests cover the matching contracts, but rendered acceptance for those actors is still open.