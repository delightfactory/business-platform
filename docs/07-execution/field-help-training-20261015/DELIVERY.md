# Field guidance, company training manual and rich UAT data

Delivered after whole Operator/Company acceptance, on the same development branch. No merge or production deployment.

## What changed

- Explicit contextual examples/help across the audited217text-entry source slots:171have examples or guidance,46native date/time or existing decision-critical explanations are documented exceptions. Choice/upload controls reviewed separately; source slots are not rendered instance counts. Shared ReasonField closes the previously ambiguous record-action field.
- New optional small question-mark disclosure beside Field labels. Initially closed;16pxglyph,28pxdesktop target,44pxcoarse-pointer target; Enter/Space/click toggle,Escape closes and restores focus. Critical warnings/errors stay visible. The first visual review found a global summary rule causing an oval44pxtarget; the final scoped CSS is measured28x28 and accepted from new renders.
- Arabic role-based training manual:32numbered subject sections, role routes, steps/outcomes/recovery, troubleshooting and training signoff. Source `docs/user-guide/ar.md`; offline HTML `public/user-guide.html`; final tagged A4 PDF34pages `public/user-guide.pdf`. Account menu links to the manual. Four complete untruncated Claude reads cover the original910lines. Three later textual clarity changes M1/M2/M3 were expressly permitted without another review; no application rebuild is required for replacement of existing static guide files.
- New isolated company named شركة الرحلة المتكاملة — بيانات تدريب فقط:12employees,14role accounts,2sites,3departments/3jobs,11dates/99employee work instances,24approved attendance facts,6leave requests acrossapproved/rejected/cancelled/submitted,4payroll periods,3advances,3payrollinputs and a genuine review-only calculation. Mobile/external sources and unmapped/duplicate/mapped cases are available. Read `demo-coverage.json` for exact boundaries.

## Verification and acceptance

Official Claude Opus5.5Medium session ace2d4e2-63c7-4751-abe2-d7d0224239b7 accepted this bounded slice and the full manual; visual verdict MATCH WITH ACCEPTED DEVIATIONS. First24-tool-turn pass ended before a verdict; same-session final response plus a focused full-manual/visual closure completed successfully. No provider substitution. See `claude-initial-review.md`, `claude-acceptance.md`, and `acceptance.json`.

Codex: PASS focused lint/typecheck/coherent build90977; source invariant audit692controls in67appfiles preserves behavior props; no SQL or server-action changes. Actual browser help click/Enter/Escape/focus, light/dark and390/1366CSSviewports; final28x28measured. Actual company home,12employee directory and source records viewed; guide link+HTML/PDFHTTP200. Final PDF34pages, no blank pages; representative final page visually rendered and inspected.

## Data and storage limits

Fixture is synthetic, not proof all product journeys passed. Physical GPS/device/provider success, real statutory/legal qualification, final payroll outputs/payments and governed final-output corrections have NOT been fabricated. Separate role accounts permit inspecting their actual authorized screens and guards. New company and public grants preserve owner trials/old companies. A protected pre-fixture pg_dump and operation journals remain outside Git.

Private training credentials are ONLY in the external run's `qa/TRAINING-ACCESS.private.md`, never the public manual/Git/review bundle. Account names carrying scenario descriptions are an intentional nonblocking UAT aid, not real HR data.

Active trial dependencies/build and six owned local containers are retained outside OneDrive because the owner is testing. The temporary guide-only server61191 has been stopped. No broad cleanup, Docker reset, volume deletion or cloud-quota recovery claim. The previous accepted goal remains complete; this document records the new requested follow-up.
