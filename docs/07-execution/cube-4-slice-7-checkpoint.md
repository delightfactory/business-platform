# Cube 4 — Slice 7 source checkpoint

2026-10-02. Source frozen for independent review; no SQL execution, application, build or browser qualification.

## Executable source scope

Interest-free advance principal/versioned integer-cent schedule (final installment carries exact remainder), separate approval and externally evidenced disbursement activation, reviewed early/manual settlement with FIFO allocations, pre-obligation cancellation, reviewed defer/termination evidence, immutable compensating settlement entries and governed paid Payroll deduction correction. Current authority, exact scoped intent, CAS, immutable audit/receipts and Tenant → Employee → Employment → Employer serialization are preserved. Finance is a separate optional capability with People dependency; prior obligations remain readable/closable by currently authorized actors after entitlement loss. Existing approved Payroll adjustments retain their existing interpretation.

Actual run_manifest, amendment_manifest, build_review, engine freshness and append_final_output_single integration includes immutable advance source identity. Locked consumption appends the exact allowed deduction and allocation atomically with final output, never in a separate browser command. Unpaid replacement restores original consumption through immutable compensating movements before recording successor attribution. Ever-paid correction requires the exact reviewed external responsibility, output, Employment and amount; original net/payments/ever-paid fact survive. Private allowance records need effective verified statutory pack, classification, insured-wage basis and obligation evidence. They do not fabricate a legal adapter. Without qualified allowance/capacity, due debt remains visible and calculation has an owned blocker; an insufficient allowed amount requires reviewed carry-forward.

Arabic task UI leads with principal, ledger balance and next installment; independent 30-bound reference search/pages preserve selected context. Schedule/history are secondary. Finance-only actors receive an owned Payroll handoff; final-output links require current view authority. A completed correction remains reachable on reload to recover its original request receipt.

## Durable request resolution

Before any network call, browser Web Locks serialize actor/Tenant/Employer local journal creation. Journal stores exact original operation, Employment, advance, expected revision, fields and attempt; no JWT/credential or automatic expiry. Late responses may clear only their matching attempt. Reload, Back/Forward and whole Server Action response loss retain original intent. Resolver and every writer share the same database scope lock and require original operation's current authority before receipt/tombstone resolution. An original committed receipt is returned; definitive absence appends an immutable intent-bound tombstone that rejects a delayed original writer. Denial/lock/transport failure never clears an unresolved journal. A failed validation or CAS request can be safely released only through that authoritative absence proof. Real concurrent resolver/writer orders and full HTTP loss/reload remain runtime gates.

## Mistaken principal evidence boundary

`correct_disbursement` requires current Finance manage AND approve, a reviewed reference/reason/confirmation, original disbursement, exact unchanged principal balance and NO historical settlement or Payroll deduction (even if later compensated). It appends an exact reversing entry; original principal and evidence remain immutable. Canonical private `payroll.advance_status(tenant, advance)` returns `record_corrected`, never `settled`. Corrected debt is excluded from due-source projection. `advance_replacements(tenant_id,replacement_id,original_id,correction_event)` immutably links a separately drafted/approved replacement. This is correction of erroneous evidence, not bank refund/write-off/forgiveness of genuine debt.

Remaining concrete case: discrepant original principal AFTER genuine repayment/locked consumption requires an independently reviewed legal/source reconciliation basis. This slice deliberately refuses the mistaken-evidence shortcut in that case and does not claim complete principal-amendment lifecycle qualification.

## Checks actually executed

- Initial focused ESLint for seven changed TS/TSX files: PASS; initial TypeScript noEmit: PASS.
- Final known-delta ESLint (AdvanceForm, advances page/rules, operator capability page): PASS; final TypeScript noEmit: PASS.
- Initial 84 rollback assertions plus 16 bounded cycle2 assertions (100 total) authored, NOT executed. Coverage includes cent remainder, approval/activation, ledger settlement/compensation, entitlement loss, authority-bound receipt/tombstone ordering, private ACL, legal refusal, atomic final-post rollback/replay, unpaid amendment and paid correction, mistaken disbursement reversal/linked replacement, and corrected-choice reload recovery. Sequential writer/resolver fixtures are not actual concurrent race evidence.
- No previous suites repeated; no build/apply/browser/commit/remote action.
- Slice6 migration preserved: `8b1455c25b8e875eca25c39c7b4f818c293b175bf0045d6b61361fd6d5d6270b`.

