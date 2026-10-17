# Official Claude Pro review

Provider: claude.ai, firstParty, Pro. CLI2.1.289, model claude-opus-5-5, medium. Session f33b9fbb-9d41-4abb-8e32-eca0d1b273c2. Initial10-turn discovery exhausted its bounded cap; one bounded report-only continuation, one focused delta and one two-image visual check. No source edits/read-only violation reported. Combined reported session cost is cumulative, not additive.

## Initial source review

# Employee rewards/penalties direct entry: source-only review

**Verdict: changes requested.** I found no P1 issues. Two P2 problems can block approval or change saved money data without the user noticing. Fix those, then the feature can move to runtime qualification. I did not run the app, render any screens or produce runtime evidence. I edited nothing.

**What I did not review:** I did not read the guide's section 23, `src/lib/guide-topics.ts`, `EmployeeProfileTabs.tsx`, the guide build and filter files, or the full `payroll.validate_input`. I also did not confirm that the `people_employee_snapshot` parameter names used in `adjustment-actions.ts:19` (`p_tenant_id`/`p_employee_id`) match the function's signature; runtime has to check that.

## P2 findings

**P2-1: Approval can get stuck, and the "entered from the employee profile" reference gets written onto records that didn't come from there.**
- `EmployeeAdjustmentForm.tsx:48` fills the reference field with `'تسجيل من ملف الموظف'` (entered from the employee profile) whenever `record.data.reference` is missing. That includes existing records created on the payroll inputs page that never had a reference.
- `payroll/inputs/actions.ts:15` only removes empty `deduction_category` and `consent_reference`, so this default reference is sent with the request. `saved-adjustment.ts:3-6` can't drop it either, because the saved record has no `reference` key to compare against.
- **Approve:** the server rejects any approval whose data differs from the saved version (`20261016140000_company_payroll_policy_versions.sql:37`, `p_data<>current.data` → `payroll_stale`). So approving such a record fails every time. An approver without manage rights sees read-only fields and has no way out.
- **Save:** a manager who edits the record stamps it with a reference claiming it came from the employee profile, which is false.
- **Fix:** only use the default when `!record`. For existing records, show the saved value or leave it empty. For an existing earning record that has no reference, don't send the field at all.

**P2-2: Editing an older record can silently switch its type.**
- `EmployeeAdjustmentForm.tsx:21-24` works out the reward/penalty classification from the current `components` list. If the record's saved type isn't in that list, the form assumes "reward". A type can be missing because it was deactivated, expired, changed, or falls past the 101-item limit.
- With more than one reward type and an editable draft, line 43 shows a select whose value matches none of its options. The browser picks the first reward type, and Save sends it. The amount can move to another type, or a penalty record can end up holding a reward type next to its old `employer_penalty` category.
- **Fix:** for existing records, keep the saved type fixed (as a hidden field plus its name, or a "type no longer available" notice). Only offer the type choice for new entries.
- Related: an approved record whose type has since gone inactive still shows "معتمد · جاهز للحساب" (approved, ready to calculate) at line 52, but the calculation will flag `adjustment_component_changed` instead (`20261016140000…sql:214`). That success label is misleading. Show the problem, or point the user to the payroll review.

## P3 notes (no action needed for qualification)
- **Default period lookup** (migration lines 36-37): the second query that picks the current period doesn't use the employment-date filters the count on line 33 uses. If the employer has overlapping periods, it can return an arbitrary row. Reuse the same filters.
- **Record order:** records are sorted by `h.id` (a UUID, lines 57/60), not by date, so the list order looks random to the user.
- **Setup form success link** (`EmployeeAdjustmentForm.tsx:79`) drops the `return` parameter. In practice the action redirects first, so this branch is mostly never reached.
- **Blocked setup:** if a component with the fixed key already exists but is inactive or the wrong kind, setup fails with a duplicate error and no type is available. The only way out is the payroll configuration screen.
- **Accessibility:** the "save your edit first" hint (line 58) isn't linked to the disabled approve/cancel buttons with `aria-describedby`.

