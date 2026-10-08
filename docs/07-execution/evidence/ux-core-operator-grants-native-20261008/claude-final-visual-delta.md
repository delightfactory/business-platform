# Official direct Claude Opus5.5 Medium

Read-only supplied source/images; session df1dfee6-d344-4464-9d39-30fb1488a841.

# R3 grants: final scoped checkpoint

## Verdict

**MATCH WITH ACCEPTED DEVIATIONS**, limited to the three final read states I inspected. The card padding I flagged as a must-fix last time is resolved, and these images show no new must-fix.

## Images read (Read only)

1. `grants-final-390.jpg`
2. `grants-final-768.jpg`
3. `grants-final-1366.jpg`

## What the images show

**Padding is restored at all three widths.**
- The eyebrow, h1, notice box, intro, "إضافة مشغّل", the "المشغّلون" heading, "إعادة قراءة المنح" and its hint now sit inside the card at every width.
- The inset is about 16px at 390, about 30px at 768 and about 40px at 1366. This matches the shared `work-card` values you reported.
- The notice box no longer runs edge to edge, and the rows are inset consistently with the headings.
- This now matches the card hierarchy of the public reference (Today mobile).

**Hierarchy and context hold at every width.**
- There is one filled primary, "إضافة مشغّل". The row actions are secondary, and revoke has the danger outline.
- The mobile and tablet topbar shows "المشغّلون", and the active desktop sidebar item matches it.
- Emails display left-to-right inside right-to-left rows without breaking the layout.
- Each row shows only the actions its state allows. The `disabled@` row is only partly visible at 1366, but no actions are visible on it.

**The title-to-notice spacing still has no gap.**
- The notice's top border sits directly under the h1 at all three widths.
- No glyphs are clipped and both are fully readable. It also looks less cramped now that the card has padding.
- This is shared spacing that was there before, not a legibility failure, so it needs no polish change.

**Accepted deviations:** the Cairo font, radius 8, and control heights of 44/44/40 versus the demo. The original pinned HTML remains the authority.

**Capture artifact:** the Next.js dev "N" badge covers the "المزيد" tab at 390 and 768. It is not part of the product, but these frames come from a dev server, not production.

## Row form key: source correctness vs what was observed

- **Source:** `key={grant.is_active ? 'update' : 'grant'}` is correct and as small as it can be. It rebuilds the row form only when the operation changes, which is the condition for the revoke→regrant bug you proved. Keeping only the operation key, without the flag key I proposed, is the right call: I raised update→update only as a prediction, and your native run did not reproduce it.
- **Observed in your native runs:**
  - The proved revoke→regrant stale defaults are fixed.
  - Two confirmed updates in a row on the same row reset correctly: a fresh list, a collapsed form and an empty reason, with no repeated submission.
  - After an unknown result, the same operation keeps the user's input.
- **Not observed:** the per-update reset came from your accessibility-tree and DOM inspection, not from these images. All three final frames are read states only, with no open task.

## Still open from my earlier source review

These final images do not show either item, and you did not report either as addressed:
- `aria-describedby` linking the "إعادة قراءة المنح" button to its warning.
- One clear primary on the error page: re-read as primary for read failures, and return to `/operator` as primary for confirmed denial.

Settle both, or record them explicitly as open, before preserving the work.

## Unresolved gates (not claimed)

- **Full visual:** both verdicts remain **NOT VISUALLY VERIFIED** beyond these three read states and the earlier inspected states. Not covered: error and status screens, the open task and pending states, dark mode, brand themes, and the 768 open-task state.
- **Environment:** this used a synthetic SDK with reseeded rows. It does not cover real roles, Auth, the provider or SQL behaviour, or any real mutation.
- **Recovery when the shared form's action throws:** still open.
- **Mounted state:** uncertainty in a mounted page, losing authority and switching accounts are still open.
- **Historical intent recovery:** still open; there is no per-attempt receipt.
- **Measurement:** no N/C/P/I/B speed claim and no voice-control runtime check.
- **Closure:** no R3, B1/B2 or R0–R8 closure; no PR, merge or deploy; no financial or D16 change; no payroll A/B choice.