## Open qualification gates

Slice6 remains frozen/unapplied after its review limit, with its unresolved durable-absence UI recovery finding. Both actual QA databases remain ledger114. Slice7 depends on reviewed/qualified Slice6 schema and must not be applied by skipping it; later chain is 115 → 116. Slice7 SQL compile/runtime/authority/actual concurrency/UI/full HTTP recovery and statutory-capacity qualification are unperformed. No public G6, lawful net, production legal qualification, bank execution or complete Cube4 claim.

## Bounded independent-review cycle2 delta

Cycle1 independent source review returned FAIL with two P1 findings (review JSON `C:\Users\DELL\AppData\Local\ai-dev-workflow\reviews\cube4-slice7-independent-review-cycle1.json`). The source delta changes only the new Slice7 migration and suite. Unpaid amendment eligibility now uses the virtual advance balance excluding the original output's signed movements, so a fully consumed zero-current-balance loan remains a restored source with current allowance/freshness requirements. Paid-original restoration remains refused. Deduction compensation and list/selected-reference checks require exact POSITIVE reviewed responsibility; opposite negative employee_recovery is never accepted through absolute-value matching.

16 additional assertions cover a separate Employer's single installment fully consumed by the unpaid original, ordinary omission vs amendment restoration, stale/missing allowance blocker, atomic original compensation plus exact successor consumption, unchanged zero debt/payable/original evidence; and negative responsibility omission/direct refusal with no ledger/revision/success-audit/receipt effects. These assertions are authored, NOT run. No TS/TSX changed in this delta; prior affected ESLint/typecheck PASS remain actual evidence and were not repeated. No SQL compile/apply/tests/build/browser/commit. Nine-file ABI shapes unchanged; only migration/test hashes differ. Source is frozen again for cycle2 review, no cycle3 loop.

## Frozen source hashes

Machine-readable companion: `cube-4-slice-7-source-hashes.json`.

| File | SHA256 |
| --- | --- |
| `supabase/migrations/20261002063000_cube4_payroll_advances.sql` | `1e21c85e612bec9525223cb3615566ebfbc7a958c0425fed82410b494a0da3ee` |
| `supabase/tests/cube4_payroll_advances.test.sql` | `cdb244b22aaabd64cf72bfca10946cb047f8c7dd5f58a668f8e509400f5c30c9` |
| `src/app/tenant/[tenantId]/payroll/advances/rules.ts` | `9b1f82e6715cd555f8b0e5c8000e238e01a62867ce885858b5897581a3090d9c` |
| `src/app/tenant/[tenantId]/payroll/advances/actions.ts` | `f1bb586f3a2414bf201a5adf347705017205f3b6f270e7477b26ac03b371bfc0` |
| `src/app/tenant/[tenantId]/payroll/advances/AdvanceForm.tsx` | `d304f41a6ba45735b6db04927cd0ca5b0fd3baec3a06c74f1e99284b723995f4` |
| `src/app/tenant/[tenantId]/payroll/advances/page.tsx` | `b7f2b96028f823b90beef2d8231d93c503f91f9d8d9d607dccc9932a42d113bb` |
| `src/app/tenant/[tenantId]/payroll/runs/rules.ts` | `719eec345dc67b9265dad5d37bf9b0474a3cf7c4279a57724c8d3d068f1708fb` |
| `src/app/operator/entitlements/actions.ts` | `01a6f180d7338da72803ef8537247b357d98b19d4457ad3e7c6d863bd8286ab4` |
| `src/app/operator/entitlements/[tenantId]/page.tsx` | `2a2118e50f52a5af8aafc3fc4c5cae29b485116bf8e86094f7da4b3caf4277b6` |

## Qualified Adam-fix compatibility integration

The separately qualified additive20261002030000 fix advances both dedicated local QA ledgers to115 and engine identity to cube4-review-v3-source-safe. Two asserted candidate-engine anchor literals in this still-unapplied Slice7 migration were updated; reversing only those literals restores original reviewed SHA1e21c85e612bec9525223cb3615566ebfbc7a958c0425fed82410b494a0da3ee. Exact new migration SHA07cda75ce89dcfeb199f391aab394219c33b8b443a8d5b51ef073fa7d6bb7b74.

