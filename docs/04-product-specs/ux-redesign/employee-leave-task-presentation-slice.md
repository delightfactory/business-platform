# R6-CORE-TASK-01 — employee leave creation and detail presentation

Baseline `982d3ee20fce82da1e23df81623b612b83ee5b43`; branch `codex/ux-core-leave-task`. Implemented presentation scope, not Frozen full R6a or runtime closure. Core approved R0–R8 plan is priority; D16 integration deferred until core completion, with saved work preserved. D2/D3 navigation and D8 auth return remain pending and unapplied.

## Journey and source contracts

Employee starts from the existing own-leave overview. Creation remains a focused full page: dates -> authoritative eligible types -> conditional half-day -> mandatory reason3–500 -> explicit submission -> current own detail. Dates are visually grouped side by side above640px and stacked on narrow screens; no input/order/default/automatic request semantics changed. Reason guidance is visible and associated by `aria-describedby`. Existing fieldset gating moved from inline CSS into the module without changing disabled logic. Safe values, options read/retry, sequence fence and operation key behavior remain unchanged in the mounted component; no new storage or recovery protocol.

Detail remains current source-authoritative status, units and dates, reason/source, replacement references, optional day detail, permitted state-dependent withdrawal/cancellation and paged cancellation history. Existing state notes now precede summary facts and long reason; the reason/source use a full-width definition list. A consistent narrower task column groups existing sections, without hiding or merging their capabilities. Submitted withdrawal and approved cancellation gates/reasons/version/key/pending-history/failed-read safeguards remain unchanged. No action, parser, RPC, SQL, authority or financial effect changed.

## Reference decisions

Pinned Concept C HTML LF SHA256 `AF24015383285EAF543E9C95839F55225C2FE9817DD8B1E16D2084F857725508`; original source retained. Reference modal is a simulated example. Existing dates-first server eligibility, required reason, full-page form and conditional half-day control govern over its type-first/optional note/quota math. Cairo/radius8/40desktop44mobile/current authorized shell contracts retained. Demo has no source-authoritative own-detail/cancellation equivalent: detail comparison covers visual language and content hierarchy, not literal screen equivalence or new business authority. These are preserved source contracts; no pending amendment considered accepted.

## Evidence and verdicts

[Version-bound evidence](../../07-execution/evidence/ux-core-leave-task-20261008/README.md) contains exact source fingerprints, before/after three widths, reference form renders, read-only fixture checks and independent reviewer report.

-16 focused actual-source fixture checks pass: five create states, seven request states, three failed-read action-block cases and unchanged pre-render client handlers/hooks/identity/options source. Fields, keys, ordered read calls and supported destinations retained. No mutation executed.
-Build including TypeScript and changed TSX ESLint pass once for this batch. Reuse last global lint failure evidence: unchanged historical CommonJS evidence scripts, no rule weakening or unrelated cleanup.
-Browser samples390/768/1366: loaded Cairo, no horizontal overflow. Desktop date controls previously at y356.8/458.4 now both356.8; mobile still stacked (y344.4/451.6). This measures geometry, not faster completion. Sample mobile date/select/textarea/submit-adapter targets>=44px and visible2px date focus; existing checkbox target not newly qualified. Browser version unavailable.
-Codex + official Claude Code2.1.292 Opus5.5 Medium: **MATCH WITH ACCEPTED DEVIATIONS**, for visible new-form and detail read content. Claude read12 images and changed client source. Initial review exhausted its turn limit before final text; same session resumed solely to produce the verdict, with no repeated reads, source changes or provider substitution. Read-only violationfalse.
-N/C/P/I/B and completion of hydrated creation/withdrawal/cancellation not measured. Existing necessary dates/type/reason decisions retained; no numerical journey reduction claimed from layout. Coverage1523/manual review statuses retained; no semantic/runtime promotion.

Open: submit/cancel/spinner below viewport, actual withdrawal/cancellation forms (fixture placeholders), pending cancellation/history/full parent/dark/provider and complete end-to-end role/state qualification. Current unknown mutation/session limitations remain explicit. No full R6 acceptance claimed. Subsequent core work must qualify the actual full journey in grouped checks and continue the remaining approved phases; no additional recovery backend development before core completion.

### Historical cancellation state clarity — 2026-10-09

Real employee→HR approval→employee cancellation→HR acceptance→employee terminal follow-up at3ccbf10 succeeds in owned synthetic GoTrue/Next/PostgREST. Cancellation history remains an immutable sequence, not the current decision. Each badge explicitly labels its state **after that historical movement**, and the section explains that the request's current state is above. Never replace a past pending event with accepted, infer a current state from an older page, change actor privacy, or alter actions/versions/reasons/paging. This is a text-only correction of an ambiguity found by official Opus5.5Medium56aa4d47; focused render/inversion and scoped visual review suffice without repeating unchanged real business flows or heavy suites. Full R6/R0–R8 still requires remaining applicable acceptance.
