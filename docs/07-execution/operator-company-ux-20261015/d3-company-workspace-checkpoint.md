# Operator company workspace checkpoint

Implemented the Operator's company context, not the tenant/company users' workspace. The latter still waits for acceptance of the entire Operator.

Services, commercial limits and lifecycle now share a server-rendered company header and permission-filtered section links. Each header uses its section's already-authorized snapshot; there is no extra company read. Search/page context survives section changes and return to the directory. All six former list/detail routes redirect to the canonical company directory/sections. The obsolete cross-task component and save-before-navigation warning are removed.

Services use controlled switches with stable names, confirmed allocation state and company-wide submission locking. Dependency changes require an explicit plan sheet; durations and optional notes are secondary controls. Finite grants survive OFF/ON; expired/unknown allocations require explicit duration. Temporary denial remains available and its end date does not promise automatic activation. Display dates come from the server. Suspended/archived tenant access is distinguished from retained service grants.

Limits have inline editors, usage meters, live below-usage consequences and optional notes. Missing/conflicting state is explicit. Lifecycle uses a confirmation sheet with company identity, effects and mandatory reason; archive restoration still returns to suspended before a separate activation. No authority, lifecycle or statutory safety rule is relaxed.

Unknown responses lock mutation controls until a deliberate read. Current read results are never attributed to a specific previous attempt. Stale data requires another user choice. Successful mutation results invalidate the relevant Next route snapshots, preventing an old initial snapshot from resurfacing on navigation. Lifecycle also invalidates the other company sections and directory.

## Observed before/after journeys

One representative after run per completed journey, under the same full synthetic Operator role. The before revision is9a98ed8; the after implementation is the commit containing this checkpoint.

| Journey | Before activations | After activations | Before required fields | After required fields |
|---|---:|---:|---:|---:|
| OPJ2 enable Payroll with People absent | 6 | 2 | 2 reasons | 0 |
| OPJ3 ordinary Payroll OFF | 3 | 1 | 1 reason | 0 |
| OPJ4 lower users limit below usage | 2 | 2 | number + reason | number |
| OPJ5 suspend and restore | 4 | 4 | 2 reasons | 2 reasons |

These journeys start in the selected section and require no navigation. Service after runs used fresh Company03 with the same visible initial state as before Company02: active, all five services missing, identical role/owner fixtures. This mapping avoids deleting history or disguising legacy duration uncertainty. Limit/lifecycle after runs used the original Company02. Its usage2/limit10 precondition was restored once through the authorized legacy limit RPC; history was retained. Core lifecycle metrics exclude the initial section-entry link. OPJ1 and OPJ6-8 after measurements remain for the following stages.

## Focused runtime evidence

- Real browser: dependency plan approved, two services enabled, Payroll disabled by one switch.
- Users usage2/limit10 reduced to1; live warning before save and final usage2/limit1 after save, with existing memberships retained.
- Company02 suspended and restored with reasons; current state, allowed actions and access banner updated from server reads.
- Native date input issue found during QA: browser-visible date could differ from the last React event value. Submission now reads FormData and retains that submitted date. A subsequent finite Attendance grant, OFF and ON all displayed3 November2026.
- Route snapshot issue found during hot reload; mutations now revalidate canonical snapshots. Subsequent navigation showed the authoritative grant state.
- One scoped transport fault blocked exactly one action POST. UI reported unknown and disabled all five switches. No automatic second POST occurred. Blocking was removed, explicit read restored control, and the grant remained enabled. CDP network instrumentation was disabled and raw event objects discarded; no browser-network modification remains.
- Commercial-only synthetic login: services usable, lifecycle link absent, direct status URL denied. Full manager session restored afterwards.
- Desktop1366, tablet768 and phone390 inspected. No horizontal overflow. Representative service desktop/mobile and mobile plan images retained externally; plan capture was canceled without applying it. Temporary viewport override reset.

TypeScript, focused ESLint and final coherent build results are recorded in the run gate log before this source slice is committed. No financial SQL suite is repeated for these interface changes; D2 database evidence remains applicable. Full Operator coverage/visual acceptance and independent Claude review remain open.

Storage: worktree, dependencies, caches and evidence remain outside OneDrive. Active dependencies/QA are retained for D4-D7. Only three representative images are kept for this slice; no reclaimed-byte or cloud-quota claim is made.
