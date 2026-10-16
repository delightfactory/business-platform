# Plan: Batch 3c leave settings entry and the payroll policy end-date field

**Status:** This is a source-only plan. I didn't render or run anything. I couldn't save the plan file because no Write or ExitPlanMode tool was available in this session, so the full plan is below.

**What I read:** the five skills, `STATE.md`, `BATCH-3B.md`, the leave settings pages, `rules.ts`, `StatusCard.tsx`, `settings.module.css`, the employer-list migration, `InputForm.tsx`, the payroll configuration page, and the payroll migrations that touch the company policy.

**Conflicts to settle before coding:**
1. **The policy end date may already be enforced.** This conflicts with your "never uses `effective_until`" fact. Migration `20261002030000_cube4_payroll_review_fixes.sql:64` patches `payroll.build_review`, which was later renamed to `build_review_before_advances` in `20261002063000…:260`. The patch picks the policy by `effective_from`, which matches your fact. It also checks every day of the period: once a day reaches the policy's `effective_until`, it clears the calculation mode and raises **`policy_coverage_gap`**. So in source, a finite policy end does block payroll review from that date on. The policy can't be changed after saving (`payroll_policy_already_set`, `…cube4_payroll_inputs.sql:146`), so a finite end leads to a permanent blocker with no recovery screen.
   - **Check before writing copy:** run `pg_get_functiondef('payroll.build_review_before_advances(jsonb)')` on the owned database at port 56322 only, and look for `policy_coverage_gap`.
   - Either way, removing the end-date field when creating the policy is safe and better. Only the wording for an already-saved end date depends on the result.
2. **The new migration file is empty.** `supabase/migrations/20261016030516_leave_settings_entry_context.sql` is untracked and has no content. Put the leave change there, or delete it before committing.
3. **A wrong claim on the employer list.** Each active employer card says "متاحة للإعداد والتعديل." even to view-only users or when the leave service is off. That's a false capability message.
4. **Possible policy correction path.** `governed_corrections.sql:154,778` treats the policy as a correction source. I haven't confirmed whether a governed correction can amend it. Check this before saying "no recovery" anywhere in the interface.

---

## Part A: Opening leave settings directly when there is one legal entity

**Journey**
- **Who and what:** the leave settings manager (or a view-only leave user) wants to set up or review an entity's calendar, leave year and leave types.
- **Entry points:** the sidebar, the leave page, the company readiness checklist and the new-leave page. All of them link to `/leave/settings`.
- **Successful result:** the user lands on the entity's settings page with the next setup step clearly shown.
- **Today:** the user always passes through the entity list, even when there is only one entity. That's one extra screen and one extra choice.
- **After the change:** with exactly one entity, the user goes straight to its settings page. This is a planned reduction, not yet measured.
- **Failures:** the existing error screens stay as they are (no permission, invalid link, loading error).
- **Next step:** the existing "الخطوة التالية" panel (next setup step) on the entity's settings page.

**1. Migration (the empty untracked file)**
Use `CREATE OR REPLACE` on `public.leave_configuration_employers` with the same signature and body, adding one new value: `unique_employer`. It's calculated after the existing permission and input checks:
```sql
SELECT CASE WHEN count(*)=1 THEN (array_agg(x.id))[1] END INTO unique_id
FROM (SELECT e.id FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant LIMIT 2) x;
```
- It counts active and stopped entities, ignores the search text and the page cursor, and stays within the tenant.
- Restate the existing `REVOKE`/`GRANT` lines.
- Leave access is checked per tenant (`leave.authorized_hr_read`) with no per-entity scope, so "all entities in the tenant" is the same set the user is allowed to see.

**2. `settings/rules.ts`**
- Add `uniqueEmployer: string | null` to `EmployerPage`.
- In `readEmployerPage`: if the key is missing, treat it as `null` (works with the old function). If it's present, it must be `null` or a valid UUID; otherwise reject the whole response.

**3. `settings/page.tsx`**
- Add `choose_employer` to the query type and read it with `const choose = text(query.choose_employer) === '1'`.
- Add the redirect **after** login, the access snapshot, `canView`, the parameter checks and a successful page read:
  `if (!choose && q === '' && afterName === '' && afterId === '' && employerPage.uniqueEmployer) redirect(\`${path}/${employerPage.uniqueEmployer}\`)`
- Every link from the entity list back to itself carries `choose_employer=1`: the search form (as a hidden input), "مسح البحث", `firstHref` and `nextHref`. Then the list never jumps away once the user has chosen to see it.
- Check `node_modules/next/dist/docs` for how `redirect()` behaves in server components in this Next.js version.

**4. `settings/[employerId]/page.tsx`**
- The top back link and all three `StatusCard` back paths go to `/leave/settings?choose_employer=1`.
- Change the label from "اختيار جهة أخرى" to **"عرض كل الجهات"**. This is true even when there's only one entity, and it keeps stopped entities' history reachable.

**Redirect rules**
1. A redirect only happens after all existing checks pass. Any error or permission screen appears first.
2. It only happens with no search text, no cursor and no flag. A search, a later page or the flag never redirects.
3. It only happens when there is exactly one entity in the tenant. Zero entities, or two or more, show the list exactly as today.
4. The settings page never redirects back to the list, so there's no loop.
5. The redirect replaces the history entry, so browser Back returns to where the user came from.
6. No other permission, limit, cursor or service check changes.

