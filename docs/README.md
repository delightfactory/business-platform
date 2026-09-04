# Documentation Map

This repository treats product and engineering documentation as part of the product baseline.

## Structure

- `00-product/` — product charter, principles, target problems, and non-goals.
- `01-research/` — market, architecture, compliance, and internal reuse research that informs decisions.
- `02-blueprint/` — master platform/domain blueprint and release-level product decomposition.
- `03-architecture/` — architecture principles and Architecture Decision Records.
- `04-product-specs/` — implementation-ready product specifications once Phase 0 decisions are sufficiently mature.
- `05-engineering/` — engineering, database, security, privacy, frontend/UX, testing, and quality standards.
- `06-governance/` — source-of-truth rules, decision log, change control, specification lifecycle, repository governance, Definition of Ready, and Definition of Done.
- `07-reuse-audits/` — controlled audits of donor systems and reusable implementation assets.

## Authority model

See `06-governance/source-of-truth.md` for the authoritative conflict-resolution model.

A newer document does not automatically supersede an older accepted baseline. Material changes require explicit amendment or supersession.

## Documentation lifecycle

1. Research identifies evidence or constraints.
2. Product/architecture discussion produces a proposed decision.
3. Accepted material decisions enter the Decision Log and, when needed, an ADR.
4. Blueprint/release documents are updated.
5. Product specifications move through the governed specification lifecycle and become implementation authority only when Frozen.
6. Implementation and verification proceed against the accepted/frozen baselines.
7. Material changes preserve history through amendments or explicit supersession.

## Experience baseline

User-facing implementation is governed by `05-engineering/frontend-ux-baseline.md`. Responsive/adaptive behavior, reusable design-system primitives, interaction states, accessibility, and UX-flow consistency are product-quality requirements rather than post-implementation polish.

## Public-safe documentation

While this repository is public, documentation must not include private commercial agreements, customer-confidential information, credentials, private keys, production data, or verbatim proprietary source material from internal donor repositories.
