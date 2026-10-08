# R3 Core Journey: proposed contract, remaining batch

**Status:** Proposed only. This is not semantic, runtime or visual acceptance. Full R3, R0–R8 and visual acceptance stay open. Payroll A/B is pending its own owner decision, and D16/extras stay deferred. I made no edits, wrote no plan file and ran no tests.

## 1. Actor, jobs, entry points and outcomes

**Actor:** an active platform operator using a per-capability grant. Five capabilities are each checked separately: manage operators, onboard, lifecycle, commercial and statutory.

Every job follows the same steps:
1. Open the entry page.
2. Select the real company, account or task.
3. Read the current state.
4. Confirm one exact effect with a reason (where the source requires one), reusing any supplied version and attempt identity.
5. See an authoritative receipt, then the re-read current state.

Error handling follows the same rules for every job:
- **Stale:** the operator reviews and reloads.
- **Unknown:** only the replay the source defines (same key or attempt, same payload). No generic retry.
- **Malformed:** an honest "could not verify" message. It never claims success or failure.

| # | Function | Real operations | Terminal and recovery states |
|---|---|---|---|
| 1 | `onboardTenantAction` | Onboard a company with an existing confirmed admin | new / invalid / forbidden / admin missing / limit / conflict / **unknown (same key)** / committed receipt / re-read result |
| 2 | `changeCommercialLimitAction` | Seats or sites, each limited or unlimited | Unchanged in this batch; prior evidence reused |
| 3 | `changeTenantEntitlementAction` | Grant, deny or expiry for each of the 5 units | Unchanged; prior evidence reused |
| 4–6 | Invitation create / reissue / revoke | Separate from onboarding; delivery is governed by the R2 recipient and outbound specs | Unchanged; provider acceptance, delivery record and receipt stay distinct |
| 7 | `changeOperatorGrantAction` | Grant, update or revoke; self-revoke signs out locally; self-downgrade reroutes; last-manager rule | Unchanged routing; no new authority |
| 8 | `saveDraftAction` | New draft, or new revision of an existing head | exists / stale (PT409) / numeric invalid / **unknown (same attempt)** / saved receipt |
| 9 | `saveComparison` | Official or synthetic case against the current revision | stale / invalid / unknown (same attempt) / saved (matched or mismatched, `qualified=false`) |
| 10 | `issueRules` | Issue tax and insurance rules for one revision | stale / preconditions not met (23514) / unknown (same attempt) / issued (`tax_insurance` only, `financially_qualified=false`) |
| 11 | `changeTenantLifecycleAction` | Lifecycle transitions | Unchanged; prior evidence reused |

The statutory chain is draft → comparisons → tax/insurance issuance, and the three steps stay distinct. An issued revision is immutable. Changing it needs a new draft revision plus new comparisons. Issuance never implies a full financial lock or labour, overtime or deduction qualification.

## 2. Findings challenged

**F1 (onboarding result read): confirmed.**
- `onboarding/page.tsx:25` ignores the read error.
- Any truthy result reaches `OnboardingResult`, so `{}` renders "تم إعداد الشركة" followed by `String(undefined)`.
- The action accepts any object as a receipt.

Two corrections to the finding:
- The read is scoped to actor + key. A different actor's commit is therefore a different scope, not hidden state.
- The realistic ambiguity is the current actor's grant changing between page checks and the read, or a crafted URL.
- Neither case justifies inventing a "not committed" state or generating a new key. Absence stays ambiguous.

**F2 (statutory workspace): confirmed.**
- With `?head=X`, a response missing `head` or `current` falls through to list mode. `w.items` is then undefined, so the page shows a fake "no drafts" message.
- Bad dates make `date()` throw.
- The function is volatile, so the history statement can see a revision newer than `head.revision`. The page must show this as stale and reload, not render it as consistent.
- The current failure copy says "لم تتغير أي مسودة" after a failed *read*. That is unverifiable.

**F3 (competing primary actions): confirmed.** Two primary buttons appear on the selected draft page and again on the comparisons page.

**F4 (issuance): confirmed, but it is display honesty, not the safety barrier.**
- `statutory_draft_issue` recomputes the evidence stamp and readiness on the server (PT409 and 23514). A string `ready:"false"` showing the form cannot actually issue anything.
- The real risks are:
  - mislabelling an issued or stale revision;
  - `issueRules` accepting any truthy `pack` without checking it against the returned `{pack, revision, qualification_scope, financially_qualified}` (`issuance.sql:131`).
- The draft page also always shows "مسودة غير مؤهلة", even for an issued revision. This is an additional bug, not a separate finding.

**F5 (capability flags on entry pages): confirmed.** Truthiness checks, or ignored errors, remain in:
- `onboarding/page.tsx:21`
- `invitations/page.tsx:32`
- `invitations/new/page.tsx:18`
- `commercial/page.tsx:16-20`
- `entitlements/page.tsx:17-20`
- `tenants/page.tsx:18-21`
- `statutory/page.tsx:19`

`operator/page.tsx` and the three `[tenantId]` pages are already strict. A related gap: `invitations/page.tsx:37` turns a non-array `rows` into a fake empty list.

