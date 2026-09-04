# Quality Gates

## Principle

Quality gates exist to prevent both unsafe shortcuts and ceremonial over-testing. The depth of evidence must match the risk of the change.

## Universal gates

Every implementation change must satisfy, where applicable:

- formatting/linting;
- static/type checks;
- automated tests for changed behavior;
- build verification;
- no committed secrets or sensitive test data;
- review of tenant-boundary impact;
- migration review for persistent-data changes;
- documentation update when behavior or a governing decision changes.

## Critical-domain gates

Changes involving the following require stronger evidence:

- authentication or authorization;
- tenant isolation;
- payroll or financial calculations;
- finalized/locked records;
- audit-sensitive operations;
- integration credentials or external trust boundaries;
- destructive or irreversible data operations.

Expected evidence may include targeted regression tests, negative authorization tests, clean-database migration rehearsal, state-transition verification, and independently reviewable output.

## Database gate

Database/schema changes should be reproducible from a clean supported baseline. Migrations must not rely on manual production-only state.

## Tenant isolation gate

A feature that stores or reads tenant-owned information is incomplete until cross-tenant access is explicitly prevented and tested at the authoritative enforcement layer.

## Financial correctness gate

Financial results must not depend solely on mutable current configuration. Finalized outputs require traceability to the rules and inputs used.

## Release gate

A release candidate must be evaluated against the agreed release Definition of Done on the exact candidate revision. Passing unrelated or older CI does not qualify a different revision.

## Anti-patterns

- weakening tests to make a build pass;
- relying on hidden manual database edits;
- treating UI visibility as authorization;
- declaring a critical workflow complete without authoritative-state verification;
- adding infrastructure that has no current operational requirement merely to make the architecture appear more sophisticated.
