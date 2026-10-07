# Mandatory journey improvement contract

Authority: explicit owner instruction on 2026-10-07. This ongoing requirement binds Codex, Claude and every project implementer/reviewer. It is a project instruction, not a change to global preferences or existing Frozen business rules. Individual redesign specs remain Proposed until their required governance acceptance.

## Required for every slice

Before planning code, define actor and permissions, task frequency/cost of error, start and successful endpoint, actual supported operations, system-derived context, decisions/inputs required from the user, normal path, empty/loading/denied/invalid/stale/unknown-result/provider-failure paths and recovery/cancellation where supported.

Review every decision: does it change the business outcome, need this actor now, or belong to system-derived context? Remove unnecessary choices, repeated context selection, redundant navigation and duplicated forms; group the information needed for one decision. Use progressive disclosure for advanced/rare options. Preserve every actual operation through an obvious usable entry. Required confirmation/reason/financial review stays explicit; defaults cannot silently change business intent.

Each state has a clear purpose, dominant next action, honest result and useful continuation. An unavailable action explains the cause and responsible path. Failure preserves safe non-secret inputs and context; passwords, tokens, location payload and protected attempt signatures follow their existing security/storage contracts. Unknown financial outcomes remain unknown until authoritative resolution, with no speculative new request.

## Measured improvement, not appearance alone

Record a before/after run with the same actor, data, viewport, task start/goal and contract. Measure N navigations, C repeated context selections, P competing primary actions per state, I required manual inputs, B recovery steps; also record backtracking, successful completion and clarity of confirmation/next step. A metric can remain unchanged when already optimal or necessary; explain with evidence. Prefer faster understanding and task completion over deleting required checks. Do not claim a numerical improvement from source links alone.

Accessibility and responsive proof include Arabic/RTL wording, persistent labels, keyboard/focus, mobile targets, meaningful status/errors, loading/empty states and content at 390/768/1366px where the slice differs. Match source-authoritative access and business behavior.

## Acceptance verdict

Every review must return: task completion verdict, capability/role/state coverage verdict, simplicity verdict with before/after evidence, failure/recovery verdict, responsive/accessibility verdict, preserved invariants, open decisions and exact next action. `not-run` is separate from `pass`. An author cannot be sole acceptance reviewer.

Block acceptance for dead ends; hidden required operations; false success; lost safe values/context; unexplained disabled actions; repeated choices without reason; unauthorized exposure; altered financial/privacy guarantees; unmeasured claimed improvement; or missing evidence for critical cases. If a slice preserves an already efficient path, document why and prove no regression. Freeze only the scoped specification whose cases and amendments are ready; do not demand unreviewed whole-platform scope to accept a bounded slice.

## Delegation and continuity

Codex copies this requirement into every brief and checks it independently. Claude explicitly addresses it in authored specifications and review verdicts. Source/context changes invalidate affected evidence and require targeted re-review. Store maps, scenarios, metrics and deviations in the shared reference branch and issue #47 so the next session starts from the same contract.
