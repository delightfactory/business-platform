# Documentation Map

This repository treats product and engineering documentation as part of the product baseline.

## Structure

- `00-product/` — product charter, principles, target problems, and non-goals.
- `01-research/` — market, architecture, compliance, and internal reuse research that informs decisions.
- `02-blueprint/` — master platform/domain blueprint and release-level product decomposition.
- `03-architecture/` — architecture principles and Architecture Decision Records.
- `04-product-specs/` — implementation-ready product specifications once Phase 0 decisions are sufficiently mature.
- `05-engineering/` — engineering, database, security, privacy/data-handling, testing, and quality standards.
- `06-governance/` — decision log, source-of-truth rules, specification lifecycle, repository governance, change control, Definition of Ready, and Definition of Done.
- `07-reuse-audits/` — controlled audits of donor systems and reusable implementation assets.

## Source of truth

Documentation authority is scope-aware. A newer document does not automatically override an accepted baseline. Material changes require explicit amendment or supersession.

See `06-governance/source-of-truth.md` for the governing hierarchy and conflict-resolution process.

## Documentation lifecycle

1. Research identifies evidence or constraints.
2. Product/architecture discussion produces a proposed decision.
3. Accepted material decisions enter the Decision Log and, when needed, an ADR.
4. Blueprint/release documents are updated.
5. Product specifications move through the lifecycle defined in `06-governance/spec-lifecycle.md`.
6. Implementation begins against a Frozen specification when the work meets Definition of Ready.
7. Implementation and verification proceed against those accepted baselines.
8. Material changes preserve history through amendments or explicit supersession.

## Public-safe documentation

While this repository is public, documentation must not include private commercial agreements, customer-confidential information, credentials, private keys, production data, or verbatim proprietary source material from internal donor repositories.

Sensitive product data must also follow `05-engineering/data-classification-and-privacy.md`.