# R1-NAV-01 — mobile menu recovery on desktop transition

Base eb223680a77625dd00b6bfaaf6ad378507b3ac6b, now remote-verified. Owner explicitly continues implementation in economical mode. Class C maintenance within accepted frontend adaptive/accessible navigation; broader navigation/authority redesign remains Proposed. Use pinned Concept C reference and compatibility review; preserve all routes and server-provided destinations.

Actor/job: operator/tenant user opening existing sections and continuing after viewport expansion. Native dialog must not remain invisibly open with body scroll locked after mobile navigation is hidden above900px. Both launchers must identify their controlled dialog. No new sections, default role, permission, session/logout behavior or business operation.

Before: actual component mounted with real React/native browser dialog, actual compiled CSS, synthetic props and stubbed Next link/pathname/sign-out.390px open→1366px has dialog.open=true,display:none,body overflow:hidden. One manual Escape then closes/restores. Proposed after: breakpoint transition closes through existing native onClose cleanup, zero manual recovery steps. N/C/I and destinations unchanged. Enter/open, Escape/close button, focus return, repeat open/close and tablet behavior must remain usable. This fixture does not qualify Next client-router or real authorized tenant journeys.

Implementation: effect subscribing to the inverse of the exact CSS matchMedia max-width900px with cleanup; useId links both aria-controls to the existing dialog. CSS breakpoints unchanged. Preserve existing overflow ownership/unmount cleanup and native modal focus/escape semantics. No custom focus trap or body style overwrite outside existing owner.

Gates: actual browser lifecycle and viewport evidence at390/768/900/901/1366, existing-destination preservation; lint/typecheck/build; source inventory fingerprints and review-ID history; bounded independent Opus5.5 Medium review. Provider/session UAT and full R1/100% remain open. Exact branch Vercel deploymentEnabled=false, PR-only workflow/no PR/skip-ci preservation.

Qualified bounded maintenance: native fixture evidence and independent PASS in docs/07-execution/evidence/ux-r1-navigation-20261007. All listed broader runtime gates remain open. No full R1 closure.
