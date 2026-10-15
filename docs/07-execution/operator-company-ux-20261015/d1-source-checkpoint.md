# D1 source checkpoint: company discovery and shared controls

Status: source-qualified checkpoint; D1, full Operator acceptance and all company-workspace work remain OPEN.

Implemented:
- Request-local cached active-operator and independent task reads shared by the navigation, home and directory. Failed permission reads fail closed individually; actions/RPCs retain their own authority.
- One company directory using the existing authorized lifecycle/commercial list RPC; home search, honest empty/error states and whole-row entry. Existing company-detail operations remain reachable through the authorized entry while D3 rebuilds their presentation.
- Five Operator navigation areas at most, including team and statutory work, without an unnecessary sixth More item. Existing tenant navigation is preserved.
- Controlled accessible service switch, stable name, confirmed checked state, pending/read-only states and RTL styling. The gallery uses synthetic local state; no service mutation is implemented by the component checkpoint.
- Full Claude specification plus A1 and Codex's accepted implementation baseline preserved. No SQL/action/financial contract was changed by this slice.

Focused verification:
- `node --test scripts/tests/operator-authority.test.cjs`: PASS, four distinct behavioral cases using the real permission/workspace/server wrappers with only external SDK/cookie boundaries substituted. This is not real Auth/SQL qualification.
- Focused ESLint over changed source and tests: PASS, exit0.
- `npm run typecheck`: PASS, exit0.
- `npm run build`: PASS, exit0, including both new company routes.
- `git diff --check`: PASS.
- Real gallery at local port61190: Space toggled ON to OFF; Enter restored ON; pending/read-only controls disabled. Representative 1366 light and390 dark renders inspected;768 inspected for width. No horizontal overflow in the inspected gallery at390/768. Viewport restored.

Evidence outside sync roots: `%LOCALAPPDATA%/ai-dev-workflow/runs/20261015-operator-company-ux/evidence/d1/switch-1366-light.png` and `switch-390-dark.png`.

Codex component inspection: rendering and basic keyboard behavior PASS for the gallery only. Reference fidelity and full screen/role visual verdict: NOT VISUALLY VERIFIED. Independent Claude runtime/visual acceptance: NOT RUN; scheduled for coherent full Operator review, not every component.

Open work: D0 real baseline; remaining D1 page heads/shared authority adoption; D2 backend; D3 contextual services/limits/lifecycle and saved search return; D4 creation/invitations; D5 team; D6 statutory/comparisons; D7 final acceptance. New entry temporarily routes to existing detail pages and is not the finished contextual workspace.

Docker: official4.95 installer signed/checksummed; Windows UAC returned cancellation, so installation and qualification are pending owner interaction. Do not repeat elevation or bypass consent. Existing151 containers/90 volumes and five PostgreSQL connection checks were recorded before graceful stop; no production or persistent-data mutation performed.

Storage: all active work, dependencies, build cache and images stay in the external owned run. Keep them for the ongoing goal and retain unresolved Docker evidence. No cloud space reclamation claim; earlier temporary validation-dependency removal was rejected by approval policy and remains excluded.
