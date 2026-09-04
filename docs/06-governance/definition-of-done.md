# Definition of Done

A change is Done only when implementation, verification, and governing documentation agree on the same behavior.

## Functional completion

- acceptance criteria are satisfied;
- expected failure/edge behavior is covered where material;
- no known critical path is left dependent on undocumented manual intervention.

## Engineering completion

- relevant automated tests pass;
- static/type checks pass;
- production build passes where applicable;
- migrations are reproducible where applicable;
- temporary debug/test artifacts are removed;
- generated artifacts are consistent where applicable.

## User experience completion

For material user-facing changes:

- the workflow behaves correctly at representative mobile and desktop/laptop viewport classes, and at intermediate sizes where the layout materially changes;
- no core workflow relies on desktop-only composition or accidental responsive shrinkage;
- shared design-system primitives are used or deliberately extended instead of duplicating recurring controls/patterns;
- loading, empty, validation, failure, success, and sensitive-confirmation states are complete where relevant;
- essential actions remain accessible across supported screen sizes and input modes;
- accessibility behavior is verified to the level appropriate for the affected components/workflow;
- UX acceptance evidence is reviewable when the change materially affects user interaction or layout.

## Security and tenancy completion

- authorization is enforced at an authoritative layer;
- tenant-owned data cannot be accessed across tenant boundaries;
- sensitive actions have appropriate auditability;
- no secrets or production-sensitive data are committed.

## Financial/compliance completion

For payroll, money, statutory, or finalized records:

- calculations/state transitions are deterministic and reviewable;
- historical outcomes remain reproducible;
- mutable configuration cannot silently rewrite finalized history;
- corrections use an explicit adjustment/reversal/amendment path rather than hidden mutation.

## Documentation completion

- public behavior and material constraints are documented;
- decision log/ADR is updated if a baseline changed;
- release scope is updated if the change alters commitments.

## Qualification rule

Critical qualification evidence must refer to the exact revision proposed for merge/release. A later code change invalidates qualification evidence that depends on changed behavior.
