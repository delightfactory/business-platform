# Product Principles

These principles are guardrails for product and engineering decisions.

## 1. Platform-first, domain-bounded

The shared Platform Core must remain neutral to any single business domain. HR is the first business domain, not the architectural root of the platform.

## 2. Simple by default

A tenant should only experience the complexity required for its operating model. Optional capabilities must not become mandatory UX or data requirements.

## 3. Progressive complexity

Advanced contracts, approvals, integrations, reporting, and other controls should appear only when enabled and needed.

## 4. Commercial coherence over feature count

A release is ready when it completes a real customer job safely and coherently, not when it contains an arbitrary number of features.

## 5. Configuration before customization

Prefer bounded, validated configuration and entitlements over tenant-specific code. Customer forks are exceptional, not a product strategy.

## 6. No speculative generalization

Do not build generic engines, frameworks, or abstraction layers solely because they might be useful later. Generalize only after concrete use cases demonstrate the recurring need.

## 7. No harmful shortcuts

Speed does not justify weakening tenant isolation, authorization, financial correctness, data integrity, auditability, migration discipline, or security boundaries.

## 8. Reuse deliberately

Existing internal systems may be donors of patterns or code, but reuse must be audited. Legacy technical debt must not be inherited automatically.

## 9. Domain ownership

Each business domain owns its business rules. Cross-domain collaboration must use explicit contracts rather than hidden coupling.

## 10. Reproducibility for sensitive outcomes

Financial and compliance-sensitive outcomes must preserve enough historical context to explain and reproduce what happened.

## 11. Entitlements are product architecture

Commercial packages may change frequently. Product capabilities therefore map to stable entitlements; marketing package names and prices must not be hard-coded into domain logic.

## 12. Expand by adding domains, not rewriting the platform

Future CRM, Sales, Inventory, Procurement, and Finance capabilities should extend the platform through bounded domains and shared core services.

## 13. No dead-end workflows

A capability is not operationally complete merely because its main create/edit screen works. Every supported workflow must reach a clear, supported operational outcome.

For each material process, specifications must define the relevant completion, rejection/cancellation, correction/reversal, archival/closure, reconciliation, or external-handoff path. If a downstream capability is deliberately deferred, V1 must still provide an explicit safe stopping point or handoff such as an export, status, operator action, or documented external continuation.

Post-launch expansion should deepen operational completeness and automation without requiring the original flow to be abandoned or rebuilt from scratch.


## 14. Complexity stays behind the product boundary

The product absorbs technical and domain complexity so ordinary users can operate through business intent, current state, and a clear next action.

- backend state machines, IDs, versioning, tenancy/security mechanics, integration transport and calculation internals are not normal user-facing concepts;
- safe defaults and derived values replace repeated or unnecessary user input;
- advanced configuration is progressively disclosed to the roles and situations that need it;
- exception-oriented workflows focus attention on items requiring judgment rather than forcing users to review normal records one by one;
- technical errors are translated into plain-language operational outcomes and recovery actions;
- mobile and desktop composition may differ to keep the task direct on each device;
- simplicity never means hiding material financial, security, compliance, approval, or irreversible consequences.

A workflow that is technically capable but unnecessarily confusing, repetitive, or implementation-shaped is not considered product-complete.
