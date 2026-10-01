# Shared Time calculator — local qualification

This prerequisite extracts existing observation and A2.1 Leave compatibility calculations into private, side-effect-free helpers for explicit review previews. It preserves the current full-day review behavior; fractional absence, covered-day facts and atomic joint Leave/Time approval remain subsequent work.

## Change

`20261001160000_cube3_time_shared_calculator.sql` adds `time.calculate_interpretation_values` with explicit frozen Work Instance/policy, canonical punches and settlement instant, and typed `time.apply_leave_context_to_interpretation`. The existing writer still owns locks, sticky exclusions/latest replacements, fingerprinting, interpretation append and status updates. The existing trigger still reads approved Leave context and Attendance capability before applying the overlay. Helpers retain rounding, diagnostics, legacy break behavior and unrelated interpretation fields. No client role can execute either helper; existing private writer/trigger ACLs remain revoked.

Server readers must supply the exact frozen tenant/template/version and canonical punch set. The helpers do not independently authenticate those identities. Base observations remain available independently of the current full-coverage overlay diagnostic, which future classification must preserve.

## Executed verification

Only isolated local Docker QA databases were changed. The untouched source database was read for upgrade preservation evidence.

- Normal CLI migration chains completed through 106 migrations in fresh application-chain and source-clone upgrade targets. Early draft application failed on PL/pgSQL row declarations and the SQL keyword schema cast; both source issues were corrected before successful normal application, without runtime function repairs.
- Each target passed 39 pgTAP files, 1784 assertions, zero failing files. The new focused file passed 50 assertions: fixed/flexible and odd remaining halves, overlap rounding, overnight/DST, strict settlement, malformed inputs, retained diagnostics/fields, zero preview effects and private ACLs. Existing integration, payroll projection, cancellation, replacement and People tests remained unchanged.
- Four real blocked races passed: Leave approval versus natural OUT/worked fact in both orders, and cancellation versus fact approval in both orders. `pg_blocking_pids` established the actual blocking edge. Exact metrics, stale rejection, ledger/reversal cardinality and immutable historical facts were checked. Function hashes were unchanged throughout execution.
- A read-only parity query reproduced all four complete stored interpretation rows from explicit observation inputs and their frozen Leave evidence, including interpretations deliberately stale after cancellation.
- Fresh/upgrade function definitions and ACLs match. Original full-row digests of five employees, four employments and two user links match the untouched source.
- An independent read-only reviewer accepted the final migration/test sources with no blocker. Clean-code and test guard review found no remaining blocker.

Commands and evidence are retained under the local execution run: `qa-calculator-tests.mjs`, `qa-calculator-preservation-compare.mjs slice23`, `qa-calculator-wrapper-parity.mjs`, and `runroot/calculator-controlled-races/qa-calculator-races.mjs`. Evidence includes both test summaries, `slice23-function-data-comparison.json`, `slice23-wrapper-parity.json`, race result `9619200f-8c9c-4cfb-ab2c-f3e7e73e57ab`, and the 106-migration current source capture. Root completed the bounded implementation/tests after stopping an incomplete OpenCode relay; relay completion alone was not accepted as qualification.

No UI behavior changed in this extraction. This qualification does not establish fractional/full-day fact support, joint multi-date reconciliation, annual legal entitlement policy, Cube 3 completion, main merge or deployment.