## 3. Minimal source DTO requirements

Put pure parsers in a new `src/app/operator/statutory/dto.ts` and `src/app/operator/onboarding/result.ts`.
- Each returns `{ok:true,value} | {ok:false}`.
- Reuse `uuid` from `@/app/tenant/[tenantId]/payroll/rules`.
- Unknown extra fields are tolerated.
- No financial formulas are replicated.

**Onboarding result**
- `tenant_id` is a uuid.
- `tenant_name`, `legal_entity_name`, `site_name` and `admin_email` are non-empty strings.
- Each `*_limit_mode` is `limited` or `unlimited`.
- A limit is a positive safe integer when limited, and `null` when unlimited.
- Each `*_usage` is an integer ≥ 0.
- The action validates the RPC return with this same parser.

**Selected workspace**
- `head.id` equals the requested `?head` (case-insensitive).
- `current.head_id` equals `head.id`, and `current.revision` equals `head.revision`.
- Dates are valid: `effective_from`, plus `effective_until` when present (null or valid), and `created_at`.
- `source_references` is an array of `{title, url}` strings. Only `https:` URLs render as links; anything else renders as plain text.
- `numeric_rules` is `null`, or an object containing `tax` and `insurance` objects (enough for `NumericRulesSummary` not to throw).
- `history` is an array with every revision ≤ `head.revision`. A higher revision means **stale and reload**, not rejection.

**Workspace list**
- `items` is an array of heads with valid dates.
- `next` is `null` or `{created, id}`.

**Comparison history**
- `rows` is an array, each row with an integer id and revision, `case_data` of the shape the page renders, a boolean `result.matched`, and a valid `created_at`.
- If `current_revision` ≠ `workspace.head.revision`, treat it as **stale**.

**Release status**
- `revision` equals the workspace head revision.
- `evidence_stamp` matches `/^[a-f0-9]{32}$/`.
- `ready` is boolean.
- `blockers` is `string[]`.
- `missing_coverage` is `{year:int, scenario:string}[]`.
- `total` and `official` are integers ≥ 0.
- `issued_pack` is `null` or a uuid.
- `qualification_scope` is `'tax_insurance'` and `financially_qualified` is `false`.
- If `ready` is true while there are blockers or coverage gaps, or `issued_pack` is set, that is an integrity failure.
- A PT409 error from the status read means **stale and reload**.

**Receipts** (any mismatch means *unknown*, and the same attempt is kept for replay)
- **Draft save:** `head` is a uuid. When editing, `head` equals `previous.head` and `revision > previous.revision`. `state` is `'unqualified'`.
- **Issue:** `pack` is a uuid, `revision` equals the expected revision, and the scope and qualification fields are exact.

**Capability flags:** add `operatorActive(r) = r.error===null && r.data==='active'` beside `operatorPermission` in `src/lib/operator-access.ts`. Pages show "تعذر التحقق من الصلاحية" (with a reload link) when the check errors, separately from "غير متاحة" when it is denied.

## 4. Dominant actions, required choices and context retention

**Onboarding (`?key`)**

| State | What the page shows |
|---|---|
| No key | Form with a fresh key. |
| Read error, or malformed result | "تعذر التحقق من نتيجة الطلب". Only action: re-read with the same key. No form, no success claim. |
| Null result | "لا توجد نتيجة محفوظة لهذا الطلب في حسابك" plus the form **bound to the same key**. This is the source-defined replay: the same payload returns the result, a different one returns conflict. No fresh-key link is offered from this state. |
| Valid result | Success panel. Primary: the admin login link. Secondary: "إعداد شركة أخرى". |

- In the action, change the fallback `failed` to `unknown`: "لم تتأكد النتيجة؛ أعد الإرسال بنفس البيانات لاستعادتها". The key and the fields stay in place.
- Errors the server explicitly classified stay definitive: forbidden, admin, limit and conflict.

**Selected draft**

`DraftForm` gains a `next` prop and owns the step routing, so client state (dirty, pending, uncertain, stale) decides which action is primary.

| State | Primary action | Editing |
|---|---|---|
| No `numeric_rules` | Edit and save | Open by default |
| Rules present, not issued | "مراجعة الحساب مع نتائج المقارنة" | Secondary disclosure: "تعديل المسودة (ينشئ نسخة جديدة وتلزم مقارنات جديدة)" |
| Issued | — | Label "صدرت للضريبة والتأمين فقط · غير مؤهلة ماليًا"; secondary disclosure "إنشاء نسخة جديدة" |
| Issuance status unreadable | Re-read | Label "حالة الإصدار غير مؤكدة"; the edit disclosure stays available |
| Dirty, pending, uncertain or error | Save or recover | Disclosure forced open; the comparison link is shown as secondary |
| Stale | Existing "open current revision in a new window" | Entered fields kept |

- The issued state comes from reading the existing `statutory_draft_issuance_status`. No new RPC.

**Comparisons page**