## Capability and user journey
- **Actor:** a finance author or approver who can also open the employee profile.
- **Entry:** the employee's "المكافآت والجزاءات" (rewards and penalties) tab. Employer and employment are taken from the employee snapshot, and the current Cairo period is picked automatically only when exactly one matches.
- **Required choices:** reward or penalty, amount and reason. The type picker appears only when there is more than one type; the reference field is optional and tucked away.
- **Outcome:** Save draft redirects to the focused record. Approval is a separate button, gated by the approve permission and disabled while there are unsaved edits. The success message says not to approve until the payroll has been recalculated if it was calculated before.
- **Next step:** a link to the payroll run.
- **Failure and recovery:** each blocked state gets its own message: invalid link, denied access, no employment, no period, not on payroll, service disabled, locked period (with a correction link if the user has `payroll.correct`). Entered values are kept on a validation error. No automatic retry.
- **Simplicity:** good. There is no employer/employee picking, setup happens in context, and the user must choose the tax and social-insurance treatment explicitly (no defaults).

## Safeguards that hold in the source
- **Scope:** the read function (`20261017174211_employee_profile_adjustments.sql`) derives employment from the authorized employee snapshot. It requires one of the finance view/manage/approve permissions and matches tenant, employer, employment and period on periods, records and the focused record. Execute is revoked from PUBLIC, anon and service_role and granted only to authenticated users.
- **Server action:** `adjustment-actions.ts:20-22` checks the form's employer and employment against the snapshot before calling the existing input command.
- **Existing write command:** `payroll_save_input` still does all the enforcing:
  - permissions (`input_permission`: manage for save/cancel, approve for approve; `payroll_config.manage` for creating types);
  - locking, receipts and safe retries (attempt keys);
  - the revision check (CAS), and the rule that approve/cancel must match the saved data exactly;
  - drafts only can be saved; only draft or approved records can be cancelled;
  - frozen-period and frozen-version guards, plus the period-bounds check;
  - component eligibility, duplicate-key protection and the audit event.
- **Consent and deduction data:** existing `deduction_category` and `consent_reference` are passed through as hidden fields. New penalties use `employer_penalty`, and the default reference meets the required-reference rule for deductions.
- **Payroll calculation:** it counts only the latest approved version of each adjustment, once per run (`20261016140000…sql:209-220`). The engine is unchanged.

## Delta review

# Delta review: the two P2 fixes

**Verdict: P2-1 and P2-2 are both fixed in source. I found one new P2 of the same kind as P2-1: an older penalty that never had a deduction category gets `employer_penalty` added to it.** It's a one-line fix. This is source-only review; I make no runtime or visual claims, and I changed nothing.

## P2-1: resolved
- **New entries only:** `EmployeeAdjustmentForm.tsx:50` now fills in the "entered from the employee profile" reference only for new entries. An existing record shows its saved reference, or nothing.
- **Missing key stays missing:** `payroll/inputs/actions.ts:18` drops an empty `reference` when the saved record never had that key. Approve and cancel now send exactly the saved data, so the server's exact-match check (`p_data<>current.data`) passes. New entries are unaffected because they have no saved data to compare against.
- **No false provenance:** saving an older reward without a reference keeps it that way.

## P2-2: resolved
- **Type can't change:** existing records always send their original type as a hidden field (line 45), and the type picker only appears for new entries (lines 39, 43).
- **Missing type locks the record:** if the saved type is no longer in the current list (lines 26-29), edit, approve and cancel are all disabled. The warning says the type was not replaced (line 46), and the approved badge reads "معتمد · راجع النوع قبل الحساب" (approved, check the type before calculating) instead of "ready" (line 54).
- **Small note:** a record whose type is still valid but falls past the 101-type limit is also locked, even though the server would accept it. The overflow link still lets the user reach it in payroll inputs. Acceptable.

## New P2: older penalties lacking a deduction category
- **What happens:** line 37 sends `record?.data.deduction_category ?? (classification === 'deduction' ? 'employer_penalty' : '')`. For an existing penalty saved without `deduction_category` (for example, one created before that field was required), the form adds `employer_penalty`.
- **Effect:**
  - Approve and cancel fail with `payroll_stale`, because the data no longer matches the saved version. That's the same dead end as P2-1.
  - Save quietly writes a classification the record never had, which can change how the deduction is prioritised against the employee's deduction limit.
