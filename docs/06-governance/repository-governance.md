# Repository Governance

## Purpose

Make the repository itself a reliable product and engineering baseline rather than only a code storage location.

## Main branch

`main` represents the accepted project baseline.

Material product, architecture, security, schema, or implementation changes should reach `main` through reviewed pull requests rather than undocumented direct edits.

During early documentation-only setup, direct bootstrap commits may be used only to create the minimum repository structure needed to establish this workflow.

## Working branches

Use focused branches for bounded changes. A branch should have a clear purpose and should not accumulate unrelated product decisions or implementation work.

Examples:

- `phase-0-governance`
- `foundation/tenancy`
- `hr/attendance-core`
- `fix/payroll-rounding`

Branch naming is a communication aid, not an architecture mechanism.

## Pull requests

A PR must make its intent reviewable:

- purpose and scope;
- explicit exclusions where ambiguity exists;
- governing decision/spec impact;
- tenancy/security/data impact;
- migration impact;
- financial/compliance impact where relevant;
- verification evidence;
- complexity impact.

Critical work must be qualified on the exact revision proposed for merge.

## Merge discipline

- Do not merge known critical defects or unresolved security/tenant-isolation failures.
- Do not weaken tests or governing requirements merely to obtain a green check.
- If the PR head changes after behavior-dependent qualification, re-run affected qualification.
- Keep unrelated scope out of a PR when separation materially improves reviewability or rollback safety.
- Prefer a clean history that preserves important decisions; do not optimize commit aesthetics at the cost of losing auditability.

## Baseline changes

A code PR must not silently introduce a Class A or Class B change defined by Change Control. Governing documentation must be updated in the same PR or in an already accepted prerequisite change.

## Public repository hygiene

While the repository is public:

- assume every committed file, PR description, issue, log, fixture, artifact reference, and screenshot may become publicly visible;
- never commit secrets, private customer data, confidential commercial terms, or proprietary donor-source excerpts;
- use synthetic/sanitized evidence;
- review dependency/configuration files for accidental credential or endpoint leakage;
- decide licensing intentionally before inviting external code reuse or contributions; repository visibility alone does not define the project's licensing terms.

## Automation and protections

Repository protections and CI automation should be introduced when implementation begins and should enforce the risk-appropriate quality gates defined by the project. Protection mechanisms must support the governance model rather than become ceremonial blockers with no corresponding product risk.

## Emergency changes

If a future production emergency requires an exceptional path, the exception must be narrowly scoped, reviewed as soon as operationally possible, and followed by restoration of normal tests/documentation. Emergency handling must never become a routine bypass mechanism.