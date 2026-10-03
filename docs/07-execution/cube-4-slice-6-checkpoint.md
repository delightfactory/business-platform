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


## Owner-approved recovery redesign (new bounded round, source only)

The owner explicitly approved this redesign after the original two failed review cycles. Those FAIL artifacts remain history; this delta is not a runtime PASS.

`payroll_correction_reconcile` resolves an original actor-scoped attempt under current Payroll and operation/domain authority. It never executes the original mutation. It takes the same `correction_lock` as correction writers (tenant 0 → tenant 90427 → ordered People/Employer rows), then verifies exact canonical intent against a committed receipt. If no receipt exists, it inserts an immutable actor/Tenant/attempt closure with mandatory audit. The four public journal writers check this closure after their existing authority/lock/intent construction and before receipt lookup; a delayed matching writer is refused. The candidate writer shares the tenant 90427 fence through its existing run lock. Conflicting intent, changed scope, lost authority and pre-lock/transport ambiguity do not resolve the client journal.

The Server Action uses the reconciliation RPC for journal recovery instead of replaying the write. Receipt-confirmed success clears the journal. Server-confirmed noncommit converts it into a resolved local draft, preserving fields and original form URL across remount. Preview validity is bound to that resolved draft identity: closing an attempt invalidates the old preview even when another hook instance owns the recovery panel. Editing and fresh preview then use a fresh request UUID; no automatic altered-intent replay occurs. A lost whole first Server Action response can reconcile from the pre-network journal even though no server signature reached the browser.

Authored SQL regression delta: **19 assertions**, main suite **71** (previous 52 unchanged); cross-Employer20 and source-ranges14 unchanged. Tests cover committed result identity/no replay, absent-receipt closure/idempotence, delayed writer refusal, altered intent, Tenant/Employer scope, immutable proof, single mandatory audit, removed/restored domain authority, changed actor and private ACLs.

Not executed in this implementation round: SQL migration/suites, build, browser, concurrent writer/closure race. Root qualification must prove both race outcomes, full Server Action response loss and reload/BackForward, retained unknown journal on authority/transport failure, retained editable fields after closed noncommit, new preview/new UUID and the existing canonical/choice workflows. Public financial/legal gates are unchanged.

### Recovery redesign file hashes

| File | SHA-256 |
| --- | --- |
| supabase/migrations/20261002040200_cube4_payroll_governed_corrections.sql | 7df205116b654e5a3062bf9a88d95f52c34ec03d8fabc70438a6af49a728fff7 |
| supabase/tests/cube4_payroll_corrections.test.sql | 4edf09b7363df0c1d7e52299a14996bfa6f421e1dce09b516f6713ee520e7519 |
| src/app/tenant/[tenantId]/payroll/corrections/actions.ts | 671e13602dca6f79ee61dfb21e52af17286b4c8306c83674dc28cf833456f810 |
| src/app/tenant/[tenantId]/payroll/corrections/rules.ts | a5b5a0bc65caf63fb849a6f5dacdd631877064b25abd2d255565b831cf5776f7 |
| src/app/tenant/[tenantId]/payroll/corrections/useCorrectionRecovery.ts | 16ac18488931d5f4b9ce776058b848d0ca4c8d64ec6aba3cc848b212af1f0f89 |
| src/app/tenant/[tenantId]/payroll/corrections/CorrectionForms.tsx | 6b5dac24177a3bc726a30d958e588267954eeeb9a89596881fadf2a2741b707a |


### Current root runtime qualification (supersedes implementation-only hashes above)

Current migration73d0ea2e1522c3d1606237748e0d8dc4bccf1636968f5b762b8ef2ee78d34c45; main testaff50b0d5b9be75e1ba39d0ccaf17d82556c75014f9b2d10ef0f56092fd665ba. Recovery redesign and each narrow parser, namespace, actor-permission API and JSON-operator delta independently reviewed PASS. One rollback plpgsql_check scan of all created/changed PLpgSQL functions and attached triggers found zero diagnostics; this is not behavioral or dynamic-SQL proof.

Actual main correction suite:71/71 PASS on protected upgrade baseline115, all DDL/fixtures rolled back and baseline identity preserved. This includes committed/closed/unresolved recovery and current authority checks. A text-format-only amount assertion was corrected to exact numeric equality before this PASS.

The next20-case cross-Employer suite stopped during fixture setup before any assertion: two sites were marked default in one Tenant, violating tenant_site_one_default_idx. Its assertions are unexecuted; the14-case source-range suite and fresh baseline are still unexecuted. Do not repeat the unchanged successful71-case upgrade suite when fixing this distinct fixture. Retain current successful per-suite evidence and baseline identity.

Evidence: cube4-source6-recovery-rollback-qualification.json; cube4-source6-static-full-diagnostics.json. Prior failed logs retained. Browser response-loss/remount and real writer/closure races, ordered chain, financial/statutory qualification remain open. No new publication or production change.


### Subsequent full SQL matrix and actual concurrent recovery

Actual71+20+14 assertions PASS on each fresh/upgrade baseline115, all fixtures/DDL rolled back. The successful unchanged71-case upgrade suite was reused from its exact TAP log/source/test hashes and revalidated baseline rather than repeated. The companion default-site fixture defect was corrected with a scoped independent PASS.

Exact qualified Source6 was installed locally, both ledgers116, proven in cube4-source6-qualified-local-install.json. Source7 was subsequently installed after its own reviewed preflight; current original QA ledgers117. Never run earlier baseline115-only runners against these advanced ledgers.

Actual authenticated recovery races PASS in cube4-source6-recovery-live-races-v2.json: writer-first resolver PID242861 blocked on242860 then returned exact committed result; resolver-first writer242860 blocked on242861 then refused PT409 payroll_attempt_closed. One immutable closure, no second receipt or revision, no source/payment effects. Fixture is explicitly SYNTHETIC_NONLEGAL and does not prove statutory/public full-finalization readiness.

A separate exact228-source-file runtime copy compiled and TypeScript passed, build __m3h9F46JnFrli5obzig, port3535 PID42016. Actual correction-page render failed because the generated React client manifest omits CorrectionForms.tsx references; SourcePicker is present. Build PASS is not UI acceptance. Runtime diagnosis is pending, no unchanged rebuild or financial command repeated. Prior app3435 remains intact.


### Actual browser recovery now qualified (bounded scope)

Client manifest diagnosis found concatenated client module ID0 omitted by installed Next16.3.6 flight-manifest-plugin truthiness fallback. Runtime-only client concatenateModules=false buildUT1GBR238M-wR24QN57Za restored the exact CorrectionForms entry. Authenticated real ServerAction journey PASS: request aborted before server execution retains journal across reload/BackForward; reconciliation closes noncommit, retains fields, refuses save until a new preview; next save uses new UUID, server commits but browser response is withheld completely; reload reconciles exact committed receipt without duplicate proposal/revision/source/payment effect. Result cases1,proposals2,source3000,effects0,payments0,revision2. Screens390/820/1280 no overflow; root inspected actual mobile screenshot. Evidence cube4-source6-recovery-actual-ui.json.

Main client-only Webpack configuration and explicit dev/build --webpack scripts were adopted after bounded cycle2 source PASS (cycle1 dev-script finding corrected). Main next dev --webpack startup and Arabic login GET200 actually PASS, owned temporary verification process stopped. No repeated unaffected tests/build. Runtime3535PID41096/buildUT1 remains separate; prior3435 preserved. This does not qualify statutory/current lawful net, all correction choices or full financial finalization.
