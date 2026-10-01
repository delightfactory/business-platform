# Observed break overlap — local qualification

This slice supports an explicit immutable fixed-break placement without rewriting old Attendance interpretations or facts. It is a prerequisite for half-day Leave integration; it does not complete that integration.

## Changes

- `20261001031110_cube3_time_observed_break_overlap.sql` appends nullable `applied_break_minutes` to interpretations. For a mapped fixed break, subtract only its resolved UTC overlap with actual punches. Retain the full scheduled break separately. Legacy positive breaks without placement retain their existing aggregate subtraction.
- Invalid or ambiguous break placement requires review and emits no net minutes. Historical rows remain unchanged.
- A private, client-revoked stable helper fingerprints the raw punch/correction inputs and frozen Work Instance/policy fields. Interpretation and clean auto-approval use the same input definition under the existing Work Instance lock.
- Manual and automatic facts and bounded day responses expose the applied break. Exact function anchors fail closed instead of silently changing unrelated authorization or lifecycle code.
- Second-resolution punches retain existing PostgreSQL integer-minute rounding; this is an implementation rule, not a legal entitlement rule.

## Executed verification

Node 24.16.0, Supabase CLI 2.106.0, PostgreSQL 17.6. Only isolated loopback QA databases were changed, through the normal CLI migration chain.

- Authoring QA: 54 focused pgTAP assertions passed, using actual authenticated People, policy, punch and approval RPCs.
- Fresh application-chain QA and baseline-source-clone upgrade QA: each passed 346 assertions in seven files: observed overlap (54), manual Attendance (110), clean auto-approval (31), overtime (41), bulk queue (21), CSV import (56), half-day mapping (33).
- Cases include work after the break (180 net), partial overlap (90 gross/30 applied/60 net), second-resolution overlap (90/30/60), full shift (480/60/420), overnight, DST review, legacy aggregate behavior, immutable history and actual clean automatic approval.
- Both target chains have 99 migrations. Final function definitions and ACLs match. Full-row digests of the baseline 5 employees, 4 employments and 2 account links remain unchanged against the untouched source database.
- Commands: `qa-tests.mjs` for authoring; `qa-approval-tests.mjs` for each target; `qa-approval-preservation-compare.mjs slice11`. Evidence is under the local execution run, including `slice11-function-data-comparison.json` and per-file logs. Tests preceded this slice commit; a scoped manifest binds the tested migration/test bytes to the commit and excludes concurrent UI work.

Independent review corrected a SQL substring syntax error, invalid pre-existing policy-range values in the test fixtures, and the earlier draft's auto-approval fingerprint mismatch and rejection of valid second-resolution punches. No main merge, deployment, remote migration or Cube 3 closure is claimed.
