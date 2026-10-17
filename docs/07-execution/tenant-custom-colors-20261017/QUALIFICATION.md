# Tenant identity: palette and HEX color

Owner-requested scope, 2026-10-17: keep preset colors and allow the company administrator to choose any opaque RGB color with a native palette or editable HEX code. No changes to company data, permissions, logo handling or audit requirements.

Journey: Settings > company identity > choose a preset, palette, or paste a 3/6-digit code (optional #) > see preview > save identity > read saved result. Invalid code remains editable and blocks saving; valid input canonicalizes to lowercase #rrggbb. Preview alone does not persist. The selected base color stays exact; button foreground and light/dark text variants adapt for readability. Before: four fixed presets. After: same four plus arbitrary RGB selection and code entry. This is a capability comparison, not a measured performance claim.

Implementation: widen existing primary_color_key contract, no new column or RPC signature. Migration 20261017093957_tenant_custom_brand_colors.sql replaces only color validation in the existing save function, retaining permission rechecks, tenant/record locks, active state, logo validation, audit and grants. No new dependency. Named presets preserve existing themes. Only validated HEX enters custom CSS.

Qualification:
- Next production build and TypeScript passed; targeted ESLint passed.
- Real local Postgres: all 41 branding pgTAP assertions passed; transaction rolled back. Covers custom save/canonicalization/no-op, invalid CSS/alpha, tenant isolation, ordinary-member denial, audit before/after, preset fallback and rollback on audit failure.
- 12 Node assertions passed: color input/contrast (216 RGB samples), guide role filtering and anchors.
- Built local app: #ffc000 saved and persisted after reload; palette selection #177d80 saved and persisted. Invalid code blocked, form inputs retained. Light and dark checked; 390 CSS px mobile width has scrollWidth = clientWidth = 390. Existing synthetic QA tenant only; no production tenant data used for tests.
- Guide HTML and PDF updated together. PDF remains 42 pages; no empty pages or out-of-page characters. Page 8 rendered and inspected.
- Independent official Claude Code 2.1.289, claude.ai firstParty Pro, Opus 5.5 Medium: PASS, no material bug, no edits, readOnlyViolation=false. Session 6b0791f0-40bf-42a6-a599-180f3210e87f. Mobile screenshot reviewed; desktop screenshot not reviewed by Claude. Codex inspected both themes and mobile. Optional group label improvement deferred as nonblocking.

Compact evidence and recovery journal retained outside sync at %LOCALAPPDATA%/ai-dev-workflow/runs/20261017-brand-color. Docker stale socket directories were preserved by rename before restarting; no database/volume reset. This is reversible recovery, not a claim that the Docker recurrence is permanently fixed.

Production release identity and final cleanup are recorded separately after verification. No main merge.