- **Caveat:** this only matters if such records exist. I can't tell from the files read whether the current rules allow saving a deduction without a category.
- **Fix:** `record ? String(record.data.deduction_category ?? '') : (classification === 'deduction' ? 'employer_penalty' : '')`. The existing empty-field removal on line 15 then keeps the saved shape.

## P3 claims
- **Accessibility:** confirmed. Disabled approve/cancel buttons point to the "save your edit first" hint with `aria-describedby` (lines 57, 58, 60).
- **Missing kinds only:** confirmed in the form. `AdjustmentTypeForm` offers only the `kinds` it is given (line 77), and the tax/social choices still start empty and are required (lines 78-79).
- **Server-generated setup key:** not verified. The form puts `keySuffix` into the key (line 74), but I didn't read where it comes from. If the suffix is unique per setup, the fixed-key duplicate protection that `SCOPE.md` promises no longer holds. Two people setting up at once could create two reward types; that's not a money problem, but the type picker would then appear. Please confirm this trade-off is intended.
- **Current-period filters:** not re-read in this delta, so not verified.
- **Minor, not a regression:** if the user clears the reference on a new reward, an empty `reference` is still sent. The original code behaved the same way.

**Overall:** fix the deduction-category line, then go ahead with the final build and render recheck.

## Codex resolution of final delta

Changed the legacy deduction_category fallback exactly as requested: existing records retain their saved category or absence, only new penalties default to employer_penalty. Six real inputAction request-shape cases passed (approve/cancel of absent reference, absent category and numeric amount). Config key uniqueness per setup is deliberate; simultaneous company administrators may create two distinct same-named types, requiring type selection. No money is created by creating a type. Scope reflects this tradeoff.

## Visual review

# Final visual check: 390px mobile, approved reward

**Verdict: accepted for mobile.** I found no material visual or usability problem in the two captures. The full journey reads clearly in Arabic and right-to-left, uses the existing company theme and components, and doesn't need horizontal scrolling apart from the tab strip, which scrolls by design.

**What works:**
- **Approved screen (`mobile-approved.png`):** the success message comes first and says what happens next: the amount is included when the period's payroll is calculated, and a payroll calculated earlier must be recalculated first. The selected period is set automatically and readable (1 أكتوبر 2026 — 31 أكتوبر 2026), with a clear button to view another period. The employee name, code and active status are visible above it.
- **Record screen (`mobile-record.png`):**
  - The collapsed summary shows the type, amount and status together ("مكافأة · ٥٠٠ جنيه · معتمد").
  - Expanded, the amount and reason fields have clear labels, required markers and correct right-to-left alignment. The reference is tucked away, and the status badge says it's approved and ready for calculation.
  - "Add another" and company type setup are collapsed below the record, so the screen stays focused.
- **Layout:** touch targets look a comfortable size. The bottom navigation doesn't cover any content, and Arabic text wraps without clipping.

**Non-blocking polish (doesn't stop release):**
1. **Locked fields look editable.** On the approved record, the amount and reason fields use the same white, bordered style as editable ones, though they can't be changed. A muted read-only style or plain text would show at a glance that approved values are locked.
2. **Mixed numerals.** The summary shows Arabic-Indic digits (٥٠٠) while the amount field shows 500. One style throughout would read more consistently.
3. **Cancel is one tap.** "إلغاء الإضافة" (cancel the entry) on an approved record has no confirmation step, and a cancelled entry can't be restored, only re-entered and re-approved. A short confirmation would prevent mis-taps on mobile. No money is at risk, because the server checks the revision and cancellation is audited.

**Remaining limitations:**
- I looked at two static 390px captures only. Desktop and tablet, the draft, penalty, locked-period, denied-access, unavailable-type and setup states, keyboard and focus order, screen-reader output, and dark or high-contrast themes were not checked visually by me.
- I have not inspected the runtime database results, guide PDF or test outcomes you described; I'm relying on your report for those.
- I make no timing or usability-metric claims.

I edited, installed and committed nothing.
