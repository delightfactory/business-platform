# Specification Lifecycle

## Purpose

Ensure implementation is driven by reviewed product specifications rather than assumptions invented during coding, while preserving change history when requirements evolve.

## Lifecycle states

### Proposed

The specification is being drafted or reviewed. It may guide discussion but must not be treated as an implementation baseline.

### Frozen

The specification has been reviewed and accepted for implementation. Material scope, behavior, invariants, and acceptance criteria are fixed unless changed through an amendment.

### Amended

A later approved amendment changes part of a Frozen specification while preserving the original history and rationale.

### Superseded

The specification has been replaced by a newer governing specification. It remains in history but is no longer the active implementation baseline.

### Withdrawn

The proposed or previously planned work is intentionally no longer part of the active product direction.

## Freeze criteria

A specification may be Frozen only when:

- the user/business outcome is explicit;
- scope and material non-goals are bounded;
- domain ownership and dependencies are known;
- material security, tenancy, data, and financial implications are addressed;
- required configuration/policy semantics are defined;
- failure behavior and critical invariants are explicit where relevant;
- acceptance criteria are testable;
- unresolved decisions capable of materially changing implementation are closed or explicitly deferred outside scope.

## Implementation rule

Implementation must not silently expand or reinterpret a Frozen specification. If execution reveals a missing material decision:

1. stop the affected assumption;
2. determine whether it is a clarification within the frozen intent or a material change;
3. document material changes through the approved amendment/change-control path;
4. resume implementation against the updated baseline.

Local technical details that preserve frozen behavior may remain implementation decisions and do not require amendments.

## Amendment rule

An amendment must identify:

- the specification and section it changes;
- the prior rule/behavior;
- the new rule/behavior;
- why the change is required;
- scope/dependency impact;
- migration/backward-compatibility impact where relevant;
- verification impact.

## Historical integrity

Do not edit a Frozen specification in a way that erases the fact that a material decision changed. Use an amendment or explicit supersession so historical implementation and qualification evidence remain explainable.

## Qualification relationship

When implementation is qualified against a Frozen specification, evidence should identify both the implementation revision and the governing specification revision. A material amendment invalidates prior qualification only to the extent that the changed requirement affects it; impacted behavior must be re-qualified.