**5. Small copy and layout fixes in this route family only**

| Where | Current | Proposed |
|---|---|---|
| Entity list description | ابحث عن الجهة القانونية… | اختر الجهة القانونية لإعداد تقويمها وسنة رصيد الإجازات وأنواع الإجازة. |
| Active entity card, meta line | متاحة للإعداد والتعديل. | Remove it; the "نشطة" badge is enough (fixes conflict 3). |
| Card button | فتح الإعدادات | فتح إعدادات الجهة (active) / عرض السجل (stopped) |
| Empty list, no search | …جرّب كلمة أخرى أو امسح البحث | لا توجد جهات قانونية مسجلة لهذه الشركة بعد. يضيفها مسؤول الشركة من إعدادات الجهات والفروع. |
| Empty list, with search | (unchanged) | لا توجد جهات تطابق «q». جرّب كلمة أخرى أو امسح البحث. |
| Search button / "الصفحة التالية" | solid | ghost (the main action on the list is choosing an entity) |
| Settings page description | (long) | «الجهة»: التقويم، ثم سنة رصيد الإجازات، ثم أنواع الإجازة. كل تغيير يسري من التاريخ الذي تختاره، ويبقى السجل السابق محفوظًا. |
| Settings page, no calendar yet | "إضافة سنة إجازة" button shown even though a calendar is required first | Replace the button with the line: يتطلب إضافة تقويم أولًا. |
| "الخطوة التالية" panel | text and button only | Add a short 3-step checklist (تقويم ✓ / سنة الرصيد / أنواع الإجازة). Numbering fits because the steps are a real sequence. |

- **CSS** (`settings.module.css`): add a `.setupSteps` class (grid, done/current/pending states using existing tokens), and replace `--theme-legacy-muted` in `.filterBar label` with `--color-muted`. No new colours.
- **Out of scope:** the hint in `company-readiness.ts:40` ("اختر الجهة…") becomes slightly inaccurate for single-entity tenants. I'm leaving it as a later item.

## Part B: The company payroll policy end-date field

**Journey**
- **Who and what:** the payroll configuration manager sets the company-wide way of calculating part of a pay period, once.
- **Choices:** only the calculation method and the start date.
- **Failure and recovery:** the existing handling for a save that collides with one already made (the `policy_once` race) stays as it is.
- **Next step:** "عرض الإعداد المحفوظ" (view the saved setting).

**Changes**
1. **`payroll/inputs/InputForm.tsx:53`:** when `configuration && kind === 'policy'`, show only `field('from')` and send `<input type="hidden" name="until" value=""/>`. The existing action at `actions.ts:21` already turns an empty value into `null`. Payroll item (component) forms keep their optional end date, and operational inputs are unchanged.
   - Help text for the start date (policy only): «تسري السياسة من هذا التاريخ دون تاريخ نهاية. لا يمكن تعديلها بعد الحفظ.»
   - Side note (`InputForm.tsx:55`): «تُحدد مرة واحدة لكل جهات الشركة وتستمر دون نهاية. راجع طريقة الاحتساب قبل الحفظ.»
2. **`payroll/setup/configuration/page.tsx:77`:** show an already-saved end date as stored. Don't hide it and don't change it. The label depends on the database check in conflict 1:
   - **If `policy_coverage_gap` is present:** «تنتهي قبل {date}. بعد هذا التاريخ تُظهر مراجعة الرواتب نقصًا في سياسة الشركة ولا يكتمل الحساب.» Then record "no way to amend the policy" as an open business issue (see conflict 4). Don't make up a fix in the interface.
   - **If it's absent:** «تاريخ نهاية محفوظ سابقًا؛ لا يُستخدم في احتساب الرواتب الحالي.»
3. No changes to the calculator, the save function, any migration, or how the policy is chosen.

## Acceptance checks (proportional)

**Database tests** (extend `supabase/tests/cube3_leave_configuration_read_closure.test.sql`, on port 56322 only):
- `unique_employer` returns the entity's ID when there is exactly one, even if it's stopped, even when the search text doesn't match it, and even with a cursor.
- It returns `null` for zero entities and for two or more.
- Entities in another tenant aren't counted.
- An unauthorized user gets a 42501 error before any counting.

**Unit tests:** `readEmployerPage` handles a missing key, `null`, a valid UUID and a bad UUID.

**Runtime checks:**
1. One active entity: `/leave/settings` opens the entity's settings page directly. Back returns to the original page.
2. One stopped entity: it redirects, and the settings page shows the view-only "stopped" notice.
3. Two or more entities (including a stopped one): the list appears with no redirect.
4. Zero entities: the new empty-state message, without the "clear search" advice.
5. With one entity: `?choose_employer=1`, a search, or "next page" all show the list. The search, clear and next links keep the flag.
6. "عرض كل الجهات" on the settings page and on an error screen opens the list without looping.
7. No permission or a bad link: the same error screen, and no redirect.
8. A view-only user sees no claim that the entity can be edited.
9. A new policy shows only the start date and saves with an empty end date. A payroll item still saves with a finite end date. An already-saved end date shows the verified label. The collision race keeps its current message.

**Visual checks:** the list, the settings page and the policy form at phone and desktop widths, in RTL, light and dark, plus keyboard focus order. These are required evidence after the build; I haven't done them.