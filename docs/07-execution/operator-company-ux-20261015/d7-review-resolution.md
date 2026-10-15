# D7 independent review and bounded correction

Official first-party Claude Opus5.5 Medium reviewed pinned946411e in session3b2663ec-02f0-42b8-b2f3-df1a18e700b1. Process exited0 with success and sourceUnchanged=true. Full Arabic report is claude-operator-review-r1.md. It is explicitly source/visual review, using Codex-observed runtime; Claude did not independently run a browser or tests.

R1 found one blocking medium issue F1: opening duration for an OFF finite grant defaulted to indefinite, risking an unintended commercial extension. The editor now derives its initial mode/date from the saved grant deadline (resume_last_day for an OFF finite service), never from a temporary denial's end date. Expired/unknown grant history still requires an explicit date.

Related low-severity F2/F3 are fixed in the same component: only a granted People allocation provides the dependent-date hint/max; a replacement confirmation plan announces that the plan changed before asking for approval again. Optional F4 is also corrected locally: visible plan entries use serviceOrder (People first), consistent before/after state labels and a required marker for derived changes. No backend contract or business invariant changes.

## Actual required runtime check

The existing finite Attendance fixture was identified by a read-only database query: tenant fcd8be5e-486d-474d-8b06-989064632140 (Company03), original end2026-11-03T22:00Z, displayed last day3 November2026 in Cairo. It was not recreated. Normal UI switch OFF retained resume metadata. Opening duration showed pressed 'حتى تاريخ' and native date value2026-11-03 without editing. The dialog was canceled without submission. Normal switch ON restored enabled Attendance still through3 November. One representative image retained externally. An initially opened Company04 URI was read-only and had no finite attendance; no mutation was made there.

TypeScript, scoped lint and one coherent build are required and recorded in external d7-fix gates before this correction commit. No database/financial suites repeated, as requested by the reviewer.

## Review decisions retained

- Exact viewport comparison deviation accepted by Claude; OPJ1/6 remain labeled1280x720, early OPJ2/3 remain unrecorded. No synthetic company recreation requested.
- O-only receipt, accepted invitation continuation, browser add and component-only ready/issued stage evidence accepted as non-blocking for the reasons in R1. No official issuance evidence fabricated.
- Optional F5/F6/F7 and visual polish remain explicitly non-blocking recommendations, not claims of completed work. F7 is inherited invitation reissue/delivery handling; preserve it for the recipient/invitation lifecycle audit rather than introducing a new retry contract here.
- No new operator audit-read or conflict-repair capability was added (O-01/O-02 remain existing scope decisions).

R1 conditioned whole-Operator acceptance on F1 plus the focused checks above and explicitly did not require a full review rerun. A short same-session closure check will verify the correction and record the final verdict. Company workspace is still unaccepted and cannot start implementation before this closes.
