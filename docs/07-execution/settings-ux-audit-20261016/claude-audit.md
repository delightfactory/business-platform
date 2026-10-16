I've used 5 of the 12 tool turns and am writing the report now. I couldn't save it to the plan file because no write tool is available in this session, so the full report is below.

# Attendance, leave and payroll setup journeys: read-only UX audit

**Basis:** source at HEAD 3594817, the migration lines 170–225 you named, and the 6 provided images. I made no edits and ran no commands.

**Visual verdict: NOT VISUALLY VERIFIED** beyond these 6 images. No route is certified, and no visual fidelity to Concept C is accepted. This is a heuristic expert review, not user research.

## 1. Ranked findings

**F1 (critical): failed saves look like neutral info and don't say which field is wrong.**
- `ChannelForms.tsx:22` always renders `Message tone="info" role="status"`, whatever the result. Failure looks the same as "saving…" and as success, and that is the pale-blue panel in `attendance-failure-local.jpg`.
- `actions.ts:32` turns every Postgres error except `42501` into one message: "check fields/period/site". The source form has no period field, so the message even points the user at a field that isn't there.
- The database rejects these cases with `22023`, all with the same text:
  - name shorter than 2 characters after trimming (the client sets only `maxLength`, `:31`);
  - reason that is whitespace only (HTML `minLength=3` counts the spaces);
  - a site that is inactive or was deactivated after the page loaded (`migration:209`);
  - an invalid config combination (`:170-185`).
- If "receive new recordings" is set to "enabled" while the `hr.attendance` entitlement is off, the database returns `42501`. The user then sees "your permission changed or the service stopped", which reads like an account problem rather than "save it disabled, or ask for the service".
- **Reinforced:** Codex's repro shows the problem class. Which cause hit the owner is still unknown.

**F2 (high): the attendance source form asks for every decision at once, in the wrong order and in technical units** (`attendance-mobile-geofence.jpg`, `ChannelForms.tsx:31-37`, `location-picker.tsx:66-72`).
- **Order:** name comes before site and method, so the user has to make up a name before the choices that would naturally produce it.
- **No defaults:** "receive new recordings" (`enabled`) has no default even on create, so it's another required decision. Saving disabled is a valid way to stage a source, but the choice is never explained as "start now or later".
- **Retention in seconds:** retention is a number of seconds between 60 and 2,592,000, and the help text needs an arithmetic example. `max_age_seconds` is also in seconds.
- **Coordinates panel:** it opens by default on create (`open={latitude===undefined…}`), so lat/lon look like extra required typing even though clicking the map fills them in.
- **Map has no location context:** it centres on Cairo at zoom 5, ignoring the chosen site. The site record isn't used for the location.
- **Tuning shown with basics:** tolerance, accuracy and maximum age sit at the same level as the core location decision.
- **Wrong hypothesis:** "14 typed values" is wrong, as Codex noted. Map/GPS fills lat/lon, so on create there are 12 controls the user must actively decide.

**F3 (high): site search and site selection are two separate controls on the page.**
- `new/page.tsx:9` renders a GET search form *outside* the main form. Submitting it reloads the page with `?q`, which **throws away anything already entered in the source form**. That is lost context.
- The "first 20 results" hint shows even when there is only one site, and that site still has to be picked by hand.

**F4 (medium-high): the payroll config link silently opens the latest stored future period.**
- From setup, "إعداد البنود والسياسة" (set up items and policy) passes `period=''` (`setup/page.tsx:41`).
- `inputs/page.tsx:40-41` then sets `period = periods[0]` and redirects there. On the rendered evidence `periods[0]` is the newest stored period, which is why you saw January 2027 on 2026-10-16. I'm inferring the sort order; I didn't read it.
- Company-level component and policy setup is placed under a period selector and a "مراجعة الفترة" (period review) button (`payroll-company-config-local.jpg`). The page doesn't explain whether those components belong to the company with effective dates, or to the selected period.
- **Unknown:** whether component and policy records are really period-scoped in the database. That decides whether this is a display fix or needs a spec amendment.

**F5 (medium): payroll setup doesn't put its main task first** (`payroll-setup-local.jpg`, `setup/page.tsx:36-44`).
- Employer search shows even when the URL has `unique_employer`.
- About 10 period cards (12 per page in code), each repeating the same sentence, push "next period to create" and the primary "create period" action to the bottom of a mobile page.
- The readiness panel mostly says what this page *did not* check.

