# Review of the c5abab6 statutory candidate (proposed, not accepted)

**Scope of this review:** the statutory source you supplied, and the three 390×844 PNGs (`reference-390`, `draft-390`, `comparison-390`) opened with Read. I read no other files and made no edits. The 52 controlled-SDK cases are not SQL, Auth or runtime acceptance. Full B1/B2, R3 and R0–R8 stay open, as does the onboarding unknown state; payroll A/B is still independent and D16 deferred.

## Source verdict: acceptable as statutory work in progress, with one must-fix and two verification gates

**What holds:**
- **Receipts are checked against the submitted request, not the latest revision.** `draftReceipt` compares with the `previous` state that was sent, so a historical replay is accepted. `issueReceipt` checks pack, revision, scope and `financially_qualified`.
- **Issued state wins over ready.** On the comparisons page, the issued check comes before the ready check.
- **Selected draft never shows a fake empty list.** A bad response, a wrong head or a history/head revision race leads to an honest failure or a stale reload, never list mode.
- **Unknown comparison cases stay visible** with an alert. Unsafe source URLs show as text, not links.
- **No new behaviour was added.** I saw no new RPC, authority, storage or legal values. Attempt identities, the stale (PT409) path and the existing error messages are unchanged.
- **One primary action in each default state I checked:**

| State | Primary action |
|---|---|
| No numeric rules | Save |
| Rules present | Go to comparisons |
| Release status unreadable | Re-read status |
| Not ready (comparisons page) | New comparison |
| Ready (comparisons page) | Review issuance |
| Issued | None (shows "new revision" as a secondary choice) |

**C1 (must fix before acceptance): the save receipt can be hidden after the first save that adds numeric rules.**
- `DraftForm` returns the bare form when there is no `next`, no `issued` and no `secondary` flag. After the first save that adds rules, revalidation supplies `next`, so the form moves inside `<details>`.
- That details element opens only when `editing` or `activeEdit` is true. After a successful save, both are false, so it renders closed. The success message "حُفظت المسودة…" ends up hidden inside it.
- The same move remounts the `<form>` and `NumericRulesEditor`. Entered values survive, because they live in `DraftForm`, and the editor re-seeds from the saved rules. So nothing is lost, but the operator sees no receipt.
- **Minimal fix:** in `submit`, call `setEditing(true)` when `result.saved` is true. Alternatively, decide whether to wrap from `props.head` alone, so the structure never changes after a save. Add a G4 case for the transition from no rules to rules after a save.

**C2 (verification gate): `releaseStatus` may be too strict for the newer patched readiness output.**
- It requires every `missing_coverage` item to be `{year: integer, scenario: string}`.
- If the `20261003048000` labour patch emits coverage items in another shape, the comparisons page fails closed. The draft page then shows "حالة الإصدار غير مؤكدة" and demotes the comparisons step.
- That is safe, but it would block a legitimate journey. Codex should confirm the patched shape. Rejecting `ready` together with blockers is fine, because the source cannot produce that combination.

**C3 (verification gate): labour comparison presentation.**
- `c.domain === 'labour_deductions'` and the `actual`/`expected` keys must match the patched comparator.
- The Arabic labels in `labourScenarios` and `labourOutputs`, for example "حد النفقة" and "ترتيب الاستقطاعات", must come from existing source labels. If they are new wording, they need owner/legal wording review; that is a material decision.
- Unreadable rows are already shown, not dropped, which is correct.

**Lower-priority items (not blockers):**
- The draft list labels every head "مسودة غير مؤهلة", including issued ones. The list RPC has no issuance data, so neutral wording would be more truthful.
- If the release read on the draft page returns 42501 (permission lost), it shows as "status unconfirmed" rather than "authority lost".
- When the revision is issued, the form copy still says "تعديل بيانات المسودة" and "حفظ تعديل المسودة". It would be clearer if it said that saving creates a new revision.
- Unknown insurance branch codes render with an empty label. They should fall back to the raw code.

## Journey verdict: not accepted

- **Statutory subpart:** the flow (draft → comparisons → tax/insurance issuance) is clearer and keeps the three steps distinct, and issuance never claims financial qualification.
- **Not implemented yet:**
  - onboarding, with its own client contract for unknown results;
  - the remaining strict capability flags;
  - the invitations rows and selected-invitation errors.
- **Not tested:**
  - real-role runtime;
  - unknown/stale replay against SQL;
  - no-JS native behaviour;
  - matched before/after N/C/P/I/B measurement.
- **Comparisons screenshot uses synthetic data:** it shows ready with total 1 / official 1, which is fixture data. It says nothing about legal qualification or real coverage.

## Visual verdict (390 only, two default states): direction only, not accepted

- **Reference image:** used for shared cards, hierarchy and light semantic direction only. Concept C has no operator screen.
- **Confirmed in the captures:**
  - Arabic RTL with the Cairo font;
  - no horizontal overflow;
  - one dominant filled action per screen: "مراجعة الحساب مع نتائج المقارنة" on the draft, "مراجعة الإصدار" on comparisons;
  - controls look roughly 44px tall;
  - the RTL disclosure marker is correct.
- **Issues:**
  - Headings inside cards render at body size: the version name, the "تأهيل قواعد الضريبة والتأمين" heading, and "المراجع المحفوظة". The text is dense, and the comparisons back button sits directly on top of the eyebrow with no spacing. Hierarchy is weaker than the reference's card rhythm.
  - The Next dev indicator covers the fourth bottom-nav label ("المزيد"). These are dev captures, not production renders.
  - The draft image was captured before the guarded-toggle change. Neither image shows a dirty, pending, uncertain, stale, error, issued or not-ready state.
- **Not visually verified:** tablet, desktop, and full same-screen comparison with the reference.

## Next required gate

1. Fix C1. Resolve C2 and C3 against the actual `20261003048000` migration; route any new labour wording to owner review.
2. Finish the rest of B1: onboarding with its own reviewed client contract (it stays open until there is captured same-actor intent evidence), the remaining strict flags, and invitations. Then run lint, tsc and build once together.
3. Make production captures with no dev overlay of the full state matrix at 390, tablet and desktop. Then get separate actual-render judgments from Codex and from official Opus, followed by the B2 grouped real-role runtime and matched before/after measurements.