| State | Primary action | Other choices |
|---|---|---|
| Integrity failure or stale | Reload only | — |
| Issued | — | Link "إنشاء نسخة جديدة من المسودة" |
| Ready | "مراجعة الإصدار" | New comparison as a secondary disclosure |
| Not ready, rules present | New comparison | Blocker list shown |
| No rules | Back to editing the draft | — |

- Keep `ComparisonForm` and `IssuanceForm` at stable tree positions and keys, so revalidation never remounts them and loses entered data.
- Only the summary's styling changes between states.

**General rules**
- Exactly one `primary-button` is visible in the default state. Opening a disclosure is the operator's explicit choice of task.
- Arabic RTL and Cairo dates are unchanged. `dir="ltr"` stays on URLs only.
- Copy for failed reads becomes: "تعذر قراءة الحالة الحالية؛ لا يمكن تأكيد حالة المسودة من هنا. أعد التحميل." It no longer says "لم تتغير أي مسودة".

## 5. Routine (source-preserving) vs owner-required

**Routine, inside this batch**
- The parsers and receipt checks above.
- Strict UUID regex on onboarding.
- Strict capability and status flags, with error shown separately from denial.
- Invitations `rows` must be an array: show a failure state instead of a fake empty list.
- Honest unknown and stale copy.
- Dominant-action routing.
- Labelling issued revisions, using the existing status RPC.
- On grant, lifecycle and commercial "failed" messages: copy telling the operator to *re-read the current state* instead of "retry".

**Owner-required (not in this batch)**
- **O1:** any fresh-key "new request" path from an ambiguous onboarding read, or any "closed / uncommitted" state.
- **O2:** idempotency or attempt keys for grant, lifecycle, commercial or entitlement mutations. These need new RPC parameters.
- **O3:** a single-snapshot workspace read to remove the history race. This needs a migration; the UI handles the race as stale for now.
- **O4:** any pack-detail view, or wording about the legal meaning of issuance.
- **O5:** payroll A/B and D16.

## 6. Next implementation batch (B1, one coherent milestone)

1. `operator-access.ts`: add `operatorActive`. Apply it plus `operatorPermission` to the 7 entry pages in §2 F5.
2. `onboarding/result.ts`: parser. Then update `onboarding/page.tsx` to the four-state routing, and `actions.ts` to validate its receipt and return `unknown`.
3. `statutory/dto.ts`: the workspace, history, release and receipt parsers. Then:
   - `statutory/page.tsx`: selected mode never falls through to list mode; stale handling; issued label; copy changes.
   - `DraftForm.tsx`: the `next` prop and routing.
   - `actions.ts`: receipt check.
4. `comparisons/page.tsx`, `IssuanceStatus.tsx` and `issuance-actions.ts`: parsers, PT409 treated as stale, dominant routing, issue-receipt check.
5. `invitations/page.tsx`: fail on non-array rows; surface the selected-invitation read error.

Run lint, tsc and build once, at the end of B1.

**B2 (separate milestone):** a grouped complete-journey runtime across all 11 functions, using the role and state matrix in §1. Measurements are taken on matched before/after supported journeys, and no N/C/P/I/B numbers are claimed beforehand.

## 7. Focused qualification groups and gates

- **G1, pure parsers:** compact table tests covering valid, null, error+data, `{}`, wrong head, revision mismatch, string booleans, bad dates, non-arrays, non-https URLs, extra fields, and inconsistent ready/blockers.
- **G2, page regressions:** reuse Codex's controlled-SDK async-page harness. Turn the 12 baseline observations into expected-fixed cases, and add the stale history race, PT409 on status, the issued label, and invitations rows. This is still not acceptance.
- **G3, action receipts:**
  - onboarding: each mapped error, unknown, and a malformed receipt keeping the same key;
  - draft: mismatched head or revision becomes uncertain with the same attempt;
  - issue: wrong pack, revision, scope or `financially_qualified` becomes uncertain;
  - comparison: unchanged.
- **G4, client hooks:** `DraftForm` and `IssuanceForm` replay the same attempt after uncertain; dirty or uncertain forces the disclosure open; the forms are not remounted on revalidation.
- **G5, permission flags:** for each page, test the error, denied, `"true"` string, and `true` cases.

**Reused, not repeated:** SQL role and financial evidence for unchanged contracts, and the provider/Auth/R2 delivery tests.

**Visual:** the layout changes (disclosures, button classes) require separate Codex *and* official Opus judgments of the actual rendered pages later. Concept C supplies shared direction only (palette, cards, secondary controls, RTL); it has no operator screen. No visual claim is made now, and the tablet/desktop exclusions inherited from 14049fe still apply.

## Blockers and risks

- **Onboarding replay is an unverified assumption.** The same-key replay assumes `onboard_tenant` returns the stored snapshot for the same key and payload. I did not read that part of the migration. Codex should confirm it before implementing step 2. If it doesn't, the null-result state needs owner decision O1.
- **`numeric_rules` guard depth.** The guard covers only what `NumericRulesSummary` dereferences. If deeper malformation can still throw, render the integrity failure; never drop rows.
- **Issue receipt.** After a successful issue, revalidation replaces the form with the issued status. That is acceptable, because the authoritative current state is the receipt the operator sees.