**F6 (medium): leave setup is mostly continuous already, so the hypothesis is partly wrong.**
- After creating a calendar, year or type, the user is sent back to the hub (`actions.ts:80,169,225` → `?state=…-created`), and `nextLeaveSetup` (`rules.ts:79-84`) shows one primary next step. So "calendar → return → year → return" is really an automatic redirect plus one click.
- **Real gaps:**
  1. **Employer list:** the list page (`leave/settings/page.tsx`) doesn't skip ahead when there is only one employer (`leave-settings-entry.jpg`), unlike payroll's `unique_employer`.
  2. **Opening balances:** the final step links to `/leave/balances` *without employer context* (`[employerId]/page.tsx:104`). The user then searches again for employee, movement type, period and leave type.
  3. **Hub doesn't summarise progress:** it never shows a 3–4 step progress summary, only the next missing item.

**F7 (medium): Time navigation mixes daily work with rarely used setup.**
- `navigation-model.ts:9` orders the tabs attendance, review, leave, balances, sources, settings. Two setup tabs sit among daily tabs.
- Work-policy templates live under People.
- Nothing tells the user "employees can now record" or "leave requests can now use balances".

**F8 (low-medium): the attendance and payroll images appear clipped on the right in RTL** (headings truncated, e.g. "…ة تسجيل حضور"). This may be a screenshot-stitching artifact. **Unknown:** it needs a clean viewport capture before it's treated as a layout defect. The leave images are not clipped.

## 2. Current flows (from source)

- **Attendance source:** Time tab "attendance sources" → list → "add" → page with search (separate GET form) + source form (name, method, site, enabled → geofence, retention → [map, radius, lat/lon, tolerance, accuracy, max age, failure action] → reason) → submit. On success, go to the detail page. On failure, a generic blue status with inputs kept. Unknown result: "verify before resubmitting". The success screen doesn't show "who can record next".
- **Leave:** settings → employer list (even with one employer) → hub → next step (calendar → redirect to hub) → next step (year → hub) → next step (type → hub) → "review balances" → `/leave/balances` with employer context lost → employee search → movement type → period → type → amount.
- **Payroll:** setup (employer search, card, 3 anchors, period cards, readiness, generate/change cycle) → "set up items and policy" → `/inputs?mode=config` silently redirected to `periods[0]`.

## 3. Recommended navigation grouping

Your hypothesis is confirmed with one change: **keep the existing tabs as entry points.** Don't add a global admin section.

- **Time tab order:** put daily tabs (attendance, attendance review, leave, balances) before a visually separate "Setup" group (attendance sources, leave settings) at the end. Use the existing `ordered`/`timeOrder` with group metadata, and keep only server-authorized links.
- **Setup readiness block:** add one block on the existing time and payroll overviews, built only from data those pages already load. Each row says configured / missing / no permission and deep-links to the right route with employer context.
- Show "no permission" rows to the actor without creating any new authority. Work-policy templates stay under People but get linked from the attendance readiness row.

## 4. Task flows to build

**A. Create attendance source (actor: HR or attendance manager; job: let employees at a site record attendance)**
1. **Where and how:** pick the site first, auto-selected when there's one, with search inside the same form so entries aren't lost. Then pick the recording method.
2. **Name:** proposed as "{method} — {site}" and editable, with client validation of 2–100 characters after trimming.
3. **Location and privacy:**
   - Choose whether location checking is required.
   - Map centred on the site's coordinates if the site has them; otherwise on the device location when the user asks. Lat/lon fields collapsed after a map pick.
   - Radius in metres.
   - **Retention entered as number + unit (minutes/hours/days)** and converted to whole seconds, keeping the database rules (60 s to 30 days, integer). No default value.
   - Failure action.
4. **Advanced tuning:** tolerance, accuracy and max age go in a disclosure that **opens automatically and shows an error summary if any required field there is empty or invalid**. Still required, no silent defaults. Max age gets a seconds/minutes unit.
5. **Review:** a short summary, then the explicit choice between "start receiving now" and "save stopped", then the reason (still required).
6. **Result:** a real success state. If `enabled=false` or the entitlement is off, say so. Next step: whether employees need a work policy or site assignment before they can record. Use existing readiness data only; don't invent rules.
7. **Failure and recovery:**
   - `tone="bad" role="alert"` for errors, `success` for success, a distinct `warning` for an unknown result.
   - An error summary that moves focus to the summary and links to each field.
   - Map known database reasons to the field (name, reason, site inactive, config) using client pre-validation that mirrors `validate_channel_config` and `migration:205,209`.
   - A distinct entitlement message for `enabled=true`.
   - On an unknown result: keep "check the log before resubmitting", block automatic retry, and add a link to the list.

