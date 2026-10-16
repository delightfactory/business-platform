# Navigation and field-help qualification

Base: `1c2315a8c952562e64e1d8ead8851e7fe2476e03`. Development branch only. Local synthetic QA; no production migration or data mutation.

Implemented a persistent RTL desktop sidebar, daily/setup grouping, complete mobile drawer and concise bottom navigation. The server-authorized destination set is preserved, including unfamiliar routes. Organization is exposed only through the existing organization-manager permission snapshot. Payroll employer/period context is retained.

Field help is a quiet expandable inline region with a real label, keyboard Escape recovery and touch target. It no longer covers input values. Updated Arabic guide HTML/PDF (34 A4 pages); rendered navigation/help pages checked.

## Evidence and acceptance

- Eight node tests pass: authorized destination closure across five role fixtures, no input mutation, setup grouping, payroll context, current-page resolution including exact home/unknown routes/operator aliases.
- Scoped ESLint passed. Qualification Next build checks TypeScript. Source/build binding is in qualification.json.
- Real local admin journey, desktop1366 and mobile390: People → Organization reached in two clicks; no before/after click-count claim.
- Mobile390/tablet768: measured scrollWidth equals viewport. Expanded help ends before the input. Menu Escape restores focus and body scroll; opening/closing it and changing theme preserve the unsaved draft. Theme restored to system.
- Independent Claude Opus5.5Medium review c1306a72 found one Medium current-page issue. Fixed in shared resolution with tests; delta164666ec accepted. Review is read-only and explicitly distinguishes its screenshot/code inspection from the orchestrator's runtime checks.
- Four screenshots show the rendered layout before the final current-page-only correction. No layout styles changed after those images. A full matrix of live actors, screen readers, 200% zoom and all83routes was NOT run. This is scoped acceptance, not whole-platform completion.

## Remaining

Attendance setup search currently navigates away and loses values; source duplication must be resolved before a long form. Leave/payroll settings and local page links need the next workflow batch. People page heading still says الناس while the navigation says الموظفون; consolidate page copy there. Monthly calendar requires an authorized batched read contract, not repeated daily calls or inferred absence.

## Storage

All build/dependencies/raw evidence remain in the external owned run outside OneDrive. Existing61190 QA build preserved. No files deleted in this slice and no reclaimed-byte claim. Active caches are reused while the goal remains open; previous rejected cleanup targets remain untouched.

Final build after current-page correction passed. Actual organization page header and sidebar now select only the organization destination; no home/daily bottom tab is current. final-settings.png is from that final build.