Independent compatibility-only review PASS: cube4-post-adam-compatibility-delta-review.json. Original financial source review cycle2 PASS is preserved. Prepared qualification runners now require exact qualified Adam fix hash, then approved/qualified Slice6 ledger116 before Slice7 ledger117. Slice6 approval input is still absent; no gate bypass, SQL application, new DB assertion execution or browser/build qualification is implied.100 authored Slice7 assertions remain unexecuted.


## Current authorized ordered local qualification

Source6 full105 assertions on each baseline and authenticated concurrent recovery races now PASS; qualified dependency installed116. Original reviewed Source7 migration07cda75ce89dcfeb199f391aab394219c33b8b443a8d5b51ef073fa7d6bb7b74 preflight PASS then installed locally to117 on both QA databases. No production/publication.

First actual100-case suite stopped before assertions: its next-period quotes incorrectly used calendar-change preview on historical dates. Three quotes now use actual public workspace.next_preview; second same-Tenant default site corrected to nondefault. Narrow source review PASS, dates/money/production source unchanged. Changed suite executed19 passing assertions then stopped at a fixture setting end_date without employment_status='ended'. Root corrected that one setup statement; latest testff2a57480dca9cd59d570ab83f418f030251f96b7be4192ada2d782e634751bd awaits scoped review and qualification. No100-case/runtime completion claim. Failed evidence retained; no repeated successful earlier Payroll suites.


## Actual full Source7 SQL acceptance

First real fixture runs exposed dated preview ABI, employment lifecycle and correction lifecycle setup errors; each was corrected with bounded source review and existing production guards preserved. Current test SHA87b0882e8bfd7eee38599a2356f5da1746883e0a7fedd6e4ed74d6e01a58470d. Four correction fixtures now link their proposals through draft/review/approved/routed transitions with real revision guards. Monetary/security assertions are unchanged.

Actual function scan found two SQL/PL variable-alias collisions. Original Source7 ledger/source07cda remains immutable. Additive20261002064500_cube4_payroll_advance_namespace_fixes.sql SHAe9888c5c625aff55af039ffbfe5dc5bcddaea86dfe4929f6304847708a240350 repairs only those SQL aliases, with exact prior-definition MD5 and changed-anchor refusal. Independent cycle2 review PASS; rollback full Payroll function/trigger static scan0 errors, then local install118 both QA. Windows text-mode SQL input changed LF literal anchors into CRLF; readonly text/binary probe established cause, binary UTF8 executor fixed transport with prior failed evidence retained.

Actual Source7 test100/100 PASS each upgrade/fresh QA at118, with fixtures rolled back, evidence cube4-advances-tests-evidence.json. Existing Source6/Adam/Time/Leave suites not repeated. This verifies NONLEGAL adapter/interface fixtures only. Advance UI, authenticated command-response loss, real advance races, reports, lawful statutory allowance selection and final full financial workflow remain open.


### Current actual advance UI qualification — 2026-10-02

The isolated authenticated Arabic UI exercised one draft, three exact installments 33.33/33.33/33.34, approval, synthetic external disbursement100, settlement40, compensation40, and full settlement100. Final evidence proves revision6, five immutable events, zero outstanding, derived settled status, payments0 and final outputs0. Screens390/820/1280 have no horizontal overflow. The pre-send save and complete committed draft-response loss were recovered without duplicate writes.

Evidence: `cube4-advances-bounded-ui-evidence.json`, referencing retained initial/continuation failures and read-only final PASS. Settlement recovery required a harness restart reconstructing the exact journal from the immutable receipt after an early assertion; it does not prove uninterrupted browser recovery. The stored lifecycle remains active while the workspace derives settled from zero balance. No money operation was repeated to repair a verifier. Advance concurrency races, remaining choices, complete legal payroll and ordered Reports8 acceptance remain open.


### Actual advance recovery concurrency — 2026-10-02

Both authenticated live races PASS (`cube4-advances-live-recovery-races.json`). Writer247184 first blocks resolver247185, which returns the exact committed result after commit. Resolver first blocks the delayed writer, then rejects it with PT409/finance_attempt_closed. Closed attempt has zero receipts/one tombstone; draft remains revision1/principal25/debt0. No payroll output or payment effect. Existing advance SQL100each and money UI are retained without rerun. This is the advance recovery fence, not the complete payroll/source-consumption race matrix.
