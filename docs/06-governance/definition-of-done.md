# Definition of Done

A change is Done only when implementation, verification, and governing documentation agree on the same behavior.

## Functional completion

- acceptance criteria are satisfied;
- expected failure/edge behavior is covered where material;
- every material workflow introduced or changed has a reachable supported operational end state or an explicit external handoff;
- cancellation/rejection/correction/reversal/reconciliation paths are complete where required by the governing specification;
- no known critical path is left dependent on undocumented manual intervention;
- a deferred downstream capability does not leave the current workflow stranded without a clear status, export, operator action, or other governed continuation path.

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
- users can identify the current state, available next action, and final/handed-off outcome of the workflow;
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
- corrections use an explicit adjustment/reversal/amendment path rather than hidden mutation;
- operational completion includes a defined reconciliation/settlement/payment-status or external-handoff state where actual money movement is outside the product scope.

## Documentation completion

- public behavior and material constraints are documented;
- decision log/ADR is updated if a baseline changed;
- release scope is updated if the change alters commitments;
- deferred operational depth that is intentionally postponed is recorded in the appropriate capability/roadmap backlog rather than silently forgotten.

## Qualification rule

Critical qualification evidence must refer to the exact revision proposed for merge/release. A later code change invalidates qualification evidence that depends on changed behavior.


## Operational-simplicity completion

Material user-facing work is not Done when it is merely functional. It must also demonstrate that:

- the primary task can be completed without understanding backend/database/security implementation concepts;
- redundant user input has been removed where the system can safely derive/default the value;
- advanced options do not clutter the ordinary workflow;
- exception-oriented views focus users on records requiring action;
- the current state and next action are understandable without reading technical documentation;
- failure messages identify the operational problem and recovery action;
- financial/security/compliance consequences remain explicit despite simplification;
- representative usability acceptance checks show no avoidable screens, fields or decisions in the primary flow.

A workflow may fail this gate even when automated functional tests pass.
