# Completion-gap audit (read-only, source only, NOT VISUALLY VERIFIED)

**What I read:** `STATE.md`, `BATCH-6.md`, `claude-design-system-v2.md`, `screen-matrix.csv`, and the installed `enterprise-workflow-ux`, `frontend-design` and `backend-ui-closure` SKILL.md files. For source, I fully read `operator/companies/new/page.tsx`, `ServiceManager.tsx` and `me/leave/page.tsx`. I grepped `me/leave/[requestId]/page.tsx`, the `me/leave` actions and the operator denied/failure branches. I did not read the other routes and looked at no renders. I didn't create the plan file because there was no write tool in this session. Nothing was edited or run.

## Closure matrix

| Owner requirement | Current evidence | Missing proof or change |
|---|---|---|
| Navigation: destinations reachable, nothing hidden | Batch 2 accepted (model tests, built proof) | None. Don't reopen. |
| Codes, attendance setup, payroll config, leave entry, calendar, people, member permissions | Batches 1–6 and 3a/3b/3c accepted, scoped | None for those batches. |
| No dead ends or unexplained denials (operator) | Source: `companies/new/page.tsx:13` and `:15` show a bare Banner inside `main.app-shell` with **no link out and no retry link**, even though the text says "أعد المحاولة". `limits`, `services` and `status` (`:15`/`:18`, `:21`/`:24`) have a link back to the companies list, but their "partial authority" message also says retry with no retry link. | **Genuine blocker (small).** Add a retry link plus a back link that respects the user's authority, matching the existing `ButtonLink` pattern. Not checked: whether `app-shell` here renders the operator sidebar. |
| Self-service journey is clear end to end | Not part of any accepted batch. `me/leave/page.tsx` shows balances and request history correctly. Errors, invalid page numbers and the read-only state are distinct. Submit and withdraw redirect to the detail page (`actions.ts:73`, `:109`), which shows a state-checked confirmation (`[requestId]/page.tsx:68-70`). | No rendered phone evidence for the employee family at all. Copy mismatch: the empty-state text points to «طلب إجازة جديد» but the button says «طلب إجازة» (`page.tsx:138` vs `:88`). The list page's `state=submitted\|withdrawn` notice (`:85-90`) can't be reached from the current actions, so it's harmless dead code. It's unverified whether the self-service-only employee's link «العودة إلى مساحة الشركة» (5 instances) goes somewhere useful. |
| Operator service management has truthful outcomes | `ServiceManager.tsx` handles unknown→locked→re-read, stale, no-op, derived plan confirmation and denial impact. This is strong. | None in source. Only representative render evidence (phone/desktop) is missing. |
| Design system: tokens/forms (plan item 2) and list/detail/empty/error pattern (plan item 3) | Applied piecemeal in accepted slices. Mixed classes are still in use (`secondary-button` / `empty-state` next to `ButtonLink`/`Message` in `me/leave/page.tsx:101-103`). | **Partial.** One consolidated shared-component pass is needed: legacy class wrappers, the `SettingsLink` className drop, the "الناس" vs "الموظفون" H1, and the retained 3c/4/6 optional notes. Cosmetic/consistency work, not a safety issue. |
| Representative rendered acceptance | Only batch-scoped images exist. The 15 Oct `DELIVERY.md` is historical. | Per family: one representative phone and one desktop render, light and dark, across the 15 families. Not 6 shots per route. |

## Bounded next actions (max 3, in order)

**1. Operator recovery closure (blocker, small)**
- **Actor and job:** an operator without onboarding authority, or whose authority check partially failed, tries to create a company or manage a company's services, limits or status.
- **Entry:** `/operator/companies/new`, or `/operator/companies/[id]/{services,limits,status}`.
- **Success:** they understand why it's unavailable and reach an authorized destination in one click. If the check partially failed, a retry link reloads the same URL with its context.
- **Choices:** retry or go back.
- **Failure and recovery:** an invalid `key` points to the original attempt, or at least to the companies list or invitations. Keep the onboarding idempotency and unknown-outcome rules as they are.
- **Next step:** whichever destination they picked.
- **Proof:** source diff, one built denied render and one built partial-failure render (phone). No authority or RPC changes.

**2. Self-service leave journey check and copy fix (needed for coverage, low risk)**
- **Actor and job:** an employee with self-service leave access checks their balance, submits a request, then withdraws it or asks to cancel it.
- **Entry:** `/tenant/[id]/me/leave`.
- **Success:** the detail page shows the confirmed state.
- **Choices:** leave type, dates, half day.
- **Failure and recovery:** separate read-failure states, invalid page, read-only view, unknown outcome.
- **Next step:** back to the list with its page number preserved.
- **Changes:** align the CTA wording, confirm where the "back" link goes for a self-service-only role (replace it with «ملفي» if `/tenant/[id]` isn't useful to them), and drop the unreachable list notice.
- **Proof:** a phone render with the existing owned employee QA login only. Don't re-test the balance or financial logic.

**3. One consolidated shared-component pass, plus a representative render sheet (polish, finite)**
- **Scope:** fold in all the retained optional notes and the legacy class wrappers.
- **Evidence:** for each of the 15 families, capture phone and desktop in light and dark, using existing owned operator, admin and employee sessions. This replaces any all-85-route pass.
- **Stop when:** there's one independent bounded review of the sheet. After that, any remaining notes are explicitly optional.

## Not claimed
- I haven't read the source of the remaining roughly 79 routes.
- No visual verification.
- Not verified: whether the operator shell renders navigation on those bare `main` pages.
- The full goal is **not** closed.