**B. Leave first-time setup**
- Skip the employer list when there is one active employer, matching payroll's `unique_employer` pattern.
- Hub shows a 4-row progress summary: calendar, year, types, optional opening balances.
- Create forms keep redirecting back to the hub.
- The balances link carries the employer, and the leave year or type if one is unique.
- Routine editing stays the current hub. **Don't build a universal wizard.**

**C. Payroll configuration vs period work**
- The config link should never silently choose a period. Either use the period containing today, or show an explicit choice that names it, e.g. "latest stored period: January 2027 (future)".
- Label clearly whether components and policy are company-level with effective dates or tied to a period.
- On setup:
  - hide employer search when there's only one employer;
  - move "next period" and its primary action above the stored periods;
  - collapse older periods.

## 5. Preserve (don't regress)

- Required audit reason.
- Version history (`channel_source_versions`).
- Read-only name, kind and site on edit.
- Advisory lock and re-check of authority.
- The "verify before resubmitting" guard; no automatic retries.
- Entitlement check.
- No invented GPS or retention values.
- Leave calendar → year → type order and effective-date versioning.
- The leave hub's next-step panel.
- Payroll period authority, period validation (`validatePayrollPeriod`), locked history, and the open-run/attendance blockers before a calendar change.
- Disable-only form.
- Offline guard.

## 6. Display-only vs needs a spec amendment

**Display/client-only (no behaviour change):**
- Message tones and roles.
- Error summary and focus.
- Client checks that mirror the database (trimmed name length, trimmed reason length, ranges, integer retention).
- Field order.
- Search kept inside the form, or single-site auto-selection.
- Coordinates disclosure closed after a map pick.
- Advanced disclosure that opens on error.
- Retention unit converter that sends identical seconds.
- Tab grouping.
- Single-employer skip for leave.
- Employer kept on the balances link.
- Payroll setup ordering.

**Needs an amendment or decision recorded in issue #47:**
- Server action returning structured error *codes* (it changes the action contract). The database already raises distinct messages (`channel_config_invalid`, `channel_site_invalid`, `channel_entitlement_disabled`), so this needs no database change.
- A proposed default name.
- Map centred on site coordinates, if sites don't store coordinates yet.
- Readiness map semantics ("who can record next").
- Payroll config default-period rule and the company-vs-period labelling.
- Any default for `enabled`.

## 7. Acceptance scenarios and metrics

The baselines come from the observed source. These are not measured times.

| Scenario | Before | Target |
|---|---|---|
| New mobile source with location check, one site | 12 active decisions (+2 lat/lon fields shown open), site picked by hand, seconds units | ≤9 visible decisions before advanced settings; site auto-selected; 0 unit conversions by the user |
| Name of 1 character / whitespace-only reason / inactive site / entitlement off | generic blue status | red alert, focus on summary, named field or cause, all inputs kept |
| Site search after partly filling the form | form entries lost | 0 entries lost |
| Unknown network result | guard message | same guard and no automatic duplicate; link to the list to verify |
| Leave first setup, one employer | 2 navigations before the hub; employer context lost before balances | 0 employer re-selections; employer kept on balances |
| Payroll config with no period | lands on the Jan 2027 period without saying so | period named explicitly, or the period containing today |
| Repeat admin (edit an existing type/source) | direct | no added steps (no wizard) |

Also verify at 390 px RTL and with keyboard only. Get Codex and Claude rendered verdicts per `design-reference-acceptance.md`.

## 8. Hypothesis checks

- **"Leave needs a continuous guided flow":** partly wrong. The flow is already continuous through redirects and the next-step panel. The real fixes are the single-employer skip, the employer handoff to balances and a progress summary.
- **"Prefill the reason":** not recommended. The database requires a reason of 3+ characters after trimming, and the audit value depends on a human writing it.
- **"14 required values":** too high. It's 12 active decisions.
- **Setup/daily separation within each module, no global admin section:** confirmed.
- **Payroll "silent latest period":** confirmed in source (`inputs/page.tsx:40-41`).

## 9. Unknowns

- The owner's exact failing input, time and company.
- Whether production `hr.attendance` was enabled at that time.
- Whether `tenant_sites` stores coordinates.
- How `payroll_run_periods` is sorted.
- Whether payroll components are company-scoped or period-scoped in the database.
- Whether the right-side clipping in the attendance and payroll images is real.
- The cause of the first payroll access-read failure.
- `/leave/balances` and the type/year/calendar forms are not rendered or read here.
- No production log evidence either way.