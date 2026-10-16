The contract is below; nothing has been implemented. I read the code only. I didn't run or render anything, and the measurements are the HR-admin baseline you recorded at `a68ce5a`.

## Findings that shape the contract

1. **Preview URL would break.** `EmployeePreview.tsx:28` builds the fetch as `${href}/preview`. If `href` gains `?return=…`, the URL becomes `…?return=…/preview`. Fix: pass a separate `previewHref` built from the IDs (`/tenant/${t}/people/${id}/preview`, same route), with no query string. No new API.
2. **Saves already keep the return.** Every profile write redirects through `profileActionRedirect` or `profileReturnUrl` using `ProfileReturnField`. Switching tabs keeps it too (`EmployeeProfileTabs` only sets `tab`). The signed-out redirect at `page.tsx:37` keeps it as well. A carried `q`/`page` therefore survives saves, tab changes and login with no change to any action file.
3. **`safeReturn` rejects some searches, and that's fine.** It rejects `%2F` and `%5C`, so a search containing `/` or `\` loses its context and falls back to the plain directory. Acceptable. Don't relax the check.
4. **`ReadinessList` is shared** with the company home page (`tenant/[tenantId]/page.tsx:90`). Don't change its labels globally; pass `statusLabel` per item instead.
5. **The existing test already uses a directory return** (`task=/people?q=…` in `scripts/tests/company-profile-context.test.cjs:8`). Extend that file rather than adding a new harness.
6. **No blockers.**

## Journey

- **Actor:** HR admin, or a reader with fewer permissions.
- **Job:** find an employee and finish or check their setup.
- **Entry:** `/people`, possibly filtered (`?q=&page=`).
- **Success:** the file opens in one click. The user sees the single next step for the employee's core setup and its owner. They return to the same search results.
- **Choices:** open the file, or preview it read-only.
- **Failure and recovery:**
  - Preview fails or the session expired: keep the current retry message and the "open full file" link.
  - Return value is invalid: go back to the plain directory.
  - A fact can't be read: show "تعذر التحقق" in amber, never green.
- **Next step:** the one action in the next-step card.

| Measure | Baseline | Target |
|---|---|---|
| Clicks from row to file | 2 | 1 |
| Back link keeps `q`/`page` | no | yes |
| Return links visible on profile | 2 (+ "عرض جميع الموظفين") | 1 (the second appears only when coming from a task) |
| Readiness links visible before expanding | 8 | ≤1 |
| "Next step" labels shown at once | 2 | ≤1 |
| Readiness items reachable | 8 | 8 |
| Actions removed | — | 0 |

## 1. Directory (`people/page.tsx`, `EmployeePreview.tsx`, `people.module.css`)

**Page**
- Change the H1 to **«الموظفون»**, matching the nav and breadcrumb.
- Description: «ابحث عن موظف وافتح ملفه لمتابعة إعداده.»

**Row actions**
- **«فتح الملف»**: a ghost `ButtonLink` with the `user` icon, linking to `profileHref`. It's the only text action in the row; don't use a filled button in every row.
- **Preview**: an icon-only `<a>` with the `eye` icon, 44×44 px.
  - `aria-label` and `title`: «معاينة سريعة: {name}».
  - Plain `href={profileHref}`, so it still works without JavaScript and with modifier-key clicks.
  - Keep the current `aria-haspopup`, abort-on-close, focus return, projection and privacy behaviour unchanged.
- **Inside the preview sheet:** the footer link «فتح الملف الكامل» uses `profileHref`.

**Building `profileHref`**
- Start from `const current = pageHref(tenantId, query, page)`.
- Add `return` only when `query` is non-empty or `page > 1`, so URLs stay clean otherwise.
- Pass it through `profileReturnUrl(tenantId, id, base, current)`, which validates with `safeReturn`.

**`EmployeePreview` props:** `{ href, previewHref, … }`. The fetch uses `previewHref`.

**Layout**
- Desktop: keep the current four columns; the last one becomes an action cluster (`display:flex; gap:8px`).
- 900px and below: the action cluster sits at row 2, column 2.
- Below 600px: name and status badge on row 1, employer and site on row 2, then a full-width action row. «فتح الملف» takes `flex:1` and the eye icon stays fixed at 44px. All targets are at least 44px and nothing scrolls horizontally.
- CSS currently targets `.employeeRow>a`; change it to target the new `.rowActions` wrapper.

## 2. Profile return (`profile-return.ts`, profile `page.tsx`)

Add a pure helper to `profile-return.ts`:

```ts
export function profileBackLink(tenantId: string, raw: unknown): { href: string; label: string; fromTask: boolean }
```

| `safeReturn` result | Link | Label | `fromTask` |
|---|---|---|---|
| Path is `/tenant/{t}/people` and has `q` | `returnTo` | «العودة إلى نتائج البحث» | false |
| Path is `/tenant/{t}/people`, no `q` | `returnTo` | «العودة إلى الموظفين» | false |
| Any other valid internal path | `returnTo` | «العودة إلى المهمة» | true |
| `null` | `/tenant/{t}/people` | «العودة إلى الموظفين» | false |

