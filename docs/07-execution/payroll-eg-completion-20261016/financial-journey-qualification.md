# Representative public financial journey — engineering qualification

16 October 2026. Scope: software behavior on synthetic data, NOT Egyptian legal acceptance. No production change, real company data, bank transfer or paid-plan change.

## Current-source proof and isolation

Source is current owned QA container supabase_db_business-platform-operator-ux-20261015. Created dedicated database business_platform_cube4_adam_positive_qa from a schema-only pg_dump of public/platform_core/platform_private/people/payroll/time/leave/auth. No tenant/Auth/application rows copied. Existing current QA and user previews untouched. Installed same required trusted extensions, matched actual extensions schema USAGE grants. Template clone business_platform_cube4_upgrade_qa is also owned, empty synthetic QA. No source database termination or reset.

Restore adjustments are explicit: existing target public schema uses IF NOT EXISTS; role-specific ALTER DEFAULT PRIVILEGES omitted because postgres cannot change supabase_auth_admin future defaults. Existing runtime object ACLs from dump retained. This is qualification of the exercised current functions, NOT fresh migration-ledger parity or a whole Supabase deployment recreation.

Hash across payroll/platform_private/platform_core/public function source+runtime ACL:
- live-owned QA source: c0e805bce96401ab6b6a7fd2aad24fbf
- dedicated QA before and after all successful tests: c0e805bce96401ab6b6a7fd2aad24fbf
- dedicated Auth users/tenants/final outputs:0:0:0 before and after rollback.

## Results

1. Existing monthly approved Leave + recurring earning public journey:34PASS. Extended by7behavior assertions to complete actual canonical corrected output through payment_request_prepare/get/submit, lost-response replay and public payment facts:41PASS, ROLLBACK. Returned remaining0; payment facts paid; exactly1event after replay; original frozen employee result unchanged. The existing canonical replacement-net assertion164.25 is positive; no vacuous zero-payment success.
2. Independent insured-month public journey:39PASS, ROLLBACK. Covers actual month ownership, preservation of original/replacement lineage and rejection of reuse. This is not independent official insurance-rate validation.
3. Existing old cube4_payroll_payments suite does NOT pass current canonical qualification: payroll_approval_blocked when it manually patches an old synthetic result. Do not weaken guards or claim it passed. New extension exercises actual composed canonical output, not manual final-output insertion.

Both positive journey suites FIRST prove the actual legal issuer rejects a synthetic pack, then explicitly simulate only that external legal-evidence dependency within the dedicated database transaction. No official evidence or legal approval fabricated, no bypass added to production. All actual calculate/approve/finalize/correction/payment logic and audit/atomicity/idempotency checks remain exercised.

## Review

Test-guard applied by root. Seven added assertions test distinct observable behavior; no additional mocks. Official Claude Opus5.5Medium d3c602d5-063c-45e3-9a13-7a869355cae0 reviewed the appended diff only: CONDITIONAL PASS pending plan/net checks. Root resolves both from current source: no_plan() at line7 and existing positive164.25 replacement assertions. Full run reports1..41/ROLLBACK without not-ok or plan diagnostics. Reviewer did not inspect/run whole fixture; no claim otherwise. No further review loop required for these resolved conditions.

Early restore attempts failed atomically on pre-existing public schema, missing pg_trgm and role-specific future default privileges; corrected isolation setup, no app changes. Initial journey failed on absent extensions-schema USAGE; exact source grants reproduced, rerun passed. Failure logs retained externally. All test failures ended with unchanged function hash and0:0:0 fixture state.

## Still required

Real independently obtained official results and reviewer attestation for Egypt2026 packs; source-bound effective-dated defaults/employee and cumulative context UX; actual financial live qualification and final deployment/rollback evidence. See reviewer-packet for ten proposed synthetic input scenarios with expected outputs deliberately blank. Owner will name reviewer. Goal remains active.
