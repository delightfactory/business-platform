# WP1–WP2: shared visual foundation

- Concept C tokens (light, dark, system) and four company palettes; legacy aliases retained.
- Alexandria 500/600 headings; IBM Plex Sans Arabic 400/500/600/700 body.
- Self-hosted Arabic and Latin subsets with explicit Unicode ranges and swap; Cairo removed.
- Offline page fonts and precache asset byte-integrity hashes updated; caching behavior unchanged.
- Owned icon allowlist; typed UI primitives, form hints/errors, Radix Sheet, segment filters, transient Toast.
- Development-only component gallery; production returns notFound.
- Status display adapters reuse current channel/leave labels without changing state or authority.
- Focused validation: all 120 text/background pairs pass WCAG AA; all 19 precached assets match SHA-256.
- Build and final rendered comparison are consolidated by the orchestrator after integration.
- No backend, permission, action, financial, or offline-submission behavior changes.
