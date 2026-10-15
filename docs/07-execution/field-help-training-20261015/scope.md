# Owner-requested field guidance, training and UAT data

Base:42f1016097aa4c62d9a6b3ceda74f3f8036a54b4 on development branch codex/operator-company-ux. This is a new follow-up slice after accepted Operator/Company delivery. No merge, production deployment or real-user data changes.

## Experience contract

Actors: Operator and every Company/HR role, including employee self-service. Task: understand an entered value, execute a role-authorized journey and verify its result without a live trainer. Entry: existing field or account-menu guide. Success: a meaningful example/units/constraints available at the field, a complete role-based manual, and a separate clearly synthetic rich test company.

Owner clarification: avoid descriptive clutter. Short examples belong in placeholders; optional meaning/units/examples open through a small subdued question-mark control adjacent to the label. Keyboard and touch remain supported. Existing critical validation/warnings/recovery remain visible. No automatic policy defaults, business-rule changes, or hiding financial/privacy consequences. Native date/time picker formatting and explicit choice labels do not need fake text placeholders.

The question icon is visually16px within a28px pointer target and uses the existing muted foreground; focus remains visible. Optional help is collapsed initially, toggled with click/Enter/Space and closed by Escape with focus restored. No tooltip that requires hover, no new component dependency, and no authentication/data request for field help.

Historical location evidence retention:60..2592000seconds. 86400seconds is a one-day arithmetic example, not a recommended privacy policy. Expiration makes evidence eligible for the existing trusted cleanup; do not promise installed automatic purge or deletion of attendance records.

## Deliverables and safeguards

1. Versioned source-slot audit with contextual examples and explicit exceptions; dynamic fields reviewed by domain, never inferred only from ambiguous names like value/until.
2. Existing validation, name/id/value/default/min/max, actions, permissions and server rules preserved. Copy/layout changes only, plus the manual entry.
3. Arabic role-based manual: where to start, required choices/actions, result, recovery and next step. Offline printable HTML/PDF for company training; no credentials or internal endpoints in the public guide.
4. Isolated synthetic UAT company with roles, employees, organization/work setup, differing attendance and leave states and payroll periods. Preserve current test data and owner trial edits. Snapshot QA before adding data. Do not fabricate statutory qualification, physical-device/GPS success or financial outputs.
5. Focused source/type/lint/build checks, representative keyboard/mobile/desktop runtime and data readback. Official Claude Opus5.5 Medium read-only acceptance for this related UI/manual batch per repository gate; no repeat whole-platform review.

Dependencies and build evidence stay outside OneDrive. Reuse the active trial installation; preserve data/backup/journals and compact acceptance evidence. No broad cleanup, database reset or unrelated-project changes.