Changes in profile `page.tsx`:
- **Line 279:** render one compact back link above the header using the existing `back-link` pattern (as in `users/invite/page.tsx:34`), not a full-width bar.
- **Line 285:** delete the second return link («العودة إلى المهمة»).
- **Line 301:** show «عرض جميع الموظفين» only when `fromTask`. That way someone who came from a task can still reach the directory, and there's no duplicate otherwise. «إضافة موظف آخر» and the follow-up and correction links stay as they are.

No caching of the search and no `localStorage`.

## 3. Readiness (`EmployeeReadiness.tsx`, plus a small pure helper)

Keep everything that builds `steps` exactly as it is: facts, states, detail text, owners and actions. Only regroup the output.

**Grouping**
- **Core group (5), in the original order:** work, policy, account, self-service, channel.
- **Review group (3):** wage, opening balances, tax and insurance.

**Helper** (`readiness-focus.ts` next to `EmployeeReadiness.tsx`):
- `focusIndex(items)` returns the first core item whose state is not `done`, or −1.
- `counts(items)` returns `{ saved, unknown, total }`.

**Next-step card** (`role="region"`, labelled by its heading)

| Focus state | Heading | Body | Action |
|---|---|---|---|
| `todo` | «الخطوة التالية: {title}» | the step's detail | its action, as the **only filled** button on the Overview tab |
| `other-role` | «بانتظار {owner}: {title}» | detail, then «يتولّاها: {owner}» | its action if it has one, as ghost; otherwise none |
| `unknown` | «تعذر التحقق: {title}» | detail, then «حدّث الصفحة أو راجع القسم المختص.» | its action if any, as ghost |
| none (−1) | «الإعدادات الأساسية مسجلة» | «سُجّلت الإعدادات الأساسية الخمسة. هذا لا يثبت أن الموظف يستطيع تسجيل الحضور اليوم؛ السبب الفعلي يظهر له في يومه.» | none |

**Pending-account cases**
- Account `pending` or `user_created` is `other-role` and comes before self-service in the order. The card therefore stops at «بانتظار الموظف ومسؤول المستخدمين: حساب الدخول» and never suggests enabling services.
- `manual_review` is treated the same way, with its own detail text.

**Summary line** under the card: «{saved} من 5 إعدادات أساسية مسجلة», followed by «، وتعذر التحقق من {unknown}» when `unknown > 0`.

**Core disclosure:** `<Disclosure summary="تفاصيل الإعدادات الأساسية (5)">` wrapping `ReadinessList`. Per-item badge labels:
- `done` → «مسجّل»
- `todo` → «مطلوب»
- `other-role` and `unknown` keep their current labels («يحتاج دورًا آخر» and «تعذر التحقق»)
- No item in the list says «خطوتك التالية»; the card is the only "next step".

**Review disclosure:** «مراجعات الأجر والأرصدة وبيانات الرواتب (3)».
- It gets the `open` attribute when the wage step is `todo` or `unknown`, so a missing wage is never hidden.
- Badge labels stay as they are now («تُراجع لكل فترة», «راجع الأرصدة»).
- A reader without wage permission sees only the current «يحتاج دورًا آخر / مسؤول الأجور» text. No amounts are shown.

**Existing note** (line 61): keep it, below the review group.

**Mobile:** full-width card; action button full width below 600px and at least 44px tall. The `<summary>` elements are reachable by keyboard and have visible focus.

## Acceptance and recovery cases

**Unit tests** (extend `company-profile-context.test.cjs`)
1. `profileBackLink` covers the four rows of the table, plus external, `//`, other-tenant and `%2F` inputs, all of which fall back to the directory.
2. `focusIndex` and `counts`:
   - Noor fixture (work, policy and channel done; account todo; services todo): focus is account, saved = 3.
   - Pending account: focus is account (`other-role`) and services are never the focus.
   - Unknown policy: focus is policy, even though a later step is `todo`.
   - All core steps done: −1.
   - Wage, balance and tax steps never count as core.
3. Profile URL with return: the preview fetch URL stays `/people/{id}/preview` with no query.

**Rendered checks** (synthetic owned QA, HR admin, `q=DEMO-010`, plus a reader role), at 390, 768 and 1280px:
4. One click on «فتح الملف» opens Noor's file. The back link reads «العودة إلى نتائج البحث» and restores `q`/`page`.
5. The preview opens and Esc closes it; focus returns to the eye icon. Ctrl-click opens the file in a new tab with the return carried.
6. Save a policy, change tab, or let the session expire and log in again: the back link still restores the search.
7. Overview shows 1 next-step label and at most 1 link before expanding; both disclosures expand to all 8 items with their original actions.
8. Reader: the card shows the owner's role, no wage values, and no unauthorized actions.

Remaining gap: user acceptance isn't proven. Visual quality is NOT VISUALLY VERIFIED until checks 4–8 have rendered evidence.