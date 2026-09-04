# Definition of Ready

A work item is ready for implementation when the team can execute it without inventing material product or architecture decisions inside the code.

## Required

- user/business outcome is explicit;
- scope is bounded;
- out-of-scope behavior is stated when ambiguity is likely;
- relevant domain owner/boundary is known;
- dependencies are identified;
- security and tenant-isolation impact is understood;
- persistent-data impact is understood;
- data classification/privacy impact is understood where personal, financial, location, biometric-related, or otherwise sensitive data is involved;
- acceptance criteria are testable;
- required policy/configuration behavior is defined;
- the governing product specification is Frozen when the work requires a formal specification baseline;
- unresolved decisions that could materially change implementation are closed or explicitly deferred.

## User-facing work readiness

For material frontend/user-facing work, readiness additionally requires:

- primary user intent and workflow are understood;
- expected desktop/laptop and mobile behavior is defined where layout or interaction differs materially;
- reusable design-system primitives are identified instead of introducing duplicate base components;
- loading, empty, validation, failure, success, cancellation, and sensitive-confirmation states are considered where relevant;
- entitlement/permission-disabled behavior is understood;
- accessibility and touch/keyboard implications are considered where relevant.

Detailed pixel design is not required before implementation when existing approved patterns fully cover the workflow. The purpose is to prevent UI behavior and responsive semantics from being invented inconsistently inside feature code.

## Additional requirements for critical work

Payroll, authorization, tenant isolation, financial state, sensitive-data handling, and destructive operations require explicit invariants and failure behavior before implementation begins.

## Not Ready examples

- "make payroll flexible" without defined policy boundaries;
- "support all biometric devices" without an adapter scope;
- "make workflows configurable" without concrete workflow cases;
- implementing a future domain merely to prepare for possible expansion;
- starting implementation from a Proposed specification when material behavior is still unresolved;
- designing a desktop-only workflow and deferring mobile behavior to an unspecified later cleanup when the capability is part of the supported web application.
