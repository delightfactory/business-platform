# Scoped source verdict: statutory subpart of B1 at the C1 delta

**C1 is resolved at source level.** For an existing head, the fragment always has the same three child positions: acknowledgement, next link and `<details>`. An absent child renders as `null` or `false` and keeps its position. So when the rules prop changes from none to present:

- the `<form>` and `NumericRulesEditor` keep their tree path and are not remounted;
- the success acknowledgement sits outside the disclosure and stays visible even when `<details>` is closed;
- after a save the disclosure may close, but the comparisons link then becomes the single primary next step, with the receipt above it. That is the intended routing, and the entered state stays mounted.

**Gating is correct for the other states:**
- With no rules, `editRequired` forces the disclosure open, so the form stays visible.
- Error, stale and uncertain states force it open through `activeEdit`, so their alerts and recovery links stay visible.

**Unchanged:** fields, request signature, attempt identity, the uncertain/stale behaviour and the request release.

**C2 is closed:** the patch adds a blocker code only. The coverage item shape is unchanged, so the strict `releaseStatus` matches the source.

**C3 source is closed:** the domain value and output keys match the comparator. Acceptance of the legal wording is still open, with no new explanations and no labour case creation.

**Non-blocking items carried forward:**
- the list labels every draft "غير مؤهلة", even when issued;
- losing permission (42501) on the draft page's release read shows as "status unconfirmed";
- for an issued revision, the form heading and button still say "تعديل";
- an unknown insurance branch code renders with an empty label.

## Residual gates

1. **Runtime:** the save → revalidation transition while mounted, issue → issued, and stale or unknown replay against real SQL with real roles. The two tree-path checks are not acceptance.
2. **Rest of B1:**
   - onboarding, with its own reviewed client contract;
   - the remaining strict capability flags;
   - invitations rows and errors;
   - then the one affected lint/TS delta check after the grouped lint/TS/build pass.
3. **Owner/legal acceptance:** the C3 labour wording.
4. **Visual:** production captures with no dev overlay of the full state matrix (default, dirty, pending, uncertain, stale, error, issued, not-ready) at 390, tablet and desktop. Then separate Codex and official Opus actual-render verdicts. The full reference, tablet and desktop are not visually verified.
5. **B2:** the grouped real-role journey across all 11 functions, with matched before/after N/C/P/I/B measurements. No measured claims exist yet.

Full B1/B2, R3 and R0–R8 stay open. Payroll A/B is still independent and D16 deferred.
