# Cube 4 Slice 6 source checkpoint — 2026-10-02

Status: source-frozen for independent review. This is authored source, not SQL/runtime/financial qualification. No migration application, build, browser run, commit, remote action, or prior suite replay was performed by the writer.

## Delivered scope

- Immutable typed proposal versions, audited preview/save/approve/release/cancel, CAS and atomic receipt recovery; separate approval of proposal and financially qualified amendment candidates.
- Governed compensation (whole or dated split), Employment eligibility/dates, assignment (whole or dated split), omitted new/existing Employee Employment, and bounded Payroll input versions. Private proof binds exact table/operation/old/new row, approved proposal, affected outputs, actor, transaction and backend. Existing lifecycle workforce status follows approved Employment changes.
- Never-paid replacement remains private until G6: all affected sources, candidate appends, original-to-successor links and run succession commit atomically; originals remain immutable. Any-ever-paid originals are preserved, including mixed paid/unpaid and Tenant policy effects across Employers. Locks use Tenant advisory foundation before deterministic Employee, Employment and Employer scopes.
- Paid correction uses explicit reviewed responsibility per paid output: signed later-period approved component or independently approved external settlement basis/evidence. Input creation does not imply paid/settled; external evidence does not fabricate statutory reconciliation. Original payable/payment ledger is unchanged.
- Applied original adjustments retain their exact immutable approved calculation basis in replacement calculation, once; they are neither omitted nor applied again. Normal calculation cannot recreate a financially finalized period.
- Arabic scoped discovery/source selection, preview, issue review, one primary next step, release/edit recovery, successor/history links, responsibility and settlement entry. Forms retain fields and unresolved intent; current authority checked before receipt recovery. Narrow handoffs from People, legacy correction requests, final output and payment review. Root overview/setup files remain separately owned and reviewed.

## Checks actually performed

- TypeScript first run found three branch-narrowing errors in corrections/page.tsx; fixed the edit branch. Changed-source typecheck then PASS (exit 0).
- ESLint over the 14 affected TS/TSX files below: PASS (exit 0). No unchanged static gates repeated.
- Authored main rollback suite: 41 assertions, not executed. It covers preserved source/original, legal gate, unpaid private replacement/replay, paid responsibility/evidence bounds, proposed new Employment target before insertion, mixed disposition, preserved consumed adjustment, current authority/recovery, and original scope identity.
- Root-owned cross-Employer companion: 20 assertions, not executed; unchanged hash listed below. Root owns its qualification separately. SQL compile/application and actual action response-loss/UI/race qualification remain root gates after independent review PASS.

## Explicit remaining qualification gates

No verified statutory pack/goldens or legal-net calculation, public irreversible G6 finalization, Time/Leave financial adapter qualification, or complete cross-domain G3 race claim. Synthetic NONLEGAL fixtures qualify invariants only. SQL supports bounded multi-change proposals; current interactive form authors one typed source change per version. Choice pages remain bounded to 30 records with independent query/cursor and separately scoped current selection. Browser exhaustion evidence is still a runtime gate. Independently reviewed settlement evidence is retained as an open accountable responsibility; no statutory settlement completion is inferred.

## Independent cycle 1 delta — source frozen for cycle 2

Cycle 1 FAIL found source expiry/inactive and absent-old INSERT ranges (root R1/R3), durable recovery (R2), enum mismatch (R4), and reference continuation (R5). Historical checks above remain historical observations.

- Root corrected affected-output discovery and authored the separate source_ranges companion: 14 unrun assertions. Its file and affected-output function remain root owned.
- R2 client journal is written before network: key payroll-correction:v1:+JSON.stringify([actor,tenant,employer,output]); __attempt is client UUID and __actor is current authenticated page user. Journal retains ordered FormData, original revision/attempt/href/form owner and previous ActionState including previewHash. No credentials/JWT or unresolved expiry. Persistent workspace recovery resolves original receipt even after workflow state changed. Current authority still gates server receipt access. Definitive receipt resolution clears journal; denied/transport recovery retains it. Storage failure prevents mutation submission. New/failed preview and changed fields invalidate confirmation.
- R4 shared inputOptions provides empty fixed base, percentage base_pay and fixed_30_day. Main fixture invalid uppercase key/base_salary was corrected to canonical values.
- R5 additive payroll_correction_choices supplies independent search/stable cursor per choice: items≤30 plus current selected metadata. Covers Employees/sources/sites/departments/jobs/managers/Employee identities/policy versions/periods/components/outputs. SourcePicker and server selection resolve later sources and exact reference labels/version beyond first page.

Final affected ESLint PASS; final typecheck PASS. Earlier lint found ref/effect synchronization errors and one replacement introduced a JSX delimiter error; corrected with only affected checks repeated. No SQL/application/browser/build/unchanged suites ran.

