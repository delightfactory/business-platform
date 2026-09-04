# Source of Truth and Conflict Resolution

## Purpose

Prevent implementers from resolving conflicting documentation by guesswork, recency alone, or code precedent.

## Governing rule

A document is authoritative only within its stated scope and lifecycle status. A newer document does not automatically override an older governing baseline unless it explicitly supersedes or amends it.

## Authority model

Use the following order when determining implementation authority:

1. **Explicit accepted amendment or superseding decision** that names the affected baseline.
2. **Accepted ADR** for the technical decision it governs.
3. **Frozen product specification** for the capability/work item it governs.
4. **Accepted product/architecture baseline** such as the Product Charter, Product Principles, Master Product Blueprint, or accepted Decision Log entry.
5. **Research and audit material** as supporting evidence only.
6. **Implementation/code behavior** as evidence of current behavior, never as automatic authority for a conflicting product or architecture decision.

The hierarchy is scoped rather than absolute. A narrow frozen specification may define implementation behavior within its capability while remaining constrained by higher-level accepted product and architecture principles unless an approved amendment explicitly changes those principles.

## Conflict handling

When two authoritative documents appear to conflict:

1. stop implementation of the conflicting assumption;
2. identify the exact conflicting statements and their lifecycle status;
3. determine whether an explicit amendment/supersession already resolves the conflict;
4. if not, raise and record a decision before implementation continues;
5. correct the stale documentation so the conflict is not left for future implementers.

## Prohibited shortcuts

- "latest file wins" without explicit supersession;
- silently following code because documentation disagrees;
- rewriting history so a changed decision appears to have always been intended;
- using research notes as if they were approved requirements;
- implementing an unresolved conflict and documenting it afterward.

## Exact-revision principle

When a specification or baseline is used to qualify implementation, the repository revision containing that baseline should be identifiable. Material changes to the governing baseline require re-evaluation of dependent implementation assumptions.