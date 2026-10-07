# R1-NAV-01 qualification

Actual source component mounted with installed React/react-dom and native HTML dialog, matchMedia and focus. Compiled production CSS was served locally. Synthetic tenant and operator props; Next link/pathname/image and signOut mocked. No project data, account, backend connection or sign-out operation. External harness transpiled the TSX with installed TypeScript and bundled using Next's bundled webpack, served on127.0.0.1:3565. Raw generated bundles/harness and relay runtime logs remain local.

Before390->1366: dialog remains open but hidden; overflow hidden; manual Escape required. After390/900->901/1366: native close and existing cleanup restore scrolling, zero manual recovery steps. Escape restores launcher focus; bottom launcher and explicit close work. Synthetic operator768->901 also closes; both launchers control same actual dialog ID. Phone and desktop screenshots are fixture evidence, not authenticated product acceptance.

Gates: full npm run lint, npm run typecheck and npm run build passed. After matching the exact max-width900px query, targeted component ESLint and production build passed.254 other tracked source files byte-identical; total255. Inventory remains1521 registry entries; seven positional navigation control IDs migrated by same ordered semantic fingerprints, retaining prior review states. No route, label, permission or business-operation changes.

Independent official Claude Code2.1.292: claude-opus-5-5 / medium, completed,1 turn,0 tool calls, readOnlyViolation=false, PASS. Orchestrator reviewed complete diff. The review's Vercel note is resolved: the sole additional config change disables deployment for this exact preservation branch, as explicitly authorized; existing mappings untouched. No PR; workflow is pull_request-only; commit skip-ci.

Open: actual Next client-navigation/path-change/unmount UAT, provider/session/sign-out, authorized roles and wider R1/100% semantic/runtime coverage. This evidence does not close these gates. Owned fixture stopped, port3565 has no listener; temporary browser tab closed and viewport restored. Permanent original reference stays available.