Main suite: 52 authored assertions, preserving previous 41 and adding R4/R5 canonical/31+ fixtures. Root cross-Employer companion:20; root source ranges:14. Full Server Action response-loss/reload/BackForward and authenticated 31+ browser journeys remain root qualification gates; no runtime PASS claimed here.

## Source SHA-256

| File | SHA-256 |
| --- | --- |
| supabase/migrations/20261002040200_cube4_payroll_governed_corrections.sql | 8b1455c25b8e875eca25c39c7b4f818c293b175bf0045d6b61361fd6d5d6270b |
| supabase/tests/cube4_payroll_corrections.test.sql | e51aeda26cb3f96809211e7c6cded74bb6f5dbf8f00fc27c59e86e8ec2b7e94e |
| supabase/tests/cube4_payroll_corrections_cross_employer.test.sql | 67180baecb9ceffe4aa5126a7d98e2dcbae68f7ab79454584cadfe860d83a374 |
| src/app/tenant/[tenantId]/payroll/corrections/actions.ts | ee04f7d687e9cf8a579a0075c726490039fa68abaf02de74729fd0164148c7f6 |
| src/app/tenant/[tenantId]/payroll/corrections/rules.ts | badb1f80367162f44d94a5e1c13cea31cb5b986b6424cb9ec05dbb84f4febc77 |
| src/app/tenant/[tenantId]/payroll/corrections/CorrectionForms.tsx | 012bd2bfca2cc758972eafa20f110cf86c6b91c871a8db2de7a89d2c6a4eda4a |
| src/app/tenant/[tenantId]/payroll/corrections/page.tsx | 1aed9929d8ddeed1ef375d499f4674e16dfe68c9635f026af041432f86b0675f |
| src/app/tenant/[tenantId]/payroll/inputs/CorrectionForm.tsx | 942abe541920f0440bcd290258852ca2c2ec3d384ad34015e3d22f6054ff356e |
| src/app/tenant/[tenantId]/payroll/output/page.tsx | 6e0a7e48053ffc3f1ce08f23671aa5c49c86b0afb22dfb87ab333556a43ded09 |
| src/app/tenant/[tenantId]/payroll/payments/page.tsx | d5a9c58430804256d75d30b752d0a0cf726a43f1ce6d7835f8aaec4dee45ff26 |
| src/app/tenant/[tenantId]/payroll/runs/rules.ts | a1a2d9b37752fbd6b2c9e278bc68437ffe12677a5fa79875575adc200a6812cf |
| src/app/tenant/[tenantId]/people/[employeeId]/page.tsx | 4e5ebe4e04cdd6062ba2a6f90854229d71fdb804e21cb13910954e7cc9e0f948 |
| src/app/tenant/[tenantId]/people/[employeeId]/CompensationPanel.tsx | 4eb1fe1236568e33d2bbae22107734486e459f5735e1d5d6e15c05d819b9163a |
| src/app/tenant/[tenantId]/people/compensation-actions.ts | f794d1b60d40653b778bcde81298f72c0b78a3228afba349d5a83a8bef2b829a |
| src/app/tenant/[tenantId]/people/employment-lifecycle-actions.ts | 7b48a7d76f20a1cba52e561dfa6dabf9bf852f203985580ca1dd3c7e189bcb9a |
| src/app/tenant/[tenantId]/people/work-assignment-actions.ts | 8f592149104b110ee615c16c97b086ba1a72a410ec0fded8c7a331260bd75577 |
| src/app/tenant/[tenantId]/users/page.tsx | b654975a7fd0218987a631495a4bca804a6cc024219f081283bbf108fc5367e2 |
| src/app/tenant/[tenantId]/payroll/corrections/useCorrectionRecovery.ts | 3979e0f4bf3c657b427f3e1847a3a7d02de7b490da0401ef2dbeddc030a31426 |
| src/app/tenant/[tenantId]/payroll/corrections/PagedChoice.tsx | 2654955e2513540b1207374260eddf6ff2b3bf2835557d372f86347bb4a3c5dd |
| src/app/tenant/[tenantId]/payroll/corrections/SourcePicker.tsx | fe0469bdbb10b64dce0588dfd766b880610fe4203798ac7adc830bf5012b939a |
| src/app/tenant/[tenantId]/payroll/inputs/rules.ts | d1707b33c7da6b438203b686f528055a7d96023624b87d1b1854ef82d3ee84b9 |
| src/app/tenant/[tenantId]/payroll/inputs/InputForm.tsx | 6cd65cd5ca1386ffa8f0d599c9ee546d625db3f61bdcdd2236f3294a4526731c |
| supabase/tests/cube4_payroll_corrections_source_ranges.test.sql | c7b1b7f0129c35d7e04ad42ffc61ee2521a0b46c17b4382beb95f37ac1ea5ed6 |
