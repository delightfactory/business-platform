# Change Control

## Purpose

Protect the product from accidental scope growth, undocumented architectural drift, and changes that trade long-term product integrity for short-term convenience.

## Change classes

### Class A — Product/architecture baseline change

Examples:

- changing domain boundaries;
- making an optional capability mandatory;
- changing tenancy/isolation strategy;
- changing entitlement semantics;
- changing payroll finalization guarantees;
- introducing a new platform-wide engine or infrastructure pattern.

Requirements:

1. documented rationale;
2. alternatives considered;
3. impact on V1 scope and complexity;
4. security/data/migration impact where relevant;
5. decision log or ADR update;
6. reviewed PR before implementation dependency.

### Class B — Feature scope change

Examples:

- adding/removing a V1 capability;
- expanding a workflow;
- adding a new integration required for release.

Requirements:

- explicit customer/job justification;
- dependency analysis;
- test/quality impact;
- release plan update.

### Class C — Implementation detail

Local implementation choices that do not change accepted product behavior, domain boundaries, security guarantees, or release scope may proceed under normal review.

## Scope expansion test

Before accepting material scope, answer:

1. Which current user or business job requires this?
2. Is it required for the active release?
3. Can it be safely deferred?
4. Does it introduce a new platform abstraction?
5. What existing capability becomes more complex because of it?
6. Does it create a customer-specific branch in behavior or code?

## No silent baseline changes

Code is not permitted to become the first place where a material product or architecture decision appears. The governing documentation must be updated in the same or an earlier reviewed change.

## Amendments over rewrites

When a frozen decision changes, preserve the rationale/history. Supersede or amend the prior decision rather than rewriting history to imply the new decision was always intended.
