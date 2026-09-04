# Documentation Map

This repository treats product and engineering documentation as part of the product baseline.

## Structure

- `00-product/` — product charter, principles, target problems, and non-goals.
- `01-research/` — market, architecture, compliance, and internal reuse research that informs decisions.
- `02-blueprint/` — master platform/domain blueprint and release-level product decomposition.
- `03-architecture/` — architecture principles and Architecture Decision Records.
- `04-product-specs/` — implementation-ready product specifications once Phase 0 decisions are sufficiently mature.
- `05-engineering/` — engineering, database, security, testing, and quality standards.
- `06-governance/` — decision log, change control, Definition of Ready, and Definition of Done.
- `07-reuse-audits/` — controlled audits of donor systems and reusable implementation assets.

## Authority order

When documents conflict, the newest explicitly accepted decision or superseding ADR takes precedence. Conflicts should be corrected rather than left for implementers to interpret.

## Documentation lifecycle

1. Research identifies evidence or constraints.
2. Product/architecture discussion produces a proposed decision.
3. Accepted material decisions enter the Decision Log and, when needed, an ADR.
4. Blueprint/release documents are updated.
5. Product specs are written only when the relevant work meets Definition of Ready.
6. Implementation and verification proceed against those accepted baselines.

## Public-safe documentation

While this repository is public, documentation must not include private commercial agreements, customer-confidential information, credentials, private keys, production data, or verbatim proprietary source material from internal donor repositories.
