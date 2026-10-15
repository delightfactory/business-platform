# Final verdict: dynamic training guide (Opus 5.5, read-only)

The R1 fix works and I found no new defects. Source, coverage, journey and the desktop and mobile visuals all pass. I did not run, edit, commit or deploy anything.

## R1: fixed
`docs/user-guide/ar.md:10` now tells users to pick their task from the table of contents they can see. Only people preparing training for several roles are sent to «الدليل الكامل للتدريب» and then «رحلتك حسب دورك». The first step in filtered views no longer points to a hidden section.

Keeping the role summary out of the employee's default view is an acceptable choice for focused content. It stays one choice away in the selector, and the full guide and PDF still contain it.

## Source, privacy and authorization: PASS
I reused my earlier checks; the only source change since then is line 10.
- The guide link carries only fixed topic names, with no tenant or account IDs.
- Topics are worked out from links the server already authorized for that account.
- Mixed-role accounts get all their topics; pending accounts get the profile and first-login sections; a direct public visit shows the full guide.
- Printing gives only the sections on screen, and the PDF download is clearly labeled as the full guide.
- The filter only changes what is displayed; it grants no access.
- Labels in the changed text were confirmed earlier to exist in the app.

## Coverage: PASS
- No feature or safeguard was removed.
- All sections and the role summary are one selector choice away, and the PDF is the complete guide.

## Journey and simplicity: PASS
- **Who and how:** an employee opens «حسابي ← دليل الاستخدام والتدريب».
- **What they get:** the guide opens on their sections, and a status line names those sections and how to switch.
- **Fewer headings:** the table of contents drops from 35 to 6 headings. That figure comes from the rendered page; nobody was tested for understanding or speed.
- **One clear selector, no dead ends:** there is a single selector, and the first instruction now points to visible content.
- **Arabic and mobile:** right-to-left layout is correct and the controls are large enough to tap.

## Visual verdicts
Images I inspected:
- `guide-employee-mobile-2x.png` (780×1688)
- `guide-employee-desktop.jpg` (1366×900)
- `guide-pdf-first.jpg`
- `guide-pdf-last.jpg`

I did not open `candidate-hashes.json`, so these verdicts aren't tied to those hashes by me.

- **Desktop: MATCH WITH ACCEPTED DEVIATIONS.**
  - It keeps the accepted light document style: header colour, white cards, sidebar table of contents and typography.
  - The deviations are the new task-selector panel and the renamed print and download buttons. Both fit the document style, and the app's layout and theme are untouched.
  - The new line 10 text is shown in the rendered page.
- **Mobile at 390px: MATCH WITH ACCEPTED DEVIATIONS.**
  - The capture covers the first screen only (390×844), not the full page.
  - It shows a single column with stacked, full-width buttons and selector. Arabic text wraps cleanly with nothing cut off sideways, and the table of contents lists only the employee's sections.
  - Anything below the first screen is NOT VISUALLY VERIFIED by me.
- **PDF: MATCH.**
  - The first page shows the full guide with the updated line 10 text and the full table of contents starting at «1. رحلتك حسب دورك».
  - The last page is the unchanged training sign-off page.
  - I did not check the page count or tagging (34 pages, A4); that remains your claim.

This certification covers only the changed guide files and the guide link in the account menu. No further review is needed unless a concrete defect turns up.