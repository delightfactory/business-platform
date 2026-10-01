# Leave configuration UI — local qualification

## Delivered scope

HR can search and page legal employers, inspect retained configuration, create and revise Leave calendars, add a company-defined balance year period, create and revise Leave types, and activate/deactivate types. Calendar/type changes preserve effective versions. The year-period form includes its last date; calendar/type version end dates exclude that date.

The routes under `src/app/tenant/[tenantId]/leave/settings/` use authenticated Leave RPCs and their authoritative tenant/permission/lifecycle checks. Configuration access does not require the broad People directory permission. Manage-only/approve-only read support and employer isolation were qualified in the separate configuration-read database slice. Inactive employers and disabled services expose retained configuration without new-work actions. Creation, versioning and activation remain gated by the actual write RPCs.

Each operation has a focused form with retained inputs on error, disabled fields during submission and visible pending feedback. Advanced reference codes are optional to edit and collapsed by default. Company navigation exposes the settings entry to authorized Leave readers. Employer search/paging uses the server's bounded keyset API and exact employer lookup; the client UUID parser accepts PostgreSQL canonical UUIDs without inventing a version/variant restriction.

## Executed gates

- Independent `npm run typecheck`: passed.
- Scoped ESLint for the settings folder and `context-navigation.tsx`: passed.
- `npm run build`: passed with Next.js 16.3.6, Node 24.16.0. The build included concurrent uncommitted own-cancellation UI; its successful compilation is not functional qualification of that separate slice.
- Authenticated browser on loopback Next development server 3304 and isolated authoring QA: created a calendar; deliberately submitted a duplicate reference and observed retained name, dates, weekly rest, source, reason and code; corrected the code and created successfully.
- Created a 2027 balance year period and a paid, tracked working-day Leave type. Saved a later type version, observed both versions, deactivated then reactivated the type. Saved a later calendar version with a holiday and observed preserved earlier configuration.
- Employer selector with 55 synthetic inactive records: first page 50, terminal page 5, exact deep link to the last employer. Inactive detail displayed retained/empty configuration without creation links.
- RTL widths 390, 820 and 1280 matched document scroll widths. Browser snapshots and screenshots were inspected; pending navigation and submission feedback were observed.

Evidence lives in the local execution run: `qa-settings-mobile-error.png`, `qa-settings-desktop-overview.png`, `qa-settings-tablet-type.png`, `qa-settings-mobile-type.png`, and the development log. Some native date controls were populated through a DOM value setter plus events because the browser CLI's date fill did not persist reliably; actual forms and authenticated RPCs performed every recorded mutation. This does not replace physical device UAT, which the owner deferred.

No new migrations are part of this UI slice. It does not qualify annual legal grants, balances adjustment UI, HR request workflows, Attendance reconciliation, or Cube 3 closure. Tests/browser runs preceded the slice commit. Only listed settings/nav/qualification files are committed; concurrent cancellation UI and Next-generated agent files remain excluded. No merge or deployment occurred.
