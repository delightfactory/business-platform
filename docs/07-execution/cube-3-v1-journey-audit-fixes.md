# Cube 3 V1 journey audit fixes

This slice addresses the preliminary employee/HR journey audit within the existing V1 Leave and Attendance interfaces. It adds no schema, calculation engine or workflow framework.

## Result

- Work policy authoring now reads and saves the existing half-day mapping fields: fixed break placement and flexible half-day break duration, including explicit zero. Unrelated revisions retain mapping; unmapped legacy policies remain editable. Validation errors retain all entered fields. Overtime thresholds appear only when enabled and retain their values.
- Employee request types load automatically when valid dates are committed by leaving the date field. Changing dates preserves the reason and any still-eligible type. Mismatched options cannot be submitted. Employee cancel navigation is disabled during submission/withdrawal.
- HR chooses approval or rejection in one decision form with one reason. A stable server dispatcher submits the explicitly selected decision through the existing independently authorized actions. Calculation refresh remains a separate secondary action. Calculation versions/counts move into disclosure; the primary view shows days, pay effect and balance effect.
- Ledger request/reversal references remain stored and available in audit details, with human context in the main row.
- An existing balance account has a direct adjustment action that prefills its type and period and opens the form. It also resolves an authoritative type beyond the first result page without inferring its current policy version.
- Uncertain balance posting keeps its original payload and operation key. Fields cannot be edited and the draft cannot be cleared while the outcome is unresolved. Retry shows the confirmed receipt without another ledger entry. Recovery wording describes the result rather than execution mechanics.
- Half-day configuration recovery links to the same tenant's policy page and retains a return link after saving. Policy assignment and frozen attendance history retain their existing rules; saving a template does not rewrite an already materialized day.

## Qualification

Focused local browser checks used exclusive synthetic fixtures in the calc-upgrade QA database and preview3315, with actual Auth, server actions, REST and database persistence. They verified:

1. Fixed and overnight mapping, flexible zero, catalog/editor readback, and name revision retaining the exact prior policy version.
2. Invalid mapping rejected with entered fields retained, followed by successful correction in the same form.
3. Automatic employee choices, date-edit preservation, persisted request, selected approval/rejection after toggling, and a stale decision refused while preserving its reason.
4. Approval consumes once; context adjustment persists once; a deliberately dropped response after committed posting restores the same draft/key and confirms replay with exactly one ledger entry.
5. Ledger reference disclosure, type selection beyond50 results, policy return-context retention, and disabled cancel navigation during a delayed actual withdrawal.
6. Phone/tablet/desktop widths390/820/1280 without horizontal overflow; representative screenshots inspected. Existing development-tool/fixed-navigation screenshot artifacts were not treated as layout defects.

TypeScript and ESLint passed. Final independent read-only Antigravity reviews passed, including the stable decision dispatcher and controlled-field corrections discovered in runtime tests. Production build (`npm run build -- --webpack`) passed.

Evidence is retained outside the repository in slice27-policy-browser.json, slice27-errors-and-reject-browser.json, slice28-journey-browser.json, slice28-recovery-browser.json and slice28-final-browser.json. The middle two preserve their partial successes and later failure rather than claiming those entire runners passed; the later focused checks qualify the corrected remaining paths. No fixtures, credentials or session data are committed.

## Remaining Cube 3 scope

This closes the localized audit work order, not full Cube 3 qualification. Linked approved-leave replacement UI and the V1 annual entitlement gate remain open. No main merge, production deployment or remote database migration is included.
