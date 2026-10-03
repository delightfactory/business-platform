# Cube 4 numerical statutory draft authoring

Bounded Compliance authoring extends the existing reference dossier. It does not issue, activate or qualify a calculation pack. No legal constants were seeded and no real net/payable was enabled. The owner's official 2026 numerical results/portal availability remains unavailable; independent legal qualification stays open.

## Implemented behavior

An explicitly authorized Compliance operator can enter tax treatment, personal exemption, income-column selection basis, up to 16 schedules with up to 32 marginal bands each, insured-wage bounds/category, up to six distinct insurance branches and percentage contributions, reviewed tax deductibility and base-wage tax treatment. The two tax/base-treatment decisions require explicit selection when authoring a new numerical definition. Percentages and monetary values are stored as exact decimal strings; frontend does not perform financial arithmetic or accept free-form formula/JSON editing.

Validation rejects unknown fields, unsupported forms, invalid/inverted boundaries, duplicate branches, nonfinite/scientific amounts, out-of-range percentages and total contribution rates over 100 percent. The final income schedule and marginal band remain open ended. Existing fixed adapter rounding conventions are shown in Arabic; this UI does not invent new rounding options or determine legal obligation months.

Numerical payload participates in authority locking, current-revision CAS and actor/attempt receipt intent. Repeated identical saves return the original receipt; changed intent cannot reuse it. Earlier reference-only versions remain readable. The existing eight-argument metadata-only endpoint preserves numerical values on later metadata edits and preserves its original receipt contract. Explicit removal through the numerical endpoint appends a version without numerical rules and retains history.

Current and historical numerical definitions have human-readable collapsed summaries. Controlled fields retain rejected values. Every numerical data mutation, including add/delete buttons, marks the parent form dirty and invalidates old saved confirmation. Unknown/stale/pending states freeze numerical edits with the rest of the dossier.

## Evidence and limits

- `cube4-statutory-numeric-drafts-qualification-v2.json`: 24 new and 35 metadata regression assertions each on local baseline 141, rollback, PASS. The initial harness expected 34 metadata assertions despite 35 passing output lines; original failure retained and successful upgrade logs reused without rerun.
- `reviews/cube4-statutory-numeric-drafts-review.json`: initial P2 dirty-confirmation finding retained. `review-v2.json`: six current source hashes, PASS after explicit parent dirty callback. Independent review is a read-only Codex reviewer, weaker provider separation than a different-provider review.
- Final TypeScript and focused statutory UI ESLint exit 0 (session 42104); tracked whitespace check exit 0.
- `cube4-statutory-numeric-drafts-local-install.json`: exact reviewed migration installed once into both named local QA databases, ledger 141 to 142; prior dossier content/heads, packs and input histories unchanged, no numerical rules seeded.
- `cube4-statutory-numeric-drafts-ui.json`: first actual browser journey PASS. A rate of 101 is rejected by the server while fields/rows remain; correction saves one new revision with `10.1256`, `1.1256` and `123.45` intact. Structural unsaved change hides old confirmation; reload restores saved rules. Prior reference-only revision remains intact. RTL/responsive 390/820/1280 and existing pack/input digests unchanged. Phone/desktop screenshots inspected.

Synthetic local dossier advances from revision 5 to 6, with one additional immutable version/receipt. No production change, commit or publication occurred. This evidence qualifies bounded draft authoring, not actual dropped-response numerical browser recovery, complete replay of all migrations, build/full-cube regression, pack issuance, integrated financial review or official statutory correctness.

Next: reviewed numerical comparison evidence and issuance using the existing adapter schemas, then authoritative employee/month/duration composition into financial review. Do not rerun these successful authoring suites without a relevant change.
