# Independent technical review

Claude Opus5.5 Medium, official CLI, session e31d88b7-60fd-4002-88c0-b503ab910e6d. Initial review found4concrete issues; one bounded correction cycle. Read-only violation false in both runs. This internal quality review is not a company usage/official-proof requirement.

**Verdict: PASS.** All four findings are fixed, and none of the fixes adds a review or evidence gate, which is consistent with the owner amendment. The four SQL suites (35/37/52/39), ESLint and the build are taken from your report; I did not re-run them.

## The four findings

1. **Old compulsory-evidence wording:** fixed.
   - `NumericRules.tsx:41`: the collapsed detail now says "طريقة التوزيع محفوظة / لم تُحدد…" and closes with "حالة التفعيل موضحة في الصفحة".
   - `:25`: the partition option and hint now describe only the calculation method.
   - The other matches that remain are accurate or harmless:
     - `:18` ("الحفظ لا يفعّلها") is correct, because saving and activating are separate steps.
     - `:28` ("فرع محفوظ يحتاج مراجعة مرجعه") only appears for unknown legacy branch codes.
2. **Legacy-issued revisions:** fixed.
   - Readiness (`migration:152`) now reports the issued pack's real policy, or `legacy_issued_review` when it has none. Unissued drafts still report `optional_company_review_v1`.
   - `dto.ts:65` rejects any policy value other than the two supported ones.
   - `comparisons/page.tsx:34` hides the form for legacy packs and points to creating a new version. The database guard (`:383`) still keeps legacy evidence immutable.
   - `IssuanceStatus.tsx:7` now shows the "add optional comparisons" message only for the new policy.
   - The new regression test (`cube4_statutory_issuance.test.sql:84-93`) builds a pack without the policy field through the real readiness function and checks that it reports `legacy_issued_review`.
3. **Empty references heading:** fixed. `page.tsx:40` shows the heading only when `source_references.length>0`.
4. **Grey "active" badge:** fixed. `page.tsx:40` uses `issued?"is-active":"is-inactive"`, and both PNGs show the green badge.

## Extras you listed

- **Comparison URL rule:** `migration:402` now uses the same pattern as draft sources (`:28`), so URLs with embedded credentials are rejected.
- **Empty-state copy:** `page.tsx:44` now reads "احفظ إعدادات الحساب للبدء؛ المراجع اختيارية".
- **Shell label and stages:** the shell and breadcrumb read "إعدادات حساب الرواتب", and the stages show as two columns at 1366 px.

## Visual check

The phone image is 375 px and the desktop image is now a real 1366 px RTL render of the active configuration page. Both show:
- the active badge in green;
- no empty references heading;
- the step-2 "فعالة" marker;
- no overflow, with readable Arabic.

The activation form, the comparison form and the legacy read-only view are **NOT VISUALLY VERIFIED**, because they are not in these images.

## Minor, not blocking

- The "مقارنات الحساب (اختيارية)" link still has no visible link styling in either render.
- A blank gap remains between the dates line and the numeric summary now that the references block is hidden (visible in both PNGs).