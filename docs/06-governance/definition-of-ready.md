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
- acceptance criteria are testable;
- required policy/configuration behavior is defined;
- unresolved decisions that could materially change implementation are closed or explicitly deferred.

## Additional requirements for critical work

Payroll, authorization, tenant isolation, financial state, and destructive operations require explicit invariants and failure behavior before implementation begins.

## Not Ready examples

- "make payroll flexible" without defined policy boundaries;
- "support all biometric devices" without an adapter scope;
- "make workflows configurable" without concrete workflow cases;
- implementing a future domain merely to prepare for possible expansion.
