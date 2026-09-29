# Cube 0 interface and interaction audit

## Scope and decision

This audit covers the implemented Platform Operator, Tenant, and Auth surfaces in the isolated Cube 0 experience branch. It checks the rendered page, shared controls, task entry and exit, visible state, form recovery, Arabic wording, accessible names, and layout at phone, tablet, and desktop widths. It does not sign off physical-device touch behavior or every mutation outcome. Keep the Cube 0 UX gate open until the remaining checks below are recorded.

## Page inventory reviewed

| Area | Pages | Review |
| --- | --- | --- |
| Tenant | Home; users and invitations; member invitation; legal entities and sites; new legal entity; legal entity detail and site actions; new site; branding | All eight rendered with representative signed-in data at 428 px. Headings, controls, and horizontal overflow checked. Detail disclosures and branding were visually inspected. |
| Operator | Home; invitation list and new invitation; onboarding; company list and lifecycle detail; commercial list and limits detail; entitlement list and detail; operator grants | All eleven rendered with representative signed-in data at desktop width and 390 px. Headings, controls, and horizontal overflow checked. Home, invitation form, and operator grants were visually inspected. |
| Auth and selection | Login; password recovery and update; invalid first-admin/member invitation links; tenant selection | Six routes rendered with appropriate fallback or signed-in state. Valid invitation acceptance and actual email delivery still require dedicated flow evidence. |

At 390–428 px, every inspected Operator and Tenant route stayed within the available page width. A representative Operator invitation and Tenant legal entity detail also fit at 768 px; the Operator home was inspected at desktop width. The automated control inventory found no visible unnamed buttons or select/input controls and no visible button/select/text field under 40 px high. The visually hidden branding file input is intentionally activated by a labeled, touch-sized control.

## Corrections made in this pass

- Shared control dimensions, spacing, focus, hover, pressed, disabled, and tenant brand color states now use common tokens. Action groups on narrow screens have usable touch targets.
- Branding uses an Arabic file picker with selected-file feedback and keeps the entered name, color, reason, and selected file available if save fails. A failed database save attempts to remove the newly uploaded logo object.
- First-admin invitation, member invitation, legal entity and site creation, and entity/site detail changes show errors beside the form and preserve entered values. Pending submit states are visible.
- Operator onboarding, lifecycle, limits, entitlements, and grant actions retain open forms and entered values on validation or database rejection. Repeated Operator and branch actions have target-specific accessible names where needed.
- Login preserves an allowlisted return to the requested task after session expiry. Data-load failures are distinct from genuinely empty invitation or company lists. Operator invitation, onboarding, and commercial forms show a numeric limit only when a limited plan is selected.
- The legal entity detail now labels the displayed site quota as the company-wide active-branch quota, avoiding confusion with the branch count for that entity.

After the local demo was rebuilt, inviting an existing Tenant member returned an inline "already a member" message, kept the email in place, and restored the submit button after its pending state. Keyboard activation opened and closed the mobile menu and dismissed a success toast. These are representative interaction checks; they do not replace the remaining mutation checks.

## Control and surface refinement — 2026-09-30

Shared action controls now use Cairo 600 at 14px, an 8px radius, and 40px desktop / 44px narrow-screen minimum height. Secondary actions use neutral styling; primary actions have a restrained highlight and shadow. Content-sized action groups replace incidental full-width stretching. Form fields, action dividers, surface shadows, disclosure indicators, and reduced-motion behavior follow the same contract in `frontend-ux-baseline.md`.

The rebuilt local demo was inspected on Tenant site creation and entity detail, and Operator grants. Computed controls measured 44px on the narrow Tenant form and 40px on the desktop Operator form, including its expanded confirmation action. The Tenant form had no horizontal overflow. Keyboard expansion and collapse of the Operator action remained functional. Production build, TypeScript, targeted layout lint, and diff whitespace checks passed. This visual pass does not close the interaction acceptance items below.

## Closeout pass — 2026-09-30

The rebuilt local demo completed these bounded acceptance journeys with disposable data:

- Tenant Site: created a Site, observed the company-wide 3/3 limit and its corrective message, then deactivated the test Site. Database state retained the inactive Site and its `created,deactivated` audit sequence; active usage returned to 2/3. A later reactivate/deactivate pair verified recovery and a touch-emulated toast dismissal, then restored 2/3.
- Tenant Member invitation: created, reissued, and revoked a disposable invitation. The final record is `revoked`, issuance 2; audit recorded `invitation_created,delivery_sent,reissued,delivery_sent,revoked`.
- Operator First Admin invitation: created, reissued, and revoked a disposable onboarding intent. The final record is `revoked`, issuance 2, with `created,delivery_sent,reissued,delivery_sent,revoked` in its audit. No new Tenant was accepted or created.
- Operator commercial decisions: changed the Site limit 3 → 4 → 3 and HR People entitlement denied → granted → denied. Current database values are again 3 and denied, with both changes and reasons in their audit tables.
- The entitlement journey exposed a real UI defect: a missing Payroll decision incorrectly kept its Grant option disabled after HR People became available. The card now derives Payroll's prerequisite from the effective People decision. The rebuilt demo showed Grant enabled when People was available and disabled after it was denied again. The database command continues to enforce the dependency.
- Edge pointer activation opened and closed the mobile menu and returned focus to its trigger. CDP touch emulation then opened and closed it; touch emulation also dismissed a success toast. Chrome pointer activation dismissed a separate Operator success toast. The in-app browser's pointer automation did not activate the menu, but its keyboard activation did; the independent Edge result isolated that observation from application behavior.
- At a 768px viewport, a complete Tenant invitation task opened from the member list, rejected an already active member inline while retaining the entered email, and returned to the list. The resulting page width was 753px within a 768px viewport. The error uses `role="alert"`, `aria-invalid`, and `aria-describedby`; the menu is a labeled modal dialog with focus return.

The current source passed `npm run build` (including TypeScript), `npm run lint`, and `git diff --check`. A focused local `tenant_lifecycle` SQL test passed 41 of 42 assertions, including stale-state rejection and mandatory-audit rollback. The sole failure expected exactly two Tenant list entries in an otherwise populated demo database that has three; it is a fixture-count assertion, not a failed lifecycle command. The previously recorded clean-database Foundation suite passed 447/447 before these UI and action-form changes; no database migration changed in this pass.

Visual evidence: [mobile menu](evidence/cube0-close-mobile-menu.png), [tablet users](evidence/cube0-close-tablet-users.png), and [Operator entitlements](evidence/cube0-close-operator-entitlements.png).

## Remaining acceptance evidence

1. A physical phone and actual screen reader were unavailable in this pass (`adb devices` reported no attached device). Touch emulation, keyboard, pointer, semantic markup, and responsive checks passed; device and assistive-technology acceptance must be recorded separately if required for the final UX gate.
2. Record the exact committed revision and final review decision in `cube-0-qualification.md` after landing this pass. The live demo currently includes local changes that are not represented by the earlier reviewed commit.
